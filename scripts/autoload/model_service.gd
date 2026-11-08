extends Node
## 模型服务（自动加载，名字 ModelService）：加载模型、发话、检查回复。
## 任何失败（没模型、超时、回复不合格式）都不会中断游戏，一律退回 FB- 后备句。

const SCHEMA_PATH := "res://data/model_output_schema.json"
const LINE_SCHEMA_PATH := "res://data/model_line_schema.json"
const JUDGE_SCHEMA_PATH := "res://data/model_judge_schema.json"
const MODELS_DIR := "models"
const REQUIRED_KEYS: Array[String] = ["reply", "emotion", "player_attitude", "intent", "options"]
const NO_ACTION := "none"
const OPTION_COUNT := 3
const POLL_SEC := 0.05
const LEADING_PUNCTUATION := ",，.。、;；:：!！?？/ "
## 模型有时把 JSON 碎片或转义符写进文字里，这种选项不能给玩家看
const JUNK_PATTERN := "[{}\\[\\]<>`\\\\]|/n|reply|json"

enum Status { NOT_LOADED, LOADING, READY, FAILED }

var status := Status.NOT_LOADED
var _model: NobodyWhoModel = null
var _chat: NobodyWhoChat = null        # 聊天：带完整格式（态度、intent、选项）
var _line_chat: NobodyWhoChat = null   # 说一句：只要文字和动作
var _line_busy := false
var _judge_chat: NobodyWhoChat = null  # 判断：只判断态度和 intent，不带人设
var _judge_prompt_used := ""
var _junk := RegEx.create_from_string(JUNK_PATTERN)
var _stuck := false  # 超时后叫它停也停不下来
var _said: Array[String] = []  # 这段对话里双方说过的话
var last_action := NO_ACTION    # 她最近一句话的动作标签，有模型后（模块 9）播放对应动画


## 启动时在后台加载。可以多次调用，只会加载一次。
func ensure_loaded() -> void:
	if status != Status.NOT_LOADED:
		return
	var path := model_path()
	if not FileAccess.file_exists(path):
		push_warning("找不到模型文件，聊天会用后备句：" + path)
		status = Status.FAILED
		return
	status = Status.LOADING
	# 模型只加载一次，聊天和"说一句"共用；两者格式不同，所以各开一个对话
	_model = await NobodyWhoModel.create(path, {})
	if _model != null:
		_chat = await NobodyWhoChat.create(_model, _chat_config(SCHEMA_PATH))
		_line_chat = await NobodyWhoChat.create(_model, _chat_config(LINE_SCHEMA_PATH))
		if int(DataDB.balance("model_separate_judge")) == 1:
			var judge_config := _chat_config(JUDGE_SCHEMA_PATH)
			_judge_prompt_used = judge_prompt()
			judge_config["system_prompt"] = _judge_prompt_used
			_judge_chat = await NobodyWhoChat.create(_model, judge_config)
	status = Status.READY if _chat != null and _line_chat != null else Status.FAILED


func _chat_config(schema_path: String) -> Dictionary:
	return {
		"sampler": make_sampler(schema_path),
		"n_ctx": int(DataDB.balance("model_context_tokens")),
		# 新版 Qwen 默认会先"思考"一大段，游戏要快速回复，所以关掉；不支持的模型会忽略
		"template_variables": {"enable_thinking": false},
	}


## 控制模型怎么选字。默认设置下同样的话总得到同样的回答，所以每次开游戏换一个随机种子，
## 并加上重复惩罚。--seed= 可以固定种子，方便测试时复现结果。
static func make_sampler(schema_path := SCHEMA_PATH) -> NobodyWhoSamplerConfig:
	var seed_value := randi()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			seed_value = arg.trim_prefix("--seed=").to_int()
	var builder := NobodyWhoSamplerBuilder.new()
	builder = builder.json_schema(FileAccess.get_file_as_string(schema_path))
	builder = builder.penalties(int(DataDB.balance("model_repeat_window")), float(DataDB.balance("model_repeat_penalty")), 0.0, 0.0)
	builder = builder.top_k(int(DataDB.balance("model_top_k")))
	builder = builder.top_p(float(DataDB.balance("model_top_p")), 1)
	builder = builder.temperature(float(DataDB.balance("model_temperature")))
	builder = builder.seed(seed_value)
	return builder.dist()


## 模型文件路径：--model= 优先（方便测试换模型）；否则看 models 文件夹，
## 编辑器里在项目文件夹，打包后在游戏程序旁边（模型太大，不打进游戏包）。
func model_path() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--model="):
			return arg.trim_prefix("--model=")
	var base := ProjectSettings.globalize_path("res://")
	if not OS.has_feature("editor"):
		base = OS.get_executable_path().get_base_dir()
	return base.path_join(MODELS_DIR).path_join(str(DataDB.balance("model_file")))


## 开始一段新对话：清空历史，设置人设
func start_conversation(system_prompt: String) -> void:
	await _wait_until_loaded()
	_said.clear()
	if status == Status.READY:
		_chat.set_system_prompt(system_prompt)
		_chat.reset_history()


## 发一句话，总会返回一份合格的回复。失败时 fallback 为 true。
## 连续超时说明模型卡死了，之后不再等它，这一局聊天都用后备句，不让玩家反复干等。
## text 是发给模型的整段话（玩家原话 + 附带的记忆和提示）；player_text 是玩家原话，用来判断态度。
## known：已经知道的判断结果（玩家点了突发事件的固定选项），有就不用再判断。
func ask(text: String, player_text := "", known := {}) -> Dictionary:
	await _wait_until_loaded()
	if status != Status.READY:
		return fallback_reply()
	var said := player_text if not player_text.is_empty() else text
	# 先单独判断态度和 intent：人设写得越生动，小模型边演边判断越不准（实测从 36/50 掉到 22/50），
	# 分开判断能保住准确度。判断结果告诉她，让回复和判断一致。微调后可以在 balance 里关掉
	var judged: Dictionary = known.duplicate()
	if not judged.is_empty():
		text += "\n" + judged_hint(judged)
	elif int(DataDB.balance("model_separate_judge")) == 1:
		judged = await judge(said)
		if not judged.is_empty():
			text += "\n" + judged_hint(judged)
	for _attempt in 1 + int(DataDB.balance("model_retries")):
		var raw := await _generate_with(_chat, text, float(DataDB.balance("model_timeout_sec")))
		var parsed := parse_reply(raw)
		# 和这段对话里说过的话一字不差就不要，再生成一次
		if not parsed.is_empty() and not _said.has(str(parsed["reply"]).strip_edges()):
			parsed.merge(judged, true)
			_said.append(said.strip_edges())
			_said.append(str(parsed["reply"]).strip_edges())
			_replace_said_options(parsed)
			return parsed
		if _stuck:
			status = Status.FAILED
			push_warning("模型卡死，之后的聊天用后备句")
			break
	return fallback_reply()


## 玩家开口时模型可能还在加载，先等一等，不要直接给后备句；但也不能无限等
func _wait_until_loaded() -> void:
	var start := Time.get_ticks_msec()
	var limit := float(DataDB.balance("model_load_timeout_sec"))
	while status == Status.LOADING and _seconds_since(start) < limit:
		await get_tree().create_timer(POLL_SEC).timeout
	if status == Status.LOADING:
		push_warning("模型加载超时，这次聊天用后备句")


## 只判断玩家这句话的态度和 intent，用一段不带人设的短提示。失败返回空字典（就用聊天里顺带的判断）
func judge(player_text: String) -> Dictionary:
	if _judge_chat == null:
		return {}
	# 名字和语言可能在加载后才改（起名、设置），变了才重设人设，省得每次重算
	var prompt := judge_prompt()
	if prompt != _judge_prompt_used:
		_judge_chat.set_system_prompt(prompt)
		_judge_prompt_used = prompt
	_judge_chat.reset_history()
	var raw := await _generate_with(_judge_chat, player_text, float(DataDB.balance("model_timeout_sec")))
	return parse_judge(raw)


static func parse_judge(raw: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(raw)
	if not parsed is Dictionary or not (parsed as Dictionary).has("player_attitude") or not (parsed as Dictionary).has("intent"):
		return {}
	if not DataDB.table("attitude_effects").has(str(parsed["player_attitude"])):
		return {}
	return {"player_attitude": str(parsed["player_attitude"]), "intent": str(parsed["intent"])}


static func judge_prompt() -> String:
	var template := FileAccess.get_file_as_string("res://text/prompts/judge_%s.txt" % Text.language)
	return template.format({"girl": GameState.girl_name, "player": GameState.player_name})


## 把判断结果写成一句提示，跟着玩家的话发给她
static func judged_hint(judged: Dictionary) -> String:
	var intent := str(judged["intent"])
	var wants := Text.t("WK-13-10") if intent == "none" else Text.f("WK-13-11", {"intent": Text.t("UI-12-" + intent)})
	return Text.f("WK-13-01", {"attitude": Text.t("WK-13-" + str(judged["player_attitude"])), "wants": wants})


## 让她"说一句"（早安、周总结、课表评论、主动开口……）：每次单独设人设，不接着聊天的历史。
## 返回 {reply, action, fallback}。失败时用 fallback_text，绝不让玩家干等。
func say_line(system_prompt: String, request: String, fallback_text: String) -> Dictionary:
	var fallback := {"reply": fallback_text, "action": NO_ACTION, "fallback": true}
	await _wait_until_loaded()
	if status != Status.READY:
		return fallback
	await _wait_turn()
	_line_busy = true
	_line_chat.set_system_prompt(system_prompt)
	_line_chat.reset_history()
	var raw := await _generate_with(_line_chat, request, float(DataDB.balance("model_line_timeout_sec")))
	_line_busy = false
	if _stuck:
		status = Status.FAILED
		push_warning("模型卡死，之后都用后备句")
	var parsed := parse_line(raw)
	return fallback if parsed.is_empty() else parsed


## "说一句"的回复只要文字和动作；文字为空或带格式碎片就不要
func parse_line(raw: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(raw)
	if not parsed is Dictionary:
		return {}
	var reply := str((parsed as Dictionary).get("reply", "")).strip_edges()
	if reply.is_empty() or _junk.search(reply) != null:
		return {}
	var action := str((parsed as Dictionary).get("action", NO_ACTION))
	if not DataDB.table("chat_actions").has(action):
		action = NO_ACTION
	return {"reply": reply, "action": action, "fallback": false}


## 同一时间只让一个"说一句"在跑：主界面闲聊和周总结可能同时要，排队比抢显卡更稳
func _wait_turn() -> void:
	while _line_busy:
		await get_tree().create_timer(POLL_SEC).timeout


## 用聊天的对话生成（流程测试的超时测试在用）
func _generate(text: String, timeout_sec: float) -> String:
	return await _generate_with(_chat, text, timeout_sec)


## 边收边等，超时就让模型停下。返回收到的全部文字；超时返回空字符串。
func _generate_with(chat: NobodyWhoChat, text: String, timeout_sec: float) -> String:
	var job := {"done": false, "text": ""}
	_stream_into(chat, text, job)
	# 用真实时间算：模型占满显卡时画面会掉帧，按帧累加的话"30 秒"可能变成几十分钟
	var start := Time.get_ticks_msec()
	while not job["done"]:
		await get_tree().create_timer(POLL_SEC).timeout
		if _seconds_since(start) >= timeout_sec:
			chat.stop_generation()
			# 让它停下来也限时等，否则插件万一不响应，游戏会一直卡在"她正在想"
			var stop_start := Time.get_ticks_msec()
			var stop_limit := float(DataDB.balance("model_stop_wait_sec"))
			while not job["done"] and _seconds_since(stop_start) < stop_limit:
				await get_tree().create_timer(POLL_SEC).timeout
			_stuck = not job["done"]
			return ""
	return job["text"]


func _seconds_since(start_msec: int) -> float:
	return (Time.get_ticks_msec() - start_msec) / 1000.0


func _stream_into(chat: NobodyWhoChat, text: String, job: Dictionary) -> void:
	var stream: NobodyWhoTokenStream = chat.ask(text)
	while true:
		var token: Variant = await stream.next_token()
		if token == null:
			break
		job["text"] += str(token)
	job["done"] = true


## 检查回复：能解析、字段齐全、文字不为空。选项里的乱码换成后备选项。
## 不合格返回空字典。
func parse_reply(raw: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(raw)
	if not parsed is Dictionary:
		return {}
	var data: Dictionary = parsed
	for key in REQUIRED_KEYS:
		if not data.has(key):
			return {}
	var options: Variant = data["options"]
	if not options is Array or options.size() != OPTION_COUNT:
		return {}
	if str(data["reply"]).strip_edges().is_empty():
		return {}
	var clean: Array[String] = []
	for i in OPTION_COUNT:
		var option := str(options[i]).strip_edges().lstrip(LEADING_PUNCTUATION)
		var unusable := option.is_empty() or _junk.search(option) != null or option == str(data["reply"]).strip_edges()
		clean.append(_fallback_option(i) if unusable else option)
	data["options"] = clean
	# 动作标签可以没有（旧提示词、微调前的数据），没有或不认识就当"不动"
	if not DataDB.table("chat_actions").has(str(data.get("action", ""))):
		data["action"] = NO_ACTION
	data["fallback"] = false
	return data


## 已经说过的话不再当选项，否则玩家会被引着一遍遍说同一句
func _replace_said_options(data: Dictionary) -> void:
	var options: Array[String] = data["options"]
	for i in OPTION_COUNT:
		if _said.has(options[i]):
			options[i] = _fallback_option(i)


func fallback_reply() -> Dictionary:
	var options: Array[String] = []
	for i in OPTION_COUNT:
		options.append(_fallback_option(i))
	return {
		"reply": Text.t("FB-01-01"),
		"emotion": "calm",
		"player_attitude": "neutral",
		"intent": "none",
		"action": NO_ACTION,
		"options": options,
		"fallback": true,
	}


func _fallback_option(index: int) -> String:
	return Text.t("FB-02-%02d" % (index + 1))
