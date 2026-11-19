class_name GirlModel
extends Node3D
## 房间里的她（房间线程 11.19）：VRoid 模型（E:\jianmo\致你\女孩\vroid\Girl.fbx），坐在椅子上。
## 待机：眨眼、轻微呼吸起伏；点她时笑一下。
## FBX 里没带贴图，按 女孩_UE导入说明.md 的表在这里给每个材质接上贴图。
## 坐姿是程序把腿和胳膊的骨头转过去摆的，以后有坐姿动画再换。

const MODEL := "res://assets/models/girl/Girl.fbx"
const TEX_DIR := "res://assets/models/girl/textures/"
## 材质名里含这几个字 → 用哪张贴图、怎么透明（scissor 剪掉透明处 / blend 半透明）
const MATERIALS := [
	["FaceMouth", "T_Girl_FaceMouth", "scissor"],
	["EyeIris", "T_Girl_EyeIris", "blend"],
	["EyeHighlight", "T_Girl_EyeHighlight", "highlight"],
	["Face_00_SKIN", "T_Girl_Face", "scissor"],
	["EyeWhite", "T_Girl_EyeWhite", "scissor"],
	["FaceBrow", "T_Girl_FaceBrow", "blend"],
	["FaceEyelash", "T_Girl_FaceEyelash", "blend"],
	["FaceEyeline", "T_Girl_FaceEyeline", "blend"],
	["HairBack", "T_Girl_HairBack", "scissor"],
	["Hair_00_HAIR", "T_Girl_Hair", "scissor"],
	["Body_00_SKIN", "T_Girl_Body", "scissor"],
	["Shoes", "T_Girl_Shoes", "scissor"],
	["Tops", "T_Girl_Tops", "scissor"],
	["Sock", "T_Girl_Socks", "opaque"],
	["Coat", "T_Girl_Coat", "scissor"],
]
const HIGHLIGHT_PRIORITY := 10
const INNER_TOP := "Tops"   # 里面那件衣服的材质名
const SLEEVE_BONES: Array[String] = ["UpperArm", "LowerArm", "Hand", "Index", "Middle", "Ring", "Little", "Thumb"]
## 坐姿：骨头名 → 绕哪根轴转多少度（大腿往前抬、小腿往下弯、胳膊放下来）
const SIT_POSE := {
	"J_Bip_L_UpperLeg": Vector3(-85, 0, 0),
	"J_Bip_R_UpperLeg": Vector3(-85, 0, 0),
	"J_Bip_L_LowerLeg": Vector3(85, 0, 0),
	"J_Bip_R_LowerLeg": Vector3(85, 0, 0),
	"J_Bip_L_UpperArm": Vector3(0, 0, -65),
	"J_Bip_R_UpperArm": Vector3(0, 0, 65),
	"J_Bip_L_LowerArm": Vector3(0, -30, 0),
	"J_Bip_R_LowerArm": Vector3(0, 30, 0),
}
## 坐着待机的动作（Mixamo 的 Sitting Idle，yi 给的），在游戏里实时把 Mixamo 骨头的转动对应到 VRoid 骨头上
const SIT_ANIM := "res://assets/models/girl/anim/sitting_idle.fbx"
const SIT_ANIM_NAME := "mixamo_com"
const RETARGET := {
	"mixamorig_Hips": "J_Bip_C_Hips", "mixamorig_Spine": "J_Bip_C_Spine", "mixamorig_Spine1": "J_Bip_C_Chest",
	"mixamorig_Spine2": "J_Bip_C_UpperChest", "mixamorig_Neck": "J_Bip_C_Neck", "mixamorig_Head": "J_Bip_C_Head",
	"mixamorig_LeftShoulder": "J_Bip_L_Shoulder", "mixamorig_LeftArm": "J_Bip_L_UpperArm",
	"mixamorig_LeftForeArm": "J_Bip_L_LowerArm", "mixamorig_LeftHand": "J_Bip_L_Hand",
	"mixamorig_RightShoulder": "J_Bip_R_Shoulder", "mixamorig_RightArm": "J_Bip_R_UpperArm",
	"mixamorig_RightForeArm": "J_Bip_R_LowerArm", "mixamorig_RightHand": "J_Bip_R_Hand",
	"mixamorig_LeftUpLeg": "J_Bip_L_UpperLeg", "mixamorig_LeftLeg": "J_Bip_L_LowerLeg",
	"mixamorig_LeftFoot": "J_Bip_L_Foot", "mixamorig_LeftToeBase": "J_Bip_L_ToeBase",
	"mixamorig_RightUpLeg": "J_Bip_R_UpperLeg", "mixamorig_RightLeg": "J_Bip_R_LowerLeg",
	"mixamorig_RightFoot": "J_Bip_R_Foot", "mixamorig_RightToeBase": "J_Bip_R_ToeBase",
}
## 隔一会儿抬左手指一下桌上的平板（yi 11.19）：在坐着的动作上面把左胳膊转向平板
const POINT_ARM := "J_Bip_L_UpperArm"
const POINT_FOREARM := "J_Bip_L_LowerArm"
const POINT_HAND := "J_Bip_L_Hand"
const POINT_SHOULDER := "J_Bip_L_Shoulder"
const POINT_CHEST := "J_Bip_C_UpperChest"
const SHOULDER_SHARE := 0.35   # 肩膀跟着转几成
const CHEST_SHARE := 0.08      # 上身跟着转几成（很小，只是带一下）
const POINT_INDEX_ROOT := "J_Bip_L_Index1"
const POINT_INDEX_TIP := "J_Bip_L_Index3"
## 指的时候握拳、只伸食指（yi 11.19）：这些手指关节往里弯
const FIST_BONES: Array[String] = ["J_Bip_L_Middle1", "J_Bip_L_Middle2", "J_Bip_L_Middle3", "J_Bip_L_Ring1", "J_Bip_L_Ring2", "J_Bip_L_Ring3", "J_Bip_L_Little1", "J_Bip_L_Little2", "J_Bip_L_Little3"]
const THUMB_BONES: Array[String] = ["J_Bip_L_Thumb2", "J_Bip_L_Thumb3"]
const FIST_AXIS := Vector3(0, 0, 1)
const FIST_ANGLE := -80.0
const THUMB_AXIS := Vector3(0, 1, 0)
const THUMB_ANGLE := 45.0
const POINT_GAP := Vector2(7.0, 12.0)   # 每隔几秒指一次
const POINT_HOLD := 1.8                  # 指着停多久
const POINT_BLEND := 1.0                 # 抬手、放手用多久（yi：放慢一点，更自然）
const POINT_STRAIGHTEN := 0.3            # 小臂伸直到几成（不完全伸直，肘部留一点弯）
const BLINK_KEY := "Fcl_EYE_Close"
const SMILE_KEY := "Fcl_ALL_Joy"
const BLINK_TIME := 0.12
const BLINK_GAP := Vector2(2.5, 5.0)   # 每隔几秒眨一次眼（随机）
const BREATH_SPEED := 1.6
const BREATH_DEPTH := 0.012            # 胸口起伏多少（骨头缩放）
const SMILE_SEC := 2.0

var skeleton: Skeleton3D
var face: MeshInstance3D
var _chest := -1
var _time := 0.0
var _next_blink := 3.0
var _rng := RandomNumberGenerator.new()
var _source: Skeleton3D          # 播着 Sitting Idle 的 Mixamo 骨架（藏起来，只拿它的动作）
var _pairs: Array = []
var point_target := Vector3.INF  # 平板的位置（房间坐标），房间画面设
var _point_weight := 0.0
var _next_point := 4.0           # [源骨头, 目标骨头, 源静止朝向(世界), 目标静止朝向(世界)]，父骨头在前


## 模型文件在不在（打包漏了就退回胶囊）
static func available() -> bool:
	return ResourceLoader.exists(MODEL)


func _ready() -> void:
	_rng.randomize()
	var scene: PackedScene = load(MODEL)
	var model := scene.instantiate() as Node3D
	add_child(model)
	skeleton = model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		_apply_materials(mesh)
		if mesh.find_blend_shape_by_name(BLINK_KEY) >= 0:
			face = mesh
	if not _start_animation():
		_sit()  # 动作文件不在或对不上时，用程序摆的坐姿


func _process(delta: float) -> void:
	_time += delta
	if _source != null:
		_retarget()
		if int(DataDB.balance("room_girl_point", 0)) == 1:
			_point()
	elif _chest >= 0:
		var breath := 1.0 + sin(_time * BREATH_SPEED) * BREATH_DEPTH
		skeleton.set_bone_pose_scale(_chest, Vector3(breath, breath, breath))
	if _time >= _next_blink:
		_next_blink = _time + _rng.randf_range(BLINK_GAP.x, BLINK_GAP.y)
		_blink()


func _sit() -> void:
	for bone_name: String in SIT_POSE:
		var bone := skeleton.find_bone(bone_name)
		if bone < 0:
			continue
		var turn: Vector3 = SIT_POSE[bone_name]
		var rest := skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()
		var extra := Quaternion.from_euler(Vector3(deg_to_rad(turn.x), deg_to_rad(turn.y), deg_to_rad(turn.z)))
		skeleton.set_bone_pose_rotation(bone, rest * extra)
	_chest = skeleton.find_bone("J_Bip_C_UpperChest")


## 放 Sitting Idle：把 Mixamo 的模型藏着播动作，每帧把骨头转动抄到她身上
func _start_animation() -> bool:
	if not ResourceLoader.exists(SIT_ANIM):
		return false
	var scene: Node3D = (load(SIT_ANIM) as PackedScene).instantiate()
	scene.visible = false
	add_child(scene)
	var players := scene.find_children("*", "AnimationPlayer", true, false)
	var skeletons := scene.find_children("*", "Skeleton3D", true, false)
	if players.is_empty() or skeletons.is_empty():
		return false
	_source = skeletons[0]
	var player: AnimationPlayer = players[0]
	if not player.has_animation(SIT_ANIM_NAME):
		return false
	player.get_animation(SIT_ANIM_NAME).loop_mode = Animation.LOOP_LINEAR
	player.play(SIT_ANIM_NAME)
	for bone in skeleton.get_bone_count():  # 按骨头顺序，父骨头一定在子骨头前面
		var target_name := skeleton.get_bone_name(bone)
		var source_name: String = RETARGET.find_key(target_name) if RETARGET.values().has(target_name) else ""
		if source_name.is_empty():
			continue
		var source_bone := _source.find_bone(source_name)
		if source_bone < 0:
			continue
		_pairs.append([source_bone, bone, _world_rest(_source, source_bone), _world_rest(skeleton, bone)])
	return not _pairs.is_empty()


func _world_rest(skel: Skeleton3D, bone: int) -> Quaternion:
	return (skel.global_basis.orthonormalized() * skel.get_bone_global_rest(bone).basis.orthonormalized()).get_rotation_quaternion()


## 源骨头在世界里比静止时多转了多少，目标骨头就从它自己的静止朝向多转多少
func _retarget() -> void:
	var target_world := skeleton.global_basis.orthonormalized().get_rotation_quaternion()
	var source_world := _source.global_basis.orthonormalized().get_rotation_quaternion()
	for pair: Array in _pairs:
		var source_pose := source_world * _source.get_bone_global_pose(pair[0]).basis.orthonormalized().get_rotation_quaternion()
		var delta: Quaternion = source_pose * (pair[2] as Quaternion).inverse()
		var wanted: Quaternion = delta * pair[3]
		var in_skeleton := target_world.inverse() * wanted
		var parent := skeleton.get_bone_parent(pair[1])
		var parent_rot := Quaternion.IDENTITY
		if parent >= 0:
			parent_rot = skeleton.get_bone_global_pose(parent).basis.orthonormalized().get_rotation_quaternion()
		skeleton.set_bone_pose_rotation(pair[1], parent_rot.inverse() * in_skeleton)


## 抬手指平板：权重 0 是原来的动作，1 是胳膊伸直对着平板
func _point() -> void:
	if point_target == Vector3.INF:
		return
	if _time >= _next_point:
		_next_point = _time + _rng.randf_range(POINT_GAP.x, POINT_GAP.y)
		var tween := create_tween()
		tween.tween_property(self, "_point_weight", 1.0, POINT_BLEND).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_interval(POINT_HOLD)
		tween.tween_property(self, "_point_weight", 0.0, POINT_BLEND * 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if _point_weight <= 0.001:
		return
	var arm := skeleton.find_bone(POINT_ARM)
	var forearm := skeleton.find_bone(POINT_FOREARM)
	if arm < 0 or forearm < 0:
		return
	# 肩膀和上身跟着往平板那边带一点，再抬整条胳膊指向平板（yi：手肘改回原来的样子）
	_turn_toward(POINT_CHEST, POINT_SHOULDER, point_target, CHEST_SHARE)
	_turn_toward(POINT_SHOULDER, POINT_ARM, point_target, SHOULDER_SHARE)
	# 小臂伸直（回到静止时相对大臂的朝向），肘部留一点弯
	var straight := skeleton.get_bone_rest(forearm).basis.get_rotation_quaternion()
	skeleton.set_bone_pose_rotation(forearm, skeleton.get_bone_pose_rotation(forearm).slerp(straight, _point_weight * POINT_STRAIGHTEN))
	# 大臂转向平板：从"现在胳膊的方向"转到"肩膀指向平板的方向"
	_turn_toward(POINT_ARM, POINT_FOREARM, point_target, 1.0)
	var room_target := point_target
	_make_fist(FIST_BONES, FIST_AXIS, FIST_ANGLE)
	# yi：手腕不要往外翻。不再单独转手腕，手保持原来动作里的朝向，小臂已经对着平板
	_relax_wrist()
	_make_fist(THUMB_BONES, THUMB_AXIS, THUMB_ANGLE)


## 把一根骨头往目标方向转一部分：它到子骨头的方向，朝"它到目标的方向"转 share 成
func _turn_toward(bone_name: String, child_name: String, target: Vector3, share: float) -> void:
	var bone := skeleton.find_bone(bone_name)
	var child := skeleton.find_bone(child_name)
	if bone < 0 or child < 0:
		return
	var from := skeleton.global_transform * skeleton.get_bone_global_pose(bone).origin
	var to := skeleton.global_transform * skeleton.get_bone_global_pose(child).origin
	var now_dir := (to - from).normalized()
	var want_dir := (target - from).normalized()
	if now_dir.is_zero_approx() or want_dir.is_zero_approx():
		return
	var skel_q := skeleton.global_basis.orthonormalized().get_rotation_quaternion()
	var bone_global := skel_q * skeleton.get_bone_global_pose(bone).basis.orthonormalized().get_rotation_quaternion()
	var wanted: Quaternion = Quaternion.IDENTITY.slerp(Quaternion(now_dir, want_dir), _point_weight * share) * bone_global
	var parent := skeleton.get_bone_parent(bone)
	var parent_q := skel_q * (skeleton.get_bone_global_pose(parent).basis.orthonormalized().get_rotation_quaternion() if parent >= 0 else Quaternion.IDENTITY)
	skeleton.set_bone_pose_rotation(bone, parent_q.inverse() * wanted)


## 手腕回到静止时相对小臂的朝向（不往外翻）
func _relax_wrist() -> void:
	var hand := skeleton.find_bone(POINT_HAND)
	if hand < 0:
		return
	var rest := skeleton.get_bone_rest(hand).basis.get_rotation_quaternion()
	skeleton.set_bone_pose_rotation(hand, skeleton.get_bone_pose_rotation(hand).slerp(rest, _point_weight))


## 转手腕，让伸出来的食指正对平板（11.19 yi 说手腕往外翻，先不用）（食指根到指尖的方向 → 指尖到平板的方向）
func _aim_hand(target: Vector3) -> void:
	var hand := skeleton.find_bone(POINT_HAND)
	var root := skeleton.find_bone(POINT_INDEX_ROOT)
	var tip := skeleton.find_bone(POINT_INDEX_TIP)
	if hand < 0 or root < 0 or tip < 0:
		return
	var root_pos := skeleton.global_transform * skeleton.get_bone_global_pose(root).origin
	var tip_pos := skeleton.global_transform * skeleton.get_bone_global_pose(tip).origin
	var now_dir := (tip_pos - root_pos).normalized()
	var want_dir := (target - root_pos).normalized()
	if now_dir.is_zero_approx() or want_dir.is_zero_approx():
		return
	var skel_q := skeleton.global_basis.orthonormalized().get_rotation_quaternion()
	var hand_global := skel_q * skeleton.get_bone_global_pose(hand).basis.orthonormalized().get_rotation_quaternion()
	var wanted: Quaternion = Quaternion.IDENTITY.slerp(Quaternion(now_dir, want_dir), _point_weight) * hand_global
	var parent_q := skel_q * skeleton.get_bone_global_pose(skeleton.get_bone_parent(hand)).basis.orthonormalized().get_rotation_quaternion()
	skeleton.set_bone_pose_rotation(hand, parent_q.inverse() * wanted)


## 手指从静止姿势往里弯，按指的程度混合（食指不动，就是伸着的）
func _make_fist(bones: Array[String], axis_local: Vector3, angle: float) -> void:
	for bone_name in bones:
		var bone := skeleton.find_bone(bone_name)
		if bone < 0:
			continue
		var rest := skeleton.get_bone_rest(bone).basis.get_rotation_quaternion()
		var curled := rest * Quaternion(axis_local, deg_to_rad(angle))
		skeleton.set_bone_pose_rotation(bone, skeleton.get_bone_pose_rotation(bone).slerp(curled, _point_weight))


func _blink() -> void:
	if face == null:
		return
	var key := face.find_blend_shape_by_name(BLINK_KEY)
	var tween := create_tween()
	tween.tween_method(func(v: float) -> void: face.set_blend_shape_value(key, v), 0.0, 1.0, BLINK_TIME)
	tween.tween_method(func(v: float) -> void: face.set_blend_shape_value(key, v), 1.0, 0.0, BLINK_TIME)


## 点她时笑一下
func smile() -> void:
	if face == null:
		return
	var key := face.find_blend_shape_by_name(SMILE_KEY)
	if key < 0:
		return
	var tween := create_tween()
	tween.tween_method(func(v: float) -> void: face.set_blend_shape_value(key, v), 0.0, 1.0, 0.2)
	tween.tween_interval(SMILE_SEC)
	tween.tween_method(func(v: float) -> void: face.set_blend_shape_value(key, v), 1.0, 0.0, 0.3)


func _apply_materials(mesh: MeshInstance3D) -> void:
	for i in mesh.get_surface_override_material_count():
		var old := mesh.mesh.surface_get_material(i)
		var mat_name := old.resource_name if old != null else ""
		for entry: Array in MATERIALS:
			if mat_name.contains(entry[0]):
				mesh.set_surface_override_material(i, _material(entry[1], entry[2]))
				break
	_hide_inner_sleeves(mesh)


## yi 11.19：里面衣服（Tops）的袖子藏起来，抬手时不会从外套袖子里穿出来。
## 做法：把 Tops 里主要跟着胳膊骨头动的三角形删掉（只改三角形列表，顶点和表情都不动），胸口那块保留。
func _hide_inner_sleeves(node: MeshInstance3D) -> void:
	var source := node.mesh as ArrayMesh
	if source == null or node.skin == null:
		return
	var target := -1
	for i in source.get_surface_count():
		var mat := source.surface_get_material(i)
		if mat != null and mat.resource_name.contains(INNER_TOP):
			target = i
	if target < 0:
		return
	var arm_binds := {}
	for bind in node.skin.get_bind_count():
		var bind_name := String(node.skin.get_bind_name(bind))
		if bind_name.is_empty() and skeleton != null and node.skin.get_bind_bone(bind) >= 0:
			bind_name = skeleton.get_bone_name(node.skin.get_bind_bone(bind))
		for part in SLEEVE_BONES:
			if bind_name.contains(part):
				arm_binds[bind] = true
	var rebuilt := ArrayMesh.new()
	rebuilt.blend_shape_mode = source.blend_shape_mode
	for shape in source.get_blend_shape_count():
		rebuilt.add_blend_shape(source.get_blend_shape_name(shape))
	for i in source.get_surface_count():
		var arrays := source.surface_get_arrays(i)
		if i == target:
			arrays[Mesh.ARRAY_INDEX] = _drop_arm_triangles(arrays, arm_binds)
		rebuilt.add_surface_from_arrays(source.surface_get_primitive_type(i), arrays, source.surface_get_blend_shape_arrays(i), {}, source.surface_get_format(i) & ~Mesh.ARRAY_FORMAT_INDEX | Mesh.ARRAY_FORMAT_INDEX)
		rebuilt.surface_set_material(i, source.surface_get_material(i))
		rebuilt.surface_set_name(i, source.surface_get_name(i))
	var overrides: Array[Material] = []
	for i in node.get_surface_override_material_count():
		overrides.append(node.get_surface_override_material(i))
	node.mesh = rebuilt
	for i in overrides.size():
		node.set_surface_override_material(i, overrides[i])


## 一个顶点"主要跟着胳膊动"：权重最大的那根骨头是胳膊或手。三角形三个顶点有一个是，就删掉
func _drop_arm_triangles(arrays: Array, arm_binds: Dictionary) -> PackedInt32Array:
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var per_vertex := bones.size() / maxi((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), 1)
	var on_arm := PackedByteArray()
	on_arm.resize((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
	for v in on_arm.size():
		var best := -1
		var best_weight := -1.0
		for k in per_vertex:
			if weights[v * per_vertex + k] > best_weight:
				best_weight = weights[v * per_vertex + k]
				best = bones[v * per_vertex + k]
		on_arm[v] = 1 if arm_binds.has(best) else 0
	var kept := PackedInt32Array()
	for t in range(0, indices.size(), 3):
		if on_arm[indices[t]] == 0 and on_arm[indices[t + 1]] == 0 and on_arm[indices[t + 2]] == 0:
			kept.append(indices[t])
			kept.append(indices[t + 1])
			kept.append(indices[t + 2])
	return kept


func _material(texture_name: String, mode: String) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(TEX_DIR + texture_name + "_BaseColor.png")
	mat.roughness = 0.6
	var normal_path := TEX_DIR + texture_name + "_Normal.png"
	if ResourceLoader.exists(normal_path):
		mat.normal_enabled = true
		mat.normal_texture = load(normal_path)
	match mode:
		"scissor":
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		"blend":
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		"highlight":
			# 眼睛高光（yi 11.19）：不受灯光影响、最后画、不被眼白和瞳孔挡住，不然在房间灯光下几乎看不见
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.render_priority = HIGHLIGHT_PRIORITY
			mat.no_depth_test = true
	return mat
