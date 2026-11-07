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


func _ready() -> void:
	reset()


## 开新游戏时调用：属性回到 girl_stats.csv 里的初始值
func reset() -> void:
	week = 1
	age = 8
	cognition = Cognition.GAME
	met_survivor = false
	flags.clear()
	stats.clear()
	for id in DataDB.table("girl_stats"):
		stats[id] = int(DataDB.row("girl_stats", id)["initial"])


func get_stat(id: String) -> int:
	return stats.get(id, 0)


## 改属性，自动截断在表格规定的范围内
func change_stat(id: String, delta: int) -> void:
	if not stats.has(id):
		push_warning("没有这个属性：" + id)
		return
	var old_value: int = stats[id]
	var new_value: int = clampi(old_value + delta, _limit(id, "min"), _limit(id, "max"))
	stats[id] = new_value
	if new_value != old_value:
		stat_changed.emit(id, old_value, new_value)


## 性格和信任的"高 / 低"判定（判定线在 balance.csv）
func is_high(id: String) -> bool:
	return get_stat(id) >= int(DataDB.balance("trait_high", 60))


func is_low(id: String) -> bool:
	return get_stat(id) <= int(DataDB.balance("trait_low", 30))


func _limit(id: String, column: String) -> int:
	var value: Variant = DataDB.row("girl_stats", id).get(column, 0)
	if value is String:  # 例如体力的上限写的是 stamina_max，就去取那个属性的当前值
		return get_stat(value)
	return int(value)
