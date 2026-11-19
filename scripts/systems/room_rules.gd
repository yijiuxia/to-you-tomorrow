class_name RoomRules
extends RefCounted
## 房间、平板、场所、科技树的规则（房间线程）。不碰画面，能测试。
## 状态都存在 GameState.flags 里（以 room_ 开头），这样每周自动存档会一起存，不用改存档代码。

const FLAG_ON := "room_on_"        # 开关物件：true = 灯亮 / 灯罩盖着 / 书摆在桌上
const FLAG_OPTION := "room_opt_"   # 平板选项：窗景、灯光、音乐当前选的 id
const FLAG_JOURNAL := "room_journal_"  # 过去的周记写定后存下来（存编号和参数，换语言也能显示）
const FLAG_UNDERGROUND := "underground_visited"



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
			return Text.t("RT-02-10" if on else "RT-02-09")
		"cover":
			return Text.t("RT-02-07" if on else "RT-02-08")
		"hide":
			return Text.t("RT-02-11" if on else "RT-02-12")
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


# ---------- 物件说明（定稿 13_平板与房间 RM） ----------

## 她给 ARK-01 起的名字（第 3 周起名前用型号）
static func ark_name() -> String:
	var name := str(GameState.flags.get(StoryRunner.ARK_NAME_FLAG, ""))
	return name if not name.is_empty() else "ARK-01"


## 点物件看到的说明：分 8 岁 / 15 岁；挂册按周数换页，植物第 3 周后多一句；窗户写现在的画面
static func info_text(row: Dictionary) -> String:
	var keys := str(row.get("info_key", ""))
	var later := str(row.get("info_key_15", ""))
	if GameState.age >= int(DataDB.balance("teen_age", 15)) and not later.is_empty():
		keys = later
	match str(row.get("id", "")):
		"wall_album":
			keys = _album_key()
		"plant":
			if GameState.week >= 3:
				keys = "RM-05-03"
	var values := {"ark": ark_name(), "view": Text.t(str(current_option("view").get("name_key", "")))}
	var lines := PackedStringArray()
	for key in keys.split(";", false):
		lines.append(Text.f(key.strip_edges(), values))
	return "
".join(lines)


## 挂册：第 2 周维修站的画、第 3 周小叶子、时间跳跃后草图、第 6 周后温室速写（遇到线多一张背影）
static func _album_key() -> String:
	if GameState.week >= 6:
		return "RM-04-05" if GameState.met_survivor else "RM-04-04"
	if GameState.week >= 4:
		return "RM-04-03"
	if GameState.week >= 3:
		return "RM-04-02"
	return "RM-04-01"


# ---------- 周记（定稿 TB-06：每周结算后写一篇，五栏；第 7 周和时间跳跃没有） ----------

const JOURNAL_LAST_WEEK := 6
const JOURNAL_SECTIONS := 5


## 已经写好的周记有哪几周（本周还没结算，所以不算本周）
static func journal_weeks() -> Array[int]:
	var result: Array[int] = []
	for week in range(1, mini(GameState.week, JOURNAL_LAST_WEEK + 1)):
		result.append(week)
	return result


## 某一周的周记：小标题 + 一句，五栏。第 6 周按有没有走进温室分两种。
## 【模型】版周记以后由人物 AI 接，现在用定稿的后备周记。
static func journal_text(week: int) -> PackedStringArray:
	var result := PackedStringArray()
	if week < 1 or week > JOURNAL_LAST_WEEK:
		return result
	var base := week * 10
	if week == 6 and not GameState.met_survivor:
		base = 70
	var titles := Text.t("TB-06-02").split(" / ")
	var values := {"ark": ark_name()}
	for i in JOURNAL_SECTIONS:
		var title := titles[i] if i < titles.size() else ""
		result.append("【%s】%s" % [title, Text.f("TB-06-%02d" % (base + i + 1), values)])
	return result


# ---------- 地球情况（定稿 TB-05：只放档案和观测数据，不放小镇的数据，免得把小镇和地球连起来） ----------

static func earth_lines() -> PackedStringArray:
	var result := PackedStringArray()
	for i in range(1, 7):
		var key := "TB-05-%02d" % i
		if i == 5 and _believes():
			key = "TB-05-08" if GameState.met_survivor else "TB-05-09"
		result.append(Text.t(key))
	result.append(Text.f("TB-05-07", {"year": int(DataDB.balance("room_ark_years_before_birth")) + GameState.age}))
	return result


## 第 7 周她相信了以后，聚居点那一行要改
static func _believes() -> bool:
	return GameState.week >= int(DataDB.balance("last_week")) and GameState.cognition == GameState.Cognition.BELIEVE


# ---------- 科技树（定稿 TT：技能够了自动解锁；剧情解锁的没到时显示 ???） ----------

static func tech_open() -> bool:
	return GameState.week >= int(DataDB.balance("room_tech_open_week"))


static func is_tech_visible(id: String) -> bool:
	var flag := str(DataDB.row("tech", id).get("show_flag", ""))
	return flag.is_empty() or bool(GameState.flags.get(flag, false))


static func is_tech_unlocked(id: String) -> bool:
	var row := DataDB.row("tech", id)
	if row.is_empty():
		return false
	var story := str(row.get("story_flag", ""))
	if not story.is_empty():
		return bool(GameState.flags.get(story, false))
	for pair: Array in [["stat", "need"], ["stat2", "need2"]]:
		var stat := str(row.get(pair[0], ""))
		if not stat.is_empty() and GameState.get_stat(stat) < int(row[pair[1]]):
			return false
	return true


## 还差什么：技能门槛写成"机械 45（当前 12）"，剧情解锁的写 ???
static func tech_need_text(id: String) -> String:
	var row := DataDB.row("tech", id)
	if not str(row.get("story_flag", "")).is_empty():
		return "???"
	var needs := PackedStringArray()
	var nows := PackedStringArray()
	for pair: Array in [["stat", "need"], ["stat2", "need2"]]:
		var stat := str(row.get(pair[0], ""))
		if not stat.is_empty():
			needs.append("%s %d" % [UiKit.stat_name(stat), int(row[pair[1]])])
			nows.append(str(GameState.get_stat(stat)))
	return Text.f("TT-00-03", {"need": "、".join(needs), "now": " / ".join(nows)})


## 表格顺序就是树从左到右的顺序
static func tech_rows() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for row: Dictionary in DataDB.table("tech").values():
		if is_tech_visible(row["id"]):
			result.append(row)
	return result
