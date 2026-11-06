extends Node

signal progress_changed

var catalog: StudyCatalog = preload("res://data/study/catalog.tres")
var progress := TaskProgress.new()
const DEFAULT_DISCIPLINE_ID: StringName = &"redes"
const DEFAULT_TOPIC_ID: StringName = &"tcp_ip_modelo_osi"
var discipline_id: StringName = DEFAULT_DISCIPLINE_ID
var topic_id: StringName = DEFAULT_TOPIC_ID

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

func reset_singleplayer() -> void:
	# A sessão singleplayer é descartada por completo ao retornar ao menu.
	# Uma instância nova impede que qualquer task concluída ou desbloqueada
	# permaneça em memória, mesmo se o jogador não tiver concluído nenhuma.
	progress = TaskProgress.new()
	discipline_id = DEFAULT_DISCIPLINE_ID
	topic_id = DEFAULT_TOPIC_ID
	progress_changed.emit()
