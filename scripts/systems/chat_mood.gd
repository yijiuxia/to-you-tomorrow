class_name ChatMood
extends RefCounted
## 情绪惯性（比赛版 4.5）：上次聊天你凶了她、敷衍她，这次她还记着；累了、心情差话就少。
## 只决定"提示模型用什么语气、说多长"，不改任何数值。

const NEGATIVE: Array[String] = ["ignore", "restrict"]
const POSITIVE: Array[String] = ["encourage", "comfort"]
const SULKY := "sulky"
const SLEEPY := "sleepy"
const DOWN := "down"
const GUARDED := "guarded"
const CHEERFUL := "cheerful"
const NORMAL := "normal"


## 开聊时的心情，按顺序判断：闹脾气 > 困 > 低落 > 戒备 > 开心 > 平常
static func state(store: MemoryStore) -> String:
	if is_sulky(store):
		return SULKY
	if GameState.get_stat("stamina") < int(DataDB.balance("low_stamina")):
		return SLEEPY
	if GameState.get_stat("mood") < int(DataDB.balance("low_mood")):
		return DOWN
	if GameState.is_low("trust"):
		return GUARDED
	if GameState.get_stat("mood") >= int(DataDB.balance("chat_cheerful_mood")) and GameState.is_high("trust"):
		return CHEERFUL
	return NORMAL


## 上次聊天（不太久以前）被凶或被敷衍的次数够多，而且多过被夸被安慰的次数，就还在生气
static func is_sulky(store: MemoryStore) -> bool:
	if store.tone.is_empty() or GameState.week - store.tone_week > int(DataDB.balance("chat_sulk_weeks")):
		return false
	var bad := _count(store.tone, NEGATIVE)
	return bad >= int(DataDB.balance("chat_sulk_min")) and bad > _count(store.tone, POSITIVE)


## 这个心情下回复最多多长：中文按字，英文按词
static func max_length(mood: String) -> int:
	var row := DataDB.row("chat_moods", mood)
	return int(row.get("max_en" if Text.language == "en" else "max_zh", 0))


static func hint(mood: String, store: MemoryStore) -> String:
	var row := DataDB.row("chat_moods", mood)
	var reason := ""
	if mood == SULKY:
		# 主要是被敷衍还是被管着，生气的理由不一样
		reason = Text.t("WK-07-21") if store.tone.count("ignore") >= store.tone.count("restrict") else Text.t("WK-07-22")
	return Text.f(str(row["hint_key"]), {"reason": reason})


## 上一句玩家的态度在她心里留下的感觉，跟着下一句话发给模型，让情绪接得上
static func after_hint(attitude: String) -> String:
	match attitude:
		"ignore":
			return Text.t("WK-07-11")
		"restrict":
			return Text.t("WK-07-12") if GameState.is_high("confidence") else Text.t("WK-07-13")
		"encourage":
			return Text.t("WK-07-14") if GameState.is_low("confidence") else Text.t("WK-07-15")
		"comfort":
			return Text.t("WK-07-16")
	return ""


## 每轮聊完更新"这次聊天的态度"。中途离开也算数，下次开聊时据此判断要不要闹脾气
static func remember_tone(store: MemoryStore, attitudes: Array[String]) -> void:
	store.tone = attitudes.duplicate()
	store.tone_week = GameState.week


static func _count(list: Array[String], wanted: Array[String]) -> int:
	var n := 0
	for item in list:
		if wanted.has(item):
			n += 1
	return n
