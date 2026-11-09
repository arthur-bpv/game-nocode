extends SceneTree

const TASK_ROOMS := {
	&"sinais_osi": "LowerLeftRoom",
	&"conecta_camadas": "UpperRightRoom",
	&"rack_osi": "LowerCentralRoom",
	&"esteira_pacotes": "UpperLeftRoom",
	&"inspecao_pacotes": "SmallLowerRightRoom",
}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var world := (load("res://scenes/world/world.tscn") as PackedScene).instantiate() as Node2D
	root.add_child(world)
	await process_frame
	var layout := world.get_node("MapLayout/Pieces") as Node2D
	var entities := world.get_node("Entities") as Node2D
	assert(world.get_node_or_null("MapSprite") == null)
	assert(world.get_node_or_null("WorldWalls") == null)
	var anchors := {}
	for piece in layout.get_children():
		if not piece is MapRoom:
			continue
		var anchor := piece.get_node("MissionSlots/Primary") as MapMissionAnchor
		assert(anchor.slot_id != &"" and not anchors.has(anchor.slot_id))
		anchors[anchor.slot_id] = anchor
		var slot := entities.get_node(String(anchor.slot_id)) as Node2D
		assert(slot.global_position.distance_to(anchor.global_position) < 0.01)
	assert(anchors.size() == 7)
	var session := root.get_node("StudySession")
	for task in session.current_topic().tasks:
		var slot := entities.get_node(String(task.map_slot)) as Node2D
		assert(slot._task != null and slot._task.id == task.id)
		assert(slot._mission != null)
		var room_name: String = TASK_ROOMS[task.id]
		assert(slot.global_position == (layout.get_node(room_name).get_node("MissionSlots/Primary") as Marker2D).global_position)
	var player := entities.get_node("player/Player") as CharacterBody2D
	assert(player.global_position.distance_to(Vector2.ZERO) < 0.01)
	await physics_frame
	var factory_room := layout.get_node("UpperLeftRoom") as Node2D
	var factory_slot = entities.get_node("sala_superior_esquerda_principal")
	var console := factory_room.to_local(factory_slot.global_position + factory_slot._task.terminal_offset - Vector2(0, 26))
	var approaches := [
		[Vector2(215, 14), Vector2(console.x, 14), console],
		[Vector2(86, 238), Vector2(86, console.y), console],
	]
	for route in approaches:
		for index in range(1, route.size()):
			var start := factory_room.to_global(route[index - 1])
			var target := factory_room.to_global(route[index])
			assert(not player.test_move(Transform2D(0, start), target - start, null, 0.001),
				"O caminho até o terminal precisa estar livre a partir dos dois corredores.")
	var camera := player.get_node("Camera2D") as Camera2D
	assert(camera.limit_left == -1800 and camera.limit_right == 2400)
	assert(camera.limit_top == -500 and camera.limit_bottom == 1800)
	var tablet = world.get_node("CanvasLayer/TabletUi")
	tablet.open_ui()
	await process_frame
	assert(tablet.get_node_or_null("Frame") == null and not tablet.get_node("%StationMinimap") is TextureRect,
		"A moldura e o minimapa devem usar controles nativos.")
	var map_rect = tablet.get_node("%StationMinimap")
	assert(map_rect.has_layout(), "O minimapa deve ler as células do mundo ativo.")
	var drawn: Rect2 = map_rect.map_area()
	var west: Vector2 = map_rect.world_to_map_position(Vector2(-1000, 0))
	var east: Vector2 = map_rect.world_to_map_position(Vector2(1000, 0))
	assert(drawn.has_point(west) and drawn.has_point(east))
	assert(west.x < east.x and is_equal_approx(west.y, east.y))
	assert(map_rect.player_position().is_equal_approx(map_rect.world_to_map_position(player.global_position)))
	player.global_position += Vector2(64, 32)
	assert(map_rect.player_position().is_equal_approx(map_rect.world_to_map_position(player.global_position)))
	tablet.close_ui()
	world.queue_free()
	await process_frame
	print("Modular world integration checks passed: seven room anchors, five tasks, spawn, camera and tablet map.")
	quit()
