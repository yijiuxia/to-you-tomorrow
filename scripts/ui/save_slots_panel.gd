class_name SaveSlotsPanel
extends CenterContainer
## 存档位（房间线程 11.19，yi 定：1 个自动存档 + 2 个手动存档）。
## 读档模式：标题页点"继续"时列出 3 个存档位，点"读取"。
## 存档模式：主界面点"保存"时列出 2 个手动存档位，已有存档的先确认覆盖。

signal load_chosen(slot: String)
signal saved(slot: String)

const PANEL_WIDTH := 460.0
const SLOT_NAMES := {"auto": "UI-11-01", "manual1": "UI-11-04", "manual2": "UI-11-05"}
const MANUAL_SLOTS: Array[String] = ["manual1", "manual2"]

var saving := false  # true 是存档模式，false 是读档模式
var _box: VBoxContainer
var _confirm: ConfirmationDialog
var _pending := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = PANEL_WIDTH
	add_child(panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 10)
	panel.add_child(_box)
	_confirm = ConfirmationDialog.new()
	_confirm.dialog_text = Text.t("UI-11-03")
	_confirm.ok_button_text = Text.t("UI-50-09")
	_confirm.cancel_button_text = Text.t("UI-50-10")
	_confirm.confirmed.connect(func() -> void: _save_to(_pending))
	add_child(_confirm)
	_rebuild()


func _rebuild() -> void:
	for child in _box.get_children():
		_box.remove_child(child)
		child.queue_free()
	UiKit.title(_box, Text.t("UI-11-06") if saving else Text.t("UI-50-03"))
	var slots: Array[String] = MANUAL_SLOTS if saving else SaveSystem.SLOTS
	for slot in slots:
		var row := UiKit.row(_box)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		UiKit.short_label(info, Text.t(SLOT_NAMES[slot]))
		var summary := SaveSystem.summary(slot)
		var detail := Text.f("UI-11-02", summary) if not summary.is_empty() else Text.t("UI-11-08")
		UiKit.short_label(info, detail).modulate = GlassTheme.TEXT_DIM
		if saving:
			var s := slot
			UiKit.button(row, Text.t("UI-11-06"), func() -> void: _ask_save(s))
		else:
			var s2 := slot
			var load_button := UiKit.button(row, Text.t("UI-11-09"), func() -> void:
				visible = false
				load_chosen.emit(s2))
			load_button.disabled = summary.is_empty()
	UiKit.button(_box, Text.t("UI-50-10"), func() -> void: visible = false)


func _ask_save(slot: String) -> void:
	if SaveSystem.has_save(slot):
		_pending = slot
		_confirm.popup_centered()
	else:
		_save_to(slot)


func _save_to(slot: String) -> void:
	if SaveSystem.save(slot, SaveSystem.RESUME_HUB):
		saved.emit(slot)
	_rebuild()
