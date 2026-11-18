extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var session := root.get_node("StudySession")
	assert(session.complete(&"rack_osi"))
	assert(session.complete(&"sinais_osi"))
	var world = load("res://scenes/world/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var slot = world.get_node("Entities/sala_superior_esquerda_principal")
	var mission: Control = slot._mission
	var tablet = world.get_node("CanvasLayer/TabletUi")
	var player = world.get_node("Entities/player/Player")
	var router = world.get_node("CanvasLayer/UiController")
	assert(not mission.visible)
	var interact := InputEventAction.new()
	interact.action = "interact"
	interact.pressed = true
	slot._unhandled_input(interact)
	assert(not tablet.visible, "Não pode abrir de longe")
	# Posiciona o corpo físico no alcance do terminal, considerando o offset existente.
	player.global_position = slot.global_position + slot._task.terminal_offset + Vector2(0, 36) - player.get_node("CollisionShape2D").position
	player.reset_physics_interpolation()
	for frame in range(5):
		await physics_frame
	assert(not slot._nearby.is_empty(), "Área precisa reconhecer o player")
	slot._task.enabled = false
	slot._unhandled_input(interact)
	assert(not tablet.visible, "Task indisponível não abre no tablet")
	slot._task.enabled = true
	slot._unhandled_input(interact)
	await process_frame
	assert(tablet.visible and mission.is_visible_in_tree())
	assert(not player.is_physics_processing())
	assert(mission.get_node_or_null("CloseButton") == null)
	assert(mission._connected.is_empty(), "A atividade deve começar sem fios conectados.")
	var source: String = mission.OSI_CAMADAS[0]
	_drag(mission, source, mission.MAPA_OSI_TCP[source])
	assert(mission._connected.size() == 1)
	var cancel := InputEventAction.new()
	cancel.action = "ui_cancel"
	cancel.pressed = true
	router._unhandled_input(cancel)
	assert(not tablet.visible and player.is_physics_processing())
	assert(not paused)
	slot._unhandled_input(interact)
	assert(mission.is_visible_in_tree() and mission._connected.size() == 1)
	# O X do tablet usa o mesmo caminho de fechamento.
	tablet.get_node("ScreenCenter/Screen/Content/Header/CloseButton").pressed.emit()
	assert(not tablet.visible and player.is_physics_processing())
	slot._unhandled_input(interact)
	for layer in mission.OSI_CAMADAS:
		if not mission._connected.has(layer):
			_drag(mission, layer, mission.MAPA_OSI_TCP[layer])
	assert(session.task_state(&"conecta_camadas") == &"completed")
	var tab := InputEventAction.new()
	tab.action = "toggle_tablet"
	tab.pressed = true
	tablet._input(tab)
	assert(not tablet.visible and player.is_physics_processing())
	await process_frame
	var notice = router.get_node("StudyCompletionNotice")
	assert(notice.visible)
	notice.get_node("Timer").timeout.emit()
	await process_frame
	slot._unhandled_input(interact)
	assert(mission.visible and tablet._replay_button.visible)
	tablet._replay_button.pressed.emit()
	var replay: Control = slot._mission
	assert(replay != mission and replay.visible and replay._connected.is_empty())
	await process_frame
	for layer in replay.OSI_CAMADAS:
		if not replay._connected.has(layer):
			_drag(replay, layer, replay.MAPA_OSI_TCP[layer])
	assert(replay._connected.size() == replay.OSI_CAMADAS.size())
	tablet.close_ui()
	await process_frame
	assert(not notice.visible)
	tablet.open_ui()
	assert(not replay.visible, "Abrir o tablet normal não reabre atividade")
	tablet.close_ui()
	world.queue_free()
	await process_frame
	print("Tablet task checks passed: range, E, close/reopen, partial state, completion, ESC/X/Tab.")
	quit()

func _drag(mission: Control, source: String, target: String) -> void:
	var board: Control = mission.get_node("%Interaction/ConnectionBoard")
	var start: Vector2 = board.get_global_transform_with_canvas() * mission._osi_jacks[source].get_center()
	var end: Vector2 = board.get_global_transform_with_canvas() * mission._tcp_jacks[target].get_center()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = start
	root.push_input(press, true)
	var motion := InputEventMouseMotion.new()
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	motion.position = end
	motion.relative = end - start
	root.push_input(motion, true)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = end
	root.push_input(release, true)
