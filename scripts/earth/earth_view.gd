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
const FILTER_BRIGHTNESS := 1.2
const FILTER_SATURATION := 1.5

var world: EarthWorld
var cell_size: float
var astar := AStarGrid2D.new()  # 机器人走路用：废墟和建筑都是障碍

var _ground: MultiMeshInstance3D
var _ruin_nodes := {}      # 废墟 id -> 节点
var _building_nodes := {}  # 建筑编号 -> { node, state }
var _scrap_nodes := {}     # 废料 id -> 节点
var _selection: MeshInstance3D
var _environment: Environment


func setup(earth_world: EarthWorld) -> void:
	world = earth_world
	cell_size = float(DataDB.balance("earth_cell_size"))
	_build_environment()
	_build_ground()
	_build_boundary()
	astar.region = Rect2i(0, 0, world.grid_size, world.grid_size)
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


func region_size() -> float:
	return world.grid_size * cell_size


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
	_update_astar()


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
	multimesh.instance_count = world.grid_size * world.grid_size
	for z in world.grid_size:
		for x in world.grid_size:
			var center := cell_center(Vector2i(x, z)) + Vector3.DOWN * 0.05
			multimesh.set_instance_transform(_cell_index(Vector2i(x, z)), Transform3D(Basis.IDENTITY, center))
	_ground = MultiMeshInstance3D.new()
	_ground.multimesh = multimesh
	add_child(_ground)

	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(region_size(), 1.0, region_size())
	shape.shape = box
	shape.position = Vector3(region_size() / 2.0, -0.5, region_size() / 2.0)
	body.add_child(shape)
	add_child(body)


## 四周的隐形墙，ARK-01 走不出这片区域
func _build_boundary() -> void:
	var size := region_size()
	var half := size / 2.0
	var walls: Array[Array] = [
		[Vector3(half, WALL_HEIGHT / 2.0, -WALL_THICKNESS / 2.0), Vector3(size, WALL_HEIGHT, WALL_THICKNESS)],
		[Vector3(half, WALL_HEIGHT / 2.0, size + WALL_THICKNESS / 2.0), Vector3(size, WALL_HEIGHT, WALL_THICKNESS)],
		[Vector3(-WALL_THICKNESS / 2.0, WALL_HEIGHT / 2.0, half), Vector3(WALL_THICKNESS, WALL_HEIGHT, size)],
		[Vector3(size + WALL_THICKNESS / 2.0, WALL_HEIGHT / 2.0, half), Vector3(WALL_THICKNESS, WALL_HEIGHT, size)],
	]
	for wall in walls:
		var body := _static_box(wall[1])
		body.position = wall[0]
		add_child(body)


func _update_ground() -> void:
	var multimesh := _ground.multimesh
	for z in world.grid_size:
		for x in world.grid_size:
			var cell := Vector2i(x, z)
			var color: Color = GROUND_COLORS[clampi(int(world.pollution.get(cell, 0)), 0, GROUND_COLORS.size() - 1)]
			if world.plants.has(cell):
				color = PLANT_COLOR
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
	return node


func _sync_scraps() -> void:
	var live := {}
	for scrap in world.scraps:
		live[scrap["id"]] = true
		if not _scrap_nodes.has(scrap["id"]):
			var node := _box_mesh(Vector3.ONE * SCRAP_SIZE, SCRAP_COLOR)
			node.position = cell_center(scrap["cell"]) + Vector3.UP * SCRAP_SIZE / 2.0
			add_child(node)
			_scrap_nodes[scrap["id"]] = node
	for id: String in _scrap_nodes.keys():
		if not live.has(id):
			_scrap_nodes[id].queue_free()
			_scrap_nodes.erase(id)


func _update_astar() -> void:
	for z in world.grid_size:
		for x in world.grid_size:
			var cell := Vector2i(x, z)
			astar.set_point_solid(cell, world.is_blocked(cell))


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
	return cell.y * world.grid_size + cell.x
