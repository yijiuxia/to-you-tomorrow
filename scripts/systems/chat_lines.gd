class_name ChatLines
extends RefCounted
## 聊天以外，她"说一句"的地方（比赛版 4.2、4.5，demo 文案"每周流程"）：
## 早安、周总结（同时记成她的感想）、改课表时的评论、上课小事件、主界面主动开口、小镇里的实时评论，
## 还有聊完后的一句摘要。全部有固定后备句，模型没加载、超时、回复不合格都不会卡住。
## 返回 {reply, action, fallback}。

const KIND_LINE := "line"


## 早安：第 model_morning_from_week 周起由模型说，之前用固定句（第 1～3 周文案写好的）
static func morning() -> Dictionary:
	var fixed := Text.t("WK-01-01")
	if GameState.week < int(DataDB.balance("model_morning_from_week")):
		return _fixed(fixed)
	return await _say(Text.t("WK-11-01"), fixed)


## 周总结：她对这周的感受。同一句话记成她的"感想"（反思），以后聊天会想起
static func week_summary(events: PackedStringArray) -> Dictionary:
	var happened := Text.t("WK-08-06").join(events) if not events.is_empty() else Text.t("WK-11-10")
	var line := await _say(Text.f("WK-11-02", {"events": happened}), Text.t("FB-04-01"))
	if not line["fallback"]:
		GameState.memory.remember_event(line["reply"], MemoryStore.KIND_REFLECTION, int(DataDB.balance("memory_reflection_importance")), GameState.week, GameState.age)
	return line


## 周结算页用：先把本周的事记成记忆，再让她说一句周总结。返回显示在结算页上的一行
static func week_end_line() -> String:
	var events := MemoryWriter.record_week(GameState.memory)
	var line := await week_summary(events)
	return Text.f("UI-41-11", {"text": line["reply"]})


## 早上课程结算后：记下上周的课，返回早安那一行（她的名字 + 话）
static func morning_line(results: Array[Dictionary]) -> String:
	MemoryWriter.record_courses(GameState.memory, results)
	var line := await morning()
	return Text.f("UI-41-11", {"text": line["reply"]})


## 改课表时评论一句；照这个课表会累倒的话，告诉模型哪天，让她说得出来
static func schedule_comment(plan: Array[String], collapse_day: int, day_names: PackedStringArray) -> Dictionary:
	var names := PackedStringArray()
	for course in plan:
		names.append(Text.t(str(DataDB.row("courses", course)["name_key"])))
	var warning := ""
	if collapse_day >= 0 and collapse_day < day_names.size():
		warning = Text.f("WK-11-04", {"day": day_names[collapse_day]})
	return await _say(Text.f("WK-11-03", {"plan": Text.t("WK-08-06").join(names), "warning": warning}), Text.t("FB-04-02"))


## 上课小事件（10% 概率，不改数值）：让她讲一件和这门课有关的小事，并记成一条不太重要的记忆
static func course_event(course: String, day_name: String) -> Dictionary:
	var course_name := Text.t(str(DataDB.row("courses", course)["name_key"]))
	var line := await _say(Text.f("WK-11-05", {"day": day_name, "course": course_name}), Text.t("FB-04-03"))
	if not line["fallback"]:
		GameState.memory.remember_event(line["reply"], MemoryStore.KIND_EVENT, 1, GameState.week - 1, GameState.age)
	return line


## 主界面闲着时主动开口。有时顺便提一件旧事，她会主动提起过去
static func idle(activity: String, rng: RandomNumberGenerator) -> Dictionary:
	var doing := Text.t(str(DataDB.row("chat_idle", activity)["doing_key"]))
	var memory := ""
	var store: MemoryStore = GameState.memory
	if not store.events.is_empty() and rng.randf() < float(DataDB.balance("chat_idle_memory_chance")):
		var picked: Dictionary = store.events[rng.randi_range(0, store.events.size() - 1)]
		memory = Text.f("WK-11-07", {"text": picked["text"]})
	return await _say(Text.f("WK-11-06", {"activity": doing, "memory": memory}), "")


## 剧情里的【模型】句：按 chat_story_lines.csv 写好的情况问她，后备句是台词表里那句
static func story_line(key: String) -> Dictionary:
	var row := DataDB.row("chat_story_lines", key)
	if row.is_empty():
		return _fixed(Text.t(key))
	return await _say(Text.t(str(row["request_key"])), Text.t(key))


## 给 ARK-01 起名（demo 文案 2-3）：她说"就叫你'X'吧，因为……"，程序从引号里取出名字。
## 名字取不出来、太长、带怪字符就返回空字典，剧情用默认名
static func name_ark() -> Dictionary:
	var line := await _say(Text.t("WK-17-02"), "")
	if line["fallback"]:
		return {}
	var name := pick_quoted_name(str(line["reply"]))
	if name.is_empty():
		return {}
	return {"name": name, "line": line["reply"]}


## 从"就叫你'小芽'吧"里取出引号中的名字；长度和字符不合格返回空字符串
static func pick_quoted_name(reply: String) -> String:
	var found := RegEx.create_from_string(str(DataDB.balance("chat_ark_name_pattern"))).search(reply)
	if found == null:
		return ""
	var name := found.get_string("name").strip_edges()
	var limit := int(DataDB.balance("chat_ark_name_max_en" if Text.language == "en" else "chat_ark_name_max_zh"))
	if name.is_empty() or name.length() > limit or name.to_lower().contains("ark-01"):
		return ""
	return name


## 小镇里看到什么说一句（实时评论，和模块 6 共用）。fixed 是地球线程原来的固定句，失败时就用它
static func earth_comment(fixed: String) -> Dictionary:
	var plain := ChatEvent.strip_name(fixed)
	return await _say(Text.f("WK-11-09", {"event": plain}), plain)


## 聊完后把这次对话缩成一句记下来（比赛版 4.5：早期对话压缩成摘要），下次不用整段塞给模型。
## 模型失败时用程序拼的一句（玩家说的第一句话），保证记忆里总有这次聊天
static func summarize(lines: Array[Dictionary]) -> String:
	if lines.is_empty():
		return ""
	var said := ""
	var first_player := ""
	for line in lines:
		var is_player: bool = line["speaker"] == MemoryStore.SPEAKER_PLAYER
		var who := GameState.player_name if is_player else GameState.girl_name
		said += "\n" + Text.f("WK-10-10", {"name": who, "text": line["text"]})
		if is_player and first_player.is_empty():
			first_player = line["text"]
	var fixed := Text.f("WK-08-07", {"week": GameState.week, "line": first_player})
	var result := await _say(Text.f("WK-11-08", {"lines": said}), fixed)
	var summary: String = result["reply"]
	GameState.memory.remember_event(summary, MemoryStore.KIND_SUMMARY, int(DataDB.balance("memory_summary_importance")), GameState.week, GameState.age)
	return summary


## 说一句用的人设：角色卡 + 状态卡 + 记忆 + 此刻心情 + 只要一句话的规则
static func system_prompt() -> String:
	var store: MemoryStore = GameState.memory
	var mood := ChatMood.state(store)
	var names := {"girl": GameState.girl_name, "player": GameState.player_name}
	var card := without_catchphrases(FileAccess.get_file_as_string(ChatPrompt.TEMPLATE_DIR + "card_%s_%d.txt" % [Text.language, ChatPrompt.card_age()]).format(names))
	var limit := int(DataDB.balance("chat_line_max_en" if Text.language == "en" else "chat_line_max_zh"))
	var rules := FileAccess.get_file_as_string(ChatPrompt.TEMPLATE_DIR + "line_rules_%s.txt" % Text.language).format(names).replace("{max_chars}", str(limit))
	var parts := PackedStringArray([card, ChatPrompt.state_card()])
	var remembered := ChatPrompt.memory_block(store)
	if not remembered.is_empty():
		parts.append(remembered)
	parts.append(Text.f("WK-10-11", {"hint": ChatMood.hint(mood, store)}))
	parts.append(rules)
	return "\n\n".join(parts)


## "说一句"每次都是单独问的，模型不知道刚说过口头禅，会句句都带（实测"……算了"几乎每句都有），所以这里去掉口头禅那一行
static func without_catchphrases(card: String) -> String:
	var kept := PackedStringArray()
	for line in card.split("
"):
		if not line.begins_with(Text.t("WK-10-19")):
			kept.append(line)
	return "
".join(kept)


static func _say(request: String, fallback_text: String) -> Dictionary:
	var line := await ModelService.say_line(system_prompt(), request, fallback_text)
	# 小模型爱把记忆原样念出来（实测周总结记成感想后，后面几句都在重复它），这种就用固定句
	if not line["fallback"] and is_copied(str(line["reply"])):
		return _fixed(fallback_text)
	return line


## 和她的某条记忆一字不差，或者整条记忆都被抄进来了
static func is_copied(reply: String) -> bool:
	var store: MemoryStore = GameState.memory
	for memory in store.events:
		var text := str(memory["text"])
		if reply == text or (text.length() >= int(DataDB.balance("chat_copy_min_chars")) and reply.contains(text)):
			return true
	return false


static func _fixed(text: String) -> Dictionary:
	return {"reply": text, "action": ModelService.NO_ACTION, "fallback": true}
