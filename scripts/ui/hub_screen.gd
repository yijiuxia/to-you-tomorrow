extends Control
## 主界面（房间线程 11.19，逐块照 yi 的参考图"方舟生活"做，颜色用科技蓝）：
## 3D 房间铺满整个画面，界面是浮在上面的玻璃面板——
## 顶栏（方舟生活 + 四个页签 + 资源 + 设置）、左上人物卡、左边当前状态、
## 中间偏右的大面板（本周计划 / 成长记录 / 记忆日志 / 方舟总览，跟着页签换）、
## 右边竖排菜单（状态、课程、地球建造）、左下她说的话、底部（结束本周）、右下方舟时间。
## yi 11.19 定：状态和课表面板默认收起，点按钮滑出、再点收起；主界面没有自由聊天按钮，点她才冒出"聊天"。
## yi 定：平板和舱门不做按钮，只能点房间里的平板和门。
## 头像 yi 定不做。图标是 assets/ui/icons 里的简单线条图标，以后可以换美术画的。

signal town_pressed
signal chat_pressed
signal schedule_pressed
signal end_week_confirmed
signal place_pressed(id: String)  # 从舱门电梯或第 7 周按钮去别的场所

const ICON_DIR := "res://assets/ui/icons/"
const ICON_SIZE := 16
const ICON_SMALL := 13
const MARGIN := 12
const TOP_HEIGHT := 34.0
const LEFT_WIDTH := 236.0
const CENTER_WIDTH := 390.0
const RIGHT_WIDTH := 118.0
const BUBBLE_WIDTH := 330.0
const BAR_HEIGHT := 4.0
const SMALL_FONT := 11
const TITLE_FONT := 15
const STATUS_STATS := {"mood": "smile", "curiosity": "bulb", "stamina": "battery", "empathy": "hands", "confidence": "star"}
const SKILL_STATS := {"mechanics": "wrench", "ecology": "leaf", "comms": "signal"}
const COURSE_ICONS := {"skill": "book", "confidence": "star", "curiosity": "bulb", "empathy": "hands", "trust": "heart", "rest": "moon"}
const TABS: Array[String] = ["plan", "growth", "memory", "overview"]
const TAB_KEYS := {"plan": "RT-09-10", "growth": "RT-09-11", "memory": "RT-09-12", "overview": "RT-09-13"}
const MEMORY_SHOWN := 8
const SLIDE_TIME := 0.22          # 面板滑出 / 收起要多久（秒）
const SLIDE_DISTANCE := 40.0      # 滑多远（像素）
const TALK_OFFSET := Vector3(0.35, 0.6, 0)  # "聊天"出现在她头顶右边一点
const TALK_SHOW_SEC := 4.0        # 不点的话几秒后消失

const EndWeekDialog := preload("res://scripts/ui/end_week_dialog.gd")

var room: RoomView
var tablet: TabletPanel
var elevator: ElevatorMenu
var center: PanelContainer      # 中间的大面板
var current_tab := "plan"
var _confirm: EndWeekDialog
var _center_box: VBoxContainer
var _tab_buttons := {}
var _status_column: VBoxContainer
var _status_panel: PanelContainer   # "当前状态"：点右边"状态"才滑出来（yi 11.19 定）
var _status_button: Button
var _plan_button: Button
var talk_button: Button             # 点她以后在她旁边冒出来的"聊天"（yi 定：主界面不放自由聊天按钮）
var _tweens := {}


func _ready() -> void:
	room = RoomView.new()
	room.scene_id = "cabin"
	room.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(room)
	room.talk_requested.connect(_show_talk_button)
	room.tablet_requested.connect(open_tablet)
	room.door_requested.connect(open_elevator)

	_build_top_bar()
	_build_left_column()
	_build_center()
	_build_right_menu()
	_build_bubble()
	_build_bottom()
	_build_time()
	_build_talk_button()
	# 课表和状态默认收起，点按钮才滑出来
	center.visible = false
	_status_panel.visible = false
	_highlight_tabs("")

	_confirm = EndWeekDialog.new()
	_confirm.confirmed.connect(func() -> void: end_week_confirmed.emit())
	add_child(_confirm)


# ---------- 顶栏 ----------

func _build_top_bar() -> void:
	var bar := _corner_panel(Control.PRESET_TOP_WIDE)
	bar.offset_left = MARGIN
	bar.offset_right = -MARGIN
	bar.offset_top = 10
	bar.custom_minimum_size.y = TOP_HEIGHT
	bar.add_theme_stylebox_override("panel", _panel_style(6))
	var row := _row(bar, 14)
	_icon(row, "home", ICON_SIZE + 4).modulate = GlassTheme.TEXT
	_label(row, Text.t("RT-09-01"), TITLE_FONT)
	var help := _icon(row, "help", ICON_SMALL)
	help.modulate = GlassTheme.TEXT_DIM
	help.tooltip_text = Text.t("RT-02-17")
	help.mouse_filter = Control.MOUSE_FILTER_STOP
	_gap(row, 18)
	for id in TABS:
		var tab := _flat_button(row, Text.t(TAB_KEYS[id]), "", func() -> void: show_tab(id))
		_tab_buttons[id] = tab
	_spacer(row)
	if WeekSystem.is_earth_open() and GameState.earth != null:
		var rec := GameState.earth.recovery()
		_resource(row, "metal", Text.f("RT-09-02", {"value": GameState.earth.metal}))
		_resource(row, "chip", Text.f("RT-09-03", {"value": GameState.earth.electronics}))
		_resource(row, "bolt", Text.f("RT-09-14", {"value": rec.get("power", 0)}))
		_resource(row, "drop", Text.f("RT-09-15", {"value": rec.get("water", 0)}))
	_flat_button(row, Text.t("UI-11-06"), "", open_save)
	_icon_button(row, "gear", _open_pause)


## 设置：和按 Esc 一样打开暂停菜单（里面有设置）
func _open_pause() -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_ESCAPE
	event.pressed = true
	Input.parse_input_event(event)


func _resource(parent: Control, icon_name: String, text: String) -> void:
	var chip := _row(parent, 4)
	_icon(chip, icon_name, ICON_SMALL).modulate = GlassTheme.ACCENT
	_label(chip, text, SMALL_FONT)


# ---------- 左边：人物卡 + 当前状态 ----------

func _build_left_column() -> void:
	_status_column = VBoxContainer.new()
	_status_column.add_theme_constant_override("separation", 10)
	_status_column.position = Vector2(MARGIN, 10 + TOP_HEIGHT + 14)
	_status_column.custom_minimum_size.x = LEFT_WIDTH
	_status_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_status_column)

	# 人物卡：yi 定不做头像，只放名字、年龄、周数和信任
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _panel_style(9))
	_status_column.add_child(card)
	var info := VBoxContainer.new()
	card.add_child(info)
	var name_row := _row(info, 10)
	_label(name_row, GameState.girl_name, 18)
	_label(name_row, Text.f("RT-09-04", {"age": GameState.age, "week": GameState.week}), SMALL_FONT, GlassTheme.TEXT_DIM)
	_stat_line(info, "trust", "heart", false)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(9))
	_status_column.add_child(panel)
	_status_panel = panel
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	panel.add_child(box)
	_header(box, "pulse", Text.t("RT-09-05"))
	for id: String in STATUS_STATS:
		_stat_line(box, id, STATUS_STATS[id], true)
	var skills := _row(box, 14)
	for id: String in SKILL_STATS:
		var chip := _row(skills, 4)
		_icon(chip, SKILL_STATS[id], ICON_SMALL).modulate = GlassTheme.ACCENT
		var skill := _label(chip, "%s %d" % [UiKit.stat_name(id), GameState.get_stat(id)], SMALL_FONT, GlassTheme.TEXT_DIM)
		UiKit.set_hover_text(skill, stat_hover_text(id))
	# 累了、病了、心情低的提醒
	var low_stamina := int(DataDB.balance("low_stamina"))
	if GameState.get_stat("stamina") <= 0:
		_warn(box, Text.t("UI-02-12"))
	elif GameState.get_stat("stamina") < low_stamina:
		_warn(box, Text.t("UI-02-11"))
	if GameState.get_stat("mood") < int(DataDB.balance("low_mood")):
		_warn(box, Text.t("UI-02-13"))


## 一行属性：图标 名字 状态词 …… 数值 / 上限，下面一条进度条；鼠标指上去看说明
func _stat_line(parent: Control, id: String, icon_name: String, with_word: bool) -> void:
	var line := VBoxContainer.new()
	line.add_theme_constant_override("separation", 3)
	parent.add_child(line)
	var head := _row(line, 8)
	_icon(head, icon_name, ICON_SMALL).modulate = GlassTheme.ACCENT
	_label(head, UiKit.stat_name(id), 12)
	if with_word:
		_label(head, _band_word(id), SMALL_FONT, GlassTheme.TEXT_DIM)
	_spacer(head)
	var top := stat_max(id)
	_label(head, "%d / %d" % [GameState.get_stat(id), top], SMALL_FONT, GlassTheme.TEXT_DIM)
	var bar := ProgressBar.new()
	bar.max_value = top
	bar.value = GameState.get_stat(id)
	bar.show_percentage = false
	bar.custom_minimum_size.y = BAR_HEIGHT
	line.add_child(bar)
	UiKit.set_hover_text(line, stat_hover_text(id))


## 状态词：高 / 中 / 低三档（门槛和性格说明用的一样）
func _band_word(id: String) -> String:
	if GameState.is_high(id):
		return Text.t("RT-09-36")
	if GameState.is_low(id):
		return Text.t("RT-09-38")
	return Text.t("RT-09-37")


static func stat_max(id: String) -> int:
	var value: Variant = DataDB.row("girl_stats", id).get("max", 100)
	if value is String:  # 体力的上限写的是 stamina_max，取那个属性的当前值
		return GameState.get_stat(value)
	return int(value)


# ---------- 中间的大面板（跟着顶栏页签换内容） ----------

func _build_center() -> void:
	center = PanelContainer.new()
	center.add_theme_stylebox_override("panel", _panel_style(10))
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE)
	center.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	center.offset_right = -(MARGIN + RIGHT_WIDTH + 14)
	center.offset_top = 10 + TOP_HEIGHT + 30
	center.custom_minimum_size.x = CENTER_WIDTH
	_center_box = VBoxContainer.new()
	_center_box.add_theme_constant_override("separation", 6)
	center.add_child(_center_box)


## 切页签：再点一下当前页签就收起面板，看得到后面的房间
func show_tab(id: String) -> void:
	if id == current_tab and center.visible:
		_slide(center, false, SLIDE_DISTANCE)
		_highlight_tabs("")
		_mark(_plan_button, false)
		return
	current_tab = id
	_slide(center, true, SLIDE_DISTANCE)
	_highlight_tabs(id)
	_mark(_plan_button, id == "plan")
	for child in _center_box.get_children():
		_center_box.remove_child(child)
		child.queue_free()
	match id:
		"plan":
			_fill_plan()
		"growth":
			_fill_growth()
		"memory":
			_fill_memory()
		"overview":
			_fill_overview()


func _highlight_tabs(id: String) -> void:
	for tab_id: String in _tab_buttons:
		var button: Button = _tab_buttons[tab_id]
		if tab_id == id:
			var style := GlassTheme.box(Color(GlassTheme.ACCENT, 0.12), Color(0, 0, 0, 0), 4, 0)
			style.border_width_bottom = 2
			style.border_color = GlassTheme.ACCENT
			style.content_margin_left = 14
			style.content_margin_right = 14
			button.add_theme_stylebox_override("normal", style)
			button.add_theme_color_override("font_color", GlassTheme.TEXT)
		else:
			var idle := GlassTheme.box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 4, 0)
			idle.content_margin_left = 14
			idle.content_margin_right = 14
			button.add_theme_stylebox_override("normal", idle)
			button.add_theme_color_override("font_color", GlassTheme.TEXT_DIM)


func _center_header(icon_name: String, title: String, extra: String) -> void:
	var head := _row(_center_box, 10)
	_icon(head, icon_name, ICON_SIZE).modulate = GlassTheme.ACCENT
	_label(head, title, TITLE_FONT)
	_spacer(head)
	if not extra.is_empty():
		_label(head, extra, SMALL_FONT, GlassTheme.TEXT_DIM)
	_center_box.add_child(HSeparator.new())


## 本周计划：本周目标 + 7 天课表 + 调整计划
func _fill_plan() -> void:
	_center_header("calendar", Text.t("RT-09-16"), Text.f("RT-09-09", {"week": GameState.week, "last": int(DataDB.balance("last_week"))}))
	var goal := PanelContainer.new()
	goal.add_theme_stylebox_override("panel", GlassTheme.box(Color(GlassTheme.BG_BUTTON, 0.7), GlassTheme.BORDER, 8, 10))
	_center_box.add_child(goal)
	var goal_row := _row(goal, 10)
	_icon(goal_row, "flag", ICON_SIZE).modulate = GlassTheme.ACCENT
	var goal_text := VBoxContainer.new()
	goal_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	goal_row.add_child(goal_text)
	_label(goal_text, Text.t("RT-09-17"), 12)
	var intent := Text.f("RT-09-18", {"girl": GameState.girl_name, "intent": Text.t("UI-12-" + GameState.girl_intent)}) if GameState.girl_intent != "none" else Text.t("RT-09-19")
	_label(goal_text, intent, SMALL_FONT, GlassTheme.TEXT_DIM).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	for day in GameState.schedule.size():
		var course_id: String = GameState.schedule[day]
		var course := DataDB.row("courses", course_id)
		var line := PanelContainer.new()
		line.add_theme_stylebox_override("panel", GlassTheme.box(Color(1, 1, 1, 0.03), Color(GlassTheme.BORDER, 0.25), 6, 6))
		_center_box.add_child(line)
		var row := _row(line, 12)
		var day_label := _label(row, Text.t("RT-09-%02d" % (20 + day)), 12)
		day_label.custom_minimum_size.x = 34
		_icon(row, COURSE_ICONS.get(str(course.get("type", "")), "dot"), ICON_SMALL).modulate = GlassTheme.ACCENT
		var name_label := _label(row, Text.t(str(course.get("name_key", course_id))), 12)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UiKit.set_hover_text(name_label, Text.t(str(course.get("desc_key", ""))))
		var resting := course_id == "rest"
		_label(row, Text.t("RT-09-28" if resting else "RT-09-27"), SMALL_FONT, GlassTheme.TEXT_DIM if resting else GlassTheme.ACCENT)

	var foot := _row(_center_box, 10)
	var hint := _label(foot, Text.t("RT-09-29"), SMALL_FONT, GlassTheme.TEXT_DIM)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var adjust := _flat_button(foot, Text.t("RT-09-30"), "calendar", func() -> void: schedule_pressed.emit())
	adjust.add_theme_stylebox_override("normal", GlassTheme.selected_box(8))
	# 最后一周结束直接进结局，课不会再结算，排了也没用
	adjust.disabled = GameState.week >= int(DataDB.balance("last_week"))


## 成长记录：她这周写的周记（平板里能看每一周）
func _fill_growth() -> void:
	var written := RoomRules.journal_weeks()
	if written.is_empty():
		_center_header("book", Text.t("RT-09-11"), "")
		_wrap(_label(_center_box, Text.t("RT-04-60"), 12))
		return
	_center_header("book", Text.t("RT-09-11"), Text.f("TB-06-01", {"week": written[-1]}))
	for line in RoomRules.journal_text(written[-1]):
		_wrap(_label(_center_box, line, 12))


## 记忆日志：她记住的约定、喜好和最近几周的事
func _fill_memory() -> void:
	_center_header("chat", Text.t("RT-09-33"), "")
	var lines := PackedStringArray()
	if GameState.memory != null:
		for item: Dictionary in GameState.memory.core:
			lines.append("· " + str(item.get("text", "")))
		var events: Array[Dictionary] = GameState.memory.events
		for i in range(events.size() - 1, maxi(events.size() - 1 - MEMORY_SHOWN, -1), -1):
			lines.append(Text.f("RT-09-35", {"week": events[i].get("week", 0), "text": events[i].get("text", "")}))
	if lines.is_empty():
		lines.append(Text.t("RT-09-34"))
	for line in lines:
		_wrap(_label(_center_box, line, 12))


## 方舟总览：地球情况 + 方舟各处哪些能去
func _fill_overview() -> void:
	_center_header("globe", Text.t("RT-09-13"), "")
	for line in RoomRules.earth_lines():
		_wrap(_label(_center_box, line, 12))
	_center_box.add_child(HSeparator.new())
	_label(_center_box, Text.t("RT-09-40"), 12)
	for row in RoomRules.elevator_places():
		if row["id"] == "cabin":
			continue
		var key := "RT-09-42" if RoomRules.is_place_open(row["id"]) else "RT-09-41"
		_label(_center_box, Text.f(key, {"name": Text.t(row["name_key"]), "week": row["open_week"]}), 12, GlassTheme.TEXT_DIM)


# ---------- 右边竖排菜单 ----------

func _build_right_menu() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(6))
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT, Control.PRESET_MODE_MINSIZE)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.offset_right = -MARGIN
	panel.custom_minimum_size.x = RIGHT_WIDTH
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	_status_button = _menu_button(box, "pulse", Text.t("RT-09-31"), toggle_status)
	# 课程：滑出"本周成长计划"，里面的"调整计划"才进课表
	_plan_button = _menu_button(box, "book", Text.t("UI-01-03"), func() -> void: show_tab("plan"))
	var town_button := _menu_button(box, "globe", Text.t("UI-01-01"), func() -> void: town_pressed.emit())
	town_button.disabled = not WeekSystem.is_earth_open()


func _menu_button(parent: Control, icon_name: String, text: String, on_pressed: Callable) -> Button:
	var button := _flat_button(parent, text, icon_name, on_pressed)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size.y = 32
	return button


# ---------- 左下：她在做什么、她说的话 ----------

func _build_bubble() -> void:
	var bubble := _corner_panel(Control.PRESET_BOTTOM_LEFT)
	bubble.add_theme_stylebox_override("panel", _panel_style(9))
	bubble.offset_left = MARGIN
	bubble.offset_bottom = -MARGIN
	bubble.custom_minimum_size.x = BUBBLE_WIDTH
	var box := VBoxContainer.new()
	bubble.add_child(box)
	var head := _row(box, 8)
	_icon(head, "wave", ICON_SMALL).modulate = GlassTheme.ACCENT
	_label(head, GameState.girl_name, 12, GlassTheme.ACCENT)
	_label(head, "···", 12, GlassTheme.TEXT_DIM)
	# 人物 AI 线程的 ChatPresence：她自己做事、偶尔主动开口（比赛版 4.5）
	var presence := ChatPresence.new()
	presence.custom_minimum_size.x = BUBBLE_WIDTH - 32.0
	box.add_child(presence)
	presence.spoke.connect(func(_text: String, _action: String) -> void: room.set_exclaim(true))


# ---------- 底部：第 7 周去地下、结束本周 ----------

func _build_bottom() -> void:
	var holder := _corner_panel(Control.PRESET_CENTER_BOTTOM)
	holder.add_theme_stylebox_override("panel", _panel_style(6))
	holder.offset_bottom = -MARGIN
	var row := _row(holder, 10)
	if RoomRules.can_go_underground():
		_flat_button(row, Text.t("RT-07-02"), "down", func() -> void: place_pressed.emit("underground"))
	var end_button := _flat_button(row, Text.t("UI-01-04"), "moon", func() -> void: _confirm.ask())
	end_button.add_theme_stylebox_override("normal", GlassTheme.selected_box(10))


func _build_time() -> void:
	var badge := _corner_panel(Control.PRESET_BOTTOM_RIGHT)
	badge.add_theme_stylebox_override("panel", _panel_style(6))
	badge.offset_right = -MARGIN
	badge.offset_bottom = -MARGIN
	var row := _row(badge, 10)
	_icon(row, "clock", ICON_SIZE + 4).modulate = GlassTheme.ACCENT
	var box := VBoxContainer.new()
	row.add_child(box)
	_label(box, Text.t("RT-09-08"), SMALL_FONT, GlassTheme.TEXT_DIM)
	_label(box, Text.f("RT-09-09", {"week": GameState.week, "last": int(DataDB.balance("last_week"))}), 12)


# ---------- 弹出 ----------

func open_tablet() -> void:
	if tablet == null:
		tablet = TabletPanel.new()
		tablet.changed.connect(room.refresh)
		add_child(tablet)
	tablet.visible = true


## 手动存档：两个存档位（yi 11.19 定）。主界面不会在剧情中，所以这里总能存
func open_save() -> void:
	var panel := SaveSlotsPanel.new()
	panel.saving = true
	add_child(panel)


func open_elevator() -> void:
	if elevator == null:
		elevator = ElevatorMenu.new()
		elevator.place_chosen.connect(func(id: String) -> void: place_pressed.emit(id))
		add_child(elevator)
	elevator.visible = true


# ---------- 面板滑出 / 收起 ----------

func toggle_status() -> void:
	var opening := not _status_panel.visible
	_slide(_status_panel, opening, -SLIDE_DISTANCE)
	_mark(_status_button, opening)


## 打开：从旁边滑进来并淡入；收起：滑回去淡出，然后藏起来。from_x 是从哪边滑（正数从右边）
## 用 position 做动画会被容器摆回去，所以只对不在容器里的面板滑位置，在容器里的只淡入淡出
func _slide(panel: Control, opening: bool, from_x: float) -> void:
	if _tweens.has(panel):
		(_tweens[panel] as Tween).kill()
	if not is_inside_tree():
		panel.visible = opening
		panel.modulate.a = 1.0
		return
	var movable := not (panel.get_parent() is Container)
	if not panel.has_meta("home"):
		panel.set_meta("home", panel.position)
	var home: Vector2 = panel.get_meta("home")
	var shift := Vector2(from_x, 0)
	if opening:
		panel.visible = true
		panel.modulate.a = 0.0
		if movable:
			panel.position = home + shift
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "modulate:a", 1.0 if opening else 0.0, SLIDE_TIME)
	if movable:
		tween.tween_property(panel, "position", home if opening else home + shift, SLIDE_TIME)
	if not opening:
		tween.chain().tween_callback(func() -> void:
			panel.visible = false
			if movable:
				panel.position = home)
	_tweens[panel] = tween


## 打开着的按钮亮起来
func _mark(button: Button, on: bool) -> void:
	if button == null:
		return
	if on:
		button.add_theme_stylebox_override("normal", GlassTheme.selected_box(10))
	else:
		button.remove_theme_stylebox_override("normal")


# ---------- 点她以后冒出来的"聊天" ----------

func _build_talk_button() -> void:
	talk_button = _flat_button(self, Text.t("RT-09-43"), "chat", func() -> void:
		talk_button.visible = false
		chat_pressed.emit())
	talk_button.add_theme_stylebox_override("normal", GlassTheme.selected_box(8))
	talk_button.visible = false


## 在她头顶旁边出现，过几秒自己消失
func _show_talk_button() -> void:
	var girl: Node3D = room.bodies.get("girl")
	var spot := size / 2.0
	if girl != null and room.camera.is_inside_tree():
		spot = room.camera.unproject_position(girl.global_position + TALK_OFFSET)
	talk_button.visible = true
	talk_button.reset_size()
	talk_button.position = spot - Vector2(talk_button.size.x / 2.0, talk_button.size.y)
	if is_inside_tree():
		talk_button.modulate.a = 0.0
		create_tween().tween_property(talk_button, "modulate:a", 1.0, SLIDE_TIME)
		get_tree().create_timer(TALK_SHOW_SEC).timeout.connect(func() -> void:
			if is_instance_valid(talk_button):
				talk_button.visible = false)


# ---------- 小工具 ----------

## 主界面的面板：外面一圈淡淡的蓝光，顶边亮一点，像参考图的发光边
func _panel_style(padding: int) -> StyleBoxFlat:
	var style := GlassTheme.box(GlassTheme.BG, GlassTheme.BORDER, GlassTheme.RADIUS, padding)
	style.shadow_color = Color(GlassTheme.ACCENT, 0.18)
	style.shadow_size = 8
	style.border_width_top = 2
	return style


## 贴在屏幕某个角落的面板，按内容自动变大
func _corner_panel(preset: Control.LayoutPreset) -> PanelContainer:
	var panel := PanelContainer.new()
	add_child(panel)
	panel.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE)
	match preset:
		Control.PRESET_BOTTOM_LEFT, Control.PRESET_BOTTOM_RIGHT, Control.PRESET_CENTER_BOTTOM:
			panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	match preset:
		Control.PRESET_BOTTOM_RIGHT:
			panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		Control.PRESET_CENTER_BOTTOM:
			panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	return panel


func _header(parent: Control, icon_name: String, text: String) -> void:
	var head := _row(parent, 8)
	_icon(head, icon_name, ICON_SMALL).modulate = GlassTheme.ACCENT
	_label(head, text, 13)
	parent.add_child(HSeparator.new())


func _row(parent: Control, gap: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", gap)
	parent.add_child(row)
	return row


## 横排里把后面的东西推到最右边
func _spacer(parent: Control) -> void:
	var space := Control.new()
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(space)


func _gap(parent: Control, width: float) -> void:
	var gap := Control.new()
	gap.custom_minimum_size.x = width
	parent.add_child(gap)


func _label(parent: Control, text: String, font_size: int, color: Color = GlassTheme.TEXT) -> Label:
	var label := UiKit.short_label(parent, text)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


## 长句要换行：给定宽度，不然自动换行的字会被挤成一字一行
func _wrap(label: Label) -> void:
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = CENTER_WIDTH - 40.0


func _warn(parent: Control, text: String) -> void:
	var row := _row(parent, 6)
	_icon(row, "warn", ICON_SMALL).modulate = Color(1.0, 0.75, 0.45)
	_label(row, text, SMALL_FONT, Color(1.0, 0.75, 0.45))


func _icon(parent: Control, icon_name: String, icon_size: int) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = load(ICON_DIR + icon_name + ".svg")
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(icon_size, icon_size)
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	return rect


func _flat_button(parent: Control, text: String, icon_name: String, on_pressed: Callable) -> Button:
	var button := UiKit.button(parent, text, on_pressed)
	if not icon_name.is_empty():
		button.icon = load(ICON_DIR + icon_name + ".svg")
		button.add_theme_constant_override("icon_max_width", ICON_SIZE)
		button.add_theme_constant_override("h_separation", 8)
	return button


func _icon_button(parent: Control, icon_name: String, on_pressed: Callable) -> Button:
	var button := _flat_button(parent, "", icon_name, on_pressed)
	button.custom_minimum_size = Vector2(28, 24)
	return button


## yi 定的：属性都显示数字，文字说明只在鼠标放上去时显示。
## 性格和信任的说明随数值变化，其他属性是固定说明。
static func stat_hover_text(id: String) -> String:
	var row := DataDB.row("girl_stats", id)
	var key := str(row.get("desc_key", ""))
	if key.is_empty():
		return GameState.trait_text(id, GameState.get_stat(id), GameState.age)
	return Text.t(key)
