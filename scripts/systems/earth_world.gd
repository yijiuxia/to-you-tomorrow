class_name EarthWorld
extends RefCounted
## 地球的规则（比赛版 4.4）：土地、建筑、施工队列、水电网络、恢复度、周结算，
## 以及区域开放、剧情物件、特殊施工、线索、植物和地球对养成的影响。
## 这里只算数，不碰画面：画面从这里读状态，所以俯视和第三人称看到的永远一致。

signal changed

const POWER_PROBLEM := "no_power"
const WATER_PROBLEM := "no_water"
const SOIL_PROBLEM := "polluted"
const RUIN_BIG := "big"
const JOB_BUILD := "build"
const JOB_CLEAR := "clear"
const FARM := "farm_plot"
const PIPE := "water_pipe"
const NODE_ID := "power_node"
const GENERATOR := "generator"
const PURIFIER := "purifier"
const SKILL_COLUMNS := {"unlock_mechanics": "mechanics", "unlock_ecology": "ecology", "unlock_comms": "comms"}
const RELAY := "relay"
const GREENHOUSE := "greenhouse"
const BROKEN_PROBLEM := "broken"
const RIVER := "river"
const GATE := "gate"
const BRIDGE := "bridge"
const GATE_FLAG := "gate_open"
const BRIDGE_FLAG := "bridge_open"
const OLD_POWER_FLAG := "old_power_fixed"
const BRIDGE_TEMP_FLAG := "bridge_temp"
const FARM_PLANT := "grass"
const HAND_PLANT := "flower"
const TRAIT_STATS := {"built": "confidence", "planted": "empathy", "clues": "curiosity"}

var grid_width: int
var grid_height: int
var metal := 0
var electronics := 0
var pollution := {}     # 格子 -> 污染等级（2 重度 1 轻度 0 无）
var ruins := {}         # 废墟 id -> { id, kind, x, z, w, h, work_units, metal, electronics, cleared }
var buildings := {}     # 建筑编号 -> { uid, type, x, z, w, h, done, powered, watered }
var queue: Array[Dictionary] = []  # 施工队列：{ kind, ref, total, done }
var plants := {}        # 格子 -> { type, age }，age 是长了几周
var props := {}         # 剧情物件 id -> 当前状态，如 gate -> closed
var found_clues := {}   # 已发现的线索 id -> true
var holes := {}         # 苗被挖走留下的坑：格子 -> true
var week_counts := {"built": 0, "planted": 0, "clues": 0}  # 本周地球上发生的事，周结算算养成加成
var scraps: Array[Dictionary] = [] # 拆下来还没捡的废料：{ id, cell, metal, electronics }
var ark_position := Vector3.INF    # ARK-01 上次停在哪；进小镇时接着从那里开始

var _ruin_cells := {}      # 格子 -> 废墟 id
var _building_cells := {}  # 格子 -> 建筑编号
var _next_uid := 1
var _energy_output := 0
var _energy_used := 0
var _water_output := 0
var _water_used := 0
var _power_sources: Array[Dictionary] = []
var _wet := {}


func _init() -> void:
	grid_width = int(DataDB.balance("earth_grid_width"))
	grid_height = int(DataDB.balance("earth_grid_height"))
	for id: String in DataDB.table("earth_props"):
		props[id] = str(DataDB.row("earth_props", id)["default_state"])
	for id: String in DataDB.table("earth_zones"):
		var zone := DataDB.row("earth_zones", id)
		for cell in _rect_cells(int(zone["x"]), int(zone["z"]), int(zone["w"]), int(zone["h"])):
			pollution[cell] = int(zone["level"])
	for id: String in DataDB.table("earth_ruins"):
		var row := DataDB.row("earth_ruins", id)
		ruins[id] = {
			"id": id, "kind": row["kind"], "x": int(row["x"]), "z": int(row["z"]),
			"w": int(row["w"]), "h": int(row["h"]), "work_units": int(row["work_units"]),
			"metal": int(row["metal"]), "electronics": int(row["electronics"]), "cleared": false,
		}
		for cell in _rect_cells(int(row["x"]), int(row["z"]), int(row["w"]), int(row["h"])):
			_ruin_cells[cell] = id


# ---------- 查询 ----------

func building_at(cell: Vector2i) -> int:
	return _building_cells.get(cell, 0)


func ruin_at(cell: Vector2i) -> String:
	return _ruin_cells.get(cell, "")


## 格子上有没有东西（废墟、建筑、实心的剧情物件）
func is_blocked(cell: Vector2i) -> bool:
	return _ruin_cells.has(cell) or _building_cells.has(cell) or not prop_at(cell, true).is_empty()


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < grid_width and cell.y < grid_height


## 能不能走：区域开放、没有东西挡着；干河道只有桥能过
func is_walkable(cell: Vector2i) -> bool:
	if not in_bounds(cell) or not is_region_open(region_of(cell)) or is_blocked(cell):
		return false
	if region_of(cell) == RIVER:
		return _prop_rect(BRIDGE).has_point(cell) and props[BRIDGE] != "broken"
	return true


func region_of(cell: Vector2i) -> String:
	for id: String in DataDB.table("earth_regions"):
		var row := DataDB.row("earth_regions", id)
		if cell.y >= int(row["z_from"]) and cell.y <= int(row["z_to"]):
			return id
	return ""


func is_region_open(region: String) -> bool:
	var flag := str(DataDB.row("earth_regions", region).get("open_flag", ""))
	return flag.is_empty() or GameState.flags.get(flag, false)


func open_regions() -> Array[String]:
	var result: Array[String] = []
	for id: String in DataDB.table("earth_regions"):
		if is_region_open(id) and int(DataDB.row("earth_regions", id)["buildable"]) == 1:
			result.append(id)
	return result


## 在不在通信范围内：A 区本来就能操作，其他区域要在通信中继范围里（比赛版 4.4 第三类约束）
func is_cell_covered(cell: Vector2i) -> bool:
	if int(DataDB.row("earth_regions", region_of(cell)).get("comm_free", 0)) == 1:
		return true
	for building: Dictionary in buildings.values():
		var radius := float(_row(building["type"])["comm_radius"])
		if building["done"] and radius > 0.0 and Vector2(cell).distance_to(_center(building)) <= radius:
			return true
	return false


## 格子上的剧情物件 id；solid_only 时只算当前状态挡路的
func prop_at(cell: Vector2i, solid_only := false) -> String:
	for id: String in props:
		if not _prop_rect(id).has_point(cell):
			continue
		if solid_only and not str(DataDB.row("earth_props", id)["solid_states"]).split("|").has(props[id]):
			continue
		return id
	return ""


func prop_rect(id: String) -> Rect2i:
	return _prop_rect(id)


func energy_output() -> int:
	return _energy_output


func energy_used() -> int:
	return _energy_used


func water_output() -> int:
	return _water_output


func water_used() -> int:
	return _water_used


## 本周总工作单位 = 基础 + 已建好建筑的加成
func work_units_total() -> int:
	var total := int(DataDB.balance("work_units_per_week"))
	for building: Dictionary in buildings.values():
		if building["done"]:
			total += int(_row(building["type"])["bonus_work_units"])
	return total


## 按队列顺序把本周的工作单位分给每个任务。返回和 queue 一一对应的数组。
func allocation() -> Array[int]:
	var left := work_units_total()
	var result: Array[int] = []
	for job in queue:
		var used := mini(left, int(job["total"]) - int(job["done"]))
		result.append(used)
		left -= used
	return result


func work_units_left() -> int:
	var left := work_units_total()
	for used in allocation():
		left -= used
	return left


func robot_count() -> int:
	var count := int(DataDB.balance("earth_start_robots"))
	for building: Dictionary in buildings.values():
		if building["done"] and int(_row(building["type"])["bonus_work_units"]) > 0:
			count += 1
	return count


## 这一格在不在供电范围内 / 有没有水，画面用来显示覆盖范围
func is_cell_powered(cell: Vector2i) -> bool:
	for source in _power_sources:
		var radius := float(_row(source["type"])["power_radius"])
		if Vector2(cell).distance_to(_center(source)) <= radius:
			return true
	return false


func is_cell_wet(cell: Vector2i) -> bool:
	return _wet.has(cell)


## 建筑现在有什么问题：缺电 / 缺水 / 土壤污染
func problems(uid: int) -> Array[String]:
	var result: Array[String] = []
	var building: Dictionary = buildings[uid]
	if not building["done"]:
		return result
	var row := _row(building["type"])
	if int(row["needs_power"]) == 1 and not building["powered"]:
		result.append(POWER_PROBLEM)
	if int(row["needs_water"]) == 1 and not building["watered"]:
		result.append(WATER_PROBLEM)
	if building["type"] == FARM and _max_pollution(building) > int(DataDB.balance("earth_plant_max_pollution")):
		result.append(SOIL_PROBLEM)
	if building.get("broken", false):
		result.append(BROKEN_PROBLEM)
	return result


## 四项恢复度，都是 0～100 的整数。region 为空时算全部已开放区域。
func recovery(region := "") -> Dictionary:
	var ruin_total := 0
	var ruin_done := 0
	var plant_count := 0
	var cell_total := 0
	for id in open_regions():
		if region.is_empty() or region == id:
			var row := DataDB.row("earth_regions", id)
			cell_total += grid_width * (int(row["z_to"]) - int(row["z_from"]) + 1)
	for cell: Vector2i in plants:
		if region.is_empty() or region_of(cell) == region:
			plant_count += 1
	for ruin: Dictionary in ruins.values():
		if not _in_region(Vector2i(int(ruin["x"]), int(ruin["z"])), region):
			continue
		var area: int = int(ruin["w"]) * int(ruin["h"])
		ruin_total += area
		if ruin["cleared"]:
			ruin_done += area
	var power_total := 0
	var power_done := 0
	var water_total := 0
	var water_done := 0
	for building: Dictionary in buildings.values():
		if not building["done"] or not _in_region(Vector2i(int(building["x"]), int(building["z"])), region):
			continue
		var row := _row(building["type"])
		if int(row["needs_power"]) == 1:
			power_total += 1
			power_done += 1 if building["powered"] else 0
		if int(row["needs_water"]) == 1:
			water_total += 1
			water_done += 1 if building["watered"] else 0
	return {
		"ruins": _percent(ruin_done, ruin_total),
		"power": _percent(power_done, power_total),
		"water": _percent(water_done, water_total),
		"plants": _percent(plant_count, cell_total),
	}


# ---------- 建造 ----------

## 还没解锁的原因（剧情或技能）；已解锁返回空字典。建造菜单用它标出差多少。
func unlock_reason(type: String) -> Dictionary:
	var row := _row(type)
	if not str(row["unlock_story"]).is_empty() and not GameState.flags.get(row["unlock_story"], false):
		return {"key": "UI-13-07", "values": {}}
	for column: String in SKILL_COLUMNS:
		var need := int(row[column])
		var skill: String = SKILL_COLUMNS[column]
		if GameState.get_stat(skill) < need:
			return {"key": "UI-13-04", "values": {"skill": UiKit.stat_name(skill), "need": need, "now": GameState.get_stat(skill)}}
	return {}


## 能不能建。能建返回空字典；不能建返回 {key, values}，界面用它显示原因。
func can_place(type: String, x: int, z: int) -> Dictionary:
	var row := _row(type)
	var locked := unlock_reason(type)
	if not locked.is_empty():
		return locked
	if row["placement"] == "fixed" and (x != int(row["fixed_x"]) or z != int(row["fixed_z"])):
		return {"key": "UI-13-06", "values": {}}
	for cell in _rect_cells(x, z, int(row["size_x"]), int(row["size_z"])):
		if not in_bounds(cell):
			return {"key": "UI-13-01", "values": {}}
		if not is_region_open(region_of(cell)):
			return {"key": "UI-13-08", "values": {}}
		if int(DataDB.row("earth_regions", region_of(cell))["buildable"]) != 1:
			return {"key": "UI-13-09", "values": {}}
		if type != RELAY and not is_cell_covered(cell):
			return {"key": "UI-13-10", "values": {}}
		if is_blocked(cell):
			return {"key": "UI-13-02", "values": {}}
		if type == FARM and int(pollution.get(cell, 0)) > int(DataDB.balance("earth_plant_max_pollution")):
			return {"key": "UI-13-03", "values": {}}
	if metal < int(row["metal"]):
		return {"key": "UI-13-05", "values": {"material": Text.t("UI-14-01"), "count": int(row["metal"]) - metal}}
	if electronics < int(row["electronics"]):
		return {"key": "UI-13-05", "values": {"material": Text.t("UI-14-02"), "count": int(row["electronics"]) - electronics}}
	return {}


## 放蓝图：材料当场扣；不需要工作单位的（水管、供电节点）马上建好。返回建筑编号，失败返回 0。
func place(type: String, x: int, z: int) -> int:
	if not can_place(type, x, z).is_empty():
		return 0
	var row := _row(type)
	metal -= int(row["metal"])
	electronics -= int(row["electronics"])
	var uid := _next_uid
	_next_uid += 1
	var work := int(row["work_units"])
	buildings[uid] = {
		"uid": uid, "type": type, "x": x, "z": z,
		"w": int(row["size_x"]), "h": int(row["size_z"]),
		"done": work == 0, "powered": false, "watered": false,
	}
	for cell in _rect_cells(x, z, int(row["size_x"]), int(row["size_z"])):
		_building_cells[cell] = uid
		plants.erase(cell)
	if work > 0:
		queue.append({"kind": JOB_BUILD, "ref": uid, "total": work, "done": 0})
	else:
		week_counts["built"] += 1
	_recompute_networks()
	changed.emit()
	return uid


## 取消蓝图：退回材料和已投入的进度都作废
func cancel_blueprint(uid: int) -> void:
	var building: Dictionary = buildings[uid]
	if building["done"]:
		return
	var row := _row(building["type"])
	metal += int(row["metal"])
	electronics += int(row["electronics"])
	_remove_building(uid)


## 拆除建好的建筑：不退材料
func demolish(uid: int) -> void:
	if buildings[uid]["done"]:
		_remove_building(uid)


func queue_clear(ruin_id: String) -> void:
	var ruin: Dictionary = ruins[ruin_id]
	if ruin["cleared"] or ruin["kind"] != RUIN_BIG or is_ruin_queued(ruin_id):
		return
	queue.append({"kind": JOB_CLEAR, "ref": ruin_id, "total": int(ruin["work_units"]), "done": 0})
	changed.emit()


func cancel_clear(ruin_id: String) -> void:
	for job in queue:
		if job["kind"] == JOB_CLEAR and job["ref"] == ruin_id:
			queue.erase(job)
			changed.emit()
			return


func is_ruin_queued(ruin_id: String) -> bool:
	for job in queue:
		if job["kind"] == JOB_CLEAR and job["ref"] == ruin_id:
			return true
	return false


# ---------- ARK-01 现场操作（不消耗工作单位）----------

## 用切割头拆小废料：废料掉在原地，要捡起来才算资源。返回掉落物，拆不了返回空字典。
func cut_small(ruin_id: String) -> Dictionary:
	var ruin: Dictionary = ruins.get(ruin_id, {})
	if ruin.is_empty() or ruin["cleared"] or ruin["kind"] == RUIN_BIG:
		return {}
	_clear_ruin(ruin)
	var drop := {
		"id": ruin_id, "cell": Vector2i(int(ruin["x"]), int(ruin["z"])),
		"metal": int(ruin["metal"]), "electronics": int(ruin["electronics"]),
	}
	scraps.append(drop)
	changed.emit()
	return drop


func pick_up(scrap_id: String) -> Dictionary:
	for scrap in scraps:
		if scrap["id"] == scrap_id:
			scraps.erase(scrap)
			metal += int(scrap["metal"])
			electronics += int(scrap["electronics"])
			changed.emit()
			return scrap
	return {}


# ---------- 周结算 ----------

## 点"结束本周"时统一结算（比赛版 4.4）。返回本周报告，周结算页用。
func end_week() -> Dictionary:
	var before_metal := metal
	var before_electronics := electronics
	var finished: Array[String] = []

	# 先算施工：工作单位按队列分配，没做完的留到下周
	var plan := allocation()
	var remaining: Array[Dictionary] = []
	for i in queue.size():
		var job := queue[i]
		job["done"] = int(job["done"]) + plan[i]
		if int(job["done"]) >= int(job["total"]):
			finished.append(_finish_job(job))
		else:
			remaining.append(job)
	queue = remaining
	_recompute_networks()

	# 再算设施产出：刚建好的这周就开始工作
	for building: Dictionary in buildings.values():
		if not building["done"]:
			continue
		var row := _row(building["type"])
		metal += int(row["metal_output"])
		if int(row["cleanse_radius"]) > 0 and building["powered"]:
			_cleanse(building, int(row["cleanse_radius"]))
	_grow_plants()
	_recompute_networks()
	var traits := _trait_gains()
	week_counts = {"built": 0, "planted": 0, "clues": 0}
	var by_region := {}
	for region in open_regions():
		by_region[region] = recovery(region)
	changed.emit()
	return {
		"finished": finished,
		"metal": metal - before_metal,
		"electronics": electronics - before_electronics,
		"recovery": recovery(),
		"regions": by_region,
		"traits": traits,
	}


# ---------- 剧情物件、特殊施工、线索（ARK-01 和剧情模块用）----------

## 剧情直接改物件状态，比如第 5 周材料堆变矮、搭临时便桥
func set_prop_state(id: String, state: String) -> void:
	props[id] = state
	if id == BRIDGE and state != "broken":
		GameState.flags[BRIDGE_FLAG] = true
	_recompute_networks()
	changed.emit()


## 特殊施工能不能做：返回空字典表示能做，否则是 {key, values}
func special_reason(id: String) -> Dictionary:
	var row := DataDB.row("earth_specials", id)
	var skill := str(row["skill"])
	var need := int(row["need"])
	if GameState.get_stat(skill) < need:
		return {"key": "UI-13-04", "values": {"skill": UiKit.stat_name(skill), "need": need, "now": GameState.get_stat(skill)}}
	return {}


func is_special_done(id: String) -> bool:
	return GameState.flags.get(str(DataDB.row("earth_specials", id)["flag"]), false)


## 做特殊施工（比赛版 4.4：自动机器人做不了、必须她在现场完成的事）。
## 体力低时可能失败（4.4"她怎样影响建造"）。返回 { ok, key, values }。
func try_special(id: String, rng: RandomNumberGenerator) -> Dictionary:
	if is_special_done(id):
		return {"ok": false, "key": "", "values": {}}
	var reason := special_reason(id)
	if not reason.is_empty():
		return {"ok": false, "key": reason["key"], "values": reason["values"]}
	if GameState.get_stat("stamina") < int(DataDB.balance("low_stamina")) and rng.randf() < float(DataDB.balance("ark_tired_fail_chance")):
		return {"ok": false, "key": "UI-18-12", "values": {}}
	var row := DataDB.row("earth_specials", id)
	GameState.flags[str(row["flag"])] = true
	if not str(row["prop"]).is_empty():
		props[str(row["prop"])] = str(row["state_after"])
	week_counts["built"] += 1
	_recompute_networks()
	changed.emit()
	return {"ok": true, "key": "", "values": {}}


## 现在场上能看到的线索（剧情没开始的不显示）
func active_clues() -> Array[String]:
	var result: Array[String] = []
	for id: String in DataDB.table("earth_clues"):
		var flag := str(DataDB.row("earth_clues", id)["needs_flag"])
		if not found_clues.has(id) and (flag.is_empty() or GameState.flags.get(flag, false)) and is_region_open(str(DataDB.row("earth_clues", id)["region"])):
			result.append(id)
	return result


func discover_clue(id: String) -> void:
	if found_clues.has(id):
		return
	found_clues[id] = true
	GameState.flags["clue_" + id] = true
	week_counts["clues"] += 1
	changed.emit()


func clue_cell(id: String) -> Vector2i:
	var row := DataDB.row("earth_clues", id)
	return Vector2i(int(row["x"]), int(row["z"]))


## 用喷洒头种一株植物；种不了返回 false
func hand_plant(cell: Vector2i, type := HAND_PLANT) -> bool:
	if not is_walkable(cell) or plants.has(cell) or int(pollution.get(cell, 2)) > int(DataDB.balance("earth_plant_max_pollution")):
		return false
	plants[cell] = {"type": type, "age": 0}
	holes.erase(cell)
	week_counts["planted"] += 1
	changed.emit()
	return true


## 剧情用：植物被挖走，留下坑
func dig_up(cells: Array[Vector2i]) -> void:
	for cell in cells:
		if plants.erase(cell):
			holes[cell] = true
	changed.emit()


## 设备停运（突发事件用）：坏了的建筑不工作，要用焊接头修
func break_building(uid: int) -> void:
	if buildings.has(uid):
		buildings[uid]["broken"] = true
		_recompute_networks()
		changed.emit()


func repair_building(uid: int) -> bool:
	if not buildings.has(uid) or not buildings[uid].get("broken", false):
		return false
	buildings[uid]["broken"] = false
	_recompute_networks()
	changed.emit()
	return true


func plant_grown(cell: Vector2i) -> bool:
	var plant: Dictionary = plants.get(cell, {})
	return not plant.is_empty() and int(plant["age"]) >= int(DataDB.row("plants", plant["type"])["grow_weeks"])


# ---------- 内部 ----------

func _finish_job(job: Dictionary) -> String:
	if job["kind"] == JOB_CLEAR:
		var ruin: Dictionary = ruins[job["ref"]]
		_clear_ruin(ruin)
		metal += int(ruin["metal"])
		electronics += int(ruin["electronics"])
		return Text.t("UI-19-01")
	var building: Dictionary = buildings[job["ref"]]
	building["done"] = true
	week_counts["built"] += 1
	if building["type"] == GREENHOUSE:
		props["greenhouse_ruin"] = "fixed"
	return Text.t(_row(building["type"])["name_key"])


func _clear_ruin(ruin: Dictionary) -> void:
	ruin["cleared"] = true
	var drop := int(DataDB.balance("earth_clear_pollution_drop"))
	for cell in _rect_cells(int(ruin["x"]), int(ruin["z"]), int(ruin["w"]), int(ruin["h"])):
		_ruin_cells.erase(cell)
		pollution[cell] = maxi(0, int(pollution.get(cell, 0)) - drop)


func _remove_building(uid: int) -> void:
	for job in queue:
		if job["kind"] == JOB_BUILD and job["ref"] == uid:
			queue.erase(job)
			break
	var building: Dictionary = buildings[uid]
	for cell in _rect_cells(int(building["x"]), int(building["z"]), int(building["w"]), int(building["h"])):
		_building_cells.erase(cell)
	buildings.erase(uid)
	_recompute_networks()
	changed.emit()


## 算谁通电、谁有水。能源和清洁水是每周产量，不够时按建造顺序先到先得。
func _recompute_networks() -> void:
	var sorted: Array = buildings.keys()
	sorted.sort()

	# 通电：发电设备是源头；供电节点在已通电范围内才会继续往外传
	var sources: Array[Dictionary] = []
	_energy_output = 0
	for uid: int in sorted:
		var building: Dictionary = buildings[uid]
		building["powered"] = false
		building["watered"] = false
		if building["done"] and not building.get("broken", false) and building["type"] == GENERATOR:
			sources.append(building)
			_energy_output += int(_row(GENERATOR)["energy_output"])
	var grew := true
	while grew:
		grew = false
		for uid: int in sorted:
			var building: Dictionary = buildings[uid]
			if building["done"] and building["type"] == NODE_ID and not sources.has(building) and _in_power_range(building, sources):
				sources.append(building)
				grew = true

	_power_sources = sources
	_energy_used = 0
	for uid: int in sorted:
		var building: Dictionary = buildings[uid]
		var row := _row(building["type"])
		if not building["done"] or building.get("broken", false) or int(row["needs_power"]) != 1:
			continue
		var use := int(row["energy_use"])
		if _in_power_range(building, sources) and _energy_used + use <= _energy_output:
			building["powered"] = true
			_energy_used += use

	# 有水：通电的净水站出水，水管一段接一段传，碰到净水站或水管的建筑才有水
	var wet := {}
	var frontier: Array[Vector2i] = []
	_water_output = 0
	for uid: int in sorted:
		var building: Dictionary = buildings[uid]
		if building["done"] and building["type"] == PURIFIER and building["powered"]:
			_water_output += int(_row(PURIFIER)["water_output"])
			for cell in _rect_cells(int(building["x"]), int(building["z"]), int(building["w"]), int(building["h"])):
				wet[cell] = true
				frontier.append(cell)
	while not frontier.is_empty():
		var cell: Vector2i = frontier.pop_back()
		for next in _neighbors(cell):
			if wet.has(next):
				continue
			var uid: int = _building_cells.get(next, 0)
			if uid != 0 and buildings[uid]["done"] and buildings[uid]["type"] == PIPE:
				wet[next] = true
				frontier.append(next)

	_wet = wet
	_water_used = 0
	for uid: int in sorted:
		var building: Dictionary = buildings[uid]
		var row := _row(building["type"])
		if not building["done"] or building.get("broken", false) or int(row["needs_water"]) != 1:
			continue
		var use := int(row["water_use"])
		if _touches_wet(building, wet) and _water_used + use <= _water_output:
			building["watered"] = true
			_water_used += use

	# 大门：通了电，或者修好了旧备用电源，就打开（比赛版 4.4 地图）
	if not GameState.flags.get(GATE_FLAG, false):
		var gate_powered := false
		for cell in _rect_cells(_prop_rect(GATE).position.x, _prop_rect(GATE).position.y, _prop_rect(GATE).size.x, _prop_rect(GATE).size.y):
			if is_cell_powered(cell):
				gate_powered = true
		if gate_powered or GameState.flags.get(OLD_POWER_FLAG, false):
			GameState.flags[GATE_FLAG] = true
	if GameState.flags.get(GATE_FLAG, false):
		props[GATE] = "open"
	if GameState.flags.get(BRIDGE_TEMP_FLAG, false) and props[BRIDGE] == "broken":
		props[BRIDGE] = "temp"
		GameState.flags[BRIDGE_FLAG] = true


func _in_power_range(building: Dictionary, sources: Array[Dictionary]) -> bool:
	var center := _center(building)
	for source in sources:
		if source == building:
			continue
		var radius := float(_row(source["type"])["power_radius"])
		if center.distance_to(_center(source)) <= radius:
			return true
	return false


func _touches_wet(building: Dictionary, wet: Dictionary) -> bool:
	for cell in _rect_cells(int(building["x"]), int(building["z"]), int(building["w"]), int(building["h"])):
		for next in _neighbors(cell):
			if wet.has(next):
				return true
	return false


func _cleanse(building: Dictionary, radius: int) -> void:
	var center := _center(building)
	for cell: Vector2i in pollution:
		if int(pollution[cell]) > 0 and Vector2(cell).distance_to(center) <= radius:
			pollution[cell] = int(pollution[cell]) - 1


## 有水的种植区长满自己的地并向外扩散；离开有水的种植区范围的植物慢慢枯死
func _grow_plants() -> void:
	var max_pollution := int(DataDB.balance("earth_plant_max_pollution"))
	var radius := float(DataDB.balance("earth_farm_spread_radius"))
	var spread := int(DataDB.balance("earth_farm_spread_per_week"))
	var alive := {}
	for building: Dictionary in buildings.values():
		if building["type"] != FARM or not building["watered"] or not problems(building["uid"]).is_empty():
			continue
		var center := _center(building)
		for cell in _rect_cells(int(building["x"]), int(building["z"]), int(building["w"]), int(building["h"])):
			alive[cell] = plants.get(cell, {"type": FARM_PLANT, "age": -1})
		var candidates: Array[Vector2i] = []
		for x in range(int(center.x - radius), int(center.x + radius) + 1):
			for z in range(int(center.y - radius), int(center.y + radius) + 1):
				var cell := Vector2i(x, z)
				if not pollution.has(cell) or Vector2(cell).distance_to(center) > radius:
					continue
				if plants.has(cell):
					alive[cell] = plants[cell]
				elif is_walkable(cell) and not holes.has(cell) and int(pollution[cell]) <= max_pollution:
					candidates.append(cell)
		# 从近到远扩散，结果固定，方便玩家理解也方便测试
		candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return Vector2(a).distance_squared_to(center) < Vector2(b).distance_squared_to(center))
		for cell in candidates.slice(0, spread):
			alive[cell] = {"type": FARM_PLANT, "age": -1}
	var withered := 0
	var wither_limit := int(DataDB.balance("earth_plant_wither_per_week"))
	for cell: Vector2i in plants:
		if not alive.has(cell) and withered < wither_limit:
			withered += 1
		elif not alive.has(cell):
			alive[cell] = plants[cell]
	# 每活过一周长大一点；新长出来的从 0 开始
	for cell: Vector2i in alive:
		var plant: Dictionary = alive[cell].duplicate()
		plant["age"] = int(plant["age"]) + 1
		alive[cell] = plant
	plants = alive


## 地球反过来影响养成（比赛版 4.4）：每周按次数加，封顶
func _trait_gains() -> Dictionary:
	var cap := int(DataDB.balance("earth_trait_weekly_cap"))
	var per := {"built": "earth_trait_from_build", "planted": "earth_trait_from_plant", "clues": "earth_trait_from_clue"}
	var gains := {}
	for key: String in TRAIT_STATS:
		var amount := mini(int(week_counts[key]) * int(DataDB.balance(per[key])), cap)
		if amount > 0:
			gains[TRAIT_STATS[key]] = amount
	return gains


func _prop_rect(id: String) -> Rect2i:
	var row := DataDB.row("earth_props", id)
	return Rect2i(int(row["x"]), int(row["z"]), int(row["w"]), int(row["h"]))


func _in_region(cell: Vector2i, region: String) -> bool:
	return region.is_empty() or region_of(cell) == region


func _max_pollution(building: Dictionary) -> int:
	var highest := 0
	for cell in _rect_cells(int(building["x"]), int(building["z"]), int(building["w"]), int(building["h"])):
		highest = maxi(highest, int(pollution.get(cell, 0)))
	return highest


func _center(building: Dictionary) -> Vector2:
	return Vector2(int(building["x"]) + (int(building["w"]) - 1) / 2.0, int(building["z"]) + (int(building["h"]) - 1) / 2.0)


func _neighbors(cell: Vector2i) -> Array[Vector2i]:
	return [cell + Vector2i.LEFT, cell + Vector2i.RIGHT, cell + Vector2i.UP, cell + Vector2i.DOWN]


func _rect_cells(x: int, z: int, w: int, h: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for i in w:
		for j in h:
			cells.append(Vector2i(x + i, z + j))
	return cells


func _row(type: String) -> Dictionary:
	return DataDB.row("buildings", type)


func _percent(part: int, whole: int) -> int:
	return 0 if whole == 0 else part * 100 / whole
