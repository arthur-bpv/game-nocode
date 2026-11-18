extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var session := root.get_node("StudySession")
	for task in session.current_topic().tasks.slice(0, 4):
		assert(session.complete(task.id))
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	root.add_child(world)
	var tablet = world.get_node("CanvasLayer/TabletUi")
	var transport = await _open(world, "sala_superior_direita_principal")
	await process_frame
	assert(tablet.visible and transport.confirm.disabled and transport.round_index == 0)
	assert(transport.interaction.get_child_count() == 3)
	var panel_content: Control = transport.get_node("Center/Content")
	assert(absf(panel_content.get_rect().get_center().y - transport.size.y * 0.5) <= 1.0)
	transport.options[1].pressed.emit()
	transport.confirm.pressed.emit()
	assert(transport.round_index == 0 and "Erro" in transport.feedback.text)
	transport.options[0].pressed.emit()
	transport.confirm.pressed.emit()
	transport.confirm.pressed.emit()
	assert(transport.confirm.disabled)
	var escape := InputEventAction.new()
	escape.action = &"ui_cancel"
	escape.pressed = true
	root.push_input(escape)
	assert(not tablet.visible and not world.get_node("CanvasLayer/Pause").visible)
	await create_timer(0.7).timeout
	await _open(world, "sala_superior_direita_principal")
	assert(transport.round_index == 1)
	for answer in [1, 0]:
		transport.options[answer].pressed.emit()
		transport.confirm.pressed.emit()
		await create_timer(0.7).timeout
	assert(session.task_state(&"escolher_transporte") == &"completed")
	tablet.close_ui()
	var notice := world.get_node("CanvasLayer/UiController/StudyCompletionNotice")
	await process_frame
	assert(notice.visible and "Sala 06" in notice.get_node("%NextRoom").text)
	notice.get_node("Timer").timeout.emit()
	await process_frame

	var repair = await _open(world, "sala_inferior_direita_principal")
	assert(tablet.visible and repair.send.disabled)
	for index in [1, 0, 2, 3]:
		repair.cards[index].pressed.emit()
	assert(not repair.send.disabled)
	repair.send.pressed.emit()
	assert("Erro" in repair.feedback.text and session.task_state(&"reparar_encapsulamento") == &"available")
	repair.slots[0].pressed.emit()
	assert(not repair.cards[1].disabled and repair.send.disabled)
	root.push_input(escape)
	assert(not tablet.visible)
	await _open(world, "sala_inferior_direita_principal")
	assert(repair.order == [-1, 0, 2, 3])
	repair.clear.pressed.emit()
	assert(repair.order.count(-1) == 4)
	for index in range(4):
		repair.cards[index].pressed.emit()
		repair.cards[index].pressed.emit()
	assert(repair.order == [0, 1, 2, 3])
	repair.send.pressed.emit()
	assert(repair.send.disabled and repair.clear.disabled)
	await create_timer(1.3).timeout
	assert(repair.depth == 4 and session.task_state(&"reparar_encapsulamento") == &"completed")
	assert("6/7" in world.get_node("CanvasLayer/TaskProgressHud/%Toggle").text)
	world.queue_free()
	await process_frame
	print("Network repair tablet checks passed.")
	quit()

func _open(world: Node, slot_name: String) -> Control:
	var slot = world.get_node_or_null("Entities/" + slot_name)
	assert(slot != null and slot._mission != null)
	var player = world.get_node("Entities/player/Player")
	player.global_position = slot.global_position + slot._task.terminal_offset + Vector2(0, 70)
	player.reset_physics_interpolation()
	for frame in 4:
		await physics_frame
	var interact := InputEventAction.new()
	interact.action = &"interact"
	interact.pressed = true
	root.push_input(interact)
	return slot._mission
