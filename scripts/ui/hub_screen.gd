extends Control
## 主界面：属性面板 + 四个按钮（小镇 / 聊天 / 课表 / 结束本周）。

signal town_pressed
signal chat_pressed
signal schedule_pressed
signal end_week_confirmed

const NUMBER_STATS: Array[String] = ["mood", "mechanics", "ecology", "comms"]
const TRAIT_STATS: Array[String] = ["confidence", "curiosity", "empathy", "trust"]
const GIRL_BLOCK_COLOR := Color(0.35, 0.45, 0.6)
const PANEL_MIN_WIDTH := 420.0

var _confirm: ConfirmationDialog


func _ready() -> void:
	var box := UiKit.page(self)
	UiKit.title(box, Text.f("UI-01-05", {"week": GameState.week, "girl": GameState.girl_name, "age": GameState.age}))
	if GameState.girl_intent != "none":
		UiKit.label(box, Text.f("UI-01-06", {"girl": GameState.girl_name, "intent": Text.t("UI-12-" + GameState.girl_intent)}))

	var middle := UiKit.row(box)
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build_girl_block(middle)
	_build_stat_panel(middle)

	var buttons := UiKit.row(box)
	UiKit.button(buttons, Text.t("UI-01-01"), func() -> void: town_pressed.emit())
	UiKit.button(buttons, Text.t("UI-01-02"), func() -> void: chat_pressed.emit())
	var schedule_button := UiKit.button(buttons, Text.t("UI-01-03"), func() -> void: schedule_pressed.emit())
	# 最后一周结束直接进结局，课不会再结算，排了也没用
	schedule_button.disabled = GameState.week >= int(DataDB.balance("last_week"))
	UiKit.button(buttons, Text.t("UI-01-04"), _ask_end_week)

	_confirm = ConfirmationDialog.new()
	_confirm.ok_button_text = Text.t("UI-05-04")
	_confirm.cancel_button_text = Text.t("UI-05-05")
	_confirm.confirmed.connect(func() -> void: end_week_confirmed.emit())
	add_child(_confirm)


## 她的位置先放一个方块
func _build_girl_block(parent: Control) -> void:
	var block := ColorRect.new()
	block.color = GIRL_BLOCK_COLOR
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(block)
	var note := UiKit.label(block, Text.t("UI-01-07"))
	note.set_anchors_preset(Control.PRESET_FULL_RECT)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func _build_stat_panel(parent: Control) -> void:
	var panel := VBoxContainer.new()
	panel.custom_minimum_size.x = PANEL_MIN_WIDTH
	parent.add_child(panel)
	UiKit.label(panel, "%s %d / %d" % [UiKit.stat_name("stamina"), GameState.get_stat("stamina"), GameState.get_stat("stamina_max")])
	for id in NUMBER_STATS:
		UiKit.label(panel, "%s %d" % [UiKit.stat_name(id), GameState.get_stat(id)])
	# 性格和信任只显示一句话，不显示数字（比赛版 4.1）
	for id in TRAIT_STATS:
		UiKit.label(panel, "%s：%s" % [UiKit.stat_name(id), GameState.trait_text(id, GameState.get_stat(id), GameState.age)])
	var low_stamina := int(DataDB.balance("low_stamina"))
	if GameState.get_stat("stamina") <= 0:
		UiKit.label(panel, Text.t("UI-02-12"))
	elif GameState.get_stat("stamina") < low_stamina:
		UiKit.label(panel, Text.t("UI-02-11"))
	if GameState.get_stat("mood") < int(DataDB.balance("low_mood")):
		UiKit.label(panel, Text.t("UI-02-13"))


func _ask_end_week() -> void:
	var lines := PackedStringArray([Text.t("UI-05-01")])
	if GameState.week >= int(DataDB.balance("last_week")):
		lines.append(Text.t("UI-05-06"))
	else:
		var same := GameState.schedule == GameState.last_schedule
		lines.append(Text.t("UI-05-02") if same else Text.t("UI-05-03"))
	_confirm.dialog_text = "\n".join(lines)
	_confirm.popup_centered()
