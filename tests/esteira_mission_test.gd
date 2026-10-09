extends SceneTree

var _failed := false
var _completed_count := 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene := load("res://scenes/missions/esteira.tscn") as PackedScene
	_check(scene != null, "A cena da esteira não pôde ser carregada.")
	if scene == null:
		quit(1)
		return
	var mission := scene.instantiate()
	root.add_child(mission)
	mission.completed.connect(func() -> void: _completed_count += 1)
	await process_frame

	_check(mission.package != null, "O pacote não foi criado.")
	_check(mission.cabin_sprites.size() == 7, "A esteira precisa ter sete cabines.")
	_check(mission.cabin_lights.size() == 7, "Cada cabine precisa ter um indicador.")
	_check(mission.state == 0 and not mission.conveyor_on, "A missão deve começar desligada.")
	mission._turn_conveyor_on()
	await create_timer(0.95).timeout
	_check(mission.conveyor_on and mission.package.visible, "O painel verde deve iniciar a esteira e exibir o pacote.")

	for index in range(mission.STAGES.size()):
		mission._enter_current_cabin()
		await create_timer(0.55).timeout
		_check(mission.state == mission.TaskState.PROCESSING, "A cabine %d não entrou em processamento." % (index + 1))
		if index == 3:
			mission._handle_segment_choice(1)
			mission._handle_segment_choice(2)
			mission._handle_segment_choice(3)
		else:
			var stage: Dictionary = mission.STAGES[index]
			mission._validate_answer(int(stage["answer"]))
		await create_timer(1.4).timeout

	await create_timer(0.4).timeout
	_check(mission.state == mission.TaskState.COMPLETED, "A entrega final não foi concluída.")
	_check(_completed_count == 1, "A missão deve emitir completed uma única vez.")

	mission.restore_completed()
	_check(_completed_count == 1, "Restaurar progresso não pode emitir completed.")
	mission._reset_task(true)
	_check(mission.state == mission.TaskState.IDLE and mission.stage_index == 0, "Reiniciar precisa restaurar o estado inicial.")

	mission.queue_free()
	await process_frame
	if _failed:
		quit(1)
		return
	print("Esteira mission checks passed: sete etapas, pacote, conclusão, restauração e reinício.")
	quit(0)

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
