class_name VineCurtain
extends Node3D
## 垂藤帘（房间线程 11.19，照 E:\jianmo_test\致你\植被\植物素材测试.blend 里 GN_垂藤帘 的做法在 Godot 里程序生成）：
## 沿一根横杆随机长出很多根藤，长短不一、成簇，轻轻摆一点；每隔几厘米长一片叶子，叶子随机朝向、大小、深浅。
## 用来替换房间模型里的垂藤贴片（Card_Vine_*），从侧面看也是立体的。
## 数值都在 balance.csv 的 room_vine_ 开头几行。

## 叶子颜色：跟房间里其他绿植（绿萝、盆栽）差不多的黄绿到深绿，每根藤再整体偏一点（yi 11.19）
const LEAF_COLORS: Array[Color] = [Color(0.36, 0.62, 0.20), Color(0.46, 0.70, 0.24), Color(0.56, 0.76, 0.30), Color(0.28, 0.50, 0.16), Color(0.64, 0.80, 0.36), Color(0.22, 0.42, 0.14)]
const STEM_COLOR := Color(0.36, 0.30, 0.18)

var width := 0.5         # 横杆多长（米）
var length := 0.8        # 最长的藤多长（米）
var axis := Vector3.RIGHT  # 横杆的方向
var seed_value := 1


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var per_meter := float(DataDB.balance("room_vine_per_meter", 40))
	var spacing := float(DataDB.balance("room_vine_leaf_spacing", 0.035))
	var leaf_size := float(DataDB.balance("room_vine_leaf_size", 0.035))
	var strands := maxi(3, int(width * per_meter))
	var leaves: Array[Transform3D] = []
	var colors: Array[Color] = []
	var stems := SurfaceTool.new()
	stems.begin(Mesh.PRIMITIVE_LINES)
	stems.set_color(STEM_COLOR)
	var side := axis.cross(Vector3.UP).normalized()
	for i in strands:
		# 成簇：先挑一个簇中心，再在附近散开
		var along := clampf(rng.randf_range(-0.5, 0.5) * width + rng.randfn(0.0, width * 0.05), -width / 2.0, width / 2.0)
		var depth := rng.randf_range(-0.03, 0.03)
		var strand_len := length * pow(rng.randf(), 1.0 / 2.2)  # 长短分布：多数短、少数长
		strand_len = maxf(strand_len, length * 0.15)
		var sway := rng.randf_range(-0.12, 0.12)
		var strand_tint := rng.randf_range(-0.12, 0.12)  # 这根藤整体偏亮还是偏暗
		var start := axis * along + side * depth
		var steps := maxi(2, int(strand_len / spacing))
		var prev := start
		for s in range(1, steps + 1):
			var t := float(s) / steps
			# 往下垂，越往下越往外摆一点
			var point := start + Vector3(0, -strand_len * t, 0) + side * (sway * t * t * strand_len) + axis * (sin(t * 6.0 + i) * 0.01)
			stems.add_vertex(prev)
			stems.add_vertex(point)
			prev = point
			var basis := Basis(Vector3.UP, rng.randf_range(0, TAU)) * Basis(Vector3.RIGHT, rng.randf_range(0.6, 1.4))
			var size := leaf_size * rng.randf_range(0.6, 1.2) * lerpf(1.0, 0.6, t)
			leaves.append(Transform3D(basis.scaled(Vector3.ONE * size), point))
			var leaf_color := LEAF_COLORS[rng.randi() % LEAF_COLORS.size()]
			leaf_color = leaf_color.lightened(strand_tint) if strand_tint > 0.0 else leaf_color.darkened(-strand_tint)
			# 越往下的叶子越嫩、越浅
			colors.append(leaf_color.lightened(t * 0.06 + rng.randf_range(0.0, 0.05)))
	var stem_mesh := MeshInstance3D.new()
	stem_mesh.mesh = stems.commit()
	var stem_mat := StandardMaterial3D.new()
	stem_mat.vertex_color_use_as_albedo = true
	stem_mesh.material_override = stem_mat
	add_child(stem_mesh)

	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = _leaf_mesh()
	multi.instance_count = leaves.size()
	for i in leaves.size():
		multi.set_instance_transform(i, leaves[i])
		multi.set_instance_color(i, colors[i])
	var leaves_node := MultiMeshInstance3D.new()
	leaves_node.multimesh = multi
	var leaf_mat := StandardMaterial3D.new()
	leaf_mat.vertex_color_use_as_albedo = true
	leaf_mat.vertex_color_is_srgb = true  # 颜色按屏幕上看到的算，不然整体发白
	leaf_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	leaf_mat.roughness = 0.7
	leaves_node.material_override = leaf_mat
	add_child(leaves_node)


## 一片叶子：心形的小平面（宽 1、长 1.3，尖朝下），带一点弯
func _leaf_mesh() -> ArrayMesh:
	var outline := [Vector2(0, 0), Vector2(0.35, 0.15), Vector2(0.5, 0.45), Vector2(0.4, 0.85), Vector2(0, 1.3),
		Vector2(-0.4, 0.85), Vector2(-0.5, 0.45), Vector2(-0.35, 0.15)]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center := Vector3(0, -0.55, 0.06)
	for i in outline.size():
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i + 1) % outline.size()]
		tool.add_vertex(center)
		tool.add_vertex(Vector3(a.x, -a.y, 0))
		tool.add_vertex(Vector3(b.x, -b.y, 0))
	tool.generate_normals()
	return tool.commit()
