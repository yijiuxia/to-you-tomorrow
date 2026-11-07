class_name ChatRules
extends RefCounted
## 聊天的数值规则（比赛版 4.3）。模型只给标签，这里决定数值怎么变。

const SUPPORTIVE: Array[String] = ["encourage", "comfort"]
const EFFECT_STATS: Array[String] = ["confidence", "trust", "mood"]


## 本周能聊几轮 = 基础 + 信任 ÷ 除数 + 心情加成 − 体力减成，再截断到范围内
static func rounds_for(stats: Dictionary) -> int:
	var rounds := int(DataDB.balance("chat_rounds_base"))
	rounds += int(stats["trust"]) / int(DataDB.balance("chat_rounds_trust_divisor"))
	if int(stats["mood"]) >= int(DataDB.balance("chat_rounds_mood_bonus_at")):
		rounds += 1
	if int(stats["stamina"]) < int(DataDB.balance("low_stamina")):
		rounds -= 1
	return clampi(rounds, int(DataDB.balance("chat_rounds_min")), int(DataDB.balance("chat_rounds_max")))


## 算这一轮要改哪些属性。used 记录本周已变化的量，每个属性累计不超过封顶。
## 策划说"一次聊天"封顶；轮数可以分几次用完，所以按整周算，否则反复开关聊天就能刷数值。
static func round_changes(attitude: String, words: String, used: Dictionary) -> Dictionary:
	var wanted := {}
	var effect := DataDB.row("attitude_effects", attitude)
	for id in EFFECT_STATS:
		var delta := int(effect.get(id, 0))
		if delta != 0:
			wanted[id] = delta
	if SUPPORTIVE.has(attitude):
		for key: String in DataDB.table("chat_keywords"):
			var row := DataDB.row("chat_keywords", key)
			if _contains_any(words, str(row["words"]).split("|")):
				var id := str(row["stat"])
				wanted[id] = int(wanted.get(id, 0)) + 1

	var cap := int(DataDB.balance("chat_change_cap"))
	var result := {}
	for id: String in wanted:
		var so_far := int(used.get(id, 0))
		var allowed := clampi(so_far + int(wanted[id]), -cap, cap) - so_far
		if allowed != 0:
			result[id] = allowed
			used[id] = so_far + allowed
	return result


static func _contains_any(text: String, words: PackedStringArray) -> bool:
	for word in words:
		if not word.is_empty() and text.contains(word):
			return true
	return false
