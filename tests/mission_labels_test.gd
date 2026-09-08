extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var mission = load("res://scenes/missions/conecta_camadas.tscn").instantiate()
	root.add_child(mission)
	await process_frame
	for cabinet_name in ["OsiCabinet", "TcpCabinet"]:
		var cabinet = mission.get_node(cabinet_name)
		var expected := 7 if cabinet_name == "OsiCabinet" else 4
		assert(cabinet.get_child_count() == expected, "Nomes devem ser Labels editáveis.")
		assert(cabinet.texture.get_size().x <= 1024 and cabinet.texture.get_size().y <= 1024)
		for label in cabinet.get_children():
			assert(label is Label and not label.text.is_empty())
			assert(label.mouse_filter == Control.MOUSE_FILTER_IGNORE)
			assert(label.position.x >= 0 and label.position.y >= 0)
			assert(label.get_rect().end.x <= cabinet.size.x + 1)
			assert(label.get_rect().end.y <= cabinet.size.y + 1)
	assert(is_equal_approx(mission.get_node("OsiCabinet").size.y, 300.0 * 6258 / 4898))
	assert(is_equal_approx(mission.get_node("TcpCabinet").size.y, 300.0 * 6211 / 4734))
	mission.queue_free()
	await process_frame
	print("Mission labels checks passed.")
	quit()
