class_name PageText
extends RefCounted
## 拼出周结算、时间跳跃、结局页的文字。

const JUMP_HIDDEN_CATEGORY := "state"  # 体力和心情跳跃后重置，不算"这些年"的成长
const CHANGE_HIDDEN: Array[String] = ["stamina"]  # 体力单独一行说明，不混进变化里


## 周结算：所有属性都写数字涨跌
static func week_summary(recovered: int) -> PackedStringArray:
	var result := _earth_lines()
	result.append(Text.f("UI-07-03", {"value": recovered}))
	var changes := _changes(GameState.summary_stats)
	result.append(Text.t("UI-07-02"))
	if changes.is_empty():
		result.append(Text.t("UI-07-04"))
	else:
		result.append_array(changes)
	result.append(Text.t("WK-02-01"))
	GameState.summary_stats = GameState.stats.duplicate()
	return result


## 时间跳跃后的"这些年"总结页（文案 TJ-03）。蒙太奇（TJ-02）在这页之前由剧情播放器播。
## 技能一行、性格和信任一行，写真实的旧值和新值。
static func time_jump(before: Dictionary, old_age: int) -> PackedStringArray:
	var result := PackedStringArray()
	result.append(Text.f("TJ-03-02", {"girl": GameState.girl_name, "old_age": old_age, "new_age": GameState.age}))
	var skills := PackedStringArray()
	var traits := PackedStringArray()
	for id: String in DataDB.table("girl_stats"):
		var category := str(DataDB.row("girl_stats", id)["category"])
		if category == JUMP_HIDDEN_CATEGORY:
			continue
		var item := Text.f("TJ-03-91", {"name": UiKit.stat_name(id), "old": before[id], "new": GameState.get_stat(id)})
		if category == "skill":
			skills.append(item)
		else:
			traits.append(item)
	result.append(Text.f("TJ-03-03", {"list": " · ".join(skills)}))
	result.append(Text.f("TJ-03-04", {"list": " · ".join(traits)}))
	result.append(Text.t("TJ-03-06"))
	result.append(Text.t("TJ-03-07"))
	# 第 3 周一直没看到植物事件（正常不会发生，结束本周时会保底播）：种植区由时间跳跃保底解锁
	if GameState.flags.get("seeds_from_plant", false) and not GameState.flags.get("plant_event_done", false):
		result.append(Text.t("UI-54-07"))
	GameState.summary_stats = GameState.stats.duplicate()
	return result


## 周结算里的地球部分：施工完成、获得资源、四项恢复度
static func _earth_lines() -> PackedStringArray:
	var report: Dictionary = GameState.last_earth_report
	var result := PackedStringArray()
	if report.is_empty():
		return result
	var finished: Array = report["finished"]
	if not finished.is_empty():
		result.append(Text.f("UI-07-07", {"names": Text.t("UI-50-12").join(PackedStringArray(finished))}))
	if int(report["metal"]) != 0 or int(report["electronics"]) != 0:
		result.append(Text.f("UI-07-08", {"metal": report["metal"], "electronics": report["electronics"]}))
	if report.get("goal_done", false):
		result.append(Text.t("UI-20-14"))
	if not str(report.get("girl_clue", "")).is_empty():
		result.append(Text.f("UI-20-17", {"name": Text.t(str(DataDB.row("earth_clues", report["girl_clue"])["name_key"]))}))
	if not str(report.get("self_handled", "")).is_empty():
		result.append(Text.t("UI-20-18"))
	var regions: Dictionary = report.get("regions", {})
	for region: String in regions:
		var name := Text.t(str(DataDB.row("earth_regions", region)["name_key"]))
		result.append(Text.f("UI-15-60", {"name": name, "recovery": recovery_text(regions[region])}))
	return result


static func recovery_text(values: Dictionary) -> String:
	var parts: PackedStringArray = []
	var names := {"ruins": "UI-15-01", "power": "UI-15-02", "water": "UI-15-03", "plants": "UI-15-04"}
	for key: String in names:
		parts.append(Text.f("UI-15-05", {"name": Text.t(names[key]), "value": values[key]}))
	return " · ".join(parts)


static func _changes(before: Dictionary) -> PackedStringArray:
	var result := PackedStringArray()
	for id: String in DataDB.table("girl_stats"):
		var now := GameState.get_stat(id)
		var old_value := int(before[id])
		if now != old_value and not CHANGE_HIDDEN.has(id):
			result.append(Text.f("UI-07-06", {"name": UiKit.stat_name(id), "delta": "%+d" % (now - old_value)}))
	return result
