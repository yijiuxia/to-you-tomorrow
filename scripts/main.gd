extends Control
## 游戏总流程：决定现在显示哪个画面。规则都在 systems/，这里只管切换。
## 第 1 周：开局排课 → 主界面（聊天 / 课表）→ 结束本周 → 周结算
## 之后每周：早上课程结算 → 主界面（小镇 / 聊天 / 课表）→ 结束本周 → 周结算
## 第 3 周后插入时间跳跃，第 7 周后进结局。

const HubScreen := preload("res://scripts/ui/hub_screen.gd")
const ScheduleScreen := preload("res://scripts/ui/schedule_screen.gd")
const SettlementScreen := preload("res://scripts/ui/settlement_screen.gd")
const ChatScreen := preload("res://scripts/ui/chat_screen.gd")
const TextPageScreen := preload("res://scripts/ui/text_page_screen.gd")
const EarthScreen := preload("res://scripts/earth/earth_screen.gd")

var current: Control = null  # 当前画面，自动测试也用它来点按钮


func _ready() -> void:
	ModelService.ensure_loaded()  # 后台加载，不挡住界面；没加载好时聊天用后备句
	start_game()


func start_game() -> void:
	GameState.reset()
	var screen := ScheduleScreen.new()
	screen.first_time = true
	screen.finished.connect(show_hub)
	_show(screen)


func show_settlement() -> void:
	var screen := SettlementScreen.new()
	screen.finished.connect(show_hub)
	_show(screen)


func show_hub() -> void:
	var screen := HubScreen.new()
	screen.town_pressed.connect(show_town)
	screen.chat_pressed.connect(show_chat)
	screen.schedule_pressed.connect(show_schedule)
	screen.end_week_confirmed.connect(show_week_summary)
	_show(screen)


func show_schedule() -> void:
	var screen := ScheduleScreen.new()
	screen.finished.connect(show_hub)
	_show(screen)


func show_chat() -> void:
	var screen := ChatScreen.new()
	screen.finished.connect(show_hub)
	_show(screen)


func show_town() -> void:
	var screen := EarthScreen.new()
	screen.back_pressed.connect(show_hub)
	screen.end_week_confirmed.connect(show_week_summary)
	_show(screen)


func show_week_summary() -> void:
	var recovered := WeekSystem.end_week()
	var lines := PageText.week_summary(recovered)
	_show_page(Text.f("UI-07-01", {"week": GameState.week}), lines, Text.t("UI-06-01"), _after_summary)


func _after_summary() -> void:
	match WeekSystem.next_stage():
		WeekSystem.NEXT_ENDING:
			_show_page(Text.t("ED-01-01"), PageText.ending(), Text.t("ED-03-01"), start_game)
		WeekSystem.NEXT_JUMP:
			var old_age := GameState.age
			var before := WeekSystem.apply_time_jump()
			_show_page(Text.t("TJ-02-01"), PageText.time_jump(before, old_age), Text.t("UI-06-01"), _start_next_week)
		_:
			_start_next_week()


func _start_next_week() -> void:
	WeekSystem.start_next_week()
	show_settlement()


func _show_page(title: String, lines: PackedStringArray, button: String, next: Callable) -> void:
	var screen := TextPageScreen.new()
	screen.title_text = title
	screen.lines = lines
	screen.button_text = button
	screen.finished.connect(next)
	_show(screen)


func _show(screen: Control) -> void:
	if current != null:
		current.queue_free()
	current = screen
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(screen)
