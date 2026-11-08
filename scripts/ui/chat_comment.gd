class_name ChatComment
extends Label
## 改课表时她评论一句（demo 文案"主界面·课表"）。人物 AI 线程的文件。
## 玩家可能连着改好几天，所以停手一会儿再问模型，只评论最后的课表。

var _version := 0


func _ready() -> void:
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


## 课表变了就调用。collapse_day 是程序算出的累倒那天（-1 表示不会累倒）
func request(plan: Array[String], collapse_day: int, day_names: PackedStringArray) -> void:
	_version += 1
	var mine := _version
	await get_tree().create_timer(float(DataDB.balance("chat_comment_wait_sec"))).timeout
	if mine != _version or not is_inside_tree():
		return  # 又改了，等最后一次
	var line := await ChatLines.schedule_comment(plan, collapse_day, day_names)
	if mine == _version and is_inside_tree():
		text = Text.f("UI-41-11", {"text": line["reply"]})
