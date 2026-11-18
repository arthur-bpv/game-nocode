extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var session := root.get_node("StudySession")
	var world := (load("res://scenes/world/world.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	var canvas := world.get_node("CanvasLayer")
	var tablet := canvas.get_node("TabletUi")
	var notice := canvas.get_node("UiController/StudyCompletionNotice")
	var player := world.get_node("Entities/player/Player") as CharacterBody2D
	var slots := {}
	for task in session.current_topic().tasks:
		slots[task.id] = world.get_node("Entities/" + String(task.map_slot))

	var rack: Control = slots[&"rack_osi"]._mission
	var decoder: Control = slots[&"sinais_osi"]._mission
	var matching: Node2D = slots[&"conecta_camadas"]
	assert(rack.visible and not decoder.visible)
	tablet.open_mission(matching._mission)
	assert(not tablet.visible, "O tablet deve rejeitar a abertura direta de uma etapa futura.")

	# Primeira conclusão pelo fluxo de instalação das baias.
	for block_name in rack.BLOCK_ORDER:
		var block := rack.get_node(block_name) as TextureRect
		rack._start_drag(block.get_rect().get_center())
		rack._finish_drag(rack.rack.position + rack._slot_rect(block_name).get_center())
	await process_frame
	assert(decoder.visible and session.task_state(&"sinais_osi") == &"available")
	assert(notice.visible and "Decodificador" in notice.get_node("%NextRoom").text)
	notice.get_node("Timer").timeout.emit()
	await process_frame

	# Segunda conclusão pelo botão físico do decodificador.
	var button := decoder.buttons["Aplicacao"]["normal"] as TextureRect
	player.global_position = decoder.get_parent().global_position + button.get_rect().get_center()
	decoder._process(0)
	decoder.prompt_order = [{"text": "HTTPS", "answer": "Aplicacao"}]
	decoder.prompt_index = 0
	decoder._show_prompt()
	var interact := InputEventAction.new()
	interact.action = &"interact"
	interact.pressed = true
	root.push_input(interact)
	await create_timer(0.75).timeout
	assert(session.task_state(&"conecta_camadas") == &"available")
	assert(notice.visible and "Correspondência" in notice.get_node("%NextRoom").text)
	notice.get_node("Timer").timeout.emit()
	await process_frame

	player.global_position = matching.global_position + matching._task.terminal_offset + Vector2(0, 45)
	player.reset_physics_interpolation()
	for frame in 4:
		await physics_frame
	root.push_input(interact)
	assert(tablet.visible and matching._mission.is_visible_in_tree())
	tablet.close_ui()

	var replay: Control = slots[&"rack_osi"].restart_mission()
	assert(replay != null and not replay.solved)
	for block_name in replay.BLOCK_ORDER:
		var block := replay.get_node(block_name) as TextureRect
		replay._start_drag(block.get_rect().get_center())
		replay._finish_drag(replay.rack.position + replay._slot_rect(block_name).get_center())
	await process_frame
	assert(replay.solved and not notice.visible)
	assert(session.task_state(&"conecta_camadas") == &"available")

	world.queue_free()
	await process_frame
	print("TCP/IP world progression checks passed: both physical transitions, locked tablet and replay.")
	quit()
