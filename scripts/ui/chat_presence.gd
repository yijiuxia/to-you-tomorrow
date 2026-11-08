class_name ChatPresence
extends VBoxContainer
## 主界面里的她（比赛版 4.5，借鉴 AI Town）：不干等着，隔一会儿换一件自己的事做，
## 偶尔主动跟你说一句。人物 AI 线程的文件，主界面只需要 add_child(ChatPresence.new())。
## 有模型后（模块 9），activity_changed / spoke 的 action 用来播放动作。

signal activity_changed(activity: String, action: String)
signal spoke(text: String, action: String)

var activity := ""
var _doing: Label
var _said: Label
var _rng := RandomNumberGenerator.new()
var _lines_left := 0
var _busy := false


func _ready() -> void:
	_rng.randomize()
	_lines_left = int(DataDB.balance("chat_idle_max_lines"))
	_doing = Label.new()
	_doing.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_doing)
	_said = Label.new()
	_said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_said)
	_change_activity()
	_schedule(float(DataDB.balance("chat_idle_first_sec")))


func _schedule(seconds: float) -> void:
	get_tree().create_timer(seconds).timeout.connect(_tick)


## 每隔一会儿：换一件事做，有一定概率主动说一句（每次进主界面最多说几句，不吵人）
func _tick() -> void:
	if not is_inside_tree():
		return
	_change_activity()
	if not _busy and _lines_left > 0 and _rng.randf() < float(DataDB.balance("chat_idle_speak_chance")):
		_speak()
	_schedule(float(DataDB.balance("chat_idle_change_sec")))


func _speak() -> void:
	_busy = true
	var line := await ChatLines.idle(activity, _rng)
	_busy = false
	if not is_inside_tree() or str(line["reply"]).is_empty():
		return
	_lines_left -= 1
	_said.text = Text.f("UI-41-11", {"text": line["reply"]})
	spoke.emit(line["reply"], line["action"])


## 按权重挑一件适合她年龄的事，尽量不和刚才一样
func _change_activity() -> void:
	var choices: Array[String] = []
	var weights: Array[float] = []
	for id: String in DataDB.table("chat_idle"):
		var row := DataDB.row("chat_idle", id)
		if GameState.age < int(row["min_age"]) or GameState.age > int(row["max_age"]) or id == activity:
			continue
		choices.append(id)
		weights.append(float(row["weight"]))
	if choices.is_empty():
		return
	activity = choices[_rng.rand_weighted(PackedFloat32Array(weights))]
	var row := DataDB.row("chat_idle", activity)
	_doing.text = Text.t(str(row["show_key"]))
	activity_changed.emit(activity, str(row["action"]))
