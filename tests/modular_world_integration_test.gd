extends SceneTree

const TASK_ROOMS := {
	&"sinais_osi": "LowerLeftRoom",
	&"conecta_camadas": "UpperRightRoom",
	&"rack_osi": "LowerCentralRoom",
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
	var camera := player.get_node("Camera2D") as Camera2D
	assert(camera.limit_left == -1800 and camera.limit_right == 2400)
	assert(camera.limit_top == -500 and camera.limit_bottom == 1800)
	var map_rect := world.get_node("CanvasLayer/TabletUi/ScreenCenter/Screen/Content/Body/Section/SectionContent/TextureRect") as TextureRect
	assert(map_rect.texture.resource_path == "res://assets/sprites/map/modular_map_overview.png")
	assert(map_rect.texture.get_size() == Vector2(4200, 2300))
	world.queue_free()
	await process_frame
	print("Modular world integration checks passed: seven room anchors, three tasks, spawn, camera and tablet map.")
	quit()
