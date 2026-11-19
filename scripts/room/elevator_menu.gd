class_name ElevatorMenu
extends CenterContainer
## 舱门的电梯菜单（房间线程）：门打开后选去哪里。没开放的场所显示成灰的。

signal place_chosen(id: String)

const MENU_WIDTH := 360.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP  # 打开时挡住后面的房间
	var panel := PanelContainer.new()
	add_child(panel)
	panel.custom_minimum_size.x = MENU_WIDTH
	var box := VBoxContainer.new()
	panel.add_child(box)
	UiKit.title(box, Text.t("RM-05-01"))
	for row in RoomRules.elevator_places():
		var id := str(row["id"])
		if id == "cabin":
			continue  # 已经在生活舱，"取消"就是留下
		var text := Text.t(row["name_key"])
		var open := RoomRules.is_place_open(id)
		if not open:
			text += " " + Text.f("RM-05-08", {"week": row["open_week"]})
		var button := UiKit.button(box, text, func() -> void:
			visible = false
			place_chosen.emit(id))
		button.disabled = not open
	UiKit.button(box, Text.t("RM-05-11"), func() -> void: visible = false)
