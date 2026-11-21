extends Node
## 直接使用正式 EarthView 和 ARK-01 原相机，不改变存档。

func _ready() -> void:
	var output := "user://vegetation_shots"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot-dir="): output=arg.trim_prefix("--shot-dir=")
	DirAccess.make_dir_recursive_absolute(output)
	get_window().size=Vector2i(1280,720)
	GameState.reset()
	GameState.flags["gate_open"]=true
	GameState.flags["bridge_open"]=true
	var world := EarthWorld.new()
	var view := EarthView.new()
	add_child(view)
	view.setup(world)
	view.set_game_filter(true)
	var ark := ArkController.new()
	view.add_child(ark)
	ark.setup(view,view.cell_center(Vector2i(13,14)))
	ark.set_active(true)
	var results: Array = []
	for shot: Array in [["A",Vector2i(13,14),PI],["B",Vector2i(19,42),PI],["C",Vector2i(20,81),PI/2]]:
		ark.position=view.cell_center(shot[1])+Vector3.UP
		ark._pivot.rotation.y=shot[2]
		for i in 60: await get_tree().process_frame
		var samples: Array[float] = []
		var previous := Time.get_ticks_usec()
		for i in 120:
			await get_tree().process_frame
			var now := Time.get_ticks_usec()
			samples.append(float(now-previous)/1000.0)
			previous=now
		get_viewport().get_texture().get_image().save_png(output.path_join(shot[0]+"_ark.png"))
		var total := 0.0
		for ms in samples: total+=ms
		samples.sort()
		results.append({"zone":shot[0],"mean_ms":total/samples.size(),"p95_ms":samples[113]})
	var report := {"zones":results,"counts":view._vegetation.counts,"gpu":RenderingServer.get_video_adapter_name(),"resolution":"1280x720","scope":"actual EarthView and ArkController fixed cameras; excludes full UI and language model"}
	var file := FileAccess.open(output.path_join("performance.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("PASS: actual ARK cameras captured ",report)
	get_tree().quit()
