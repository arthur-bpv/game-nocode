extends SceneTree

const TERMINALS := {
	&"conecta_camadas": "tcpip_patch_panel.png",
	&"encapsulamento_esteira": "task_terminal.png",
	&"escolher_transporte": "tcpip_transport_selector.png",
	&"reparar_encapsulamento": "tcpip_encapsulation_module.png",
}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var session := root.get_node("StudySession")
	var world: Node = load("res://scenes/world/world.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	var player := world.get_node("Entities/player/Player") as CharacterBody2D
	var tablet := world.get_node("CanvasLayer/TabletUi")
	var prerequisites: Array[String] = []
	var topic := session.current_topic() as StudyTopic
	for task in session.current_topic().tasks:
		var slot := world.get_node("Entities/" + String(task.map_slot))
		var beacon := slot.get_node_or_null("TaskBeacon") as Label
		assert(beacon != null, "Indicador ausente em %s." % task.id)
		var state: StringName = session.task_state(task.id)
		assert(beacon.text == ("!" if state == &"available" else "–"))
		if task.id in TERMINALS:
			var sprite := slot.get_node("TaskTerminalSprite") as Sprite2D
			assert(sprite.texture.resource_path.get_file() == TERMINALS[task.id])
			var body := slot.get_node("TerminalBody") as StaticBody2D
			var interaction := slot.get_node("TerminalInteraction") as Area2D
			assert(body.collision_layer != 0 and interaction.collision_mask != 0)
			var shape := body.get_node("CollisionShape2D") as CollisionShape2D
			assert(shape.shape is RectangleShape2D and not shape.disabled)
			var area := interaction.get_node("CollisionShape2D") as CollisionShape2D
			assert(area.shape.get_rect().has_point(interaction.to_local(sprite.global_position)))
		if task.presentation == StudyTask.Presentation.TABLET:
			assert(session.restore_progress({"version": 1, "completed": {"redes": {String(topic.id): prerequisites}}}))
			assert(beacon.text == "!")
			var stance: Vector2
			if task.id == &"inspecao_pacotes":
				var scanner := slot.get_node("InspectionInteraction") as Area2D
				stance = scanner.global_position + Vector2(0, 44)
			else:
				var interaction := slot.get_node("TerminalInteraction") as Area2D
				stance = interaction.global_position + Vector2(0, 68)
			player.global_position = stance
			player.reset_physics_interpolation()
			for frame in 4:
				await physics_frame
			var player_shape := player.get_node("CollisionShape2D") as CollisionShape2D
			var query := PhysicsShapeQueryParameters2D.new()
			query.shape = player_shape.shape
			query.transform = player_shape.global_transform
			query.exclude = [player.get_rid()]
			assert(player.get_world_2d().direct_space_state.intersect_shape(query).is_empty(),
				"O piso em frente a %s precisa ficar livre." % task.id)
			var interact := InputEventAction.new()
			interact.action = &"interact"
			interact.pressed = true
			root.push_input(interact)
			assert(tablet.visible and slot._mission.is_visible_in_tree(),
				"Não foi possível abrir %s pela frente do equipamento." % task.id)
			tablet.close_ui()
		prerequisites.append(String(task.id))
	world.queue_free()
	await process_frame
	print("TCP/IP terminal identity checks passed.")
	quit()
