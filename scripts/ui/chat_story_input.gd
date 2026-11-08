class_name ChatStoryInput
extends VBoxContainer
## 剧情选项下面的自由聊天（yi 定，2026-11-08）：玩家可以不点现成选项，自己对她说一句。
## 每个剧情选项只能用一次，不占每周的聊天轮数；她回一句后，玩家还是点选项接回剧情。
## 数值按判断出的玩家态度走态度表（和每周聊天共用封顶），模型失败用后备句、不改数值。人物 AI 线程的文件。

signal replied(text: String)

var story_text := ""   # 刚才那句剧情台词，告诉模型现在在发生什么
var _input: LineEdit
var _send: Button
var _reply: Label
var _used := false


func _init(current_story_text: String = "") -> void:
	story_text = current_story_text


func _ready() -> void:
	var line := UiKit.row(self)
	_input = LineEdit.new()
	_input.placeholder_text = Text.t("UI-43-01")
	_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input.text_submitted.connect(submit)
	line.add_child(_input)
	_send = UiKit.button(line, Text.t("UI-09-03"), func() -> void: submit(_input.text))
	_reply = UiKit.label(self, "")


## 发出玩家自己说的一句（自动测试也用它）
func submit(raw: String) -> void:
	var text := raw.strip_edges()
	if text.is_empty() or _used:
		return
	_used = true
	_input.editable = false
	_send.disabled = true
	_reply.text = Text.f("UI-09-04", {"girl": GameState.girl_name})
	var situation := Text.f("WK-16-01", {"story": story_text})
	await ModelService.start_conversation(ChatPrompt.build(situation))
	var reply := await ModelService.ask(ChatPrompt.turn_message(text, "", false), text, {}, ChatPrompt.facts_for(text), ChatPrompt.top_fact(text))
	if not is_inside_tree():
		return
	_reply.text = Text.f("UI-09-06", {"girl": GameState.girl_name, "text": reply["reply"]})
	ModelService.last_action = reply["action"]
	# 后备句不是她真的听懂了，不能据此改数值（和每周聊天一样）
	if not reply["fallback"]:
		var changes := ChatRules.round_changes(reply["player_attitude"], text, GameState.chat_week_changes)
		for id: String in changes:
			GameState.change_stat(id, changes[id])
		MemoryWriter.record_turn(GameState.memory, text, reply["reply"])
		if reply.get("claim", "") == ModelService.CLAIM_TRUE:
			MemoryWriter.record_correction(GameState.memory, text)
	replied.emit(reply["reply"])


func is_used() -> bool:
	return _used
