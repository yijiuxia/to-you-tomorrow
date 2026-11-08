class_name ChatEventPanel
extends PanelContainer
## 突发事件对话（比赛版 4.3）：她先开口，2～4 轮，自由打字或点三个选项，
## 结束后按最后一轮的 intent 发出 finished(intent)，地球线程按它执行结果。
## 打开时游戏暂停（玩家打字时不计时），关掉时恢复。人物 AI 线程的文件。

signal finished(intent: String)

var event: Dictionary = {}
var _rounds_left := 0
var _intents: Array[String] = []
var _options: Array = []        # 当前三个选项：[文字, 已知的 intent 或 ""]
var _option_buttons: Array[Button] = []
var _title: Label
var _log: RichTextLabel
var _input: LineEdit
var _send: Button
var _busy := false
var _was_paused := false


func _init(for_event: Dictionary = {}) -> void:
	event = for_event


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_was_paused = get_tree().paused
	get_tree().paused = true
	set_anchors_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	custom_minimum_size = Vector2(float(DataDB.balance("chat_event_panel_width")), float(DataDB.balance("chat_event_panel_height")))
	var box := VBoxContainer.new()
	add_child(box)
	_title = UiKit.label(box, "")
	_log = RichTextLabel.new()
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.scroll_following = true
	box.add_child(_log)
	for i in ChatEvent.OPTION_COUNT:
		_option_buttons.append(UiKit.button(box, "", _on_option.bind(i)))
	var line := UiKit.row(box)
	_input = LineEdit.new()
	_input.placeholder_text = Text.t("UI-09-02")
	_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input.text_submitted.connect(_on_submitted)
	line.add_child(_input)
	_send = UiKit.button(line, Text.t("UI-09-03"), func() -> void: _on_submitted(_input.text))
	_rounds_left = ChatEvent.rounds_for()
	_set_options(ChatEvent.options(event))
	_open()


## 她先开口：用自己的话说出发生了什么，再按这件事设好这次对话的人设
func _open() -> void:
	_set_enabled(false)
	var opening := await ChatLines.earth_comment(Text.t(str(event["say_key"])))
	if not is_inside_tree():
		return
	_add_girl(opening["reply"])
	await ModelService.start_conversation(ChatPrompt.build(ChatEvent.situation(event, opening["reply"], _rounds_left)))
	if is_inside_tree():
		_refresh()
		_set_enabled(true)
		_input.grab_focus()


func _on_option(index: int) -> void:
	_send_line(str(_options[index][0]), str(_options[index][1]))


func _on_submitted(raw: String) -> void:
	_send_line(raw.strip_edges(), "")


## known_intent：点了固定选项就直接知道结果，不让模型猜
func _send_line(text: String, known_intent: String) -> void:
	if text.is_empty() or _busy or _rounds_left <= 0:
		return
	_busy = true
	_input.clear()
	_set_enabled(false)
	_log.add_text(Text.f("UI-09-07", {"text": text}) + "\n")
	var message := ChatPrompt.turn_message(text, "", false)
	if _rounds_left == 1:
		message += "\n" + Text.t("WK-14-02")
	var known := {}
	if not known_intent.is_empty():
		known = {"player_attitude": "neutral", "intent": known_intent}
	var reply := await ModelService.ask(message, text, known)
	if not is_inside_tree():
		return
	_rounds_left -= 1
	_intents.append(known_intent if not known_intent.is_empty() else str(reply["intent"]))
	_add_girl(reply["reply"])
	ModelService.last_action = reply["action"]
	if not reply["fallback"]:
		MemoryWriter.record_turn(GameState.memory, text, reply["reply"])
	_busy = false
	if _rounds_left <= 0:
		_finish()
		return
	# 之后的选项用模型给的（玩家说的三个方向）；模型失败时还用三个固定选项
	if reply["fallback"]:
		_set_options(ChatEvent.options(event))
	else:
		var next: Array = []
		for option: String in reply["options"]:
			next.append([option, ""])
		_set_options(next)
	_refresh()
	_set_enabled(true)
	_input.grab_focus()


func _finish() -> void:
	var intent := ChatEvent.final_intent(event, _intents)
	# 把这件事记成她的记忆：她怎么跟你说的、最后决定怎么做
	var summary := Text.f("WK-14-03", {"week": GameState.week, "event": ChatEvent.opening_text(event), "result": Text.t("UI-12-" + intent)})
	GameState.memory.remember_event(summary, MemoryStore.KIND_EVENT, int(DataDB.balance("memory_event_chat_importance")), GameState.week, GameState.age)
	finished.emit(intent)
	close()


## 关掉对话、恢复游戏（地球画面在结果定下后也会调用）
func close() -> void:
	if is_inside_tree():
		get_tree().paused = _was_paused
	queue_free()


func _exit_tree() -> void:
	if get_tree() != null and get_tree().paused and not _was_paused:
		get_tree().paused = false


func _set_options(options: Array) -> void:
	_options = options
	for i in _option_buttons.size():
		_option_buttons[i].text = str(options[i][0]) if i < options.size() else ""
		_option_buttons[i].visible = i < options.size()


func _refresh() -> void:
	_title.text = Text.f("UI-42-01", {"rounds": _rounds_left})


func _set_enabled(enabled: bool) -> void:
	_input.editable = enabled
	_send.disabled = not enabled
	for button in _option_buttons:
		button.disabled = not enabled


func _add_girl(text: String) -> void:
	_log.add_text(Text.f("UI-09-06", {"girl": GameState.girl_name, "text": text}) + "\n")
