extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var audio_settings := root.get_node("AudioSettings")
	for bus_name in [&"Master", &"Music", &"SFX"]:
		assert(AudioServer.get_bus_index(bus_name) >= 0, "Bus de áudio ausente: %s" % bus_name)
	var original_sfx_volume: float = audio_settings.get_volume(&"SFX")
	audio_settings.set_volume(&"SFX", 0.42)
	var saved_config := ConfigFile.new()
	assert(saved_config.load("user://settings.cfg") == OK, "Configurações de áudio não foram persistidas.")
	assert(is_equal_approx(float(saved_config.get_value("audio", "sfx_volume")), 0.42), "Volume SFX salvo incorretamente.")
	audio_settings.set_volume(&"SFX", original_sfx_volume)

	var menu_scene := load("res://scenes/menu.tscn") as PackedScene
	assert(menu_scene != null, "Menu principal não carregou.")
	var menu := menu_scene.instantiate()
	root.add_child(menu)
	await process_frame
	assert(menu.get_node("%SingleplayerButton") != null, "Singleplayer ausente.")
	var multiplayer := menu.get_node("Center/Panel/Content/ModeButtons/MultiplayerColumn/MultiplayerButton") as Button
	assert(multiplayer.disabled, "Multiplayer deve estar desabilitado.")
	menu.queue_free()
	await process_frame
	var settings_scene := load("res://scenes/configurações.tscn") as PackedScene
	assert(settings_scene != null, "Configurações standalone não carregaram.")
	var settings := settings_scene.instantiate()
	root.add_child(settings)
	await process_frame
	assert(settings.get_node("Volume").visible, "Configurações de áudio standalone não abriram.")
	settings.queue_free()
	await process_frame

	var world_scene := load("res://scenes/world/world.tscn") as PackedScene
	assert(world_scene != null, "Mundo não carregou.")
	var world := world_scene.instantiate()
	root.add_child(world)
	await process_frame

	var walls := world.get_node("MapSprite/WorldWalls")
	assert(walls.get_child_count() == 3, "O mundo deve carregar três polígonos persistidos.")
	var tablet := world.get_node("CanvasLayer/TabletUi")
	var pause_menu := world.get_node("CanvasLayer/Pause")
	var ui_controller := world.get_node("CanvasLayer/UiController")

	tablet.open_ui()
	assert(tablet.visible, "Tablet não abriu.")
	_send_cancel_to(ui_controller)
	assert(not tablet.visible, "ESC deve fechar o tablet antes de pausar.")
	assert(not pause_menu.visible, "Fechar o tablet não deve abrir o pause.")

	_send_cancel_to(ui_controller)
	assert(pause_menu.visible and paused, "ESC deve abrir e pausar o jogo.")
	pause_menu._on_settings_pressed()
	assert(pause_menu.get_node("%VolumeScreen").visible, "Configurações de áudio não abriram.")
	_send_cancel_to(ui_controller)
	assert(not pause_menu.get_node("%VolumeScreen").visible, "ESC deve voltar do áudio às ações.")
	_send_cancel_to(ui_controller)
	assert(not pause_menu.visible and not paused, "ESC deve continuar o jogo a partir do pause.")

	print("UI runtime checks passed.")
	quit(0)

func _send_cancel_to(ui_controller: Node) -> void:
	var event := InputEventAction.new()
	event.action = "ui_cancel"
	event.pressed = true
	ui_controller._unhandled_input(event)
