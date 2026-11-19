extends Node
## 房间、平板、场所、科技树的自动测试（房间线程）。运行方法：
## Godot_console.exe --headless --path . res://scenes/tests/room_tests.tscn
## 全部通过时退出码是 0。

const HubScreen := preload("res://scripts/ui/hub_screen.gd")

var _failures := 0
var _count := 0


func _ready() -> void:
	GameState.reset()
	test_tables()
	test_toggles_and_options()
	test_journal()
	test_tech()
	test_places_open_by_week()
	await test_room_view_clicks()
	await test_hub_room()
	await test_every_place_builds()
	GameState.reset()
	print("房间测试 %d 项，失败 %d 项" % [_count, _failures])
	await _frames(3)
	get_tree().quit(1 if _failures > 0 else 0)


## 表里用到的文字编号都要存在，场所都要在 places.csv 里
func test_tables() -> void:
	for row: Dictionary in DataDB.table("room_objects").values():
		_ok(not RoomRules.place(row["scene"]).is_empty(), "物件 %s 的场所存在" % row["id"])
		_ok(Text.has_language(row["name_key"], "zh"), "物件名字编号存在：" + row["name_key"])
		var info := str(row["info_key"])
		_ok(info.is_empty() or Text.has_language(info, "zh"), "物件说明编号存在：" + info)
	for table: String in ["places", "room_options", "tech"]:
		for row: Dictionary in DataDB.table(table).values():
			_ok(Text.has_language(row["name_key"], "zh"), "%s 的名字编号存在：%s" % [table, row["name_key"]])


func test_toggles_and_options() -> void:
	_ok(RoomRules.is_on("lamp"), "台灯默认开着")
	_eq(RoomRules.toggle("lamp"), false, "点一下关灯")
	_ok(not RoomRules.is_on("lamp"), "关灯记下来了")
	RoomRules.toggle("lamp")
	_eq(RoomRules.current_option("view")["id"], "view_earth", "窗景默认是地球")
	RoomRules.choose_option("view", "view_stars")
	_eq(RoomRules.current_option("view")["id"], "view_stars", "换窗景")
	_ok(RoomRules.toggle_label("cover", true) != RoomRules.toggle_label("cover", false), "灯罩按钮两种状态文字不同")


func test_journal() -> void:
	GameState.reset()
	var lines := RoomRules.journal_text(1)
	_ok(lines.size() >= 10, "周记有五个部分")
	_ok(not "\n".join(lines).contains("RM-"), "周记没有漏掉的编号")
	GameState.stats["curiosity"] = 80
	_ok("\n".join(RoomRules.journal_text(1)).contains(Text.t("RM-04-10")), "好奇高时写好奇的那句")
	GameState.week = 2
	var frozen := RoomRules.journal_text(1)
	GameState.stats["curiosity"] = 10
	_eq(RoomRules.journal_text(1), frozen, "过去的周记写定后不再变")
	GameState.reset()


func test_tech() -> void:
	GameState.reset()
	GameState.stats["mechanics"] = 44
	_ok(not RoomRules.is_tech_unlocked("generator"), "机械 44 不解锁发电")
	GameState.stats["mechanics"] = 45
	_ok(RoomRules.is_tech_unlocked("generator"), "机械 45 解锁发电")
	_eq(int(DataDB.row("tech", "generator")["need"]), int(DataDB.row("buildings", "generator")["unlock_mechanics"]), "科技门槛和建造门槛一致")
	_eq(RoomRules.tech_tree().size(), 3, "三个技能三列")
	GameState.reset()


func test_places_open_by_week() -> void:
	GameState.reset()
	_ok(RoomRules.is_place_open("machine"), "第 1 周能去机械室")
	_ok(not RoomRules.can_go_underground(), "第 1 周不能去地下")
	GameState.week = int(RoomRules.place("underground")["open_week"])
	_ok(RoomRules.can_go_underground(), "第 7 周能去地下")
	for row in RoomRules.elevator_places():
		_ok(row["id"] != "underground", "电梯里没有地下居民区")
	GameState.reset()


func test_room_view_clicks() -> void:
	var view := RoomView.new()
	view.scene_id = "cabin"
	add_child(view)
	await _frames(2)
	var talked := [false]
	var tablet := [false]
	var door := [false]
	view.talk_requested.connect(func() -> void: talked[0] = true)
	view.tablet_requested.connect(func() -> void: tablet[0] = true)
	view.door_requested.connect(func() -> void: door[0] = true)
	view.set_exclaim(true)
	view.click("girl")
	_ok(talked[0], "点她 → 聊天")
	view.click("tablet")
	_ok(tablet[0], "点平板 → 打开平板")
	view.click("door")
	_ok(door[0], "点门 → 电梯")
	view.click("bookshelf")
	_eq(view.info_text(), Text.t("RM-02-02"), "点书架看说明")
	view.click("model_ark")
	_ok(view.is_looking(), "点模型近看")
	view.stop_looking()
	_ok(not view.is_looking(), "退出近看")
	var lamp_before := RoomRules.is_on("lamp")
	view.click("lamp")
	_eq(RoomRules.is_on("lamp"), not lamp_before, "点台灯直接开关")
	var lamp_light: Light3D = view.bodies["lamp"].get_meta("light")
	_eq(lamp_light.visible, RoomRules.is_on("lamp"), "台灯的光跟着开关")
	view.click("plant")
	_eq(view.info_text(), Text.t("RM-02-04"), "点植物看说明和灯罩按钮")
	# 真模型里的玻璃罩跟着开关走
	var glass := view.viewport.find_child("EcoDome_Glass_Wall", true, false) as Node3D
	_ok(glass != null, "真模型里找得到玻璃罩")
	if glass != null:
		RoomRules.toggle("plant")
		view.refresh()
		_eq(glass.visible, RoomRules.is_on("plant"), "玻璃罩跟着开关")
		RoomRules.toggle("plant")
		view.refresh()
	view.queue_free()
	await _frames(1)


func test_hub_room() -> void:
	GameState.reset()
	var hub := HubScreen.new()
	add_child(hub)
	await _frames(2)
	_ok(hub.room != null, "主界面有房间")
	var chat := [false]
	hub.chat_pressed.connect(func() -> void: chat[0] = true)
	hub.room.click("girl")
	_ok(chat[0], "主界面点她进聊天")
	hub.room.click("tablet")
	_ok(hub.tablet != null and hub.tablet.visible, "平板打开")
	_ok(hub.tablet.journal_shown().contains(Text.f("RM-04-01", {"week": 1})), "平板周记显示本周")
	hub.room.click("door")
	_ok(hub.elevator != null and hub.elevator.visible, "电梯菜单打开")
	var chosen := [""]
	hub.place_pressed.connect(func(id: String) -> void: chosen[0] = id)
	hub.elevator.place_chosen.emit("greenhouse")
	_eq(chosen[0], "greenhouse", "选温室")
	hub.queue_free()
	await _frames(1)


func test_every_place_builds() -> void:
	for id: String in DataDB.table("places"):
		var screen := PlaceScreen.new()
		screen.place_id = id
		add_child(screen)
		await _frames(1)
		_ok(screen.view.bodies.size() > 0, "场所 %s 有东西" % id)
		screen.queue_free()
	_ok(GameState.flags.get(RoomRules.FLAG_UNDERGROUND, false), "去过地下会记下来")
	await _frames(1)


func _frames(count: int) -> void:
	for _i in count:
		await get_tree().process_frame


func _ok(condition: bool, message: String) -> void:
	_count += 1
	if not condition:
		_failures += 1
		print("失败：", message)


func _eq(actual: Variant, expected: Variant, message: String) -> void:
	_ok(actual == expected, "%s（期望 %s，实际 %s）" % [message, expected, actual])
