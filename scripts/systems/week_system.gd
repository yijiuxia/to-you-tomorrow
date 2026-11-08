class_name WeekSystem
extends RefCounted
## 一周的流程规则：结算课表、结束本周、时间跳跃（demo 文案"每周流程"、比赛版 4.1）。

const NEXT_MORNING := "morning"
const NEXT_JUMP := "jump"
const NEXT_ENDING := "ending"
const STAMINA_MAX := "stamina_max"
const JUMP_RESET_STATS: Array[String] = ["stamina", "mood"]


## 结算当前课表，把结果写进 GameState，返回每天的结果
static func settle_schedule(rng: RandomNumberGenerator) -> Array[Dictionary]:
	var working := GameState.stats.duplicate()
	var results := CourseSystem.run_week(GameState.schedule, working, rng)
	# 先改上限，否则体力会被旧上限截断
	GameState.change_stat(STAMINA_MAX, int(working[STAMINA_MAX]) - GameState.get_stat(STAMINA_MAX))
	for id: String in working:
		GameState.change_stat(id, int(working[id]) - GameState.get_stat(id))
	GameState.last_schedule = GameState.schedule.duplicate()
	return results


## 本周还能聊几轮。第一次问的时候才算，这样用到的是课程结算后的属性；算过就固定下来。
static func chat_rounds_left() -> int:
	if GameState.chat_rounds_left < 0:
		GameState.chat_rounds_left = ChatRules.rounds_for(GameState.stats)
	return GameState.chat_rounds_left


## 小镇这周开放了吗。第 1 周排完课一周就过去了，建造教学从第 2 周开始（yi 定）。
static func is_earth_open() -> bool:
	return GameState.week >= int(DataDB.balance("earth_open_week"))


## 点"结束本周"确认后：地球统一结算，体力每周固定恢复。
## 第 1 周还没上过课也没开小镇，两样都跳过：这样第一次上课时体力仍是初始值，课程数值核算不变。
static func end_week() -> int:
	GameState.last_earth_report = GameState.earth.end_week() if is_earth_open() else {}
	var traits: Dictionary = GameState.last_earth_report.get("traits", {})
	for id: String in traits:
		GameState.change_stat(id, int(traits[id]))
	if GameState.week < int(DataDB.balance("first_class_week")):
		return 0
	var before := GameState.get_stat("stamina")
	GameState.change_stat("stamina", int(DataDB.balance("stamina_weekly_recover")))
	return GameState.get_stat("stamina") - before


## 周结算之后去哪里
static func next_stage() -> String:
	if GameState.week >= int(DataDB.balance("last_week")):
		return NEXT_ENDING
	if GameState.week == int(DataDB.balance("timejump_after_week")):
		return NEXT_JUMP
	return NEXT_MORNING


## 进入下一周：清掉只属于本周的状态
static func start_next_week() -> void:
	GameState.week += 1
	GameState.chat_rounds_left = -1
	GameState.chat_week_changes.clear()


## 时间跳跃（比赛版 4.1）。返回跳跃前的属性，用于"这些年"总结页。
## 技能 = 原值 + 加成 + 前两周涨幅 × 倍数，最高封顶，但不会把已超过封顶的值拉低。
## 性格和信任 = 原值 + 前两周变化 × 倍数。
static func apply_time_jump() -> Dictionary:
	var before := GameState.stats.duplicate()
	var skill_bonus := int(DataDB.balance("timejump_skill_bonus"))
	var skill_cap := int(DataDB.balance("timejump_skill_cap"))
	var skill_mult := int(DataDB.balance("timejump_skill_growth_mult"))
	var trait_mult := int(DataDB.balance("timejump_trait_mult"))
	for id: String in DataDB.table("girl_stats"):
		var old_value := GameState.get_stat(id)
		var growth := old_value - int(GameState.initial_stats[id])
		match str(DataDB.row("girl_stats", id)["category"]):
			"skill":
				var target := maxi(old_value, mini(old_value + skill_bonus + growth * skill_mult, skill_cap))
				GameState.change_stat(id, target - old_value)
			"trait", "relation":
				GameState.change_stat(id, growth * trait_mult)
	GameState.change_stat(STAMINA_MAX, int(DataDB.balance("timejump_stamina_max_bonus")))
	var reset_value := int(DataDB.balance("timejump_reset_value"))
	for id in JUMP_RESET_STATS:
		GameState.change_stat(id, reset_value - GameState.get_stat(id))
	GameState.age = int(DataDB.balance("teen_age"))
	return before


## 结局看最高的性格（比赛版第 5 节）；同分时按表格顺序取靠前的
static func top_trait() -> String:
	var best := ""
	for id: String in DataDB.table("girl_stats"):
		if str(DataDB.row("girl_stats", id)["category"]) != "trait":
			continue
		if best.is_empty() or GameState.get_stat(id) > GameState.get_stat(best):
			best = id
	return best
