extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var world := (load("res://scenes/world/world.tscn") as PackedScene).instantiate()
	root.add_child(world)
	var layout := world.get_node("MapLayout")
	var floor := layout.get_node_or_null("Floor") as TileMapLayer
	var walls := layout.get_node_or_null("Walls") as TileMapLayer
	assert(floor != null and walls != null, "O mapa jogável deve usar camadas de tiles.")
	assert(floor.tile_set.tile_size == Vector2i(32, 32))
	assert(walls.tile_set == floor.tile_set and walls.collision_enabled)
	assert(floor.get_used_cells().size() > 3000 and walls.get_used_cells().size() > 200)
	var wall_variants := {}
	for cell in walls.get_used_cells():
		var atlas := walls.get_cell_atlas_coords(cell)
		if atlas.y >= 4:
			wall_variants[atlas] = true
	assert(wall_variants.size() >= 6, "As paredes precisam alternar trechos contínuos, painéis e reforços.")
	assert(floor.get_cell_source_id(Vector2i(99, 2)) == 0, "A sala de cabeamento precisa ter uma ala própria.")
	assert(floor.get_cell_source_id(Vector2i(55, 69)) == 0, "O setor sul precisa ter um recuo central.")
	var square_corners := layout.get_node_or_null("SquareWallCorners")
	assert(square_corners != null and square_corners.get_child_count() >= 8,
		"As salas quadradas precisam de peças nos encontros externos de 90 graus.")
	var corner_textures := {}
	for corner: Sprite2D in square_corners.get_children():
		assert(corner.texture.get_size() == Vector2(32, 32))
		var cell := walls.local_to_map(walls.to_local(corner.global_position))
		assert(walls.get_cell_source_id(cell) == 0 and floor.get_cell_source_id(cell) == -1)
		corner_textures[corner.texture] = true
	assert(corner_textures.size() == 4, "Devem existir as quatro orientações de canto.")
	for cell in [Vector2i(94, 2), Vector2i(105, 2), Vector2i(51, 70), Vector2i(59, 70)]:
		assert(walls.get_cell_atlas_coords(cell).y == 5,
			"O canto curto do nicho deve usar um chanfro com acabamento contínuo.")
	var diagonal_tiles := {}
	var diagonals := layout.get_node_or_null("BevelFinishes")
	assert(diagonals != null, "O acabamento precisa ter uma faixa contínua por diagonal.")
	for cell in walls.get_used_cells():
		var atlas := walls.get_cell_atlas_coords(cell)
		if atlas.y == 5:
			diagonal_tiles[atlas] = true
			var data := walls.get_cell_tile_data(cell)
			assert(data.get_collision_polygon_points(0, 0).size() == 3,
				"O chanfro deve ter colisão triangular.")
			assert(data.modulate.a == 0.0, "A arte repetida dos chanfros deve ficar oculta.")
	assert(diagonal_tiles.size() == 4, "As quatro orientações de chanfro devem aparecer no mapa.")
	assert(diagonals.get_child_count() > 4)
	var same_direction_joins := 0
	for finish in diagonals.get_children():
		var face := finish.get_node("Face") as Polygon2D
		assert(face.polygon.size() == 4 and face.polygon[0].distance_to(face.polygon[1]) >= Vector2(32, 32).length(),
			"O acabamento deve cobrir a diagonal inteira da célula.")
		assert(face.texture != null and face.texture.get_size() == Vector2(2, 32),
			"A diagonal deve usar o perfil das paredes retas.")
		var start_out := face.polygon[3] - face.polygon[0]
		var end_out := face.polygon[2] - face.polygon[1]
		if start_out.is_equal_approx(end_out):
			same_direction_joins += 1
	assert(same_direction_joins >= 2, "Os chanfros da ala de observação ligam duas paredes horizontais.")
	for corridor in [Rect2i(16, 31, 5, 9), Rect2i(97, 32, 6, 11)]:
		for y in range(corridor.position.y, corridor.end.y):
			assert(walls.get_cell_source_id(Vector2i(corridor.position.x - 1, y)) == 0)
			assert(walls.get_cell_source_id(Vector2i(corridor.end.x, y)) == 0)
			for x in range(corridor.position.x, corridor.end.x):
				assert(floor.get_cell_source_id(Vector2i(x, y)) == 0,
					"As saídas do norte devem ficar no eixo das salas.")
	var start := floor.local_to_map(floor.to_local(Vector2.ZERO))
	var visited := {start: true}
	var queue: Array[Vector2i] = [start]
	var cursor := 0
	while cursor < queue.size():
		var cell := queue[cursor]
		cursor += 1
		assert(walls.get_cell_source_id(cell) == -1, "Paredes e piso precisam ocupar células diferentes.")
		for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			var neighbor: Vector2i = cell + direction
			if floor.get_cell_source_id(neighbor) == -1:
				assert(walls.get_cell_source_id(neighbor) == 0, "O perímetro do piso precisa ser fechado.")
			elif not visited.has(neighbor):
				visited[neighbor] = true
				queue.append(neighbor)
	assert(visited.size() == floor.get_used_cells().size(), "Todos os setores devem ser conectados.")
	for room in layout.get_node("Pieces").get_children():
		var anchor: Marker2D = room.get_node("MissionSlots/Primary")
		assert(visited.has(floor.local_to_map(floor.to_local(anchor.global_position))),
			"A missão precisa estar sobre piso acessível: %s" % room.name)
	await physics_frame
	var player := world.get_node("Entities/player/Player") as CharacterBody2D
	assert(player.test_move(Transform2D(0, Vector2.ZERO), Vector2(0, -500)),
		"A parede norte deve bloquear a cápsula.")
	var capsule := player.get_node("CollisionShape2D") as CollisionShape2D
	var east_lane_center := Vector2(0, 48) - capsule.position
	assert(not player.test_move(Transform2D(0, east_lane_center), Vector2(1050, 0)),
		"O corredor leste deve comportar a cápsula do jogador.")
	for y in range(31, 41):
		for x in range(53, 60):
			assert(floor.get_cell_source_id(Vector2i(x, y)) == 0, "O corredor central deve manter o mesmo eixo.")
		assert(walls.get_cell_source_id(Vector2i(52, y)) == 0)
		assert(walls.get_cell_source_id(Vector2i(60, y)) == 0)
	assert(not player.test_move(Transform2D(0, Vector2(16, 400)), Vector2(0, 480)),
		"O jogador deve atravessar o corredor central em linha reta.")
	var details := layout.get_node("Details") as TileMapLayer
	assert(not details.collision_enabled)
	var variants := {}
	for cell in details.get_used_cells():
		assert(visited.has(cell), "Os detalhes devem ficar no piso.")
		variants[details.get_cell_atlas_coords(cell)] = true
	assert(variants.size() >= 7, "O mapa precisa usar as novas variações decorativas.")
	world.queue_free()
	await process_frame
	print("Tile station map checks passed.")
	quit()
