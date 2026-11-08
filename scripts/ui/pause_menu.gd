extends CanvasLayer
## 暂停菜单：游戏里按 Esc 打开，再按 Esc 或点"继续游戏"关上。
## 打开时整个游戏暂停（地球上的机器人也停）。这一层自己设成"暂停时照样运行"，按钮才点得动。

signal to_title_pressed
signal language_changed

const SettingsPanel := preload("res://scripts/ui/settings_panel.gd")
const LAYER := 50
const BACKDROP := Color(0, 0, 0, 0.6)
const BUTTON_WIDTH := 260.0

var _root: Control
var _settings: Control = null
var _old_mouse_mode := Input.MOUSE_MODE_VISIBLE


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.hide()


func is_open() -> bool:
	return _root.visible


func open() -> void:
	# 第三人称时鼠标可能被锁住，打开菜单要放出来，关上时还原
	_old_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_root.show()
	get_tree().paused = true


func close() -> void:
	if _settings != null:
		_settings.close()
	_root.hide()
	get_tree().paused = false
	Input.mouse_mode = _old_mouse_mode


func _unhandled_input(event: InputEvent) -> void:
	if not is_open():
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		if _settings != null:
			_settings.close()
		else:
			close()


func _build() -> void:
	# 换语言后整层重建，按钮文字跟着换
	if _root != null:
		_root.queue_free()
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var backdrop := ColorRect.new()
	backdrop.color = BACKDROP
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(backdrop)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UiKit.GAP)
	center.add_child(box)
	UiKit.title(box, Text.t("UI-52-01")).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu_button(box, Text.t("UI-52-02"), close)
	_menu_button(box, Text.t("UI-50-04"), _open_settings)
	_menu_button(box, Text.t("UI-52-03"), _to_title)
	var note := UiKit.label(box, Text.t("UI-52-04"))
	note.custom_minimum_size.x = BUTTON_WIDTH * 1.5


func _open_settings() -> void:
	_settings = SettingsPanel.new()
	_settings.closed.connect(func() -> void: _settings = null)
	_settings.language_changed.connect(_on_language_changed)
	_root.add_child(_settings)


func _on_language_changed() -> void:
	language_changed.emit()
	var was_open := is_open()
	_settings = null
	_build()
	_root.visible = was_open
	_open_settings()


func _to_title() -> void:
	close()
	to_title_pressed.emit()


func _menu_button(parent: Control, text: String, on_pressed: Callable) -> void:
	UiKit.button(parent, text, on_pressed).custom_minimum_size.x = BUTTON_WIDTH
