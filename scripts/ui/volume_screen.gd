extends Control
class_name VolumeScreen

signal back_requested

const BUS_CONTROLS := {
	&"Master": ["MasterSlider", "MasterMute"],
	&"Music": ["MusicSlider", "MusicMute"],
	&"SFX": ["SFXSlider", "SFXMute"],
}
const DISPLAY_CONFIG_PATH := "user://display_settings.cfg"
const DEFAULT_WINDOW_SIZE := Vector2i(960, 540)
const BASE_VIEWPORT_SIZE := Vector2i(1920, 1080)
const WINDOW_SIZES: Array[Vector2i] = [
	Vector2i(960, 540),
	Vector2i(1280, 720),
	Vector2i(1600, 900),
]
enum DisplayMode { BORDERLESS_FULLSCREEN, WINDOWED }

@onready var preview_player: AudioStreamPlayer = %PreviewPlayer

var mode_options: OptionButton
var window_size_row: HBoxContainer
var window_size_options: OptionButton

func _ready() -> void:
	# Mantém o layout de 1920×1080 inteiro e o escala proporcionalmente em qualquer janela.
	get_window().content_scale_size = BASE_VIEWPORT_SIZE
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	_build_settings_sections()
	_load_display_settings()
	for bus_name in BUS_CONTROLS:
		var controls: Array = BUS_CONTROLS[bus_name]
		var slider := get_node("%%%s" % controls[0]) as HSlider
		var mute := get_node("%%%s" % controls[1]) as CheckButton
		slider.set_value_no_signal(AudioSettings.get_volume(bus_name) * 100.0)
		mute.set_pressed_no_signal(AudioSettings.is_muted(bus_name))
		slider.value_changed.connect(_on_volume_changed.bind(bus_name))
		mute.toggled.connect(_on_mute_toggled.bind(bus_name))

func _build_settings_sections() -> void:
	var content := $Center/Panel/Content as VBoxContainer
	(content.get_node("Title") as Label).text = "CONFIGURAÇÕES"

	var audio_title := Label.new()
	audio_title.text = "ÁUDIO"
	audio_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	audio_title.add_theme_font_size_override("font_size", 18)
	content.add_child(audio_title)
	content.move_child(audio_title, content.get_node("MasterLabel").get_index())

	var insert_at := content.get_node("Buttons").get_index()
	var video_title := Label.new()
	video_title.text = "VÍDEO"
	video_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	video_title.add_theme_font_size_override("font_size", 18)
	content.add_child(video_title)
	content.move_child(video_title, insert_at)
	insert_at += 1

	var mode_row := HBoxContainer.new()
	var mode_label := Label.new()
	mode_label.text = "MODO DE TELA"
	mode_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_options = OptionButton.new()
	mode_options.custom_minimum_size = Vector2(205, 0)
	mode_options.add_item("TELA CHEIA SEM BORDAS")
	mode_options.add_item("MODO JANELA (COM BORDAS)")
	mode_options.item_selected.connect(_on_display_mode_selected)
	mode_row.add_child(mode_label)
	mode_row.add_child(mode_options)
	content.add_child(mode_row)
	content.move_child(mode_row, insert_at)
	insert_at += 1

	window_size_row = _make_size_row("TAMANHO DA JANELA", WINDOW_SIZES)
	window_size_options = window_size_row.get_node("Options") as OptionButton
	window_size_options.item_selected.connect(_on_window_size_selected)
	content.add_child(window_size_row)
	content.move_child(window_size_row, insert_at)

func _make_size_row(label_text: String, sizes: Array[Vector2i]) -> HBoxContainer:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var options := OptionButton.new()
	options.name = "Options"
	options.custom_minimum_size = Vector2(165, 0)
	for item_size in sizes:
		options.add_item("%d x %d" % [item_size.x, item_size.y])
	row.add_child(label)
	row.add_child(options)
	return row

func _load_display_settings() -> void:
	var config := ConfigFile.new()
	if config.load(DISPLAY_CONFIG_PATH) != OK:
		_apply_window_size(DEFAULT_WINDOW_SIZE)
		_refresh_display_controls()
		return
	var saved_mode: int = int(config.get_value("display", "mode", DisplayMode.WINDOWED))
	var settings_version: int = int(config.get_value("display", "settings_version", 0))
	var window_size: Vector2i = config.get_value("display", "window_size", DEFAULT_WINDOW_SIZE)
	# Nas versões antigas: 0 era cheia, 1 sem bordas e 2 janela.
	if settings_version == 0 and saved_mode <= 1:
		_apply_display_mode(DisplayMode.BORDERLESS_FULLSCREEN)
	elif saved_mode == DisplayMode.BORDERLESS_FULLSCREEN:
		_apply_display_mode(DisplayMode.BORDERLESS_FULLSCREEN)
	else:
		_apply_window_size(window_size)
	_refresh_display_controls()

func _save_display_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("display", "settings_version", 1)
	config.set_value("display", "mode", mode_options.selected)
	config.set_value("display", "window_size", _selected_size(window_size_options, WINDOW_SIZES))
	config.save(DISPLAY_CONFIG_PATH)

func _selected_size(options: OptionButton, sizes: Array[Vector2i]) -> Vector2i:
	var index := clampi(options.selected, 0, sizes.size() - 1)
	return sizes[index]

func _on_display_mode_selected(index: int) -> void:
	if index == DisplayMode.BORDERLESS_FULLSCREEN:
		_apply_display_mode(DisplayMode.BORDERLESS_FULLSCREEN)
	else:
		_apply_window_size(_selected_size(window_size_options, WINDOW_SIZES))
	_refresh_display_controls()
	_save_display_settings()

func _on_window_size_selected(index: int) -> void:
	_apply_window_size(WINDOW_SIZES[index])
	_save_display_settings()

func _apply_display_mode(mode: int) -> void:
	# WINDOW_MODE_FULLSCREEN já é sem bordas. Não use WINDOW_FLAG_BORDERLESS:
	# no depurador incorporado do Windows ela pode tentar acessar uma tela ausente.
	if mode == DisplayMode.BORDERLESS_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		get_window().borderless = false

func _apply_window_size(window_size: Vector2i) -> void:
	# A flag precisa ser removida mesmo se a janela veio do modo sem bordas.
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
	DisplayServer.window_set_size(window_size)

func _refresh_display_controls() -> void:
	var mode: int = DisplayMode.WINDOWED
	if get_window().mode == Window.MODE_FULLSCREEN or get_window().mode == Window.MODE_EXCLUSIVE_FULLSCREEN:
		mode = DisplayMode.BORDERLESS_FULLSCREEN
	mode_options.select(mode)
	window_size_row.visible = mode == DisplayMode.WINDOWED
	if mode == DisplayMode.WINDOWED:
		_select_window_size(get_window().size)

func _select_window_size(target: Vector2i) -> void:
	for index in WINDOW_SIZES.size():
		if WINDOW_SIZES[index] == target:
			window_size_options.select(index)
			return
	window_size_options.select(0)

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
	_refresh_display_controls()
	for bus_name in BUS_CONTROLS:
		var controls: Array = BUS_CONTROLS[bus_name]
		var slider := get_node("%%%s" % controls[0]) as HSlider
		var mute := get_node("%%%s" % controls[1]) as CheckButton
		slider.set_value_no_signal(AudioSettings.get_volume(bus_name) * 100.0)
		mute.set_pressed_no_signal(AudioSettings.is_muted(bus_name))
