extends Node

signal progress_changed

var catalog: StudyCatalog = preload("res://data/study/catalog.tres")
var progress := TaskProgress.new()
const DEFAULT_DISCIPLINE_ID: StringName = &"redes"
const DEFAULT_TOPIC_ID: StringName = &"tcp_ip_modelo_osi"
const COMPLETIONS_PATH := "user://completed_topics.cfg"
var _completions := ConfigFile.new()
var discipline_id: StringName = DEFAULT_DISCIPLINE_ID
var topic_id: StringName = DEFAULT_TOPIC_ID

func _ready() -> void:
	_completions.load(COMPLETIONS_PATH)
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
	_record_topic_completion()
	progress_changed.emit()
	return true

func topic_completed(discipline: StringName, topic: StringName) -> bool:
	return _completions.get_value(String(discipline), String(topic), false) == true

func _record_topic_completion() -> void:
	if topic_completed(discipline_id, topic_id):
		return
	var topic := current_topic()
	var has_required_tasks := false
	for task in topic.tasks:
		if not task.enabled or task.always_available:
			continue
		has_required_tasks = true
		if task_state(task.id) != &"completed":
			return
	if has_required_tasks:
		_completions.set_value(String(discipline_id), String(topic_id), true)
		var error := _completions.save(COMPLETIONS_PATH)
		if error != OK:
			push_warning("Não foi possível salvar a conclusão do tema: %s" % error_string(error))

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
