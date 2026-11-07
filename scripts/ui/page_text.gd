class_name PageText
extends RefCounted
## 拼出周结算、时间跳跃、结局页的文字。

const NUMBER_CATEGORIES: Array[String] = ["state", "skill"]
const SKILL_CATEGORY := "skill"
const CHANGE_HIDDEN: Array[String] = ["stamina"]  # 体力单独一行说明，不混进变化里


## 周结算：状态和技能写涨跌；性格和信任只在文字档位变化时写
static func week_summary(recovered: int, before_age: int) -> PackedStringArray:
	var result := PackedStringArray([Text.f("UI-07-03", {"value": recovered})])
	var changes := _changes(GameState.summary_stats, before_age)
	result.append(Text.t("UI-07-02"))
	if changes.is_empty():
		result.append(Text.t("UI-07-04"))
	else:
		result.append_array(changes)
	result.append(Text.t("WK-02-01"))
	GameState.summary_stats = GameState.stats.duplicate()
	return result


## 时间跳跃：先几句过渡，再是"这些年"总结（比赛版用一页文字代替蒙太奇）
static func time_jump(before: Dictionary, old_age: int) -> PackedStringArray:
	var result := PackedStringArray()
	for i in range(1, 5):
		result.append(Text.t("TJ-01-%02d" % i))
	result.append(Text.f("TJ-02-02", {"girl": GameState.girl_name, "old_age": old_age, "new_age": GameState.age}))
	for id: String in DataDB.table("girl_stats"):
		var category := str(DataDB.row("girl_stats", id)["category"])
		var name := UiKit.stat_name(id)
		if category == SKILL_CATEGORY:
			result.append(Text.f("TJ-02-03", {"name": name, "old": before[id], "new": GameState.get_stat(id)}))
		elif not NUMBER_CATEGORIES.has(category):
			var old_text := GameState.trait_text(id, int(before[id]), old_age)
			var new_text := GameState.trait_text(id, GameState.get_stat(id), GameState.age)
			if old_text != new_text:
				result.append(Text.f("TJ-02-04", {"name": name, "old": old_text, "new": new_text}))
	GameState.summary_stats = GameState.stats.duplicate()
	return result


## 结局（比赛版第 5 节的统一收尾，先用一页文字）
static func ending() -> PackedStringArray:
	var girl := {"girl": GameState.girl_name}
	var result := PackedStringArray([
		Text.t("ED-01-02"),
		Text.f("ED-02-" + WeekSystem.top_trait(), girl),
		Text.f("ED-01-03", girl),
		Text.t("ED-01-04"),
	])
	if GameState.is_high("trust"):
		result.append(Text.f("ED-01-05", girl))
	return result


static func _changes(before: Dictionary, age: int) -> PackedStringArray:
	var result := PackedStringArray()
	for id: String in DataDB.table("girl_stats"):
		var now := GameState.get_stat(id)
		var old_value := int(before[id])
		if NUMBER_CATEGORIES.has(str(DataDB.row("girl_stats", id)["category"])):
			if now != old_value and not CHANGE_HIDDEN.has(id):
				result.append(Text.f("UI-07-06", {"name": UiKit.stat_name(id), "delta": "%+d" % (now - old_value)}))
		else:
			var old_text := GameState.trait_text(id, old_value, age)
			var new_text := GameState.trait_text(id, now, age)
			if old_text != new_text:
				result.append(Text.f("UI-07-05", {"name": UiKit.stat_name(id), "old": old_text, "new": new_text}))
	return result
