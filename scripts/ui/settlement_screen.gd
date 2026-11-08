extends Control
## 早上 + 课程结算：一天一行结果文字，可以点"继续"跳过等待。

signal finished

const Schedule := preload("res://scripts/ui/schedule_screen.gd")

var _lines: VBoxContainer
var _button: Button
var _pending: PackedStringArray = []
var _next_line := 0


func _ready() -> void:
	var box := UiKit.page(self)
	UiKit.title(box, Text.f("WK-01-02", {"week": GameState.week}))
	var morning := UiKit.label(box, "")  # 人物 AI 线程改：早安第 4 周起由模型说，说完再填（ChatLines.morning_line）
	_lines = VBoxContainer.new()
	box.add_child(_lines)
	UiKit.spacer(box)
	_button = UiKit.button(box, Text.t("UI-06-01"), _on_button)

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var results := WeekSystem.settle_schedule(rng)
	for result in results:
		_pending.append(_line_text(result))
	_reveal_next()
	_add_girl_lines(morning, results)


## 人物 AI 线程加：早安、上课小事件由她说（模型失败用固定句），同时把上周的课记进她的记忆
func _add_girl_lines(morning: Label, results: Array[Dictionary]) -> void:
	morning.text = await ChatLines.morning_line(results)
	for result in results:
		if result["event"] and is_inside_tree():
			var line := await ChatLines.course_event(result["course"], Schedule.day_name(result["day"]))
			if is_inside_tree():
				UiKit.label(_lines, Text.f("UI-41-11", {"text": line["reply"]}))


func _line_text(result: Dictionary) -> String:
	var row := DataDB.row("courses", result["course"])
	var text := Text.t(row["result_key"])
	match result["status"]:
		CourseSystem.STATUS_SICK:
			text = Text.t("CR-STATUS-SICK")
		CourseSystem.STATUS_REFUSED:
			text = Text.t("CR-STATUS-REFUSED")
		CourseSystem.STATUS_TIRED:
			text = Text.t("CR-STATUS-TIRED")
	if result["event"]:
		text += " " + Text.t("CR-EVENT-01")
	return Text.f("CR-LINE", {"day": Schedule.day_name(result["day"]), "course": Text.t(row["name_key"]), "result": text})


func _reveal_next() -> void:
	if _next_line >= _pending.size() or not is_inside_tree():
		return
	UiKit.label(_lines, _pending[_next_line])
	_next_line += 1
	if _next_line < _pending.size():
		get_tree().create_timer(float(DataDB.balance("settle_line_sec"))).timeout.connect(_reveal_next)


## 还没放完时点一下先全部放完，放完再点才离开
func _on_button() -> void:
	if _next_line < _pending.size():
		while _next_line < _pending.size():
			_reveal_next()
		return
	finished.emit()
