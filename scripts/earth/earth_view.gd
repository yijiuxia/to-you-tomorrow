class_name EarthView
extends Node3D
## 地球的 3D 画面：只根据 EarthWorld 画方块，不改任何规则。
## 第 5 步有模型后，把这里的方块换成模型就行，规则和操作都不用动。

const GROUND_COLORS: Array[Color] = [Color(0.56, 0.5, 0.36), Color(0.45, 0.42, 0.36), Color(0.33, 0.31, 0.3)]  # 无 / 轻度 / 重度污染
const GROUND_SHADER := preload("res://scripts/earth/ground.gdshader")
const GROUND_TEXTURES := {
	"tex_polluted": "res://assets/textures/earth/m_ground_polluted.png", "tex_cleared": "res://assets/textures/earth/m_ground_cleared.png",
	"tex_grass": "res://assets/textures/earth/m_ground_grass.png", "tex_soil": "res://assets/textures/earth/m_soil.png",
	"tex_road": "res://assets/textures/earth/m_asphalt_dirty.png",
}
## 地面种类，和 ground.gdshader 里的编号一致
const GROUND_POLLUTED := 0
const GROUND_LIGHT := 1
const GROUND_CLEARED := 2
const GROUND_GRASS := 3
const GROUND_SOIL := 4
const GROUND_ROAD := 5
const GROUND_CROSSWALK := 6
const ROAD_KINDS := {"road": GROUND_ROAD, "crosswalk": GROUND_CROSSWALK}
const SEEDLING_TINT := Color(1.15, 1.2, 0.9)
const HOLE_TINT := Color(0.45, 0.4, 0.35)
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
const TIME_DAY := "day"
const TIME_EVENING := "evening"
const TIME_NIGHT := "night"
const GRID_GAP_TOP := 0.02            # 俯视时格子之间留 2% 的缝当网格线
const GRID_GAP_THIRD_PERSON := 0.0     # 第三人称不留缝
const WEED_MODEL := "toxic_weeds"
const SHRUB_MODEL := "toxic_shrub"
const WEED_CHANCE := 0.07    # 重度污染格子里有多少长毒草
const SHRUB_CHANCE := 0.025  # 多少长毒灌木
const WEED_SIZE := 1.6
const SHRUB_SIZE := 2.2
const OUTER_GROUND_SIZE := 900.0
const OUTER_GROUND_Y := -0.25
const SKY_CURVE := 0.06  # 越小，天顶颜色离地平线越近，天空渐变越明显
const RIVER_TINT := Color(0.62, 0.6, 0.56)  # 河道泥土贴图偏红，压成灰褐色
const FOG_DENSITY := 0.0012
const SKY_PRESETS := {
	"day": {"top": Color(0.33, 0.55, 0.85), "horizon": Color(0.75, 0.8, 0.85), "ground": Color(0.35, 0.33, 0.3),
		"sun_rotation": Vector3(-55.0, -30.0, 0.0), "sun_color": Color(1.0, 0.97, 0.9), "sun_energy": 1.0, "ambient": Color.WHITE},
	"evening": {"top": Color(0.22, 0.26, 0.48), "horizon": Color(0.93, 0.68, 0.5), "ground": Color(0.3, 0.25, 0.22),
		"sun_rotation": Vector3(-12.0, -70.0, 0.0), "sun_color": Color(1.0, 0.75, 0.55), "sun_energy": 0.75, "ambient": Color(0.95, 0.85, 0.8)},
	"night": {"top": Color(0.03, 0.04, 0.1), "horizon": Color(0.12, 0.14, 0.24), "ground": Color(0.05, 0.05, 0.06),
		"sun_rotation": Vector3(-40.0, 150.0, 0.0), "sun_color": Color(0.6, 0.7, 1.0), "sun_energy": 0.25, "ambient": Color(0.45, 0.5, 0.75)},
}
const BACKGROUND_COLOR := Color(0.55, 0.57, 0.6)
const FILTER_BRIGHTNESS := 1.1
const FILTER_SATURATION := 1.5
const SLAB_COLOR := Color(0.22, 0.21, 0.2)
const SLAB_THICKNESS := 0.1
const WORKSHOP_COLOR := Color(0.42, 0.33, 0.28)
const WORKSHOP_HEIGHT := 2.8
const WORKSHOP_TYPE := "repair_station"
const HANGAR_SCALE := 2.2  # 维修站机库画得比 3×2 格大，参考图 A1 里它是主角
const DOME_SCALE := 1.5
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
	"landmark_power_ruined": [RUIN_BIG_COLOR, 6.0], "landmark_power_repaired": [Color(0.6, 0.6, 0.62), 6.0],
	"landmark_tank_ruined": [RUIN_BIG_COLOR, 6.0], "landmark_tank_repaired": [Color(0.8, 0.8, 0.8), 6.0],
	"landmark_factory_ruined": [RUIN_BIG_COLOR, 5.0], "landmark_factory_repaired": [Color(0.7, 0.65, 0.6), 5.0],
	"landmark_shed_ruined": [RUIN_BIG_COLOR, 5.0], "landmark_shed_repaired": [Color(0.6, 0.6, 0.62), 5.0],
	"landmark_purifier_ruined": [RUIN_BIG_COLOR, 4.0], "landmark_purifier_repaired": [Color(0.75, 0.8, 0.85), 4.0],
}

## Lux3D 模型（assets/models/lux3d/）：建筑种类 -> 模型名；没有文件就继续用方块
const LUX3D_BUILDINGS := {
	"recycler": "recycler", "generator": "generator", "purifier": "purifier", "repair_station": "hangar",
	"farm_plot": "farm_plot", "soil_improver": "soil_improver", "relay": "relay",
}
## 剧情物件"种类_状态" -> 模型名
const LUX3D_PROPS := {
	"gate_closed": "gate", "old_power_broken": "old_power", "old_power_fixed": "old_power",
	"greenhouse_broken": "dome_ruin", "greenhouse_half": "dome_ruin", "greenhouse_fixed": "dome",
	"landmark_power_ruined": "b01_ruin", "landmark_power_repaired": "b01_power",
	"landmark_tank_ruined": "tank_ruin", "landmark_tank_repaired": "tank",
	"landmark_factory_ruined": "b03_ruin", "landmark_factory_repaired": "b03_factory",
	"landmark_shed_ruined": "shed_ruin", "landmark_shed_repaired": "shed",
	"landmark_purifier_ruined": "purifier_ruin", "landmark_purifier_repaired": "purifier",
	"tank_full": "tank", "tank_empty": "tank", "pile_high": "tarp", "pile_low": "parts", "bridge_fixed": "bridge_fixed", "bridge_temp": "bridge_temp",
}
## 线索种类 -> 模型（脚印、信号还用发光块）
const LUX3D_CLUES := {"hole": "hole", "item": "seed_capsule"}
## 远景：[模型, 东西位置(地图宽的倍数), 南北位置(地图长的倍数), 占地边长米, 朝向度]
const LUX3D_SCENERY := [
	["landing_pod", 1.12, 0.08, 6.0, 20.0],
	# 新布局（照参考图 A5/B1）：东边高架路、北面和西面残楼天际线（渡槽模型带了一大块地面，效果不好先不放）
	["viaduct", 1.35, 0.15, 40.0, 90.0],
	["ruin_big", -0.6, 0.3, 24.0, 90.0],
	["ruin_big", -0.65, 0.6, 28.0, 80.0],
	["ruin_big", -0.55, 0.9, 22.0, 100.0],
	["ruin_big", 0.2, 1.12, 26.0, 180.0],
	["ruin_big", 0.75, 1.15, 30.0, 170.0],
	["ruin_small", 1.6, 0.5, 20.0, -90.0],
]

var world: EarthWorld
var cell_size: float
var astar := AStarGrid2D.new()  # 机器人走路用：废墟和建筑都是障碍

var _ground: MultiMeshInstance3D
var _ground_textured := false
var _ground_cell_mesh: BoxMesh
var _road_cells := {}  # 格子 -> 地面种类（柏油路 / 斑马线），来自 earth_roads.csv
var _ruin_nodes := {}      # 废墟 id -> 节点
var _building_nodes := {}  # 建筑编号 -> { node, state }
var _scrap_nodes := {}     # 废料 id -> 节点
var _selection: MeshInstance3D
var _environment: Environment
var _sun: DirectionalLight3D
var _sky_material: ProceduralSkyMaterial
var _workshop: Node3D  # 坏掉的旧车间：修好之前一直立在那里
var _prop_nodes := {}    # 物件 id -> { node, state }
var _clue_nodes := {}
var _hole_nodes := {}
var _weed_nodes := {}     # 格子 -> 毒草/毒灌木模型     # 格子 -> 坑的模型    # 线索 id -> 节点
var _terrain_walls: Node3D
var _terrain_key := ""   # 区域开放和桥的状态；变了才重建挡墙


func setup(earth_world: EarthWorld) -> void:
	world = earth_world
	cell_size = float(DataDB.balance("earth_cell_size"))
	_build_environment()
	_build_ground()
	_build_boundary()
	_build_scenery()
	_build_roads()
	_build_decor()
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
	# 第三人称不画格子线：格子铺满不留缝；俯视建造时留缝当网格线（yi 定）
	var gap := GRID_GAP_THIRD_PERSON if enabled else GRID_GAP_TOP
	_ground_cell_mesh.size = Vector3(cell_size * (1.0 - gap), _ground_cell_mesh.size.y, cell_size * (1.0 - gap))
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
	set_time_of_day(sky_for_week(GameState.week))  # 小镇画面跨周不重建时，天空也跟着换
	_update_ground()
	_sync_ruins()
	_sync_buildings()
	_sync_scraps()
	_sync_props()
	_sync_clues()
	_sync_holes()
	_sync_weeds()
	_update_terrain_walls()
	_update_astar()
	_workshop.visible = true
	for building: Dictionary in world.buildings.values():
		if building["type"] == WORKSHOP_TYPE:
			_workshop.visible = false


func _build_environment() -> void:
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = SUN_ROTATION
	_sun.shadow_enabled = true
	add_child(_sun)
	_environment = Environment.new()
	_sky_material = ProceduralSkyMaterial.new()
	_sky_material.sky_curve = SKY_CURVE
	var sky := Sky.new()
	sky.sky_material = _sky_material
	_environment.background_mode = Environment.BG_SKY
	_environment.sky = sky
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color.WHITE
	_environment.ambient_light_energy = 0.5
	# 远处起一点雾，地图外的残楼才有远近层次（参考图 B1、C1）
	_environment.fog_enabled = true
	_environment.fog_density = FOG_DENSITY
	var holder := WorldEnvironment.new()
	holder.environment = _environment
	add_child(holder)
	set_time_of_day(sky_for_week(GameState.week))


## 第几周用哪种天空（yi 定：只按周换），表在 balance.csv 的 earth_sky_by_week
static func sky_for_week(week: int) -> String:
	var list := str(DataDB.balance("earth_sky_by_week", TIME_DAY)).split("|")
	return list[clampi(week - 1, 0, list.size() - 1)].strip_edges()


## 天空三种：白天 / 傍晚 / 夜里。颜色、太阳角度和亮度都在 SKY_PRESETS 里
func set_time_of_day(mode: String) -> void:
	var preset: Dictionary = SKY_PRESETS.get(mode, SKY_PRESETS[TIME_DAY])
	_sky_material.sky_top_color = preset["top"]
	_sky_material.sky_horizon_color = preset["horizon"]
	_sky_material.ground_horizon_color = preset["horizon"]
	_sky_material.ground_bottom_color = preset["ground"]
	_sun.rotation_degrees = preset["sun_rotation"]
	_sun.light_color = preset["sun_color"]
	_sun.light_energy = preset["sun_energy"]
	_environment.ambient_light_color = preset["ambient"]
	# 雾用天顶和地平线中间的颜色，傍晚不会整片发橙
	_environment.fog_light_color = (preset["horizon"] as Color).lerp(preset["top"], 0.5)


## 地面用 MultiMesh：900 格一次画完，改颜色不用重建
func _build_ground() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(cell_size * (1.0 - GRID_GAP_TOP), 0.1, cell_size * (1.0 - GRID_GAP_TOP))
	mesh.material = _ground_material()
	_ground_cell_mesh = mesh
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.mesh = mesh
	multimesh.instance_count = world.grid_width * world.grid_height
	for z in world.grid_height:
		for x in world.grid_width:
			var center := cell_center(Vector2i(x, z)) + Vector3.DOWN * 0.05
			multimesh.set_instance_transform(_cell_index(Vector2i(x, z)), Transform3D(Basis.IDENTITY, center))
	_ground = MultiMeshInstance3D.new()
	_ground.multimesh = multimesh
	add_child(_ground)

	# 地图外的荒地：一大片重度污染地面，远景楼才不是飘在天上
	var outer := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * OUTER_GROUND_SIZE
	plane.material = mesh.material.duplicate() if _ground_textured else _box_mesh(Vector3.ONE, SLAB_COLOR).mesh.material
	outer.mesh = plane
	outer.position = Vector3(map_size().x / 2.0, OUTER_GROUND_Y, map_size().y / 2.0)
	# 外圈不是 MultiMesh，没有 INSTANCE_CUSTOM，着色器读到 0，整片按"重度污染"画
	add_child(outer)

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
	# 开局是破机库（A6 演变图第一张），修好维修站后换成新机库；模型比格子大一圈，碰撞还是按格子
	var hangar := Lux3DModels.make("hangar_ruin", Vector2(w, h) * cell_size * HANGAR_SCALE)
	if hangar == null:
		hangar = Lux3DModels.make("hangar", Vector2(w, h) * cell_size * HANGAR_SCALE)
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


## 地面有贴图就用贴图（按污染程度、草、河道换），贴图缺了退回纯色
func _ground_material() -> Material:
	var shader_material := ShaderMaterial.new()
	shader_material.shader = GROUND_SHADER
	for key: String in GROUND_TEXTURES:
		var path: String = GROUND_TEXTURES[key]
		if not ResourceLoader.exists(path):
			var plain := StandardMaterial3D.new()
			plain.vertex_color_use_as_albedo = true
			_ground_textured = false
			return plain
		shader_material.set_shader_parameter(key, load(path))
	_ground_textured = true
	return shader_material


func _update_ground() -> void:
	var multimesh := _ground.multimesh
	for z in world.grid_height:
		for x in world.grid_width:
			var cell := Vector2i(x, z)
			var region := world.region_of(cell)
			var level := clampi(int(world.pollution.get(cell, 0)), 0, GROUND_COLORS.size() - 1)
			var color: Color = GROUND_COLORS[level]
			var kind: int = [GROUND_CLEARED, GROUND_LIGHT, GROUND_POLLUTED][level]
			if region == EarthWorld.RIVER:
				color = RIVER_COLOR
				kind = GROUND_SOIL
			if world.plants.has(cell):
				color = PLANT_COLOR if world.plant_grown(cell) else SEEDLING_COLOR
				kind = GROUND_GRASS
			elif world.holes.has(cell):
				color = HOLE_COLOR
				kind = GROUND_SOIL
			if _road_cells.has(cell) and not world.plants.has(cell) and region != EarthWorld.RIVER:
				kind = _road_cells[cell]
			if _ground_textured:
				# 贴图自己带颜色，这里只留"苗比草浅、坑比泥深"的一点区别，叠加色照旧
				color = Color.WHITE
				if world.plants.has(cell) and not world.plant_grown(cell):
					color = SEEDLING_TINT
				elif world.holes.has(cell):
					color = HOLE_TINT
				elif region == EarthWorld.RIVER:
					color = RIVER_TINT
			multimesh.set_instance_custom_data(_cell_index(cell), Color(kind, 0, 0, 0))
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
			# 默认：大废墟是碎石堆、小废墟是废料；表里 model 列可以指定（如塌了一半的旧房子用 ruin_big）
			var model_name := str(DataDB.row("earth_ruins", id).get("model", ""))
			if model_name.is_empty():
				model_name = "rubble" if big else "scrap"
			if not ResourceLoader.exists(Lux3DModels.DIR + model_name + ".glb"):
				model_name = "ruin_small" if big else "scrap"
			_swap_to_model(node, model_name, int(ruin["w"]), int(ruin["h"]))
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
		var grow: float = HANGAR_SCALE if building["type"] == WORKSHOP_TYPE else 0.96
		_swap_to_model(node, LUX3D_BUILDINGS.get(building["type"], ""), int(building["w"]), int(building["h"]), grow)
	return node


## 有模型就把方块藏起来、摆上模型；碰撞盒保留，机器人寻路不受影响
func _swap_to_model(node: Node3D, model_name: String, w: int, h: int, grow := 0.96) -> void:
	if model_name == "":
		return
	var model := Lux3DModels.make(model_name, Vector2(w, h) * cell_size * grow)
	if model == null:
		return
	for child in node.get_children():
		if child is MeshInstance3D:
			child.visible = false
	node.add_child(model)


## 路只是画面：记下哪些格子画成柏油路或斑马线，地面刷新时用
func _build_roads() -> void:
	for id: String in DataDB.table("earth_roads"):
		var row := DataDB.row("earth_roads", id)
		var kind: int = ROAD_KINDS.get(str(row["kind"]), GROUND_ROAD)
		for z in range(int(row["z"]), int(row["z"]) + int(row["h"])):
			for x in range(int(row["x"]), int(row["x"]) + int(row["w"])):
				_road_cells[Vector2i(x, z)] = kind


## 小镇摆件（路灯、警示锥、帐篷、吊车……）：只是画面，没有碰撞，位置在 earth_decor.csv
func _build_decor() -> void:
	for id: String in DataDB.table("earth_decor"):
		var row := DataDB.row("earth_decor", id)
		var model := Lux3DModels.make_spec(str(row["model"]), float(row["size"]))
		if model == null:
			continue
		model.position = Vector3(float(row["x"]) * cell_size, 0.0, float(row["z"]) * cell_size)
		model.rotation_degrees.y = float(row["rot"])
		add_child(model)


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
		# 温室穹顶画得比 5×5 格大一圈（参考图 C1 里它是 C 区的主角），碰撞还是按格子
		var grow: float = DOME_SCALE if str(row["kind"]) == "greenhouse" else 0.96
		var model := Lux3DModels.make(LUX3D_PROPS.get(look_key, ""), Vector2(rect.size) * cell_size * grow) if LUX3D_PROPS.has(look_key) else null
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
## 重度污染的地上零星长着毒草（暗紫、灰褐，世界观：只有她种的才是真绿）。
## 哪些格子长按格子坐标算，每次都一样；污染降下去、建了东西、种了植物，毒草就消失。
func _sync_weeds() -> void:
	for z in world.grid_height:
		for x in world.grid_width:
			var cell := Vector2i(x, z)
			var want := _weed_for(cell)
			if want.is_empty():
				if _weed_nodes.has(cell):
					_weed_nodes[cell].queue_free()
					_weed_nodes.erase(cell)
				continue
			if _weed_nodes.has(cell):
				continue
			var model := Lux3DModels.make_spec("lux3d:" + want, WEED_SIZE if want == WEED_MODEL else SHRUB_SIZE)
			if model == null:
				return
			var jitter := _cell_hash(cell, 7)
			model.position = cell_center(cell) + Vector3(jitter - 0.5, 0.0, _cell_hash(cell, 13) - 0.5) * cell_size * 0.5
			model.rotation_degrees.y = jitter * 360.0
			add_child(model)
			_weed_nodes[cell] = model


func _weed_for(cell: Vector2i) -> String:
	if int(world.pollution.get(cell, 0)) < 2 or world.is_blocked(cell) or _road_cells.has(cell):
		return ""
	if world.plants.has(cell) or world.holes.has(cell) or world.region_of(cell) == EarthWorld.RIVER:
		return ""
	var roll := _cell_hash(cell, 1)
	if roll < SHRUB_CHANCE:
		return SHRUB_MODEL
	if roll < SHRUB_CHANCE + WEED_CHANCE:
		return WEED_MODEL
	return ""


## 按格子坐标算一个 0～1 的固定"随机数"，同一格每次都一样
func _cell_hash(cell: Vector2i, salt: int) -> float:
	var h := absi(hash(Vector3i(cell.x, cell.y, salt)))
	return float(h % 10000) / 10000.0


## 苗被挖走留下的坑：地面变深色之外再摆一个坑的模型
func _sync_holes() -> void:
	for cell: Vector2i in world.holes:
		if _hole_nodes.has(cell):
			continue
		var model := Lux3DModels.make("hole", Vector2.ONE * cell_size * 0.9)
		if model == null:
			return
		model.position = cell_center(cell)
		add_child(model)
		_hole_nodes[cell] = model
	for cell: Vector2i in _hole_nodes.keys():
		if not world.holes.has(cell):
			_hole_nodes[cell].queue_free()
			_hole_nodes.erase(cell)


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
			# 被挖的坑、种子罐这类线索换成 Lux3D 模型，发光块压扁成脚下的光圈，还能一眼看到
			var kind := str(DataDB.row("earth_clues", id).get("kind", ""))
			var model := Lux3DModels.make(LUX3D_CLUES.get(kind, ""), Vector2.ONE * cell_size * 0.8) if LUX3D_CLUES.has(kind) else null
			if model != null:
				node.scale = Vector3(1.6, 0.25, 1.6)
				var holder := Node3D.new()
				holder.scale = Vector3(1.0 / 1.6, 4.0, 1.0 / 1.6)
				holder.position = Vector3.DOWN * CLUE_SIZE.y / 2.0
				holder.add_child(model)
				node.add_child(holder)
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
