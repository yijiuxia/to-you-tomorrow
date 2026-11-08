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
	test_regions_locked_until_gate()
	test_gate_opens_with_old_power()
	test_bridge_and_river()
	test_comm_coverage()
	test_special_fails_when_tired()
	test_clues_and_traits()
	test_hand_plant_and_dig()
	test_broken_building()
	test_plants_grow_up()
	test_proposals()
	test_threshold_behaviors()
	test_week_goal()
	test_events()
	test_farm_unlock()
	test_germination()
	test_tutorial_once()
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
	GameState.flags["seeds_from_plant"] = true
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
	_eq(w.metal, 8, "清理得金属 8")
	_eq(w.electronics, 2, "清理得电子 2")
	_eq(report["metal"], 8, "报告里有金属")
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


func test_regions_locked_until_gate() -> void:
	var w := _rich_world()
	_eq(w.region_of(Vector2i(0, 0)), "a", "南边是 A 区")
	_eq(w.region_of(Vector2i(0, 40)), "b", "中间是 B 区")
	_eq(w.region_of(Vector2i(0, 62)), "river", "干河道")
	_eq(w.region_of(Vector2i(0, 80)), "c", "北边是 C 区")
	_eq(w.open_regions(), ["a"], "开局只有 A 区")
	_eq(w.can_place("recycler", 5, 40).get("key"), "UI-13-08", "B 区没开放不能建")
	_true(not w.is_walkable(Vector2i(5, 40)), "B 区没开放不能走")
	_true(w.is_blocked(Vector2i(12, 29)), "大门关着挡路")
	# 发电设备放在大门旁边，通电后大门打开
	_built(w, "generator", 13, 26)
	_true(GameState.flags.get("gate_open", false), "大门通电后打开")
	_eq(w.props["gate"], "open", "大门状态变成打开")
	_true(not w.is_blocked(Vector2i(12, 29)), "大门打开后不挡路")
	_eq(w.open_regions(), ["a", "b"], "B 区开放")
	_eq(w.can_place("recycler", 5, 41).get("key"), "UI-13-10", "B 区要通信中继才能建")


func test_gate_opens_with_old_power() -> void:
	var w := _world()
	GameState.change_stat("mechanics", 29)
	_eq(w.try_special("old_power", RandomNumberGenerator.new()).get("key"), "UI-13-04", "机械不够修不了")
	GameState.change_stat("mechanics", 1)
	_true(w.try_special("old_power", RandomNumberGenerator.new())["ok"], "机械 30 修好旧备用电源")
	_true(GameState.flags.get("gate_open", false), "修好旧电源大门打开")
	_eq(w.props["old_power"], "fixed", "旧电源变成修好")
	_true(not w.try_special("old_power", RandomNumberGenerator.new())["ok"], "不能修两次")


func test_bridge_and_river() -> void:
	var w := _rich_world()
	GameState.flags["gate_open"] = true
	w._recompute_networks()
	_eq(w.can_place("power_node", 2, 62).get("key"), "UI-13-09", "干河道不能建")
	_true(not w.is_walkable(Vector2i(14, 62)), "桥断着过不去")
	_true(not w.is_region_open("c"), "C 区没开")
	GameState.flags["bridge_temp"] = true
	w._recompute_networks()
	_eq(w.props["bridge"], "temp", "剧情搭了临时便桥")
	_true(w.is_walkable(Vector2i(14, 62)), "桥上能走")
	_true(not w.is_walkable(Vector2i(2, 62)), "桥外的干河道还是不能走")
	_true(w.is_region_open("c"), "C 区开放")


func test_comm_coverage() -> void:
	var w := _rich_world()
	GameState.flags["gate_open"] = true
	w._recompute_networks()
	_eq(w.can_place("recycler", 5, 41).get("key"), "UI-13-10", "没有中继")
	_built(w, "relay", 10, 40)
	_true(w.can_place("recycler", 5, 41).is_empty(), "中继范围内能建")
	_eq(w.can_place("recycler", 5, 57).get("key"), "UI-13-10", "中继范围外不能建")


func test_special_fails_when_tired() -> void:
	var w := _world()
	GameState.change_stat("mechanics", 30)
	GameState.change_stat("stamina", -60)
	var rng := RandomNumberGenerator.new()
	var fails := 0
	for i in 200:
		rng.seed = i
		var copy := EarthWorld.new()
		if not copy.try_special("old_power", rng)["ok"]:
			fails += 1
		GameState.flags.erase("old_power_fixed")
		GameState.flags.erase("gate_open")
	_true(fails > 70 and fails < 130, "体力低时约一半失败（实际 %d/200）" % fails)


func test_clues_and_traits() -> void:
	var w := _rich_world()
	_eq(w.active_clues(), ["seed_jar"], "剧情没开始看不到脚印（种子罐一直都在）")
	GameState.flags["anomaly_started"] = true
	_eq(w.active_clues(), ["dug_hole", "seed_jar"], "A 区的坑出现；B 区还没开")
	w.discover_clue("dug_hole")
	_true(GameState.flags.get("clue_dug_hole", false), "发现线索记成剧情标记")
	_built(w, "power_node", 0, 0)
	_built(w, "power_node", 0, 1)
	for i in 5:
		_built(w, "water_pipe", 2, i)
	var report := w.end_week()
	_eq(report["traits"].get("curiosity"), 1, "发现线索好奇 +1")
	_eq(report["traits"].get("confidence"), 3, "建成 7 项，自信封顶 +3")
	_eq(w.end_week()["traits"], {}, "下一周重新计数")


func test_hand_plant_and_dig() -> void:
	var w := _world()
	_true(not w.hand_plant(Vector2i(0, 0)), "重度污染种不了")
	_true(w.hand_plant(Vector2i(4, 8)), "轻度污染能种")
	_true(not w.hand_plant(Vector2i(4, 8)), "同一格不能种两次")
	_eq(w.plants[Vector2i(4, 8)]["type"], "flower", "喷洒头种的是花")
	var cells: Array[Vector2i] = [Vector2i(4, 8)]
	w.dig_up(cells)
	_true(not w.plants.has(Vector2i(4, 8)), "被挖走")
	_true(w.holes.has(Vector2i(4, 8)), "留下坑")
	_true(w.hand_plant(Vector2i(4, 8)), "坑里能补种")
	_true(not w.holes.has(Vector2i(4, 8)), "补种后坑没了")


func test_broken_building() -> void:
	var w := _rich_world()
	_built(w, "generator", 0, 25)
	var user := _built(w, "soil_improver", 3, 25)
	_true(w.buildings[user]["powered"], "先是通电的")
	w.break_building(user)
	_true(w.problems(user).has(EarthWorld.BROKEN_PROBLEM), "坏了")
	_true(not w.buildings[user]["powered"], "坏了不工作")
	_true(w.repair_building(user), "焊接头修好")
	_true(w.buildings[user]["powered"], "修好后恢复")


func test_plants_grow_up() -> void:
	var w := _world()
	w.hand_plant(Vector2i(4, 8))
	_true(not w.plant_grown(Vector2i(4, 8)), "刚种下是苗")
	w.plants[Vector2i(4, 8)]["age"] = 2
	_true(w.plant_grown(Vector2i(4, 8)), "花长两周后长大")


func test_proposals() -> void:
	var w := _world()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	GameState.stats["stamina"] = 20
	_true(GirlEarth.maybe_propose(w, rng).is_empty(), "体力低时不提方案")
	GameState.stats["stamina"] = 70
	var got := 0
	for i in 20:
		if not GirlEarth.maybe_propose(w, rng).is_empty():
			got += 1
	_eq(got, 2, "每周最多 2 次")
	GameState.weekly = {}
	var proposal := {}
	while proposal.is_empty():
		proposal = GirlEarth.maybe_propose(w, rng)
	_eq(proposal["id"], "fix_shed", "默认提清理棚屋")
	GirlEarth.answer(w, proposal, GirlEarth.ACCEPT)
	_true(w.is_ruin_queued("shed"), "同意后排进施工队列")
	_eq(GameState.get_stat("confidence"), 42, "同意自信 +2")
	_eq(GameState.get_stat("trust"), 51, "同意信任 +1")
	GirlEarth.answer(w, proposal, GirlEarth.REJECT)
	_eq(GameState.get_stat("trust"), 49, "直接否决信任 -2")
	_eq(GameState.flags.get("proposal_rejects"), 1, "记下被否决")
	GirlEarth.answer(w, proposal, GirlEarth.EXPLAIN)
	_eq(GameState.get_stat("trust"), 49, "说明理由否决不变")


func test_threshold_behaviors() -> void:
	var w := _world()
	w.hand_plant(Vector2i(4, 9))  # 堆场废墟（3,10）旁边
	_true(not GirlEarth.objects_to_clear(w, "yard"), "共情不高不阻止")
	GameState.change_stat("empathy", 20)
	_true(GirlEarth.objects_to_clear(w, "yard"), "共情 60 阻止拆植物旁的废墟")
	_true(not GirlEarth.objects_to_clear(w, "tank"), "旁边没植物不阻止")
	_true(not GirlEarth.reveals_clues(), "好奇不高不标隐藏点")
	GameState.change_stat("curiosity", 20)
	_true(GirlEarth.reveals_clues(), "好奇 60 标隐藏点")
	GameState.flags["anomaly_started"] = true
	GameState.change_stat("trust", -25)
	_eq(GirlEarth.week_end_discovery(w), "", "信任低：找到了也不说")
	_true(GameState.flags.has("hidden_clue_dug_hole"), "但她确实找到了")
	GameState.change_stat("trust", 40)
	_eq(GirlEarth.week_end_discovery(w), "dug_hole", "信任够了会告诉你")


func test_week_goal() -> void:
	var w := _world()
	_true(GirlEarth.pick_week_goal(w).is_empty(), "自信不高不定目标")
	GameState.change_stat("confidence", 20)
	var goal := GirlEarth.pick_week_goal(w)
	_eq(goal["id"], "goal_ruins", "第一个目标是清废墟")
	_true(not GirlEarth.goal_reward(w, goal), "没完成没奖励")
	for id in ["plaza", "yard", "shed"]:
		w.ruins[id]["cleared"] = true
	_true(GirlEarth.goal_reward(w, goal), "完成有奖励")
	_eq(GameState.get_stat("confidence"), 62, "自信 +2")


func test_events() -> void:
	var w := _rich_world()
	_built(w, "generator", 0, 25)
	var user := _built(w, "soil_improver", 3, 25)
	var rng := RandomNumberGenerator.new()
	var picked := {}
	for i in 300:
		GameState.weekly = {}
		rng.seed = i
		var e := GirlEarth.pick_event(w, rng)
		if not e.is_empty():
			picked[e["id"]] = true
	_true(picked.has("device_stop") and picked.has("ark_failure"), "两种事件都会出现")
	_true(not picked.has("danger_zone"), "好奇不够不会想进危险区域")
	GameState.weekly = {}
	var count := 0
	for i in 50:
		if not GirlEarth.pick_event(w, rng).is_empty():
			count += 1
	_true(count <= 1, "每周最多 1 次")
	var stop: Dictionary = DataDB.row("earth_events", "device_stop")
	GirlEarth.start_event(w, stop)
	_true(w.problems(user).has(EarthWorld.BROKEN_PROBLEM), "设备停运真的坏了")
	_eq(GirlEarth.resolve_event(w, stop, "continue"), "UI-21-40", "机械够她自己修好")
	_true(w.problems(user).is_empty(), "修好了")
	GirlEarth.start_event(w, stop)
	_eq(GirlEarth.resolve_event(w, stop, "ask_help"), "UI-21-41", "让你修就还坏着")


func test_farm_unlock() -> void:
	var w := _world()
	w.metal = 100
	_eq(w.unlock_reason("farm_plot").get("key"), "UI-13-07", "开局种植区没解锁")
	GameState.flags["plant_event_done"] = true
	_eq(w.unlock_reason("farm_plot").get("key"), "UI-13-07", "只有植物事件不够")
	_true(w.active_clues().has("seed_jar"), "种子罐能找")
	w.discover_clue("seed_jar")
	_true(GameState.flags.get("seed_jar_found", false), "找到种子罐")
	_true(not GameState.flags.get("w5_trace_found", false), "种子罐不算第 5 周的线索")
	_true(w.unlock_reason("farm_plot").is_empty(), "种子罐 + 植物事件 = 解锁")
	GameState.flags.clear()
	GameState.flags["seed_jar_found"] = true
	_eq(w.unlock_reason("farm_plot").get("key"), "UI-13-07", "只有种子罐、没看到植物事件也不行")
	GameState.flags.clear()
	WeekSystem.apply_time_jump()
	_true(w.unlock_reason("farm_plot").is_empty(), "没找到种子罐：时间跳跃后解锁")
	GameState.reset()


func test_germination() -> void:
	var w := _rich_world()
	_built(w, "generator", 0, 3)
	_built(w, "purifier", 3, 2)
	_built(w, "farm_plot", 6, 7)
	_pipes(w, 2, 6)
	GameState.stats["ecology"] = 0
	w.end_week()
	_eq(w.plants.size(), 4 + 2, "生态 0：4 格只发芽 2 格（0.4 × 4 四舍五入）")


func test_tutorial_once() -> void:
	GameState.reset()
	GameState.flags.clear()
	_eq(EarthTutorial.lines_for("enter", {"units": 6}).size(), 0, "第 1 周没有建造教学")
	GameState.week = 2
	var lines := EarthTutorial.lines_for("enter", {"units": 6})
	_eq(lines.size(), 8, "第 2 周进小镇：介绍 5 条 + 镜头 3 条")
	_true(lines[6].contains("6"), "工作单位数填进去了")
	_eq(EarthTutorial.lines_for("enter", {"units": 6}).size(), 0, "只出现一次")
	_eq(EarthTutorial.lines_for("third_person", {}).size(), 2, "第一次切第三人称")
	GameState.reset()


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
	GameState.flags.clear()
	GameState.weekly = {}
	return EarthWorld.new()


func _rich_world() -> EarthWorld:
	var w := _world()
	GameState.flags["seeds_from_plant"] = true
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
