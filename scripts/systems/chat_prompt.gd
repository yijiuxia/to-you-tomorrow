class_name ChatPrompt
extends RefCounted
## 把真实状态整理成发给模型的文字（比赛版 4.3、4.5）。
## - build()：开聊时的人设 = 角色卡（8 岁 / 15 岁）+ 状态卡 + 核心记忆 + 上次聊到哪 + 此刻心情 + 输出规则。
##   整段对话只设一次：中途改人设会让模型把整段对话重算一遍，曾经因此卡住。
## - turn_message()：每句话随话附上"只有她知道的事"（相关记忆、世界书设定）和情绪提示。
##   按这句话的内容挑记忆，所以放在每句话里，而不是人设里。

const TEMPLATE_DIR := "res://text/prompts/"
const NUMERIC_STATS: Array[String] = ["stamina", "mood"]
const TRAIT_STATS: Array[String] = ["confidence", "curiosity", "empathy", "trust"]
const SKILL_STATS: Array[String] = ["mechanics", "ecology", "comms"]
const COGNITION_KEYS: Array[String] = ["WK-10-01", "WK-10-02", "WK-10-03"]  # 顺序同 GameState.Cognition


static func build() -> String:
	var store: MemoryStore = GameState.memory
	var mood := ChatMood.state(store)
	var names := {"girl": GameState.girl_name, "player": GameState.player_name}
	var card := _template("card_%s_%d.txt" % [Text.language, card_age()]).format(names)
	var rules := _template("rules_%s.txt" % Text.language).format(names).replace("{max_chars}", str(ChatMood.max_length(mood)))
	var parts := PackedStringArray([card, state_card()])
	var remembered := memory_block(store)
	if not remembered.is_empty():
		parts.append(remembered)
	parts.append(Text.f("WK-10-11", {"hint": ChatMood.hint(mood, store)}))
	parts.append(rules)
	return "\n\n".join(parts)


## 每句话发给模型的内容：玩家原话 + 上一句留下的情绪 + 想起的事 + 收尾提示
static func turn_message(player_text: String, last_attitude: String, closing: bool) -> String:
	var lines := PackedStringArray([player_text])
	var feeling := ChatMood.after_hint(last_attitude)
	if not feeling.is_empty():
		lines.append(feeling)
	var aside := aside_lines(player_text)
	if not aside.is_empty():
		lines.append(Text.t("WK-10-12"))
		lines.append_array(aside)
	if closing:
		lines.append(Text.t("WK-05-01"))
	return "\n".join(lines)


## 这句话让她想起的事和知道的设定，都按相关度挑，不相关就不带
static func aside_lines(player_text: String) -> PackedStringArray:
	var result := PackedStringArray()
	var store: MemoryStore = GameState.memory
	var recalled := store.recall(player_text, int(DataDB.balance("memory_recall_count")), GameState.week, GameState.age)
	if not recalled.is_empty():
		var texts := PackedStringArray()
		for memory in recalled:
			texts.append(str(memory["text"]))
		result.append(Text.f("WK-10-13", {"items": _join_items(texts)}))
	var known := ChatWorldbook.entries(player_text, int(DataDB.balance("chat_worldbook_max")))
	if not known.is_empty():
		result.append(Text.f("WK-10-14", {"items": _join_items(known)}))
	return result


## 状态卡：第几周、剧情阶段、她以为地球是什么、属性、本周的课、上周小镇的事、她想做的事
static func state_card() -> String:
	var lines := PackedStringArray()
	var stage := DataDB.row("chat_stages", str(GameState.week))
	var stage_text := Text.t(str(stage.get("text_key", ""))) if not stage.is_empty() else ""
	lines.append(Text.f("WK-10-04", {"week": GameState.week, "stage": stage_text}))
	lines.append(Text.t(COGNITION_KEYS[GameState.cognition]))
	lines.append(_state_text())
	lines.append(_courses_text())
	if not GameState.last_earth_report.is_empty():
		lines.append(_earth_text())
	if GameState.girl_intent != "none":
		lines.append(Text.f("WK-10-15", {"intent": Text.t("UI-12-" + GameState.girl_intent)}))
	return "\n".join(lines)


## 核心记忆（每次都带）+ 最近的感想 + 上次聊到的几句原话
static func memory_block(store: MemoryStore) -> String:
	var lines := PackedStringArray()
	if not store.core.is_empty():
		var items := PackedStringArray()
		for item in store.core:
			items.append(str(item["text"]))
		lines.append(Text.f("WK-10-07", {"items": _join_items(items)}))
	var thought := store.latest_reflection()
	if not thought.is_empty():
		lines.append(Text.f("WK-10-08", {"text": thought}))
	if not store.recent.is_empty():
		var said := ""
		for line in store.recent:
			var who := GameState.player_name if line["speaker"] == MemoryStore.SPEAKER_PLAYER else GameState.girl_name
			said += "\n" + Text.f("WK-10-10", {"name": who, "text": line["text"]})
		lines.append(Text.f("WK-10-09", {"lines": said}))
	return "\n".join(lines)


## 8 岁和 15 岁用两张角色卡（时间跳跃后年龄变成 teen_age）
static func card_age() -> int:
	var teen := int(DataDB.balance("teen_age"))
	return teen if GameState.age >= teen else int(DataDB.balance("child_age"))


static func _template(file_name: String) -> String:
	return FileAccess.get_file_as_string(TEMPLATE_DIR + file_name)


static func _state_text() -> String:
	var parts: PackedStringArray = []
	for id: String in NUMERIC_STATS + SKILL_STATS:
		parts.append(Text.f("WK-06-02", {"name": _name(id), "value": GameState.get_stat(id)}))
	for id: String in TRAIT_STATS:
		parts.append(Text.f("WK-06-03", {"name": _name(id), "text": GameState.trait_text(id, GameState.get_stat(id), GameState.age)}))
	return Text.f("WK-06-01", {"stats": Text.t("WK-08-06").join(parts)})


static func _courses_text() -> String:
	var names: PackedStringArray = []
	for course: String in GameState.last_schedule:
		var name := Text.t(str(DataDB.row("courses", course)["name_key"]))
		if not names.has(name):
			names.append(name)
	return Text.f("WK-06-04", {"courses": Text.t("WK-08-06").join(names)})


## 上周小镇里完成了什么（来自周结算的真实结果）
static func _earth_text() -> String:
	var finished: Array = GameState.last_earth_report.get("finished", [])
	if finished.is_empty():
		return Text.t("WK-10-06")
	var names := PackedStringArray()
	for name: String in finished:
		if not names.has(name):
			names.append(name)
	return Text.f("WK-10-05", {"names": Text.t("WK-08-06").join(names)})


static func _join_items(items: PackedStringArray) -> String:
	return Text.t("WK-10-16").join(items)


static func _name(id: String) -> String:
	return Text.t(str(DataDB.row("girl_stats", id)["name_key"]))
