extends Node
## 数据表读取（自动加载，名字 DataDB）
## 所有数值都在 res://data/ 的表格里。改数值只改表格，不用改这里。
## 表格第一列是 id；以 # 开头的行会被跳过，可以当注释用。

const DATA_DIR := "res://data/"
const TABLES := ["courses", "girl_stats", "buildings", "attitude_effects", "balance", "chat_keywords", "trait_texts", "earth_ruins", "earth_zones", "earth_regions", "earth_props", "earth_specials", "earth_clues", "plants", "girl_proposals", "girl_goals", "earth_events", "memory_patterns", "memory_flags", "chat_actions", "chat_moods", "chat_stages", "chat_idle", "earth_tutorial", "chat_story_lines", "room_objects", "places", "room_options", "tech", "earth_roads", "earth_decor"]  # "tech" 之前 4 张是房间线程加的；最后 2 张是美术线程加的（小镇的路和摆件）

var _tables := {}  # 表名 -> { id -> { 列名: 值 } }


func _ready() -> void:
	for table_name in TABLES:
		_tables[table_name] = _load_csv(DATA_DIR + table_name + ".csv")


## 取整张表：{ id -> 一行 }
func table(table_name: String) -> Dictionary:
	return _tables.get(table_name, {})


## 取一行；找不到时返回空字典
func row(table_name: String, id: String) -> Dictionary:
	return table(table_name).get(id, {})


## 取平衡参数（balance.csv 的 value 列）
func balance(id: String, default_value: Variant = 0) -> Variant:
	var r := row("balance", id)
	if r.is_empty():
		push_warning("balance.csv 里没有：" + id)
		return default_value
	return r["value"]


func _load_csv(path: String) -> Dictionary:
	var result := {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("读不到数据表：" + path)
		return result
	var header := file.get_csv_line()
	if header.is_empty():
		return result
	header[0] = header[0].trim_prefix("﻿")  # 去掉 Excel 存 UTF-8 时加的 BOM
	while not file.eof_reached():
		var line := file.get_csv_line()
		if line.is_empty() or line[0].strip_edges() == "" or line[0].begins_with("#"):
			continue
		var r := {}
		for i in header.size():
			r[header[i]] = _parse(line[i]) if i < line.size() else ""
		result[str(line[0]).strip_edges()] = r
	return result


func _parse(text: String) -> Variant:
	var t := text.strip_edges()
	if t.is_valid_int():
		return t.to_int()
	if t.is_valid_float():
		return t.to_float()
	return t
