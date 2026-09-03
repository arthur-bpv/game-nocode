extends Control
class_name VolumeScreen

signal back_requested

const BUS_CONTROLS := {
	&"Master": ["MasterSlider", "MasterMute"],
	&"Music": ["MusicSlider", "MusicMute"],
	&"SFX": ["SFXSlider", "SFXMute"],
}

@onready var preview_player: AudioStreamPlayer = %PreviewPlayer

func _ready() -> void:
	for bus_name in BUS_CONTROLS:
		var controls: Array = BUS_CONTROLS[bus_name]
		var slider := get_node("%%%s" % controls[0]) as HSlider
		var mute := get_node("%%%s" % controls[1]) as CheckButton
		slider.set_value_no_signal(AudioSettings.get_volume(bus_name) * 100.0)
		mute.set_pressed_no_signal(AudioSettings.is_muted(bus_name))
		slider.value_changed.connect(_on_volume_changed.bind(bus_name))
		mute.toggled.connect(_on_mute_toggled.bind(bus_name))

func open_screen() -> void:
	_refresh_controls()
	show()
	(get_node("%MasterSlider") as HSlider).grab_focus()

func _on_volume_changed(value: float, bus_name: StringName) -> void:
	AudioSettings.set_volume(bus_name, value / 100.0)
	if bus_name == &"SFX" and not AudioSettings.is_muted(&"SFX"):
		preview_player.play()

func _on_mute_toggled(muted: bool, bus_name: StringName) -> void:
	AudioSettings.set_muted(bus_name, muted)

func _on_reset_pressed() -> void:
	AudioSettings.reset_defaults()
	_refresh_controls()
	preview_player.play()

func _on_back_pressed() -> void:
	back_requested.emit()

func _refresh_controls() -> void:
	for bus_name in BUS_CONTROLS:
		var controls: Array = BUS_CONTROLS[bus_name]
		var slider := get_node("%%%s" % controls[0]) as HSlider
		var mute := get_node("%%%s" % controls[1]) as CheckButton
		slider.set_value_no_signal(AudioSettings.get_volume(bus_name) * 100.0)
		mute.set_pressed_no_signal(AudioSettings.is_muted(bus_name))
