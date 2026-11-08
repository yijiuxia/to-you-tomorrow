extends Control
## 设置面板：音量、全屏、文字速度、语言。标题页和暂停菜单共用，盖在当前画面上面。
## 每改一项马上生效并保存，不需要"应用"按钮。

signal closed
signal language_changed

const BACKDROP := Color(0, 0, 0, 0.6)
const PANEL_WIDTH := 460.0


func _ready() -> void:
	# 暂停时也要能点
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var backdrop := ColorRect.new()
	backdrop.color = BACKDROP
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = PANEL_WIDTH
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, UiKit.PAGE_MARGIN)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UiKit.GAP)
	margin.add_child(box)

	UiKit.title(box, Text.t("UI-53-01"))
	_slider_row(box, Text.t("UI-53-02"), 0, 100, SaveSettings.volume, func(value: float) -> void:
		SaveSettings.volume = int(value)
		SaveSettings.save_settings())
	_slider_row(box, Text.t("UI-53-04"), int(DataDB.balance("ui_text_speed_min", 10)), int(DataDB.balance("ui_text_speed_max", 120)), SaveSettings.text_speed, func(value: float) -> void:
		SaveSettings.text_speed = int(value)
		SaveSettings.save_settings())

	var fullscreen := CheckBox.new()
	fullscreen.text = Text.t("UI-53-03")
	fullscreen.button_pressed = SaveSettings.fullscreen
	fullscreen.toggled.connect(func(on: bool) -> void:
		SaveSettings.fullscreen = on
		SaveSettings.save_settings())
	box.add_child(fullscreen)

	var language_row := UiKit.row(box)
	UiKit.short_label(language_row, Text.t("UI-53-05"))
	var language := OptionButton.new()
	language.add_item(Text.t("UI-53-06"))
	language.add_item(Text.t("UI-53-07"))
	language.select(SaveSettings.LANGUAGES.find(SaveSettings.language))
	language.item_selected.connect(_on_language_selected)
	language_row.add_child(language)
	UiKit.label(box, Text.t("UI-53-09"))

	UiKit.button(box, Text.t("UI-53-08"), close)


func close() -> void:
	closed.emit()
	queue_free()


func _on_language_selected(index: int) -> void:
	SaveSettings.language = SaveSettings.LANGUAGES[index]
	SaveSettings.save_settings()
	language_changed.emit()


func _slider_row(parent: Control, text: String, low: int, high: int, value: int, on_changed: Callable) -> void:
	var line := UiKit.row(parent)
	UiKit.short_label(line, text)
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = 1
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(slider)
	var number := UiKit.short_label(line, str(value))
	slider.value_changed.connect(func(new_value: float) -> void:
		number.text = str(int(new_value))
		on_changed.call(new_value))
