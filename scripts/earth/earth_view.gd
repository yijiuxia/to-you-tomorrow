class_name EarthView
extends Node3D
## 地球的 3D 画面：只根据 EarthWorld 画方块，不改任何规则。
## 第 5 步有模型后，把这里的方块换成模型就行，规则和操作都不用动。

const GROUND_COLORS: Array[Color] = [Color(0.56, 0.5, 0.36), Color(0.45, 0.42, 0.36), Color(0.33, 0.31, 0.3)]  # 无 / 轻度 / 重度污染
const PLANT_COLOR := Color(0.25, 0.62, 0.25)
const POWER_TINT := Color(0.35, 0.5, 0.9)
const WATER_TINT := Color(0.2, 0.75, 0.85)
const OVERLAY_STRENGTH := 0.28
const RUIN_BIG_COLOR := Color(0.32, 0.27, 0.24)
const RUIN_SMALL_COLOR := Color(0.65, 0.42, 0.25)
const SCRAP_COLOR := Color(0.95, 0.8, 0.25)
const BLUEPRINT_COLOR := Color(0.3, 0.6, 1.0, 0.45)
const SELECT_COLOR := Color(1.0, 0.95, 0.4)
const PROBLEM_COLOR := Color(0.85, 0.25, 0.2)
const BUILDING_COLORS := {
	"recycler": Color(0.55, 0.55, 0.6), "generator": Color(0.9, 0.7, 0.2), "purifier": Color(0.3, 0.7, 0.85),
	"repair_station": Color(0.75, 0.45, 0.25), "farm_plot": Color(0.45, 0.35, 0.2), "soil_improver": Color(0.6, 0.45, 0.7),
	"relay": Color(0.85, 0.85, 0.9), "power_node": Color(0.95, 0.85, 0.35), "water_pipe": Color(0.25, 0.55, 0.8),
}
const BUILDING_HEIGHTS := {
	"recycler": 2.0, "generator": 3.0, "purifier": 2.5, "repair_station": 3.5, "farm_plot": 0.3,
	"soil_improver": 1.5, "relay": 5.0, "power_node": 2.5, "water_pipe": 0.4,
}
const BIG_RUIN_HEIGHT := 2.2
const SMALL_RUIN_HEIGHT := 0.9
const SCRAP_SIZE := 0.5
const SELECT_HEIGHT := 0.05
const WALL_HEIGHT := 10.0
const WALL_THICKNESS := 2.0
const SUN_ROTATION := Vector3(-55.0, -30.0, 0.0)
const BACKGROUND_COLOR := Color(0.55, 0.57, 0.6)
const FILTER_BRIGHTNESS := 1.1
const FILTER_SATURATION := 1.5
const SLAB_COLOR := Color(0.22, 0.21, 0.2)
const SLAB_THICKNESS := 0.1
const WORKSHOP_COLOR := Color(0.42, 0.33, 0.28)
const WORKSHOP_HEIGHT := 2.8
const WORKSHOP_TYPE := "repair_station"
const LOCKED_TINT := Color(0.12, 0.12, 0.14)
const LOCKED_STRENGTH := 0.55
const RIVER_COLOR := Color(0.42, 0.35, 0.27)
const SEEDLING_COLOR := Color(0.55, 0.78, 0.4)
const HOLE_COLOR := Color(0.2, 0.15, 0.1)
const CLUE_COLOR := Color(0.3, 1.0, 0.95)
const CLUE_SIZE := Vector3(0.6, 0.15, 0.6)
const TERRAIN_WALL_HEIGHT := 12.0
## 剧情物件按"种类_状态"给颜色和高度；高度 0 表示这个状态不显示
const PROP_LOOKS := {
	"gate_closed": [Color(0.5, 0.3, 0.2), 4.0], "gate_open": [Color(0.5, 0.3, 0.2), 0.3],
	"old_power_broken": [Color(0.4, 0.35, 0.3), 2.0], "old_power_fixed": [Color(0.9, 0.75, 0.3), 2.2],
	"bridge_broken": [Color(0.45, 0.42, 0.4), 0.0], "bridge_temp": [Color(0.55, 0.4, 0.25), 0.3], "bridge_fixed": [Color(0.6, 0.6, 0.62), 0.6],
	"pile_high": [Color(0.55, 0.5, 0.45), 2.5], "pile_low": [Color(0.55, 0.5, 0.45), 1.0],
	"tank_full": [Color(0.3, 0.5, 0.7), 2.5], "tank_empty": [Color(0.45, 0.45, 0.48), 2.5],
	"greenhouse_broken": [Color(0.6, 0.8, 0.85, 0.35), 3.5], "greenhouse_half": [Color(0.6, 0.85, 0.85, 0.5), 3.5], "greenhouse_fixed": [Color(0.4, 0.8, 0.5, 0.5), 3.5],
	"underground_hidden": [Color.BLACK, 0.0], "underground_shown": [Color(0.15, 0.15, 0.15), 0.2],
}

## Lux3D 模型（assets/models/lux3d/）：建筑种类 -> 模型名；没有文件就继续用方块
const LUX3D_BUILDINGS := {
	"recycler": "recycler", "generator": "generator", "purifier": "purifier", "repair_station": "hangar",
	"farm_plot": "farm_plot", "soil_improver": "soil_improver", "relay": "relay",
}
## 剧情物件"种类_状态" -> 模型名
const LUX3D_PROPS := {
	"gate_closed": "gate", "old_power_broken": "old_power", "old_power_fixed": "old_power",
	"greenhouse_broken": "dome", "greenhouse_half": "dome", "greenhouse_fixed": "dome",
	"tank_full": "tank", "tank_empty": "tank", "bridge_fixed": "bridge_fixed", "bridge_temp": "bridge_temp",
}
## 远景：[模型, 东西位置(地图宽的倍数), 南北位置(地图长的倍数), 占地边长米, 朝向度]
const LUX3D_SCENERY := [
	["b01_power", -0.45, 0.42, 26.0, 90.0],
	["b03_factory", 1.45, 0.47, 26.0, -90.0],
	["shed", -0.4, 0.12, 22.0, 90.0],
]

var world: EarthWorld
var cell_size: float
var astar := AStarGrid2D.new()  # 机器人走路用：废墟和建筑都是障碍

var _ground: MultiMeshInstance3D
var _ruin_nodes := {}      # 废墟 id -> 节点
var _building_nodes := {}  # 建筑编号 -> { node, state }
var _scrap_nodes := {}     # 废料 id -> 节点
var _selection: MeshInstance3D
var _environment: Environment
var _workshop: Node3D  # 坏掉的旧车间：修好之前一直立在那里
var _prop_nodes := {}    # 物件 id -> { node, state }
var _clue_nodes := {}    # 线索 id -> 节点
var _terrain_walls: Node3D
var _terrain_key := ""   # 区域开放和桥的状态；变了才重建挡墙


func setup(earth_world: EarthWorld) -> void:
	world = earth_world
	cell_size = float(DataDB.balance("earth_cell_size"))
	_build_environment()
	_build_ground()
	_build_boundary()
	_build_scenery()
	astar.region = Rect2i(0, 0, world.grid_width, world.grid_height)
	astar.cell_size = Vector2.ONE
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	_selection = _box_mesh(Vector3.ONE, SELECT_COLOR)
	_selection.visible = false
	add_child(_selection)
	world.changed.connect(refresh)
	refresh()


func cell_center(cell: Vector2i) -> Vector3:
	return Vector3((cell.x + 0.5) * cell_size, 0.0, (cell.y + 0.5) * cell_size)


func rect_center(x: int, z: int, w: int, h: int) -> Vector3:
	return Vector3((x + w / 2.0) * cell_size, 0.0, (z + h / 2.0) * cell_size)


func cell_at(position_3d: Vector3) -> Vector2i:
	return Vector2i(floori(position_3d.x / cell_size), floori(position_3d.z / cell_size))


## 整张地图的大小（米）：x 是东西，y 是南北
func map_size() -> Vector2:
	return Vector2(world.grid_width, world.grid_height) * cell_size


## 第三人称才有的"游戏滤镜"：调亮、加饱和。俯视保持灰暗的真实颜色（比赛版 4.4）。
func set_game_filter(enabled: bool) -> void:
	_environment.adjustment_enabled = enabled
	_environment.adjustment_brightness = FILTER_BRIGHTNESS
	_environment.adjustment_saturation = FILTER_SATURATION


## 高亮选中的矩形；传 Rect2i() 表示不选中
func show_selection(rect: Rect2i) -> void:
	_selection.visible = rect.size != Vector2i.ZERO
	if _selection.visible:
		var center := rect_center(rect.position.x, rect.position.y, rect.size.x, rect.size.y)
		_selection.position = center + Vector3.UP * SELECT_HEIGHT
		_selection.scale = Vector3(rect.size.x * cell_size + cell_size * 0.2, SELECT_HEIGHT, rect.size.y * cell_size + cell_size * 0.2)


## 世界状态变了就同步画面
func refresh() -> void:
	_update_ground()
	_sync_ruins()
	_sync_buildings()
	_sync_scraps()
	_sync_props()
	_sync_clues()
	_update_terrain_walls()
	_update_astar()
	_workshop.visible = true
	for building: Dictionary in world.buildings.values():
		if building["type"] == WORKSHOP_TYPE:
			_workshop.visible = false


func _build_environment() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = SUN_ROTATION
	sun.shadow_enabled = true
	add_child(sun)
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_COLOR
	_environment.background_color = BACKGROUND_COLOR
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color.WHITE
	_environment.ambient_light_energy = 0.5
	var holder := WorldEnvironment.new()
	holder.environment = _environment
	add_child(holder)


## 地面用 MultiMesh：900 格一次画完，改颜色不用重建
func _build_ground() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(cell_size * 0.98, 0.1, cell_size * 0.98)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	mesh.material = material
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = world.grid_width * world.grid_height
	for z in world.grid_height:
		for x in world.grid_width:
			var center := cell_center(Vector2i(x, z)) + Vector3.DOWN * 0.05
			multimesh.set_instance_transform(_cell_index(Vector2i(x, z)), Transform3D(Basis.IDENTITY, center))
	_ground = MultiMeshInstance3D.new()
	_ground.multimesh = multimesh
	add_child(_ground)

	# 格子之间留了缝当网格线；缝下面垫一层，不然描边滤镜会把缝当成很深的沟
	var slab := _box_mesh(Vector3(map_size().x, SLAB_THICKNESS, map_size().y), SLAB_COLOR)
	slab.position = Vector3(map_size().x / 2.0, -0.05 - SLAB_THICKNESS, map_size().y / 2.0)
	add_child(slab)

	var row := DataDB.row("buildings", WORKSHOP_TYPE)
	var w := int(row["size_x"])
	var h := int(row["size_z"])
	_workshop = _box_mesh(Vector3(w * cell_size * 0.96, WORKSHOP_HEIGHT, h * cell_size * 0.96), WORKSHOP_COLOR)
	_workshop.position = rect_center(int(row["fixed_x"]), int(row["fixed_z"]), w, h) + Vector3.UP * WORKSHOP_HEIGHT / 2.0
	add_child(_workshop)
	var hangar := Lux3DModels.make("hangar", Vector2(w, h) * cell_size * 0.96)
	if hangar != null:
		(_workshop as MeshInstance3D).mesh = null
		hangar.position = Vector3.DOWN * WORKSHOP_HEIGHT / 2.0
		_workshop.add_child(hangar)

	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(map_size().x, 1.0, map_size().y)
	shape.shape = box
	shape.position = Vector3(map_size().x / 2.0, -0.5, map_size().y / 2.0)
	body.add_child(shape)
	add_child(body)


## 四周的隐形墙，ARK-01 走不出这片区域
func _build_boundary() -> void:
	var size := map_size()
	var walls: Array[Array] = [
		[Vector3(size.x / 2.0, WALL_HEIGHT / 2.0, -WALL_THICKNESS / 2.0), Vector3(size.x, WALL_HEIGHT, WALL_THICKNESS)],
		[Vector3(size.x / 2.0, WALL_HEIGHT / 2.0, size.y + WALL_THICKNESS / 2.0), Vector3(size.x, WALL_HEIGHT, WALL_THICKNESS)],
		[Vector3(-WALL_THICKNESS / 2.0, WALL_HEIGHT / 2.0, size.y / 2.0), Vector3(WALL_THICKNESS, WALL_HEIGHT, size.y)],
		[Vector3(size.x + WALL_THICKNESS / 2.0, WALL_HEIGHT / 2.0, size.y / 2.0), Vector3(WALL_THICKNESS, WALL_HEIGHT, size.y)],
	]
	for wall in walls:
		var body := _static_box(wall[1])
		body.position = wall[0]
		add_child(body)


func _update_ground() -> void:
	var multimesh := _ground.multimesh
	for z in world.grid_height:
		for x in world.grid_width:
			var cell := Vector2i(x, z)
			var region := world.region_of(cell)
			var color: Color = GROUND_COLORS[clampi(int(world.pollution.get(cell, 0)), 0, GROUND_COLORS.size() - 1)]
			if region == EarthWorld.RIVER:
				color = RIVER_COLOR
			if world.plants.has(cell):
				color = PLANT_COLOR if world.plant_grown(cell) else SEEDLING_COLOR
			elif world.holes.has(cell):
				color = HOLE_COLOR
			if not world.is_region_open(region):
				color = color.lerp(LOCKED_TINT, LOCKED_STRENGTH)
			if world.is_cell_wet(cell):
				color = color.lerp(WATER_TINT, OVERLAY_STRENGTH)
			elif world.is_cell_powered(cell):
				color = color.lerp(POWER_TINT, OVERLAY_STRENGTH)
			multimesh.set_instance_color(_cell_index(cell), color)


func _sync_ruins() -> void:
	for id: String in world.ruins:
		var ruin: Dictionary = world.ruins[id]
		if ruin["cleared"]:
			if _ruin_nodes.has(id):
				_ruin_nodes[id].queue_free()
				_ruin_nodes.erase(id)
		elif not _ruin_nodes.has(id):
			var big: bool = ruin["kind"] == EarthWorld.RUIN_BIG
			var height := BIG_RUIN_HEIGHT if big else SMALL_RUIN_HEIGHT
			var node := _solid_block(int(ruin["w"]), int(ruin["h"]), height, RUIN_BIG_COLOR if big else RUIN_SMALL_COLOR)
			node.position = rect_center(int(ruin["x"]), int(ruin["z"]), int(ruin["w"]), int(ruin["h"]))
			_swap_to_model(node, "ruin_big" if big else "ruin_small", int(ruin["w"]), int(ruin["h"]))
			add_child(node)
			_ruin_nodes[id] = node


func _sync_buildings() -> void:
	for uid: int in _building_nodes.keys():
		if not world.buildings.has(uid):
			_building_nodes[uid]["node"].queue_free()
			_building_nodes.erase(uid)
	for uid: int in world.buildings:
		var building: Dictionary = world.buildings[uid]
		var state := "%s%s" % [str(building["done"]), str(world.problems(uid).is_empty())]
		if _building_nodes.has(uid):
			if _building_nodes[uid]["state"] == state:
				continue
			_building_nodes[uid]["node"].queue_free()
		var node := _make_building(building, uid)
		add_child(node)
		_building_nodes[uid] = {"node": node, "state": state}


func _make_building(building: Dictionary, uid: int) -> Node3D:
	var color: Color = BUILDING_COLORS.get(building["type"], Color.WHITE)
	if not building["done"]:
		color = BLUEPRINT_COLOR
	elif not world.problems(uid).is_empty():
		color = color.lerp(PROBLEM_COLOR, 0.6)
	var node := _solid_block(int(building["w"]), int(building["h"]), BUILDING_HEIGHTS.get(building["type"], 2.0), color)
	node.position = rect_center(int(building["x"]), int(building["z"]), int(building["w"]), int(building["h"]))
	# 建好且正常运转时换成 Lux3D 模型；蓝图和出问题时还用方块，颜色提示更清楚
	if building["done"] and world.problems(uid).is_empty():
		_swap_to_model(node, LUX3D_BUILDINGS.get(building["type"], ""), int(building["w"]), int(building["h"]))
	return node


## 有模型就把方块藏起来、摆上模型；碰撞盒保留，机器人寻路不受影响
func _swap_to_model(node: Node3D, model_name: String, w: int, h: int) -> void:
	if model_name == "":
		return
	var model := Lux3DModels.make(model_name, Vector2(w, h) * cell_size * 0.96)
	if model == null:
		return
	for child in node.get_children():
		if child is MeshInstance3D:
			child.visible = false
	node.add_child(model)


## 地图外面的远景建筑：B 区的发电厂、厂房，A 区的分拣棚（只看不进）
func _build_scenery() -> void:
	var size := map_size()
	for item: Array in LUX3D_SCENERY:
		var model := Lux3DModels.make(item[0], Vector2(item[3], item[3]))
		if model == null:
			continue
		model.position = Vector3(item[1] * size.x, 0.0, item[2] * size.y)
		model.rotation_degrees.y = item[4]
		add_child(model)


func _sync_scraps() -> void:
	var live := {}
	for scrap in world.scraps:
		live[scrap["id"]] = true
		if not _scrap_nodes.has(scrap["id"]):
			var node := _box_mesh(Vector3.ONE * SCRAP_SIZE, SCRAP_COLOR)
			node.position = cell_center(scrap["cell"]) + Vector3.UP * SCRAP_SIZE / 2.0
			var model := Lux3DModels.make("scrap", Vector2.ONE * SCRAP_SIZE * 2.0)
			if model != null:
				node.mesh = null
				model.position = Vector3.DOWN * SCRAP_SIZE / 2.0
				node.add_child(model)
			add_child(node)
			_scrap_nodes[scrap["id"]] = node
	for id: String in _scrap_nodes.keys():
		if not live.has(id):
			_scrap_nodes[id].queue_free()
			_scrap_nodes.erase(id)


func _update_astar() -> void:
	for z in world.grid_height:
		for x in world.grid_width:
			var cell := Vector2i(x, z)
			astar.set_point_solid(cell, not world.is_walkable(cell))


func _sync_props() -> void:
	for id: String in world.props:
		var row := DataDB.row("earth_props", id)
		var look_key := "%s_%s" % [row["kind"], world.props[id]]
		if _prop_nodes.has(id):
			if _prop_nodes[id]["state"] == look_key:
				continue
			_prop_nodes[id]["node"].queue_free()
			_prop_nodes.erase(id)
		var look: Array = PROP_LOOKS.get(look_key, [Color.MAGENTA, 1.0])
		var rect := world.prop_rect(id)
		var node := Node3D.new()
		var model := Lux3DModels.make(LUX3D_PROPS.get(look_key, ""), Vector2(rect.size) * cell_size * 0.96) if LUX3D_PROPS.has(look_key) else null
		if model != null:
			node.add_child(model)
		elif float(look[1]) > 0.0:
			var mesh := _box_mesh(Vector3(rect.size.x * cell_size * 0.96, float(look[1]), rect.size.y * cell_size * 0.96), look[0])
			mesh.position = Vector3.UP * float(look[1]) / 2.0
			node.add_child(mesh)
		node.position = rect_center(rect.position.x, rect.position.y, rect.size.x, rect.size.y)
		add_child(node)
		_prop_nodes[id] = {"node": node, "state": look_key}


## 线索：俯视看到地上的标记，第三人称看到发光路标（美术清单），这里先用同一个发光方块
func _sync_clues() -> void:
	var live := {}
	for id in world.active_clues():
		if not GirlEarth.reveals_clues():
			continue
		live[id] = true
		if not _clue_nodes.has(id):
			var node := _box_mesh(CLUE_SIZE, CLUE_COLOR)
			var material: StandardMaterial3D = node.mesh.material
			material.emission_enabled = true
			material.emission = CLUE_COLOR
			node.position = cell_center(world.clue_cell(id)) + Vector3.UP * CLUE_SIZE.y / 2.0
			add_child(node)
			_clue_nodes[id] = node
	for id: String in _clue_nodes.keys():
		if not live.has(id):
			_clue_nodes[id].queue_free()
			_clue_nodes.erase(id)


## 没开放的区域和干河道立隐形墙，ARK-01 过不去；桥能过时在桥那段留口子
func _update_terrain_walls() -> void:
	var key := ""
	for id: String in DataDB.table("earth_regions"):
		key += "%s%s" % [id, str(world.is_region_open(id))]
	key += str(world.props.get(EarthWorld.BRIDGE, ""))
	if key == _terrain_key:
		return
	_terrain_key = key
	if _terrain_walls != null:
		_terrain_walls.queue_free()
	_terrain_walls = Node3D.new()
	add_child(_terrain_walls)
	var bridge := world.prop_rect(EarthWorld.BRIDGE)
	var bridge_open: bool = world.props[EarthWorld.BRIDGE] != "broken"
	for id: String in DataDB.table("earth_regions"):
		var row := DataDB.row("earth_regions", id)
		var z_from := int(row["z_from"])
		var depth := int(row["z_to"]) - z_from + 1
		if not world.is_region_open(id):
			_add_wall(0, z_from, world.grid_width, depth)
		elif id == EarthWorld.RIVER:
			if bridge_open:
				_add_wall(0, z_from, bridge.position.x, depth)
				_add_wall(bridge.end.x, z_from, world.grid_width - bridge.end.x, depth)
			else:
				_add_wall(0, z_from, world.grid_width, depth)


func _add_wall(x: int, z: int, w: int, h: int) -> void:
	if w <= 0 or h <= 0:
		return
	var body := _static_box(Vector3(w * cell_size, TERRAIN_WALL_HEIGHT, h * cell_size))
	body.position = rect_center(x, z, w, h) + Vector3.UP * TERRAIN_WALL_HEIGHT / 2.0
	_terrain_walls.add_child(body)


## 带碰撞的方块，脚底在 y=0
func _solid_block(w: int, h: int, height: float, color: Color) -> Node3D:
	var size := Vector3(w * cell_size * 0.96, height, h * cell_size * 0.96)
	var body := _static_box(size)
	body.get_child(0).position = Vector3.UP * height / 2.0
	var mesh := _box_mesh(size, color)
	mesh.position = Vector3.UP * height / 2.0
	body.add_child(mesh)
	return body


func _static_box(size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	return body


func _box_mesh(size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = material
	var node := MeshInstance3D.new()
	node.mesh = mesh
	return node


func _cell_index(cell: Vector2i) -> int:
	return cell.y * world.grid_width + cell.x
