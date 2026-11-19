class_name PlaceScreen
extends Control
## 一个场所的画面（房间线程）：机械室、温室、通讯室、人类保护区、地下居民区。
## 沿过道左右走，点发光的东西看说明；按"回生活舱"回去。

signal finished

var place_id := "machine"
var view: RoomView
const CARD_WIDTH := 460.0


func _ready() -> void:
	var row := RoomRules.place(place_id)
	view = RoomView.new()
	view.scene_id = place_id
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(view)
	var box := UiKit.page(self)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(box.get_parent() as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 说明文字放在一块浅色玻璃面板上：场所里换成了 Lux3D 模型，背景暗，直接写字看不清
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	card.custom_minimum_size.x = CARD_WIDTH
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(card)
	var text := VBoxContainer.new()
	card.add_child(text)
	UiKit.title(text, Text.t(row["name_key"]))
	UiKit.label(text, Text.f(row["desc_key"], {"pods": int(DataDB.balance("room_preserve_pods"))}))
	if place_id == "preserve":
		UiKit.label(text, Text.t("PL-04-02"))  # 请勿离开过道
	UiKit.label(text, Text.t("RT-05-09"))
	if place_id == "underground":
		GameState.flags[RoomRules.FLAG_UNDERGROUND] = true
		UiKit.label(text, Text.t("RT-07-09"))
	for child in text.get_children():
		(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var filler := UiKit.spacer(box)
	filler.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var buttons := UiKit.row(box)
	UiKit.button(buttons, Text.t("RT-05-10"), func() -> void: finished.emit())
	for child in box.get_children():
		if child is Label:
			(child as Label).mouse_filter = Control.MOUSE_FILTER_IGNORE
