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
const CHARACTER_KEYS := {"ark": "UI-54-03", "survivor": "UI-54-05"}

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
	if key != raw and Text.has_language(key, Text.DEFAULT_LANGUAGE):
		return Text.t(key)
	return raw.format({"girl": GameState.girl_name, "player": GameState.player_name})


## 说话人显示的名字。台词文件里写 girl / player / ark / survivor，旁白不写名字。
static func speaker_of(line: DialogueLine) -> String:
	match line.character:
		"", "narrator":
			return NARRATOR
		"girl":
			return GameState.girl_name
		"player":
			return GameState.player_name
	if CHARACTER_KEYS.has(line.character):
		return Text.t(CHARACTER_KEYS[line.character])
	return line.character


# ---- 下面是台词文件里可以调用的方法 ----

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
