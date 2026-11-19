class_name RoomView
extends SubViewportContainer
## 3D 小场景（房间线程）：按 places.csv 搭墙和地板，按 room_objects.csv 摆能点的东西。
## 生活舱和机械室、温室、通讯室、人类保护区、地下居民区都用它，只是 scene 不同。
## 通用交互：点物件 → 看说明 / 近看 / 开关；聊天、平板、舱门这三种交给外面的画面处理。
## 现在全是方块，以后换模型时只改 _make_object()，规则和表格不用动。

signal talk_requested
signal tablet_requested
signal door_requested
signal object_clicked(id: String)  # 每次点到东西都发，测试和以后的统计用

const WALL_THICKNESS := 0.1
const LOOK_TIME := 0.35
const SHADE_GROW := 1.6     # 灯罩比植物大多少
const HIDDEN_ALPHA := 0.25  # 书收起来后变淡，还能点回来
const LAMP_RANGE := 3.0
const MAIN_LIGHT_RANGE := 30.0
const STARFIELD_TEX := "res://assets/textures/room/T_Starfield.jpg"
const EARTH_TEX := "res://assets/textures/room/T_Earth_Surface.jpg"
const CLOUDS_TEX := "res://assets/textures/room/T_Earth_Clouds.png"
const CLOUD_LIFT := 1.01           # 云层比地面高一点点
const ATMOSPHERE_LIFT := 1.025
const EARTH_TINT := Color(0.85, 0.92, 1.0)  # 贴图有点太艳，压一点
const ATMOSPHERE_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never;
void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	ALBEDO = vec3(0.35, 0.6, 1.0) * rim * 1.6;
}
"""
const GLASS_COLOR := Color(0.75, 0.88, 0.97)
## 真模型里的玻璃零件：blend 里观景窗玻璃透明度是 0，导出后看不见，这里统一换成 Godot 的玻璃材质
const GLASS_NODES: Array[String] = ["Window_Glass", "EcoDome_Glass_Wall", "EcoDome_Glass_Cap", "Jar_Terrarium_Glass", "Dress_B2_Canister_Glass"]
const BACKDROP_DISTANCE := 6000.0   # 窗外星空离房间多远（米）：要在地球后面
const BACKDROP_SIZE := Vector2(28000, 16000)

var scene_id := "cabin"
var viewport := SubViewport.new()
var camera := Camera3D.new()
var info_panel: PanelContainer
var bodies := {}  # 物件 id -> StaticBody3D

var _place: Dictionary
var _rail_x := 0.0
var _home := Transform3D()   # 不近看时镜头的位置
var _looking := false
var _main_light: OmniLight3D
var _music: AudioStreamPlayer
var _music_base := 0.0
var _music_phase := 0.0
var _info_title: Label
var _info_text: Label
var _info_buttons: HBoxContainer
var _exclaim: Label3D
var girl: GirlModel          # 她的 VRoid 模型（没有模型文件时为空，用胶囊）
var _model: Node3D           # 真模型（没有时是方块墙）
var _starfield: MeshInstance3D
var _earth: MeshInstance3D
var _hover_label: Label      # 看不见的点击框没法发光，鼠标指上去时在左上角显示名字


func _ready() -> void:
	stretch = true
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_STOP
	_place = RoomRules.place(scene_id)
	viewport.own_world_3d = true
	viewport.physics_object_picking = true
	viewport.handle_input_locally = false
	add_child(viewport)
	_build_environment()
	if str(_place.get("model", "")).is_empty():
		_build_shell()
	else:
		_load_model()
	for row in RoomRules.objects_in(scene_id):
		_make_object(row)
	_rail_x = (float(_place["rail_from"]) + float(_place["rail_to"])) / 2.0  # 从过道中间开始
	_place_camera()
	camera.far = BACKDROP_DISTANCE * 1.5  # 要看得到很远的星空和地球
	viewport.add_child(camera)
	_build_info_panel()
	_hover_label = UiKit.short_label(self, "")
	_hover_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hover_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_hover_label.offset_top = 80  # 顶栏下面
	_hover_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hover_label.add_theme_color_override("font_color", GlassTheme.ACCENT)
	if scene_id == "cabin":
		_build_music()
	refresh()


func _process(delta: float) -> void:
	if not is_visible_in_tree() or _looking or _rail_length() <= 0.0:
		return
	var direction := Input.get_axis("ui_left", "ui_right")
	if Input.is_physical_key_pressed(KEY_A):
		direction -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		direction += 1.0
	if is_zero_approx(direction):
		return
	var speed := float(DataDB.balance("room_walk_speed"))
	_rail_x = clampf(_rail_x + clampf(direction, -1.0, 1.0) * speed * delta, float(_place["rail_from"]), float(_place["rail_to"]))
	_place_camera()


## 右键退出近看。Esc 留给暂停菜单。
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		stop_looking()
		hide_info()


# ---------- 搭场景 ----------

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(_place["light_color"])
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	viewport.add_child(world_env)
	_main_light = OmniLight3D.new()
	_main_light.omni_range = MAIN_LIGHT_RANGE
	_main_light.light_energy = 1.4
	_main_light.shadow_enabled = true
	_main_light.position = Vector3(0, float(_place["height"]) - 0.3, 0)
	viewport.add_child(_main_light)


## 地板、天花板、左右墙、里面的墙。靠镜头那面墙不做，镜头从那边看进来。
func _build_shell() -> void:
	var w := float(_place["width"])
	var d := float(_place["depth"])
	var h := float(_place["height"])
	var wall := Color(_place["wall_color"])
	var floor_color := Color(_place["floor_color"])
	_box(Vector3(0, -WALL_THICKNESS / 2, 0), Vector3(w, WALL_THICKNESS, d), floor_color)
	_box(Vector3(0, h + WALL_THICKNESS / 2, 0), Vector3(w, WALL_THICKNESS, d), wall.darkened(0.2))
	_box(Vector3(0, h / 2, -d / 2), Vector3(w, h, WALL_THICKNESS), wall)
	_box(Vector3(-w / 2, h / 2, 0), Vector3(WALL_THICKNESS, h, d), wall.darkened(0.08))
	_box(Vector3(w / 2, h / 2, 0), Vector3(WALL_THICKNESS, h, d), wall.darkened(0.08))


## 真模型：房间整个是一个 glb，再在窗外放星空和地球
func _load_model() -> void:
	var scene: PackedScene = load(str(_place["model"]))
	_model = scene.instantiate()
	viewport.add_child(_model)
	_main_light.omni_range = float(_place["width"]) * 2.0
	_main_light.position = Vector3(0, float(_place["height"]) - 0.4, 0)
	_build_backdrop()
	_apply_glass()
	_turn_off_fake_lights()


## blend 里左边柜子的拉手用了发光材质（WB_Amber_Light），游戏里看着像灯，yi 说不是灯，关掉发光
const NOT_LIGHTS: Array[String] = ["WB_Amber_Light"]


func _turn_off_fake_lights() -> void:
	for node in _model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		for i in mesh.mesh.get_surface_count():
			var mat := mesh.mesh.surface_get_material(i) as BaseMaterial3D
			if mat != null and NOT_LIGHTS.has(mat.resource_name):
				var plain := mat.duplicate() as BaseMaterial3D
				plain.emission_enabled = false
				mesh.set_surface_override_material(i, plain)


func _apply_glass() -> void:
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(GLASS_COLOR, float(DataDB.balance("room_glass_alpha")))
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.03
	glass.metallic_specular = 0.8  # 灯照上去有高光
	glass.rim_enabled = true  # 斜着看时边缘更亮，像真玻璃
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	for node_name in GLASS_NODES:
		var mesh := _model.find_child(node_name, true, false) as MeshInstance3D
		if mesh != null:
			mesh.material_override = glass


func _build_backdrop() -> void:
	_starfield = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = BACKDROP_SIZE
	_starfield.mesh = quad
	var sky := StandardMaterial3D.new()
	sky.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sky.albedo_texture = load(STARFIELD_TEX)
	_starfield.material_override = sky
	_starfield.position = Vector3(BACKDROP_DISTANCE, 0, 0)
	_starfield.rotation_degrees = Vector3(0, -90, 0)  # 面朝房间
	viewport.add_child(_starfield)
	var radius := float(DataDB.balance("room_earth_radius"))
	var center_parts := str(DataDB.balance("room_earth_center")).split(",")
	_earth = _sphere(radius, load(EARTH_TEX), false)
	_earth.position = Vector3(float(center_parts[0]), float(center_parts[1]), float(center_parts[2]))
	_earth.rotation_degrees.y = float(DataDB.balance("room_earth_turn"))
	viewport.add_child(_earth)
	_earth.add_child(_sphere(radius * CLOUD_LIFT, load(CLOUDS_TEX), true))
	_earth.add_child(_atmosphere(radius * ATMOSPHERE_LIFT))


## 大气层：地球边缘一圈淡蓝色的光（越靠边越亮）
func _atmosphere(radius: float) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 128
	sphere.rings = 64
	node.mesh = sphere
	var shader := Shader.new()
	shader.code = ATMOSPHERE_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shader
	node.material_override = mat
	return node


func _sphere(radius: float, texture: Texture2D, see_through: bool) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 128
	sphere.rings = 64
	node.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = texture
	mat.albedo_color = EARTH_TINT
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if see_through:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	node.material_override = mat
	return node


## 在真模型里按名字找零件（开关灯罩、收书时要藏起来的那些）
func _model_nodes(row: Dictionary) -> Array[Node3D]:
	var result: Array[Node3D] = []
	if _model == null:
		return result
	for node_name in str(row.get("nodes", "")).split(";", false):
		var node := _model.find_child(node_name.strip_edges(), true, false) as Node3D
		if node != null:
			result.append(node)
	return result


func _box(pos: Vector3, box_size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = box_size
	mesh.mesh = box
	mesh.material_override = _material(color)
	mesh.position = pos
	viewport.add_child(mesh)
	return mesh


func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	return mat


func _make_object(row: Dictionary) -> void:
	var box_size := Vector3(float(row["sx"]), float(row["sy"]), float(row["sz"]))
	var color_text := str(row["color"])
	var color := Color(color_text) if not color_text.is_empty() else Color.GRAY
	var body := StaticBody3D.new()
	body.name = str(row["id"])
	body.position = Vector3(float(row["x"]), float(row["y"]), float(row["z"]))
	body.set_meta("row", row)
	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	if row["kind"] == "talk":
		# 她的占位人形用胶囊，比方块像人；以后换少女模型
		var capsule := CapsuleMesh.new()
		capsule.radius = box_size.x / 2.0
		capsule.height = box_size.y
		mesh.mesh = capsule
	else:
		var box := BoxMesh.new()
		box.size = box_size
		mesh.mesh = box
	var mat := _material(color)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material_override = mat
	mesh.visible = not color_text.is_empty()  # 颜色空着：盖在真模型上的看不见的点击框
	body.add_child(mesh)
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = box_size
	shape.shape = box_shape
	body.add_child(shape)
	viewport.add_child(body)
	bodies[row["id"]] = body
	if row["kind"] == "prop":
		body.input_ray_pickable = false
		return
	body.input_event.connect(func(_cam: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape: int) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			click(str(row["id"])))
	if scene_id != "cabin":
		body.set_meta("glow_always", true)  # 场所里能点的东西一直微微发光，玩家知道该点哪里
	body.mouse_entered.connect(func() -> void: _set_glow(body, true))
	body.mouse_exited.connect(func() -> void: _set_glow(body, false))
	match row["effect"]:
		"light":
			if row["id"] == "ceiling_light":
				body.set_meta("light", _main_light)
			else:
				var lamp := OmniLight3D.new()
				lamp.omni_range = LAMP_RANGE
				lamp.position = Vector3(0, box_size.y, 0)
				body.add_child(lamp)
				body.set_meta("light", lamp)
		"cover" when _model_nodes(row).is_empty():
			var shade := MeshInstance3D.new()
			shade.name = "Shade"
			var shade_box := BoxMesh.new()
			shade_box.size = box_size * SHADE_GROW
			shade.mesh = shade_box
			var glass := _material(Color(0.8, 0.9, 1.0, 0.3))
			glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			shade.material_override = glass
			body.add_child(shade)
	if row["kind"] == "talk" and GirlModel.available():
		# 有她的模型就用模型，胶囊藏起来只当点击框
		mesh.visible = false
		girl = GirlModel.new()
		# 大小和坐下时往下放多少都在 balance.csv（yi：按参考图比例放大）
		# 15 岁（时间跳跃后）再大一些（yi 11.19）
		var teen := GameState.age >= int(DataDB.balance("teen_age", 15))
		var girl_scale := float(DataDB.balance("room_girl_scale_15" if teen else "room_girl_scale", 1.0))
		girl.scale = Vector3.ONE * girl_scale
		girl.position = Vector3(0, -float(row["y"]) + float(DataDB.balance("room_girl_drop_15" if teen else "room_girl_drop", -0.25)), 0)
		# 平板在哪：她隔一会儿抬手指一下
		for other in RoomRules.objects_in(scene_id):
			if other["kind"] == "tablet":
				girl.point_target = Vector3(float(other["x"]), float(other["y"]), float(other["z"]))
		body.add_child(girl)
	if row["kind"] == "talk":
		_exclaim = Label3D.new()
		_exclaim.text = "!"
		_exclaim.font_size = 96
		_exclaim.modulate = Color(1, 0.85, 0.2)
		_exclaim.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_exclaim.position = Vector3(0, box_size.y * 0.5 + 0.25, 0)
		_exclaim.visible = false
		body.add_child(_exclaim)


func _set_glow(body: StaticBody3D, on: bool) -> void:
	var row: Dictionary = body.get_meta("row")
	_hover_label.text = Text.t(row["name_key"]) if on else ""
	var mat: StandardMaterial3D = (body.get_node("Mesh") as MeshInstance3D).material_override
	if on:
		mat.emission_enabled = true
		mat.emission = mat.albedo_color
		mat.emission_energy_multiplier = float(DataDB.balance("room_glow")) * 2.0
	else:
		mat.emission_enabled = false
		refresh()  # 灯和窗户本来就亮，恢复原样


## 按现在的状态更新画面：灯开关、灯罩、书、窗景、灯色、音乐
func refresh() -> void:
	var light_color := Color(RoomRules.current_option("light").get("color", "#ffffff")) if scene_id == "cabin" else Color(_place["light_color"])
	_main_light.light_color = light_color
	for id: String in bodies:
		var body: StaticBody3D = bodies[id]
		var row: Dictionary = body.get_meta("row")
		var on := RoomRules.is_on(id)
		var mat: StandardMaterial3D = (body.get_node("Mesh") as MeshInstance3D).material_override
		match row["effect"]:
			"light":
				var light: Light3D = body.get_meta("light")
				light.visible = on
				light.light_color = light_color
				mat.emission_enabled = on
				mat.emission = mat.albedo_color
				mat.emission_energy_multiplier = 1.0
			"cover":
				if body.has_node("Shade"):
					(body.get_node("Shade") as Node3D).visible = on
				for node in _model_nodes(row):
					node.visible = on
			"hide":
				mat.albedo_color.a = 1.0 if on else HIDDEN_ALPHA
				for node in _model_nodes(row):
					node.visible = on
			"window":
				if _starfield != null:
					var view := RoomRules.current_option("view")
					var sky: StandardMaterial3D = _starfield.material_override
					sky.albedo_color = Color(view.get("color", "#ffffff"))
					# 方舟走廊：灰墙，不要星星
					sky.albedo_texture = load(STARFIELD_TEX) if int(view.get("earth", 0)) == 1 or view.get("id", "") == "view_stars" else null
					# 实时画面：地球也跟着偏灰（原始图像，没有色彩优化）
					(_earth.material_override as StandardMaterial3D).albedo_color = EARTH_TINT * Color(view.get("color", "#ffffff"))
					_earth.visible = int(view.get("earth", 0)) == 1
					continue
				mat.albedo_color = Color(RoomRules.current_option("view").get("color", "#101830"))
				mat.emission_enabled = true
				mat.emission = mat.albedo_color
				mat.emission_energy_multiplier = 0.8
		if body.has_meta("glow_always"):
			mat.emission_enabled = true
			mat.emission = mat.albedo_color
			mat.emission_energy_multiplier = float(DataDB.balance("room_glow"))
	if _music != null:
		_music_base = float(RoomRules.current_option("music").get("value", 0))


## 她想说话时头上冒感叹号，点她聊过就消失
func set_exclaim(on: bool) -> void:
	if _exclaim != null:
		_exclaim.visible = on


# ---------- 交互 ----------

## 点到一个物件。测试直接调用它，不用模拟鼠标。
func click(id: String) -> void:
	var body: StaticBody3D = bodies.get(id)
	if body == null:
		return
	var row: Dictionary = body.get_meta("row")
	object_clicked.emit(id)
	match row["kind"]:
		"talk":
			set_exclaim(false)
			if girl != null:
				girl.smile()
			talk_requested.emit()
		"tablet":
			tablet_requested.emit()
		"door":
			door_requested.emit()
		"look":
			look_at_object(id)
			show_info(row)
		"toggle":
			if str(row["info_key"]).is_empty():
				RoomRules.toggle(id)  # 灯：点一下就开关，不弹窗
				refresh()
			else:
				show_info(row)
		_:
			show_info(row)


func look_at_object(id: String) -> void:
	var body: StaticBody3D = bodies[id]
	var target := body.global_position
	var from := _home.origin
	var direction := (from - target).normalized()
	var mesh: MeshInstance3D = body.get_node("Mesh")
	var distance := float(DataDB.balance("room_look_distance")) + mesh.mesh.get_aabb().size.length()
	var goal := Transform3D(Basis(), target + direction * distance).looking_at(target, Vector3.UP)
	_looking = true
	_tween_camera(goal)


func stop_looking() -> void:
	if not _looking:
		return
	_looking = false
	_tween_camera(_home)


func is_looking() -> bool:
	return _looking


func _tween_camera(goal: Transform3D) -> void:
	if not is_inside_tree():
		camera.transform = goal
		return
	var tween := create_tween()
	tween.tween_property(camera, "transform", goal, LOOK_TIME).set_trans(Tween.TRANS_SINE)


func _rail_length() -> float:
	return float(_place["rail_to"]) - float(_place["rail_from"])


func _place_camera() -> void:
	var cam_x := str(_place.get("cam_x", ""))
	if not cam_x.is_empty():
		# 真模型：镜头对齐 blend 里的主镜头
		camera.keep_aspect = Camera3D.KEEP_WIDTH
		camera.fov = float(_place["cam_fov"])
		_home = Transform3D(Basis(Vector3.UP, deg_to_rad(float(_place["cam_yaw"]))), Vector3(float(cam_x), float(_place["cam_y"]), float(_place["cam_z"])))
		if not _looking:
			camera.transform = _home
		return
	var pos := Vector3(_rail_x, float(_place["cam_y"]), float(_place["cam_z"]))
	var look := Vector3(_rail_x, float(_place["cam_y"]) - 0.5, -float(_place["depth"]) / 2)
	_home = Transform3D(Basis(), pos).looking_at(look, Vector3.UP)
	if not _looking:
		camera.transform = _home


# ---------- 说明面板 ----------

func _build_info_panel() -> void:
	info_panel = PanelContainer.new()
	info_panel.custom_minimum_size = Vector2(420, 0)
	# 放在右边中间，不挡底部按钮和左边的状态面板
	info_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT, Control.PRESET_MODE_MINSIZE)
	info_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	info_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	info_panel.offset_right = -24
	var box := VBoxContainer.new()
	info_panel.add_child(box)
	_info_title = UiKit.title(box, "")
	_info_text = UiKit.label(box, "")
	_info_buttons = UiKit.row(box)
	info_panel.visible = false
	add_child(info_panel)


func show_info(row: Dictionary) -> void:
	_info_title.text = Text.t(row["name_key"])
	_info_text.text = RoomRules.info_text(row)  # 按年龄、周数、窗外画面挑说明（定稿 RM）
	for child in _info_buttons.get_children():
		child.queue_free()
	var id := str(row["id"])
	if row["kind"] == "toggle":
		var toggle_button := UiKit.button(_info_buttons, RoomRules.toggle_label(row["effect"], RoomRules.is_on(id)), func() -> void: pass)
		toggle_button.pressed.connect(func() -> void:
			RoomRules.toggle(id)
			refresh()
			toggle_button.text = RoomRules.toggle_label(row["effect"], RoomRules.is_on(id)))
	UiKit.button(_info_buttons, Text.t("RT-02-16"), func() -> void:
		hide_info()
		stop_looking())
	info_panel.visible = true


func hide_info() -> void:
	info_panel.visible = false


func info_text() -> String:
	return _info_text.text if info_panel.visible else ""


# ---------- 音乐（还没有素材，先合成一个很轻的和弦） ----------

func _build_music() -> void:
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = 22050.0
	stream.buffer_length = 0.3
	_music = AudioStreamPlayer.new()
	_music.stream = stream
	_music.volume_db = float(DataDB.balance("room_music_volume_db"))
	add_child(_music)
	_music.play()
	set_process_internal(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_INTERNAL_PROCESS and _music != null and _music.playing:
		_fill_music()


## 三个音（根音、大三度、五度）叠在一起，音量慢慢起伏
func _fill_music() -> void:
	var playback := _music.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return
	var rate := (_music.stream as AudioStreamGenerator).mix_rate
	var frames := playback.get_frames_available()
	for i in frames:
		var sample := 0.0
		if _music_base > 0.0:
			var t := _music_phase / rate
			var swell := 0.6 + 0.4 * sin(TAU * 0.1 * t)
			sample = (sin(TAU * _music_base * t) + sin(TAU * _music_base * 1.25 * t) + sin(TAU * _music_base * 1.5 * t)) / 3.0 * swell * 0.5
		playback.push_frame(Vector2(sample, sample))
		_music_phase += 1.0
