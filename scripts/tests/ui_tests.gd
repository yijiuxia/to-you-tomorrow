extends Node
## 界面、存档、设置、剧情播放器的自动测试（界面线程）。运行方法（后台跑，不弹窗口）：
## Godot_console.exe --headless --path . res://scenes/tests/ui_tests.tscn -- --model=none.gguf
## 全部通过时退出码是 0。

const MainScene := preload("res://scenes/main.tscn")
const StoryScreen := preload("res://scripts/ui/story_screen.gd")
const NameScreen := preload("res://scripts/ui/name_screen.gd")
const TitleScreen := preload("res://scripts/ui/title_screen.gd")
const ScheduleScreen := preload("res://scripts/ui/schedule_screen.gd")
const WATCHDOG_SEC := 60.0
const DictObject := preload("res://scripts/tests/ui_test_dict_object.gd")

var _failures := 0
var _count := 0


func _ready() -> void:
	get_tree().create_timer(WATCHDOG_SEC).timeout.connect(func() -> void:
		print("失败：测试超时")
		get_tree().quit(2))
	# 界面测试用不到模型。模型还在加载时退出，NobodyWho 的后台线程会让程序崩溃（退出码 -1073741819），
	# 所以先标记成"没有模型"，main 就不会去加载
	ModelService.status = ModelService.Status.FAILED
	SaveSystem.save_path = "user://test_ui.sav"
	SaveSettings.settings_path = "user://test_ui_settings.cfg"
	SaveSystem.delete_save()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveSettings.settings_path))

	test_every_text_has_both_languages()
	test_language_switch()
	test_name_cleaning()
	test_save_round_trip()
	test_broken_save_is_ignored()
	test_save_uses_to_dict()
	test_settings_round_trip()
	test_story_triggers_and_fallback()
	await test_story_runner_choice_changes_state()
	await test_story_screen_skip()
	await test_week3_plant_and_seed_jar()
	await test_play_over()
	test_time_jump_seed_line()
	await test_title_to_first_week_and_pause()

	SaveSystem.delete_save()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveSettings.settings_path))
	print("界面测试 %d 项，失败 %d 项" % [_count, _failures])
	get_tree().paused = false
	await _frames(3)  # 等测试里建的画面真正释放完再退出
	get_tree().quit(1 if _failures > 0 else 0)


## 中英文都要写（CLAUDE.md 多线程规则 3）。新加的编号漏了英文，这里会列出来。
func test_every_text_has_both_languages() -> void:
	var missing: PackedStringArray = []
	for key: String in Text.all_keys():
		for lang: String in SaveSettings.LANGUAGES:
			if not Text.has_language(key, lang):
				missing.append("%s(%s)" % [key, lang])
	_ok(missing.is_empty(), "所有文字都有中英文，缺：" + ", ".join(missing))


func test_language_switch() -> void:
	Text.language = "en"
	_eq(Text.t("UI-50-02"), "New Game", "切到英文")
	_eq(Text.t("UI-01-01"), "Earth Build", "原表里写的英文优先")  # 11.19 "小镇"按钮改名"地球建造"
	_eq(Text.t("UI-06-01"), "Continue", "补充表里的英文生效")
	Text.language = "zh"
	_eq(Text.t("UI-50-02"), "开始游戏", "切回中文")


func test_name_cleaning() -> void:
	_eq(NameScreen.clean_name("  {小}禾 "), "小禾", "名字去掉空格和花括号")


func test_save_round_trip() -> void:
	GameState.reset()
	GameState.week = 4
	GameState.age = 15
	GameState.girl_name = "测试名"
	GameState.change_stat("trust", 7)
	GameState.flags["story_seen_op"] = true
	GameState.schedule[0] = "mechanics"
	GameState.cognition = GameState.Cognition.DOUBT
	GameState.earth.metal = 33
	var trust := GameState.get_stat("trust")
	var cells := GameState.earth.pollution.size()
	_ok(SaveSystem.save(), "能写存档")
	_ok(SaveSystem.has_save(), "存档文件存在")
	_eq(SaveSystem.summary().get("week"), 4, "标题页能看到存档周数")

	GameState.reset()
	_eq(GameState.week, 1, "重置后回到第 1 周")
	_ok(SaveSystem.load_save(), "能读存档")
	_eq(GameState.week, 4, "周数读回来")
	_eq(GameState.age, 15, "年龄读回来")
	_eq(GameState.girl_name, "测试名", "名字读回来")
	_eq(GameState.get_stat("trust"), trust, "属性读回来")
	_eq(GameState.flags.get("story_seen_op"), true, "剧情标记读回来")
	_eq(GameState.schedule[0], "mechanics", "课表读回来")
	_eq(GameState.cognition, GameState.Cognition.DOUBT, "认知状态读回来")
	_eq(GameState.earth.metal, 33, "地球材料读回来")
	_eq(GameState.earth.pollution.size(), cells, "地球格子读回来")
	_ok(GameState.earth.pollution.keys()[0] is Vector2i, "格子坐标还是 Vector2i")
	_eq(GameState.earth.ark_position, Vector3.INF, "ARK-01 没去过时位置保持 INF")
	SaveSystem.delete_save()
	_ok(not SaveSystem.has_save(), "能删存档")
	GameState.reset()


## 记忆这类自己会转字典的对象：存档用它的 to_dict() / from_dict()
func test_save_uses_to_dict() -> void:
	var holder := DictHolder.new()
	holder.store = DictObject.from_dict({"items": ["a", "b"]})
	var packed := SaveSystem._pack(holder)
	_ok(packed["store"].has(SaveSystem.DICT_KEY), "存档调用了 to_dict")
	var restored := DictHolder.new()
	SaveSystem._unpack(restored, str_to_var(var_to_str(packed)))
	_ok(restored.store is DictObject, "读档用 from_dict 还原对象")
	_eq(restored.store.items, ["a", "b"], "对象内容还原")


func test_broken_save_is_ignored() -> void:
	var file := FileAccess.open(SaveSystem.save_path, FileAccess.WRITE)
	file.store_string("这不是存档")
	file.close()
	GameState.week = 3
	_ok(not SaveSystem.load_save(), "坏存档读取失败")
	_eq(GameState.week, 3, "坏存档不改动游戏状态")
	_ok(SaveSystem.summary().is_empty(), "坏存档在标题页不显示")
	SaveSystem.delete_save()
	GameState.reset()


func test_settings_round_trip() -> void:
	SaveSettings.load_and_apply()
	_eq(SaveSettings.text_speed, int(DataDB.balance("ui_text_speed_default")), "没有设置文件时用默认文字速度")
	SaveSettings.volume = 30
	SaveSettings.text_speed = 9999
	SaveSettings.language = "en"
	SaveSettings.save_settings()
	_eq(SaveSettings.text_speed, int(DataDB.balance("ui_text_speed_max")), "文字速度截在上限")
	_eq(Text.language, "en", "设置语言后文字表跟着换")
	SaveSettings.volume = 0
	SaveSettings.language = "zh"
	SaveSettings.load_and_apply()
	_eq(SaveSettings.volume, 30, "音量读回来")
	_eq(SaveSettings.language, "en", "语言读回来")
	SaveSettings.language = "xx"
	SaveSettings.apply()
	_eq(Text.language, "zh", "不认识的语言退回中文")
	SaveSettings.save_settings()


func test_story_triggers_and_fallback() -> void:
	GameState.reset()
	var ids := _ids(StoryTriggers.pick("new_game"))
	_ok("op" in ids, "新游戏播开场")
	StoryTriggers.mark_seen("op")
	_ok(not "op" in _ids(StoryTriggers.pick("new_game")), "播过的不再播")
	_ok(not "w5_alarm" in _ids(StoryTriggers.pick("week_end")), "不是第 5 周不播保底")
	GameState.week = 5
	_ok("w5_alarm" in _ids(StoryTriggers.pick("week_end")), "第 5 周没发现线索：播保底")
	GameState.flags["w5_trace_found"] = true
	_ok(not "w5_alarm" in _ids(StoryTriggers.pick("week_end")), "已经发现线索：不播保底")
	_ok(StoryTriggers.check("week() == 5 and stat(\"trust\") >= 0"), "条件能用周数和属性")
	_ok(not StoryTriggers.check("这不是条件("), "写错的条件算不满足")
	_ok(StoryTriggers.check(""), "空条件算满足")
	GameState.reset()


func test_story_runner_choice_changes_state() -> void:
	GameState.reset()
	var trust := GameState.get_stat("trust")
	var runner := StoryRunner.new()
	var line := await runner.start("op.dialogue", "start")
	_ok(line != null, "开场能读到第一句")
	if line == null:
		return
	_eq(StoryRunner.text_of(line), Text.t("OP-01-01"), "台词按编号取文字表")
	_eq(StoryRunner.speaker_of(line), "", "旁白不显示名字")
	line = await runner.next(line.next_id)
	_eq(StoryRunner.speaker_of(line), GameState.girl_name, "girl 显示她的名字")
	_eq(line.responses.size(), 2, "开场有两个选项")
	Text.language = "en"
	_eq(StoryRunner.text_of(line.responses[0]), Text.t("OP-01-03"), "选项也能显示英文")
	Text.language = "zh"
	line = await runner.next(line.responses[0].next_id)
	_eq(GameState.get_stat("trust"), trust + int(DataDB.balance("story_op_greet_trust")), "选项改了属性")
	var count := 0
	while line != null and count < 20:
		line = await runner.next(line.next_id)
		count += 1
	_ok(line == null, "开场能走到结尾")
	GameState.reset()


func test_story_screen_skip() -> void:
	GameState.reset()
	GameState.week = 5
	var screen := StoryScreen.new()
	screen.node = StoryTriggers.pick("week_end")[0]
	var done := [false]
	screen.finished.connect(func() -> void: done[0] = true)
	add_child(screen)
	await _frames(3)
	_ok(screen.line != null, "剧情画面显示了第一句")
	await screen.skip()
	await _frames(2)
	_ok(done[0], "跳过能走到结尾")
	_ok(GameState.flags.get("w5_trace_found", false), "跳过时改状态照样执行")
	_ok(StoryTriggers.is_seen("w5_alarm"), "播完记为已播")
	screen.queue_free()
	GameState.reset()


## 第 3 周：植物事件设标记、给 ARK-01 起名；种子罐先找到 / 后找到说法不同（文案 05_第3周）
func test_week3_plant_and_seed_jar() -> void:
	GameState.reset()
	GameState.week = 3
	_ok("w3_plant_fallback" in _ids(StoryTriggers.pick("week_end")), "第 3 周没看过植物：结束本周时保底播")
	# 第 2 周先找到种子罐
	GameState.flags["seed_jar_found"] = true
	var said := await _play_all("w3.dialogue", "seed_jar")
	_ok("W3-04-08" in said and not "W3-04-05" in said, "植物事件前找到：先收好")
	said = await _play_all("w3.dialogue", "plant")
	_ok(GameState.flags.get("plant_event_done", false), "植物事件播完设 plant_event_done")
	_eq(StoryRunner.ark_name(), Text.t("UI-54-06"), "ARK-01 有了名字")
	_ok("W3-03-19" in said and not "W3-04-01" in said, "已有种子罐：起名后说我们有种子")
	_ok(said.find("W3-05-05") < said.find("W3-03-19"), "W3-03-19 在起名之后")
	_ok(not "w3_plant_fallback" in _ids(StoryTriggers.pick("week_end")), "看过植物事件后不再保底")
	# 植物事件后才找到
	GameState.reset()
	GameState.week = 3
	said = await _play_all("w3.dialogue", "plant")
	_ok("W3-04-01" in said and not "W3-03-19" in said, "还没种子罐：引导去维修站")
	GameState.flags["seed_jar_found"] = true
	said = await _play_all("w3.dialogue", "seed_jar")
	_ok("W3-04-05" in said and not "W3-04-08" in said, "植物事件后找到：可以自己种了")
	Text.language = "en"
	_ok(StoryRunner.text_of(await StoryRunner.new().start("w3.dialogue", "seed_jar")).begins_with("Scanner"), "第 3 周台词有英文")
	Text.language = "zh"
	GameState.reset()


func test_play_over() -> void:
	GameState.reset()
	GameState.week = 3
	var parent := Node.new()
	add_child(parent)
	_ok(StoryScreen.play_over(parent, "没有这个时刻") == null, "没有剧情时返回 null")
	var holder := StoryScreen.play_over(parent, "earth_plant_found")
	_ok(holder != null, "地球画面上能播植物事件")
	await _frames(3)
	var screen: StoryScreen = holder.get_child(0)
	await screen.skip()
	await _frames(3)
	_ok(GameState.flags.get("plant_event_done", false), "盖在上面播也会设标记")
	_ok(not is_instance_valid(holder) or holder.is_queued_for_deletion(), "播完自己消失")
	parent.queue_free()
	GameState.reset()


func test_time_jump_seed_line() -> void:
	GameState.reset()
	var before := GameState.stats.duplicate()
	GameState.flags["seeds_from_plant"] = true
	_ok(Text.t("UI-54-07") in PageText.time_jump(before, 8), "没找到种子罐：这些年页写植物结了种子")
	GameState.flags["seed_jar_found"] = true
	_ok(not Text.t("UI-54-07") in PageText.time_jump(before, 8), "找到过种子罐：不写这一行")
	GameState.reset()


## 从某个标记一路走到结尾（选项都选第一个），返回经过的台词编号
func _play_all(file_name: String, cue: String) -> PackedStringArray:
	var said: PackedStringArray = []
	var runner := StoryRunner.new()
	var line := await runner.start(file_name, cue)
	var guard := 0
	while line != null and guard < 100:
		said.append(line.static_id)
		var next_id := line.next_id if line.responses.is_empty() else (line.responses[0] as DialogueResponse).next_id
		line = await runner.next(next_id)
		guard += 1
	return said


func test_title_to_first_week_and_pause() -> void:
	var main: Control = MainScene.instantiate()
	add_child(main)
	await _frames(2)
	_ok(main.current is TitleScreen, "启动是标题页")
	_ok(_button(main.current, Text.t("UI-50-03")).disabled, "没有存档时不能继续")
	_button(main.current, Text.t("UI-50-02")).pressed.emit()
	await _frames(2)
	_ok(main.current is NameScreen, "开始游戏后起名")
	var naming: NameScreen = main.current
	naming.girl_input.text = "小禾"
	naming.player_input.text = ""
	naming.confirm()
	await _frames(2)
	_eq(GameState.girl_name, "小禾", "她的名字改了")
	_eq(GameState.player_name, Text.t("UI-51-06"), "你的名字空着用默认")
	_ok(main.current is StoryScreen, "起名后播开场")
	var story: StoryScreen = main.current
	await _frames(2)
	await story.skip()
	story.choose(1)
	await _frames(2)
	await story.skip()
	await _frames(2)
	_ok(main.current is ScheduleScreen, "开场后排第一周的课")
	_ok(SaveSystem.has_save(), "第 1 周开始已自动存档")

	var esc := InputEventKey.new()
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	main._input(esc)
	_ok(get_tree().paused and main.pause_menu.is_open(), "Esc 打开暂停")
	main.pause_menu.close()
	_ok(not get_tree().paused, "关闭暂停后继续")

	main.show_title()
	await _frames(2)
	_ok(not _button(main.current, Text.t("UI-50-03")).disabled, "有存档时能继续")
	main.continue_game()
	await _frames(2)
	_ok(main.current is ScheduleScreen, "继续回到第 1 周排课")
	_eq(GameState.girl_name, "小禾", "继续后名字还在")
	main.queue_free()
	await _frames(1)


func _ids(nodes: Array[Dictionary]) -> Array:
	return nodes.map(func(n: Dictionary) -> String: return n["id"])


func _button(root: Node, text: String) -> Button:
	for button: Button in root.find_children("*", "Button", true, false):
		if button.text == text:
			return button
	_ok(false, "找不到按钮：" + text)
	return Button.new()


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


class DictHolder:
	extends RefCounted
	var store: RefCounted = null
