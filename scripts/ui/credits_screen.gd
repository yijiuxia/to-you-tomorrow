extends Control
## 制作人员名单：结局之后和标题页都能进，点按钮回标题。名单在文字表 UI-56-02 起。

signal finished

const FIRST_LINE := 2
const LAST_LINE := 8


func _ready() -> void:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", UiKit.GAP)
	center.add_child(box)
	_centered(UiKit.title(box, Text.t("UI-56-01")))
	for i in range(FIRST_LINE, LAST_LINE + 1):
		_centered(UiKit.short_label(box, Text.t("UI-56-%02d" % i)))
	_centered(UiKit.short_label(box, Text.t("UI-56-10")))
	UiKit.button(box, Text.t("UI-56-09"), func() -> void: finished.emit())


func _centered(label: Label) -> void:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
