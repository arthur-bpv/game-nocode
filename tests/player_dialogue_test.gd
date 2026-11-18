extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var session := root.get_node("StudySession")
	var world := (load("res://scenes/world/world.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	var dialogue := world.get_node("CanvasLayer/PlayerDialogue") as Control
	assert(not dialogue.visible)
	var panel := dialogue.get_node("Panel") as Control
	assert(panel.position.x >= 0.0 and panel.position.y > dialogue.size.y * 0.5)
	var player := world.get_node("Entities/player/Player") as CharacterBody2D
	var rack_slot := world.get_node("Entities/sala_inferior_central_principal") as Node2D
	assert(not (rack_slot._mission.get_node("StatusLabel") as Label).visible)
	player.global_position = Vector2(0, 1160)
	await physics_frame
	await physics_frame
	await create_timer(0.2).timeout
	assert(dialogue.visible)
	assert("baias" in dialogue.message_label.text)
	assert(not dialogue.get_node("Panel/Row/Portrait").visible)
	rack_slot._mission.mentor_message.emit("Teste de dica futura.", 3.0)
	assert(dialogue.message_label.text == "Teste de dica futura.")
	assert(session.restore_progress({"version": 1, "completed": {"redes": {"tcp_ip_modelo_osi": ["rack_osi"]}}}))
	var signal_slot := world.get_node("Entities/sala_inferior_esquerda_principal") as Node2D
	assert(not signal_slot._mission.feedback.visible)
	player.global_position = Vector2(-1320, 1000)
	await physics_frame
	await physics_frame
	await create_timer(0.2).timeout
	assert("botão" in dialogue.message_label.text)
	var button := signal_slot._mission.buttons["Aplicacao"]["normal"] as TextureRect
	player.global_position = signal_slot.global_position + button.position + button.size / 2.0
	signal_slot._mission._process(0.0)
	assert("[E]" in dialogue.message_label.text)
	signal_slot._mission.mentor_message.emit("Correto!", 0.1)
	assert(dialogue.message_label.text == "Correto!")
	await create_timer(0.2).timeout
	assert("[E]" in dialogue.message_label.text)
	dialogue.clear()
	assert("monitor" in dialogue.message_label.text)
	player.global_position = Vector2.ZERO
	await physics_frame
	await process_frame
	assert(not dialogue.visible)
	world.queue_free()
	await process_frame
	print("Room guide checks passed: instruction, temporary feedback and exit.")
	quit()
