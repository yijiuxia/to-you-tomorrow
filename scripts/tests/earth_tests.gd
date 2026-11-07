extends Node
## 地球规则的自动测试。运行方法：
## Godot_console.exe --headless --path . res://scenes/tests/earth_tests.tscn
## 全部通过时退出码是 0。

var _failures := 0
var _count := 0


func _ready() -> void:
	test_start_state()
	test_place_pays_materials_and_queues()
	test_place_blocked_reasons()
	test_skill_gate()
	test_work_units_and_cross_week()
	test_clear_ruin_gives_materials_and_lowers_pollution()
	test_cut_and_pickup()
	test_power_range_and_nodes()
	test_energy_budget()
	test_water_chain()
	test_farm_grows_spreads_and_withers()
	test_recycler_income()
	test_repair_station_bonus()
	test_cancel_and_demolish()
	test_recovery_values()
	print("地球测试 %d 项，失败 %d 项" % [_count, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func test_start_state() -> void:
	var w := _world()
	_eq(w.work_units_total(), 6, "每周 6 个工作单位")
	_eq(w.work_units_left(), 6, "开局没有任务")
	_eq(w.robot_count(), 2, "2 台机器人")
	_true(w.is_blocked(Vector2i(9, 4)), "广场废墟占着地")
	_true(not w.is_blocked(Vector2i(0, 0)), "空地可用")
	_eq(w.pollution[Vector2i(0, 0)], 2, "默认重度污染")
	_eq(w.pollution[Vector2i(4, 8)], 1, "维修站附近轻度污染")


func test_place_pays_materials_and_queues() -> void:
	var w := _world()
	w.metal = 5
	var uid := w.place("recycler", 0, 0)
	_true(uid != 0, "能放回收站")
	_eq(w.metal, 2, "材料当场扣")
	_eq(w.queue.size(), 1, "进施工队列")
	_eq(w.work_units_left(), 4, "占 2 个工作单位")
	_eq(w.buildings[uid]["done"], false, "还没建好")
	_true(w.is_blocked(Vector2i(1, 0)), "占地 2×1")
	_true(not w.is_blocked(Vector2i(0, 1)), "占地不多占")


func test_place_blocked_reasons() -> void:
	var w := _world()
	_eq(w.can_place("recycler", 0, 0).get("key"), "UI-13-05", "缺材料")
	w.metal = 100
	_eq(w.can_place("recycler", 29, 0).get("key"), "UI-13-01", "超界")
	_eq(w.can_place("recycler", 9, 4).get("key"), "UI-13-02", "和废墟重叠")
	_eq(w.can_place("farm_plot", 0, 0).get("key"), "UI-13-03", "重度污染不能种")
	_true(w.can_place("farm_plot", 4, 7).is_empty(), "轻度污染能种")
	GameState.change_stat("mechanics", 10)
	w.electronics = 100
	_eq(w.can_place("repair_station", 0, 0).get("key"), "UI-13-06", "固定建筑不能乱放")
	_true(w.can_place("repair_station", 4, 4).is_empty(), "固定位置能放")
	_eq(w.can_place("greenhouse", -1, -1).get("key"), "UI-13-07", "温室要等剧情")


func test_skill_gate() -> void:
	var w := _world()
	w.metal = 100
	w.electronics = 100
	var reason := w.can_place("generator", 0, 0)
	_eq(reason.get("key"), "UI-13-04", "发电设备缺技能")
	_eq(reason["values"]["need"], 45, "要机械 45")
	_eq(reason["values"]["now"], 0, "现在 0")
	GameState.change_stat("mechanics", 45)
	_true(w.can_place("generator", 0, 0).is_empty(), "技能够了能建")


func test_work_units_and_cross_week() -> void:
	var w := _rich_world()
	var first := w.place("recycler", 0, 0)   # 2 单位
	var second := w.place("generator", 0, 2) # 4 单位
	var third := w.place("recycler", 0, 5)   # 2 单位，本周排不上
	_eq(w.work_units_left(), 0, "6 个单位用完")
	_eq(w.allocation(), [2, 4, 0], "按队列顺序分配")
	var report := w.end_week()
	_eq(report["finished"].size(), 2, "前两个完成")
	_true(w.buildings[first]["done"] and w.buildings[second]["done"], "建好了")
	_eq(w.buildings[third]["done"], false, "第三个留到下周")
	_eq(w.queue.size(), 1, "队列留一个")
	w.end_week()
	_true(w.buildings[third]["done"], "下周建好")

	# 跨周任务：大建筑一周做不完
	var v := _rich_world()
	GameState.flags["week6"] = true
	var job := {"kind": EarthWorld.JOB_BUILD, "ref": v.place("recycler", 0, 0), "total": 8, "done": 0}
	v.queue[0] = job
	v.end_week()
	_eq(v.queue[0]["done"], 6, "第一周投 6")
	_eq(v.work_units_left(), 4, "第二周还需要 2")
	v.end_week()
	_true(v.queue.is_empty(), "第二周做完")
	GameState.flags.clear()


func test_clear_ruin_gives_materials_and_lowers_pollution() -> void:
	var w := _world()
	w.queue_clear("plaza")
	w.queue_clear("plaza")
	_eq(w.queue.size(), 1, "不重复排队")
	_eq(w.work_units_left(), 4, "清理占 2 单位")
	var report := w.end_week()
	_eq(w.metal, 4, "清理得金属 4")
	_eq(w.electronics, 1, "清理得电子 1")
	_eq(report["metal"], 4, "报告里有金属")
	_true(w.ruins["plaza"]["cleared"], "废墟清掉了")
	_true(not w.is_blocked(Vector2i(9, 4)), "地空出来了")
	_eq(w.pollution[Vector2i(9, 4)], 0, "污染降一级")
	w = _world()
	w.queue_clear("scrap1")
	_true(w.queue.is_empty(), "小废料不能排机器人")


func test_cut_and_pickup() -> void:
	var w := _world()
	_true(w.cut_small("plaza").is_empty(), "大废墟拆不了")
	var drop := w.cut_small("scrap3")
	_eq(drop["metal"], 1, "掉金属")
	_eq(w.metal, 0, "捡起来才算")
	_eq(w.work_units_left(), 6, "不消耗工作单位")
	_true(w.cut_small("scrap3").is_empty(), "不能拆两次")
	w.pick_up("scrap3")
	_eq(w.metal, 1, "捡到金属")
	_eq(w.electronics, 1, "第 3 块多给电子")
	_true(w.pick_up("scrap3").is_empty(), "不能捡两次")


func test_power_range_and_nodes() -> void:
	var w := _rich_world()
	_built(w, "generator", 0, 25)
	var near := _built(w, "soil_improver", 5, 26)
	var far := _built(w, "soil_improver", 12, 26)
	_true(w.buildings[near]["powered"], "范围内通电")
	_eq(w.problems(far), [EarthWorld.POWER_PROBLEM], "范围外缺电")
	_built(w, "power_node", 5, 25)
	_true(not w.buildings[far]["powered"], "节点够不到还是缺电")
	_built(w, "power_node", 9, 25)
	_true(w.buildings[far]["powered"], "节点接力后通电")

	var v := _rich_world()
	_built(v, "generator", 0, 25)
	var island := _built(v, "power_node", 15, 25)
	var user := _built(v, "soil_improver", 16, 26)
	_true(not v.buildings[user]["powered"], "没接到电源的节点不算：%d" % island)


func test_energy_budget() -> void:
	var w := _rich_world()
	_built(w, "generator", 0, 25)  # 产 10
	var ids: Array[int] = []
	for i in 6:  # 每个用 2，第 6 个不够
		ids.append(_built(w, "soil_improver", 2 + i, 24))
	_eq(w.energy_output(), 10, "产能 10")
	_eq(w.energy_used(), 10, "用满")
	_true(w.buildings[ids[4]]["powered"], "第 5 个还有电")
	_eq(w.problems(ids[5]), [EarthWorld.POWER_PROBLEM], "第 6 个能源不够")


func test_water_chain() -> void:
	var w := _rich_world()
	_built(w, "generator", 0, 3)
	var purifier := _built(w, "purifier", 3, 2)
	var farm := _built(w, "farm_plot", 6, 7)
	_true(w.buildings[purifier]["powered"], "净水站通电")
	_eq(w.problems(farm), [EarthWorld.WATER_PROBLEM], "没接水管缺水")
	_pipes(w, 2, 5)
	_eq(w.problems(farm), [EarthWorld.WATER_PROBLEM], "水管没接到还是缺水")
	var last := _built(w, "water_pipe", 6, 6)
	_true(w.buildings[farm]["watered"], "水管接上后有水")
	w.demolish(last)
	_true(not w.buildings[farm]["watered"], "水管断了就没水")
	_built(w, "water_pipe", 6, 6)
	w.demolish(purifier)
	_eq(w.water_output(), 0, "净水站没了不产水")
	_true(not w.buildings[farm]["watered"], "净水站停运就缺水")


func test_farm_grows_spreads_and_withers() -> void:
	var w := _rich_world()
	_built(w, "generator", 0, 3)
	var purifier := _built(w, "purifier", 3, 2)
	var farm := _built(w, "farm_plot", 6, 7)
	w.end_week()
	_true(w.plants.is_empty(), "缺水不长")
	_pipes(w, 2, 6)
	_true(w.buildings[farm]["watered"], "接上水")
	w.end_week()
	_eq(w.plants.size(), 8, "长满 4 格并扩散 4 格")
	_true(w.plants.has(Vector2i(6, 7)), "种植区本身有植物")
	w.end_week()
	_eq(w.plants.size(), 12, "继续扩散")
	w.demolish(purifier)
	var before := w.plants.size()
	w.end_week()
	_eq(w.plants.size(), before - 4, "断水后每周枯死 4 格")


## 从净水站旁边接水管：(5,2) → (6,2) → 沿 x=6 往下到 z
func _pipes(w: EarthWorld, from_z: int, to_z: int) -> void:
	_built(w, "water_pipe", 5, 2)
	for z in range(from_z, to_z + 1):
		_built(w, "water_pipe", 6, z)


func test_recycler_income() -> void:
	var w := _world()
	w.metal = 3
	w.place("recycler", 0, 0)
	var report := w.end_week()
	_eq(w.metal, 3, "建好当周就产 3 金属")
	_eq(report["metal"], 3, "报告净增 3")
	w.end_week()
	_eq(w.metal, 6, "每周 +3")


func test_repair_station_bonus() -> void:
	var w := _rich_world()
	_built(w, "repair_station", 4, 4)
	_eq(w.work_units_total(), 9, "修好后 +3")
	_eq(w.robot_count(), 3, "多一台机器人")


func test_cancel_and_demolish() -> void:
	var w := _world()
	w.metal = 3
	var uid := w.place("recycler", 0, 0)
	w.cancel_blueprint(uid)
	_eq(w.metal, 3, "取消退材料")
	_true(w.queue.is_empty(), "队列清掉")
	_true(not w.is_blocked(Vector2i(0, 0)), "地空出来")
	uid = w.place("recycler", 0, 0)
	w.end_week()
	var metal_now := w.metal
	w.demolish(uid)
	_eq(w.metal, metal_now, "拆除不退材料")
	_true(not w.buildings.has(uid), "建筑没了")


func test_recovery_values() -> void:
	var w := _rich_world()
	_eq(w.recovery(), {"ruins": 0, "power": 0, "water": 0, "plants": 0}, "开局全 0")
	w.cut_small("scrap1")
	_true(w.recovery()["ruins"] >= 0, "小废料算清理")
	for id: String in w.ruins:
		w.ruins[id]["cleared"] = true
	_eq(w.recovery()["ruins"], 100, "全清理 100%")
	_built(w, "generator", 0, 25)
	_built(w, "soil_improver", 3, 25)
	_built(w, "soil_improver", 20, 25)
	_eq(w.recovery()["power"], 50, "一半通电 50%")


## 直接建好一座建筑，省掉等工作单位的步骤
func _built(w: EarthWorld, type: String, x: int, z: int) -> int:
	var uid := w.place(type, x, z)
	_true(uid != 0, "建 %s 在 %d,%d：%s" % [type, x, z, str(w.can_place(type, x, z))])
	if uid == 0:
		return 0
	for job in w.queue:
		if job["ref"] == uid:
			w.queue.erase(job)
			break
	w.buildings[uid]["done"] = true
	w._recompute_networks()
	return uid


func _world() -> EarthWorld:
	GameState.reset()
	return EarthWorld.new()


func _rich_world() -> EarthWorld:
	var w := _world()
	w.metal = 1000
	w.electronics = 1000
	for id in ["mechanics", "ecology", "comms"]:
		GameState.change_stat(id, 100)
	return w


func _eq(actual: Variant, expected: Variant, label: String) -> void:
	_count += 1
	if str(actual) != str(expected):
		_failures += 1
		print("失败：%s（期望 %s，实际 %s）" % [label, str(expected), str(actual)])


func _true(condition: bool, label: String) -> void:
	_eq(condition, true, label)
