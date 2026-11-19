class_name GlassTheme
extends RefCounted
## 玻璃面板样式（房间线程，按 yi 的参考图"方舟生活"）：半透明深青底、细青色描边、圆角。
## main.gd 把它设在根窗口上，所有画面（包括暂停菜单这种 CanvasLayer 里的）都会用上。
## 想改颜色只改这里的常量。

const BG := Color(0.03, 0.1, 0.12, 0.84)         # 面板底色
const BG_BUTTON := Color(0.08, 0.19, 0.21, 0.88)
const BG_HOVER := Color(0.12, 0.27, 0.29, 0.92)
const BG_PRESSED := Color(0.22, 0.52, 0.54, 0.95)
const BORDER := Color(0.45, 0.85, 0.85, 0.45)     # 细描边
const BORDER_HOVER := Color(0.55, 0.95, 0.95, 0.85)
const ACCENT := Color(0.42, 0.88, 0.82)           # 强调色：进度条、选中的页签
const TEXT := Color(0.9, 0.97, 0.97)
const TEXT_DIM := Color(0.65, 0.76, 0.77)
const TEXT_DISABLED := Color(0.5, 0.58, 0.6)
const RADIUS := 10
const BUTTON_RADIUS := 8
const SCREEN_TOP := Color(0.04, 0.1, 0.13)        # 没有 3D 场景的画面用的背景渐变
const SCREEN_BOTTOM := Color(0.02, 0.05, 0.07)


static func make() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 17
	var panel := box(BG, BORDER, RADIUS, 14)
	theme.set_stylebox("panel", "PanelContainer", panel)
	theme.set_stylebox("panel", "Panel", panel)
	theme.set_stylebox("panel", "PopupPanel", panel)
	theme.set_stylebox("panel", "TooltipPanel", box(Color(0.03, 0.09, 0.1, 0.95), BORDER, 6, 8))
	theme.set_color("font_color", "TooltipLabel", TEXT)

	for type: String in ["Button", "CheckBox", "OptionButton", "MenuButton"]:
		var normal := box(BG_BUTTON, BORDER, BUTTON_RADIUS, 0)
		_pad(normal, 16, 8)
		var hover := box(BG_HOVER, BORDER_HOVER, BUTTON_RADIUS, 0)
		_pad(hover, 16, 8)
		var pressed := box(BG_PRESSED, BORDER_HOVER, BUTTON_RADIUS, 0)
		_pad(pressed, 16, 8)
		var disabled := box(Color(BG_BUTTON, 0.45), Color(BORDER, 0.2), BUTTON_RADIUS, 0)
		_pad(disabled, 16, 8)
		if type == "CheckBox":
			# 单选框不要底板，太重；只在指上去时亮一点
			normal = box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), BUTTON_RADIUS, 6)
			pressed = normal
			disabled = normal
		theme.set_stylebox("normal", type, normal)
		theme.set_stylebox("hover", type, hover)
		theme.set_stylebox("pressed", type, pressed)
		theme.set_stylebox("hover_pressed", type, pressed)
		theme.set_stylebox("disabled", type, disabled)
		theme.set_stylebox("focus", type, StyleBoxEmpty.new())
		theme.set_color("font_color", type, TEXT)
		theme.set_color("font_hover_color", type, Color.WHITE)
		theme.set_color("font_pressed_color", type, Color.WHITE)
		theme.set_color("font_hover_pressed_color", type, Color.WHITE)
		theme.set_color("font_focus_color", type, TEXT)
		theme.set_color("font_disabled_color", type, TEXT_DISABLED)

	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("default_color", "RichTextLabel", TEXT)

	for type: String in ["LineEdit", "TextEdit"]:
		var field := box(Color(0.02, 0.07, 0.08, 0.85), BORDER, 6, 8)
		theme.set_stylebox("normal", type, field)
		theme.set_stylebox("focus", type, box(Color(0.02, 0.07, 0.08, 0.9), BORDER_HOVER, 6, 8))
		theme.set_stylebox("read_only", type, field)
		theme.set_color("font_color", type, TEXT)
		theme.set_color("font_placeholder_color", type, TEXT_DIM)
		theme.set_color("caret_color", type, ACCENT)

	var bar_bg := box(Color(1, 1, 1, 0.1), Color(0, 0, 0, 0), 3, 0)
	var bar_fill := box(ACCENT, Color(0, 0, 0, 0), 3, 0)
	theme.set_stylebox("background", "ProgressBar", bar_bg)
	theme.set_stylebox("fill", "ProgressBar", bar_fill)
	theme.set_color("font_color", "ProgressBar", TEXT)

	# 页签：选中的那个底下一条青色线
	var tab_selected := box(BG_HOVER, Color(0, 0, 0, 0), 6, 0)
	tab_selected.border_width_bottom = 2
	tab_selected.border_color = ACCENT
	_pad(tab_selected, 14, 6)
	var tab_idle := box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 6, 0)
	_pad(tab_idle, 14, 6)
	var tab_hover := box(BG_BUTTON, Color(0, 0, 0, 0), 6, 0)
	_pad(tab_hover, 14, 6)
	theme.set_stylebox("tab_selected", "TabContainer", tab_selected)
	theme.set_stylebox("tab_unselected", "TabContainer", tab_idle)
	theme.set_stylebox("tab_hovered", "TabContainer", tab_hover)
	theme.set_stylebox("panel", "TabContainer", box(Color(0, 0, 0, 0.15), Color(0, 0, 0, 0), 6, 10))
	theme.set_color("font_selected_color", "TabContainer", Color.WHITE)
	theme.set_color("font_unselected_color", "TabContainer", TEXT_DIM)
	theme.set_color("font_hovered_color", "TabContainer", TEXT)

	var scroll := box(Color(1, 1, 1, 0.05), Color(0, 0, 0, 0), 3, 0)
	var grab := box(Color(ACCENT, 0.5), Color(0, 0, 0, 0), 3, 0)
	for type: String in ["VScrollBar", "HScrollBar"]:
		theme.set_stylebox("scroll", type, scroll)
		theme.set_stylebox("grabber", type, grab)
		theme.set_stylebox("grabber_highlight", type, box(ACCENT, Color(0, 0, 0, 0), 3, 0))
		theme.set_stylebox("grabber_pressed", type, box(ACCENT, Color(0, 0, 0, 0), 3, 0))
	return theme


## 圆角面板：底色、描边色、圆角、内边距
static func box(bg: Color, border: Color, radius: int, padding: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1 if border.a > 0.0 else 0)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(padding)
	style.anti_aliasing = true
	return style


static func _pad(style: StyleBoxFlat, horizontal: int, vertical: int) -> void:
	style.content_margin_left = horizontal
	style.content_margin_right = horizontal
	style.content_margin_top = vertical
	style.content_margin_bottom = vertical


## 没有 3D 场景的画面（课表、聊天、周结算……）铺一层深青色渐变当背景
static func add_background(parent: Control) -> TextureRect:
	var gradient := Gradient.new()
	gradient.set_color(0, SCREEN_TOP)
	gradient.set_color(1, SCREEN_BOTTOM)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0, 1)
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	parent.move_child(rect, 0)
	return rect
