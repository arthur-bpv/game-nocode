extends CanvasLayer

signal transition_started(scene_path: String)
signal transition_finished(scene_path: String)
signal transition_failed(scene_path: String, error: Error)

const MINIMUM_VISIBLE_SECONDS := 0.3

var _overlay: Control
var _status_label: Label
var _spinner: TextureRect
var _loading := false
var _elapsed := 0.0

func _ready() -> void:
	layer = 1000
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_overlay()

func _process(delta: float) -> void:
	if not _loading:
		return
	_elapsed += delta
	_spinner.rotation = TAU * float(int(_elapsed * 16.0) % 16) / 16.0

func change_scene(scene_path: String) -> void:
	if _loading:
		return
	if not ResourceLoader.exists(scene_path, "PackedScene"):
		transition_failed.emit(scene_path, ERR_FILE_NOT_FOUND)
		push_error("Cena não encontrada: %s" % scene_path)
		return

	_loading = true
	_elapsed = 0.0
	_status_label.text = "CARREGANDO"
	_spinner.rotation = 0.0
	_spinner.show()
	_overlay.modulate.a = 1.0
	_overlay.show()
	transition_started.emit(scene_path)
	await get_tree().process_frame

	var request_error := ResourceLoader.load_threaded_request(scene_path, "PackedScene")
	if request_error != OK:
		_finish_with_error(scene_path, request_error)
		return

	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(scene_path, progress)
	while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
		status = ResourceLoader.load_threaded_get_status(scene_path, progress)

	if status != ResourceLoader.THREAD_LOAD_LOADED:
		_finish_with_error(scene_path, ERR_CANT_OPEN)
		return

	while _elapsed < MINIMUM_VISIBLE_SECONDS:
		await get_tree().process_frame

	var packed_scene := ResourceLoader.load_threaded_get(scene_path) as PackedScene
	if packed_scene == null:
		_finish_with_error(scene_path, ERR_CANT_OPEN)
		return
	get_tree().paused = false
	var change_error := get_tree().change_scene_to_packed(packed_scene)
	if change_error != OK:
		_finish_with_error(scene_path, change_error)
		return
	await get_tree().process_frame
	_overlay.hide()
	_loading = false
	transition_finished.emit(scene_path)

func _finish_with_error(scene_path: String, error: Error) -> void:
	_loading = false
	_status_label.text = "ERRO AO CARREGAR"
	_spinner.hide()
	transition_failed.emit(scene_path, error)
	push_error("Falha ao carregar %s: %s" % [scene_path, error])

func _build_overlay() -> void:
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.theme = load("res://assets/ui/netbot_theme.tres") as Theme
	add_child(_overlay)

	var background := ColorRect.new()
	background.color = Color(0.005, 0.015, 0.025, 1.0)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(360, 0)
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	center.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 24)
	panel.add_child(content)

	var logo := Label.new()
	logo.text = "NETBOT"
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.add_theme_font_size_override("font_size", 42)
	logo.add_theme_color_override("font_color", Color(0.2, 0.95, 1.0))
	content.add_child(logo)

	_status_label = Label.new()
	_status_label.text = "CARREGANDO"
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_status_label)

	_spinner = TextureRect.new()
	_spinner.texture = preload("res://assets/ui/pixellab/carregando-pixellab.png")
	_spinner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_spinner.custom_minimum_size = Vector2(96, 96)
	_spinner.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_spinner.pivot_offset = Vector2(48, 48)
	_spinner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_spinner)
	content.move_child(_spinner, 1)
	_overlay.hide()
