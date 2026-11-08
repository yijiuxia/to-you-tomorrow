class_name MemoryStore
extends RefCounted
## 她的记忆（比赛版 4.5：分层记忆 + 记忆流）。只存和取，不调模型，所以能直接测试。
## - 核心记忆 core：喜好、和你的约定。每次聊天都带上，让她前后一致。
## - 事件记忆 events：每周发生的事、她的感想（反思）、聊天摘要。按相关度挑几条带上。
## - 最近的话 recent：最近几轮对话原文。每次聊天会清空模型的对话历史，靠它接上上次聊到哪。
## 存档时用 to_dict / from_dict。

const KIND_EVENT := "event"
const KIND_REFLECTION := "reflection"
const KIND_SUMMARY := "summary"
const SPEAKER_PLAYER := "player"
const SPEAKER_GIRL := "girl"
const STOPWORDS_PATH := "res://text/prompts/memory_stopwords.txt"
const CJK_FIRST := 0x4E00
const CJK_LAST := 0x9FFF
const MIN_ENGLISH_WORD := 4

static var _stopwords: PackedStringArray = []

var core: Array[Dictionary] = []    # { key, text, week }
var events: Array[Dictionary] = []  # { week, age, kind, text, topics, importance }
var recent: Array[Dictionary] = []  # { speaker, text }
var tone: Array[String] = []        # 上一次聊天里玩家每轮的态度，情绪惯性用（ChatMood）
var tone_week := 0                  # tone 是第几周记下的
var noted_flags: Array[String] = [] # 已经记成记忆的剧情标记，不重复记
var lies_week := 0                  # 玩家乱说的次数是第几周数的
var lies_count := 0                 # 这周玩家说了几次不对的往事


## 记一条核心记忆。key 相同的会被替换：她改口说最喜欢别的颜色，就记新的
func remember_core(key: String, text: String, week: int) -> void:
	for item in core:
		if item["key"] == key:
			item["text"] = text
			item["week"] = week
			return
	core.append({"key": key, "text": text, "week": week})
	# 太多会挤占提示词，去掉最早的
	while core.size() > int(DataDB.balance("memory_core_max")):
		core.pop_front()


## 记一条事件记忆。话题标签用世界书的关键词算，取用时按它比较相关度
func remember_event(text: String, kind: String, importance: int, week: int, age: int) -> void:
	if text.strip_edges().is_empty():
		return
	events.append({
		"week": week,
		"age": age,
		"kind": kind,
		"text": text.strip_edges(),
		"topics": ChatWorldbook.topics(text),
		"importance": importance,
	})
	# 最旧、最不重要的先忘
	while events.size() > int(DataDB.balance("memory_events_max")):
		var weakest := 0
		for i in events.size():
			if int(events[i]["importance"]) < int(events[weakest]["importance"]):
				weakest = i
		events.remove_at(weakest)


func remember_line(speaker: String, text: String) -> void:
	recent.append({"speaker": speaker, "text": text.strip_edges()})
	while recent.size() > int(DataDB.balance("memory_recent_lines")):
		recent.pop_front()


## 按相关度取最多 count 条（比赛版 4.5，借鉴 Generative Agents：相关度 + 新旧 + 重要程度）。
## 只取和这句话有关的；一条都不相关时宁可不带，小模型被无关的记忆带偏比忘了更糟。
## 15 岁时聊到相关话题，8 岁时的事额外加分，她会提起小时候（时间跳跃后的要求）。
func recall(query: String, count: int, now_week: int, now_age: int) -> Array[Dictionary]:
	var query_topics := ChatWorldbook.topics(query)
	var query_words := words_of(query)
	var scored: Array[Dictionary] = []
	for memory in events:
		var relevance := relevance_of(memory, query_topics, query_words)
		if relevance < float(DataDB.balance("memory_min_relevance")):
			continue
		var score := relevance
		score += int(memory["importance"]) * float(DataDB.balance("memory_importance_weight"))
		var weeks_ago := now_week - int(memory["week"])
		score += maxf(0.0, float(DataDB.balance("memory_recent_bonus")) - weeks_ago * float(DataDB.balance("memory_recent_decay")))
		if int(memory["age"]) < now_age:
			score += float(DataDB.balance("memory_childhood_bonus"))
		scored.append({"memory": memory, "score": score})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["score"] > b["score"])
	var result: Array[Dictionary] = []
	for item in scored.slice(0, count):
		result.append(item["memory"])
	return result


## 相关度 = 共同话题数 × 权重 + 共同词数 × 权重（词数有上限，长句子不占便宜）
func relevance_of(memory: Dictionary, query_topics: PackedStringArray, query_words: PackedStringArray) -> float:
	var topic_hits := 0
	for topic in query_topics:
		if (memory["topics"] as PackedStringArray).has(topic):
			topic_hits += 1
	var word_hits := 0
	var text := str(memory["text"]).to_lower()
	for word in query_words:
		if text.contains(word):
			word_hits += 1
	word_hits = mini(word_hits, int(DataDB.balance("memory_word_cap")))
	return topic_hits * float(DataDB.balance("memory_topic_weight")) + word_hits * float(DataDB.balance("memory_word_weight"))


## 最近一条感想，开聊时让她"心里还想着"，她会主动提起过去的事
func latest_reflection() -> String:
	for i in range(events.size() - 1, -1, -1):
		if events[i]["kind"] == KIND_REFLECTION:
			return events[i]["text"]
	return ""


## 把一句话拆成用来比较的词：中文取相邻两个字，英文取单词。去掉"我们""你的"这种到处都有的词
static func words_of(text: String) -> PackedStringArray:
	var result := PackedStringArray()
	var lower := text.to_lower()
	var english := ""
	for i in lower.length():
		var code := lower.unicode_at(i)
		if _is_cjk(code) and i + 1 < lower.length() and _is_cjk(lower.unicode_at(i + 1)):
			_add_word(result, lower.substr(i, 2))
		if (code >= 97 and code <= 122) or code == 39:  # a-z 和撇号
			english += lower[i]
		else:
			_add_word(result, english)
			english = ""
	_add_word(result, english)
	return result


static func _add_word(list: PackedStringArray, word: String) -> void:
	var is_short_english := not word.is_empty() and not _is_cjk(word.unicode_at(0)) and word.length() < MIN_ENGLISH_WORD
	if word.is_empty() or is_short_english or list.has(word) or stopwords().has(word):
		return
	list.append(word)


static func _is_cjk(code: int) -> bool:
	return code >= CJK_FIRST and code <= CJK_LAST


static func stopwords() -> PackedStringArray:
	if _stopwords.is_empty():
		for line in FileAccess.get_file_as_string(STOPWORDS_PATH).split("\n", false):
			var word := line.strip_edges().to_lower()
			if not word.is_empty() and not word.begins_with("#"):
				_stopwords.append(word)
	return _stopwords


func to_dict() -> Dictionary:
	return {"core": core, "events": events, "recent": recent, "tone": tone, "tone_week": tone_week, "noted_flags": noted_flags, "lies_week": lies_week, "lies_count": lies_count}


static func from_dict(data: Dictionary) -> MemoryStore:
	var store := MemoryStore.new()
	for item: Dictionary in data.get("core", []):
		store.core.append(item)
	for item: Dictionary in data.get("events", []):
		var copy := item.duplicate()
		copy["topics"] = PackedStringArray(item.get("topics", []))
		store.events.append(copy)
	for item: Dictionary in data.get("recent", []):
		store.recent.append(item)
	for attitude: String in data.get("tone", []):
		store.tone.append(attitude)
	store.tone_week = int(data.get("tone_week", 0))
	for flag: String in data.get("noted_flags", []):
		store.noted_flags.append(flag)
	store.lies_week = int(data.get("lies_week", 0))
	store.lies_count = int(data.get("lies_count", 0))
	return store
