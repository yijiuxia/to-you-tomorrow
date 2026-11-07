extends Control
## 课表：给 7 天各选一门课。第 1 周点确认后马上结算，其他周只是保存。

signal finished

const DAY_KEY_START := 11
const EFFECT_ORDER: Array[String] = ["stamina", "stamina_max", "mood", "mechanics", "ecology", "comms", "confidence", "curiosity", "empathy", "trust"]

var first_time := false  # 第 1 周开场排课

var _pickers: Array[OptionButton] = []
var _course_ids: Array[String] = []
var _warning: Label


func _ready() -> void:
	for id: String in DataDB.table("courses"):
		_course_ids.append(id)
	var box := UiKit.page(self)
	UiKit.title(box, Text.f("UI-04-01", {"week": GameState.week}))
	UiKit.label(box, Text.t("UI-04-02"))
	for day in int(DataDB.balance("week_days")):
		_add_day_row(box, day)
	_warning = UiKit.label(box, "")
	UiKit.spacer(box)
	var buttons := UiKit.row(box)
	UiKit.button(buttons, Text.t("UI-04-03"), _use_last_week)
	UiKit.button(buttons, Text.t("UI-04-04"), _rest_all)
	UiKit.button(buttons, Text.t("UI-04-08") if first_time else Text.t("UI-04-05"), _save)
	_refresh_warning()


func _add_day_row(parent: Control, day: int) -> void:
	var line := UiKit.row(parent)
	UiKit.short_label(line, day_name(day))
	var picker := OptionButton.new()
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for id in _course_ids:
		picker.add_item(_course_name(id))
		picker.get_popup().set_item_tooltip(picker.item_count - 1, course_hover_text(id))
	picker.select(_course_ids.find(GameState.schedule[day]))
	picker.tooltip_text = course_hover_text(GameState.schedule[day])
	picker.item_selected.connect(func(_index: int) -> void: _on_course_changed(picker))
	line.add_child(picker)
	_pickers.append(picker)


func _course_name(id: String) -> String:
	return Text.t(DataDB.row("courses", id)["name_key"])


func _on_course_changed(picker: OptionButton) -> void:
	picker.tooltip_text = course_hover_text(_course_ids[picker.selected])
	_refresh_warning()


## yi 定的：列表只显示课程名，说明和效果放在鼠标悬停里。
## 都从表格拼出来，改数值后这里自动变。
static func course_hover_text(id: String) -> String:
	var row := DataDB.row("courses", id)
	var effects: PackedStringArray = []
	for stat in EFFECT_ORDER:
		var delta := int(row.get(stat, 0))
		if delta != 0:
			effects.append("%s %+d" % [UiKit.stat_name(stat), delta])
	return "%s\n%s" % [Text.t(row["desc_key"]), " · ".join(effects)]


func _current_plan() -> Array[String]:
	var plan: Array[String] = []
	for picker in _pickers:
		plan.append(_course_ids[picker.selected])
	return plan


## 程序按规则算出她哪天累倒（demo 文案：旁白不说谎）。
## 预演要从下周开始时的体力算，所以先加上周末恢复。
func _refresh_warning() -> void:
	var start := GameState.stats.duplicate()
	if not first_time:
		start["stamina"] = GameState.clamp_value("stamina", int(start["stamina"]) + int(DataDB.balance("stamina_weekly_recover")), start)
	var day := CourseSystem.first_collapse_day(_current_plan(), start)
	_warning.text = Text.f("UI-04-06", {"day": day_name(day)}) if day >= 0 else ""


func _use_last_week() -> void:
	_fill(GameState.last_schedule)


func _rest_all() -> void:
	var plan: Array[String] = []
	for _i in _pickers.size():
		plan.append(CourseSystem.REST)
	_fill(plan)


func _fill(plan: Array[String]) -> void:
	for day in _pickers.size():
		_pickers[day].select(_course_ids.find(plan[day]))
		_pickers[day].tooltip_text = course_hover_text(plan[day])
	_refresh_warning()


func _save() -> void:
	GameState.schedule = _current_plan()
	finished.emit()


static func day_name(day: int) -> String:
	return Text.t("UI-04-%02d" % (DAY_KEY_START + day))
