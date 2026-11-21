extends Node3D
## 连续污染地表由 ground.gdshader 绘制；本模块只管上层草海和特色植物。
## 噪声调整连续草层的高度与物种，不用随机空格制造秃斑。

const ROOT := "res://assets/models/vegetation/"
var view: EarthView
var noise := FastNoiseLite.new()
var signature := ""
var counts: Dictionary = {}
var _meshes: Dictionary = {}
var _groups: Dictionary = {}
var _near_wall: Dictionary = {}
var _near_road: Dictionary = {}
var _settings: Dictionary = {}
var _occupied: Dictionary = {}
var _road_rects: Array[Rect2] = []
var _wall_rects: Array[Rect2] = []

func setting(key: String) -> float:
	if not _settings.has(key): _settings[key] = float(DataDB.balance("earth_veg_"+key))
	return _settings[key]

func setup(owner_view: EarthView) -> void:
	view = owner_view
	noise.seed = int(setting("seed"))
	noise.frequency = setting("noise_frequency")
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	refresh()

func eligible(cell: Vector2i) -> bool:
	var world := view.world
	return world.in_bounds(cell) and world.region_of(cell)!=EarthWorld.RIVER and int(world.pollution.get(cell,0))>0 and not world.is_blocked(cell) and not view._road_cells.has(cell) and not world.plants.has(cell) and not world.holes.has(cell)

func refresh() -> void:
	# 只在影响覆盖的状态变化时重建；材料、周数变化不重复生成草海。
	var world := view.world
	var next := str(hash([world.pollution,world.ruins,world.buildings,world.plants,world.holes,world.props]))
	if next==signature: return
	signature=next
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_groups.clear()
	_near_wall.clear()
	_near_road.clear()
	_occupied.clear()
	_road_rects.clear()
	_wall_rects.clear()
	for row: Dictionary in DataDB.table("earth_roads").values():
		_road_rects.append(Rect2(float(row["x"])*view.cell_size,float(row["z"])*view.cell_size,float(row["w"])*view.cell_size,float(row["h"])*view.cell_size))
	for ruin: Dictionary in world.ruins.values():
		if not ruin["cleared"]: _wall_rects.append(Rect2(float(ruin["x"])*view.cell_size,float(ruin["z"])*view.cell_size,float(ruin["w"])*view.cell_size,float(ruin["h"])*view.cell_size))
	for id: String in world.props:
		if not world.prop_at(world.prop_rect(id).position,true).is_empty():
			var rect := world.prop_rect(id)
			_wall_rects.append(Rect2(Vector2(rect.position)*view.cell_size,Vector2(rect.size)*view.cell_size))
	counts={"a":0,"b":0,"c":0}
	for z in world.grid_height:
		for x in world.grid_width:
			var cell := Vector2i(x,z)
			if not eligible(cell): continue
			var wall := false
			var road := false
			for offset: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN,Vector2i(-1,-1),Vector2i(1,1),Vector2i(-1,1),Vector2i(1,-1)]:
				wall = wall or world.is_blocked(cell+offset)
				road = road or view._road_cells.has(cell+offset)
			_near_wall[cell]=wall
			_near_road[cell]=road
			_fill_cell(cell,world.region_of(cell))
	_attach_vines()
	_flush()

func _fill_cell(cell: Vector2i, region: String) -> void:
	var wall: bool = _near_wall[cell]
	var road: bool = _near_road[cell]
	# 候选点不再位于格内小网格；跨格共享最小间距，消除行列和方格边界。
	var attempts := ceili(view.cell_size*view.cell_size*setting("candidate_density"))
	for i in attempts:
		var key := Vector2i(cell.x*attempts+i,cell.y*attempts+i*7)
		var random := view._cell_hash(key,int(setting("seed")))
		var px := (cell.x+view._cell_hash(key,11))*view.cell_size
		var pz := (cell.y+view._cell_hash(key,13))*view.cell_size
		var p := Vector2(px,pz)
		var field := clampf(noise.get_noise_2d(px,pz)*setting("noise_contrast")+0.5,0,1)
		var detail := clampf(noise.get_noise_2d(px*setting("detail_frequency"),pz*setting("detail_frequency"))+0.5,0,1)
		var road_distance := _distance_to_rects(p,_road_rects)
		var wall_distance := _distance_to_rects(p,_wall_rects)
		var edge := smoothstep(0.0,setting("road_transition"),road_distance+noise.get_noise_2d(px*2,pz*2)*setting("edge_warp"))
		if region=="a":
			var crack := absf(sin(px*setting("crack_frequency")+noise.get_noise_2d(px,pz)*TAU))
			if not wall or crack>setting("crack_width") or random>setting("a_chance"): continue
		else:
			var density := lerpf(setting("density_low"),setting("density_high"),field)*lerpf(setting("edge_density"),1.0,edge)
			if random>density: continue
		if not _reserve(p): continue
		var height := lerpf(setting(region+"_height_min"),setting(region+"_height_max"),field*detail)
		height*=lerpf(setting("individual_min"),setting("individual_max"),view._cell_hash(key,19))
		height*=lerpf(setting("wall_height"),1.0,smoothstep(0.0,setting("wall_transition"),wall_distance))
		height*=lerpf(setting("road_height"),1.0,edge)
		var species := view._cell_hash(key,23)
		var kind := "finegrass"
		if species<setting("dry_ratio"): kind="dryshoots"
		elif species<setting("broad_ratio"):
			kind="broadgrass"
			height*=setting("understory_height")
		_add(kind,Vector3(px,setting("ground_y"),pz),height,view._cell_hash(key,29)*TAU,key)
		counts[region]+=1
	# 特色植物只在连续草海中的少数高密区域出现。
	if region=="a" or road: return
	var roll := view._cell_hash(cell,31)
	if roll>setting("feature_chance"): return
	var kind: String = ["bladder","crystal","parasol","giantleaf","moss"][int(view._cell_hash(cell,37)*5)]
	var height := setting(kind+"_height")
	var feature_pos := view.cell_center(cell)+Vector3(view._cell_hash(cell,47)-0.5,0,view._cell_hash(cell,53)-0.5)*view.cell_size
	feature_pos.y=setting("ground_y")
	_add(kind,feature_pos,height*lerpf(setting("individual_min"),setting("individual_max"),roll/setting("feature_chance")),roll*TAU,cell)

func _distance_to_rects(p: Vector2, rects: Array[Rect2]) -> float:
	var distance := INF
	for rect in rects:
		var nearest := p.clamp(rect.position,rect.end)
		distance=minf(distance,p.distance_to(nearest))
	return distance

func _reserve(p: Vector2) -> bool:
	var radius := setting("minimum_distance")
	var bucket := Vector2i(floori(p.x/radius),floori(p.y/radius))
	for z in range(-1,2):
		for x in range(-1,2):
			var key := bucket+Vector2i(x,z)
			for existing: Vector2 in _occupied.get(key,[]):
				if p.distance_to(existing)<radius: return false
	if not _occupied.has(bucket): _occupied[bucket]=[]
	_occupied[bucket].append(p)
	return true

func _attach_vines() -> void:
	for ruin: Dictionary in view.world.ruins.values():
		if ruin["cleared"] or ruin["kind"]!=EarthWorld.RUIN_BIG: continue
		var cell := Vector2i(int(ruin["x"]),int(ruin["z"])-1)
		if not eligible(cell) or view.world.region_of(cell)=="a": continue
		var pos := view.rect_center(int(ruin["x"]),int(ruin["z"]),int(ruin["w"]),int(ruin["h"]))
		pos.z = int(ruin["z"])*view.cell_size-setting("vine_offset")
		pos.y=setting("ground_y")
		_add("rustvine",pos,setting("rustvine_height"),0,cell)

func _add(kind: String, position_3d: Vector3, height: float, angle: float, seed_cell: Vector2i) -> void:
	var variants := setting("base_variants") if kind in ["finegrass","broadgrass","dryshoots"] else setting("variants")
	var variant := int(view._cell_hash(seed_cell,43)*variants)
	var asset := "%s/%s_%02d" % [kind,kind,variant]
	var parts := _load_parts(asset)
	if parts.is_empty(): return
	var native_height: float = _meshes[asset]["height"]
	var scale_value := height/maxf(native_height,0.01)
	var basis := Basis(Vector3.UP,angle)
	if kind in ["finegrass","broadgrass","dryshoots"]:
		var width := lerpf(setting("spread_min"),setting("spread_max"),view._cell_hash(seed_cell,59))
		basis=basis.scaled(Vector3(scale_value*width,scale_value,scale_value/width))
	else: basis=basis.scaled(Vector3.ONE*scale_value)
	var chunk := Vector2i(floori(position_3d.x/setting("chunk_meters")),floori(position_3d.z/setting("chunk_meters")))
	var batch_key := str(chunk)+asset
	if not _groups.has(batch_key): _groups[batch_key]={"asset":asset,"transforms":[],"grass":kind in ["finegrass","broadgrass","dryshoots"]}
	_groups[batch_key]["transforms"].append(Transform3D(basis,position_3d))

func _load_parts(asset: String) -> Array:
	if _meshes.has(asset): return _meshes[asset]["parts"]
	var scene := load(ROOT+asset+".glb") as PackedScene
	if scene==null: return []
	var node := scene.instantiate() as Node3D
	var parts: Array = []
	_collect(node,Transform3D.IDENTITY,parts,asset)
	var min_y := INF
	var max_y := -INF
	for part: Dictionary in parts:
		var bounds: AABB = part["transform"]*(part["mesh"] as Mesh).get_aabb()
		min_y=minf(min_y,bounds.position.y)
		max_y=maxf(max_y,bounds.end.y)
	_meshes[asset]={"parts":parts,"height":max_y-min_y}
	node.free()
	return parts

func _collect(node: Node, parent: Transform3D, parts: Array, asset: String) -> void:
	var transform := parent
	if node is Node3D: transform=parent*node.transform
	if node is MeshInstance3D:
		var mesh: Mesh = node.mesh.duplicate()
		for i in mesh.get_surface_count():
			var material := mesh.surface_get_material(i).duplicate() as StandardMaterial3D
			if material!=null:
				material.cull_mode=BaseMaterial3D.CULL_DISABLED
				if not material.resource_name.begins_with("Culm") and (asset.begins_with("finegrass") or asset.begins_with("broadgrass") or asset.begins_with("dryshoots")):
					material.albedo_color=Color(setting("grass_tint_r"),setting("grass_tint_g"),setting("grass_tint_b"))
					material.roughness=setting("roughness")
				mesh.surface_set_material(i,material)
		parts.append({"mesh":mesh,"transform":transform})
	for child in node.get_children(): _collect(child,transform,parts,asset)

func _flush() -> void:
	for group: Dictionary in _groups.values():
		for part: Dictionary in _meshes[group["asset"]]["parts"]:
			var batch := MultiMeshInstance3D.new()
			var mm := MultiMesh.new()
			mm.transform_format=MultiMesh.TRANSFORM_3D
			mm.mesh=part["mesh"]
			mm.instance_count=group["transforms"].size()
			for i in mm.instance_count: mm.set_instance_transform(i,group["transforms"][i]*part["transform"])
			batch.multimesh=mm
			batch.visibility_range_end=setting("grass_distance") if group["grass"] else setting("feature_distance")
			batch.visibility_range_end_margin=setting("distance_margin")
			batch.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if group["grass"] else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			add_child(batch)
