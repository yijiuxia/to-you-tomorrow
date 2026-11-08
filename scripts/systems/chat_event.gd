class_name ChatEvent
extends RefCounted
## 突发事件对话的规则（比赛版 4.3）：她先开口描述情况，聊 2～4 轮（信任高聊得久），
## 结束后按最后一轮的 intent 执行结果。事件本身（条件、概率、结果）在地球线程的 GirlEarth 里。

const OPTION_COUNT := 3


## 聊几轮：基础 + 信任高 / 普通时加轮，截断在范围内
static func rounds_for() -> int:
	var rounds := int(DataDB.balance("chat_event_rounds_min"))
	if GameState.is_high("trust"):
		rounds += 2
	elif not GameState.is_low("trust"):
		rounds += 1
	return clampi(rounds, int(DataDB.balance("chat_event_rounds_min")), int(DataDB.balance("chat_event_rounds_max")))


## 这个事件认哪些结果（就是三个选项对应的 intent）
static func valid_intents(event: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for i in range(1, OPTION_COUNT + 1):
		result.append(str(event["option%d_intent" % i]))
	return result


## 三个固定选项：[文字, intent]。第一轮给玩家点，点了就知道是哪个结果，不用猜
static func options(event: Dictionary) -> Array:
	var result: Array = []
	for i in range(1, OPTION_COUNT + 1):
		result.append([Text.t(str(event["option%d_key" % i])), str(event["option%d_intent" % i])])
	return result


## 最后的结果：从最后一轮往前找第一个这个事件认的 intent；
## 一直没说清楚就按第三个选项（表里第三个都是最稳妥的：休息 / 撤回 / 不去）
static func final_intent(event: Dictionary, intents: Array[String]) -> String:
	var valid := valid_intents(event)
	for i in range(intents.size() - 1, -1, -1):
		if valid.has(intents[i]):
			return intents[i]
	return valid[OPTION_COUNT - 1]


## 她先开口那句的固定版本（去掉"朝禾："前缀，模型改写失败时显示它）
static func opening_text(event: Dictionary) -> String:
	return strip_name(Text.t(str(event["say_key"])))


## 地球线程的固定句带着"她的名字："，给模型看或换成她的话时要去掉
static func strip_name(text: String) -> String:
	for mark in ["：", ": "]:
		var prefix: String = GameState.girl_name + mark
		if text.begins_with(prefix):
			return text.substr(prefix.length())
	return text


## 这次对话的额外人设：发生了什么、她已经说了什么、要在几轮内说完
static func situation(event: Dictionary, opening: String, rounds: int) -> String:
	return Text.f("WK-14-01", {"event": opening_text(event), "said": opening, "rounds": rounds})
