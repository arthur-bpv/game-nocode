extends SceneTree

const JOINS := [
	["CentralRoom/Connections/West", Vector2.LEFT],
	["CentralRoom/Connections/East", Vector2.RIGHT],
	["CentralRoom/Connections/South", Vector2.DOWN],
	["UpperLeftRoom/Connections/East", Vector2.RIGHT],
	["UpperLeftRoom/Connections/South", Vector2.DOWN],
	["LowerLeftRoom/Connections/North", Vector2.UP],
	["LowerLeftRoom/Connections/East", Vector2.RIGHT],
	["LowerCentralRoom/Connections/North", Vector2.UP],
	["LowerCentralRoom/Connections/West", Vector2.LEFT],
	["LowerCentralRoom/Connections/East", Vector2.RIGHT],
	["SmallLowerRightRoom/Connections/West", Vector2.LEFT],
	["SmallLowerRightRoom/Connections/East", Vector2.RIGHT],
	["UpperRightRoom/Connections/West", Vector2.LEFT],
	["UpperRightRoom/Connections/South", Vector2.DOWN],
	["LowerRightRoom/Connections/West", Vector2.LEFT],
]

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var section := (load("res://scenes/world/maps/central_section_prototype.tscn") as PackedScene).instantiate() as Node2D
	root.add_child(section)
	await physics_frame
	var space: PhysicsDirectSpaceState2D = section.get_world_2d().direct_space_state
	for item in JOINS:
		var marker := section.get_node("Pieces/" + item[0]) as Marker2D
		var direction: Vector2 = item[1]
		var query := PhysicsRayQueryParameters2D.create(
			marker.global_position - direction * 40,
			marker.global_position + direction * 40)
		var hit := space.intersect_ray(query)
		assert(hit.is_empty(), "Entrada bloqueada: %s" % item[0])
	var solid_walls := [
		["CentralRoom", Vector2(0, -155), Vector2(0, -205)],
		["UpperLeftRoom", Vector2(-120, 0), Vector2(-205, 0)],
		["LowerLeftRoom", Vector2(-180, 0), Vector2(-245, 0)],
		["LowerCentralRoom", Vector2(0, 175), Vector2(0, 250)],
		["SmallLowerRightRoom", Vector2(0, 130), Vector2(0, 190)],
		["UpperRightRoom", Vector2(150, 0), Vector2(220, 0)],
		["LowerRightRoom", Vector2(75, 0), Vector2(150, 0)],
	]
	for wall in solid_walls:
		var room := section.get_node("Pieces/" + wall[0]) as Node2D
		var query := PhysicsRayQueryParameters2D.create(room.to_global(wall[1]), room.to_global(wall[2]))
		assert(not space.intersect_ray(query).is_empty(), "Parede ausente: %s" % wall[0])
	var player_scene := (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as Node2D
	section.add_child(player_scene)
	var player_body := player_scene.get_node("Player") as CharacterBody2D
	var player_collision := player_body.get_node("CollisionShape2D") as CollisionShape2D
	await physics_frame
	for item in JOINS:
		var marker := section.get_node("Pieces/" + item[0]) as Marker2D
		var direction: Vector2 = item[1]
		var offset := Vector2.ZERO
		if direction.x != 0:
			offset.y = 5 - player_collision.position.y
		if item[0] == "LowerRightRoom/Connections/West":
			offset.y = 50 - player_collision.position.y
		var start := marker.global_position + offset - direction * 40
		var blocked := player_body.test_move(Transform2D(0, start), direction * 80, null, 0.001)
		assert(not blocked, "Jogador não atravessa a entrada: %s" % item[0])
	var l_corridor := section.get_node("Pieces/UpperRightSouthCorridor") as Node2D
	assert(not player_body.test_move(
		Transform2D(0, l_corridor.to_global(Vector2(87, -150))),
		Vector2(0, 600), null, 0.001), "Jogador não desce pelo corredor em L.")
	assert(not player_body.test_move(
		Transform2D(0, l_corridor.to_global(Vector2(87, 151))),
		Vector2(-374, 0), null, 0.001), "Jogador não vira à esquerda no corredor em L.")
	print("Modular map collision checks passed: open passages and blocking walls.")
	quit()
