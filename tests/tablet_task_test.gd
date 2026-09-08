extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var session := root.get_node("StudySession")
	var world = load("res://scenes/world/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var slot = world.get_node("Entities/CamadasSlot")
	var mission: Control = slot._mission
	var tablet = world.get_node("CanvasLayer/TabletUi")
	var player = world.get_node("Entities/player/Player")
	var router = world.get_node("CanvasLayer/UiController")
	assert(not mission.visible)
	var interact := InputEventAction.new()
	interact.action = "interact"
	interact.pressed = true
	slot._unhandled_input(interact)
	assert(not tablet.visible, "Não pode abrir de longe")
	# Posiciona o corpo físico no alcance do terminal, considerando o offset existente.
	player.global_position = slot.global_position + Vector2(340, 230) - player.get_node("CollisionShape2D").position
	player.reset_physics_interpolation()
	for frame in range(5):
		await physics_frame
	assert(not slot._nearby.is_empty(), "Área precisa reconhecer o player")
	slot._task.enabled = false
	slot._unhandled_input(interact)
	assert(not tablet.visible, "Task indisponível não abre no tablet")
	slot._task.enabled = true
	slot._unhandled_input(interact)
	await process_frame
	assert(tablet.visible and mission.is_visible_in_tree())
	assert(not player.is_physics_processing())
	assert(not mission.get_node("CloseButton").visible)
	_drag(mission, "aplicacao", "aplicacao")
	assert(mission._connected.size() == 1)
	var cancel := InputEventAction.new()
	cancel.action = "ui_cancel"
	cancel.pressed = true
	router._unhandled_input(cancel)
	assert(not tablet.visible and player.is_physics_processing())
	assert(not paused)
	slot._unhandled_input(interact)
	assert(mission.is_visible_in_tree() and mission._connected.size() == 1)
	# O X do tablet usa o mesmo caminho de fechamento.
	tablet.get_node("ScreenCenter/Screen/Content/Header/CloseButton").pressed.emit()
	assert(not tablet.visible and player.is_physics_processing())
	slot._unhandled_input(interact)
	for layer in mission.OSI_CAMADAS:
		if not mission._connected.has(layer):
			_drag(mission, layer, mission.MAPA_OSI_TCP[layer])
	assert(session.task_state(&"conecta_camadas") == &"completed")
	var tab := InputEventAction.new()
	tab.action = "toggle_tablet"
	tab.pressed = true
	tablet._input(tab)
	assert(not tablet.visible and player.is_physics_processing())
	tablet.open_ui()
	assert(not mission.visible, "Abrir o tablet normal não reabre atividade")
	tablet.close_ui()
	world.queue_free()
	await process_frame
	print("Tablet task checks passed: range, E, close/reopen, partial state, completion, ESC/X/Tab.")
	quit()

func _drag(mission: Control, source: String, target: String) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = mission._osi_jacks[source].get_center()
	mission._gui_input(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = mission._tcp_jacks[target].get_center()
	mission._gui_input(release)
