extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var map_sprite := Sprite2D.new()
	map_sprite.texture = load("res://assets/sprites/Mapa.png") as Texture2D
	assert(map_sprite.texture != null, "Não foi possível carregar a arte do mapa.")

	var walls := StaticBody2D.new()
	walls.set_script(load("res://scenes/world/world_walls.gd"))
	map_sprite.add_child(walls)
	root.add_child(map_sprite)
	await process_frame

	assert(
		walls.get_child_count() == 3,
		"Esperados: limite externo e dois obstáculos internos."
	)

	print("World map runtime checks passed: %d collision polygons." % walls.get_child_count())
	quit()
