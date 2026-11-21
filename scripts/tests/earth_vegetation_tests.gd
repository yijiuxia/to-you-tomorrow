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
		assert(not vegetation.eligible(cell))
		assert(view.pollution_surface(cell).y==0)
	assert(not vegetation.eligible(Vector2i(4,63)))
	assert(view.pollution_surface(Vector2i(1,5)).x==7)
	print("PASS: continuous moss, concrete A, dense B/C, roads/river excluded, clean/planted cells retreat, stable refresh")
	get_tree().quit()
