extends Control
## 主界面（房间线程 11.19 按 yi 的参考图"方舟生活"重排）：
## 3D 房间铺满整个画面，界面都是浮在上面的玻璃面板——
## 顶栏（方舟生活 + 周数 + 材料）、左上人物卡、左边当前状态、左下她说的话、底部按钮、右下周数。
## 按钮还是原来那几个（地球建造 / 聊天 / 课表 / 结束本周），多了"终端"（打开平板）。

signal town_pressed
signal chat_pressed
signal schedule_pressed
signal end_week_confirmed
signal place_pressed(id: String)  # 房间线程加：从舱门电梯或第 7 周按钮去别的场所

const BAR_STATS: Array[String] = ["mood", "stamina", "curiosity", "empathy", "confidence", "trust"]
const SKILL_STATS: Array[String] = ["mechanics", "ecology", "comms"]
const MARGIN := 16
const LEFT_WIDTH := 330.0
const BAR_HEIGHT := 6.0
const AVATAR_SIZE := 64.0
const BUBBLE_WIDTH := 460.0
const SMALL_FONT := 14

const EndWeekDialog := preload("res://scripts/ui/end_week_dialog.gd")

var _confirm: EndWeekDialog
var room: RoomView
var tablet: TabletPanel
var elevator: ElevatorMenu


func _ready() -> void:
	room = RoomView.new()
	room.scene_id = "cabin"
	room.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(room)
	room.talk_requested.connect(func() -> void: chat_pressed.emit())
	room.tablet_requested.connect(open_tablet)
	room.door_requested.connect(open_elevator)

	_build_top_bar()
	_build_left_column()
	_build_bubble()
	_build_buttons()
	_build_week_badge()

	_confirm = EndWeekDialog.new()
	_confirm.confirmed.connect(func() -> void: end_week_confirmed.emit())
	add_child(_confirm)


# ---------- 顶栏 ----------

func _build_top_bar() -> void:
	var bar := _panel(Control.PRESET_TOP_WIDE)
	bar.offset_left = MARGIN
	bar.offset_right = -MARGIN
	bar.offset_top = MARGIN
	var row := UiKit.row(bar)
	UiKit.short_label(row, Text.t("RM-09-01")).add_theme_font_size_override("font_size", 22)
	_dim(UiKit.short_label(row, Text.f("UI-01-05", {"week": GameState.week, "girl": GameState.girl_name, "age": GameState.age})))
	if GameState.girl_intent != "none":
		_dim(UiKit.short_label(row, Text.f("UI-01-06", {"girl": GameState.girl_name, "intent": Text.t("UI-12-" + GameState.girl_intent)})))
	UiKit.spacer(row)
	if WeekSystem.is_earth_open() and GameState.earth != null:
		UiKit.short_label(row, Text.f("RM-09-02", {"value": GameState.earth.metal}))
		UiKit.short_label(row, Text.f("RM-09-03", {"value": GameState.earth.electronics}))


# ---------- 左边：人物卡 + 当前状态 ----------

func _build_left_column() -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.position = Vector2(MARGIN, 84)
	column.custom_minimum_size.x = LEFT_WIDTH
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	_build_card(column)
	_build_stat_panel(column)


func _build_card(parent: Control) -> void:
	var card := PanelContainer.new()
	parent.add_child(card)
	var row := UiKit.row(card)
	# 头像还没有素材：先放一个写着名字第一个字的圆
	var avatar := PanelContainer.new()
	avatar.custom_minimum_size = Vector2(AVATAR_SIZE, AVATAR_SIZE)
	avatar.size_flags_vertical = Control.SIZE_SHRINK_CENTER  # 不被拉成椭圆
	avatar.add_theme_stylebox_override("panel", GlassTheme.box(Color(GlassTheme.ACCENT, 0.25), GlassTheme.BORDER_HOVER, int(AVATAR_SIZE / 2.0) - 1, 0))  # 圆角正好一半时中间会有一条缝，减 1
	row.add_child(avatar)
	var initial := UiKit.short_label(avatar, GameState.girl_name.left(1))
	initial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	initial.add_theme_font_size_override("font_size", 28)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	UiKit.short_label(info, GameState.girl_name).add_theme_font_size_override("font_size", 22)
	_dim(UiKit.short_label(info, Text.f("RM-09-04", {"age": GameState.age, "week": GameState.week})))
	_bar_line(info, "trust")


func _build_stat_panel(parent: Control) -> void:
	var panel := PanelContainer.new()
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	UiKit.short_label(box, Text.t("RM-09-05"))
	for id in BAR_STATS:
		if id != "trust":
			_bar_line(box, id)
	var skills := UiKit.row(box)
	for id in SKILL_STATS:
		var skill := _dim(UiKit.short_label(skills, "%s %d" % [UiKit.stat_name(id), GameState.get_stat(id)]))
		UiKit.set_hover_text(skill, stat_hover_text(id))
	# 累了、病了、心情低的提醒
	var low_stamina := int(DataDB.balance("low_stamina"))
	if GameState.get_stat("stamina") <= 0:
		_warn(UiKit.label(box, Text.t("UI-02-12")))
	elif GameState.get_stat("stamina") < low_stamina:
		_warn(UiKit.label(box, Text.t("UI-02-11")))
	if GameState.get_stat("mood") < int(DataDB.balance("low_mood")):
		_warn(UiKit.label(box, Text.t("UI-02-13")))


## 一行属性：名字 …… 数值 / 上限，下面一条进度条；鼠标指上去看说明
func _bar_line(parent: Control, id: String) -> void:
	var line := VBoxContainer.new()
	line.add_theme_constant_override("separation", 2)
	parent.add_child(line)
	var head := UiKit.row(line)
	UiKit.short_label(head, UiKit.stat_name(id))
	UiKit.spacer(head)
	var top := stat_max(id)
	_dim(UiKit.short_label(head, "%d / %d" % [GameState.get_stat(id), top]))
	var bar := ProgressBar.new()
	bar.max_value = top
	bar.value = GameState.get_stat(id)
	bar.show_percentage = false
	bar.custom_minimum_size.y = BAR_HEIGHT
	line.add_child(bar)
	UiKit.set_hover_text(line, stat_hover_text(id))


static func stat_max(id: String) -> int:
	var value: Variant = DataDB.row("girl_stats", id).get("max", 100)
	if value is String:  # 体力的上限写的是 stamina_max，取那个属性的当前值
		return GameState.get_stat(value)
	return int(value)


# ---------- 左下：她在做什么、她说的话 ----------

func _build_bubble() -> void:
	var bubble := _panel(Control.PRESET_BOTTOM_LEFT)
	bubble.offset_left = MARGIN
	bubble.offset_bottom = -MARGIN
	bubble.custom_minimum_size.x = BUBBLE_WIDTH
	var box := VBoxContainer.new()
	bubble.add_child(box)
	var name_label := UiKit.short_label(box, Text.f("RM-09-06", {"girl": GameState.girl_name}))
	name_label.add_theme_color_override("font_color", GlassTheme.ACCENT)
	# 人物 AI 线程的 ChatPresence：她自己做事、偶尔主动开口（比赛版 4.5）
	var presence := ChatPresence.new()
	presence.custom_minimum_size.x = BUBBLE_WIDTH - 32.0
	box.add_child(presence)
	presence.spoke.connect(func(_text: String, _action: String) -> void: room.set_exclaim(true))


# ---------- 底部按钮 ----------

func _build_buttons() -> void:
	var holder := _panel(Control.PRESET_CENTER_BOTTOM)
	holder.offset_bottom = -MARGIN
	var buttons := UiKit.row(holder)
	UiKit.button(buttons, Text.t("UI-01-02"), func() -> void: chat_pressed.emit())
	var schedule_button := UiKit.button(buttons, Text.t("UI-01-03"), func() -> void: schedule_pressed.emit())
	# 最后一周结束直接进结局，课不会再结算，排了也没用
	schedule_button.disabled = GameState.week >= int(DataDB.balance("last_week"))
	var town_button := UiKit.button(buttons, Text.t("UI-01-01"), func() -> void: town_pressed.emit())
	town_button.disabled = not WeekSystem.is_earth_open()
	UiKit.button(buttons, Text.t("RM-09-07"), open_tablet)
	# 第 7 周跟幸存者去地下居民区
	if RoomRules.can_go_underground():
		UiKit.button(buttons, Text.t("RM-07-02"), func() -> void: place_pressed.emit("underground"))
	UiKit.button(buttons, Text.t("UI-01-04"), func() -> void: _confirm.ask())


func _build_week_badge() -> void:
	var badge := _panel(Control.PRESET_BOTTOM_RIGHT)
	badge.offset_right = -MARGIN
	badge.offset_bottom = -MARGIN
	var box := VBoxContainer.new()
	badge.add_child(box)
	_dim(UiKit.short_label(box, Text.t("RM-09-08")))
	UiKit.short_label(box, Text.f("RM-09-09", {"week": GameState.week, "last": int(DataDB.balance("last_week"))}))
	UiKit.short_label(box, Text.t("RM-02-17")).add_theme_font_size_override("font_size", SMALL_FONT - 2)


# ---------- 弹出 ----------

func open_tablet() -> void:
	if tablet == null:
		tablet = TabletPanel.new()
		tablet.changed.connect(room.refresh)
		add_child(tablet)
	tablet.visible = true


func open_elevator() -> void:
	if elevator == null:
		elevator = ElevatorMenu.new()
		elevator.place_chosen.connect(func(id: String) -> void: place_pressed.emit(id))
		add_child(elevator)
	elevator.visible = true


# ---------- 小工具 ----------

## 贴在屏幕某个角落的玻璃面板，按内容自动变大
func _panel(preset: Control.LayoutPreset) -> PanelContainer:
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


func _dim(label: Label) -> Label:
	label.add_theme_color_override("font_color", GlassTheme.TEXT_DIM)
	label.add_theme_font_size_override("font_size", SMALL_FONT)
	return label


func _warn(label: Label) -> Label:
	label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.45))
	label.add_theme_font_size_override("font_size", SMALL_FONT)
	return label


## yi 定的：属性都显示数字，文字说明只在鼠标放上去时显示。
## 性格和信任的说明随数值变化，其他属性是固定说明。
static func stat_hover_text(id: String) -> String:
	var row := DataDB.row("girl_stats", id)
	var key := str(row.get("desc_key", ""))
	if key.is_empty():
		return GameState.trait_text(id, GameState.get_stat(id), GameState.age)
	return Text.t(key)
