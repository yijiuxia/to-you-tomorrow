extends Node
## 人物 AI（聊天、记忆、鲜活感）的自动测试，不用模型。运行方法：
## Godot_console.exe --headless --path . res://scenes/tests/chat_tests.tscn
## 全部通过时退出码是 0。

var _failures := 0
var _count := 0


func _ready() -> void:
	test_worldbook_topics()
	test_worldbook_respects_story()
	test_words_of()
	test_recall_picks_relevant()
	test_recall_skips_unrelated()
	test_recall_limit_and_childhood()
	test_core_memory_replaces()
	test_events_forget_weakest()
	test_memory_save_roundtrip()
	test_learn_favourite_and_promise()
	test_record_week()
	test_record_courses()
	test_prompt_cards()
	test_state_card()
	test_mood_inertia()
	test_turn_message()
	test_schema_matches_tables()
	test_reply_action()
	await test_lines_fallback()
	test_presence_fits_age()
	test_judge_parsing()
	test_event_rules()
	test_childhood_after_jump()
	test_copied_memory()
	test_claims()
	await test_story_free_talk()
	await test_event_chat_flow()
	print("聊天测试 %d 项，失败 %d 项" % [_count, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func test_worldbook_topics() -> void:
	_fresh()
	var topics := ChatWorldbook.topics("我们去小镇种植物吧")
	_ok(topics.has("plant"), "提到植物有 plant 话题")
	_ok(topics.has("earth"), "提到小镇有 earth 话题")
	_ok(not ChatWorldbook.topics("今天的机器人").has("people"), "“机器人”不算提到别人")
	_ok(ChatWorldbook.topics("Look at the SKY").has("sky"), "英文不分大小写")


func test_worldbook_respects_story() -> void:
	_fresh()
	GameState.week = 2
	_eq(ChatWorldbook.entries("工业区的大门", 5).size(), 0, "第 2 周还不知道工业区")
	GameState.week = 4
	_eq(ChatWorldbook.entries("工业区的大门", 5).size(), 1, "第 4 周知道工业区")
	var before := ChatWorldbook.entries("小镇里有别人吗", 5)
	_ok(_any_contains(before, "从没见过人"), "相遇前她只知道没见过人")
	GameState.met_survivor = true
	var after := ChatWorldbook.entries("小镇里有别人吗", 5)
	_ok(not _any_contains(after, "从没见过人"), "相遇后不再说没见过人")
	_ok(_any_contains(after, "真正的人"), "相遇后知道见过人")
	_ok(_any_contains(ChatWorldbook.entries("聊聊方舟", 5), GameState.player_name), "设定里填上玩家名字")
	_eq(ChatWorldbook.entries("小镇 天空 星星 方舟", 2).size(), 2, "最多补几条按参数")


func test_words_of() -> void:
	var words := MemoryStore.words_of("我们的小芽开花了")
	_ok(words.has("小芽"), "中文取相邻两个字")
	_ok(not words.has("我们"), "去掉到处都有的词")
	words = MemoryStore.words_of("The little sprout bloomed")
	_ok(words.has("sprout") and not words.has("the"), "英文取单词，去掉短词")


func test_recall_picks_relevant() -> void:
	var store := MemoryStore.new()
	store.remember_event("第 2 周，我们种下了第一株小芽。", MemoryStore.KIND_EVENT, 3, 2, 8)
	store.remember_event("第 2 周，我上得最多的是机械课。", MemoryStore.KIND_EVENT, 1, 2, 8)
	store.remember_event("第 3 周，我们在小镇里完成了：发电设备。", MemoryStore.KIND_EVENT, 2, 3, 8)
	var found := store.recall("那株小芽现在怎么样了？", 3, 3, 8)
	_eq(found.size(), 1, "只取和小芽有关的")
	_ok(found.size() > 0 and str(found[0]["text"]).contains("小芽"), "取到种小芽那条")
	found = store.recall("发电机修好了吗", 3, 3, 8)
	_ok(found.size() > 0 and str(found[0]["text"]).contains("发电"), "按话题取到发电那条")


func test_recall_skips_unrelated() -> void:
	var store := MemoryStore.new()
	store.remember_event("第 2 周，我们种下了第一株小芽。", MemoryStore.KIND_EVENT, 3, 2, 8)
	_eq(store.recall("你好呀", 3, 2, 8).size(), 0, "没关系的话一条都不带")


func test_recall_limit_and_childhood() -> void:
	var store := MemoryStore.new()
	for week in range(1, 6):
		store.remember_event("第 %d 周，我给植物浇了水。" % week, MemoryStore.KIND_EVENT, 1, week, 8 if week <= 3 else 15)
	_eq(store.recall("植物", 3, 5, 15).size(), 3, "最多取 count 条")
	var teen := MemoryStore.new()
	teen.remember_event("第 2 周，我们种下了第一株小芽。", MemoryStore.KIND_EVENT, 2, 2, 8)
	teen.remember_event("第 5 周，小芽被挖走了。", MemoryStore.KIND_EVENT, 2, 5, 15)
	var found := teen.recall("小芽", 1, 5, 15)
	_ok(found.size() == 1 and int(found[0]["age"]) == 8, "长大后聊到相关话题，优先想起小时候")


func test_core_memory_replaces() -> void:
	var store := MemoryStore.new()
	store.remember_core("like_颜色", "我最喜欢的颜色是蓝色。", 2)
	store.remember_core("like_颜色", "我最喜欢的颜色是绿色。", 4)
	_eq(store.core.size(), 1, "同一个喜好只记一条")
	_ok(str(store.core[0]["text"]).contains("绿色"), "改口后记新的")
	for i in 20:
		store.remember_core("promise_%d" % i, "约定 %d" % i, i)
	_eq(store.core.size(), int(DataDB.balance("memory_core_max")), "核心记忆有上限")


func test_events_forget_weakest() -> void:
	var store := MemoryStore.new()
	store.remember_event("我第一次见到人。", MemoryStore.KIND_EVENT, 3, 6, 15)
	for i in int(DataDB.balance("memory_events_max")) + 5:
		store.remember_event("普通的一天 %d" % i, MemoryStore.KIND_EVENT, 1, 2, 8)
	_eq(store.events.size(), int(DataDB.balance("memory_events_max")), "事件记忆有上限")
	_ok(str(store.events[0]["text"]).contains("见到人"), "重要的事不会先忘")


func test_memory_save_roundtrip() -> void:
	var store := MemoryStore.new()
	store.remember_core("like_花", "我最喜欢的花是向日葵。", 2)
	store.remember_event("第 2 周，我们种下了第一株小芽。", MemoryStore.KIND_REFLECTION, 3, 2, 8)
	store.remember_line(MemoryStore.SPEAKER_PLAYER, "你好")
	store.tone.append("ignore")
	store.noted_flags.append("first_plant")
	var copy := MemoryStore.from_dict(JSON.parse_string(JSON.stringify(store.to_dict())))
	_eq(copy.core.size(), 1, "读档后核心记忆还在")
	_eq(copy.latest_reflection(), "第 2 周，我们种下了第一株小芽。", "读档后感想还在")
	_eq(copy.recall("小芽", 3, 2, 8).size(), 1, "读档后还能按话题取记忆")
	_eq(copy.recent.size(), 1, "读档后最近的话还在")
	_ok(copy.tone.has("ignore") and copy.noted_flags.has("first_plant"), "读档后态度和标记还在")


func test_learn_favourite_and_promise() -> void:
	_fresh()
	var store := MemoryStore.new()
	MemoryWriter.record_turn(store, "你最喜欢什么颜色？", "我最喜欢的颜色是天蓝色！")
	_eq(store.core.size(), 1, "认出她说的喜好")
	_ok(store.core.size() > 0 and str(store.core[0]["text"]).contains("天蓝色"), "记下喜欢的颜色")
	MemoryWriter.record_turn(store, "我答应你，下周一起去看温室。", "好呀！")
	_eq(store.core.size(), 2, "认出玩家的约定")
	_ok(str(store.core[1]["text"]).contains("下周一起去看温室"), "约定记下原话")
	MemoryWriter.record_turn(store, "What do you like?", "My favourite flower is sunflower.")
	_ok(str(store.core[2]["text"]).contains("sunflower"), "英文也能认出喜好")
	_eq(store.recent.size(), 6, "每轮记下两句原话")
	MemoryWriter.record_turn(store, "今天天气怎么样", "我喜欢你陪我。")
	_eq(store.core.size(), 3, "普通的话不进核心记忆")


func test_record_week() -> void:
	_fresh()
	GameState.week = 2
	GameState.last_earth_report = {"finished": ["发电设备", "清理", "清理"]}
	GameState.flags["first_plant"] = true
	var store := MemoryStore.new()
	var added := MemoryWriter.record_week(store)
	_eq(added.size(), 2, "完成的事和新剧情各记一条")
	_ok(_any_contains(added, "发电设备、清理"), "完成的事去重后写在一起")
	_ok(_any_contains(added, "第一株小芽"), "剧情标记变成记忆")
	GameState.week = 3
	GameState.last_earth_report = {}
	_eq(MemoryWriter.record_week(store).size(), 0, "同一个剧情标记只记一次")


func test_record_courses() -> void:
	_fresh()
	GameState.week = 3
	var results: Array[Dictionary] = []
	for course in ["mechanics", "mechanics", "ecology", "rest"]:
		results.append({"course": course, "status": CourseSystem.STATUS_NORMAL})
	results.append({"course": "rest", "status": CourseSystem.STATUS_SICK})
	var store := MemoryStore.new()
	var added := MemoryWriter.record_courses(store, results)
	_eq(added.size(), 2, "上得最多的课 + 累倒")
	_ok(_any_contains(added, "第 2 周") and _any_contains(added, Text.t("CR-NAME-01")), "记成上周的机械课")


func test_prompt_cards() -> void:
	_fresh()
	var child := ChatPrompt.build()
	_ok(child.contains("8 岁") and child.contains("你看你看"), "8 岁用幼年角色卡")
	_ok(not child.contains("{girl}") and not child.contains("{max_chars}"), "占位符都填好了")
	_ok(child.contains("最多 %d 个字" % ChatMood.max_length(ChatMood.NORMAL)), "按心情写回复长度")
	GameState.age = int(DataDB.balance("teen_age"))
	_ok(ChatPrompt.build().contains("15 岁"), "长大后用少女角色卡")
	Text.language = "en"
	var english := ChatPrompt.build()
	_ok(english.contains("15 years old") and english.contains("English only"), "英文用英文角色卡和规则")
	_ok(english.contains("at most %d words" % ChatMood.max_length(ChatMood.NORMAL)), "英文按词数限制长度")
	Text.language = Text.DEFAULT_LANGUAGE


func test_state_card() -> void:
	_fresh()
	GameState.week = 3
	GameState.last_earth_report = {"finished": ["净水站"]}
	GameState.girl_intent = "plant"
	var card := ChatPrompt.state_card()
	_ok(card.contains("第 3 周") and card.contains(Text.t("WK-09-03")), "状态卡写剧情阶段")
	_ok(card.contains(Text.t("WK-10-01")), "状态卡写她以为是游戏")
	_ok(card.contains("净水站"), "状态卡写上周小镇的事")
	_ok(card.contains(Text.t("UI-12-plant")), "状态卡写她想做的事")
	GameState.memory.remember_core("like_颜色", "我最喜欢的颜色是蓝色。", 2)
	GameState.memory.remember_event("这周有点累。", MemoryStore.KIND_REFLECTION, 2, 3, 8)
	GameState.memory.remember_line(MemoryStore.SPEAKER_PLAYER, "晚安")
	var prompt := ChatPrompt.build()
	_ok(prompt.contains("蓝色"), "核心记忆每次都带")
	_ok(prompt.contains("这周有点累"), "带上最近的感想")
	_ok(prompt.contains(GameState.player_name + "：晚安"), "带上上次聊到的原话")


func test_mood_inertia() -> void:
	_fresh()
	GameState.week = 3
	var store: MemoryStore = GameState.memory
	_eq(ChatMood.state(store), ChatMood.NORMAL, "平常心情")
	var tone: Array[String] = ["ignore", "neutral", "ignore"]
	ChatMood.remember_tone(store, tone)
	_eq(ChatMood.state(store), ChatMood.SULKY, "上次被敷衍两次，这次还在生气")
	_ok(ChatMood.hint(ChatMood.SULKY, store).contains(Text.t("WK-07-21")), "生气的理由是被敷衍")
	_ok(ChatMood.max_length(ChatMood.SULKY) < ChatMood.max_length(ChatMood.NORMAL), "生气时话更短")
	GameState.week = 5
	_ne(ChatMood.state(store), ChatMood.SULKY, "过了很久就不气了")
	GameState.week = 3
	tone = ["ignore", "comfort", "restrict", "encourage", "comfort"]
	ChatMood.remember_tone(store, tone)
	_ne(ChatMood.state(store), ChatMood.SULKY, "后来哄好了就不生气")
	store.tone.clear()
	GameState.stats["stamina"] = 10
	_eq(ChatMood.state(store), ChatMood.SLEEPY, "体力低时犯困")
	GameState.stats["stamina"] = 70
	GameState.stats["mood"] = 90
	GameState.stats["trust"] = 80
	_eq(ChatMood.state(store), ChatMood.CHEERFUL, "心情好又信任你时话多")
	GameState.stats["confidence"] = 20
	_eq(ChatMood.after_hint("encourage"), Text.t("WK-07-14"), "自信低时被夸会害羞")
	_eq(ChatMood.after_hint("neutral"), "", "普通的话没有情绪提示")


func test_turn_message() -> void:
	_fresh()
	GameState.week = 3
	GameState.memory.remember_event("第 2 周，我们种下了第一株小芽。", MemoryStore.KIND_EVENT, 3, 2, 8)
	var message := ChatPrompt.turn_message("小芽还好吗？", "", false)
	_ok(message.begins_with("小芽还好吗？"), "玩家原话在最前面")
	_ok(message.contains("第一株小芽"), "附上相关的记忆")
	_ok(message.contains(Text.t("WK-10-12")), "说明这是只有她知道的事")
	_eq(ChatPrompt.turn_message("你好", "", false), "你好", "没关系的话什么都不附")
	_ok(ChatPrompt.turn_message("你好", "ignore", true).contains(Text.t("WK-05-01")), "最后一轮附上收尾提示")
	_ok(ChatPrompt.turn_message("你好", "ignore", false).contains(Text.t("WK-07-11")), "附上上一句留下的情绪")


func test_schema_matches_tables() -> void:
	var schema: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ModelService.SCHEMA_PATH))
	var actions: Array = schema["properties"]["action"]["enum"]
	var table_actions: Array = DataDB.table("chat_actions").keys()
	actions.sort()
	table_actions.sort()
	_eq(actions, table_actions, "聊天格式的动作和 chat_actions 表一致")
	var line_schema: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ModelService.LINE_SCHEMA_PATH))
	var line_actions: Array = line_schema["properties"]["action"]["enum"]
	line_actions.sort()
	_eq(line_actions, table_actions, "一句话格式的动作和 chat_actions 表一致")
	for intent: String in schema["properties"]["intent"]["enum"]:
		if intent != "none":
			_ok(Text.t("UI-12-" + intent) != "UI-12-" + intent, "intent 有显示文字：" + intent)
	for intent in ["repair_robot", "protect", "old_power", "bridge", "transceiver"]:
		_ok((schema["properties"]["intent"]["enum"] as Array).has(intent), "补上 intent：" + intent)


func test_reply_action() -> void:
	var base := {"player_attitude": "neutral", "intent": "none", "emotion": "calm", "reply": "嗯。", "options": ["好", "不好", "换个话题"]}
	_eq(ModelService.parse_reply(JSON.stringify(base))["action"], ModelService.NO_ACTION, "没有动作当作不动")
	base["action"] = "tap_tablet"
	_eq(ModelService.parse_reply(JSON.stringify(base))["action"], "tap_tablet", "认识的动作保留")
	base["action"] = "fly"
	_eq(ModelService.parse_reply(JSON.stringify(base))["action"], ModelService.NO_ACTION, "不认识的动作当作不动")


## 没有模型时，各处"说一句"都用固定句，并且不卡住
func test_lines_fallback() -> void:
	_fresh()
	GameState.week = 2
	var morning := await ChatLines.morning()
	_eq(morning["reply"], Text.t("WK-01-01"), "第 4 周前早安用固定句")
	GameState.week = 5
	morning = await ChatLines.morning()
	_ok(morning["fallback"] and morning["reply"] == Text.t("WK-01-01"), "没模型时早安用固定句")
	var summary := await ChatLines.week_summary(PackedStringArray(["第 5 周，我们修好了净水站。"]))
	_eq(summary["reply"], Text.t("FB-04-01"), "没模型时周总结用固定句")
	_eq(GameState.memory.latest_reflection(), "", "后备句不当成她的感想")
	var idle := await ChatLines.idle("town", RandomNumberGenerator.new())
	_eq(idle["reply"], "", "没模型时主界面不主动说话")
	var lines: Array[Dictionary] = [
		{"speaker": MemoryStore.SPEAKER_PLAYER, "text": "我们明天去看温室吧"},
		{"speaker": MemoryStore.SPEAKER_GIRL, "text": "好呀"},
	]
	var note := await ChatLines.summarize(lines)
	_ok(note.contains("我们明天去看温室吧"), "没模型时摘要用玩家说的第一句")
	_eq(GameState.memory.recall("温室", 3, 5, 15).size(), 1, "聊天摘要记进记忆，之后能想起")
	var prompt := ChatLines.system_prompt()
	_ok(prompt.contains("最多 %d 个字" % int(DataDB.balance("chat_line_max_zh"))), "说一句的人设限制长度")
	_ok(not prompt.contains("options"), "说一句不要求给选项")
	_ok(not prompt.contains("你看你看！\" \"嘿嘿"), "说一句不带口头禅那一行")
	_ok(ChatPrompt.build().contains("【口头禅】"), "聊天还带口头禅")
	var plan: Array[String] = ["mechanics", "mechanics"]
	var comment := await ChatLines.schedule_comment(plan, 1, PackedStringArray(["周一", "周二"]))
	_eq(comment["reply"], Text.t("FB-04-02"), "没模型时课表评论用固定句")
	_eq(ModelService.parse_line("{\"reply\":\"早！\",\"action\":\"turn_head\"}")["action"], "turn_head", "说一句的回复能解析")
	_ok(ModelService.parse_line("{\"reply\":\"\",\"action\":\"wave\"}").is_empty(), "空的一句不要")


func test_presence_fits_age() -> void:
	_fresh()
	for age in [8, 15]:
		GameState.age = age
		var seen := {}
		for i in 30:
			var presence := ChatPresence.new()
			add_child(presence)
			var row := DataDB.row("chat_idle", presence.activity)
			_ok(not presence.activity.is_empty() and age >= int(row["min_age"]) and age <= int(row["max_age"]), "主界面做的事适合 %d 岁" % age)
			seen[presence.activity] = true
			presence.free()
		_ok(seen.size() > 1, "%d 岁做的事不止一种" % age)


func test_judge_parsing() -> void:
	_eq(ModelService.parse_judge("{\"player_attitude\":\"comfort\",\"intent\":\"rest\"}"), {"player_attitude": "comfort", "intent": "rest", "claim": "none"}, "判断结果能解析")
	_eq(ModelService.parse_judge("{\"player_attitude\":\"angry\",\"intent\":\"rest\"}"), {}, "不认识的态度不要")
	var hint := ModelService.judged_hint({"player_attitude": "restrict", "intent": "withdraw"})
	_ok(hint.contains(Text.t("WK-13-restrict")) and hint.contains(Text.t("UI-12-withdraw")), "判断结果写成提示告诉她")
	_ok(ModelService.judge_prompt().contains(GameState.player_name), "判断提示填上名字")


func test_event_rules() -> void:
	_fresh()
	var event := DataDB.row("earth_events", "ark_failure")
	GameState.stats["trust"] = 20
	_eq(ChatEvent.rounds_for(), 2, "信任低时突发事件聊 2 轮")
	GameState.stats["trust"] = 50
	_eq(ChatEvent.rounds_for(), 3, "信任普通时聊 3 轮")
	GameState.stats["trust"] = 80
	_eq(ChatEvent.rounds_for(), 4, "信任高时聊 4 轮")
	var intents: Array[String] = ["continue", "none"]
	_eq(ChatEvent.final_intent(event, intents), "continue", "最后一轮没说清楚，就看前一轮")
	intents = ["none", "plant"]
	_eq(ChatEvent.final_intent(event, intents), "withdraw", "一直没说清楚就按最稳妥的第三个选项")
	intents = ["ask_help", "withdraw"]
	_eq(ChatEvent.final_intent(event, intents), "withdraw", "按最后一轮的 intent")
	_ok(not ChatEvent.opening_text(event).begins_with(GameState.girl_name), "她开口的话去掉名字前缀")
	_ok(ChatPrompt.build(ChatEvent.situation(event, "怎么办", 3)).contains("怎么办"), "人设里写上发生了什么")


## 没有模型时也能把突发事件聊完：点固定选项，按最后一次点的结果执行，游戏暂停后恢复
func test_event_chat_flow() -> void:
	_fresh()
	GameState.stats["trust"] = 20
	var event := DataDB.row("earth_events", "danger_zone")
	var panel := ChatEventPanel.new(event)
	var result := {"intent": ""}
	panel.finished.connect(func(intent: String) -> void: result["intent"] = intent)
	add_child(panel)
	_ok(get_tree().paused, "突发事件对话时游戏暂停")
	for i in 10:
		await get_tree().process_frame
	panel._on_option(0)
	for i in 10:
		await get_tree().process_frame
	panel._on_option(1)
	for i in 10:
		await get_tree().process_frame
	_eq(result["intent"], "investigate", "两轮后按最后点的选项执行")
	_ok(not get_tree().paused, "聊完游戏恢复")
	_ok(_any_contains(_event_texts(), Text.t("UI-12-investigate")), "这件事记进她的记忆")


func _event_texts() -> PackedStringArray:
	var texts := PackedStringArray()
	for memory: Dictionary in GameState.memory.events:
		texts.append(str(memory["text"]))
	return texts


func test_childhood_after_jump() -> void:
	_fresh()
	GameState.memory.remember_event("第 2 周，我们种下了第一株小芽。", MemoryStore.KIND_EVENT, 3, 2, 8)
	GameState.memory.remember_event("第 3 周，我上得最多的是机械课。", MemoryStore.KIND_EVENT, 1, 3, 8)
	GameState.age = int(DataDB.balance("teen_age"))
	GameState.week = int(DataDB.balance("timejump_after_week")) + 1
	_ok(ChatPrompt.build().contains("第一株小芽"), "刚长大那周，她心里记着小时候最重要的事")
	GameState.week += 1
	_ok(not ChatPrompt.build().contains("第一株小芽"), "之后不再每次都带")


func test_copied_memory() -> void:
	_fresh()
	GameState.memory.remember_event("哇！净水站建好了呀，嘿嘿。", MemoryStore.KIND_REFLECTION, 2, 2, 8)
	_ok(ChatLines.is_copied("哇！净水站建好了呀，嘿嘿。"), "原样念记忆算抄")
	_ok(ChatLines.is_copied("嗯，哇！净水站建好了呀，嘿嘿。你看！"), "整条记忆抄进来也算")
	_ok(not ChatLines.is_copied("净水站终于好了！"), "用自己的话说不算抄")


func test_claims() -> void:
	_fresh()
	_eq(ModelService.parse_judge("{\"player_attitude\":\"neutral\",\"claim\":\"false\",\"intent\":\"none\"}")["claim"], "false", "能读出玩家说的往事对不对")
	_eq(ModelService.parse_judge("{\"player_attitude\":\"neutral\",\"intent\":\"none\"}")["claim"], "none", "没写就当不是在说往事")
	var judged := {"player_attitude": "neutral", "intent": "none", "claim": "false"}
	_ok(ModelService.judged_hint(judged, "材料少了三箱。").contains("材料少了三箱"), "玩家说错时告诉她真实的是什么")
	judged["claim"] = "true"
	_ok(ModelService.judged_hint(judged).contains(Text.t("WK-15-11")), "玩家说对时让她承认记混了")
	judged["claim"] = "unknown"
	_ok(ModelService.judged_hint(judged).contains(Text.t("WK-15-13")), "没这回事时让她说不记得")
	GameState.memory.remember_core("like_颜色", "我最喜欢的颜色是天蓝色。", 2)
	GameState.memory.remember_event("第 5 周，堆好的材料少了三箱。", MemoryStore.KIND_EVENT, 2, 5, 15)
	_eq(ChatPrompt.facts_for("这周先把发电机修好吧。"), "", "不是在说往事就不核对")
	var facts := ChatPrompt.facts_for("材料少了五箱，你记错了吧？")
	_ok(facts.contains("三箱") and facts.contains("天蓝色"), "真实记录 = 核心记忆 + 相关记忆")
	_eq(ChatPrompt.top_fact("材料少了五箱吧？"), "第 5 周，堆好的材料少了三箱。", "最相关的一条真实记忆")
	_eq(ChatPrompt.facts_for("你好").find("三箱"), -1, "不相关的事件不当证据")
	_eq(ChatPrompt.top_fact("你说过你最喜欢红色"), "我最喜欢的颜色是天蓝色。", "说起喜好时用核心记忆核对")
	_eq(ChatPrompt.top_fact("上次你说你会弹钢琴"), "", "没有相关记忆就没有证据")
	MemoryWriter.record_correction(GameState.memory, "被挖走的是净水站旁边的苗")
	_eq(GameState.memory.recall("苗被挖走", 1, GameState.week, GameState.age).size(), 1, "提醒记下来，之后想得起")


## 剧情选项下的自由聊天：只能说一次，不占聊天轮数；没模型时用后备句、不改数值
func test_story_free_talk() -> void:
	_fresh()
	GameState.week = 2
	var rounds := WeekSystem.chat_rounds_left()
	var before := GameState.stats.duplicate()
	var talk := ChatStoryInput.new("地球上真的有人吗？")
	var got := {"text": ""}
	talk.replied.connect(func(text: String) -> void: got["text"] = text)
	add_child(talk)
	await talk.submit("我也不知道，我们一起去看看。")
	_eq(got["text"], Text.t("FB-01-01"), "没模型时她回后备句")
	_ok(talk.is_used(), "说过一次就不能再说")
	got["text"] = ""
	await talk.submit("再说一句")
	_eq(got["text"], "", "第二句不会发出去")
	_eq(WeekSystem.chat_rounds_left(), rounds, "不占每周聊天轮数")
	_eq(GameState.stats, before, "后备句不改数值")
	talk.free()


# ---------- 工具 ----------

func _fresh() -> void:
	GameState.reset()
	Text.language = Text.DEFAULT_LANGUAGE


func _any_contains(lines: PackedStringArray, part: String) -> bool:
	for line in lines:
		if line.contains(part):
			return true
	return false


func _ok(condition: bool, message: String) -> void:
	_count += 1
	if not condition:
		_failures += 1
		print("失败：" + message)


func _ne(actual: Variant, other: Variant, message: String) -> void:
	_count += 1
	if actual == other:
		_failures += 1
		print("失败：%s，不应该是 %s" % [message, str(other)])


func _eq(actual: Variant, expected: Variant, message: String) -> void:
	_count += 1
	if actual != expected:
		_failures += 1
		print("失败：%s，应该是 %s，实际 %s" % [message, str(expected), str(actual)])
