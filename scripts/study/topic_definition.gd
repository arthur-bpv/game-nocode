class_name StudyTopic
extends Resource

@export var id: StringName
@export var title: String
# A posição no array é a ordem pedagógica. Não duplicar com números nos scripts.
@export var sequential: bool = true
@export var tasks: Array[StudyTask] = []

func find_task(task_id: StringName) -> StudyTask:
	for task in tasks:
		if task.id == task_id:
			return task
	return null
