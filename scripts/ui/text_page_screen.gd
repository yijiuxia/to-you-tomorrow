extends Control
## 通用文字页：周结算、时间跳跃、结局和小镇占位都用它，第 1 步还不需要各自的画面。

signal finished

var title_text := ""
var lines := PackedStringArray()
var button_text := ""


func _ready() -> void:
	var box := UiKit.page(self)
	UiKit.title(box, title_text)
	for line in lines:
		UiKit.label(box, line)
	UiKit.spacer(box)
	UiKit.button(box, button_text, func() -> void: finished.emit())
