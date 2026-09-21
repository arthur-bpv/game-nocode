extends SceneTree

var _failed := false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _check_player_movement()
	await _check_physical_tablet()
	if _failed:
		quit(1)
		return
	print("Text controller checks passed: movement and physical tablet interaction.")
	quit(0)


func _check_player_movement() -> void:
	var player_scene := (load("res://scenes/player/player.tscn") as PackedScene).instantiate()
	root.add_child(player_scene)
	var player := player_scene.get_node("Player") as CharacterBody2D

	Input.action_press("move_right")
	player._physics_process(1.0 / 60.0)
	Input.action_release("move_right")
	_check(is_equal_approx(player.velocity.x, 460.0), "Movimento horizontal não preservou SPEED=460.")
	_check(is_zero_approx(player.velocity.y), "Movimento horizontal alterou o eixo vertical.")

	player._physics_process(1.0 / 60.0)
	_check(player.velocity.is_zero_approx(), "Jogador não parou depois que a ação foi liberada.")
	player_scene.free()


func _check_physical_tablet() -> void:
	var world := Node2D.new()
	var entities := Node2D.new()
	entities.name = "Entities"
	world.add_child(entities)

	var tablet := (load("res://scenes/tablet/Tablet.tscn") as PackedScene).instantiate()
	tablet.name = "Tablet"
	tablet.monitoring = false
	entities.add_child(tablet)

	var player := CharacterBody2D.new()
	player.add_to_group("player")
	entities.add_child(player)

	var canvas_layer := CanvasLayer.new()
	canvas_layer.name = "CanvasLayer"
	world.add_child(canvas_layer)
	var tablet_ui := (load("res://scenes/tablet/TabletMenu.tscn") as PackedScene).instantiate()
	tablet_ui.name = "TabletUi"
	canvas_layer.add_child(tablet_ui)
	root.add_child(world)
	await process_frame

	tablet._on_body_shape_entered(RID(), player, 0, 0)
	_check(tablet.get_node("Label").visible, "Dica de interação não apareceu perto do tablet.")
	var interact := InputEventAction.new()
	interact.action = "interact"
	interact.pressed = true
	tablet._unhandled_input(interact)
	_check(tablet_ui.visible, "Interação não abriu a interface do tablet.")
	_check(not player.is_physics_processing(), "Movimento do jogador continuou com o tablet aberto.")

	tablet._on_body_shape_exited(RID(), player, 0, 0)
	_check(not tablet.get_node("Label").visible, "Dica de interação permaneceu após sair da área.")
	tablet_ui.close_ui()
	_check(player.is_physics_processing(), "Movimento do jogador não voltou ao fechar o tablet.")
	world.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
