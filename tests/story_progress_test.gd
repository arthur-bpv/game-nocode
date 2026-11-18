extends SceneTree

const SESSION := preload("res://scripts/study/study_session.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var path := "user://story_progress_test_%d.cfg" % Time.get_ticks_usec()
	var legacy_save := ConfigFile.new()
	legacy_save.set_value("redes", "routing", true)
	assert(legacy_save.save(path) == OK)
	var session := _load_session(path)
	var discipline: StudyDiscipline = session.current_discipline()
	var protocols: StudyTopic = discipline.topics[0]
	var routing: StudyTopic = discipline.topics[1]
	assert(session.topic_completed(discipline.id, routing.id))
	assert(session.topic_summary(discipline, routing).state == &"not_started",
		"O distintivo anterior deve ser preservado sem inventar registros de tasks.")
	var badge_signals: Array[StringName] = []
	session.discipline_badge_earned.connect(func(id: StringName) -> void: badge_signals.append(id))

	assert(session.discipline_summary(discipline) == {"completed": 0, "total": 2, "earned": false})
	assert(session.topic_summary(discipline, protocols).state == &"not_started")
	assert(not session.complete(protocols.tasks[1].id), "A ordem pedagógica continua bloqueando as próximas tasks.")
	assert(session.complete(protocols.tasks[0].id))
	assert(session.topic_summary(discipline, protocols).completed == 1)
	assert(session.topic_summary(discipline, protocols).state == &"in_progress")
	assert(session.discipline_summary(discipline).completed == 0)
	session.reset_singleplayer()
	assert(session.task_state(protocols.tasks[0].id) == &"completed")
	assert(session.task_state(protocols.tasks[1].id) == &"available")

	var reloaded := _load_session(path)
	assert(reloaded.task_state(protocols.tasks[0].id) == &"completed")
	reloaded.queue_free()

	for task in protocols.tasks.slice(1):
		assert(session.complete(task.id))
	assert(session.topic_summary(discipline, protocols).state == &"completed")
	assert(session.topic_completed(discipline.id, protocols.id))
	assert(session.discipline_summary(discipline) == {"completed": 1, "total": 2, "earned": false})
	assert(not session.badge_earned(discipline.id) and badge_signals.is_empty())

	assert(session.select(discipline.id, routing.id))
	for task in routing.tasks:
		assert(session.complete(task.id))
	assert(session.discipline_summary(discipline) == {"completed": 2, "total": 2, "earned": true})
	assert(badge_signals == [discipline.id])
	assert(not session.complete(routing.tasks[0].id))
	assert(badge_signals == [discipline.id])

	reloaded = _load_session(path)
	assert(reloaded.badge_earned(discipline.id))
	assert(reloaded.discipline_summary(discipline) == session.discipline_summary(discipline))
	reloaded.queue_free()

	var upcoming := StudyTopic.new()
	upcoming.id = &"upcoming"
	upcoming.enabled = false
	upcoming.required = false
	assert(session.topic_summary(discipline, upcoming).state == &"unavailable")
	assert(not session.select(discipline.id, upcoming.id))
	var empty := StudyDiscipline.new()
	empty.id = &"empty"
	empty.topics.append(upcoming)
	assert(session.discipline_summary(empty) == {"completed": 0, "total": 0, "earned": false})

	session.queue_free()
	await process_frame
	assert(DirAccess.remove_absolute(path) == OK)
	print("Story progress checks passed.")
	quit()

func _load_session(path: String) -> Node:
	var session := SESSION.new()
	session._save_path = path
	root.add_child(session)
	return session
