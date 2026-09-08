class_name TaskProgress
extends RefCounted

# Somente conclusões são armazenadas; bloqueios são derivados do catálogo.
var _completed: Dictionary = {}

func state(discipline_id: StringName, topic: StudyTopic, task_id: StringName) -> StringName:
	var task := topic.find_task(task_id)
	if task == null or not task.enabled:
		return &"unavailable"
	if _is_completed(discipline_id, topic.id, task_id):
		return &"completed"
	if topic.sequential:
		for previous in topic.tasks:
			if previous.id == task_id:
				break
			if not _is_completed(discipline_id, topic.id, previous.id):
				return &"locked"
	return &"available"

func complete(discipline_id: StringName, topic: StudyTopic, task_id: StringName) -> bool:
	if state(discipline_id, topic, task_id) != &"available":
		return false
	var discipline := String(discipline_id)
	var theme := String(topic.id)
	if not _completed.has(discipline):
		_completed[discipline] = {}
	if not _completed[discipline].has(theme):
		_completed[discipline][theme] = []
	_completed[discipline][theme].append(String(task_id))
	return true

func _is_completed(discipline_id: StringName, topic_id: StringName, task_id: StringName) -> bool:
	return String(task_id) in _completed.get(String(discipline_id), {}).get(String(topic_id), [])

func snapshot() -> Dictionary:
	return {"version": 1, "completed": _completed.duplicate(true)}

# Fronteira de persistência: rejeita estados inválidos sem apagar o atual.
func restore(data: Dictionary) -> bool:
	if data.get("version") != 1 or not data.get("completed") is Dictionary:
		return false
	for discipline in data.completed:
		if not discipline is String or not data.completed[discipline] is Dictionary:
			return false
		for topic in data.completed[discipline]:
			var ids: Variant = data.completed[discipline][topic]
			if not topic is String or not ids is Array:
				return false
			for id in ids:
				if not id is String or id.is_empty():
					return false
	_completed = data.completed.duplicate(true)
	return true
