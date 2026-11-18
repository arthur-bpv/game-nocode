extends SceneTree

const TASK_ID := &"encapsulamento_esteira"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var session := root.get_node("StudySession")
	var topic := session.current_topic() as StudyTopic
	for task in topic.tasks:
		if task.id == TASK_ID:
			break
		assert(session.progress.complete(session.discipline_id, topic, task.id))
	var slot_path := "Entities/" + String(topic.find_task(TASK_ID).map_slot)
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	root.add_child(world)
	var slot = world.get_node(slot_path)
	assert(slot._task != null and slot._task.id == TASK_ID)
	var mission = slot._mission
	var tablet = world.get_node("CanvasLayer/TabletUi")
	var player: CharacterBody2D = world.get_node("Entities/player/Player")
	assert(not mission.visible and not tablet.visible)
	assert(slot.get_node("TaskTerminalSprite").texture.resource_path.ends_with("task_terminal.png"))
	assert(slot.get_node("TaskBeacon").text == "!")
	player.global_position = slot.global_position + slot._task.terminal_offset + Vector2(0, 80)
	player.reset_physics_interpolation()
	for frame in 5:
		await physics_frame
	var interact := InputEventAction.new()
	interact.action = &"interact"
	interact.pressed = true
	root.push_input(interact)
	await process_frame
	assert(tablet.visible and mission.is_visible_in_tree())
	assert(not player.is_physics_processing())

	var row_positions: Array[Vector2] = []
	for row: Control in mission._rows:
		row_positions.append(row.position)

	mission._choices[2].pressed.emit()
	assert(mission._stage == 0 and "Internet" in mission._feedback.text)
	assert(session.task_state(TASK_ID) == &"available")
	mission._choices[0].pressed.emit()
	assert(mission._stage == 1)
	tablet.close_ui()
	assert(player.is_physics_processing())
	root.push_input(interact)
	assert(tablet.visible and mission._stage == 1)
	for index in range(1, 4):
		mission._choices[index].pressed.emit()
		await process_frame
		assert(mission._rows[index].position == row_positions[index])
	assert(mission._stage == 4)
	assert(session.task_state(TASK_ID) == &"completed")
	assert(slot.get_node("TaskBeacon").text == "✓")
	assert("roteador" in mission._feedback.text and "servidor" in mission._feedback.text)
	mission._replay.pressed.emit()
	assert(mission._stage == 0 and not mission._guided)
	assert(session.task_state(TASK_ID) == &"completed")
	mission._hint.pressed.emit()
	assert("navegador" in mission._instruction.text)

	tablet.close_ui()
	await process_frame
	var notice := world.get_node("CanvasLayer/UiController/StudyCompletionNotice") as Control
	assert(notice.visible)
	notice.get_node("Timer").timeout.emit()
	await process_frame
	world.queue_free()
	await process_frame
	world = load("res://scenes/world/world.tscn").instantiate()
	root.add_child(world)
	mission = world.get_node(slot_path)._mission
	assert(mission._stage == 4 and mission._replay.visible)
	world.queue_free()
	await process_frame
	print("Encapsulation terminal checks passed.")
	quit()
