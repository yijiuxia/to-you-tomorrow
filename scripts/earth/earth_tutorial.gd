class_name EarthTutorial
extends RefCounted
## 建造教学提示（文案 04_第2周.md 的【界面·教学】）。每条只出现一次，记在剧情标记里，读档后不会重复。

const FLAG_PREFIX := "tutorial_"


## 某个时机到了，返回这次要显示的提示文字（可能好几条）；没有返回空数组
static func lines_for(trigger: String, values: Dictionary) -> PackedStringArray:
	var result := PackedStringArray()
	for id: String in DataDB.table("earth_tutorial"):
		var row := DataDB.row("earth_tutorial", id)
		if str(row["trigger"]) != trigger or GameState.week != int(row["week"]) or GameState.flags.get(FLAG_PREFIX + id, false):
			continue
		GameState.flags[FLAG_PREFIX + id] = true
		for key in str(row["text_keys"]).split("|"):
			result.append(Text.f(key, values))
	return result
