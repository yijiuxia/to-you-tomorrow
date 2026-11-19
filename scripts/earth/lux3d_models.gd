class_name Lux3DModels
extends RefCounted
## Lux3D 生成的模型（assets/models/lux3d/名字.glb）。
## 有模型就按占地大小缩放后摆上；没有就返回 null，调用方继续用方块。

const DIR := "res://assets/models/lux3d/"
const KIT_DIR := "res://assets/models/decor/"  # 场景建模线程 kit 里挑出来用的小摆件（kit 文件夹不进仓库）

static var _cache := {}


## 返回一个底面贴地、居中、占地不超过 footprint（x 东西、y 南北，米）的模型节点
static func make(model_name: String, footprint: Vector2, max_height := 0.0) -> Node3D:
	var path := DIR + model_name + ".glb"
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	var scene: PackedScene = _cache[path]
	if scene == null:
		return null
	return _fit(scene.instantiate() as Node3D, footprint, max_height)


static func _fit(model: Node3D, footprint: Vector2, max_height: float) -> Node3D:
	var box := _bounds(model, Transform3D.IDENTITY)
	if box.size.x <= 0.0 or box.size.z <= 0.0:
		return null
	# 模型长边和占地长边方向不一致时转 90 度，免得长条建筑被压成小块
	var turn := (box.size.x >= box.size.z) != (footprint.x >= footprint.y) and absf(footprint.x - footprint.y) > 0.01
	var size_x := box.size.z if turn else box.size.x
	var size_z := box.size.x if turn else box.size.z
	var s := minf(footprint.x / size_x, footprint.y / size_z)
	if max_height > 0.0 and box.size.y * s > max_height:
		s = max_height / box.size.y
	var holder := Node3D.new()
	var pivot := Node3D.new()
	holder.add_child(pivot)
	pivot.add_child(model)
	if turn:
		pivot.rotation_degrees.y = 90.0
	model.scale = Vector3.ONE * s
	var center := box.get_center()
	model.position = Vector3(-center.x * s, -box.position.y * s, -center.z * s)
	return holder


static func _bounds(node: Node, parent_xform: Transform3D) -> AABB:
	var xform := parent_xform
	if node is Node3D:
		xform = parent_xform * (node as Node3D).transform
	var result := AABB()
	var has := false
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		result = xform * (node as MeshInstance3D).mesh.get_aabb()
		has = true
	for child in node.get_children():
		var sub := _bounds(child, xform)
		if sub.size == Vector3.ZERO:
			continue
		result = sub if not has else result.merge(sub)
		has = true
	return result


## 摆件用：spec 是 "lux3d:名字" 或 "kit:名字"；size 是最长边几米，0 表示用模型原尺寸
static func make_spec(spec: String, size: float) -> Node3D:
	var parts := spec.split(":")
	if parts.size() != 2:
		return null
	var path: String = KIT_DIR + parts[1] + ".glb" if parts[0] == "kit" else DIR + parts[1] + ".glb"
	if not ResourceLoader.exists(path):
		return null
	if not _cache.has(path):
		_cache[path] = load(path)
	var model := (_cache[path] as PackedScene).instantiate() as Node3D
	var holder := Node3D.new()
	holder.add_child(model)
	var box := _bounds(model, Transform3D.IDENTITY)
	var longest := maxf(box.size.x, maxf(box.size.y, box.size.z))
	# 摆件按"三个方向里最长的一边"缩放：路灯是高、管材堆是长，都能对上真实尺寸
	var s := size / longest if size > 0.0 and longest > 0.0 else 1.0
	var center := box.get_center()
	model.scale *= s
	model.position = Vector3(-center.x * s, -box.position.y * s, -center.z * s)
	return holder


static func make_path(path: String, footprint: Vector2) -> Node3D:
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	var scene: PackedScene = _cache[path]
	if scene == null:
		return null
	return _fit(scene.instantiate() as Node3D, footprint, 0.0)
