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
	_check(mission.cabin_centers.size() == 7, "A esteira precisa ter sete cabines.")
	_check(mission.get_node_or_null("CentralCabinReflections") != null,
		"O visor central deve ter reflexos na frente do pacote.")
	for index in range(mission.cabin_centers.size()):
		var entry: Vector2 = mission.package_stops[index]
		var window: Vector2 = mission.cabin_window_points[index]
		var exit: Vector2 = mission.cabin_exit_points[index]
		_check(is_equal_approx(entry.y, window.y) and is_equal_approx(exit.y, window.y),
			"A travessia da cabine deve permanecer na horizontal.")
		_check((entry.x - window.x) * (exit.x - window.x) < 0.0,
			"O pacote deve sair pelo lado oposto ao da entrada.")
		_check(entry.x > window.x if index == 3 else entry.x < window.x,
			"O pacote deve chegar pela lateral de cada cabine.")
	_check(mission.cabin_lights.size() == 7, "Cada cabine precisa ter um indicador.")
	_check(mission.state == 0 and not mission.conveyor_on, "A missão deve começar desligada.")
	var player_scene := load("res://scenes/player/player.tscn") as PackedScene
	var actor := player_scene.instantiate()
	root.add_child(actor)
	var player := actor.get_node("Player") as CharacterBody2D
	player.global_position = mission.get_global_transform() * (mission.panel_rect.get_center() + Vector2(0, 60))
	var player_start := player.global_position
	await physics_frame
	var hit := player.get_world_2d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters2D.create(
			mission.get_global_transform() * Vector2(150, -30),
			mission.get_global_transform() * Vector2(150, 80), 1, [player.get_rid()]))
	_check(hit.get("collider") is StaticBody2D, "A cabine e a correia precisam bloquear o jogador.")
	var interact := InputEventAction.new()
	interact.action = &"interact"
	interact.pressed = true
	root.push_input(interact)
	_check(mission.challenge_panel.visible, "O console deve abrir o painel desde a partida.")
	_check(mission.choice_labels[0].disabled, "O painel deve bloquear respostas durante o transporte.")
	await create_timer(1.35).timeout
	var package_screen_position := mission.package.get_global_transform_with_canvas().origin as Vector2
	_check(package_screen_position.x > 0 and package_screen_position.x < root.get_visible_rect().size.x * 0.55,
		"O pacote precisa aparecer na região livre à esquerda.")
	var panel_rect: Rect2 = mission.challenge_panel.get_global_rect()
	var screen_size := root.get_visible_rect().size
	_check(panel_rect.position.x > screen_size.x * 0.5 and panel_rect.end.x <= screen_size.x,
		"O painel deve ocupar só a parte direita da tela.")

	for index in range(mission.STAGES.size()):
		_check(mission.state == mission.TaskState.PROCESSING, "A cabine %d deve abrir automaticamente." % (index + 1))
		_check(mission.challenge_title.text.contains(mission.STAGES[index]["layer"]),
			"O painel deve mostrar a cabine atual.")
		_check(player.global_position == player_start, "O jogador deve responder sem sair do console.")
		if index == 0:
			mission.choice_labels[1].pressed.emit()
			_check(mission.state == mission.TaskState.ERROR, "Uma resposta incorreta deve reter o pacote.")
			await create_timer(0.75).timeout
			_check(mission.state == mission.TaskState.PROCESSING, "Deve ser possível tentar novamente.")
			mission._close_challenge()
			_check(player.is_physics_processing(), "Fechar o painel devolve o movimento.")
			root.push_input(interact)
			_check(mission.challenge_panel.visible and mission.state == mission.TaskState.PROCESSING,
				"Reabrir deve manter a pergunta e a posição do pacote.")
		if index == 3:
			for choice in mission.choice_labels:
				choice.pressed.emit()
		else:
			var stage: Dictionary = mission.STAGES[index]
			mission.choice_labels[int(stage["answer"]) - 1].pressed.emit()
		var deadline := Time.get_ticks_msec() + 4000
		while mission.state != mission.TaskState.PROCESSING and mission.state != mission.TaskState.COMPLETED:
			if Time.get_ticks_msec() >= deadline:
				_check(false, "O pacote não chegou à próxima parada.")
				quit(1)
				return
			await process_frame

	await create_timer(0.4).timeout
	_check(mission.state == mission.TaskState.COMPLETED, "A entrega final não foi concluída.")
	_check(_completed_count == 1, "A missão deve emitir completed uma única vez.")

	mission.restore_completed()
	_check(_completed_count == 1, "Restaurar progresso não pode emitir completed.")
	mission._reset_task(true)
	_check(mission.state == mission.TaskState.IDLE and mission.stage_index == 0, "Reiniciar precisa restaurar o estado inicial.")

	_check(not mission.challenge_panel.visible and player.is_physics_processing(),
		"Concluir deve fechar o painel e devolver o movimento.")
	actor.queue_free()
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
