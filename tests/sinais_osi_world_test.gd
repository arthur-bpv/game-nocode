extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var session := root.get_node("StudySession")
	var world := (load("res://scenes/world/world.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	var slot := world.get_node("Entities/sala_inferior_esquerda_principal") as Node2D
	var mission: Control = slot._mission
	assert(mission.visible and not mission.solved)
	var player := world.get_node("Entities/player/Player") as CharacterBody2D
	var button := mission.buttons["Aplicacao"]["normal"] as TextureRect
	player.global_position = slot.global_position + button.position + button.size * 0.5
	mission._process(0.0)
	assert(mission.nearby_layer == "Aplicacao")
	mission.prompt_order = [{"text": "HTTP e navegadores", "answer": "Aplicacao"}]
	mission.prompt_index = 0
	mission._show_prompt()
	var interact := InputEventAction.new()
	interact.action = "interact"
	interact.pressed = true
	mission._unhandled_input(interact)
	await create_timer(0.65).timeout
	assert(session.task_state(&"sinais_osi") == &"completed")
	assert(mission.solved and mission.monitor_screen.visible)
	var saved: Dictionary = session.progress.snapshot()
	world.queue_free()
	await process_frame
	assert(session.restore_progress(saved))
	world = (load("res://scenes/world/world.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	mission = world.get_node("Entities/sala_inferior_esquerda_principal")._mission
	assert(mission.solved and mission.monitor_screen.visible)
	world.queue_free()
	await process_frame
	print("Sinais OSI world checks passed: physical button, completion and restore.")
	quit()
