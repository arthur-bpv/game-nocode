class_name StudyCatalog
extends Resource

@export var disciplines: Array[StudyDiscipline] = []

func find_discipline(discipline_id: StringName) -> StudyDiscipline:
	for discipline in disciplines:
		if discipline.id == discipline_id:
			return discipline
	return null

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	var discipline_ids := {}
	for discipline in disciplines:
		if discipline == null:
			errors.append("Disciplina nula")
			continue
		_check_id(discipline.id, discipline_ids, "disciplina", errors)
		if not ResourceLoader.exists(discipline.map_scene, "PackedScene"):
			errors.append("Mapa ausente: " + discipline.map_scene)
		var topic_ids := {}
		for topic in discipline.topics:
			if topic == null:
				errors.append("Tema nulo")
				continue
			_check_id(topic.id, topic_ids, "tema", errors)
			var task_ids := {}
			var slots := {}
			for task in topic.tasks:
				if task == null:
					errors.append("Task nula")
					continue
				_check_id(task.id, task_ids, "task", errors)
				if task.enabled:
					_check_id(task.map_slot, slots, "slot", errors)
					if not ResourceLoader.exists(task.mission_scene, "PackedScene"):
						errors.append("Missão ausente: " + task.mission_scene)
	return errors

func _check_id(id: StringName, seen: Dictionary, kind: String, errors: PackedStringArray) -> void:
	if id == &"" or seen.has(id):
		errors.append("ID vazio/duplicado de %s: %s" % [kind, id])
	seen[id] = true
