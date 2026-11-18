extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var session := root.get_node("StudySession")
	# Continua validando o modo físico, disponível por configuração da task.
	session.catalog = session.catalog.duplicate(true)
	session.current_topic().find_task(&"conecta_camadas").presentation = 0
	assert(not session.select(&"missing", &"tcp_ip_modelo_osi"))
	assert(session.select(&"redes", &"tcp_ip_modelo_osi"))
	assert(session.complete(&"rack_osi"))
	assert(session.complete(&"sinais_osi"))
	var world = load("res://scenes/world/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var slot = world.get_node("Entities/sala_superior_esquerda_principal")
	var mission = slot._mission
	assert(mission.position == Vector2.ZERO)
	assert(mission.size == Vector2(680, 460))
	assert(slot.global_position == world.get_node("MapLayout/Pieces/UpperLeftRoom/MissionSlots/Primary").global_position)
	assert(mission.visible)
	assert(mission._connected.is_empty(), "A atividade deve começar sem fios conectados.")
	var source: String = mission.OSI_CAMADAS[0]
	var wrong_target: String = "internet" if mission.MAPA_OSI_TCP[source] != "internet" else "transporte"
	_drag(mission, source, wrong_target)
	assert(session.task_state(&"conecta_camadas") == &"available")
	assert(mission._connected.is_empty())
	assert("Tente de novo" in mission.get_node("%Feedback").text)
	var wire_layer: Control = mission.get_node("%Interaction/ConnectionBoard/WireLayer")
	var sample_curve: PackedVector2Array = wire_layer._curve(
		mission._osi_jacks["aplicacao"].get_center(), mission._tcp_jacks["aplicacao"].get_center()
	)
	assert(sample_curve.size() == 25)
	assert(sample_curve[0] == mission._osi_jacks["aplicacao"].get_center())
	assert(sample_curve[-1] == mission._tcp_jacks["aplicacao"].get_center())
	for layer in mission.OSI_CAMADAS:
		_drag(mission, layer, mission.MAPA_OSI_TCP[layer])
	assert(session.task_state(&"conecta_camadas") == &"completed")
	assert("Missão completa" in mission.get_node("%Feedback").text)
	assert(not session.complete(&"conecta_camadas"))
	var saved: Dictionary = session.progress.snapshot()
	world.queue_free()
	await process_frame
	assert(session.restore_progress(saved))
	world = load("res://scenes/world/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	mission = world.get_node("Entities/sala_superior_esquerda_principal")._mission
	assert(mission._connected.size() == 7)
	assert("Missão completa" in mission.get_node("%Feedback").text)
	world.queue_free()
	await process_frame
	assert(not session.select(&"redes", &"tcp_ip"))
	assert(not session.select(&"redes", &"modelo_osi"))
	var menu = load("res://scenes/menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	menu.get_node("%SingleplayerButton").pressed.emit()
	var discipline_card := menu.find_child("Discipline_redes", true, false) as Button
	assert(discipline_card != null)
	discipline_card.pressed.emit()
	var topic_card := menu.find_child("Topic_tcp_ip_modelo_osi", true, false) as Button
	assert(topic_card != null)
	topic_card.pressed.emit()
	assert(menu.find_child("LaunchButton", true, false).text == "Continuar")
	menu.queue_free()
	await process_frame
	# Um tema sem tasks não herda a missão que antes estava embutida no mapa.
	var original_catalog = session.catalog
	session.catalog = original_catalog.duplicate(true)
	session.current_topic().tasks.clear()
	world = load("res://scenes/world/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	assert(world.get_node("Entities/sala_superior_esquerda_principal").get_child_count() == 0)
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
	mission._handle_board_input(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = mission._tcp_jacks[target].get_center()
	mission._handle_board_input(release)
