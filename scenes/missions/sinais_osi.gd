extends Control

signal completed

const BUTTON_ATLAS_PATH := "res://assets/sprites/Handshake.png"
const COMPUTER_ON_REGION := Rect2(114, 130, 168, 147)
const COMPUTER_OFF_REGION := Rect2(117, 133, 162, 141)
const BUTTON_NORMAL_REGIONS := {
	"Rede": Rect2(1070, 109, 151, 92), "Fisica": Rect2(1296, 109, 151, 92),
	"Aplicacao": Rect2(1529, 109, 151, 92), "Enlace": Rect2(1759, 109, 151, 92),
	"Apresentacao": Rect2(1987, 109, 151, 92), "Sessao": Rect2(2215, 109, 151, 92),
	"Transporte": Rect2(2450, 109, 151, 92),
}
const BUTTON_PRESSED_REGIONS := {
	"Rede": Rect2(1070, 250, 151, 96), "Fisica": Rect2(1296, 250, 151, 96),
	"Aplicacao": Rect2(1529, 250, 151, 96), "Enlace": Rect2(1759, 250, 151, 96),
	"Apresentacao": Rect2(1987, 250, 151, 96), "Sessao": Rect2(2215, 250, 151, 96),
	"Transporte": Rect2(2450, 250, 151, 96),
}

const BUTTON_ERROR_REGIONS := {
	"Rede": Rect2(1070, 395, 151, 96), "Fisica": Rect2(1296, 395, 151, 96),
	"Aplicacao": Rect2(1529, 395, 151, 96), "Enlace": Rect2(1759, 395, 151, 96),
	"Apresentacao": Rect2(1987, 395, 151, 96), "Sessao": Rect2(2215, 395, 151, 96),
	"Transporte": Rect2(2450, 395, 151, 96),
}

const PROMPTS := [
	{"text": "HTTP e navegadores", "answer": "Aplicacao"},
	{"text": "Criptografia e formatos", "answer": "Apresentacao"},
	{"text": "Portas e comunicacao fim a fim", "answer": "Transporte"},
	{"text": "Enderecamento IP", "answer": "Rede"},
	{"text": "Quadros e enderecos MAC", "answer": "Enlace"},
	{"text": "Sinais, cabos e conectores", "answer": "Fisica"},
	{"text": "Controle de dialogo", "answer": "Sessao"},
]

var buttons: Dictionary = {}
var prompt_label: Label
var feedback: Label
var monitor: TextureRect
var monitor_screen: ColorRect
var prompt_index := 0
var prompt_order: Array = []
var input_locked := false
var solved := false
var nearby_layer := ""

func _ready() -> void:
	size = Vector2(720, 480)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	prompt_order = PROMPTS.duplicate()
	prompt_order.shuffle()
	_build()

func _button_atlas(layer: String, state: StringName) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = load(BUTTON_ATLAS_PATH)
	if state == &"pressed":
		texture.region = BUTTON_PRESSED_REGIONS[layer]
	elif state == &"error":
		texture.region = BUTTON_ERROR_REGIONS[layer]
	else:
		texture.region = BUTTON_NORMAL_REGIONS[layer]
	return texture

func _layout_position(node_name: String) -> Vector2:
	var marker := get_node_or_null("Layout/" + node_name) as Node2D
	return marker.position if marker != null else Vector2.ZERO

func _build() -> void:
	_build_computer()
	for layer in BUTTON_NORMAL_REGIONS:
		_add_button(layer, _layout_position(layer))
	feedback = Label.new()
	feedback.position = _layout_position("Feedback")
	feedback.size = Vector2(260, 20)
	feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback.add_theme_font_size_override("font_size", 10)
	add_child(feedback)
	_show_prompt()

func _computer_atlas(off: bool = false) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = load(BUTTON_ATLAS_PATH)
	texture.region = COMPUTER_OFF_REGION if off else COMPUTER_ON_REGION
	return texture

func _build_computer() -> void:
	monitor = TextureRect.new()
	monitor.texture = _computer_atlas()
	monitor.position = _layout_position("Monitor")
	monitor.size = Vector2(100, 87)
	monitor.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	monitor.stretch_mode = TextureRect.STRETCH_SCALE
	monitor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	monitor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(monitor)
	prompt_label = Label.new()
	prompt_label.position = Vector2(12, 14)
	prompt_label.size = Vector2(138, 78)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt_label.clip_text = true
	prompt_label.add_theme_color_override("font_color", Color("24259a"))
	prompt_label.add_theme_font_size_override("font_size", 12)
	monitor_screen = ColorRect.new()
	monitor_screen.position = Vector2(8, 8)
	monitor_screen.size = Vector2(147, 101)
	monitor_screen.color = Color("39d83c")
	monitor_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	monitor_screen.hide()
	monitor.add_child(monitor_screen)
	monitor.add_child(prompt_label)

func _add_button(layer: String, button_position: Vector2) -> void:
	var normal := TextureRect.new()
	normal.name = layer
	normal.texture = _button_atlas(layer, &"normal")
	normal.position = button_position
	normal.size = Vector2(54, 32)
	normal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	normal.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	normal.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	normal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(normal)
	var pressed := TextureRect.new()
	pressed.texture = _button_atlas(layer, &"pressed")
	pressed.position = button_position + Vector2(0, 3)
	pressed.size = Vector2(54, 32)
	pressed.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pressed.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pressed.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pressed.hide()
	add_child(pressed)
	var error := TextureRect.new()
	error.texture = _button_atlas(layer, &"error")
	error.position = button_position
	error.size = Vector2(54, 32)
	error.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	error.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	error.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	error.mouse_filter = Control.MOUSE_FILTER_IGNORE
	error.hide()
	add_child(error)
	buttons[layer] = {"normal": normal, "pressed": pressed, "error": error}

func _show_prompt() -> void:
	if prompt_index >= prompt_order.size():
		solved = true
		feedback.text = "Sucesso! Painel de camadas concluido."
		prompt_label.hide()
		monitor.texture = _computer_atlas(false)
		monitor.modulate = Color.WHITE
		monitor_screen.show()
		StudySession.complete(&"sinais_osi")
		completed.emit()
		return
	var item: Dictionary = prompt_order[prompt_index]
	prompt_label.text = item["text"] as String
	feedback.text = "Selecione a camada OSI correspondente."

func _process(_delta: float) -> void:
	if solved or input_locked:
		return
	nearby_layer = _layer_under_player()
	if nearby_layer.is_empty():
		feedback.text = "Passe sobre um botao e pressione [E]."
	else:
		feedback.text = "[E] Pressionar " + nearby_layer

func _layer_under_player() -> String:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var slot := get_parent() as Node2D
	if player == null or slot == null:
		return ""
	var player_local := player.global_position - slot.global_position
	for layer in buttons:
		var normal := buttons[layer]["normal"] as TextureRect
		var hitbox := Rect2(normal.position, normal.size).grow(6.0)
		if hitbox.has_point(player_local):
			return layer
	return ""

func _unhandled_input(event: InputEvent) -> void:
	if solved or input_locked or nearby_layer.is_empty():
		return
	if event.is_action_pressed("interact") and not event.is_echo():
		_press(nearby_layer)
		get_viewport().set_input_as_handled()

func _reset_button_states() -> void:
	for layer in buttons:
		var visual: Dictionary = buttons[layer]
		(visual["pressed"] as TextureRect).hide()
		(visual["error"] as TextureRect).hide()
		(visual["normal"] as TextureRect).show()

func _press(layer: String) -> void:
	input_locked = true
	var visual: Dictionary = buttons[layer]
	(visual["normal"] as TextureRect).hide()
	(visual["error"] as TextureRect).hide()
	(visual["pressed"] as TextureRect).show()
	var item: Dictionary = prompt_order[prompt_index]
	var correct: bool = layer == str(item["answer"])
	if correct:
		feedback.text = "Correto!"
		await get_tree().create_timer(0.55).timeout
		# Um acerto limpa todos os estados visuais anteriores.
		_reset_button_states()
		prompt_index += 1
		input_locked = false
		_show_prompt()
	else:
		(visual["pressed"] as TextureRect).hide()
		(visual["error"] as TextureRect).show()
		feedback.text = "Incorreto: tente novamente."
		await get_tree().create_timer(0.75).timeout
		(visual["error"] as TextureRect).hide()
		(visual["normal"] as TextureRect).show()
		input_locked = false

func restore_completed() -> void:
	pass
