extends Control
## 小镇画面：俯视和第三人称共用同一个 3D 场景，V 切换（比赛版 4.4）。
## 规则都在 EarthWorld，这里只把玩家操作转给规则，再把结果显示出来。

signal back_pressed
signal end_week_confirmed

const EndWeekDialog := preload("res://scripts/ui/end_week_dialog.gd")
const StoryScreen := preload("res://scripts/ui/story_screen.gd")
const MENU_ORDER: Array[String] = ["recycler", "repair_station", "generator", "power_node", "purifier", "water_pipe", "farm_plot", "soil_improver", "relay"]
const CONTINUOUS_TYPES: Array[String] = [EarthWorld.PIPE, EarthWorld.NODE_ID]  # 这些会连续放很多个
const GHOST_OK := Color(0.3, 1.0, 0.4, 0.5)
const GHOST_BAD := Color(1.0, 0.25, 0.2, 0.5)
const GHOST_HEIGHT := 1.0
const PANEL_WIDTH := 320.0
const ARK_START := Vector2i(8, 8)
const ROBOT_HOME := Vector2i(7, 6)
const ROBOT_SPACING := 1
const MESSAGE_SEC := 3.0

var world: EarthWorld
var view: EarthView
var top_camera: TopCamera
var ark: ArkController
var third_person := false
var placing_type := ""
var selected_ruin := ""
var selected_building := 0
var selected_prop := ""

var _robots: Array[RobotAgent] = []
var _ghost: MeshInstance3D
var _ghost_material: StandardMaterial3D
var _dragging_place := false
var _last_drag_cell := Vector2i(-1, -1)
var _confirm: EndWeekDialog
var _status: Label
var _recovery_label: Label
var _hint: Label
var _reason: Label
var _message: Label
var _prompt: Label
var _left_panel: PanelContainer
var _right_panel: PanelContainer
var _menu_buttons := {}
var _queue_box: VBoxContainer
var _info_box: VBoxContainer
var _message_left := 0.0
var _card: PanelContainer          # 她的方案 / 突发事件卡片：在画面中间，选完就消失
var _girl_line: Label              # 她的实时评论
var _comment_ready_at := 0.0       # 实时评论冷却（比赛版 4.4：最少隔 20 秒）
var _goal_label: Label
var _confirm_clear := ""           # 共情高时拆植物旁的废墟要点两次
var _last_region := ""
var _rng := RandomNumberGenerator.new()
var proposal: Dictionary = {}      # 当前等你回答的方案（测试也读它）
var event: Dictionary = {}         # 当前的突发事件
var _tutorial: PanelContainer      # 建造教学提示：在画面上方，不挡操作
var _tutorial_lines: Label
var _scraps_cut := 0
var _plant_area := Rect2i()        # 第 3 周植物事件：ARK-01 走近广场边缘就触发
var _story_playing := false
var _seed_jar_known := false
var _event_chat: ChatEventPanel = null  # 人物 AI 线程加：突发事件对话


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	world = GameState.earth
	_build_world()
	_build_hud()
	world.changed.connect(_on_world_changed)
	_on_world_changed()
	_set_third_person(false)
	_rng.randomize()
	var plaza: Dictionary = world.ruins.get("plaza", {})
	if not plaza.is_empty():
		_plant_area = Rect2i(int(plaza["x"]), int(plaza["z"]), int(plaza["w"]), int(plaza["h"])).grow(int(DataDB.balance("earth_plant_story_margin")))
	_seed_jar_known = GameState.flags.get("seed_jar_found", false)
	_show_tutorial("enter")
	# 第 3 周第一次进小镇有剧情（界面线程的剧情表 earth_enter）；播完再轮到她的方案和事件
	if await _play_story("earth_enter"):
		return
	_start_girl_moments()


## 在小镇画面上直接播剧情；没有要播的返回 false。播的时候暂停 ARK-01 的操作。
func _play_story(moment: String) -> bool:
	var holder: Node = StoryScreen.play_over(self, moment)
	if holder == null:
		return false
	_story_playing = true
	ark.set_active(false)
	await Signal(holder, "all_finished")  # 剧情画面用 add_user_signal 加的信号
	_story_playing = false
	if is_inside_tree():
		ark.set_active(third_person)
		_start_girl_moments()
	return true


func _show_tutorial(trigger: String) -> void:
	var lines := EarthTutorial.lines_for(trigger, {"units": world.work_units_left()})
	if lines.is_empty():
		return
	_tutorial_lines.text = "\n".join(lines)
	_tutorial.visible = true


## 进小镇时：本周目标、她的方案、突发事件（都是她"活着"的地方，比赛版 4.4）
func _start_girl_moments() -> void:
	if not GameState.weekly.has("goal"):
		GameState.weekly["goal"] = GirlEarth.pick_week_goal(world)
	var goal: Dictionary = GameState.weekly["goal"]
	_goal_label.text = "" if goal.is_empty() else Text.f("UI-20-09", {"goal": Text.t(str(goal["say_key"]))})
	proposal = GirlEarth.maybe_propose(world, _rng)
	if not proposal.is_empty():
		_show_card(Text.t(str(proposal["say_key"])), [
			[Text.t("UI-20-06"), GirlEarth.ACCEPT], [Text.t("UI-20-07"), GirlEarth.EXPLAIN], [Text.t("UI-20-08"), GirlEarth.REJECT],
		], answer_proposal)
		return
	event = GirlEarth.pick_event(world, _rng)
	if not event.is_empty():
		GirlEarth.start_event(world, event)
		# 人物 AI 线程改：突发事件是 2～4 轮聊天，她先开口，最后一轮的 intent 决定结果（比赛版 4.3）
		_event_chat = ChatEventPanel.new(event)
		_event_chat.finished.connect(answer_event)
		add_child(_event_chat)


func answer_proposal(choice: String) -> void:
	GirlEarth.answer(world, proposal, choice)
	proposal = {}
	_close_card()


func answer_event(intent: String) -> void:
	var result := GirlEarth.resolve_event(world, event, intent)
	event = {}
	if is_instance_valid(_event_chat):  # 人物 AI 线程加：结果定了就关掉事件对话
		_event_chat.close()
	_close_card()
	if not result.is_empty():
		_show_message(Text.t(result))


## 她的实时评论：有冷却，冷却中的就不说了（人物 AI 线程接好后换成模型生成）
func girl_says(text: String) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now < _comment_ready_at:
		return
	_comment_ready_at = now + float(DataDB.balance("girl_comment_cooldown_sec"))
	_girl_line.text = text
	_girl_says_in_own_words(text)


## 人物 AI 线程加：先显示固定句，模型用她自己的话改写好了再换上（失败就留着固定句）
func _girl_says_in_own_words(fixed: String) -> void:
	var line := await ChatLines.earth_comment(fixed)
	if is_inside_tree() and _girl_line.text == fixed and not line["fallback"]:
		_girl_line.text = Text.f("UI-09-06", {"girl": GameState.girl_name, "text": line["reply"]})


func _show_card(text: String, options: Array, on_choice: Callable) -> void:
	_close_card()
	_card = PanelContainer.new()
	_card.set_anchors_preset(Control.PRESET_CENTER)
	_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_card.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_card)
	var box := VBoxContainer.new()
	_card.add_child(box)
	UiKit.short_label(box, text)
	for option: Array in options:
		UiKit.button(box, str(option[0]), on_choice.bind(option[1]))


func _close_card() -> void:
	if _card != null:
		_card.queue_free()
		_card = null


func _exit_tree() -> void:
	if world != null and world.changed.is_connected(_on_world_changed):
		world.changed.disconnect(_on_world_changed)
	if view != null and world != null and world.changed.is_connected(view.refresh):
		world.changed.disconnect(view.refresh)


func _process(delta: float) -> void:
	if _message_left > 0.0:
		_message_left -= delta
		if _message_left <= 0.0:
			_message.text = ""
	if not third_person:
		_update_ghost()
	else:
		_check_region_comment()
		_check_plant_story()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_V:
				toggle_view()
				return
			KEY_ESCAPE:
				cancel_placing()
				return
			KEY_F9:
				if OS.is_debug_build():
					debug_boost()
				return
	if third_person:
		return
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event
		if button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed:
				_on_left_click(button.position)
			else:
				_dragging_place = false
		elif button.button_index == MOUSE_BUTTON_RIGHT and not button.pressed and not top_camera.dragged:
			cancel_placing()
	elif event is InputEventMouseMotion and _dragging_place:
		var cell := _cell_under(event.position)
		if cell != _last_drag_cell:
			_last_drag_cell = cell
			world.place(placing_type, cell.x, cell.y)


# ---------- 玩家操作（测试也直接调这些）----------

func toggle_view() -> void:
	_set_third_person(not third_person)


func start_placing(type: String) -> void:
	# 固定位置的建筑（修旧车间）只有一个地方能建，不用玩家再找地方，点一下就下单
	var row := DataDB.row("buildings", type)
	if row["placement"] == "fixed":
		var reason := world.can_place(type, int(row["fixed_x"]), int(row["fixed_z"]))
		if reason.is_empty():
			world.place(type, int(row["fixed_x"]), int(row["fixed_z"]))
		else:
			_show_message(Text.f(reason["key"], reason["values"]))
		return
	placing_type = type
	selected_ruin = ""
	selected_building = 0
	view.show_selection(Rect2i())
	_refresh_info()
	_hint.text = Text.t("UI-17-08")


func cancel_placing() -> void:
	placing_type = ""
	_ghost.visible = false
	_reason.text = ""
	_hint.text = Text.t("UI-17-11")


func select_cell(cell: Vector2i) -> void:
	selected_ruin = world.ruin_at(cell)
	selected_building = world.building_at(cell)
	selected_prop = "" if not selected_ruin.is_empty() or selected_building != 0 else world.prop_at(cell)
	_refresh_selection()


## 放蓝图；成功返回建筑编号
func place_at(cell: Vector2i) -> int:
	var uid := world.place(placing_type, cell.x, cell.y)
	if uid != 0 and GirlEarth.objects_to_plan(_rng):
		girl_says(Text.t("UI-20-16"))
	if uid != 0 and not CONTINUOUS_TYPES.has(placing_type):
		cancel_placing()
	return uid


## 测试版专用：技能和材料加满，方便试玩后面的建筑（比赛版门槛要到第 3 周才够）
func debug_boost() -> void:
	var skills := int(DataDB.balance("debug_skill_boost"))
	for id in ["mechanics", "ecology", "comms"]:
		GameState.change_stat(id, skills)
	GameState.flags["seeds_from_plant"] = true  # 测试时直接打开种植区
	world.metal += int(DataDB.balance("debug_material_boost"))
	world.electronics += int(DataDB.balance("debug_material_boost"))
	world.changed.emit()
	_show_message(Text.t("UI-18-07"))


func _on_left_click(screen_position: Vector2) -> void:
	var cell := _cell_under(screen_position)
	if placing_type.is_empty():
		select_cell(cell)
		return
	var continuous := CONTINUOUS_TYPES.has(placing_type)
	place_at(cell)
	if continuous:
		_dragging_place = true
		_last_drag_cell = cell


func _set_third_person(value: bool) -> void:
	third_person = value
	cancel_placing()
	top_camera.active = not value
	top_camera.current = not value
	ark.set_active(value)
	view.set_game_filter(value)
	_left_panel.visible = not value
	_right_panel.visible = not value and _info_box.get_child_count() > 0
	_hint.text = Text.t("UI-17-10") if value else Text.t("UI-17-11")
	_on_world_changed()
	if value:
		_show_tutorial("third_person")


func _cell_under(screen_position: Vector2) -> Vector2i:
	var point := top_camera.ground_point(screen_position)
	return Vector2i(-1, -1) if point == Vector3.INF else view.cell_at(point)


func _update_ghost() -> void:
	if placing_type.is_empty():
		return
	var cell := _cell_under(get_viewport().get_mouse_position())
	var row := DataDB.row("buildings", placing_type)
	var w := int(row["size_x"])
	var h := int(row["size_z"])
	_ghost.visible = true
	_ghost.position = view.rect_center(cell.x, cell.y, w, h) + Vector3.UP * GHOST_HEIGHT / 2.0
	_ghost.scale = Vector3(w * view.cell_size, GHOST_HEIGHT, h * view.cell_size)
	var reason := world.can_place(placing_type, cell.x, cell.y)
	_ghost_material.albedo_color = GHOST_OK if reason.is_empty() else GHOST_BAD
	_reason.text = "" if reason.is_empty() else Text.f(reason["key"], reason["values"])


# ---------- 机器人 ----------

## 有活就派，每个任务至少一台；多余的机器人回家
func _assign_robots() -> void:
	while _robots.size() < world.robot_count():
		var robot := RobotAgent.new()
		add_child(robot)
		robot.setup(view, ROBOT_HOME + Vector2i(_robots.size() * ROBOT_SPACING, 0))
		_robots.append(robot)
	var plan := world.allocation()
	var jobs: Array[Dictionary] = []
	for i in world.queue.size():
		if plan[i] > 0:
			jobs.append(world.queue[i])
	for i in _robots.size():
		var robot := _robots[i]
		if jobs.is_empty():
			if not robot.target_job.is_empty() or robot.state == RobotAgent.State.IDLE and view.cell_at(robot.position) != ROBOT_HOME + Vector2i(i, 0):
				robot.send_home(ROBOT_HOME + Vector2i(i, 0))
			continue
		var job: Dictionary = jobs[i % jobs.size()]
		if robot.target_job != job:
			robot.assign(job, _job_rect(job))


func _job_rect(job: Dictionary) -> Rect2i:
	var source: Dictionary = world.ruins[job["ref"]] if job["kind"] == EarthWorld.JOB_CLEAR else world.buildings[job["ref"]]
	return Rect2i(int(source["x"]), int(source["z"]), int(source["w"]), int(source["h"]))


# ---------- 搭建 ----------

func _build_world() -> void:
	view = EarthView.new()
	add_child(view)
	view.setup(world)
	top_camera = TopCamera.new()
	top_camera.limit = view.map_size()
	top_camera.focus = view.cell_center(ARK_START)
	view.add_child(top_camera)
	ark = ArkController.new()
	view.add_child(ark)
	var start := world.ark_position
	ark.setup(view, view.cell_center(ARK_START) if start == Vector3.INF else start)
	ark.message.connect(_show_message)
	ark.girl_comment.connect(girl_says)
	ark.scrap_cut.connect(_on_scrap_cut)
	ark.prompt_changed.connect(func(text: String) -> void: _prompt.text = text)

	_ghost = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	_ghost_material = StandardMaterial3D.new()
	_ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_material.albedo_color = GHOST_OK
	mesh.material = _ghost_material
	_ghost.mesh = mesh
	_ghost.visible = false
	view.add_child(_ghost)


func _build_hud() -> void:
	var top := PanelContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	add_child(top)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", UiKit.GAP)
	top.add_child(bar)
	UiKit.button(bar, Text.t("UI-17-04"), func() -> void: back_pressed.emit())
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(texts)
	_status = UiKit.short_label(texts, "")
	_recovery_label = UiKit.short_label(texts, "")
	_confirm = EndWeekDialog.new()
	_confirm.confirmed.connect(func() -> void: end_week_confirmed.emit())
	add_child(_confirm)
	UiKit.button(bar, Text.t("UI-01-04"), func() -> void: _confirm.ask())

	_left_panel = _side_panel(Control.PRESET_LEFT_WIDE)
	var left := VBoxContainer.new()
	_left_panel.add_child(left)
	UiKit.short_label(left, Text.t("UI-17-01"))
	for type in MENU_ORDER:
		var button := UiKit.button(left, "", start_placing.bind(type))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.clip_text = true
		_menu_buttons[type] = button
	UiKit.short_label(left, Text.t("UI-17-02"))
	_queue_box = VBoxContainer.new()
	left.add_child(_queue_box)

	_right_panel = _side_panel(Control.PRESET_RIGHT_WIDE)
	_info_box = VBoxContainer.new()
	_right_panel.add_child(_info_box)

	var bottom := VBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.alignment = BoxContainer.ALIGNMENT_END
	add_child(bottom)
	_girl_line = _bottom_label(bottom)
	_tutorial = PanelContainer.new()
	_tutorial.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_tutorial.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_tutorial.offset_top = 80.0
	_tutorial.visible = false
	add_child(_tutorial)
	var tutorial_box := VBoxContainer.new()
	_tutorial.add_child(tutorial_box)
	_tutorial_lines = UiKit.short_label(tutorial_box, "")
	UiKit.button(tutorial_box, Text.t("UI-17-15"), func() -> void: _tutorial.visible = false)
	_goal_label = _bottom_label(bottom)
	_message = _bottom_label(bottom)
	_prompt = _bottom_label(bottom)
	_reason = _bottom_label(bottom)
	_hint = _bottom_label(bottom)


func _side_panel(preset: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(preset)
	panel.custom_minimum_size.x = PANEL_WIDTH
	panel.offset_top = 72.0
	if preset == Control.PRESET_RIGHT_WIDE:
		panel.offset_left = -PANEL_WIDTH
		panel.anchor_bottom = 0.0
		panel.grow_vertical = Control.GROW_DIRECTION_END
	else:
		panel.anchor_bottom = 0.0
		panel.grow_vertical = Control.GROW_DIRECTION_END
	add_child(panel)
	return panel


func _bottom_label(parent: Control) -> Label:
	var label := UiKit.short_label(parent, "")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 第三人称画面很亮，文字要描边才看得清
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	return label


# ---------- 刷新显示 ----------

## 第三人称下 ARK-01 走近广场边缘：第 3 周的植物事件（剧情表 earth_plant_found）
func _check_plant_story() -> void:
	if _story_playing or _plant_area.size == Vector2i.ZERO or GameState.flags.get("plant_event_done", false):
		return
	if _plant_area.has_point(view.cell_at(ark.position)):
		_play_story("earth_plant_found")


func _check_region_comment() -> void:
	var region := world.region_of(view.cell_at(ark.position))
	if region != _last_region:
		if not _last_region.is_empty() and not region.is_empty():
			girl_says(Text.f("UI-20-20", {"name": Text.t(str(DataDB.row("earth_regions", region)["name_key"]))}))
		_last_region = region


func _on_scrap_cut() -> void:
	_scraps_cut += 1
	if _scraps_cut >= int(DataDB.balance("earth_tutorial_scraps")):
		_show_tutorial("scraps_3")


func _on_world_changed() -> void:
	# 扫到种子罐：播剧情（剧情表 earth_seed_jar_found）
	if not _seed_jar_known and GameState.flags.get("seed_jar_found", false):
		_seed_jar_known = true
		if is_node_ready():
			_play_story.call_deferred("earth_seed_jar_found")

	_status.text = "%s    %s    %s" % [
		Text.f("UI-17-13", {"week": GameState.week}),
		Text.f("UI-14-05", {
			"metal_name": Text.t("UI-14-01"), "metal": world.metal,
			"electronics_name": Text.t("UI-14-02"), "electronics": world.electronics,
			"energy_name": Text.t("UI-14-03"), "energy_used": world.energy_used(), "energy": world.energy_output(),
			"water_name": Text.t("UI-14-04"), "water_used": world.water_used(), "water": world.water_output(),
		}),
		Text.f("UI-14-06", {"left": world.work_units_left(), "total": world.work_units_total()}),
	]
	_recovery_label.text = PageText.recovery_text(world.recovery()) + "    " + (Text.t("UI-17-06") if third_person else Text.t("UI-17-05"))
	_refresh_menu()
	_refresh_queue()
	_refresh_selection()
	_assign_robots()


func _refresh_menu() -> void:
	for type: String in _menu_buttons:
		var row := DataDB.row("buildings", type)
		var button: Button = _menu_buttons[type]
		button.text = Text.f("UI-17-07", {
			"name": Text.t(row["name_key"]), "metal": row["metal"], "electronics": row["electronics"], "work": row["work_units"],
		})
		var locked := world.unlock_reason(type)
		button.disabled = not locked.is_empty()
		button.tooltip_text = "" if locked.is_empty() else Text.f(locked["key"], locked["values"])


func _refresh_queue() -> void:
	for child in _queue_box.get_children():
		_queue_box.remove_child(child)
		child.queue_free()
	if world.queue.is_empty():
		UiKit.short_label(_queue_box, Text.t("UI-17-03"))
	for job in world.queue:
		UiKit.short_label(_queue_box, _job_text(job))


func _job_text(job: Dictionary) -> String:
	if job["kind"] == EarthWorld.JOB_CLEAR:
		return Text.f("UI-17-12", {"name": Text.t("UI-19-01"), "done": job["done"], "total": job["total"]})
	var type: String = world.buildings[job["ref"]]["type"]
	return Text.f("UI-17-09", {"name": Text.t(DataDB.row("buildings", type)["name_key"]), "done": job["done"], "total": job["total"]})


func _refresh_selection() -> void:
	if not selected_ruin.is_empty() and world.ruins[selected_ruin]["cleared"]:
		selected_ruin = ""
	if selected_building != 0 and not world.buildings.has(selected_building):
		selected_building = 0
	var rect := Rect2i()
	if not selected_ruin.is_empty():
		var ruin: Dictionary = world.ruins[selected_ruin]
		rect = Rect2i(int(ruin["x"]), int(ruin["z"]), int(ruin["w"]), int(ruin["h"]))
	elif selected_building != 0:
		var building: Dictionary = world.buildings[selected_building]
		rect = Rect2i(int(building["x"]), int(building["z"]), int(building["w"]), int(building["h"]))
	view.show_selection(rect)
	_refresh_info()


func _refresh_info() -> void:
	for child in _info_box.get_children():
		_info_box.remove_child(child)
		child.queue_free()
	if not selected_ruin.is_empty():
		_ruin_info(world.ruins[selected_ruin])
	elif selected_building != 0:
		_building_info(world.buildings[selected_building])
	elif not selected_prop.is_empty():
		_prop_info(selected_prop)
	_right_panel.visible = not third_person and _info_box.get_child_count() > 0


func _ruin_info(ruin: Dictionary) -> void:
	if ruin["kind"] != EarthWorld.RUIN_BIG:
		UiKit.label(_info_box, Text.t("UI-19-02"))
		UiKit.label(_info_box, Text.t("UI-16-11"))
		return
	var id: String = ruin["id"]
	UiKit.label(_info_box, Text.t("UI-19-01"))
	UiKit.label(_info_box, Text.f("UI-16-10", {"metal": ruin["metal"], "electronics": ruin["electronics"]}))
	if world.is_ruin_queued(id):
		UiKit.button(_info_box, Text.t("UI-16-09"), world.cancel_clear.bind(id))
	else:
		UiKit.button(_info_box, Text.f("UI-16-08", {"work": ruin["work_units"]}), request_clear.bind(id))


func _building_info(building: Dictionary) -> void:
	var uid: int = building["uid"]
	UiKit.label(_info_box, Text.t(DataDB.row("buildings", building["type"])["name_key"]))
	if not building["done"]:
		var job := _building_job(uid)
		UiKit.label(_info_box, Text.f("UI-16-05", {"done": job.get("done", 0), "total": job.get("total", 0)}))
		UiKit.button(_info_box, Text.t("UI-16-06"), world.cancel_blueprint.bind(uid))
		return
	var problems := world.problems(uid)
	if problems.is_empty():
		UiKit.label(_info_box, Text.t("UI-16-04"))
	var keys := {EarthWorld.POWER_PROBLEM: "UI-16-01", EarthWorld.WATER_PROBLEM: "UI-16-02", EarthWorld.SOIL_PROBLEM: "UI-16-03", EarthWorld.BROKEN_PROBLEM: "UI-16-13"}
	for problem in problems:
		UiKit.label(_info_box, Text.t(keys[problem]))
	var demolish := UiKit.button(_info_box, Text.t("UI-16-07"), world.demolish.bind(uid))
	demolish.tooltip_text = Text.t("UI-17-14")


## 剧情物件：名字，以及需要她去现场做的特殊施工
func _prop_info(id: String) -> void:
	UiKit.label(_info_box, Text.t(str(DataDB.row("earth_props", id)["name_key"])))
	for special: String in DataDB.table("earth_specials"):
		var row := DataDB.row("earth_specials", special)
		if str(row["prop"]) != id or world.is_special_done(special):
			continue
		UiKit.label(_info_box, Text.f("UI-18-32", {"name": Text.t(row["name_key"])}))
		var reason := world.special_reason(special)
		if not reason.is_empty():
			UiKit.label(_info_box, Text.f(reason["key"], reason["values"]))


## 排清理：共情高、废墟旁有植物时她会阻止，要再点一次才算数（比赛版 4.4）
func request_clear(ruin_id: String) -> void:
	if _confirm_clear != ruin_id and GirlEarth.objects_to_clear(world, ruin_id):
		_confirm_clear = ruin_id
		girl_says(Text.t("UI-20-15"))
		_show_message(Text.t("UI-20-15"))
		return
	_confirm_clear = ""
	world.queue_clear(ruin_id)
	_show_tutorial("clear_queued")


func _building_job(uid: int) -> Dictionary:
	for job in world.queue:
		if job["kind"] == EarthWorld.JOB_BUILD and job["ref"] == uid:
			return job
	return {}


func _show_message(text: String) -> void:
	_message.text = text
	_message_left = MESSAGE_SEC
