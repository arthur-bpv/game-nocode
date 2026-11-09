extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	root.add_child(world)
	var slot = world.get_node("Entities/sala_superior_esquerda_principal")
	var mission = slot._mission
	var tablet = world.get_node("CanvasLayer/TabletUi")
	var player: CharacterBody2D = world.get_node("Entities/player/Player")
	assert(not mission.visible and mission.get_node_or_null("ConveyorCollision") == null,
		"A sala deve conter só o terminal da atividade.")
	var interact := InputEventAction.new()
	interact.action = &"interact"
	interact.pressed = true
	root.push_input(interact)
	assert(not tablet.visible)
	player.global_position = slot.global_position + slot._task.terminal_offset - Vector2(0, 26)
	player.reset_physics_interpolation()
	for frame in 5:
		await physics_frame
	root.push_input(interact)
	assert(tablet.visible and mission.is_visible_in_tree() and not player.is_physics_processing())
	assert(mission.STEPS.size() == 3)
	mission.answers[0].pressed.emit()
	assert(mission.step_index == 0 and mission.packet.position == mission.stops[0])
	mission.answers[1].pressed.emit()
	assert(mission.answers[0].disabled)
	tablet.close_ui()
	await create_timer(0.55).timeout
	root.push_input(interact)
	assert(tablet.visible and mission.step_index == 1 and mission.packet.position == mission.stops[1])
	mission.answers[0].pressed.emit()
	await create_timer(0.55).timeout
	mission.answers[2].pressed.emit()
	await create_timer(0.55).timeout
	assert(mission.step_index == 3 and mission.packet.position == mission.stops[3])
	assert(root.get_node("StudySession").task_state(&"esteira_pacotes") == &"completed")
	mission.replay.pressed.emit()
	assert(mission.step_index == 0 and mission.packet.position == mission.stops[0])
	assert(root.get_node("StudySession").task_state(&"esteira_pacotes") == &"completed")
	tablet.close_ui()
	assert(player.is_physics_processing())
	print("Packet tablet checks passed")
	quit()
