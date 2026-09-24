extends Node

@onready var tablet: Control = get_node("../TabletUi")
@onready var pause_menu: Control = get_node("../Pause")

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if tablet.visible:
		tablet.close_ui()
	elif pause_menu.visible:
		pause_menu.handle_cancel()
	else:
		pause_menu.open_pause()
	get_viewport().set_input_as_handled()
