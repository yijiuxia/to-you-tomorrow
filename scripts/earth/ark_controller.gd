class_name ArkController
extends CharacterBody3D
## ARK-01：第三人称下玩家操控。WASD 移动，按住右键转视角，空格跳，
## Tab 换工具头，按住 E 用当前工具，F 拾取，Q 扫描（比赛版 4.4、demo 文案 1-2）。
## 四个工具头：切割（拆小废料）、焊接（修坏掉的设备）、装配（特殊施工）、喷洒（种植）。
## 现场操作不消耗工作单位。

signal message(text: String)
signal prompt_changed(text: String)
signal tool_changed(tool: String)
signal girl_comment(text: String)

const TOOLS: Array[String] = ["cutter", "welder", "assembler", "sprayer"]
const TOOL_KEYS := {"cutter": "UI-18-20", "welder": "UI-18-21", "assembler": "UI-18-22", "sprayer": "UI-18-23"}

const BODY_SIZE := Vector3(1.4, 1.6, 1.8)
const BODY_COLOR := Color(0.95, 0.95, 0.9)
const SCREEN_COLOR := Color(0.2, 0.8, 0.85)
const JUMP_SPEED := 6.0
const GRAVITY := 18.0
const LOOK_SPEED := 0.3
const CAMERA_DISTANCE := 8.0
const CAMERA_HEIGHT := 1.5
const PITCH_MIN := -60.0
const PITCH_MAX := 10.0
const START_PITCH := -20.0
const TURN_SPEED := 10.0
const OUTLINE_SHADER := preload("res://scripts/earth/outline.gdshader")

var active := false
var world: EarthWorld
var view: EarthView
var camera: Camera3D

var _pivot: Node3D
var _spring: SpringArm3D
var _visual: Node3D
var _outline: MeshInstance3D
var _looking := false
var _cut_progress := 0.0
var _cut_target := ""
var _speed: float
var _cut_seconds: float
var _range: float
var _last_prompt := ""
var tool := "cutter"
var _special_seconds: float
var _rng := RandomNumberGenerator.new()


func setup(earth_view: EarthView, start: Vector3) -> void:
	view = earth_view
	world = earth_view.world
	_speed = float(DataDB.balance("ark_speed"))
	_cut_seconds = float(DataDB.balance("ark_cut_seconds"))
	_range = float(DataDB.balance("ark_interact_range"))
	_special_seconds = float(DataDB.balance("ark_special_seconds"))
	_rng.randomize()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = BODY_SIZE
	shape.shape = box
	shape.position = Vector3.UP * BODY_SIZE.y / 2.0
	add_child(shape)
	_build_visual()
	_build_camera()
	position = start


func set_active(value: bool) -> void:
	active = value
	camera.current = value
	_outline.visible = value
	if not value:
		_looking = false
		prompt_changed.emit("")


func _physics_process(delta: float) -> void:
	if not active:
		return
	var input := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W):
		input.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		input.y += 1.0
	if Input.is_physical_key_pressed(KEY_A):
		input.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		input.x += 1.0
	var move := Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, _pivot.rotation.y).normalized()
	velocity.x = move.x * _speed
	velocity.z = move.z * _speed
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	if is_on_floor() and Input.is_physical_key_pressed(KEY_SPACE):
		velocity.y = JUMP_SPEED
	move_and_slide()
	if move != Vector3.ZERO:
		_visual.rotation.y = lerp_angle(_visual.rotation.y, atan2(move.x, move.z), minf(1.0, TURN_SPEED * delta))
	world.ark_position = position
	_update_cutting(delta)
	_update_prompt()


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event
		if button.button_index == MOUSE_BUTTON_RIGHT:
			_looking = button.pressed
	elif event is InputEventMouseMotion and _looking:
		var motion: InputEventMouseMotion = event
		_pivot.rotation_degrees.y -= motion.relative.x * LOOK_SPEED
		_spring.rotation_degrees.x = clampf(_spring.rotation_degrees.x - motion.relative.y * LOOK_SPEED, PITCH_MIN, PITCH_MAX)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_F:
				pick_up_nearest()
			KEY_Q:
				scan()
			KEY_TAB:
				next_tool()


func next_tool() -> void:
	tool = TOOLS[(TOOLS.find(tool) + 1) % TOOLS.size()]
	_cut_progress = 0.0
	tool_changed.emit(tool)


## 当前工具对准的目标：{ kind, id, seconds, prompt }；没有目标返回空字典
func current_target() -> Dictionary:
	match tool:
		"cutter":
			var ruin := nearest_small_ruin()
			if not ruin.is_empty():
				return {"kind": "cut", "id": ruin, "seconds": _cut_seconds, "prompt": Text.t("UI-18-05")}
		"welder":
			for building: Dictionary in world.buildings.values():
				if building.get("broken", false) and _near_rect(Rect2i(int(building["x"]), int(building["z"]), int(building["w"]), int(building["h"]))):
					return {"kind": "repair", "id": building["uid"], "seconds": _cut_seconds, "prompt": Text.t("UI-18-24")}
		"assembler":
			var special := nearest_special()
			if not special.is_empty():
				var name := Text.t(str(DataDB.row("earth_specials", special)["name_key"]))
				return {"kind": "special", "id": special, "seconds": _special_seconds, "prompt": Text.f("UI-18-25", {"name": name})}
		"sprayer":
			var cell := view.cell_at(position)
			if not world.plants.has(cell):
				return {"kind": "plant", "id": cell, "seconds": _cut_seconds, "prompt": Text.t("UI-18-26")}
	return {}


## 附近能做的特殊施工；收发器在 ARK-01 自己身上，剧情允许后哪里都能修
func nearest_special() -> String:
	for id: String in DataDB.table("earth_specials"):
		if world.is_special_done(id):
			continue
		var prop := str(DataDB.row("earth_specials", id)["prop"])
		if prop.is_empty():
			if GameState.flags.get("transceiver_allowed", false):
				return id
		elif _near_rect(world.prop_rect(prop)):
			return id
	return ""


## 用当前工具做一次（按住 E 的计时在 _update_cutting 里，测试也可以直接调这里）
func use_tool(target: Dictionary) -> void:
	match target["kind"]:
		"cut":
			cut(target["id"])
		"repair":
			if world.repair_building(target["id"]):
				message.emit(Text.t("UI-18-27"))
				girl_comment.emit(Text.t("UI-20-22"))
		"special":
			var result := world.try_special(target["id"], _rng)
			if result["ok"]:
				message.emit(Text.t("UI-18-28"))
			elif not str(result["key"]).is_empty():
				message.emit(Text.f(result["key"], result["values"]))
		"plant":
			if world.hand_plant(target["id"]):
				message.emit(Text.t("UI-18-29"))
			else:
				message.emit(Text.t("UI-13-03"))


func _near_rect(rect: Rect2i) -> bool:
	var cell := view.cell_at(position)
	var grown := rect.grow(int(ceil(_range / view.cell_size)))
	return grown.has_point(cell)


## 最近的小废料 id；范围内没有返回空字符串
func nearest_small_ruin() -> String:
	var best := ""
	var best_distance := _range + cell_half()
	for id: String in world.ruins:
		var ruin: Dictionary = world.ruins[id]
		if ruin["cleared"] or ruin["kind"] == EarthWorld.RUIN_BIG:
			continue
		var distance := _flat_distance(view.rect_center(int(ruin["x"]), int(ruin["z"]), int(ruin["w"]), int(ruin["h"])))
		if distance < best_distance:
			best_distance = distance
			best = id
	return best


func cell_half() -> float:
	return view.cell_size / 2.0


## 拆一块。按住 E 的计时在 _update_cutting 里，测试也可以直接调这里。
func cut(ruin_id: String) -> void:
	if not world.cut_small(ruin_id).is_empty():
		message.emit(Text.t("UI-18-01"))


func pick_up_nearest() -> void:
	for scrap in world.scraps:
		if _flat_distance(view.cell_center(scrap["cell"])) <= _range + cell_half():
			var got := world.pick_up(scrap["id"])
			if int(got["electronics"]) > 0:
				message.emit(Text.f("UI-18-03", {"metal": got["metal"], "electronics": got["electronics"]}))
			else:
				message.emit(Text.f("UI-18-02", {"metal": got["metal"]}))
			return


## 扫描周围有什么
func scan() -> void:
	var radius := float(DataDB.balance("earth_scan_radius"))
	var counts := {"ruins": 0, "buildings": 0, "scraps": 0}
	for id: String in world.ruins:
		var ruin: Dictionary = world.ruins[id]
		if not ruin["cleared"] and _flat_distance(view.rect_center(int(ruin["x"]), int(ruin["z"]), int(ruin["w"]), int(ruin["h"]))) <= radius:
			counts["ruins" if ruin["kind"] == EarthWorld.RUIN_BIG else "scraps"] += 1
	for building: Dictionary in world.buildings.values():
		if _flat_distance(view.rect_center(int(building["x"]), int(building["z"]), int(building["w"]), int(building["h"]))) <= radius:
			counts["buildings"] += 1
	var found := 0
	for id in world.active_clues():
		var clue_radius := float(DataDB.row("earth_clues", id).get("scan_radius", 0))
		if _flat_distance(view.cell_center(world.clue_cell(id))) <= (clue_radius if clue_radius > 0.0 else radius):
			world.discover_clue(id)
			found += 1
	message.emit(Text.f("UI-18-04", counts) + ("" if found == 0 else " " + Text.f("UI-18-30", {"count": found})))
	if found > 0:
		girl_comment.emit(Text.t("UI-20-21"))


func _update_cutting(delta: float) -> void:
	var target := current_target()
	if target.is_empty() or not Input.is_physical_key_pressed(KEY_E):
		_cut_progress = 0.0
		_cut_target = ""
		return
	var key := "%s%s" % [target["kind"], str(target["id"])]
	if key != _cut_target:
		_cut_target = key
		_cut_progress = 0.0
	_cut_progress += delta
	if _cut_progress >= float(target["seconds"]):
		use_tool(target)
		_cut_progress = 0.0


func _update_prompt() -> void:
	var text := Text.f("UI-18-31", {"tool": Text.t(TOOL_KEYS[tool])})
	var target := current_target()
	if not target.is_empty():
		text += "  " + str(target["prompt"])
	elif tool == "cutter" and _near_big_ruin():
		text += "  " + Text.t("UI-18-06")
	if text != _last_prompt:
		_last_prompt = text
		prompt_changed.emit(text)


func _near_big_ruin() -> bool:
	var ahead := view.cell_at(position)
	for x in range(ahead.x - 1, ahead.x + 2):
		for z in range(ahead.y - 1, ahead.y + 2):
			var id := world.ruin_at(Vector2i(x, z))
			if not id.is_empty() and world.ruins[id]["kind"] == EarthWorld.RUIN_BIG:
				return true
	return false


func _flat_distance(point: Vector3) -> float:
	return Vector2(position.x, position.z).distance_to(Vector2(point.x, point.z))


func _build_visual() -> void:
	_visual = Node3D.new()
	_visual.rotation.y = 0.0  # 开局朝北，背对镜头
	add_child(_visual)
	var body := _box(BODY_SIZE, BODY_COLOR)
	body.position = Vector3.UP * BODY_SIZE.y / 2.0
	_visual.add_child(body)
	# 屏幕脸：一眼看出它朝哪边
	var screen := _box(Vector3(BODY_SIZE.x * 0.7, BODY_SIZE.y * 0.4, 0.1), SCREEN_COLOR)
	screen.position = Vector3(0.0, BODY_SIZE.y * 0.7, BODY_SIZE.z / 2.0 + 0.05)
	_visual.add_child(screen)


func _build_camera() -> void:
	_pivot = Node3D.new()
	_pivot.position = Vector3.UP * CAMERA_HEIGHT
	_pivot.rotation.y = PI  # 镜头在南边往北看，和俯视方向一致
	add_child(_pivot)
	_spring = SpringArm3D.new()
	_spring.spring_length = CAMERA_DISTANCE
	_spring.rotation_degrees.x = START_PITCH
	_spring.add_excluded_object(get_rid())
	_pivot.add_child(_spring)
	camera = Camera3D.new()
	_spring.add_child(camera)
	# 描边是"游戏滤镜"的一部分：一块贴满屏幕的片，只在第三人称显示
	_outline = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	var material := ShaderMaterial.new()
	material.shader = OUTLINE_SHADER
	quad.material = material
	_outline.mesh = quad
	_outline.extra_cull_margin = 16384.0
	_outline.visible = false
	camera.add_child(_outline)


func _box(size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material = material
	var node := MeshInstance3D.new()
	node.mesh = mesh
	return node
