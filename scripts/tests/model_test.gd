extends Control
## 第 0 步的模型测试：验证 NobodyWho 能加载模型、输出固定 JSON，并记录速度。
##
## 有两种用法（模型路径都用 --model= 传入，因为模型不在仓库里）：
## 1. 手动聊天：打开窗口，在输入框打字。
## 2. 自动跑分：加 --auto，把 lines.csv 的句子全跑一遍，结果写到 --out= 指定的文件。
##    可选：--cpu 只用 CPU（模拟没有独立显卡）；--limit=10 只跑前 10 句。

const SYSTEM_PROMPT_PATH := "res://tests/model_test/system_prompt.txt"
const LINES_PATH := "res://tests/model_test/lines.csv"
const SCHEMA_PATH := "res://data/model_output_schema.json"
const REQUIRED_KEYS: Array[String] = ["reply", "emotion", "player_attitude", "intent", "options"]

var _chat: NobodyWhoChat
var _log: RichTextLabel
var _input: LineEdit


func _ready() -> void:
	var args := _read_args()
	_build_ui()
	var model_path: String = args.get("model", "")
	if model_path.is_empty():
		_say("没有模型路径：启动时要加 --model=模型文件路径")
		if args.has("auto"):
			get_tree().quit(1)
		return

	# 用格式约束让模型只能输出 4.3 节规定的 JSON，比生成后再检查更可靠。
	# 直接传文件原文：Godot 解析 JSON 会把 3 变成 3.0，插件不接受。
	var config := {
		"system_prompt": FileAccess.get_file_as_string(SYSTEM_PROMPT_PATH),
		"sampler": NobodyWhoSamplerPresets.constrain_with_json_schema(FileAccess.get_file_as_string(SCHEMA_PATH)),
		"use_gpu": not args.has("cpu"),
		# 新版 Qwen 默认会先"思考"一大段，游戏要快速回复，所以关掉；不支持的模型会忽略
		"template_variables": {"enable_thinking": false},
	}

	var load_start := Time.get_ticks_msec()
	_chat = await NobodyWhoChat.create(model_path, config)
	var load_ms := Time.get_ticks_msec() - load_start
	if _chat == null:
		_say("模型加载失败，详情看上面的错误信息")
		if args.has("auto"):
			get_tree().quit(1)
		return
	_say("模型加载完成：%d 毫秒，GPU=%s" % [load_ms, str(config["use_gpu"])])

	if args.has("auto"):
		await _run_auto(args, load_ms, config["use_gpu"])
		get_tree().quit()
	else:
		_input.editable = true
		_input.grab_focus()


## 把句子逐个发给模型，每句前清空历史，这样每句互不影响、结果可比
func _run_auto(args: Dictionary, load_ms: int, use_gpu: bool) -> void:
	var lines := _load_lines()
	var limit: int = int(args.get("limit", lines.size()))
	var results: Array[Dictionary] = []
	for row: Dictionary in lines.slice(0, limit):
		_chat.reset_history()
		var r := await _ask(row["line"])
		r["id"] = row["id"]
		r["line"] = row["line"]
		r["expected_intent"] = row["expected_intent"]
		r["expected_attitude"] = row["expected_attitude"]
		results.append(r)
		_say("%s  首字 %d ms  总计 %d ms  合法=%s  intent=%s（应为 %s）" % [
			r["id"], r["first_token_ms"], r["total_ms"], str(r["valid"]),
			r.get("intent", "-"), r["expected_intent"],
		])
	var out_path: String = args.get("out", "")
	if not out_path.is_empty():
		var file := FileAccess.open(out_path, FileAccess.WRITE)
		file.store_string(JSON.stringify({"load_ms": load_ms, "use_gpu": use_gpu, "results": results}, "  "))
		file.close()


## 发一句话，记录首字和总耗时，并检查回复是否符合格式
func _ask(text: String) -> Dictionary:
	var start := Time.get_ticks_msec()
	var first_token_ms := -1
	var response := ""
	var stream: NobodyWhoTokenStream = _chat.ask(text)
	while true:
		var token: Variant = await stream.next_token()
		if token == null:
			break
		if first_token_ms < 0:
			first_token_ms = Time.get_ticks_msec() - start
		response += str(token)
	var result := {
		"raw": response,
		"first_token_ms": first_token_ms,
		"total_ms": Time.get_ticks_msec() - start,
		"valid": false,
	}
	var parsed: Variant = JSON.parse_string(response)
	if parsed is Dictionary and _has_required_shape(parsed):
		result["valid"] = true
		result.merge(parsed)
	return result


## 字段齐全，且 options 正好 3 个，才算合法
func _has_required_shape(data: Dictionary) -> bool:
	for key: String in REQUIRED_KEYS:
		if not data.has(key):
			return false
	var options: Variant = data["options"]
	return options is Array and options.size() == 3


func _on_input_submitted(text: String) -> void:
	if text.strip_edges().is_empty():
		return
	_input.clear()
	_input.editable = false
	_say("你：" + text)
	var r := await _ask(text)
	_say("%s\n（首字 %d ms，总计 %d ms，合法=%s）" % [r["raw"], r["first_token_ms"], r["total_ms"], str(r["valid"])])
	_input.editable = true
	_input.grab_focus()


func _load_lines() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var file := FileAccess.open(LINES_PATH, FileAccess.READ)
	var header := file.get_csv_line()
	while not file.eof_reached():
		var cells := file.get_csv_line()
		if cells.size() < header.size():
			continue
		var row := {}
		for i in header.size():
			row[header[i]] = cells[i]
		rows.append(row)
	return rows


## 读 -- 后面的自定义参数，如 --model=x 变成 {"model": "x"}
func _read_args() -> Dictionary:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=", true, 1)
		args[parts[0]] = parts[1] if parts.size() > 1 else true
	return args


func _build_ui() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(box)
	_log = RichTextLabel.new()
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.selection_enabled = true
	_log.scroll_following = true
	box.add_child(_log)
	_input = LineEdit.new()
	_input.editable = false
	_input.text_submitted.connect(_on_input_submitted)
	box.add_child(_input)


func _say(text: String) -> void:
	print(text)
	_log.add_text(text + "\n")
