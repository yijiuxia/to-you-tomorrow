extends Node
## 模型服务（自动加载，名字 ModelService）：加载模型、发话、检查回复。
## 任何失败（没模型、超时、回复不合格式）都不会中断游戏，一律退回 FB- 后备句。

const SCHEMA_PATH := "res://data/model_output_schema.json"
const MODELS_DIR := "models"
const REQUIRED_KEYS: Array[String] = ["reply", "emotion", "player_attitude", "intent", "options"]
const OPTION_COUNT := 3
const POLL_SEC := 0.05
## 模型有时把 JSON 碎片或转义符写进文字里，这种选项不能给玩家看
const JUNK_PATTERN := "[{}\\[\\]<>`\\\\]|/n|reply|json"

enum Status { NOT_LOADED, LOADING, READY, FAILED }

var status := Status.NOT_LOADED
var _chat: NobodyWhoChat = null
var _junk := RegEx.create_from_string(JUNK_PATTERN)


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
	_chat = await NobodyWhoChat.create(path, {
		"sampler": NobodyWhoSamplerPresets.constrain_with_json_schema(FileAccess.get_file_as_string(SCHEMA_PATH)),
		"n_ctx": int(DataDB.balance("model_context_tokens")),
		# 新版 Qwen 默认会先"思考"一大段，游戏要快速回复，所以关掉；不支持的模型会忽略
		"template_variables": {"enable_thinking": false},
	})
	status = Status.READY if _chat != null else Status.FAILED


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
	if status == Status.READY:
		_chat.set_system_prompt(system_prompt)
		_chat.reset_history()


## 对话中途更新人设，比如告诉她该收尾了；已有的对话历史不变
func update_prompt(system_prompt: String) -> void:
	if status == Status.READY:
		_chat.set_system_prompt(system_prompt)


## 发一句话，总会返回一份合格的回复。失败时 fallback 为 true。
func ask(text: String) -> Dictionary:
	await _wait_until_loaded()
	if status != Status.READY:
		return fallback_reply()
	for _attempt in 1 + int(DataDB.balance("model_retries")):
		var raw := await _generate(text, float(DataDB.balance("model_timeout_sec")))
		var parsed := parse_reply(raw)
		if not parsed.is_empty():
			return parsed
	return fallback_reply()


## 玩家开口时模型可能还在加载，先等一等，不要直接给后备句；但也不能无限等
func _wait_until_loaded() -> void:
	var waited := 0.0
	var limit := float(DataDB.balance("model_load_timeout_sec"))
	while status == Status.LOADING and waited < limit:
		await get_tree().create_timer(POLL_SEC).timeout
		waited += POLL_SEC
	if status == Status.LOADING:
		push_warning("模型加载超时，这次聊天用后备句")


## 边收边等，超时就让模型停下。返回收到的全部文字；超时返回空字符串。
func _generate(text: String, timeout_sec: float) -> String:
	var job := {"done": false, "text": ""}
	_stream_into(text, job)
	var waited := 0.0
	while not job["done"]:
		await get_tree().create_timer(POLL_SEC).timeout
		waited += POLL_SEC
		if waited >= timeout_sec:
			_chat.stop_generation()
			# 让它停下来也限时等，否则插件万一不响应，游戏会一直卡在"她正在想"
			var stop_waited := 0.0
			var stop_limit := float(DataDB.balance("model_stop_wait_sec"))
			while not job["done"] and stop_waited < stop_limit:
				await get_tree().create_timer(POLL_SEC).timeout
				stop_waited += POLL_SEC
			return ""
	return job["text"]


func _stream_into(text: String, job: Dictionary) -> void:
	var stream: NobodyWhoTokenStream = _chat.ask(text)
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
		var option := str(options[i]).strip_edges()
		var unusable := option.is_empty() or _junk.search(option) != null
		clean.append(_fallback_option(i) if unusable else option)
	data["options"] = clean
	data["fallback"] = false
	return data


func fallback_reply() -> Dictionary:
	var options: Array[String] = []
	for i in OPTION_COUNT:
		options.append(_fallback_option(i))
	return {
		"reply": Text.t("FB-01-01"),
		"emotion": "calm",
		"player_attitude": "neutral",
		"intent": "none",
		"options": options,
		"fallback": true,
	}


func _fallback_option(index: int) -> String:
	return Text.t("FB-02-%02d" % (index + 1))
