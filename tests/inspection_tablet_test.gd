extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var session := root.get_node("StudySession")
	for task in session.current_topic().tasks.slice(0, 6):
		assert(session.complete(task.id))
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	root.add_child(world)
	var slot = world.get_node("Entities/sala_inferior_centro_direita_principal")
	var mission = slot._mission
	var tablet = world.get_node("CanvasLayer/TabletUi")
	var player: CharacterBody2D = world.get_node("Entities/player/Player")
	var station := slot.get_node("InspectionInteraction") as Area2D
	var floor_layer := world.get_node("MapLayout/Floor") as TileMapLayer
	var approach := station.global_position + Vector2(0, 58)
	var cell := floor_layer.local_to_map(floor_layer.to_local(approach))
	assert(floor_layer.get_cell_source_id(cell) >= 0, "A frente do scanner precisa estar no piso.")
	var left := cell
	var right := cell
	while floor_layer.get_cell_source_id(left + Vector2i.LEFT) >= 0:
		left += Vector2i.LEFT
	while floor_layer.get_cell_source_id(right + Vector2i.RIGHT) >= 0:
		right += Vector2i.RIGHT
	var room_center := (floor_layer.map_to_local(left) + floor_layer.map_to_local(right)) * 0.5
	assert(absf(station.global_position.x - floor_layer.to_global(room_center).x) <= 2.0,
		"O scanner deve ficar alinhado ao centro da faixa de piso à sua frente.")
	var beacon := slot.get_node("TaskBeacon") as Label
	var display := slot.get_node("Timer") as Label
	var beacon_rect := beacon.get_global_rect()
	var display_rect := display.get_global_rect()
	assert(not beacon_rect.intersects(display_rect), "O estado e o contador não devem se sobrepor.")
	assert(absf(beacon_rect.merge(display_rect).get_center().x - station.global_position.x) <= 2.0,
		"O conjunto do indicador e do contador deve ficar centralizado sobre o scanner.")
	player.global_position = approach
	player.reset_physics_interpolation()
	for frame in 5:
		await physics_frame
	var corridor := Vector2(0, 128)
	assert(not player.test_move(Transform2D(0, approach + corridor), -corridor),
		"O jogador deve poder se aproximar do scanner vindo do centro da sala.")
	assert(not player.test_move(player.global_transform, corridor),
		"O jogador deve poder voltar ao centro da sala a partir do scanner.")
	var interact := InputEventAction.new()
	interact.action = &"interact"
	interact.pressed = true
	root.push_input(interact)
	await process_frame
	var host = tablet.get_node("ScreenCenter/Screen/Content/MissionHost")
	assert(tablet.visible and mission.get_parent() == host)
	assert(mission.size == host.size and mission.position == Vector2.ZERO)
	assert(not player.is_physics_processing())
	assert(not world.get_node("CanvasLayer/TaskProgressHud").visible)
	assert(slot.get_node_or_null("InspectionOverlay") == null)

	mission.remaining = 0.0
	for frame in 3:
		await process_frame
	assert(mission.is_package_ready())
	mission.package_drawer.pressed.emit()
	assert(mission.inspection_tab.visible)
	var packet: String = mission.tab_request_label.text
	var choice: CheckButton = mission.defect_toggles.values()[0]
	choice.button_pressed = true
	var cancel := InputEventAction.new()
	cancel.action = &"ui_cancel"
	cancel.pressed = true
	root.push_input(cancel)
	assert(not tablet.visible and not mission.is_visible_in_tree())
	assert(player.is_physics_processing())
	assert(world.get_node("CanvasLayer/TaskProgressHud").visible)
	root.push_input(interact)
	assert(tablet.visible and mission.is_package_ready() and mission.inspection_tab.visible)
	assert(mission.tab_request_label.text == packet and choice.button_pressed)
	# Inspeciona as três caixas pelo fluxo de reenviar e aprovar.
	for index in mission.BOX_TOTAL:
		assert(mission.is_package_ready() and mission.queue_index == index)
		for defect in mission.DEFECT_OPTIONS:
			mission.defect_toggles[defect.to_lower()].button_pressed = defect in mission.active_defects
		if not mission.active_defects.is_empty():
			mission.submit_button.pressed.emit()
			assert(mission.returning and mission.pending_return_defects.is_empty())
			mission.remaining = 0.0
			for frame in 3:
				await process_frame
		mission.approve_button.pressed.emit()
		if index + 1 < mission.BOX_TOTAL:
			mission.remaining = 0.0
			for frame in 3:
				await process_frame
	assert(session.task_state(&"inspecao_pacotes") == &"completed")
	var notice := world.get_node("CanvasLayer/UiController/StudyCompletionNotice")
	assert(not notice.visible)
	tablet.close_ui()
	await process_frame
	assert(notice.visible and not notice.get_node("%NextRoom").visible)
	assert("Tema concluído" == notice.get_node("%Heading").text)
	notice.get_node("Timer").timeout.emit()
	await process_frame
	world.queue_free()
	await process_frame
	print("Inspection tablet checks passed.")
	quit()
