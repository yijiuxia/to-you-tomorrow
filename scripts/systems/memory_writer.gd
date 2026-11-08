class_name MemoryWriter
extends RefCounted
## 把真实发生的事写成她的记忆（比赛版 4.5）。记忆的内容来自程序，不让模型编：
## 模型只负责"她的感想"和"聊天摘要"（见 ChatLines），事实永远以这里为准。

const IMPORTANCE_LOW := 1
const IMPORTANCE_MID := 2
const SPEAKER_GIRL := "girl"
const SPEAKER_PLAYER := "player"

static var _patterns: Array[Dictionary] = []


## 周结算时调用：本周地球上完成的事、新发生的剧情，写成事件记忆。返回新记下的句子（反思时给模型看）
static func record_week(store: MemoryStore) -> PackedStringArray:
	var added := PackedStringArray()
	var report: Dictionary = GameState.last_earth_report
	var finished: Array = report.get("finished", [])
	if not finished.is_empty():
		var names := PackedStringArray()
		for name: String in finished:
			if not names.has(name):
				names.append(name)
		added.append(_add(store, Text.f("WK-08-01", {"week": GameState.week, "names": _join(names)}), IMPORTANCE_MID))
	for flag: String in DataDB.table("memory_flags"):
		if store.noted_flags.has(flag) or not ChatWorldbook.flag_on(flag):
			continue
		var row := DataDB.row("memory_flags", flag)
		store.noted_flags.append(flag)
		var text := Text.f("WK-08-05", {"week": GameState.week, "event": Text.t(str(row["text_key"]))})
		added.append(_add(store, text, int(row["importance"])))
	return added


## 早上课程结算后调用：上得最多的课、累倒、拒绝上课
static func record_courses(store: MemoryStore, results: Array[Dictionary]) -> PackedStringArray:
	var added := PackedStringArray()
	if results.is_empty():
		return added
	# 课在上周上的，记成上周的事
	var week := GameState.week - 1
	var counts := {}
	var sick := false
	var refused := false
	for result in results:
		match str(result["status"]):
			CourseSystem.STATUS_SICK:
				sick = true
			CourseSystem.STATUS_REFUSED:
				refused = true
		var course := str(result["course"])
		if course != CourseSystem.REST:
			counts[course] = int(counts.get(course, 0)) + 1
	if not counts.is_empty():
		var best := ""
		for course: String in counts:
			if best.is_empty() or int(counts[course]) > int(counts[best]):
				best = course
		var name := Text.t(str(DataDB.row("courses", best)["name_key"]))
		added.append(_add(store, Text.f("WK-08-02", {"week": week, "course": name}), IMPORTANCE_LOW, week))
	if sick:
		added.append(_add(store, Text.f("WK-08-03", {"week": week}), IMPORTANCE_MID, week))
	if refused:
		added.append(_add(store, Text.f("WK-08-04", {"week": week}), IMPORTANCE_LOW, week))
	return added


## 每轮聊天后调用：记下原话，并认出喜好和约定写进核心记忆
static func record_turn(store: MemoryStore, player_text: String, girl_reply: String) -> void:
	store.remember_line(MemoryStore.SPEAKER_PLAYER, player_text)
	store.remember_line(MemoryStore.SPEAKER_GIRL, girl_reply)
	for pattern in patterns():
		var text := girl_reply if pattern["speaker"] == SPEAKER_GIRL else player_text
		var found: RegExMatch = (pattern["regex"] as RegEx).search(text)
		if found == null:
			continue
		var topic := found.get_string("topic") if found.names.has("topic") else ""
		var value := found.get_string("value").strip_edges() if found.names.has("value") else ""
		var key := str(pattern["key"]).format({"topic": topic.to_lower(), "week": GameState.week})
		var line := Text.f(str(pattern["text_key"]), {"topic": topic, "value": value, "line": text.strip_edges()})
		store.remember_core(key, line, GameState.week)


## 玩家提醒她记混了、而且说得对：把这次提醒记成一条重要的记忆，下次想起这件事时会带上
static func record_correction(store: MemoryStore, player_text: String) -> void:
	var text := Text.f("WK-15-21", {"week": GameState.week, "line": player_text.strip_edges()})
	store.remember_event(text, MemoryStore.KIND_EVENT, int(DataDB.balance("memory_correction_importance")), GameState.week, GameState.age)


static func patterns() -> Array[Dictionary]:
	if _patterns.is_empty():
		for id: String in DataDB.table("memory_patterns"):
			var row := DataDB.row("memory_patterns", id).duplicate()
			var regex := RegEx.create_from_string(str(row["regex"]))
			if regex == null or not regex.is_valid():
				push_error("memory_patterns.csv 的正则写错了：" + id)
				continue
			row["regex"] = regex
			_patterns.append(row)
	return _patterns


static func _add(store: MemoryStore, text: String, importance: int, week := -1) -> String:
	var when := GameState.week if week < 0 else week
	store.remember_event(text, MemoryStore.KIND_EVENT, importance, when, GameState.age)
	return text


static func _join(names: PackedStringArray) -> String:
	return Text.t("WK-08-06").join(names)
