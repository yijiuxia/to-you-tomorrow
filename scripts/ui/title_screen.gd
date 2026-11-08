extends Control
## 标题页：开始游戏、继续、设置、制作人员、退出。

signal new_game_pressed
signal continue_pressed
signal credits_pressed
signal language_changed

const SettingsPanel := preload("res://scripts/ui/settings_panel.gd")
const BUTTON_WIDTH := 260.0

var _overwrite: ConfirmationDialog


func _ready() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UiKit.GAP)
	center.add_child(box)
	var game_title := UiKit.title(box, Text.t("UI-50-01"))
	game_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_menu_button(box, Text.t("UI-50-02"), _on_new_game)
	var continue_button := _menu_button(box, Text.t("UI-50-03"), func() -> void: continue_pressed.emit())
	var info := SaveSystem.summary()
	continue_button.disabled = info.is_empty()
	if not info.is_empty():
		var note := UiKit.label(box, Text.f("UI-50-07", info))
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu_button(box, Text.t("UI-50-04"), open_settings)
	_menu_button(box, Text.t("UI-50-05"), func() -> void: credits_pressed.emit())
	_menu_button(box, Text.t("UI-50-06"), func() -> void: get_tree().quit())

	_overwrite = ConfirmationDialog.new()
	_overwrite.dialog_text = Text.t("UI-50-08")
	_overwrite.ok_button_text = Text.t("UI-50-09")
	_overwrite.cancel_button_text = Text.t("UI-50-10")
	_overwrite.confirmed.connect(func() -> void: new_game_pressed.emit())
	add_child(_overwrite)


func open_settings() -> void:
	var panel := SettingsPanel.new()
	panel.language_changed.connect(func() -> void: language_changed.emit())
	add_child(panel)


## 已有存档时先确认，免得一下点掉之前的进度
func _on_new_game() -> void:
	if SaveSystem.has_save():
		_overwrite.popup_centered()
	else:
		new_game_pressed.emit()


func _menu_button(parent: Control, text: String, on_pressed: Callable) -> Button:
	var node := UiKit.button(parent, text, on_pressed)
	node.custom_minimum_size.x = BUTTON_WIDTH
	return node
