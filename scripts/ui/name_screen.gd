extends Control
## 起名：她的名字和你的名字。空着就用默认名字。名字存进 GameState，文字表里的 {girl} {player} 会自动换。

signal finished

const FIELD_WIDTH := 320.0

var girl_input: LineEdit
var player_input: LineEdit


func _ready() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UiKit.GAP)
	center.add_child(box)
	var max_length := int(DataDB.balance("ui_name_max_length", 8))
	UiKit.title(box, Text.t("UI-51-01"))
	UiKit.short_label(box, Text.t("UI-51-02"))
	girl_input = _field(box, Text.t("UI-51-05"), max_length)
	UiKit.short_label(box, Text.t("UI-51-03"))
	player_input = _field(box, Text.t("UI-51-06"), max_length)
	UiKit.short_label(box, Text.f("UI-51-07", {"count": max_length}))
	UiKit.button(box, Text.t("UI-51-04"), confirm)
	girl_input.grab_focus.call_deferred()


func confirm() -> void:
	GameState.girl_name = _name_or_default(girl_input)
	GameState.player_name = _name_or_default(player_input)
	finished.emit()


func _field(parent: Control, default_name: String, max_length: int) -> LineEdit:
	var field := LineEdit.new()
	field.placeholder_text = default_name
	field.max_length = max_length
	field.custom_minimum_size.x = FIELD_WIDTH
	field.text_submitted.connect(func(_text: String) -> void: confirm())
	parent.add_child(field)
	return field


## 名字里的花括号会被当成占位符，去掉它们
static func clean_name(raw: String) -> String:
	return raw.replace("{", "").replace("}", "").strip_edges()


func _name_or_default(field: LineEdit) -> String:
	var value := clean_name(field.text)
	return value if not value.is_empty() else field.placeholder_text
