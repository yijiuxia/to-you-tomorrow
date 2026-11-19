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
	_sit()


func _process(delta: float) -> void:
	_time += delta
	if _chest >= 0:
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
