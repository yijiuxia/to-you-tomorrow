class_name RoomRules
extends RefCounted
## 房间、平板、场所、科技树的规则（房间线程）。不碰画面，能测试。
## 状态都存在 GameState.flags 里（以 room_ 开头），这样每周自动存档会一起存，不用改存档代码。

const FLAG_ON := "room_on_"        # 开关物件：true = 灯亮 / 灯罩盖着 / 书摆在桌上
const FLAG_OPTION := "room_opt_"   # 平板选项：窗景、灯光、音乐当前选的 id
const FLAG_JOURNAL := "room_journal_"  # 过去的周记写定后存下来（存编号和参数，换语言也能显示）
const FLAG_UNDERGROUND := "underground_visited"

const TRAIT_LINES := {"curiosity": "RM-04-10", "empathy": "RM-04-11", "confidence": "RM-04-12"}
const LIFE_FIRST := 30  # RM-04-30 是第 1 周的生活句，往后每周 +1


## 某个场所里的全部物件，按表格顺序
static func objects_in(scene: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for row: Dictionary in DataDB.table("room_objects").values():
		if row["scene"] == scene:
			result.append(row)
	return result


static func place(id: String) -> Dictionary:
	return DataDB.row("places", id)


static func is_place_open(id: String) -> bool:
	var row := place(id)
	return not row.is_empty() and GameState.week >= int(row["open_week"])


## 电梯菜单里的场所（包括还没开放的，画面上显示成灰的）
static func elevator_places() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for row: Dictionary in DataDB.table("places").values():
		if int(row["in_elevator"]) == 1:
			result.append(row)
	return result


## 第 7 周可以跟幸存者去地下居民区。世界观还没定，先只看周数，以后要加条件改这里。
static func can_go_underground() -> bool:
	return is_place_open("underground")


# ---------- 开关物件 ----------

static func is_on(id: String) -> bool:
	return bool(GameState.flags.get(FLAG_ON + id, true))


static func toggle(id: String) -> bool:
	var value := not is_on(id)
	GameState.flags[FLAG_ON + id] = value
	return value


## 开关按钮上写什么：按现在的状态给出"按下去会怎样"
static func toggle_label(effect: String, on: bool) -> String:
	match effect:
		"light":
			return Text.t("RM-02-10" if on else "RM-02-09")
		"cover":
			return Text.t("RM-02-07" if on else "RM-02-08")
		"hide":
			return Text.t("RM-02-11" if on else "RM-02-12")
	return ""


# ---------- 平板选项 ----------

static func options(group: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for row: Dictionary in DataDB.table("room_options").values():
		if row["group"] == group:
			result.append(row)
	return result


static func current_option(group: String) -> Dictionary:
	var list := options(group)
	var chosen := str(GameState.flags.get(FLAG_OPTION + group, ""))
	for row in list:
		if row["id"] == chosen:
			return row
	return list[0] if not list.is_empty() else {}


static func choose_option(group: String, id: String) -> void:
	GameState.flags[FLAG_OPTION + group] = id


# ---------- 周记 ----------

## 第 week 周的周记，每行 [编号, 参数]。当前这周随状态变；过去的周第一次被看到时写定。
static func journal_entry(week: int) -> Array:
	var key := FLAG_JOURNAL + str(week)
	if GameState.flags.has(key):
		return GameState.flags[key]
	var lines: Array = []
	lines.append(["RM-04-02", {}])
	lines.append([_trait_line(), {}])
	lines.append(["RM-04-03", {}])
	lines.append(["RM-04-20", {}])
	lines.append(["RM-04-04", {}])
	lines.append(["RM-04-%02d" % (LIFE_FIRST + clampi(week, 1, 7) - 1), {}])
	lines.append(["RM-04-05", {}])
	if week >= int(DataDB.balance("earth_open_week")) and GameState.earth != null:
		lines.append(["RM-04-40", {"value": earth_average()}])
	else:
		lines.append(["RM-04-41", {}])
	lines.append(["RM-04-06", {}])
	lines.append([_trust_line(), {}])
	if week < GameState.week:
		GameState.flags[key] = lines
	return lines


static func journal_text(week: int) -> PackedStringArray:
	var result := PackedStringArray()
	for line: Array in journal_entry(week):
		result.append(Text.f(line[0], line[1]))
	return result


## 她最突出的性格决定"自己"那一句；都不高就写平常的一句
static func _trait_line() -> String:
	var best := ""
	var best_value := -1
	for id: String in TRAIT_LINES:
		if GameState.is_high(id) and GameState.get_stat(id) > best_value:
			best = id
			best_value = GameState.get_stat(id)
	return TRAIT_LINES[best] if not best.is_empty() else "RM-04-13"


static func _trust_line() -> String:
	if GameState.is_high("trust"):
		return "RM-04-50"
	if GameState.is_low("trust"):
		return "RM-04-51"
	return "RM-04-52"


# ---------- 地球情况 ----------

static func earth_average() -> int:
	var rec := GameState.earth.recovery()
	var total := 0
	for value: int in rec.values():
		total += value
	return total / maxi(rec.size(), 1)


static func earth_lines() -> PackedStringArray:
	var result := PackedStringArray()
	if not WeekSystem.is_earth_open() or GameState.earth == null:
		result.append(Text.t("RM-03-20"))
		return result
	result.append(Text.f("RM-03-18", GameState.earth.recovery()))
	result.append(Text.f("RM-03-19", {"metal": GameState.earth.metal, "electronics": GameState.earth.electronics}))
	return result


# ---------- 科技 ----------

static func is_tech_unlocked(id: String) -> bool:
	var row := DataDB.row("tech", id)
	return not row.is_empty() and GameState.get_stat(row["stat"]) >= int(row["need"])


## 按技能分成几列：{ 技能 id -> [科技行...] }，每列按门槛从低到高
static func tech_tree() -> Dictionary:
	var result := {}
	for row: Dictionary in DataDB.table("tech").values():
		if not result.has(row["stat"]):
			result[row["stat"]] = []
		result[row["stat"]].append(row)
	for stat: String in result:
		result[stat].sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["need"]) < int(b["need"]))
	return result
