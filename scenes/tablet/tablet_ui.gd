extends Control

func _ready():
	$PanelLeft/Terminal/InputLine.text_submitted.connect(_on_command_submitted)

func open_ui():
	if visible:
		return
	show()
	_set_player_movement(false)
	$PanelLeft/Terminal/InputLine.grab_focus()

func _close_ui():
	hide()
	_set_player_movement(true)

func _set_player_movement(enabled: bool):
	for node in get_tree().get_nodes_in_group("player"):
		node.set_physics_process(enabled)

func _unhandled_input(event):
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_close_ui()
		get_viewport().set_input_as_handled()

func _on_command_submitted(text: String):
	var cmd = text.strip_edges()
	if cmd.is_empty():
		return
	$PanelLeft/Terminal/Output.append_text("[color=cyan]> " + cmd + "[/color]\n")
	$PanelLeft/Terminal/InputLine.clear()
	$PanelLeft/Terminal/InputLine.grab_focus()
