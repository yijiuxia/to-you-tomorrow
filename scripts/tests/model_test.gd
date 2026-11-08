extends Control
## 第 0 步的模型测试：验证 NobodyWho 能加载模型、输出固定 JSON，并记录速度。
##
## 有两种用法（模型路径都用 --model= 传入，因为模型不在仓库里）：
## 1. 手动聊天：打开窗口，在输入框打字。
## 2. 自动跑分：加 --auto，把 lines.csv 的句子全跑一遍，结果写到 --out= 指定的文件。
##    可选：--cpu 只用 CPU（模拟没有独立显卡）；--limit=10 只跑前 10 句。

const TEST_AGE := 15
const TEST_WEEK := 3
const LINES_PATH := "res://tests/model_test/lines.csv"
const MEMORY_SEED_PATH := "res://tests/model_test/memory_seed.csv"
const MEMORY_LINES_PATH := "res://tests/model_test/memory_lines.csv"
const MEMORY_TEST_WEEK := 6
const SCHEMA_PATH := "res://data/model_output_schema.json"
const POLL_SEC := 0.05
const STALL_LIMIT_MS := 60000
const REQUIRED_KEYS: Array[String] = ["reply", "emotion", "player_attitude", "intent", "options"]

var _chat: NobodyWhoChat
var _judge: NobodyWhoChat = null  # --judge：先单独判断态度和 intent，和游戏里的 model_separate_judge 一样
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
		"system_prompt": _system_prompt(),
		"sampler": ModelService.make_sampler(),
		"use_gpu": not args.has("cpu"),
		# 新版 Qwen 默认会先"思考"一大段，游戏要快速回复，所以关掉；不支持的模型会忽略
		"template_variables": {"enable_thinking": false},
	}

	var load_start := Time.get_ticks_msec()
	# --judge 时和游戏一样：模型只加载一次，聊天和判断共用
	var source: Variant = model_path
	if args.has("judge"):
		source = await NobodyWhoModel.create(model_path, {})
	_chat = await NobodyWhoChat.create(source, config)
	var load_ms := Time.get_ticks_msec() - load_start
	if _chat == null:
		_say("模型加载失败，详情看上面的错误信息")
		if args.has("auto"):
			get_tree().quit(1)
		return
	_say("模型加载完成：%d 毫秒，GPU=%s" % [load_ms, str(config["use_gpu"])])
	if args.has("judge"):
		_judge = await NobodyWhoChat.create(source, {
			"system_prompt": ModelService.judge_prompt(),
			"sampler": ModelService.make_sampler(ModelService.JUDGE_SCHEMA_PATH),
			"use_gpu": config["use_gpu"],
			"template_variables": {"enable_thinking": false},
		})

	if args.has("lines"):
		await _run_lines()
		get_tree().quit()
	elif args.has("memory"):
		await _run_memory(args, int(args["memory"]))
		get_tree().quit()
	elif args.has("auto"):
		await _run_auto(args, load_ms, config["use_gpu"])
		get_tree().quit()
	else:
		_input.editable = true
		_input.grab_focus()


## 和游戏用同一份人设文字，测的才是游戏里的效果。这些句子是按 15 岁写的。
func _system_prompt() -> String:
	GameState.age = TEST_AGE
	GameState.week = TEST_WEEK
	GameState.last_schedule.assign(["mechanics", "mechanics", "ecology", "rest", "comms", "together", "rest"])
	return ChatPrompt.build()


## 把句子逐个发给模型，每句前清空历史，这样每句互不影响、结果可比
func _run_auto(args: Dictionary, load_ms: int, use_gpu: bool) -> void:
	var lines := _load_lines()
	var limit: int = int(args.get("limit", lines.size()))
	var results: Array[Dictionary] = []
	for row: Dictionary in lines.slice(0, limit):
		_chat.reset_history()
		var judged := {}
		var judge_ms := 0
		var line: String = row["line"]
		if _judge != null:
			_judge.reset_history()
			var j := await _ask(row["line"], _judge, false)
			judge_ms = j["total_ms"]
			judged = ModelService.parse_judge(j["raw"])
			if not judged.is_empty():
				line += "
" + ModelService.judged_hint(judged)
		var r := await _ask(line)
		r.merge(judged, true)
		r["judge_ms"] = judge_ms
		r["total_ms"] = int(r["total_ms"]) + judge_ms
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


## 记忆实测（比赛版 4.5"取几条"要实测）：--memory=条数。先放进 15 条事件记忆和 2 条核心记忆，
## 再问 12 个要靠记忆才能答对的问题，看回复里有没有说出关键词，并记录速度。
func _run_memory(args: Dictionary, count: int) -> void:
	GameState.week = MEMORY_TEST_WEEK
	GameState.age = TEST_AGE
	GameState.memory = MemoryStore.new()
	for row in _load_csv(MEMORY_SEED_PATH):
		GameState.memory.remember_event(row["text"], MemoryStore.KIND_EVENT, int(row["importance"]), int(row["week"]), int(row["age"]))
	GameState.memory.remember_core("like_颜色", "我最喜欢的颜色是天蓝色。", 3)
	GameState.memory.remember_core("promise_5", "新星答应过我：“下次一起看日出”", 5)
	DataDB.table("balance")["memory_recall_count"]["value"] = count  # 只在这次测试里改
	_chat.set_system_prompt(ChatPrompt.build())
	var results: Array[Dictionary] = []
	var hits := 0
	for row in _load_csv(MEMORY_LINES_PATH):
		_chat.reset_history()
		var message := ChatPrompt.turn_message(row["line"], "", false)
		if _judge != null:
			_judge.reset_history()
			var judged := ModelService.parse_judge((await _ask(row["line"], _judge, false))["raw"])
			if not judged.is_empty():
				message += "
" + ModelService.judged_hint(judged)
		var r := await _ask(message)
		var reply := str(r.get("reply", ""))
		var hit := false
		for word in str(row["keywords"]).split("|"):
			if reply.contains(word):
				hit = true
		hits += 1 if hit else 0
		r["id"] = row["id"]
		r["line"] = row["line"]
		r["hit"] = hit
		r["recalled"] = GameState.memory.recall(row["line"], count, GameState.week, GameState.age).size()
		results.append(r)
		_say("%s 记得=%s 带了 %d 条 %d ms：%s" % [row["id"], str(hit), r["recalled"], r["total_ms"], reply])
	_say("取 %d 条：答对 %d / %d" % [count, hits, results.size()])
	var out_path: String = args.get("out", "")
	if not out_path.is_empty():
		var file := FileAccess.open(out_path, FileAccess.WRITE)
		file.store_string(JSON.stringify({"count": count, "hits": hits, "results": results}, "  "))
		file.close()


## --lines：用真模型把各处"说一句"都跑一遍，看她说得像不像她（8 岁第 2 周、15 岁第 5 周各一遍）
func _run_lines() -> void:
	ModelService.ensure_loaded()
	for setting in [[8, 2], [TEST_AGE, 5]]:
		GameState.reset()
		GameState.age = setting[0]
		GameState.week = setting[1]
		for row in _load_csv(MEMORY_SEED_PATH):
			if int(row["age"]) <= GameState.age and int(row["week"]) < GameState.week:
				GameState.memory.remember_event(row["text"], MemoryStore.KIND_EVENT, int(row["importance"]), int(row["week"]), int(row["age"]))
		var rng := RandomNumberGenerator.new()
		_say("== %d 岁 第 %d 周" % setting)
		_say("早安：" + str((await ChatLines.morning())["reply"]))
		_say("周总结：" + str((await ChatLines.week_summary(PackedStringArray(["第 %d 周，我们在小镇里完成了：净水站。" % GameState.week])))["reply"]))
		var plan: Array[String] = ["mechanics", "mechanics", "mechanics", "fitness", "mechanics", "mechanics", "rest"]
		_say("课表评论：" + str((await ChatLines.schedule_comment(plan, 4, PackedStringArray(["周一", "周二", "周三", "周四", "周五", "周六", "周日"])))["reply"]))
		_say("上课小事件：" + str((await ChatLines.course_event("ecology", "周三"))["reply"]))
		for activity in ["window", "daydream"]:
			_say("主动开口（%s）：%s" % [activity, (await ChatLines.idle(activity, rng))["reply"]])
		_say("小镇评论：" + str((await ChatLines.earth_comment(Text.t("UI-21-02")))["reply"]))
		var talk: Array[Dictionary] = [
			{"speaker": MemoryStore.SPEAKER_PLAYER, "text": "今天累不累？"},
			{"speaker": MemoryStore.SPEAKER_GIRL, "text": "有一点，不过我把净水站修好了！"},
			{"speaker": MemoryStore.SPEAKER_PLAYER, "text": "真棒，明天休息一下吧。"},
		]
		_say("聊天摘要：" + await ChatLines.summarize(talk))


func _load_csv(path: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var file := FileAccess.open(path, FileAccess.READ)
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


## 发一句话，记录首字和总耗时，并检查回复是否符合格式
func _ask(text: String, chat: NobodyWhoChat = null, check_shape := true) -> Dictionary:
	if chat == null:
		chat = _chat
	var start := Time.get_ticks_msec()
	var first_token_ms := -1
	var response := ""
	var stream: NobodyWhoTokenStream = chat.ask(text)
	var job := {"done": false, "text": "", "first": -1}
	_read_stream(stream, job, start)
	while not job["done"]:
		await get_tree().create_timer(POLL_SEC).timeout
		if Time.get_ticks_msec() - start > STALL_LIMIT_MS:
			print("卡住：", text, " 已生成 ", str(job["text"]).length(), " 字：", str(job["text"]).right(200))
			chat.stop_generation()
			break
	first_token_ms = job["first"]
	response = job["text"]
	var result := {
		"raw": response,
		"first_token_ms": first_token_ms,
		"total_ms": Time.get_ticks_msec() - start,
		"valid": false,
	}
	var parsed: Variant = JSON.parse_string(response)
	if check_shape and parsed is Dictionary and _has_required_shape(parsed):
		result["valid"] = true
		result.merge(parsed)
	return result


func _read_stream(stream: NobodyWhoTokenStream, job: Dictionary, start: int) -> void:
	while true:
		var token: Variant = await stream.next_token()
		if token == null:
			break
		if job["first"] < 0:
			job["first"] = Time.get_ticks_msec() - start
		job["text"] += str(token)
	job["done"] = true


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
