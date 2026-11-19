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
	UiKit.short_label(head, Text.t("RM-03-01")).add_theme_font_size_override("font_size", UiKit.TITLE_SIZE)
	UiKit.spacer(head)
	UiKit.button(head, Text.t("RM-03-21"), close)
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(tabs)
	_option_page("view", "RM-03-02")
	_option_page("music", "RM-03-03")
	_journal_page()
	_earth_page()
	_option_page("light", "RM-03-06")
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
func _option_page(group: String, title_key: String) -> void:
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


## 周记：上面一排周数按钮，下面是那一周她写的
func _journal_page() -> void:
	var box := _page("RM-03-04")
	var weeks := UiKit.row(box)
	_journal_text = UiKit.label(box, "")
	for week in range(1, GameState.week + 1):
		var w := week
		UiKit.button(weeks, Text.f("RM-04-01", {"week": w}), func() -> void: show_journal(w))
	show_journal(GameState.week)


func show_journal(week: int) -> void:
	_journal_text.text = Text.f("RM-04-01", {"week": week}) + "\n" + "\n".join(RoomRules.journal_text(week))


func journal_shown() -> String:
	return _journal_text.text


func _earth_page() -> void:
	var box := _page("RM-03-05")
	for line in RoomRules.earth_lines():
		UiKit.label(box, line)


## 科技：每个技能一列，从低到高，解锁的亮、没解锁的灰并写出门槛
func _tech_page() -> void:
	var box := _page("RM-03-07")
	UiKit.label(box, Text.t("RM-08-02"))
	var columns := UiKit.row(box)
	var tree := RoomRules.tech_tree()
	for stat: String in tree:
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		columns.add_child(column)
		UiKit.short_label(column, "%s %d" % [UiKit.stat_name(stat), GameState.get_stat(stat)])
		for row: Dictionary in tree[stat]:
			var unlocked := RoomRules.is_tech_unlocked(row["id"])
			var state := Text.t("RM-08-03") if unlocked else Text.f("RM-08-04", {"stat": UiKit.stat_name(stat), "need": row["need"]})
			var line := UiKit.label(column, "%s\n%s" % [Text.t(row["name_key"]), state])
			line.modulate = TECH_OPEN if unlocked else TECH_LOCKED
			UiKit.set_hover_text(line, Text.t(row["desc_key"]))
