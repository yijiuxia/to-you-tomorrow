extends Node
## 检查真实地球画面的连续覆盖及恢复状态，而不是另搭展示场景。

func _ready() -> void:
	GameState.reset()
	var world := EarthWorld.new()
	var view := EarthView.new()
	add_child(view)
	view.setup(world)
	var b := Vector2i(0,40)
	if view.pollution_surface(b).y!=1:
		push_error("B 区污染地表没有连续苔毯，仍是随机单丛")
		get_tree().quit(1)
		return
	var vegetation: Node3D = view.get("_vegetation")
	assert(vegetation != null)
	if not vegetation.eligible(Vector2i(19,42)):
		push_error("道路仍被整条排除，无法长出裂缝草")
		get_tree().quit(1)
		return
	# 导入后的网格必须包含真实茎秆面，防止只剩叶片仍被当作通过。
	assert(vegetation.road_samples.size()>20,"Road only permits growth but generated no plants")
	var center_growth := 0
	for sample: Vector2 in vegetation.road_samples:
		if sample.x < -1.0: center_growth+=1
		assert(sample.y<=float(DataDB.balance("earth_veg_road_max_height"))+0.00001)
	assert(center_growth>0,"Road centre is still completely barren")
	for asset: String in vegetation._meshes:
		if asset.begins_with("finegrass_meadow"): continue
		if not (asset.begins_with("finegrass") or asset.begins_with("broadgrass") or asset.begins_with("dryshoots")): continue
		var has_culm := false
		for part: Dictionary in vegetation._meshes[asset]["parts"]:
			var mesh: Mesh = part["mesh"]
			for surface in mesh.get_surface_count():
				has_culm = has_culm or mesh.surface_get_material(surface).resource_name.begins_with("Culm")
		assert(has_culm,"Imported groundcover has no stalk geometry: "+asset)
	assert(vegetation.counts.get("a",0)<vegetation.counts.get("b",0)/10)
	assert(vegetation.counts.get("b",0)>0 and vegetation.counts.get("c",0)>0)
	var first: String = vegetation.signature
	view.refresh()
	assert(first==vegetation.signature)
	world.pollution[b] = 0
	view.refresh()
	assert(view.pollution_surface(b).y==0)
	assert(not vegetation.eligible(b))
	world.pollution[b] = 2
	world.plants[b] = {"type":"flower","age":0}
	view.refresh()
	assert(view.pollution_surface(b).y==0)
	assert(not vegetation.eligible(b))
	for cell: Vector2i in view._road_cells:
		assert(view.pollution_surface(cell).y==0)
	assert(not vegetation.eligible(Vector2i(4,63)))
	assert(view.pollution_surface(Vector2i(1,5)).x==7)
	print("PASS: continuous moss, concrete A, dense B/C, road growth permitted, river excluded, recovery retreat")
	get_tree().quit()
