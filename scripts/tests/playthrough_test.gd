extends Node
## 从头点到结局的自动测试：像玩家一样按按钮，顺便给每种画面截图。
## 运行（要截图不能加 --headless）：
## Godot_console.exe --path . res://scenes/tests/playthrough_test.tscn -- --out=截图文件夹
## 通过时退出码是 0。

const MainScene := preload("res://scenes/main.tscn")
const WEEKS := 6
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
	await _shot("schedule")
	_set_first_week_plan()
	await _hover_shot("OptionButton", _first_course_name(), "hover_course")
	_click(Text.t("UI-04-08"))
	await _frames()

	for week in range(1, WEEKS + 1):
		_check(GameState.week == week, "应该在第 %d 周，实际第 %d 周" % [week, GameState.week])
		await _finish_settlement()
		await _shot("hub_w%d" % week)
		if week == 1:
			await _hover_shot("Label", UiKit.stat_name("confidence"), "hover_stat")
		if week == 1:
			await _hover_course_again()
			await _try_chat()
			await _visit_town()
		_click(Text.t("UI-01-04"))
		await _frames()
		_confirm_end_week()
		await _frames()
		await _shot("summary_w%d" % week)
		_click(Text.t("UI-06-01"))
		await _frames()
		if week == 2:
			_check(GameState.age == 15, "第 2 周后应该 15 岁")
			await _shot("jump")
			_click(Text.t("UI-06-01"))
			await _frames()

	await _shot("ending")
	_click(Text.t("ED-03-01"))
	await _frames()
	_check(GameState.week == 1 and GameState.age == 8, "结局后应该回到新游戏")
	_check(GameState.get_stat("mechanics") == 0, "新游戏属性应该重置")


## 第 1 周周一到周日：3 节机械课、休息、2 节生态课、休息
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


func _visit_town() -> void:
	_click(Text.t("UI-01-01"))
	await _frames()
	await _shot("town")
	_click(Text.t("UI-08-02"))
	await _frames()


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
	if _out_dir.is_empty() or _shot_names.has(shot_name):
		return
	_shot_names[shot_name] = true
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out_dir.path_join(shot_name + ".png"))


func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
