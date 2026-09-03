extends SceneTree

func _initialize() -> void:
	_render.call_deferred()

func _render() -> void:
	root.content_scale_size = Vector2i(1920, 1080)
	var menu := (load("res://scenes/menu.tscn") as PackedScene).instantiate()
	root.add_child(menu)
	for resolution in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(3840, 2160)]:
		root.size = resolution
		await process_frame
		await process_frame
		var image := root.get_texture().get_image()
		var path := "res://.godot/ui_menu_%sx%s.png" % [resolution.x, resolution.y]
		assert(image.save_png(path) == OK, "Falha ao salvar captura %s" % path)
	menu.queue_free()
	await process_frame

	root.size = Vector2i(1920, 1080)
	var pause_menu := (load("res://scenes/Pause.tscn") as PackedScene).instantiate()
	root.add_child(pause_menu)
	pause_menu.open_pause()
	await process_frame
	await process_frame
	assert(root.get_texture().get_image().save_png("res://.godot/ui_pause_1920x1080.png") == OK)
	pause_menu._on_settings_pressed()
	await process_frame
	assert(root.get_texture().get_image().save_png("res://.godot/ui_audio_1920x1080.png") == OK)
	pause_menu.handle_cancel()
	pause_menu._on_return_to_menu_pressed()
	await process_frame
	assert(root.get_texture().get_image().save_png("res://.godot/ui_confirmation_1920x1080.png") == OK)
	pause_menu.handle_cancel()
	pause_menu.resume_game()
	pause_menu.queue_free()
	await process_frame

	var tablet := (load("res://scenes/tablet/TabletMenu.tscn") as PackedScene).instantiate()
	root.add_child(tablet)
	tablet.open_ui()
	await process_frame
	await process_frame
	assert(root.get_texture().get_image().save_png("res://.godot/ui_tablet_1920x1080.png") == OK)
	tablet.close_ui()
	tablet.queue_free()
	await process_frame

	var transition := root.get_node("SceneTransition")
	transition.change_scene("res://scenes/world/world.tscn")
	await process_frame
	assert(root.get_texture().get_image().save_png("res://.godot/ui_loading_1920x1080.png") == OK)
	await transition.transition_finished
	print("UI render checks passed.")
	quit(0)
