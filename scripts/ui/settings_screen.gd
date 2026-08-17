extends Control
class_name SettingsScreen

signal volume_requested
signal back_requested

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		back_requested.emit()
		get_viewport().set_input_as_handled()

func _on_volume_pressed() -> void:
	volume_requested.emit()

func _on_back_pressed() -> void:
	back_requested.emit()
