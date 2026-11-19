class_name PlaceScreen
extends Control
## 一个场所的画面（房间线程）：机械室、温室、通讯室、人类保护区、地下居民区。
## 沿过道左右走，点发光的东西看说明；按"回生活舱"回去。

signal finished

var place_id := "machine"
var view: RoomView


func _ready() -> void:
	var row := RoomRules.place(place_id)
	view = RoomView.new()
	view.scene_id = place_id
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(view)
	var box := UiKit.page(self)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(box.get_parent() as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiKit.title(box, Text.t(row["name_key"]))
	UiKit.label(box, Text.t(row["desc_key"]))
	UiKit.label(box, Text.t("RM-05-09"))
	if place_id == "underground":
		GameState.flags[RoomRules.FLAG_UNDERGROUND] = true
		UiKit.label(box, Text.t("RM-07-09"))
	var filler := UiKit.spacer(box)
	filler.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var buttons := UiKit.row(box)
	UiKit.button(buttons, Text.t("RM-05-10"), func() -> void: finished.emit())
	for child in box.get_children():
		if child is Label:
			(child as Label).mouse_filter = Control.MOUSE_FILTER_IGNORE
