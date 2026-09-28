extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene := load("res://scenes/world/maps/central_section_prototype.tscn") as PackedScene
	assert(scene != null, "A seção modular não carregou.")
	var section := scene.instantiate()
	root.add_child(section)
	await process_frame

	var room := section.get_node("Pieces/CentralRoom") as MapRoom
	var upper_left := section.get_node("Pieces/UpperLeftRoom") as MapRoom
	var lower_left := section.get_node("Pieces/LowerLeftRoom") as MapRoom
	var lower_central := section.get_node("Pieces/LowerCentralRoom") as MapRoom
	var small_lower_right := section.get_node("Pieces/SmallLowerRightRoom") as MapRoom
	var upper_right := section.get_node("Pieces/UpperRightRoom") as MapRoom
	var lower_right := section.get_node("Pieces/LowerRightRoom") as MapRoom
	var west := section.get_node("Pieces/WestCorridor") as Node2D
	var east := section.get_node("Pieces/EastCorridor") as Node2D
	var south := section.get_node("Pieces/SouthCorridor") as Node2D
	var diagonal := section.get_node("Pieces/UpperLeftSouthCorridor") as Node2D
	var lower_east := section.get_node("Pieces/LowerLeftEastCorridor") as Node2D
	var lower_central_east := section.get_node("Pieces/LowerCentralEastCorridor") as Node2D
	var l_shaped := section.get_node("Pieces/UpperRightSouthCorridor") as Node2D
	var mini := section.get_node("Pieces/LowerRightMiniCorridor") as Node2D
	assert(room.area_id == &"sala_central")
	assert(upper_left.area_id == &"sala_superior_esquerda")
	assert(lower_left.area_id == &"sala_inferior_esquerda")
	assert(lower_central.area_id == &"sala_inferior_central")
	assert(small_lower_right.area_id == &"sala_inferior_centro_direita")
	assert(upper_right.area_id == &"sala_superior_direita")
	assert(lower_right.area_id == &"sala_inferior_direita")
	assert((room.get_node("MissionSlots/Primary") as MapMissionAnchor).slot_id == &"principal")
	assert((upper_left.get_node("MissionSlots/Primary") as MapMissionAnchor).slot_id == &"principal")
	assert((lower_left.get_node("MissionSlots/Primary") as MapMissionAnchor).slot_id == &"principal")
	assert((lower_central.get_node("MissionSlots/Primary") as MapMissionAnchor).slot_id == &"principal")
	assert((small_lower_right.get_node("MissionSlots/Primary") as MapMissionAnchor).slot_id == &"principal")
	assert((upper_right.get_node("MissionSlots/Primary") as MapMissionAnchor).slot_id == &"principal")
	assert((lower_right.get_node("MissionSlots/Primary") as MapMissionAnchor).slot_id == &"principal")
	for piece in [room, upper_left, lower_left, lower_central, small_lower_right,
		upper_right, lower_right, west, east, south, diagonal, lower_east,
		lower_central_east, l_shaped, mini]:
		var walls := piece.get_node("Walls") as StaticBody2D
		assert(walls != null and walls.get_child_count() > 0,
			"Peça sem colisão editável: %s" % piece.name)
		for edge in walls.get_children():
			assert(edge is CollisionShape2D and edge.shape is SegmentShape2D,
				"Parede deve ser um segmento editável: %s" % edge.get_path())

	_check_join(room.get_node("Connections/West"), west.get_node("Connections/East"))
	_check_join(upper_left.get_node("Connections/East"), west.get_node("Connections/West"))
	_check_join(room.get_node("Connections/East"), east.get_node("Connections/West"))
	_check_join(room.get_node("Connections/South"), south.get_node("Connections/North"))
	_check_join(upper_left.get_node("Connections/South"), diagonal.get_node("Connections/North"))
	_check_join(lower_left.get_node("Connections/North"), diagonal.get_node("Connections/South"))
	_check_join(lower_left.get_node("Connections/East"), lower_east.get_node("Connections/West"))
	_check_join(lower_central.get_node("Connections/North"), south.get_node("Connections/South"))
	_check_join(lower_central.get_node("Connections/West"), lower_east.get_node("Connections/East"))
	_check_join(lower_central.get_node("Connections/East"), lower_central_east.get_node("Connections/West"))
	_check_join(small_lower_right.get_node("Connections/West"), lower_central_east.get_node("Connections/East"))
	_check_join(upper_right.get_node("Connections/West"), east.get_node("Connections/East"))
	_check_join(upper_right.get_node("Connections/South"), l_shaped.get_node("Connections/North"))
	_check_join(small_lower_right.get_node("Connections/East"), l_shaped.get_node("Connections/West"))
	_check_join(l_shaped.get_node("Connections/East"), mini.get_node("Connections/West"))
	_check_join(lower_right.get_node("Connections/West"), mini.get_node("Connections/East"))
	# A sobreposição de cinco pixels cobre a borda preta original da sala.
	assert(east.position.x - 163.5 * east.scale.x < 215.5)
	assert(west.scale.x < 1.0)
	assert(west.position.x + 163.5 * west.scale.x > -215.5)
	assert(west.position.x - 163.5 * west.scale.x < upper_left.position.x + 188.5)
	assert(is_equal_approx(south.position.y - 86.0, 240.0))
	assert(lower_east.position.x - 163.5 * lower_east.scale.x < lower_left.position.x + 229)
	# O corredor vertical cobre os 55 px da parede superior da sala inferior.
	assert(south.position.y + 86.0 - (lower_central.position.y - 228.5) > 55.0)
	var medium_visual := lower_central_east.get_node("Visual") as Sprite2D
	assert(medium_visual.region_enabled)
	assert(medium_visual.region_rect.size == Vector2(186, 152))
	assert((l_shaped.get_node("Visual") as Sprite2D).z_index == 1)
	assert((mini.get_node("Visual") as Sprite2D).z_index == 1)
	assert(mini.scale == Vector2.ONE, "O minicorredor deve manter a proporção do PNG.")
	print("Modular map checks passed: sixteen aligned connections and editable wall segments.")
	quit()

func _check_join(first: Marker2D, second: Marker2D) -> void:
	assert(first.global_position.distance_to(second.global_position) < 0.01,
		"Conexões desalinhadas: %s e %s" % [first.get_path(), second.get_path()])
