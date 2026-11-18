extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var session := root.get_node("StudySession")
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var canvas := world.get_node("CanvasLayer")
	var hud := canvas.get_node("TaskProgressHud") as Control
	var toggle := hud.get_node("%Toggle") as Button
	var details := hud.get_node("%Details") as ScrollContainer
	var rows := hud.get_node("%Rows")
	var tasks: Array = session.current_topic().tasks
	assert(hud.position == Vector2(24, 24) and details.visible)
	assert(rows.get_child_count() == tasks.size())
	assert("0/%d" % tasks.size() in toggle.text)
	toggle.pressed.emit()
	assert(not details.visible)
	assert(session.complete(tasks[0].id))
	assert("1/%d" % tasks.size() in toggle.text and not details.visible)
	toggle.pressed.emit()
	assert(details.visible)
	assert(rows.get_child(0).get_node("State").text == "CONCLUÍDA")

	var tablet := canvas.get_node("TabletUi")
	tablet.open_ui()
	assert(not hud.visible)
	tablet.close_ui()
	assert(hud.visible and details.visible)
	var pause := canvas.get_node("Pause") as Control
	pause.show()
	assert(not hud.visible)
	pause.hide()
	assert(hud.visible)

	world.queue_free()
	await process_frame
	assert(session.select(&"redes", &"routing"))
	world = load("res://scenes/world/world_routing.tscn").instantiate()
	root.add_child(world)
	await process_frame
	hud = world.get_node("CanvasLayer/TaskProgressHud")
	assert(hud.get_node("%Rows").get_child_count() == session.current_topic().tasks.size())
	assert(hud.get_node("%Rows").get_child(0).get_node("Title").text == session.current_topic().tasks[0].title)
	world.queue_free()
	await process_frame
	print("Task progress HUD checks passed.")
	quit()
