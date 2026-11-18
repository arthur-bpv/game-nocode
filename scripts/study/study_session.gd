extends Node

signal progress_changed
signal task_completed(task_id: StringName)
signal discipline_badge_earned(discipline_id: StringName)

const DEFAULT_DISCIPLINE_ID: StringName = &"redes"
const DEFAULT_TOPIC_ID: StringName = &"tcp_ip_modelo_osi"
const COMPLETIONS_PATH := "user://completed_topics.cfg"
const STORY_SECTION := "_netbot_story"
const BADGES_SECTION := "_netbot_discipline_badges"

var catalog: StudyCatalog = preload("res://data/study/catalog.tres")
var progress := TaskProgress.new()
var _completions := ConfigFile.new()
var _save_path := COMPLETIONS_PATH
var discipline_id: StringName = DEFAULT_DISCIPLINE_ID
var topic_id: StringName = DEFAULT_TOPIC_ID

func _ready() -> void:
	var load_error := _completions.load(_save_path)
	if load_error != OK and load_error != ERR_FILE_NOT_FOUND:
		push_warning("Não foi possível carregar o progresso: %s" % error_string(load_error))
	for error in catalog.validate():
		push_error(error)
	var saved: Variant = _completions.get_value(STORY_SECTION, "tasks", {})
	if saved is Dictionary and not saved.is_empty():
		if progress.restore(saved):
			# Reconhece um snapshot válido mesmo se tiver sido salvo antes da badge.
			for discipline in catalog.disciplines:
				if _record_achievements(discipline):
					_save_progress()
		else:
			push_warning("O progresso das atividades tem um formato inválido.")

func select(discipline: StringName, topic: StringName) -> bool:
	var definition := catalog.find_discipline(discipline)
	var selected := definition.find_topic(topic) if definition != null else null
	if selected == null or not selected.enabled:
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
	_commit_progress()
	task_completed.emit(task_id)
	return true

# O distintivo histórico do assunto é preservado separadamente da badge da disciplina.
func topic_completed(discipline: StringName, topic: StringName) -> bool:
	return _completions.get_value(String(discipline), String(topic), false) == true

func topic_summary(discipline: StudyDiscipline, topic: StudyTopic) -> Dictionary:
	var total := 0
	var completed := 0
	var playable := false
	var started := false
	for task in topic.tasks:
		if not task.enabled:
			continue
		var state := task_state_for(discipline.id, topic, task.id)
		started = started or state == &"completed"
		playable = playable or state in [&"available", &"completed"]
		if not task.always_available:
			total += 1
			if state == &"completed":
				completed += 1
	var state := &"unavailable"
	if total > 0 and completed == total:
		state = &"completed"
	elif playable:
		state = &"in_progress" if started else &"not_started"
	return {"completed": completed, "total": total, "state": state}

func discipline_summary(discipline: StudyDiscipline) -> Dictionary:
	var total := 0
	var completed := 0
	for topic in discipline.topics:
		if topic.required:
			total += 1
			if topic_summary(discipline, topic).state == &"completed":
				completed += 1
	return {"completed": completed, "total": total, "earned": badge_earned(discipline.id)}

func badge_earned(discipline: StringName) -> bool:
	return _completions.get_value(BADGES_SECTION, String(discipline), false) == true

func task_state_for(discipline: StringName, topic: StudyTopic, task_id: StringName) -> StringName:
	return progress.state(discipline, topic, task_id)

func task_state(task_id: StringName) -> StringName:
	return task_state_for(discipline_id, current_topic(), task_id)

func next_available_task() -> StudyTask:
	for task in current_topic().tasks:
		if task_state(task.id) == &"available":
			return task
	return null

func restore_progress(data: Dictionary) -> bool:
	if not progress.restore(data):
		return false
	_commit_progress()
	return true

func reset_singleplayer() -> void:
	# A navegação e a aleatoriedade pertencem à partida, o progresso ao perfil local.
	discipline_id = DEFAULT_DISCIPLINE_ID
	topic_id = DEFAULT_TOPIC_ID
	var challenge_session: Node = get_node_or_null("/root/ChallengeSession")
	if challenge_session != null:
		challenge_session.start_new_session()
	progress_changed.emit()

func _commit_progress() -> void:
	var earned: Array[StringName] = []
	for discipline in catalog.disciplines:
		if _record_achievements(discipline):
			earned.append(discipline.id)
	_save_progress()
	progress_changed.emit()
	for id in earned:
		discipline_badge_earned.emit(id)

func _record_achievements(discipline: StudyDiscipline) -> bool:
	var requirements := discipline_summary(discipline)
	for topic in discipline.topics:
		if not topic_completed(discipline.id, topic.id) and topic_summary(discipline, topic).state == &"completed":
			_completions.set_value(String(discipline.id), String(topic.id), true)
	if requirements.earned or requirements.total == 0 or requirements.completed != requirements.total:
		return false
	_completions.set_value(BADGES_SECTION, String(discipline.id), true)
	return true

func _save_progress() -> void:
	_completions.set_value(STORY_SECTION, "tasks", progress.snapshot())
	var temporary_path := _save_path + ".tmp"
	var error := _completions.save(temporary_path)
	if error == OK:
		error = DirAccess.rename_absolute(temporary_path, _save_path)
	if error != OK:
		push_warning("Não foi possível salvar o progresso: %s" % error_string(error))
