extends Node
## 游戏状态（自动加载，名字 GameState）
## 程序里"真实发生了什么"都存在这里：属性、周数、她的认知、剧情标记。
## 模型只说话和打标签，不直接改这里的数值。

signal stat_changed(id: String, old_value: int, new_value: int)

enum Cognition { GAME, DOUBT, BELIEVE }  # 以为是游戏 / 怀疑 / 相信地球是真的

var week := 1
var age := 8
var cognition := Cognition.GAME
var met_survivor := false   # 第 5 周分线：ARK-01 有没有走进温室
var girl_name := "朝禾"
var player_name := "新星"
var stats := {}             # 属性 id -> 当前值
var flags := {}             # 剧情标记，例如 "week2_plant_named": true

var schedule: Array[String] = []        # 接下来要上的 7 天课
var last_schedule: Array[String] = []   # 上一次实际结算的课表（"沿用上周"用它）
var chat_rounds_left := -1              # 本周还能聊几轮；-1 表示本周还没算过
var chat_week_changes := {}             # 本周聊天已带来的属性变化，用来封顶防刷
var girl_intent := "none"               # 她最近一次说的建造意向
var initial_stats := {}                 # 开局属性，时间跳跃按"前两周变化"计算
var summary_stats := {}                 # 上次周结算时的属性，周结算显示和它的差


func _ready() -> void:
	reset()


## 开新游戏时调用：属性回到 girl_stats.csv 里的初始值
func reset() -> void:
	week = 1
	age = int(DataDB.balance("child_age"))
	cognition = Cognition.GAME
	met_survivor = false
	flags.clear()
	stats.clear()
	for id in DataDB.table("girl_stats"):
		stats[id] = int(DataDB.row("girl_stats", id)["initial"])
	initial_stats = stats.duplicate()
	summary_stats = stats.duplicate()
	schedule.clear()
	for _i in int(DataDB.balance("week_days")):
		schedule.append(CourseSystem.REST)
	last_schedule = schedule.duplicate()
	chat_rounds_left = -1
	chat_week_changes.clear()
	girl_intent = "none"


func get_stat(id: String) -> int:
	return stats.get(id, 0)


## 改属性，自动截断在表格规定的范围内
func change_stat(id: String, delta: int) -> void:
	if not stats.has(id):
		push_warning("没有这个属性：" + id)
		return
	var old_value: int = stats[id]
	var new_value := clamp_value(id, old_value + delta, stats)
	stats[id] = new_value
	if new_value != old_value:
		stat_changed.emit(id, old_value, new_value)


## 把一个值截断在该属性的范围内。source 是用来查上限的属性表，
## 这样排课预演可以在副本上算，不影响真实状态。
func clamp_value(id: String, value: int, source: Dictionary) -> int:
	return clampi(value, _limit(id, "min", source), _limit(id, "max", source))


## 性格和信任的"高 / 低"判定（判定线在 balance.csv）
func is_high(id: String) -> bool:
	return get_stat(id) >= int(DataDB.balance("trait_high", 60))


func is_low(id: String) -> bool:
	return get_stat(id) <= int(DataDB.balance("trait_low", 30))


## 性格和信任不显示数字，只显示一句话（比赛版 4.1）
func trait_text(id: String, value: int, for_age: int) -> String:
	var band := "mid"
	if value >= int(DataDB.balance("trait_high", 60)):
		band = "high"
	elif value <= int(DataDB.balance("trait_low", 30)):
		band = "low"
	var row := DataDB.row("trait_texts", "%s_%d_%s" % [id, for_age, band])
	return Text.t(str(row.get("key", "")))


func _limit(id: String, column: String, source: Dictionary) -> int:
	var value: Variant = DataDB.row("girl_stats", id).get(column, 0)
	if value is String:  # 例如体力的上限写的是 stamina_max，就去取那个属性的当前值
		return int(source.get(value, 0))
	return int(value)
