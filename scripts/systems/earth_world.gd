class_name EarthWorld
extends RefCounted
## 地球的规则（比赛版 4.4）：土地、建筑、施工队列、水电网络、恢复度、周结算。
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

var grid_size: int
var metal := 0
var electronics := 0
var pollution := {}     # 格子 -> 污染等级（2 重度 1 轻度 0 无）
var ruins := {}         # 废墟 id -> { id, kind, x, z, w, h, work_units, metal, electronics, cleared }
var buildings := {}     # 建筑编号 -> { uid, type, x, z, w, h, done, powered, watered }
var queue: Array[Dictionary] = []  # 施工队列：{ kind, ref, total, done }
var plants := {}        # 格子 -> true
var scraps: Array[Dictionary] = [] # 拆下来还没捡的废料：{ id, cell, metal, electronics }

var _ruin_cells := {}      # 格子 -> 废墟 id
var _building_cells := {}  # 格子 -> 建筑编号
var _next_uid := 1
var _energy_output := 0
var _energy_used := 0
var _water_output := 0
var _water_used := 0


func _init() -> void:
	grid_size = int(DataDB.balance("earth_grid_size"))
	for id: String in DataDB.table("earth_zones_a"):
		var zone := DataDB.row("earth_zones_a", id)
		for cell in _rect_cells(int(zone["x"]), int(zone["z"]), int(zone["w"]), int(zone["h"])):
			pollution[cell] = int(zone["level"])
	for id: String in DataDB.table("earth_ruins_a"):
		var row := DataDB.row("earth_ruins_a", id)
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


func is_blocked(cell: Vector2i) -> bool:
	return _ruin_cells.has(cell) or _building_cells.has(cell)


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
	return result


## 四项恢复度，都是 0～100 的整数
func recovery() -> Dictionary:
	var ruin_total := 0
	var ruin_done := 0
	for ruin: Dictionary in ruins.values():
		var area: int = int(ruin["w"]) * int(ruin["h"])
		ruin_total += area
		if ruin["cleared"]:
			ruin_done += area
	var power_total := 0
	var power_done := 0
	var water_total := 0
	var water_done := 0
	for building: Dictionary in buildings.values():
		if not building["done"]:
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
		"plants": _percent(plants.size(), grid_size * grid_size),
	}


# ---------- 建造 ----------

## 能不能建。能建返回空字典；不能建返回 {key, values}，界面用它显示原因。
func can_place(type: String, x: int, z: int) -> Dictionary:
	var row := _row(type)
	if not str(row["unlock_story"]).is_empty() and not GameState.flags.get(row["unlock_story"], false):
		return {"key": "UI-13-07", "values": {}}
	for column: String in SKILL_COLUMNS:
		var need := int(row[column])
		var skill: String = SKILL_COLUMNS[column]
		if GameState.get_stat(skill) < need:
			return {"key": "UI-13-04", "values": {"skill": UiKit.stat_name(skill), "need": need, "now": GameState.get_stat(skill)}}
	if row["placement"] == "fixed" and (x != int(row["fixed_x"]) or z != int(row["fixed_z"])):
		return {"key": "UI-13-06", "values": {}}
	for cell in _rect_cells(x, z, int(row["size_x"]), int(row["size_z"])):
		if cell.x < 0 or cell.y < 0 or cell.x >= grid_size or cell.y >= grid_size:
			return {"key": "UI-13-01", "values": {}}
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
	changed.emit()
	return {
		"finished": finished,
		"metal": metal - before_metal,
		"electronics": electronics - before_electronics,
		"recovery": recovery(),
	}


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
		if building["done"] and building["type"] == GENERATOR:
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

	_energy_used = 0
	for uid: int in sorted:
		var building: Dictionary = buildings[uid]
		var row := _row(building["type"])
		if not building["done"] or int(row["needs_power"]) != 1:
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

	_water_used = 0
	for uid: int in sorted:
		var building: Dictionary = buildings[uid]
		var row := _row(building["type"])
		if not building["done"] or int(row["needs_water"]) != 1:
			continue
		var use := int(row["water_use"])
		if _touches_wet(building, wet) and _water_used + use <= _water_output:
			building["watered"] = true
			_water_used += use


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
			alive[cell] = true
		var candidates: Array[Vector2i] = []
		for x in range(int(center.x - radius), int(center.x + radius) + 1):
			for z in range(int(center.y - radius), int(center.y + radius) + 1):
				var cell := Vector2i(x, z)
				if not pollution.has(cell) or Vector2(cell).distance_to(center) > radius:
					continue
				if plants.has(cell):
					alive[cell] = true
				elif not is_blocked(cell) and int(pollution[cell]) <= max_pollution:
					candidates.append(cell)
		# 从近到远扩散，结果固定，方便玩家理解也方便测试
		candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return Vector2(a).distance_squared_to(center) < Vector2(b).distance_squared_to(center))
		for cell in candidates.slice(0, spread):
			alive[cell] = true
	var withered := 0
	var wither_limit := int(DataDB.balance("earth_plant_wither_per_week"))
	for cell: Vector2i in plants:
		if not alive.has(cell) and withered < wither_limit:
			withered += 1
		else:
			alive[cell] = true
	plants = alive


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
