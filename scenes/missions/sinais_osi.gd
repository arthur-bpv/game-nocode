extends Control

signal completed
signal mentor_message(message: String, duration: float)
signal mentor_context(message: String)

const BUTTON_ATLAS_PATH := "res://assets/sprites/Handshake.png"
const PROJECT_FONT_PATH := "res://assets/fonts/press_start_2p/PressStart2P-Regular.ttf"
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
	{"text": "FIBRA ÓPTICA", "answer": "Fisica"},
	{"text": "USB", "answer": "Fisica"},
	{"text": "ETHERNET", "answer": "Enlace"},
	{"text": "PPP", "subtitle": "POINT-TO-POINT", "answer": "Enlace"},
	{"text": "IPV4", "answer": "Rede"},
	{"text": "IPV6", "answer": "Rede"},
	{"text": "TCP", "answer": "Transporte"},
	{"text": "UDP", "answer": "Transporte"},
	{"text": "RPC", "answer": "Sessao"},
	{"text": "NETBIOS", "answer": "Sessao"},
	{"text": "SSL", "answer": "Apresentacao"},
	{"text": "TLS", "answer": "Apresentacao"},
	{"text": "HTTPS", "answer": "Aplicacao"},
	{"text": "DHCP", "answer": "Aplicacao"},
]

var buttons: Dictionary = {}
var prompt_label: Label
var prompt_subtitle: Label
var protocol_header: Label
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

func mentor_intro() -> String:
	return "Leia o protocolo no monitor. Passe sobre um botão e pressione [E] para escolher a camada OSI."

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
	feedback.hide()
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
	monitor.size = Vector2(180, 155)
	monitor.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	monitor.stretch_mode = TextureRect.STRETCH_SCALE
	monitor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	monitor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(monitor)
	var project_font := load(PROJECT_FONT_PATH) as Font
	protocol_header = Label.new()
	protocol_header.position = Vector2(0, -30)
	protocol_header.size = Vector2(180, 24)
	protocol_header.text = "PROTOCOLOS"
	protocol_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	protocol_header.add_theme_font_override("font", project_font)
	protocol_header.add_theme_font_size_override("font_size", 11)
	protocol_header.add_theme_color_override("font_color", Color.WHITE)
	protocol_header.add_theme_color_override("font_outline_color", Color.BLACK)
	protocol_header.add_theme_constant_override("outline_size", 3)
	protocol_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	monitor.add_child(protocol_header)
	prompt_label = Label.new()
	prompt_label.position = Vector2(15, 18)
	prompt_label.size = Vector2(150, 96)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt_label.clip_text = true
	prompt_label.add_theme_font_override("font", project_font)
	prompt_label.add_theme_color_override("font_color", Color("172b78"))
	prompt_label.add_theme_font_size_override("font_size", 17)
	prompt_subtitle = Label.new()
	prompt_subtitle.position = Vector2(12, 91)
	prompt_subtitle.size = Vector2(156, 22)
	prompt_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_subtitle.clip_text = true
	prompt_subtitle.add_theme_font_override("font", project_font)
	prompt_subtitle.add_theme_font_size_override("font_size", 9)
	prompt_subtitle.add_theme_color_override("font_color", Color("172b78"))
	prompt_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_subtitle.hide()
	monitor_screen = ColorRect.new()
	monitor_screen.position = Vector2(9, 11)
	monitor_screen.size = Vector2(162, 108)
	monitor_screen.color = Color("39d83c")
	monitor_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	monitor_screen.hide()
	monitor.add_child(monitor_screen)
	monitor.add_child(prompt_label)
	monitor.add_child(prompt_subtitle)

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
		prompt_subtitle.hide()
		monitor.texture = _computer_atlas(false)
		monitor.modulate = Color.WHITE
		monitor_screen.show()
		mentor_context.emit("")
		mentor_message.emit("Painel de camadas concluído!", 5.0)
		completed.emit()
		return
	var item: Dictionary = prompt_order[prompt_index]
	prompt_label.show()
	prompt_label.text = item["text"] as String
	var subtitle := String(item.get("subtitle", ""))
	prompt_subtitle.text = subtitle
	prompt_subtitle.visible = not subtitle.is_empty()
	prompt_label.size.y = 70.0 if not subtitle.is_empty() else 96.0
	var text_length := prompt_label.text.length()
	var font_size := 14 if text_length > 10 else 16 if text_length > 7 else 18
	prompt_label.add_theme_font_size_override("font_size", font_size)
	feedback.text = "Selecione a camada OSI correspondente."

func _process(_delta: float) -> void:
	if solved or input_locked:
		return
	var previous_layer := nearby_layer
	nearby_layer = _layer_under_player()
	if nearby_layer.is_empty():
		feedback.text = "Passe sobre um botao e pressione [E]."
		if not previous_layer.is_empty():
			mentor_context.emit("")
	else:
		feedback.text = "[E] Pressionar " + nearby_layer
		if nearby_layer != previous_layer:
			mentor_context.emit("Pressione [E] para selecionar %s." % nearby_layer)

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
		mentor_message.emit("Correto! Vamos para a próxima pista.", 2.5)
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
		mentor_message.emit("Essa não é a camada da pista. Tente novamente.", 3.0)
		await get_tree().create_timer(0.75).timeout
		(visual["error"] as TextureRect).hide()
		(visual["normal"] as TextureRect).show()
		input_locked = false

func restore_completed() -> void:
	solved = true
	input_locked = true
	prompt_index = prompt_order.size()
	feedback.text = "Sucesso! Painel de camadas concluido."
	prompt_label.hide()
	prompt_subtitle.hide()
	monitor.texture = _computer_atlas(false)
	monitor.modulate = Color.WHITE
	monitor_screen.show()
