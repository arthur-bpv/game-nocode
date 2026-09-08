extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var session := root.get_node("StudySession")
	# Continua validando o modo físico, disponível por configuração da task.
	session.catalog = session.catalog.duplicate(true)
	session.current_topic().tasks[0].presentation = 0
	assert(not session.select(&"missing", &"tcp_ip_modelo_osi"))
	assert(session.select(&"redes", &"tcp_ip_modelo_osi"))
	var world = load("res://scenes/world/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var slot = world.get_node("Entities/CamadasSlot")
	assert(slot.get_child_count() == 1)
	var mission = slot.get_child(0)
	assert(mission.position == Vector2.ZERO)
	assert(mission.size == Vector2(680, 460))
	assert(slot.position == Vector2(1077, -756))
	assert(mission.visible)
	# Exercita os eventos reais de arrastar/soltar, incluindo resposta incorreta.
	_drag(mission, "aplicacao", "internet")
	assert(session.task_state(&"conecta_camadas") == &"available")
	assert(mission._connected.is_empty())
	for layer in mission.OSI_CAMADAS:
		_drag(mission, layer, mission.MAPA_OSI_TCP[layer])
	assert(session.task_state(&"conecta_camadas") == &"completed")
	assert(not session.complete(&"conecta_camadas"))
	var saved: Dictionary = session.progress.snapshot()
	world.queue_free()
	await process_frame
	assert(session.restore_progress(saved))
	world = load("res://scenes/world/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	mission = world.get_node("Entities/CamadasSlot").get_child(0)
	assert(mission._connected.size() == 7)
	assert(mission.get_node("StatusLabel").text == "Missão completa!")
	world.queue_free()
	await process_frame
	assert(not session.select(&"redes", &"tcp_ip"))
	assert(not session.select(&"redes", &"modelo_osi"))
	var menu = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	assert(menu._disciplines.item_count == 1)
	assert(menu._topics.item_count == 1)
	assert(menu._topics.get_item_text(menu._topics.selected) == "TCP/IP + Modelo OSI")
	menu.queue_free()
	await process_frame
	# Um tema sem tasks não herda a missão que antes estava embutida no mapa.
	var original_catalog = session.catalog
	session.catalog = original_catalog.duplicate(true)
	session.current_topic().tasks.clear()
	world = load("res://scenes/world/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	assert(world.get_node("Entities/CamadasSlot").get_child_count() == 0)
	world.queue_free()
	await process_frame
	session.catalog = original_catalog
	print("Study runtime checks passed: mission input, completion, return, combined topic, selector.")
	quit()

func _drag(mission: Control, source: String, target: String) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = mission._osi_jacks[source].get_center()
	mission._gui_input(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = mission._tcp_jacks[target].get_center()
	mission._gui_input(release)
