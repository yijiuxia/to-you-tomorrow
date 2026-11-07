extends Node
## 数值规则的自动测试。运行方法：
## Godot_console.exe --headless --path . res://scenes/tests/unit_tests.tscn
## 全部通过时退出码是 0。

var _failures := 0
var _count := 0


func _ready() -> void:
	test_course_effects()
	test_tired_halves_gains()
	test_collapse_means_sick_next_day()
	test_low_mood_refuses_class()
	test_skill_streak_gives_confidence()
	test_stamina_max_grows_with_fitness()
	test_recommended_week_is_sustainable()
	test_collapse_forecast()
	test_chat_rounds_formula()
	test_attitude_changes_and_cap()
	test_keyword_bonus_needs_support()
	test_rounds_fixed_after_first_ask()
	test_end_week_recovers_stamina()
	test_next_stage()
	test_time_jump()
	test_text_fills_names()
	test_reply_options_are_cleaned()
	print("测试 %d 项，失败 %d 项" % [_count, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func test_course_effects() -> void:
	var s := _stats()
	CourseSystem.run_week(_plan(["mechanics"]), s, _rng(), false)
	_eq(s["mechanics"], 3, "机械课 +3")
	_eq(s["stamina"], 55, "机械课体力 -15")


func test_tired_halves_gains() -> void:
	var s := _stats()
	s["stamina"] = 25
	var r := CourseSystem.run_week(_plan(["mechanics"]), s, _rng(), false)
	_eq(s["mechanics"], 1, "累的时候 +3 减半取整为 +1")
	_eq(s["confidence"], 39, "累的时候硬上课自信 -1")
	_eq(s["stamina"], 10, "体力消耗不减半")
	_eq(r[0]["status"], CourseSystem.STATUS_TIRED, "状态是累")

	s = _stats()
	s["stamina"] = 20
	CourseSystem.run_week(_plan(["together"]), s, _rng(), false)
	_eq(s["mood"], 80, "恢复类的心情 +10 不减半")
	_eq(s["trust"], 51, "信任 +2 减半")

	s = _stats()
	s["stamina"] = 20
	CourseSystem.run_week(_plan(["rest"]), s, _rng(), false)
	_eq(s["confidence"], 40, "休息不算硬上课")
	_eq(s["stamina"], 50, "休息体力 +30")


func test_collapse_means_sick_next_day() -> void:
	var s := _stats()
	s["stamina"] = 10
	var r := CourseSystem.run_week(_plan(["fitness", "mechanics"]), s, _rng(), false)
	_eq(r[0]["collapsed"], true, "体力降到 0 算累倒")
	_eq(r[1]["status"], CourseSystem.STATUS_SICK, "第二天生病")
	_eq(r[1]["course"], CourseSystem.REST, "生病强制休息")
	_eq(s["mechanics"], 0, "生病那天没上机械课")
	_eq(s["stamina"], 30, "生病那天按休息恢复")


func test_low_mood_refuses_class() -> void:
	var refused := 0
	var rng := _rng()
	for _i in 2000:
		var s := _stats()
		s["mood"] = 20
		var r := CourseSystem.run_week(_plan(["mechanics"]), s, rng, true)
		if r[0]["status"] == CourseSystem.STATUS_REFUSED:
			refused += 1
	_true(refused > 900 and refused < 1100, "心情低时约一半概率拒绝（实际 %d/2000）" % refused)

	var calm := _stats()
	calm["mood"] = 30
	var r2 := CourseSystem.run_week(_plan(["mechanics", "mechanics", "mechanics"]), calm, rng, true)
	for result in r2:
		_true(result["status"] != CourseSystem.STATUS_REFUSED, "心情正好 30 不会拒绝")


func test_skill_streak_gives_confidence() -> void:
	var s := _stats()
	CourseSystem.run_week(_plan(["mechanics", "mechanics", "mechanics"]), s, _rng(), false)
	_eq(s["confidence"], 41, "连续 3 天同一技能课自信 +1")

	s = _stats()
	CourseSystem.run_week(_plan(["mechanics", "ecology", "mechanics"]), s, _rng(), false)
	_eq(s["confidence"], 40, "中间换课不算连续")

	s = _stats()
	s["stamina"] = 50  # 50 → 35 → 20，第 3 天体力不够 30
	CourseSystem.run_week(_plan(["mechanics", "mechanics", "mechanics"]), s, _rng(), false)
	_eq(s["confidence"], 39, "第 3 天累：不加连续奖励，还要扣 1")


func test_stamina_max_grows_with_fitness() -> void:
	var s := _stats()
	s["stamina"] = 100
	CourseSystem.run_week(_plan(["fitness"]), s, _rng(), false)
	_eq(s["stamina_max"], 105, "体能训练上限 +5")
	_eq(s["stamina"], 80, "体能训练体力 -20")

	s = _stats()
	s["stamina"] = 90
	CourseSystem.run_week(_plan(["rest"]), s, _rng(), false)
	_eq(s["stamina"], 100, "体力不超过上限")


## 课程数值核算：5 节技能课 + 2 天休息，一周净变化 +5（含周末 +20）
func test_recommended_week_is_sustainable() -> void:
	var s := _stats()
	CourseSystem.run_week(_plan(["mechanics", "mechanics", "mechanics", "rest", "mechanics", "mechanics", "rest"]), s, _rng(), false)
	_eq(s["stamina"], 70 - 75 + 60, "推荐排法一周净变化 -15（周末再 +20）")
	_eq(s["mechanics"], 15, "推荐排法一周技能 +15")


func test_collapse_forecast() -> void:
	var s := _stats()
	var plan := _plan(["mechanics", "mechanics", "mechanics", "mechanics", "mechanics", "mechanics", "mechanics"])
	_eq(CourseSystem.first_collapse_day(plan, s), 4, "连上技能课第 5 天累倒")
	_eq(s["stamina"], 70, "预演不改真实属性")
	_eq(CourseSystem.first_collapse_day(_plan(["rest", "rest"]), s), -1, "休息不会累倒")


func test_chat_rounds_formula() -> void:
	var s := _stats()  # 信任 50，心情 70，体力 70
	_eq(ChatRules.rounds_for(s), 3 + 2 + 1, "默认 6 轮")
	s["mood"] = 59
	_eq(ChatRules.rounds_for(s), 5, "心情低于 60 不加成")
	s["stamina"] = 29
	_eq(ChatRules.rounds_for(s), 4, "体力低减一轮")
	s["trust"] = 100
	s["mood"] = 100
	s["stamina"] = 100
	_eq(ChatRules.rounds_for(s), 8, "最多 8 轮")
	s["trust"] = 0
	s["mood"] = 0
	s["stamina"] = 0
	_eq(ChatRules.rounds_for(s), 2, "最少 2 轮")


func test_attitude_changes_and_cap() -> void:
	var used := {}
	var c := ChatRules.round_changes("encourage", "", used)
	_eq(c.get("confidence"), 3, "鼓励自信 +3")
	_eq(c.get("trust"), 2, "鼓励信任 +2")
	c = ChatRules.round_changes("encourage", "", used)
	_eq(c.get("confidence"), 2, "自信封顶 5，第二次只加 2")
	c = ChatRules.round_changes("encourage", "", used)
	_eq(c.has("confidence"), false, "封顶后不再加自信")
	_eq(c.get("trust"), 1, "信任 2+2+1 到封顶")

	used = {}
	for _i in 4:
		ChatRules.round_changes("ignore", "", used)
	_eq(used.get("trust"), -5, "负向也封顶 -5")
	_eq(used.get("mood"), -5, "心情也封顶")
	_true(ChatRules.round_changes("neutral", "", {}).is_empty(), "中性无变化")


func test_keyword_bonus_needs_support() -> void:
	var c := ChatRules.round_changes("encourage", "你想看看地球吗", {})
	_eq(c.get("curiosity"), 1, "支持时聊地球好奇 +1")
	c = ChatRules.round_changes("restrict", "别想地球了", {})
	_eq(c.has("curiosity"), false, "限制时不加好奇")
	c = ChatRules.round_changes("comfort", "你照顾的植物真好", {})
	_eq(c.get("empathy"), 1, "支持时聊植物共情 +1")


func test_rounds_fixed_after_first_ask() -> void:
	GameState.reset()
	var first := WeekSystem.chat_rounds_left()
	_eq(first, 6, "开局 6 轮")
	GameState.change_stat("trust", 50)
	_eq(WeekSystem.chat_rounds_left(), first, "本周内属性变化不改已定轮数")
	WeekSystem.start_next_week()
	_true(WeekSystem.chat_rounds_left() > first, "下一周重新计算")
	GameState.reset()


func test_end_week_recovers_stamina() -> void:
	GameState.reset()
	GameState.change_stat("stamina", -50)
	_eq(WeekSystem.end_week(), 20, "每周恢复 20")
	GameState.change_stat("stamina", 100)
	_eq(WeekSystem.end_week(), 0, "不超过上限")
	GameState.reset()


func test_next_stage() -> void:
	GameState.reset()
	var stages: Array[String] = []
	for _i in 6:
		stages.append(WeekSystem.next_stage())
		WeekSystem.start_next_week()
	_eq(stages, ["morning", "jump", "morning", "morning", "morning", "ending"], "6 周流程顺序")
	GameState.reset()


## 用课程数值核算里的"均衡玩家"验算：前两周 12/9/9 → 46/37/37
func test_time_jump() -> void:
	GameState.reset()
	GameState.change_stat("mechanics", 12)
	GameState.change_stat("ecology", 9)
	GameState.change_stat("comms", 9)
	GameState.change_stat("confidence", 10)
	GameState.change_stat("trust", -5)
	GameState.change_stat("stamina", -40)
	GameState.change_stat("mood", -40)
	var before := WeekSystem.apply_time_jump()
	_eq(GameState.get_stat("mechanics"), 46, "机械 12 → 46")
	_eq(GameState.get_stat("ecology"), 37, "生态 9 → 37")
	_eq(GameState.get_stat("confidence"), 70, "自信 50 + 10×2")
	_eq(GameState.get_stat("trust"), 35, "信任 45 + (-5)×2")
	_eq(GameState.get_stat("stamina_max"), 110, "体力上限 +10")
	_eq(GameState.get_stat("stamina"), 70, "体力重置")
	_eq(GameState.get_stat("mood"), 70, "心情重置")
	_eq(GameState.age, 15, "变成 15 岁")
	_eq(before["mechanics"], 12, "返回跳跃前的值")

	GameState.reset()
	GameState.change_stat("mechanics", 30)
	WeekSystem.apply_time_jump()
	_eq(GameState.get_stat("mechanics"), 70, "只练机械封顶 70")
	GameState.reset()


func test_text_fills_names() -> void:
	GameState.girl_name = "小雨"
	_true(Text.t("CR-RES-01").contains("小雨"), "固定文字用她的名字")
	_true(not Text.t("CR-RES-01").contains("{girl}"), "占位符被替换")
	GameState.girl_name = "朝禾"


func test_reply_options_are_cleaned() -> void:
	var raw := JSON.stringify({
		"player_attitude": "neutral", "intent": "none", "emotion": "calm", "reply": "好的。",
		"options": ["，今天没学什么", "好的。", "}]{json"],
	})
	var parsed := ModelService.parse_reply(raw)
	_eq(parsed["options"][0], "今天没学什么", "去掉开头的标点")
	_eq(parsed["options"][1], Text.t("FB-02-02"), "和她的话相同的选项换成后备")
	_eq(parsed["options"][2], Text.t("FB-02-03"), "乱码选项换成后备")
	_true(ModelService.parse_reply("不是 JSON").is_empty(), "不合格回复返回空")


func _stats() -> Dictionary:
	GameState.reset()
	return GameState.stats.duplicate()


func _plan(days: Array) -> Array[String]:
	var plan: Array[String] = []
	plan.assign(days)
	return plan


func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	return rng


func _eq(actual: Variant, expected: Variant, label: String) -> void:
	_count += 1
	if actual != expected:
		_failures += 1
		print("失败：%s（期望 %s，实际 %s）" % [label, str(expected), str(actual)])


func _true(condition: bool, label: String) -> void:
	_eq(condition, true, label)
