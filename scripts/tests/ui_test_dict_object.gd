extends RefCounted
## 界面测试用：模仿人物 AI 的 MemoryStore，自己负责转成字典和从字典还原。

var items: Array = []


func to_dict() -> Dictionary:
	return {"items": items.duplicate()}


static func from_dict(data: Dictionary) -> RefCounted:
	var object := new()
	object.items = data.get("items", []).duplicate()
	return object
