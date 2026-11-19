extends Node
## 房间画面截图（房间线程）：会开窗口，跑之前先告诉 yi。
## Godot.exe --path . res://scenes/tests/room_shot.tscn -- --shot-dir=保存目录

const HubScreen := preload("res://scripts/ui/hub_screen.gd")

var _dir := "user://room_shots"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot-dir="):
			_dir = arg.trim_prefix("--shot-dir=")
	DirAccess.make_dir_recursive_absolute(_dir)
	get_window().size = Vector2i(1280, 720)
	GameState.reset()
	var hub := HubScreen.new()
	hub.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(hub)
	await _shot("1_room")
	hub.room.click("model_ark")
	await _wait(0.6)
	await _shot("2_look")
	hub.room.stop_looking()
	hub.room.hide_info()
	hub.room.click("tablet")
	await _shot("3_tablet")
	hub.tablet.tabs.current_tab = 5
	await _shot("4_tech")
	hub.queue_free()
	for id: String in ["preserve", "underground"]:
		var screen := PlaceScreen.new()
		screen.place_id = id
		screen.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(screen)
		await _shot("5_" + id)
		screen.queue_free()
	get_tree().quit()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(name_text: String) -> void:
	await _wait(0.4)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_dir.path_join(name_text + ".png"))
