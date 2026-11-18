extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var mission = load("res://scenes/missions/conecta_camadas.tscn").instantiate()
	root.add_child(mission)
	await process_frame
	var board: Control = mission.get_node("%Interaction/ConnectionBoard")
	assert(board.size == Vector2(680, 276))
	assert(mission.get_node("%Title").text == "Correspondência OSI e TCP/IP")
	for layers: Dictionary in [mission._osi_jacks, mission._tcp_jacks]:
		for key: String in layers:
			var jack: Rect2 = layers[key]
			assert(Rect2(Vector2.ZERO, board.size).encloses(jack))
	assert(mission._osi_jacks.size() == 7 and mission._tcp_jacks.size() == 4)
	mission.queue_free()
	await process_frame
	print("Mission labels checks passed.")
	quit()
