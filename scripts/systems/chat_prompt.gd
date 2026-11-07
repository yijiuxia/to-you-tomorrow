class_name ChatPrompt
extends RefCounted
## 把真实状态整理成发给模型的人设文字。完整的"状态卡"（记忆、剧情阶段）第 4 步再做。

const TEMPLATE_DIR := "res://text/prompts/"
const NUMERIC_STATS: Array[String] = ["stamina", "mood"]
const TRAIT_STATS: Array[String] = ["confidence", "curiosity", "empathy", "trust"]
const SKILL_STATS: Array[String] = ["mechanics", "ecology", "comms"]


## closing 为 true 时告诉模型"这一轮该收尾了"（比赛版 4.3）
static func build(closing: bool) -> String:
	var template := FileAccess.get_file_as_string(TEMPLATE_DIR + "girl_%s.txt" % Text.language)
	return template.format({
		"girl": GameState.girl_name,
		"player": GameState.player_name,
		"age": GameState.age,
		"week": GameState.week,
		"state": _state_text(),
		"closing": Text.t("WK-05-01") if closing else "",
	})


static func _state_text() -> String:
	var parts: PackedStringArray = []
	for id: String in NUMERIC_STATS + SKILL_STATS:
		parts.append(Text.f("WK-06-02", {"name": _name(id), "value": GameState.get_stat(id)}))
	for id: String in TRAIT_STATS:
		parts.append(Text.f("WK-06-03", {"name": _name(id), "text": GameState.trait_text(id, GameState.get_stat(id), GameState.age)}))
	return Text.f("WK-06-01", {"stats": "，".join(parts)})


static func _name(id: String) -> String:
	return Text.t(str(DataDB.row("girl_stats", id)["name_key"]))
