class_name CourseSystem
extends RefCounted
## 课程结算（比赛版 4.2）。只算数值，不碰界面。
## 在传入的属性表上直接计算，所以既能结算真实一周，也能在副本上预演课表。

const REST := "rest"
const STATUS_NORMAL := "normal"
const STATUS_SICK := "sick"
const STATUS_REFUSED := "refused"
const STATUS_TIRED := "tired"
const SKILL_TYPE := "skill"
const RECOVERY_STATS: Array[String] = ["stamina", "mood"]  # 这两项不算"收益"，累的时候不减半
const CONFIDENCE := "confidence"


## 跑完一周，返回每天的结果：
## { day, planned, course, status, changes: {属性: 实际变化}, event, collapsed }
## random_on = false 用于预演：不抽拒绝上课和小事件，结果可预测。
static func run_week(plan: Array[String], stats: Dictionary, rng: RandomNumberGenerator, random_on := true) -> Array[Dictionary]:
	var low_stamina := int(DataDB.balance("low_stamina"))
	var low_mood := int(DataDB.balance("low_mood"))
	var refuse_chance := float(DataDB.balance("low_mood_refuse_chance"))
	var event_chance := float(DataDB.balance("course_event_chance"))
	var streak_days := int(DataDB.balance("same_skill_streak_days"))
	var streak_course := ""
	var streak := 0
	var results: Array[Dictionary] = []

	for day in plan.size():
		var course := plan[day]
		var status := STATUS_NORMAL
		if int(stats["stamina"]) <= 0:
			course = REST
			status = STATUS_SICK
		elif random_on and int(stats["mood"]) < low_mood and rng.randf() < refuse_chance:
			course = REST
			status = STATUS_REFUSED

		var row := DataDB.row("courses", course)
		var is_class := course != REST
		var tired := is_class and int(stats["stamina"]) < low_stamina
		if tired:
			status = STATUS_TIRED

		var deltas := _course_deltas(row, tired)
		if tired:
			deltas[CONFIDENCE] = int(deltas.get(CONFIDENCE, 0)) - 1

		# 连续同一技能课：累的那天不算，并且中断连续
		if row.get("type") == SKILL_TYPE and not tired:
			streak = streak + 1 if course == streak_course else 1
			streak_course = course
			if streak >= streak_days:
				deltas[CONFIDENCE] = int(deltas.get(CONFIDENCE, 0)) + 1
				streak = 0
		else:
			streak = 0
			streak_course = ""

		results.append({
			"text_key": result_text_key(course, status, stats, GameState.age, day),
			"day": day,
			"planned": plan[day],
			"course": course,
			"status": status,
			"changes": _apply(deltas, stats),
			"event": random_on and rng.randf() < event_chance,
			"collapsed": int(stats["stamina"]) <= 0,
		})
	return results


## 当天结算前确定文案档位；轮换同档句子，不消耗玩法随机数。
static func result_text_key(course: String, status: String, stats: Dictionary, age: int, day: int) -> String:
	var text_age := int(DataDB.balance("teen_age")) if age >= int(DataDB.balance("teen_age")) else int(DataDB.balance("child_age"))
	var variant := posmod(day + GameState.week, 2) + 1
	var special := {STATUS_SICK: "sick", STATUS_REFUSED: "refuse", STATUS_TIRED: "tired"}
	if special.has(status):
		return "CR-%s-%d-%d" % [special[status], text_age, variant]
	var row := DataDB.row("courses", course)
	var value := int(stats.get(str(row.get("result_stat", "")), 0))
	var tier := "中"
	if value <= int(DataDB.balance("trait_low")):
		tier = "低"
	elif value >= int(DataDB.balance("trait_high")):
		tier = "高"
	return "CR-%s-%d-%s-%d" % [course, text_age, tier, variant]


## 第几天会累倒（体力降到 0）；不会累倒返回 -1。用于课表提示。
static func first_collapse_day(plan: Array[String], stats: Dictionary) -> int:
	var copy := stats.duplicate()
	for result in run_week(plan, copy, RandomNumberGenerator.new(), false):
		if result["collapsed"]:
			return result["day"]
	return -1


## 从课程表这一行读出各属性的变化。累的时候正收益减半，向下取整，所以 +1 会变成 0。
static func _course_deltas(row: Dictionary, tired: bool) -> Dictionary:
	var deltas := {}
	for id: String in DataDB.table("girl_stats"):
		var delta := int(row.get(id, 0))
		if delta == 0:
			continue
		if tired and delta > 0 and not RECOVERY_STATS.has(id):
			delta = delta / 2
		deltas[id] = delta
	return deltas


## 应用变化并返回实际变化量。先算体力上限，这样当天加的上限能容纳当天的体力。
static func _apply(deltas: Dictionary, stats: Dictionary) -> Dictionary:
	var ordered: Array = deltas.keys()
	ordered.sort_custom(func(a: String, b: String) -> bool: return a == "stamina_max" and b != "stamina_max")
	var real := {}
	for id: String in ordered:
		var old_value := int(stats[id])
		stats[id] = GameState.clamp_value(id, old_value + int(deltas[id]), stats)
		if stats[id] != old_value:
			real[id] = int(stats[id]) - old_value
	return real
