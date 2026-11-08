class_name ChatWorldbook
extends RefCounted
## 世界书（比赛版 4.5，借鉴 SillyTavern）：对话里提到关键词时，把她知道的设定补给模型。
## 小模型记不住整套世界观，全塞进人设又太长，所以只在聊到时才带上相关的几条。
## 同一套关键词也用来给记忆打"话题标签"，按相关度取记忆时靠它比较。

const PATH := "res://text/prompts/worldbook.csv"
const NO_LIMIT := 0

static var _rows: Array[Dictionary] = []


## 这段文字涉及哪些话题（不看周数和剧情标记，只看关键词），用来给记忆打标签
static func topics(text: String) -> PackedStringArray:
	var result := PackedStringArray()
	var lower := text.to_lower()
	for row in rows():
		if _matches(lower, row) and not result.has(row["id"]):
			result.append(row["id"])
	return result


## 这段文字该补哪些设定：只取现在有效的（周数、剧情标记对得上），最多 max_count 条
static func entries(text: String, max_count: int) -> PackedStringArray:
	var result := PackedStringArray()
	var lower := text.to_lower()
	for row in rows():
		if result.size() >= max_count:
			break
		if _matches(lower, row) and is_active(row):
			result.append(entry_text(row))
	return result


static func entry_text(row: Dictionary) -> String:
	var value := str(row.get(Text.language, ""))
	if value.is_empty():
		value = str(row.get(Text.DEFAULT_LANGUAGE, ""))
	return value.format({"girl": GameState.girl_name, "player": GameState.player_name})


## 剧情没到的设定不能给，否则她会提前"知道"幸存者（防剧透，完整世界观第 15 节）
static func is_active(row: Dictionary) -> bool:
	var from_week := int(row["from_week"])
	var until_week := int(row["until_week"])
	if from_week != NO_LIMIT and GameState.week < from_week:
		return false
	if until_week != NO_LIMIT and GameState.week > until_week:
		return false
	var need := str(row["need_flag"])
	if not need.is_empty() and not flag_on(need):
		return false
	var hide := str(row["hide_flag"])
	return hide.is_empty() or not flag_on(hide)


## met_survivor 存在 GameState 的变量里，其他剧情标记在 flags 里
static func flag_on(id: String) -> bool:
	if id == "met_survivor":
		return GameState.met_survivor
	return bool(GameState.flags.get(id, false))


static func _matches(lower_text: String, row: Dictionary) -> bool:
	for word: String in row["words"]:
		if lower_text.contains(word):
			return true
	return false


static func rows() -> Array[Dictionary]:
	if _rows.is_empty():
		_rows = _load()
	return _rows


static func _load() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		push_error("读不到世界书：" + PATH)
		return result
	var header := file.get_csv_line()
	header[0] = header[0].trim_prefix("﻿")
	while not file.eof_reached():
		var line := file.get_csv_line()
		if line.is_empty() or line[0].strip_edges().is_empty() or line[0].begins_with("#"):
			continue
		var row := {}
		for i in header.size():
			row[header[i]] = line[i].strip_edges() if i < line.size() else ""
		var words := PackedStringArray()
		for word in str(row["words"]).split("|", false):
			words.append(word.strip_edges().to_lower())
		row["words"] = words
		result.append(row)
	return result
