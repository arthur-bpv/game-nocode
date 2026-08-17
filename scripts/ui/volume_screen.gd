extends Control
class_name VolumeScreen

signal back_requested

@onready var volume_slider: HSlider = $Control/HSlider

func _ready() -> void:
	volume_slider.set_value_no_signal(_get_master_volume_percent())

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		back_requested.emit()
		get_viewport().set_input_as_handled()

func _on_volume_changed(value: float) -> void:
	var master_bus := AudioServer.get_bus_index("Master")
	if master_bus < 0:
		push_error("O bus de áudio Master não foi encontrado.")
		return

	if value <= 0.0:
		AudioServer.set_bus_mute(master_bus, true)
		return

	AudioServer.set_bus_mute(master_bus, false)
	AudioServer.set_bus_volume_db(master_bus, linear_to_db(value / 100.0))

func _on_back_pressed() -> void:
	back_requested.emit()

func _get_master_volume_percent() -> float:
	var master_bus := AudioServer.get_bus_index("Master")
	if master_bus < 0 or AudioServer.is_bus_mute(master_bus):
		return 0.0
	return clampf(db_to_linear(AudioServer.get_bus_volume_db(master_bus)) * 100.0, 0.0, 100.0)
