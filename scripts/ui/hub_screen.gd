extends Control
## 主界面：属性面板 + 四个按钮（小镇 / 聊天 / 课表 / 结束本周）。

signal town_pressed
signal chat_pressed
signal schedule_pressed
signal end_week_confirmed
signal place_pressed(id: String)  # 房间线程加：从舱门电梯或第 7 周按钮去别的场所

const NUMBER_STATS: Array[String] = ["mood", "mechanics", "ecology", "comms", "confidence", "curiosity", "empathy", "trust"]
const GIRL_BLOCK_COLOR := Color(0.35, 0.45, 0.6)
const PANEL_MIN_WIDTH := 420.0

const EndWeekDialog := preload("res://scripts/ui/end_week_dialog.gd")

var _confirm: EndWeekDialog
var room: RoomView          # 房间线程加：主界面中间换成 3D 房间
var tablet: TabletPanel
var elevator: ElevatorMenu


func _ready() -> void:
	var box := UiKit.page(self)
	UiKit.title(box, Text.f("UI-01-05", {"week": GameState.week, "girl": GameState.girl_name, "age": GameState.age}))
	if GameState.girl_intent != "none":
		UiKit.label(box, Text.f("UI-01-06", {"girl": GameState.girl_name, "intent": Text.t("UI-12-" + GameState.girl_intent)}))

	var middle := UiKit.row(box)
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_build_girl_block(middle)
	_build_stat_panel(middle)

	var buttons := UiKit.row(box)
	var town_button := UiKit.button(buttons, Text.t("UI-01-01"), func() -> void: town_pressed.emit())
	town_button.disabled = not WeekSystem.is_earth_open()
	UiKit.button(buttons, Text.t("UI-01-02"), func() -> void: chat_pressed.emit())
	var schedule_button := UiKit.button(buttons, Text.t("UI-01-03"), func() -> void: schedule_pressed.emit())
	# 最后一周结束直接进结局，课不会再结算，排了也没用
	schedule_button.disabled = GameState.week >= int(DataDB.balance("last_week"))
	UiKit.button(buttons, Text.t("UI-01-04"), func() -> void: _confirm.ask())
	# 房间线程加：第 7 周跟幸存者去地下居民区
	if RoomRules.can_go_underground():
		UiKit.button(buttons, Text.t("RM-07-02"), func() -> void: place_pressed.emit("underground"))

	_confirm = EndWeekDialog.new()
	_confirm.confirmed.connect(func() -> void: end_week_confirmed.emit())
	add_child(_confirm)


## 房间线程改：原来她的位置是一个方块，现在换成 3D 房间（她坐在书桌前），房间里的东西都能点。
func _build_girl_block(parent: Control) -> void:
	room = RoomView.new()
	room.scene_id = "cabin"
	parent.add_child(room)
	room.talk_requested.connect(func() -> void: chat_pressed.emit())
	room.tablet_requested.connect(open_tablet)
	room.door_requested.connect(open_elevator)
	# 人物 AI 线程加：她自己做事、偶尔主动开口（比赛版 4.5）
	var presence := ChatPresence.new()
	presence.set_anchors_preset(Control.PRESET_TOP_WIDE)
	presence.mouse_filter = Control.MOUSE_FILTER_IGNORE
	room.add_child(presence)
	presence.spoke.connect(func(_text: String, _action: String) -> void: room.set_exclaim(true))
	var hint := UiKit.short_label(room, Text.t("RM-02-17"))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hint.grow_vertical = Control.GROW_DIRECTION_BEGIN


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


func _build_stat_panel(parent: Control) -> void:
	var panel := VBoxContainer.new()
	panel.custom_minimum_size.x = PANEL_MIN_WIDTH
	parent.add_child(panel)
	var stamina := UiKit.label(panel, "%s %d / %d" % [UiKit.stat_name("stamina"), GameState.get_stat("stamina"), GameState.get_stat("stamina_max")])
	UiKit.set_hover_text(stamina, stat_hover_text("stamina"))
	for id in NUMBER_STATS:
		var line := UiKit.label(panel, "%s %d" % [UiKit.stat_name(id), GameState.get_stat(id)])
		UiKit.set_hover_text(line, stat_hover_text(id))
	var low_stamina := int(DataDB.balance("low_stamina"))
	if GameState.get_stat("stamina") <= 0:
		UiKit.label(panel, Text.t("UI-02-12"))
	elif GameState.get_stat("stamina") < low_stamina:
		UiKit.label(panel, Text.t("UI-02-11"))
	if GameState.get_stat("mood") < int(DataDB.balance("low_mood")):
		UiKit.label(panel, Text.t("UI-02-13"))


## yi 定的：属性都显示数字，文字说明只在鼠标放上去时显示。
## 性格和信任的说明随数值变化，其他属性是固定说明。
static func stat_hover_text(id: String) -> String:
	var row := DataDB.row("girl_stats", id)
	var key := str(row.get("desc_key", ""))
	if key.is_empty():
		return GameState.trait_text(id, GameState.get_stat(id), GameState.age)
	return Text.t(key)
