class_name StoryTriggers
extends RefCounted
## 剧情触发：什么时候播哪段剧情。规则写在 story/nodes.csv，不写在代码里。
## 每一行是一个剧情节点：在哪个时刻（moment）、第几周（空着表示每周都行）、满足什么条件（condition）时播。
## 每个节点只播一次，播过记在 GameState.flags 里，所以会跟着存档走。
## "保底"也是普通节点：条件写成"某件事还没发生"，比如 not flag("w5_trace_found")，
## 到了那个时刻玩家还没做到，就由保底剧情把故事推下去。
##
## 现在 main.gd 会在这些时刻问一次：
##   new_game 起完名字后 · week_start 早上课程结算后、进主界面前 · week_end 点结束本周后、周结算前
##   week_night 周结算页关掉后（夜里的剧情）· time_jump 第 3 周夜里之后、"这些年"页之前（蒙太奇）
##   after_jump 时间跳跃页之后 · ending 第 7 周之后（结局和尾声，播完接制作人员名单）
## 地球画面会问 earth_enter（进小镇）、earth_plant_found、earth_seed_jar_found。
## 别的模块（比如地球进入新区域）也可以自己起名字调用 pick("earth_enter_b")，再播放返回的节点。

const NODES_PATH := "res://story/nodes.csv"
const SEEN_PREFIX := "story_seen_"

static var _nodes: Array[Dictionary] = []


## 这个时刻该播的节点，按表格顺序。不会自动标记"已播"，播完由播放器调用 mark_seen。
static func pick(moment: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for node in nodes():
		if node["moment"] != moment or is_seen(node["id"]):
			continue
		if not str(node["week"]).is_empty() and int(node["week"]) != GameState.week:
			continue
		if not check(node["condition"]):
			continue
		result.append(node)
	return result


static func is_seen(id: String) -> bool:
	return bool(GameState.flags.get(SEEN_PREFIX + id, false))


static func mark_seen(id: String) -> void:
	GameState.flags[SEEN_PREFIX + id] = true


## 算一个条件。空条件算满足；写错的条件算不满足并报警告，不会让游戏崩掉。
static func check(condition: String) -> bool:
	if condition.strip_edges().is_empty():
		return true
	var expression := Expression.new()
	if expression.parse(condition) != OK:
		push_warning("剧情条件写错了：%s（%s）" % [condition, expression.get_error_text()])
		return false
	var value: Variant = expression.execute([], Conditions.new())
	if expression.has_execute_failed():
		push_warning("剧情条件算不出来：" + condition)
		return false
	return bool(value)


static func nodes() -> Array[Dictionary]:
	if _nodes.is_empty():
		_load()
	return _nodes


static func _load() -> void:
	var file := FileAccess.open(NODES_PATH, FileAccess.READ)
	if file == null:
		push_error("读不到剧情节点表：" + NODES_PATH)
		return
	var header := file.get_csv_line()
	header[0] = header[0].trim_prefix("﻿")
	while not file.eof_reached():
		var line := file.get_csv_line()
		var id := line[0].strip_edges()
		if id.is_empty() or id.begins_with("#"):
			continue
		var node := {}
		for i in header.size():
			node[header[i]] = line[i].strip_edges() if i < line.size() else ""
		_nodes.append(node)


## 条件里能用的词。例：week() >= 3 and stat("trust") > 50 and not seen("w5_alarm")
class Conditions:
	extends RefCounted

	func week() -> int:
		return GameState.week

	func age() -> int:
		return GameState.age

	func stat(id: String) -> int:
		return GameState.get_stat(id)

	func flag(name: String) -> bool:
		return bool(GameState.flags.get(name, false))

	func seen(id: String) -> bool:
		return StoryTriggers.is_seen(id)

	func met_survivor() -> bool:
		return GameState.met_survivor

	## 0 以为是游戏 · 1 怀疑 · 2 相信
	func cognition() -> int:
		return GameState.cognition
