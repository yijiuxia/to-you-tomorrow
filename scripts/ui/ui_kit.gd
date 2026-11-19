class_name UiKit
extends RefCounted
## 方块版界面的小工具：所有画面用它搭，第 5 步换美术时只要换画面，不动规则。

const PAGE_MARGIN := 24
const GAP := 10
const TITLE_SIZE := 22


## 铺满屏幕的竖排容器，带边距。返回里面的 VBox，画面内容往里加。
static func page(parent: Control) -> VBoxContainer:
	GlassTheme.add_background(parent)  # 房间线程加：没有 3D 场景的画面铺深青色渐变（11.19 界面改版）
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, PAGE_MARGIN)
	parent.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", GAP)
	margin.add_child(box)
	return box


static func label(parent: Control, text: String) -> Label:
	var node := Label.new()
	node.text = text
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(node)
	return node


## 不自动换行的短文字。放在横排里时必须用它：自动换行的文字没有最小宽度，会被挤成一字一行。
static func short_label(parent: Control, text: String) -> Label:
	var node := label(parent, text)
	node.autowrap_mode = TextServer.AUTOWRAP_OFF
	return node


## 鼠标放上去才显示的说明。Label 默认不接收鼠标，要打开才会弹出。
static func set_hover_text(node: Control, text: String) -> void:
	node.mouse_filter = Control.MOUSE_FILTER_STOP
	node.tooltip_text = text


static func title(parent: Control, text: String) -> Label:
	var node := label(parent, text)
	node.add_theme_font_size_override("font_size", TITLE_SIZE)
	return node


static func button(parent: Control, text: String, on_pressed: Callable) -> Button:
	var node := Button.new()
	node.text = text
	node.pressed.connect(on_pressed)
	parent.add_child(node)
	return node


static func row(parent: Control) -> HBoxContainer:
	var node := HBoxContainer.new()
	node.add_theme_constant_override("separation", GAP)
	parent.add_child(node)
	return node


## 占满剩余高度的空白，把下面的按钮推到底部
static func spacer(parent: Control) -> Control:
	var node := Control.new()
	node.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(node)
	return node


static func stat_name(id: String) -> String:
	return Text.t(str(DataDB.row("girl_stats", id)["name_key"]))
