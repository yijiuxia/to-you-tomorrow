extends Control
## 剧情播放画面：一句句显示台词（逐字出现）、等玩家选、可快进和跳过。
## 规则在 StoryRunner，这里只管显示和操作：
##   点击 / 空格 / 回车：字还没出完就一下出完，出完了就下一句
##   快进：开着时每句很快自动往下走，遇到选择会停
##   跳过：一路跳到下一个选择或结尾；改状态的台词照样执行，不会漏掉剧情效果

signal finished

const BOX_HEIGHT := 240.0
const BACKDROP := Color(0, 0, 0, 0.75)
const NAME_SIZE := 22
const OVERLAY_LAYER := 40  # 比暂停菜单（50）低，暂停时能盖住剧情

var node: Dictionary = {}  ## 剧情节点表里的一行（StoryTriggers.pick 返回的）

var runner := StoryRunner.new()
var line: DialogueLine = null

var _speaker: Label
var _text: RichTextLabel
var _hint: Label
var _choices: VBoxContainer
var _fast_button: Button
var _fast := false
var _skipping := false
var _busy := false          # 正在向 Dialogue Manager 取下一句（它是异步的）
var _shown_chars := 0.0
var _typed := true          # 这一句已经全部显示出来了
var _auto_wait := 0.0
var free_talk: ChatStoryInput = null  # 人物 AI 线程加：剧情选项下的自由聊天（自动测试也用它）


## 在别的画面上面播剧情（比如地球画面里 ARK-01 走到植物旁边时）。不换画面，播完自己消失。
## 返回 null 表示这个时刻没有要播的；否则返回播放用的节点，可以 await 它的 all_finished 等播完。
## 用法：StoryScreen.play_over(self, "earth_plant_found")
static func play_over(parent: Node, moment: String) -> Node:
	var nodes := StoryTriggers.pick(moment)
	if nodes.is_empty():
		return null
	var holder := CanvasLayer.new()  # 盖在 3D 画面和小镇界面上面
	holder.layer = OVERLAY_LAYER
	holder.add_user_signal("all_finished")
	parent.add_child(holder)
	_play_in(holder, nodes, 0)
	return holder


static func _play_in(holder: CanvasLayer, nodes: Array[Dictionary], index: int) -> void:
	if index >= nodes.size():
		holder.emit_signal("all_finished")
		holder.queue_free()
		return
	var screen: Control = load("res://scripts/ui/story_screen.gd").new()
	screen.set("node", nodes[index])
	screen.connect("finished", func() -> void:
		screen.queue_free()
		_play_in(holder, nodes, index + 1))
	holder.add_child(screen)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_begin.call_deferred()


func _begin() -> void:
	_busy = true
	var first := await runner.start(str(node.get("file", "")), str(node.get("cue", "start")))
	_busy = false
	_show_line(first)


func _process(delta: float) -> void:
	if line == null or _busy:
		return
	if _is_typing():
		_shown_chars += delta * float(SaveSettings.text_speed)
		if _shown_chars >= _text.get_total_character_count():
			_finish_typing()
		else:
			_text.visible_characters = int(_shown_chars)
	elif _fast and line.responses.is_empty():
		_auto_wait -= delta
		if _auto_wait <= 0.0:
			advance()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		advance()
		accept_event()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
			advance()
			get_viewport().set_input_as_handled()


## 字没出完就出完；出完了就走下一句。有选择时只能点选项。
func advance() -> void:
	if line == null or _busy:
		return
	if _is_typing():
		_finish_typing()
		return
	if not line.responses.is_empty():
		return
	_go(line.next_id)


func toggle_fast() -> void:
	_fast = not _fast
	_fast_button.button_pressed = _fast
	if _fast and _is_typing():
		_finish_typing()


## 跳到下一个选择或结尾
func skip() -> void:
	if line == null or _busy:
		return
	_skipping = true
	var limit := int(DataDB.balance("story_skip_max_lines", 500))
	var count := 0
	while line != null and line.responses.is_empty() and count < limit:
		_busy = true
		line = await runner.next(line.next_id)
		_busy = false
		count += 1
	_skipping = false
	_show_line(line)


## 选第几个选项（自动测试也用它）
func choose(index: int) -> void:
	if line == null or _busy or index < 0 or index >= line.responses.size():
		return
	var response: DialogueResponse = line.responses[index]
	_go(response.next_id)


func _go(next_id: String) -> void:
	_busy = true
	var next_line := await runner.next(next_id)
	_busy = false
	_show_line(next_line)


func _show_line(new_line: DialogueLine) -> void:
	line = new_line
	_clear_choices()
	if line == null:
		_end()
		return
	_speaker.text = StoryRunner.speaker_of(line)
	_speaker.visible = not _speaker.text.is_empty()
	_text.text = StoryRunner.text_of(line)
	_shown_chars = 0.0
	_text.visible_characters = 0
	_typed = false
	_hint.hide()
	if _fast:
		_finish_typing()


func _finish_typing() -> void:
	_shown_chars = _text.get_total_character_count()
	_text.visible_characters = -1
	_typed = true
	_on_typed()


func _on_typed() -> void:
	_auto_wait = float(DataDB.balance("story_fast_forward_sec", 0.15))
	if line.responses.is_empty():
		_hint.show()
	else:
		_show_choices()


func _is_typing() -> bool:
	return not _typed


func _show_choices() -> void:
	_clear_choices()
	for i in line.responses.size():
		var response: DialogueResponse = line.responses[i]
		if not response.is_allowed:
			continue
		UiKit.button(_choices, StoryRunner.text_of(response), choose.bind(i))
	# 人物 AI 线程加：选项下面可以自己对她说一句，每个选项只能用一次，不占聊天轮数（yi 定）
	free_talk = ChatStoryInput.new(StoryRunner.text_of(line))
	_choices.add_child(free_talk)


func _clear_choices() -> void:
	for child in _choices.get_children():
		child.queue_free()


func _end() -> void:
	if node.has("id"):
		StoryTriggers.mark_seen(str(node["id"]))
	set_process(false)
	finished.emit()


func _build() -> void:
	# 背景以后换成镜头画面；现在先放一块深色
	var box_panel := PanelContainer.new()
	box_panel.anchor_left = 0.0
	box_panel.anchor_right = 1.0
	box_panel.anchor_top = 1.0
	box_panel.anchor_bottom = 1.0
	box_panel.offset_top = -BOX_HEIGHT
	box_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var style := StyleBoxFlat.new()
	style.bg_color = BACKDROP
	box_panel.add_theme_stylebox_override("panel", style)
	add_child(box_panel)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, UiKit.PAGE_MARGIN)
	box_panel.add_child(margin)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_theme_constant_override("separation", UiKit.GAP)
	margin.add_child(box)

	var top := UiKit.row(box)
	_speaker = UiKit.short_label(top, "")
	_speaker.add_theme_font_size_override("font_size", NAME_SIZE)
	_speaker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fast_button = UiKit.button(top, Text.t("UI-54-01"), toggle_fast)
	_fast_button.toggle_mode = true
	_fast_button.focus_mode = Control.FOCUS_NONE
	var skip_button := UiKit.button(top, Text.t("UI-54-02"), skip)
	skip_button.focus_mode = Control.FOCUS_NONE

	_text = RichTextLabel.new()
	_text.bbcode_enabled = false
	_text.fit_content = true
	_text.mouse_filter = Control.MOUSE_FILTER_PASS
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_text)
	_choices = VBoxContainer.new()
	box.add_child(_choices)
	_hint = UiKit.short_label(box, Text.t("UI-54-04"))
	_hint.modulate.a = 0.6
	_hint.hide()
