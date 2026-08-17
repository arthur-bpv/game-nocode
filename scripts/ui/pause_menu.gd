extends Control

@onready var settings_screen: SettingsScreen = $Settings
@onready var volume_screen: VolumeScreen = $Volume
@onready var continue_button: Button = $Button
@onready var settings_button: Button = $Button2

func _ready() -> void:
	settings_screen.volume_requested.connect(_show_volume)
	settings_screen.back_requested.connect(_show_pause_actions)
	volume_screen.back_requested.connect(_show_settings)
	settings_screen.hide()
	volume_screen.hide()
	hide()

func _on_play_button_pressed() -> void:
	close_pause()

func _on_button_2_pressed() -> void:
	_show_settings()

func close_pause() -> void:
	settings_screen.hide()
	volume_screen.hide()
	hide()
	get_tree().paused = false

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"):
		return

	if volume_screen.visible:
		_show_settings()
	elif settings_screen.visible:
		_show_pause_actions()
	else:
		close_pause()
	get_viewport().set_input_as_handled()

func _show_pause_actions() -> void:
	settings_screen.hide()
	volume_screen.hide()
	continue_button.show()
	settings_button.show()

func _show_settings() -> void:
	continue_button.hide()
	settings_button.hide()
	volume_screen.hide()
	settings_screen.show()

func _show_volume() -> void:
	settings_screen.hide()
	volume_screen.show()
