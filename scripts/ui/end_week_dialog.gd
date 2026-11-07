extends ConfirmationDialog
## "结束本周"确认框，主界面和小镇共用。


func _ready() -> void:
	ok_button_text = Text.t("UI-05-04")
	cancel_button_text = Text.t("UI-05-05")


func ask() -> void:
	var lines := PackedStringArray([Text.t("UI-05-01")])
	if GameState.week >= int(DataDB.balance("last_week")):
		lines.append(Text.t("UI-05-06"))
	else:
		var same := GameState.schedule == GameState.last_schedule
		lines.append(Text.t("UI-05-02") if same else Text.t("UI-05-03"))
	dialog_text = "\n".join(lines)
	popup_centered()
