extends Node
## 文字表（自动加载，名字 Text）：按编号取文字。
## 文字都在 res://text/*.csv，第一列是编号，后面每种语言一列。
## 没用 Godot 自带的翻译导入：它要生成额外文件，重新下载仓库后容易报错；
## 这样改完表格直接生效，和 data/ 的表格一个用法。

const TEXT_DIR := "res://text/"
const FILES: Array[String] = ["ui", "cr", "fb", "wk", "tj", "ed", "op", "w1", "w5", "en_fill"]  # en_fill 放最后：只补前面表里空着的英文
const DEFAULT_LANGUAGE := "zh"

var language := DEFAULT_LANGUAGE
var _rows := {}  # 编号 -> { 语言: 文字 }


func _ready() -> void:
	for file_name in FILES:
		_load_csv(TEXT_DIR + file_name + ".csv")


## 取一句文字。当前语言没写时退回默认语言；编号不存在时显示编号本身，一眼能看出漏了什么。
func t(key: String) -> String:
	var row: Dictionary = _rows.get(key, {})
	if row.is_empty():
		push_warning("文字表里没有这个编号：" + key)
		return key
	var value: String = row.get(language, "")
	if value.is_empty():
		value = str(row.get(DEFAULT_LANGUAGE, key))
	# 她和你的名字玩家可以改，所以每句都自动填，文字表里写 {girl} {player} 就行
	return value.format({"girl": GameState.girl_name, "player": GameState.player_name})


## 取一句带占位符的文字，如 f("UI-01-05", {"week": 3})，替换 {week}
func f(key: String, values: Dictionary) -> String:
	return t(key).format(values)


func _load_csv(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("读不到文字表：" + path)
		return
	var header := file.get_csv_line()
	header[0] = header[0].trim_prefix("﻿")
	while not file.eof_reached():
		var line := file.get_csv_line()
		var key := line[0].strip_edges()
		if key.is_empty() or key.begins_with("#"):
			continue
		# 同一个编号出现在多张表里时合并：只补空着的语言。
		# 这样英文可以先集中写在 en_fill.csv，不用改动别人正在编辑的那几行。
		var row: Dictionary = _rows.get(key, {})
		for i in range(1, header.size()):
			var value := line[i] if i < line.size() else ""
			if str(row.get(header[i], "")).is_empty():
				row[header[i]] = value
		_rows[key] = row


## 所有编号（自动测试用来检查中英文是不是都填了）
func all_keys() -> Array:
	return _rows.keys()


## 某个编号在某种语言下有没有写（不退回默认语言）
func has_language(key: String, lang: String) -> bool:
	return not str(_rows.get(key, {}).get(lang, "")).is_empty()
