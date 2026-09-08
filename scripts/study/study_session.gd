extends Node

signal progress_changed

var catalog: StudyCatalog = preload("res://data/study/catalog.tres")
var progress := TaskProgress.new()
var discipline_id: StringName = &"redes"
var topic_id: StringName = &"tcp_ip_modelo_osi"

func _ready() -> void:
	for error in catalog.validate():
		push_error(error)

func select(discipline: StringName, topic: StringName) -> bool:
	var definition := catalog.find_discipline(discipline)
	if definition == null or definition.find_topic(topic) == null:
		return false
	discipline_id = discipline
	topic_id = topic
	return true

func current_discipline() -> StudyDiscipline:
	return catalog.find_discipline(discipline_id)

func current_topic() -> StudyTopic:
	return current_discipline().find_topic(topic_id)

func complete(task_id: StringName) -> bool:
	if not progress.complete(discipline_id, current_topic(), task_id):
		return false
	progress_changed.emit()
	return true

func task_state(task_id: StringName) -> StringName:
	return progress.state(discipline_id, current_topic(), task_id)

func restore_progress(data: Dictionary) -> bool:
	if not progress.restore(data):
		return false
	progress_changed.emit()
	return true
