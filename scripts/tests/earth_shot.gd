extends Node
## 小镇画面截图（美术线程）：会开窗口，跑之前先告诉 yi。
## Godot.exe --path . res://scenes/tests/earth_shot.tscn -- --shot-dir=保存目录

const SHOTS := [
	# [文件名, 时间, 镜头位置, 看向哪里]
	["1_a_day", "day", Vector3(46, 22, -14), Vector3(18, 0, 22)],
	["2_b_day", "day", Vector3(64, 30, 40), Vector3(26, 0, 80)],
	["3_c_day", "day", Vector3(64, 30, 120), Vector3(26, 0, 165)],
	["4_overview_day", "day", Vector3(110, 80, -40), Vector3(30, 0, 90)],
	["5_a_evening", "evening", Vector3(46, 22, -14), Vector3(18, 0, 22)],
	["6_a_night", "night", Vector3(46, 22, -14), Vector3(18, 0, 22)],
	["7_ark_close", "day", Vector3(20, 4, 4), Vector3(12, 1, 14)],
	# 贴地视角（和 ARK-01 第三人称差不多高），对照参考图 A1、A5、B1、C1
	["8_ground_a_hangar", "day", Vector3(28, 3, 26), Vector3(14, 2, 6)],
	["9_ground_a_road", "day", Vector3(2, 2.5, 36), Vector3(40, 1, 36)],
	["10_ground_gate", "day", Vector3(40, 2.5, 50), Vector3(30, 2, 60)],
	["11_ground_b_road", "day", Vector3(40, 3, 62), Vector3(40, 2, 110)],
	["12_ground_river", "day", Vector3(36, 3, 108), Vector3(28, 1, 130)],
	["13_ground_c_street", "day", Vector3(4, 2.5, 164), Vector3(56, 1, 164)],
	["14_ground_c_dome", "day", Vector3(30, 3, 140), Vector3(26, 3, 152)],
]

var _dir := "user://earth_shots"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot-dir="):
			_dir = arg.trim_prefix("--shot-dir=")
	DirAccess.make_dir_recursive_absolute(_dir)
	get_window().size = Vector2i(1600, 900)
	GameState.reset()
	# 三个区都打开，才能拍到 B、C 区
	GameState.flags["gate_open"] = true
	GameState.flags["bridge_open"] = true
	var world := EarthWorld.new()
	var view := EarthView.new()
	add_child(view)
	view.setup(world)
	view.set_game_filter(true)
	var ark := ArkController.new()
	view.add_child(ark)
	ark.setup(view, view.cell_center(Vector2i(6, 7)))
	var camera := Camera3D.new()
	camera.far = 1500.0
	add_child(camera)
	camera.make_current()
	for shot: Array in SHOTS:
		view.set_time_of_day(shot[1])
		camera.position = shot[2]
		camera.look_at(shot[3])
		for i in 20:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(_dir.path_join(shot[0] + ".png"))
	get_tree().quit()
