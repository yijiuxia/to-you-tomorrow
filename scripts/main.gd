extends Control
## 游戏总流程：决定现在显示哪个画面。规则都在 systems/，这里只管切换。
## 第 1 周：开局排课 → 主界面（聊天 / 课表）→ 结束本周 → 周结算
## 之后每周：早上课程结算 → 主界面（小镇 / 聊天 / 课表）→ 结束本周 → 周结算
## 第 3 周后插入时间跳跃，第 7 周后进结局。
## 界面线程加的：标题页 → 起名 → 开场剧情 → 第 1 周；结局 → 制作人员 → 标题页。
## 每周开始自动存档；几个固定时刻问 StoryTriggers 有没有剧情要播（见 story/nodes.csv）；Esc 暂停。

const HubScreen := preload("res://scripts/ui/hub_screen.gd")
const ScheduleScreen := preload("res://scripts/ui/schedule_screen.gd")
const SettlementScreen := preload("res://scripts/ui/settlement_screen.gd")
const ChatScreen := preload("res://scripts/ui/chat_screen.gd")
const TextPageScreen := preload("res://scripts/ui/text_page_screen.gd")
const EarthScreen := preload("res://scripts/earth/earth_screen.gd")
const TitleScreen := preload("res://scripts/ui/title_screen.gd")
const NameScreen := preload("res://scripts/ui/name_screen.gd")
const StoryScreen := preload("res://scripts/ui/story_screen.gd")
const CreditsScreen := preload("res://scripts/ui/credits_screen.gd")
const PauseMenu := preload("res://scripts/ui/pause_menu.gd")

var current: Control = null  # 当前画面，自动测试也用它来点按钮
var pause_menu: PauseMenu


func _ready() -> void:
	get_tree().root.theme = GlassTheme.make()  # 房间线程加：全部画面用玻璃面板样式（11.19 界面改版）
	SaveSettings.load_and_apply()  # 先读设置：语言要在第一个画面出来前定好
	ModelService.ensure_loaded()  # 后台加载，不挡住界面；没加载好时聊天用后备句
	pause_menu = PauseMenu.new()
	pause_menu.to_title_pressed.connect(show_title)
	pause_menu.language_changed.connect(_on_language_changed)
	add_child(pause_menu)
	show_title()


func show_title() -> void:
	get_tree().paused = false
	var screen := TitleScreen.new()
	screen.new_game_pressed.connect(show_naming)
	screen.continue_pressed.connect(continue_game)
	screen.credits_pressed.connect(show_credits)
	screen.language_changed.connect(_on_language_changed)
	_show(screen)


func show_naming() -> void:
	GameState.reset()
	var screen := NameScreen.new()
	screen.finished.connect(func() -> void: _play_story("new_game", _begin_first_week))
	_show(screen)


## 起名和开场之后：先存一次档（第 1 周开始），再排第一周的课
func _begin_first_week() -> void:
	SaveSystem.save()
	start_game()


## 读自动存档。存档是在每周开始时存的，所以读完从那一周的开头接着玩。
func continue_game() -> void:
	if not SaveSystem.load_save():
		show_title()
		return
	if GameState.week < int(DataDB.balance("first_class_week")):
		start_game()
	else:
		show_settlement()


func show_credits() -> void:
	var screen := CreditsScreen.new()
	screen.finished.connect(show_title)
	_show(screen)


## 第 1 周开场排课（新游戏的状态在 show_naming 里已经重置）
func start_game() -> void:
	var screen := ScheduleScreen.new()
	screen.first_time = true
	screen.finished.connect(_week_start_story)
	_show(screen)


func show_settlement() -> void:
	var screen := SettlementScreen.new()
	screen.finished.connect(_week_start_story)
	_show(screen)


func _week_start_story() -> void:
	_play_story("week_start", show_hub)


func show_hub() -> void:
	var screen := HubScreen.new()
	screen.town_pressed.connect(show_town)
	screen.chat_pressed.connect(show_chat)
	screen.schedule_pressed.connect(show_schedule)
	screen.end_week_confirmed.connect(_on_end_week)
	screen.place_pressed.connect(show_place)  # 房间线程加
	_show(screen)


## 房间线程加：去机械室、温室、通讯室、人类保护区、地下居民区，看完回主界面
func show_place(id: String) -> void:
	var screen := PlaceScreen.new()
	screen.place_id = id
	screen.finished.connect(show_hub)
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
	screen.end_week_confirmed.connect(_on_end_week)
	_show(screen)


func _on_end_week() -> void:
	_play_story("week_end", show_week_summary)


func show_week_summary() -> void:
	var recovered := WeekSystem.end_week()
	var lines := PageText.week_summary(recovered)
	lines.append(await ChatLines.week_end_line())  # 人物 AI 线程加：把本周的事记进她的记忆，她说一句周总结
	_show_page(Text.f("UI-07-01", {"week": GameState.week}), lines, Text.t("UI-06-01"), func() -> void: _play_story("week_night", _after_summary))


## 周结算页关掉、夜里的剧情（week_night，如第 1 周看地球）播完之后：
## 第 3 周后先播蒙太奇（time_jump）再跳跃和"这些年"页；第 7 周后播结局和尾声（ending），接制作人员名单
func _after_summary() -> void:
	match WeekSystem.next_stage():
		WeekSystem.NEXT_ENDING:
			_play_story("ending", show_credits)
		WeekSystem.NEXT_JUMP:
			_play_story("time_jump", _show_time_jump)
		_:
			_start_next_week()


func _show_time_jump() -> void:
	var old_age := GameState.age
	var before := WeekSystem.apply_time_jump()
	_show_page(Text.t("TJ-03-01"), PageText.time_jump(before, old_age), Text.t("TJ-03-10"), func() -> void: _play_story("after_jump", _start_next_week))


func _start_next_week() -> void:
	WeekSystem.start_next_week()
	SaveSystem.save()  # yi 定：每周开始自动存一次
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


## 问剧情表这个时刻有没有要播的，一段段播完再去 next；没有就直接去 next
func _play_story(moment: String, next: Callable) -> void:
	_play_nodes(StoryTriggers.pick(moment), 0, next)


func _play_nodes(nodes: Array[Dictionary], index: int, next: Callable) -> void:
	if index >= nodes.size():
		next.call()
		return
	var screen := StoryScreen.new()
	screen.node = nodes[index]
	screen.finished.connect(func() -> void: _play_nodes(nodes, index + 1, next))
	_show(screen)


## Esc 打开暂停。用 _input 而不是 _unhandled_input：要赶在小镇画面之前判断，
## 小镇正在放建筑时 Esc 是"取消放置"，不打开暂停。
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE):
		return
	if get_tree().paused or not _can_pause():
		return
	pause_menu.open()
	get_viewport().set_input_as_handled()


func _can_pause() -> bool:
	if current == null or current is TitleScreen or current is NameScreen or current is CreditsScreen:
		return false
	var placing: Variant = current.get("placing_type")
	return not (placing is String and not placing.is_empty())


## 换语言后，能安全重建的画面马上重建；其他画面下次打开时换（比如课程结算重建会再结算一次）
func _on_language_changed() -> void:
	if current is TitleScreen:
		show_title()
		var title: TitleScreen = current
		title.open_settings()
	elif current is HubScreen:
		show_hub()
