extends Area2D

@onready var prompt: Label = $Label

var _nearby_players: Array[Node2D] = []


func _on_body_shape_entered(
	_body_rid: RID,
	body: Node2D,
	_body_shape_index: int,
	_local_shape_index: int,
) -> void:
	if not body.is_in_group("player") or _nearby_players.has(body):
		return
	_nearby_players.append(body)
	_refresh_prompt()


func _on_body_shape_exited(
	_body_rid: RID,
	body: Node2D,
	_body_shape_index: int,
	_local_shape_index: int,
) -> void:
	_nearby_players.erase(body)
	_refresh_prompt()


func _unhandled_input(event: InputEvent) -> void:
	if _nearby_players.is_empty() or not event.is_action_pressed("interact"):
		return
	if event is InputEventKey and event.echo:
		return

	var tablet_ui := get_node_or_null("../../CanvasLayer/TabletUi")
	if tablet_ui == null or not tablet_ui.has_method("open_ui"):
		push_error("TabletUi precisa oferecer o método open_ui().")
		return
	tablet_ui.call("open_ui")
	get_viewport().set_input_as_handled()


func _refresh_prompt() -> void:
	prompt.visible = not _nearby_players.is_empty()
