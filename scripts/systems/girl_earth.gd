class_name GirlEarth
extends RefCounted
## 她怎样影响建造（比赛版 4.4"女孩怎样影响建造"、4.3 突发事件）。只算规则，不碰画面。
## 她说的话现在是临时固定句；人物 AI 线程接好模型后，把 say_key 换成模型生成即可。

const ACCEPT := "accept"
const EXPLAIN := "explain"
const REJECT := "reject"
const ANSWER_EFFECTS := {
	ACCEPT: {"confidence": 2, "trust": 1},
	EXPLAIN: {},
	REJECT: {"confidence": -1, "trust": -2},
}


# ---------- 她的方案（每周最多 2 次）----------

## 这次进小镇她要不要提方案；要提返回方案（proposals 表的一行），否则空字典
static func maybe_propose(world: EarthWorld, rng: RandomNumberGenerator) -> Dictionary:
	if GameState.weekly.get("proposals", 0) >= int(DataDB.balance("girl_proposals_per_week")):
		return {}
	if GameState.get_stat("stamina") < int(DataDB.balance("low_stamina")):
		return {}
	# 长期不被重视，她会越来越少提（每被直接否决一次，概率降一截）
	var chance: float = float(DataDB.balance("girl_proposal_chance")) - int(GameState.flags.get("proposal_rejects", 0)) * float(DataDB.balance("girl_proposal_chance_drop"))
	if rng.randf() >= chance:
		return {}
	var choices: Array[Dictionary] = []
	for id: String in DataDB.table("girl_proposals"):
		var row := DataDB.row("girl_proposals", id)
		if _proposal_possible(world, row) and GameState.get_stat(str(row["trait"])) >= int(row["min_trait"]):
			choices.append(row)
	if choices.is_empty():
		return {}
	GameState.weekly["proposals"] = GameState.weekly.get("proposals", 0) + 1
	# 性格越突出的方案越优先：建设风格由性格决定（比赛版 4.4）
	choices.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return GameState.get_stat(str(a["trait"])) > GameState.get_stat(str(b["trait"])))
	return choices[0]


## 玩家回答她的方案：同意 / 说明理由否决 / 直接否决。同意时把方案排进施工队列。
static func answer(world: EarthWorld, proposal: Dictionary, choice: String) -> void:
	var effects: Dictionary = ANSWER_EFFECTS[choice]
	for id: String in effects:
		GameState.change_stat(id, int(effects[id]))
	if choice == REJECT:
		GameState.flags["proposal_rejects"] = GameState.flags.get("proposal_rejects", 0) + 1
	if choice == ACCEPT and proposal["kind"] == "clear":
		world.queue_clear(str(proposal["target"]))
	if choice == ACCEPT and proposal["kind"] == "intent":
		GameState.girl_intent = str(proposal["target"])


static func _proposal_possible(world: EarthWorld, row: Dictionary) -> bool:
	if row["kind"] == "clear":
		var ruin: Dictionary = world.ruins.get(row["target"], {})
		return not ruin.is_empty() and not ruin["cleared"] and not world.is_ruin_queued(row["target"]) \
			and world.is_region_open(world.region_of(Vector2i(int(ruin["x"]), int(ruin["z"]))))
	return true


# ---------- 属性门槛行为 ----------

## 好奇 ≥ 60：进入区域时她会标出隐藏点（线索直接显示在地图上）
static func reveals_clues() -> bool:
	return GameState.is_high("curiosity")


## 共情 ≥ 60：你要拆植物旁边的废墟时她会阻止
static func objects_to_clear(world: EarthWorld, ruin_id: String) -> bool:
	if not GameState.is_high("empathy"):
		return false
	var ruin: Dictionary = world.ruins[ruin_id]
	var rect := Rect2i(int(ruin["x"]), int(ruin["z"]), int(ruin["w"]), int(ruin["h"])).grow(1)
	for cell: Vector2i in world.plants:
		if rect.has_point(cell):
			return true
	return false


## 心情 < 30：她更容易反对你的规划（只说一句，不拦着）
static func objects_to_plan(rng: RandomNumberGenerator) -> bool:
	return GameState.get_stat("mood") < int(DataDB.balance("low_mood")) and rng.randf() < float(DataDB.balance("girl_mood_object_chance"))


## 自信 ≥ 60：每周她自己定一个目标；完成了自信 +2、信任 +2
static func pick_week_goal(world: EarthWorld) -> Dictionary:
	if not GameState.is_high("confidence"):
		return {}
	for id: String in DataDB.table("girl_goals"):
		var row := DataDB.row("girl_goals", id)
		if not _goal_done(world, row):
			return row
	return {}


static func goal_reward(world: EarthWorld, goal: Dictionary) -> bool:
	if goal.is_empty() or not _goal_done(world, goal):
		return false
	GameState.change_stat("confidence", int(DataDB.balance("girl_goal_reward")))
	GameState.change_stat("trust", int(DataDB.balance("girl_goal_reward")))
	return true


static func _goal_done(world: EarthWorld, goal: Dictionary) -> bool:
	match str(goal["kind"]):
		"recovery":
			return int(world.recovery()[str(goal["target"])]) >= int(goal["amount"])
		"build":
			var count := 0
			for building: Dictionary in world.buildings.values():
				if building["done"] and building["type"] == goal["target"]:
					count += 1
			return count >= int(goal["amount"])
	return false


## 周结算：好奇高时她自己找到一处线索；信任 ≤ 30 时找到了也不告诉你（比赛版 4.4）
## 返回她找到并告诉你的线索 id；没找到或不说返回空字符串
static func week_end_discovery(world: EarthWorld) -> String:
	if not GameState.is_high("curiosity"):
		return ""
	var clues := world.active_clues()
	if clues.is_empty():
		return ""
	if GameState.is_low("trust"):
		GameState.flags["hidden_clue_" + clues[0]] = true
		return ""
	world.discover_clue(clues[0])
	return clues[0]


# ---------- 突发事件（4.3）----------

## 条件 → 冷却和每周上限 → 按权重抽 → 她决定找不找你。返回事件行；没有返回空字典。
static func pick_event(world: EarthWorld, rng: RandomNumberGenerator) -> Dictionary:
	if GameState.weekly.get("events", 0) >= int(DataDB.balance("event_per_week")):
		return {}
	if rng.randf() >= float(DataDB.balance("event_chance")):
		return {}
	var total := 0
	var pool: Array[Dictionary] = []
	for id: String in DataDB.table("earth_events"):
		var row := DataDB.row("earth_events", id)
		if GameState.get_stat(str(row["stat"])) >= int(row["min_stat"]) and _event_possible(world, row):
			pool.append(row)
			total += int(row["weight"])
	if pool.is_empty():
		return {}
	var roll := rng.randi_range(1, total)
	for row in pool:
		roll -= int(row["weight"])
		if roll <= 0:
			GameState.weekly["events"] = GameState.weekly.get("events", 0) + 1
			# 自信高时她可能自己处理，事后在周结算提一句
			if GameState.is_high("confidence") and rng.randf() < float(DataDB.balance("event_self_handle_chance")):
				GameState.weekly["self_handled"] = row["id"]
				return {}
			return row
	return {}


## 事件开始时发生的事：设备停运就真的让一台设备坏掉
static func start_event(world: EarthWorld, event: Dictionary) -> void:
	if str(event["id"]) == "device_stop":
		_break_first_running(world)


## 按最后一轮的 intent 执行结果（4.3）；event 是 earth_events 表的一行。
## 返回结果说明的文字编号（可能为空）。
static func resolve_event(world: EarthWorld, event: Dictionary, intent: String) -> String:
	match str(event["id"]):
		"device_stop":
			if intent == "continue" and GameState.get_stat("mechanics") >= int(DataDB.balance("event_self_repair_mechanics")):
				for uid: int in world.buildings:
					world.repair_building(uid)
				GameState.change_stat("confidence", 1)
				return "UI-21-40"
			return "UI-21-41"
		"ark_failure":
			if intent == "withdraw":
				world.ark_position = Vector3.INF  # 撤回：下次进小镇 ARK-01 回到维修站
			elif intent == "continue":
				GameState.change_stat("confidence", 1)
		"danger_zone":
			if intent == "explore":
				GameState.change_stat("curiosity", 1)
				world.set_prop_state("underground", "shown")
			elif intent == "investigate":
				for id in world.active_clues():
					world.discover_clue(id)
	return ""


static func _event_possible(world: EarthWorld, row: Dictionary) -> bool:
	if str(row["id"]) == "device_stop":
		for building: Dictionary in world.buildings.values():
			if building["done"] and not building.get("broken", false) and int(DataDB.row("buildings", building["type"])["needs_power"]) == 1:
				return true
		return false
	return true


static func _break_first_running(world: EarthWorld) -> void:
	var ids: Array = world.buildings.keys()
	ids.sort()
	for uid: int in ids:
		var building: Dictionary = world.buildings[uid]
		if building["done"] and not building.get("broken", false) and int(DataDB.row("buildings", building["type"])["needs_power"]) == 1:
			world.break_building(uid)
			return
