extends Node
## 从头点到结局的自动测试：像玩家一样按按钮，顺便给每种画面截图。
## 平时在后台运行，不弹窗口（yi 要求）：加 --headless，此时不截图。
## 只有需要看截图时才去掉 --headless：
## Godot_console.exe --path . res://scenes/tests/playthrough_test.tscn -- --out=截图文件夹
## 通过时退出码是 0。

const MainScene := preload("res://scenes/main.tscn")
const TitleScreen := preload("res://scripts/ui/title_screen.gd")
const StoryScreen := preload("res://scripts/ui/story_screen.gd")
const WEEKS := 7
const SETTLE_WAIT_SEC := 0.2
const HOVER_WAIT_SEC := 1.2
const WATCHDOG_SEC := 150.0

var _main: Control
var _step := "开始"
var _out_dir := ""
var _shot_names := {}
var _errors: PackedStringArray = []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
	# 卡死时自己退出并报失败，不要让测试永远挂着
	get_tree().create_timer(WATCHDOG_SEC).timeout.connect(_on_watchdog)
	# 存档和设置写到测试专用文件，不覆盖玩家的
	SaveSystem.save_path = "user://test_playthrough.sav"
	SaveSettings.settings_path = "user://test_playthrough_settings.cfg"
	SaveSystem.delete_save()
	_main = MainScene.instantiate()
	add_child(_main)
	await _frames()
	await _play()
	for error in _errors:
		print("失败：", error)
	print("流程测试结束，失败 %d 项" % _errors.size())
	get_tree().quit(1 if _errors.size() > 0 else 0)


func _on_watchdog() -> void:
	print("失败：测试超时，卡在：", _step)
	get_tree().quit(2)


func _play() -> void:
	await _start_new_game()
	await _shot("schedule")
	_set_first_week_plan()
	await _hover_shot("OptionButton", _first_course_name(), "hover_course")
	_click(Text.t("UI-04-08"))
	await _frames()
	await _finish_stories()

	for week in range(1, WEEKS + 1):
		_check(GameState.week == week, "应该在第 %d 周，实际第 %d 周" % [week, GameState.week])
		if week == 1:
			_check(GameState.get_stat("mechanics") == 0, "第 1 周还没上课")
			_check(_button_disabled(Text.t("UI-01-01")), "第 1 周小镇应该锁着")
		else:
			await _finish_settlement()
			_check(not _button_disabled(Text.t("UI-01-01")), "第 %d 周小镇应该开放" % week)
		if week == 2:
			_check(GameState.get_stat("mechanics") == 9, "第 2 周早上结算第一次的课，实际 %d" % GameState.get_stat("mechanics"))
			_check(GameState.get_stat("stamina") >= 0, "体力有效")
		await _shot("hub_w%d" % week)
		if week == 1:
			await _hover_course_again()
			await _try_chat()
		if week == 2:
			await _visit_town()
		if week == 3:
			await _build_power_and_water()
		else:
			_click(Text.t("UI-01-04"))
			await _frames()
			_confirm_end_week()
			await _frames()
		await _finish_stories()
		await _shot("summary_w%d" % week)
		_click(Text.t("UI-06-01"))
		await _frames()
		await _finish_stories()  # 周结算后的夜里剧情（week_night）、第 3 周后的蒙太奇（time_jump）
		if week == 3:
			_check(GameState.age == 15, "第 3 周后应该 15 岁")
			await _shot("jump")
			_click(Text.t("TJ-03-10"))
			await _frames()
			await _finish_stories()

	# 第 7 周结算后：结局和尾声都是剧情（上面已跳过），播完直接到制作人员名单
	await _finish_stories()
	_check(GameState.cognition == GameState.Cognition.BELIEVE, "结局前她已经相信地球是真的")
	await _shot("credits")
	_click(Text.t("UI-56-09"))
	await _frames()
	_check(_main.current is TitleScreen, "制作人员名单后应该回到标题页")
	# 继续：读第 7 周开始时的自动存档
	_click(Text.t("UI-50-03"))
	await _frames()
	_check(GameState.week == WEEKS and GameState.age == 15, "继续应该回到第 %d 周，实际第 %d 周" % [WEEKS, GameState.week])
	SaveSystem.delete_save()


## 标题页 → 开始游戏 → 起名（用默认名字）→ 开场剧情
func _start_new_game() -> void:
	_step = "标题页"
	_check(_main.current is TitleScreen, "启动后应该是标题页")
	await _shot("title")
	_click(Text.t("UI-50-02"))
	await _frames()
	await _shot("naming")
	_click(Text.t("UI-51-04"))
	await _frames()
	await _finish_stories()


## 有剧情在播就一路跳过，遇到选择选第一个
func _finish_stories() -> void:
	for _i in 50:
		if not _main.current is StoryScreen:
			return
		var story: Control = _main.current
		await _seconds(0.05)
		await story.skip()
		await _frames()
		if story == _main.current and story.line != null:
			story.choose(0)
			await _frames()
	_check(false, "剧情没有播完")


## 小镇画面上盖着播的剧情（进小镇时的 earth_enter 等）：一路跳过，遇到选择选第一个
func _finish_overlay_stories(earth: Node) -> void:
	for _i in 20:
		var stories := _find_all(earth, "Control").filter(func(n: Node) -> bool: return n is StoryScreen and not n.is_queued_for_deletion())
		if stories.is_empty():
			return
		var story: Control = stories[0]
		await story.skip()
		await _frames()
		if is_instance_valid(story) and not story.is_queued_for_deletion() and story.line != null:
			story.choose(0)
			await _frames()


## 第一次排课，周一到周日：3 节机械课、休息、2 节生态课、休息
func _set_first_week_plan() -> void:
	var plan := ["mechanics", "mechanics", "mechanics", "rest", "ecology", "ecology", "rest"]
	var pickers := _find_all(_main.current, "OptionButton")
	_check(pickers.size() == 7, "课表应该有 7 天")
	var ids: Array = DataDB.table("courses").keys()
	for day in pickers.size():
		pickers[day].select(ids.find(plan[day]))


## 进课表再悬停一次：这时模型已加载完，画面不再卡
func _hover_course_again() -> void:
	_click(Text.t("UI-01-03"))
	await _frames()
	await _hover_shot("OptionButton", _first_course_name(), "hover_course2")
	_click(Text.t("UI-04-05"))
	await _frames()


func _first_course_name() -> String:
	return Text.t("CR-NAME-01")


func _finish_settlement() -> void:
	await get_tree().create_timer(SETTLE_WAIT_SEC).timeout
	await _shot("settlement")
	_click(Text.t("UI-06-01"))  # 第一次放完剩下的行
	await _frames()
	_click(Text.t("UI-06-01"))  # 第二次离开
	await _frames()
	await _finish_stories()  # 早上的剧情（week_start）


## 把本周的轮数全部聊完，最后再点一次聊天，确认她只回一句
func _try_chat() -> void:
	_click(Text.t("UI-01-02"))
	await _frames()
	var input: LineEdit = _find_all(_main.current, "LineEdit")[0]
	var total: int = WeekSystem.chat_rounds_left()
	_check(total == 6, "第 1 周应该有 6 轮，实际 %d" % total)
	_step = "第一轮聊天"
	input.text_submitted.emit("你今天过得怎么样？")
	await _wait_round(total - 1)
	await _shot("chat")
	for left in range(total - 2, -1, -1):
		var options := _find_all(_main.current, "Button").filter(func(b: Button) -> bool: return b.visible and not b.disabled and b.text != Text.t("UI-09-03") and b.text != Text.t("UI-09-05"))
		_check(options.size() == 3, "应该有 3 个选项")
		_step = "聊天，剩 %d 轮" % left
		print(_step)
		options[0].pressed.emit()
		await _wait_round(left)
	await _frames()
	await _shot("chat_end")
	var log_box: RichTextLabel = _find_all(_main.current, "RichTextLabel")[0]
	print("---- 对话记录 ----
", log_box.get_parsed_text(), "----")
	_click(Text.t("UI-09-05"))
	await _frames()
	_click(Text.t("UI-01-02"))
	await _frames()
	var again: RichTextLabel = _find_all(_main.current, "RichTextLabel")[0]
	_check(again.get_parsed_text().contains(Text.t("FB-03-01")), "轮数用完后她只回一句")
	_click(Text.t("UI-09-05"))
	await _frames()
	await _test_timeout()


## 超时后模型要能停下来，之后还能继续用
func _test_timeout() -> void:
	if ModelService.status != ModelService.Status.READY:
		print("模型未加载：跳过超时测试，本次聊天全部是后备句")
		return
	_step = "超时测试"
	print(_step)
	var text: String = await ModelService._generate("说一个很长的故事", 0.05)
	_step = "超时后再问一句"
	print(_step)
	_check(text.is_empty(), "超时应该返回空")
	var reply: Dictionary = await ModelService.ask("你好")
	_check(not reply["fallback"], "超时后模型应该还能用")


func _wait_round(expected_left: int) -> void:
	var start := Time.get_ticks_msec()
	while WeekSystem.chat_rounds_left() != expected_left and Time.get_ticks_msec() - start < 120000:
		await get_tree().create_timer(0.05).timeout
	_check(WeekSystem.chat_rounds_left() == expected_left, "这一轮应该剩 %d 轮" % expected_left)
	await _frames()


## 小镇：清理广场、切换视角、拆并捡小废料（第 2 周）
func _visit_town() -> void:
	_step = "小镇俯视"
	_click(Text.t("UI-01-01"))
	await _frames()
	var earth: Control = _main.current
	await _finish_overlay_stories(earth)
	await _seconds(0.3)
	await _shot("earth_card")
	_dismiss_girl_card(earth)
	await _frames()
	await _shot("earth_top")
	# 用真实的鼠标事件点地面，确认点击能穿过界面落到场景上
	await _mouse_click_cell(earth, Vector2i(12, 7))
	_check(earth.selected_ruin == "plaza", "鼠标点废墟应该选中广场，实际 [%s]" % earth.selected_ruin)
	await _shot("earth_selected")
	_click(Text.f("UI-16-08", {"work": 2}))
	await _frames()
	_check(GameState.earth.queue.size() == 1, "清理应该进队列")
	_check(GameState.earth.work_units_left() == 4, "清理占 2 个工作单位")
	await _seconds(2.0)
	await _shot("earth_robots")
	var robot: RobotAgent = earth._robots[0]
	_check(robot.state != RobotAgent.State.IDLE, "机器人应该去干活")

	_step = "小镇第三人称"
	_press_key(KEY_V)
	await _frames()
	_check(earth.third_person, "按 V 应该切到第三人称")
	var ark: ArkController = earth.ark
	var start_position: Vector3 = ark.position
	await _hold_key(KEY_W, 0.4)
	_check(ark.position.distance_to(start_position) > 0.5, "按 W 应该走动")
	ark.position = earth.view.cell_center(Vector2i(8, 13))
	await _seconds(0.5)
	await _shot("earth_third")
	var target: String = ark.nearest_small_ruin()
	_check(target == "scrap1", "应该在小废料旁边，实际 [%s]" % target)
	await _hold_key(KEY_E, float(DataDB.balance("ark_cut_seconds")) + 0.3)
	_check(GameState.earth.scraps.size() == 1, "按住 E 应该拆下废料")
	_press_key(KEY_F)
	await _frames()
	_check(GameState.earth.metal == 1, "捡到金属，实际 %d" % GameState.earth.metal)
	_press_key(KEY_Q)
	await _frames()
	await _shot("earth_scan")
	_press_key(KEY_V)
	await _frames()
	_check(not earth.third_person, "按 V 回到俯视")
	_click(Text.t("UI-17-04"))
	await _frames()


## 第 3 周：用测试键加满，接上水电，看通电、缺水和周结算
func _build_power_and_water() -> void:
	_step = "小镇水电"
	_click(Text.t("UI-01-01"))
	await _frames()
	var earth: Control = _main.current
	await _finish_overlay_stories(earth)
	_dismiss_girl_card(earth)
	var world: EarthWorld = GameState.earth
	_check(world.ruins["plaza"]["cleared"], "广场废墟上周应该清理完")
	_check(world.metal >= 5, "清理后应该有金属，实际 %d" % world.metal)
	earth.debug_boost()
	for spec: Array in [["farm_plot", 6, 7], ["generator", 0, 3], ["purifier", 3, 2]]:
		earth.start_placing(spec[0])
		_check(earth.place_at(Vector2i(spec[1], spec[2])) != 0, "应该能放 %s" % spec[0])
	await _seconds(0.3)
	await _shot("earth_blueprints")
	earth.start_placing("repair_station")
	await _frames()
	_check(world.building_at(Vector2i(4, 4)) != 0, "维修站点一下就下单到固定位置")
	# 用真实的鼠标事件放供电节点
	earth.start_placing("power_node")
	await _seconds(0.2)
	await _shot("earth_ghost")
	await _mouse_click_cell(earth, Vector2i(20, 12))
	_check(world.building_at(Vector2i(20, 12)) != 0, "鼠标点地面应该放下供电节点")
	earth.cancel_placing()
	_click(Text.t("UI-01-04"))
	await _frames()
	_confirm_end_week()
	await _frames()
	await _finish_stories()  # 第 3 周没走到植物旁边：结束本周时先播保底的植物事件
	await _shot("summary_earth")
	var farm := world.building_at(Vector2i(6, 7))
	_check(world.problems(farm).has(EarthWorld.WATER_PROBLEM), "种植区应该缺水")


func _confirm_end_week() -> void:
	var dialogs := _find_all(_main.current, "ConfirmationDialog")
	_check(dialogs.size() == 1, "应该弹出确认框")
	dialogs[0].confirmed.emit()


## 把鼠标事件发给画面，确认悬停时真的弹出说明。不动玩家真实的鼠标。
func _hover_shot(type_name: String, text_start: String, shot_name: String) -> void:
	for node: Control in _find_all(_main.current, type_name):
		if node.text.begins_with(text_start):
			# 刚开窗口时第一个鼠标事件可能只算"进入窗口"，所以发两次
			for offset in [Vector2.ZERO, Vector2.ONE]:
				var motion := InputEventMouseMotion.new()
				motion.position = node.get_global_rect().get_center() + offset
				motion.global_position = motion.position
				get_viewport().push_input(motion)
				await _frames()
			await get_tree().create_timer(HOVER_WAIT_SEC).timeout
			await _shot(shot_name)
			return
	_check(false, "找不到要悬停的控件：%s" % text_start)


## 她的方案和突发事件是随机出现的；测试里遇到就回答掉，不影响后面的步骤
func _dismiss_girl_card(earth: Control) -> void:
	if not earth.proposal.is_empty():
		earth.answer_proposal(GirlEarth.EXPLAIN)
	if not earth.event.is_empty():
		earth.answer_event("rest")


func _mouse_click_cell(earth: Control, cell: Vector2i) -> void:
	# 后台运行没有窗口，鼠标坐标算不出来，直接调同一个处理函数；开窗口运行时才测真实鼠标
	if DisplayServer.get_name() == "headless":
		if earth.placing_type.is_empty():
			earth.select_cell(cell)
		else:
			earth.place_at(cell)
		await _frames()
		return
	var screen: Vector2 = earth.top_camera.unproject_position(earth.view.cell_center(cell))
	for pressed: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = screen
		click.global_position = screen
		get_viewport().push_input(click)
		await _frames()


## 通过 Input 模拟一直按住一个键，这样走动和切割的代码读到的和真实键盘一样
func _hold_key(key: Key, duration: float) -> void:
	var down := InputEventKey.new()
	down.physical_keycode = key
	down.pressed = true
	Input.parse_input_event(down)
	await _seconds(duration)
	var up := InputEventKey.new()
	up.physical_keycode = key
	up.pressed = false
	Input.parse_input_event(up)
	await _frames()


func _button_disabled(text: String) -> bool:
	for button: Button in _find_all(_main.current, "Button"):
		if button.text == text:
			return button.disabled
	_check(false, "找不到按钮：%s" % text)
	return true


func _press_key(key: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = true
	get_viewport().push_input(event)
	var release := InputEventKey.new()
	release.physical_keycode = key
	get_viewport().push_input(release)


func _seconds(duration: float) -> void:
	await get_tree().create_timer(duration).timeout


func _click(text: String) -> void:
	for button: Button in _find_all(_main.current, "Button"):
		if button.text == text and not button.disabled:
			button.pressed.emit()
			return
	_check(false, "找不到按钮：%s" % text)


func _find_all(node: Node, type_name: String) -> Array:
	var found := node.find_children("*", type_name, true, false)
	return found


func _frames() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


func _shot(shot_name: String) -> void:
	# 后台（--headless）运行时没有画面，跳过截图
	if _out_dir.is_empty() or _shot_names.has(shot_name) or DisplayServer.get_name() == "headless":
		return
	_shot_names[shot_name] = true
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out_dir.path_join(shot_name + ".png"))


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
