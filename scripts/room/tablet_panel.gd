class_name TabletPanel
extends CenterContainer
## 平板（房间线程）：换窗景、换音乐、看周记、看地球情况、换灯光、看科技。
## 改了选项就发 changed，房间画面收到后刷新。

signal changed
signal closed

const PANEL_SIZE := Vector2(720, 480)
const TECH_LOCKED := Color(0.55, 0.55, 0.55)
const TECH_OPEN := Color(0.55, 0.9, 0.6)

var tabs := TabContainer.new()
var _journal_text: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP  # 打开时挡住后面的房间
	var panel := PanelContainer.new()
	add_child(panel)
	panel.custom_minimum_size = PANEL_SIZE
	var box := VBoxContainer.new()
	panel.add_child(box)
	var head := UiKit.row(box)
	UiKit.short_label(head, Text.t("RT-01-11")).add_theme_font_size_override("font_size", UiKit.TITLE_SIZE)
	UiKit.spacer(head)
	UiKit.button(head, Text.t("RT-03-21"), close)
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(tabs)
	# 顺序按定稿 TB-01：周记、窗外景色、灯光、音乐、地球情况、科技树
	_journal_page()
	_option_page("view", "TB-01-02", "TB-02-05")
	_option_page("light", "TB-01-03", "TB-03-06")
	_option_page("music", "TB-01-04", "")
	_earth_page()
	_tech_page()


func close() -> void:
	visible = false
	closed.emit()


func _page(title_key: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = Text.t(title_key)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	return box


## 一组单选按钮：窗景 / 音乐 / 灯光都是这种
func _option_page(group: String, title_key: String, note_key: String) -> void:
	var box := _page(title_key)
	var button_group := ButtonGroup.new()
	var current := str(RoomRules.current_option(group).get("id", ""))
	for row in RoomRules.options(group):
		var id := str(row["id"])
		var button := CheckBox.new()
		button.text = Text.t(row["name_key"])
		button.button_group = button_group
		button.button_pressed = id == current
		button.pressed.connect(func() -> void:
			RoomRules.choose_option(group, id)
			changed.emit())
		box.add_child(button)
	if not note_key.is_empty():
		_note(box, Text.t(note_key))


## 周记：上面一排周数按钮，下面是那一周她写的（每周结算后才有）
func _journal_page() -> void:
	var box := _page("TB-01-01")
	var weeks := UiKit.row(box)
	_journal_text = UiKit.label(box, "")
	var written := RoomRules.journal_weeks()
	for week in written:
		var w := week
		UiKit.button(weeks, Text.f("TB-06-01", {"week": w}), func() -> void: show_journal(w))
	if written.is_empty():
		_journal_text.text = Text.t("RT-04-60")
	else:
		show_journal(written[-1])


func show_journal(week: int) -> void:
	_journal_text.text = Text.f("TB-06-01", {"week": week}) + "
" + "
".join(RoomRules.journal_text(week))


func journal_shown() -> String:
	return _journal_text.text


func _earth_page() -> void:
	var box := _page("TB-01-05")
	for line in RoomRules.earth_lines():
		UiKit.label(box, line)


## 科技树：从左到右一张简单的图（这里竖着排，一行一个），解锁的亮、没解锁的灰并写出还差什么
func _tech_page() -> void:
	var box := _page("TB-01-06")
	if not RoomRules.tech_open():
		UiKit.label(box, Text.t("TB-01-07"))
		return
	_note(box, Text.t("TT-00-02"))
	for row: Dictionary in RoomRules.tech_rows():
		var unlocked := RoomRules.is_tech_unlocked(row["id"])
		var state := Text.t("RT-08-03") if unlocked else RoomRules.tech_need_text(row["id"])
		var line := UiKit.label(box, "%s　·　%s" % [Text.t(row["name_key"]), state])
		line.modulate = TECH_OPEN if unlocked else TECH_LOCKED
		UiKit.set_hover_text(line, Text.t(row["desc_key"]))


func _note(parent: Control, text: String) -> void:
	var note := UiKit.label(parent, text)
	note.modulate = TECH_LOCKED
