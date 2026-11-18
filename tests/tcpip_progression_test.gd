extends SceneTree

const ORDER: Array[StringName] = [
	&"rack_osi", &"sinais_osi", &"conecta_camadas", &"encapsulamento_esteira",
	&"escolher_transporte", &"reparar_encapsulamento", &"inspecao_pacotes",
]

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var session := root.get_node("StudySession")
	var tasks: Array = session.current_topic().tasks
	assert(tasks.size() == ORDER.size())
	for index in ORDER.size():
		assert(tasks[index].id == ORDER[index])
		assert(not tasks[index].always_available)

	for index in ORDER.size():
		for other in ORDER.size():
			var expected := &"locked"
			if other < index:
				expected = &"completed"
			elif other == index:
				expected = &"available"
			assert(session.task_state(ORDER[other]) == expected)
		if index + 1 < ORDER.size():
			assert(not session.complete(ORDER[index + 1]))
		assert(session.complete(ORDER[index]))
		assert(not session.complete(ORDER[index]))
		assert(session.restore_progress(session.progress.snapshot()))

	assert(session.topic_completed(&"redes", &"tcp_ip_modelo_osi"))
	session.reset_singleplayer()
	assert(session.task_state(ORDER[0]) == &"completed")
	assert(session.task_state(ORDER[1]) == &"completed")
	assert(session.restore_progress({
		"version": 1,
		"completed": {"redes": {"tcp_ip_modelo_osi": ["encapsulamento_esteira", "inspecao_pacotes"]}},
	}))
	assert(session.task_state(ORDER[3]) == &"locked")
	assert(session.task_state(ORDER[6]) == &"locked")
	for index in 3:
		assert(session.complete(ORDER[index]))
	assert(session.task_state(ORDER[3]) == &"completed")
	assert(session.task_state(ORDER[4]) == &"available")
	assert(session.select(&"redes", &"routing"))
	for task in session.current_topic().tasks:
		assert(session.task_state(task.id) == &"available")
	print("TCP/IP progression checks passed.")
	quit()
