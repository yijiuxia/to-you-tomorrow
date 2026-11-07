extends Control
## 聊天：自由打字或点 3 个选项。模型给标签，数值由 ChatRules 决定。

signal finished

const OPTION_BUTTON_COUNT := 3
const LAST_ROUND := 1

var _rounds_label: Label
var _log: RichTextLabel
var _input: LineEdit
var _send: Button
var _thinking: Label
var _option_buttons: Array[Button] = []
var _busy := false
var _conversation_started := false  # 模型可能还在加载，人设设好之前不能发话


func _ready() -> void:
	var box := UiKit.page(self)
	_rounds_label = UiKit.title(box, "")
	_log = RichTextLabel.new()
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.scroll_following = true
	_log.selection_enabled = true
	box.add_child(_log)
	_thinking = UiKit.label(box, "")
	for i in OPTION_BUTTON_COUNT:
		var option := UiKit.button(box, "", _on_option.bind(i))
		option.visible = false
		_option_buttons.append(option)
	var line := UiKit.row(box)
	_input = LineEdit.new()
	_input.placeholder_text = Text.t("UI-09-02")
	_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input.text_submitted.connect(_on_submitted)
	line.add_child(_input)
	_send = UiKit.button(line, Text.t("UI-09-03"), func() -> void: _on_submitted(_input.text))
	UiKit.button(line, Text.t("UI-09-05"), func() -> void: finished.emit())

	if WeekSystem.chat_rounds_left() <= 0:
		# 轮数用完：她只回一句，不聊了（demo 文案）
		_add_line(Text.f("UI-09-06", {"girl": GameState.girl_name, "text": Text.t("FB-03-01")}))
		_set_input_enabled(false)
	else:
		_input.grab_focus()
		_begin_conversation()
	_refresh_rounds()


func _begin_conversation() -> void:
	await ModelService.start_conversation(ChatPrompt.build(_is_closing_round()))
	_conversation_started = true


func _is_closing_round() -> bool:
	return WeekSystem.chat_rounds_left() == LAST_ROUND


func _on_option(index: int) -> void:
	_on_submitted(_option_buttons[index].text)


func _on_submitted(raw_text: String) -> void:
	var text := raw_text.strip_edges()
	if text.is_empty() or _busy or WeekSystem.chat_rounds_left() <= 0:
		return
	_busy = true
	_input.clear()
	_set_input_enabled(false)
	_add_line(Text.f("UI-09-07", {"text": text}))
	_thinking.text = Text.t("UI-09-04")
	while not _conversation_started:
		await ModelService.get_tree().process_frame  # 用 ModelService 的：玩家离开后这个画面已不在场景里
	if not is_inside_tree():
		return
	if _is_closing_round():
		ModelService.update_prompt(ChatPrompt.build(true))

	var reply := await ModelService.ask(text)
	if not is_inside_tree():
		return  # 等回复时玩家已经离开了这个画面
	_thinking.text = ""
	_apply_reply(reply, text)
	_busy = false
	_set_input_enabled(WeekSystem.chat_rounds_left() > 0)
	if WeekSystem.chat_rounds_left() > 0:
		_input.grab_focus()
	_refresh_rounds()


func _apply_reply(reply: Dictionary, player_text: String) -> void:
	_add_line(Text.f("UI-09-06", {"girl": GameState.girl_name, "text": reply["reply"]}))
	_add_line(Text.f("UI-09-08", {"emotion": Text.t("UI-11-" + str(reply["emotion"]))}))
	GameState.chat_rounds_left -= 1
	if str(reply["intent"]) != "none":
		GameState.girl_intent = reply["intent"]
	# 后备句不是她真的听懂了，不能据此改数值
	if not reply["fallback"]:
		var changes := ChatRules.round_changes(reply["player_attitude"], player_text, GameState.chat_week_changes)
		for id: String in changes:
			GameState.change_stat(id, changes[id])
	var has_more := WeekSystem.chat_rounds_left() > 0
	for i in OPTION_BUTTON_COUNT:
		_option_buttons[i].text = reply["options"][i]
		_option_buttons[i].visible = has_more


func _refresh_rounds() -> void:
	_rounds_label.text = Text.f("UI-09-01", {"rounds": WeekSystem.chat_rounds_left()})


func _set_input_enabled(enabled: bool) -> void:
	_input.editable = enabled
	_send.disabled = not enabled
	for option in _option_buttons:
		option.disabled = not enabled


func _add_line(text: String) -> void:
	_log.add_text(text + "\n")
