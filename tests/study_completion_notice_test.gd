extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var session := root.get_node("StudySession")
	var world := (load("res://scenes/world/world.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	var canvas := world.get_node("CanvasLayer")
	var notice := canvas.get_node("UiController/StudyCompletionNotice") as Control
	var timer := notice.get_node("Timer") as Timer
	var tablet := canvas.get_node("TabletUi")
	var tasks: Array = session.current_topic().tasks
	assert(not notice.visible)

	assert(session.complete(tasks[0].id))
	await process_frame
	assert(not paused and notice.visible and not timer.is_stopped())
	assert(tasks[0].title == notice.get_node("%CompletedTitle").text)
	assert(tasks[1].title in notice.get_node("%NextRoom").text)
	timer.timeout.emit()
	assert(not notice.visible)
	assert(not session.complete(tasks[0].id))
	await process_frame
	assert(not notice.visible)

	tablet.open_ui()
	assert(session.complete(tasks[1].id))
	await process_frame
	assert(tablet.visible and not notice.visible and not paused)
	tablet.close_ui()
	await process_frame
	assert(not paused and notice.visible and tasks[2].title in notice.get_node("%NextRoom").text)

	for index in range(2, tasks.size()):
		assert(session.complete(tasks[index].id))
		await process_frame
		assert(not paused and notice.visible)
		assert(tasks[index].title == notice.get_node("%CompletedTitle").text)
	assert("Tema concluído" == notice.get_node("%Heading").text)
	assert(not notice.get_node("%NextRoom").visible)

	world.queue_free()
	await process_frame
	assert(session.select(&"redes", &"routing"))
	world = (load("res://scenes/world/world_routing.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	assert(session.complete(session.current_topic().tasks[0].id))
	await process_frame
	assert(not paused and world.get_node_or_null("CanvasLayer/UiController/StudyCompletionNotice") == null)
	world.queue_free()
	await process_frame
	print("Study completion notice checks passed.")
	quit()
