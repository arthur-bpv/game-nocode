extends SceneTree

const ROOMS := [
	[&"rack_osi", Vector2(0, 1160)],
	[&"sinais_osi", Vector2(-1320, 1000)],
	[&"conecta_camadas", Vector2(-1080, 16)],
	[&"encapsulamento_esteira", Vector2(0, -224)],
	[&"escolher_transporte", Vector2(1280, 208)],
	[&"reparar_encapsulamento", Vector2(1842, 912)],
	[&"inspecao_pacotes", Vector2(809, 720)],
]

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var world := (load("res://scenes/world/world.tscn") as PackedScene).instantiate() as Node2D
	root.add_child(world)
	await physics_frame
	await process_frame
	var route := world.get_node_or_null("TcpIpRoute")
	if route == null:
		push_error("O mundo TCP/IP deve instalar as portas da trilha.")
		quit(1)
		return
	var session := root.get_node("StudySession")
	var player := world.get_node("Entities/player/Player") as CharacterBody2D
	var hud := world.get_node("CanvasLayer/RouteDestination") as Label
	var room_panel := world.get_node("CanvasLayer/PlayerDialogue") as Control
	assert(not room_panel.visible)
	var label_position := hud.position
	var path: Array = route._path.duplicate()
	assert(path.size() > 4)
	var floor_tiles := world.get_node("MapLayout/Floor") as TileMapLayer
	player.global_position = floor_tiles.to_global(floor_tiles.map_to_local(path[2]))
	await physics_frame
	await process_frame
	assert(hud.position == label_position, "A legenda deve permanecer fixa quando o jogador anda.")
	assert(route._path == path.slice(2), "Andar na rota deve preservar o trecho restante.")
	for index in ROOMS.size():
		if not _check_rooms(world, route, index):
			quit(1)
			return
		if not hud.visible or hud.text != "Siga para a sala %02d" % (index + 1):
			push_error("O caminho deve indicar a sala %02d a partir da sala anterior." % (index + 1))
			quit(1)
			return
		player.global_position = ROOMS[index][1]
		await physics_frame
		await process_frame
		await process_frame
		if hud.visible:
			push_error("O caminho deve terminar ao entrar na sala %02d." % (index + 1))
			quit(1)
			return
		assert(room_panel.visible and not room_panel.message_label.text.is_empty())
		assert("Sala %02d" % (index + 1) in room_panel.get_node("Panel/Row/Content/Speaker").text)
		if index < ROOMS.size() - 1 and not session.complete(ROOMS[index][0]):
			push_error("A etapa disponível deve poder ser concluída.")
			quit(1)
			return
		await physics_frame
		await process_frame
		assert(not paused, "A conclusão não deve interromper a circulação.")
		await physics_frame
		await process_frame

	# Simulate loading a fully completed session without overwriting the topic
	# completion file used by an actual player.
	var snapshot: Dictionary = session.progress.snapshot()
	snapshot.completed.redes.tcp_ip_modelo_osi.append("inspecao_pacotes")
	session.restore_progress(snapshot)
	player.global_position = Vector2.ZERO
	await process_frame
	await process_frame
	if hud.visible or not hud.text.is_empty():
		push_error("A trilha concluída deve esconder a indicação.")
		quit(1)
		return
	world.queue_free()
	await process_frame
	print("Portas verificadas no início e após as seis transições.")
	quit()

func _check_rooms(world: Node2D, route: Node, unlocked_index: int) -> bool:
	var floor_tiles := world.get_node("MapLayout/Floor") as TileMapLayer
	var wall_tiles := world.get_node("MapLayout/Walls") as TileMapLayer
	var doors: Dictionary = {}
	for gate in route.get_children():
		if gate is not StaticBody2D:
			continue
		var shape := gate.get_node("Collision") as CollisionShape2D
		var gate_rect := Rect2(gate.global_position - shape.shape.size * 0.5, shape.shape.size)
		var walk_across := Vector2(0, 22) if gate_rect.size.x > gate_rect.size.y else Vector2(22, 0)
		var ray := PhysicsRayQueryParameters2D.create(gate.global_position - walk_across, gate.global_position + walk_across)
		var hit := world.get_world_2d().direct_space_state.intersect_ray(ray)
		if (hit.get("collider") == gate) != not shape.disabled:
			push_error("A colisão da porta deve acompanhar seu estado: %s" % gate.name)
			return false
		if not shape.disabled:
			for cell in floor_tiles.get_used_cells():
				if gate_rect.has_point(floor_tiles.to_global(floor_tiles.map_to_local(cell))):
					doors[cell] = true

	# Flood fill a partir da posição inicial, considerando todas as entradas.
	var spawn := floor_tiles.local_to_map(floor_tiles.to_local(Vector2.ZERO))
	var seen: Dictionary = {spawn: true}
	var pending: Array[Vector2i] = [spawn]
	var cursor := 0
	while cursor < pending.size():
		var current := pending[cursor]
		cursor += 1
		for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var cell: Vector2i = current + direction
			if seen.has(cell) or doors.has(cell):
				continue
			if floor_tiles.get_cell_source_id(cell) == -1 or wall_tiles.get_cell_source_id(cell) != -1:
				continue
			seen[cell] = true
			pending.append(cell)

	for index in ROOMS.size():
		var cell := floor_tiles.local_to_map(floor_tiles.to_local(ROOMS[index][1]))
		if seen.has(cell) != (index <= unlocked_index):
			push_error("Acessibilidade inesperada para a sala %02d na etapa %02d." % [index + 1, unlocked_index + 1])
			return false
	return true
