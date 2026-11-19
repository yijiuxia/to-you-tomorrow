extends Control
## 标题页：开始游戏、继续、设置、制作人员、退出。

signal new_game_pressed
signal continue_pressed(slot: String)  # 房间线程 11.19：继续时先选存档位
signal credits_pressed
signal language_changed
signal language_toggled  # 右上角切语言：只要重建标题页，不打开设置

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
	var continue_button := _menu_button(box, Text.t("UI-50-03"), open_slots)
	var info := SaveSystem.summary()
	continue_button.disabled = not SaveSystem.has_any_save()
	if not info.is_empty():
		var note := UiKit.label(box, Text.f("UI-50-07", info))
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu_button(box, Text.t("UI-50-04"), open_settings)
	_menu_button(box, Text.t("UI-50-05"), func() -> void: credits_pressed.emit())
	_menu_button(box, Text.t("UI-50-06"), _quit)

	_overwrite = ConfirmationDialog.new()
	_overwrite.dialog_text = Text.t("UI-50-08")
	_overwrite.ok_button_text = Text.t("UI-50-09")
	_overwrite.cancel_button_text = Text.t("UI-50-10")
	_overwrite.confirmed.connect(func() -> void: new_game_pressed.emit())
	add_child(_overwrite)

	# 右上角：中文 / English（yi 11.19 定，和设置里的语言是同一个设置）
	var language := UiKit.button(self, Text.t("UI-00-08"), func() -> void:
		SaveSettings.toggle_language()
		language_toggled.emit())
	language.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE)
	language.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	language.offset_right = -UiKit.PAGE_MARGIN
	language.offset_top = UiKit.PAGE_MARGIN


## 三个存档位，选一个读
func open_slots() -> void:
	var panel := SaveSlotsPanel.new()
	panel.load_chosen.connect(func(slot: String) -> void: continue_pressed.emit(slot))
	add_child(panel)


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


## 模型还在后台加载时直接退出会崩溃，等它加载完再退
func _quit() -> void:
	for node in find_children("*", "Button", true, false):
		(node as Button).disabled = true
	while ModelService.status == ModelService.Status.LOADING:
		await get_tree().process_frame
	get_tree().quit()
