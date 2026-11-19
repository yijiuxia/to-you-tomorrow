class_name SaveSystem
extends RefCounted
## 存档：1 个自动存档（每周早上存，新的覆盖旧的）+ 2 个手动存档（主界面点"保存"）。yi 11.19 定。
## 手动存档是在主界面存的，读回来直接回主界面；自动存档读回来从那一周早上开始。
## 存的是 GameState 里的全部脚本变量。以后谁往 GameState 加变量，会自动跟着存，不用改这里。
## 变量里的纯数据对象（比如地球 EarthWorld）也会把它自己的变量一起存下来。
## 对象自己写了 to_dict() 和静态的 from_dict(数据) 时（比如人物 AI 的记忆 MemoryStore），用它自己的方法存取。

const VERSION := 1
const OBJECT_KEY := "__object"
const VARS_KEY := "vars"
const DICT_KEY := "dict"

## 自动测试会把它改成别的文件，免得覆盖玩家的存档
static var save_path := "user://autosave.sav"

const SLOT_AUTO := "auto"
const SLOTS: Array[String] = ["auto", "manual1", "manual2"]
const RESUME_WEEK_START := "week_start"  # 读档后从那一周早上开始（自动存档）
const RESUME_HUB := "hub"                # 读档后直接回主界面（手动存档）


## 每个存档位的文件：自动存档就是 save_path，手动的在它旁边加后缀
static func path_for(slot: String) -> String:
	if slot == SLOT_AUTO:
		return save_path
	return save_path.get_basename() + "_" + slot + ".sav"


static func has_save(slot: String = SLOT_AUTO) -> bool:
	return FileAccess.file_exists(path_for(slot))


## 三个存档位里有没有任何一个（标题页"继续"能不能点）
static func has_any_save() -> bool:
	for slot in SLOTS:
		if has_save(slot):
			return true
	return false


## 把现在的 GameState 写进存档。成功返回 true。手动存档 resume 传 RESUME_HUB。
static func save(slot: String = SLOT_AUTO, resume: String = RESUME_WEEK_START) -> bool:
	var data := {
		"version": VERSION,
		"time": Time.get_datetime_string_from_system(false, true),
		"resume": resume,
		"state": _pack(GameState),
	}
	var file := FileAccess.open(path_for(slot), FileAccess.WRITE)
	if file == null:
		push_error("写不了存档：%s（%s）" % [path_for(slot), error_string(FileAccess.get_open_error())])
		return false
	# 用 Godot 自己的格式而不是 JSON：JSON 会把整数变成小数，也存不了 Vector2i 这类格子坐标
	file.store_string(var_to_str(data))
	return true


## 读存档，覆盖现在的 GameState。存档不存在或坏了返回 false，GameState 不变。
static func load_save(slot: String = SLOT_AUTO) -> bool:
	var data := _read(slot)
	if data.is_empty():
		return false
	_unpack(GameState, data["state"])
	return true


## 这个存档读回来该从哪开始（旧存档没写，按自动存档处理）
static func resume_of(slot: String) -> String:
	return str(_read(slot).get("resume", RESUME_WEEK_START))


## 标题页显示用：存档是第几周、她几岁，不改动 GameState
static func summary(slot: String = SLOT_AUTO) -> Dictionary:
	var data := _read(slot)
	if data.is_empty():
		return {}
	var state: Dictionary = data["state"]
	return {"week": state.get("week", 1), "age": state.get("age", 0), "girl": state.get("girl_name", ""), "time": data.get("time", "")}


static func delete_save(slot: String = SLOT_AUTO) -> void:
	if has_save(slot):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path_for(slot)))


static func _read(slot: String = SLOT_AUTO) -> Dictionary:
	if not has_save(slot):
		return {}
	var parsed: Variant = str_to_var(FileAccess.get_file_as_string(path_for(slot)))
	if not parsed is Dictionary:
		push_warning("存档读不出来：" + path_for(slot))
		return {}
	var data: Dictionary = parsed
	if int(data.get("version", 0)) != VERSION or not data.get("state") is Dictionary:
		push_warning("存档版本不对：" + path_for(slot))
		return {}
	return data


## 把一个对象的脚本变量变成字典
static func _pack(source: Object) -> Dictionary:
	var result := {}
	for property in source.get_property_list():
		if not property["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
			continue
		var value: Variant = source.get(property["name"])
		if value is Object:
			# 只存纯数据对象（RefCounted 脚本）；节点之类是画面，不属于存档
			if value is RefCounted and value.get_script() != null:
				var path: String = value.get_script().resource_path
				if value.has_method("to_dict"):
					value = {OBJECT_KEY: path, DICT_KEY: value.to_dict()}
				else:
					value = {OBJECT_KEY: path, VARS_KEY: _pack(value)}
			else:
				continue
		result[property["name"]] = value
	return result


## 把字典写回对象。旧存档里没有的变量保持默认值，这样以后加变量不会让旧存档读不了。
static func _unpack(target: Object, data: Dictionary) -> void:
	for property in target.get_property_list():
		var name: String = property["name"]
		if not property["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE or not data.has(name):
			continue
		var saved: Variant = data[name]
		var current: Variant = target.get(name)
		if saved is Dictionary and saved.has(OBJECT_KEY):
			var script: Script = load(str(saved[OBJECT_KEY]))
			if saved.has(DICT_KEY):
				target.set(name, script.call("from_dict", saved[DICT_KEY]))
			else:
				var object: Object = script.new()
				_unpack(object, saved[VARS_KEY])
				target.set(name, object)
		elif current is Array and saved is Array:
			# 带类型的数组（Array[String] 等）不能直接整个替换，要一个个装进去
			var array: Array = current
			array.assign(saved)
		else:
			target.set(name, saved)
