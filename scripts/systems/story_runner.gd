class_name StoryRunner
extends RefCounted
## 剧情播放的规则部分（不碰画面，能单独测试）：读台词文件、一句句往下走、处理选择。
## 台词文件是 Dialogue Manager 的 .dialogue，放在 story/。每句台词后面写编号 [ID:OP-01-02]，
## 显示时按编号去 text/ 的表格取当前语言的文字；表格里没有这个编号时，才直接显示文件里写的字。
## 这样中英文都在表格里，台词文件只管"谁说、先后顺序、分支和改状态"。
##
## 台词文件里能调用的方法（写法 $> add_stat("trust", "story_op_greet_trust")）就是下面这些 func，
## 其他全局模块也能直接用，比如 if GameState.week >= 3。

signal camera_requested(shot: String)  ## 剧情要求切镜头，画面做好后由画面去接
signal view_requested(mode: String)    ## 剧情要求切俯视 / 第三人称（"top" / "third"）

const STORY_DIR := "res://story/"
const NARRATOR := ""
const CHARACTER_KEYS := {"survivor": "UI-54-05"}
const ARK_NAME_FLAG := "ark_name"  # 第 3 周她给 ARK-01 起的名字，存在 GameState.flags 里，跟着存档走

var resource: DialogueResource


## 读一个台词文件。正常走 Godot 导入好的资源；没经过编辑器导入时
## （比如刚下载的仓库直接跑测试），就读原文现场编译，结果一样。
static func load_dialogue(file_name: String) -> DialogueResource:
	var path := STORY_DIR + file_name
	if ResourceLoader.exists(path):
		var loaded: Resource = load(path)
		if loaded is DialogueResource:
			return loaded
	if not FileAccess.file_exists(path):
		push_error("找不到台词文件：" + path)
		return null
	return DialogueManager.create_resource_from_text(FileAccess.get_file_as_string(path))


## 从某个标记（~ start 这种）开始，返回第一句；没有台词时返回 null
func start(file_name: String, cue: String) -> DialogueLine:
	resource = load_dialogue(file_name)
	if resource == null:
		return null
	return await next(cue)


## 走到下一句。台词里的改状态（$> ...）在这一步自动执行。
func next(next_id: String) -> DialogueLine:
	if resource == null or next_id.is_empty():
		return null
	return await DialogueManager.get_next_dialogue_line(resource, next_id, [self])


## 一句台词或一个选项该显示的文字
static func text_of(line_or_response: RefCounted) -> String:
	var key: String = line_or_response.get("static_id")
	var raw: String = line_or_response.get("text")
	if model_text.has(key):  # 人物 AI 线程加：这句【模型】句已经由她自己说好了
		return str(model_text[key])
	if key != raw and Text.has_language(key, Text.DEFAULT_LANGUAGE):
		return Text.t(key).format({"ark": ark_name()})
	return raw.format(names())


## 说话人显示的名字。台词文件里写 girl / player / ark / survivor，旁白不写名字。
static func speaker_of(line: DialogueLine) -> String:
	match line.character:
		"", "narrator":
			return NARRATOR
		"girl":
			return GameState.girl_name
		"player":
			return GameState.player_name
		"ark":
			return ark_name()
	if CHARACTER_KEYS.has(line.character):
		return Text.t(CHARACTER_KEYS[line.character])
	return line.character


## 台词里能用的名字占位符：{girl} {player} {ark}
static func names() -> Dictionary:
	return {"girl": GameState.girl_name, "player": GameState.player_name, "ark": ark_name()}


## ARK-01 的名字：起名之前叫型号
static func ark_name() -> String:
	var value: Variant = GameState.flags.get(ARK_NAME_FLAG, "")
	return str(value) if not str(value).is_empty() else Text.t("UI-54-03")


# ---- 下面是台词文件里可以调用的方法 ----

## 属性够不够某个门槛（门槛写在 balance.csv）
func stat_at_least(stat_id: String, balance_id: String) -> bool:
	return GameState.get_stat(stat_id) >= int(DataDB.balance(balance_id, 0))


## 给 ARK-01 起名。现在用文字表里的默认名；人物 AI 接上后可以换成模型起的名字再调用 set_ark_name
func name_ark(default_key: String) -> void:
	set_ark_name(Text.t(default_key))


## 人物 AI 线程加：剧情里的【模型】句。台词文件在那句前面写 $> model_line("编号")，
## 这里先让她按性格说好，显示那句时换上；失败就显示文字表里的后备句（data/chat_story_lines.csv 写着每句问什么）
static var model_text := {}


func model_line(key: String) -> void:
	model_text.erase(key)
	var line := await ChatLines.story_line(key)
	if not line["fallback"]:
		model_text[key] = line["reply"]


## 人物 AI 线程加：她自己给 ARK-01 起名并说为什么。line_key 是她说这句的台词编号；失败用默认名和后备句
func model_name_ark(default_key: String, line_key: String) -> void:
	model_text.erase(line_key)
	var named := await ChatLines.name_ark()
	if named.is_empty():
		name_ark(default_key)
		return
	set_ark_name(str(named["name"]))
	model_text[line_key] = named["line"]


func set_ark_name(value: String) -> void:
	GameState.flags[ARK_NAME_FLAG] = value

## 改属性。数值写在 balance.csv（story_ 开头），台词文件里只写编号，遵守"数值只放表格"。
func add_stat(stat_id: String, balance_id: String) -> void:
	GameState.change_stat(stat_id, int(DataDB.balance(balance_id, 0)))


func set_flag(name: String, value: bool = true) -> void:
	GameState.flags[name] = value


func flag(name: String) -> bool:
	return bool(GameState.flags.get(name, false))


func camera(shot: String) -> void:
	camera_requested.emit(shot)


func view(mode: String) -> void:
	view_requested.emit(mode)


# ---- 定稿剧本主线加的（2026-11-19）----

## 本周小镇目标完成没有（周结算算好的，夜里的剧情据此换说法，如第 2 周 W2-08-07 / 08）
func goal_done() -> bool:
	return bool(GameState.last_earth_report.get("goal_done", false))


## 某个属性低于门槛（门槛写在 balance.csv）
func stat_below(stat_id: String, balance_id: String) -> bool:
	return not stat_at_least(stat_id, balance_id)


## 结局按最高的性格换一句（ED-01-05～07），和 WeekSystem.top_trait 同一个算法
func top_trait_is(trait_id: String) -> bool:
	return WeekSystem.top_trait() == trait_id


## 第 6 周分线：ARK-01 走进了温室，遇到了幸存者（第 7 周据此走 W7A 或 W7B）
func meet_survivor() -> void:
	GameState.met_survivor = true


func met_survivor() -> bool:
	return GameState.met_survivor


## 改认知状态："doubt" 怀疑（第 6 周相遇后）、"believe" 相信地球是真的（第 7 周验证后）
func set_cognition(state: String) -> void:
	match state:
		"doubt":
			if GameState.cognition == GameState.Cognition.GAME:
				GameState.cognition = GameState.Cognition.DOUBT
		"believe":
			GameState.cognition = GameState.Cognition.BELIEVE
