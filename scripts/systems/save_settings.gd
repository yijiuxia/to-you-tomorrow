class_name SaveSettings
extends RefCounted
## 设置：音量、窗口 / 全屏、剧情文字速度、语言。
## 和存档分开放：开新游戏、读存档都不会动设置。默认值在 balance.csv 的 ui_ 开头几行。

const SECTION := "settings"
const LANGUAGES: Array[String] = ["zh", "en"]

## 自动测试会改成别的文件
static var settings_path := "user://settings.cfg"

static var volume := 80          # 0～100
static var fullscreen := false
static var text_speed := 40      # 剧情文字每秒出现几个字
static var language := "zh"


## 游戏启动时调用一次：读文件（没有就用默认值）并生效
static func load_and_apply() -> void:
	volume = int(DataDB.balance("ui_volume_default", 80))
	fullscreen = int(DataDB.balance("ui_fullscreen_default", 0)) == 1
	text_speed = int(DataDB.balance("ui_text_speed_default", 40))
	language = Text.DEFAULT_LANGUAGE
	var config := ConfigFile.new()
	if config.load(settings_path) == OK:
		volume = int(config.get_value(SECTION, "volume", volume))
		fullscreen = bool(config.get_value(SECTION, "fullscreen", fullscreen))
		text_speed = int(config.get_value(SECTION, "text_speed", text_speed))
		language = str(config.get_value(SECTION, "language", language))
	apply()


## 改完设置后调用：生效并写进文件
static func save_settings() -> void:
	apply()
	var config := ConfigFile.new()
	config.set_value(SECTION, "volume", volume)
	config.set_value(SECTION, "fullscreen", fullscreen)
	config.set_value(SECTION, "text_speed", text_speed)
	config.set_value(SECTION, "language", language)
	var error := config.save(settings_path)
	if error != OK:
		push_error("写不了设置：%s（%s）" % [settings_path, error_string(error)])


static func apply() -> void:
	volume = clampi(volume, 0, 100)
	text_speed = clampi(text_speed, int(DataDB.balance("ui_text_speed_min", 10)), int(DataDB.balance("ui_text_speed_max", 120)))
	if not language in LANGUAGES:
		language = Text.DEFAULT_LANGUAGE
	Text.language = language
	# 音量 0 时直接静音：linear_to_db(0) 是负无穷，有的声卡会出杂音
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(bus, volume == 0)
	AudioServer.set_bus_volume_db(bus, linear_to_db(volume / 100.0) if volume > 0 else -80.0)
	# 自动测试在没有窗口的模式下跑，不碰窗口
	if DisplayServer.get_name() != "headless":
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)
