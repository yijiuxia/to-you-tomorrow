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
	["EyeHighlight", "T_Girl_EyeHighlight", "blend"],
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
var _pairs: Array = []           # [源骨头, 目标骨头, 源静止朝向(世界), 目标静止朝向(世界)]，父骨头在前


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
	return mat
