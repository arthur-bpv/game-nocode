extends Control

signal completed
signal mentor_message(message: String, duration: float)
signal mentor_context(message: String)

const BUTTON_ATLAS_PATH := "res://assets/sprites/sinais_osi_buttons_v2.svg"
const COMPUTER_SPRITE_PATH := "res://assets/sprites/sinais_osi_console_v2.svg"
const COMPUTER_COMPLETE_SPRITE_PATH := "res://assets/sprites/sinais_osi_console_complete_v2.svg"
const PROJECT_FONT_PATH := "res://assets/fonts/press_start_2p/PressStart2P-Regular.ttf"
const COMPUTER_ON_REGION := Rect2(0, 0, 180, 155)
const COMPUTER_OFF_REGION := Rect2(0, 0, 180, 155)
const BUTTON_NORMAL_REGIONS := {
	"Aplicacao": Rect2(0, 0, 90, 52), "Apresentacao": Rect2(90, 0, 90, 52), "Sessao": Rect2(180, 0, 90, 52), "Transporte": Rect2(270, 0, 90, 52), "Rede": Rect2(360, 0, 90, 52), "Enlace": Rect2(450, 0, 90, 52), "Fisica": Rect2(540, 0, 90, 52),
}
const BUTTON_PRESSED_REGIONS := {
	"Aplicacao": Rect2(0, 52, 90, 52), "Apresentacao": Rect2(90, 52, 90, 52), "Sessao": Rect2(180, 52, 90, 52), "Transporte": Rect2(270, 52, 90, 52), "Rede": Rect2(360, 52, 90, 52), "Enlace": Rect2(450, 52, 90, 52), "Fisica": Rect2(540, 52, 90, 52),
}

const BUTTON_ERROR_REGIONS := {
	"Aplicacao": Rect2(0, 104, 90, 52), "Apresentacao": Rect2(90, 104, 90, 52), "Sessao": Rect2(180, 104, 90, 52), "Transporte": Rect2(270, 104, 90, 52), "Rede": Rect2(360, 104, 90, 52), "Enlace": Rect2(450, 104, 90, 52), "Fisica": Rect2(540, 104, 90, 52),
}
const BUTTON_LABELS := {
	"Aplicacao": "APLI\nCAÇÃO",
	"Apresentacao": "APRE\nSENTAÇÃO",
	"Sessao": "SESSÃO",
	"Transporte": "TRANS\nPORTE",
	"Rede": "REDE",
	"Enlace": "ENLACE",
	"Fisica": "FÍSICA",
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
const ROUND_LENGTH := 7

var buttons: Dictionary = {}
var prompt_label: Label
var prompt_subtitle: Label
var protocol_header: Label
var feedback: Label
var monitor: TextureRect
var monitor_screen: ColorRect
var prompt_backdrop: ColorRect
var prompt_index := 0
var prompt_order: Array = []
var input_locked := false
var solved := false
var nearby_layer := ""

func _ready() -> void:
	size = Vector2(720, 480)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	prompt_order = _build_round()
	_build()

func _build_round() -> Array:
	var selected := []
	var rng := ChallengeSession.make_rng(&"sinais_osi/round")
	for layer in BUTTON_NORMAL_REGIONS:
		var choices := []
		for item in PROMPTS:
			if item["answer"] == layer:
				choices.append(item)
		if choices.is_empty():
			push_error("Nenhum protocolo configurado para a camada %s." % layer)
			continue
		selected.append(ChallengeSession.choose_unused(StringName("sinais_osi/" + String(layer)), choices, rng))
	selected = ChallengeSession.shuffled(&"sinais_osi/order", selected)
	if selected.size() != ROUND_LENGTH:
		push_error("A rodada do decodificador precisa cobrir as sete camadas OSI.")
	return selected

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

func _computer_atlas(completed_state: bool = false) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = load(COMPUTER_COMPLETE_SPRITE_PATH if completed_state else COMPUTER_SPRITE_PATH)
	texture.region = COMPUTER_OFF_REGION if completed_state else COMPUTER_ON_REGION
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
	prompt_label.position = Vector2(25, 43)
	prompt_label.size = Vector2(130, 61)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt_label.clip_text = true
	prompt_label.add_theme_font_override("font", project_font)
	prompt_label.add_theme_color_override("font_color", Color("efffff"))
	prompt_label.add_theme_color_override("font_outline_color", Color("06131d"))
	prompt_label.add_theme_constant_override("outline_size", 3)
	prompt_label.add_theme_font_size_override("font_size", 20)
	prompt_subtitle = Label.new()
	prompt_subtitle.position = Vector2(25, 86)
	prompt_subtitle.size = Vector2(130, 18)
	prompt_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_subtitle.clip_text = true
	prompt_subtitle.add_theme_font_override("font", project_font)
	prompt_subtitle.add_theme_font_size_override("font_size", 10)
	prompt_subtitle.add_theme_color_override("font_color", Color("9ffcff"))
	prompt_subtitle.add_theme_color_override("font_outline_color", Color("06131d"))
	prompt_subtitle.add_theme_constant_override("outline_size", 2)
	prompt_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_subtitle.hide()
	prompt_backdrop = ColorRect.new()
	prompt_backdrop.position = Vector2(22, 40)
	prompt_backdrop.size = Vector2(136, 67)
	prompt_backdrop.color = Color(0.02, 0.11, 0.16, 0.82)
	prompt_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	monitor_screen = ColorRect.new()
	monitor_screen.position = Vector2(9, 11)
	monitor_screen.size = Vector2(162, 108)
	monitor_screen.color = Color("39d83c")
	monitor_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	monitor_screen.hide()
	monitor.add_child(prompt_backdrop)
	monitor.add_child(monitor_screen)
	monitor.add_child(prompt_label)
	monitor.add_child(prompt_subtitle)

func _add_button(layer: String, button_position: Vector2) -> void:
	var normal := TextureRect.new()
	normal.name = layer
	normal.texture = _button_atlas(layer, &"normal")
	normal.position = button_position
	normal.size = Vector2(90, 52)
	normal.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	normal.stretch_mode = TextureRect.STRETCH_SCALE
	normal.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	normal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(normal)
	_add_button_label(normal, layer)
	var pressed := TextureRect.new()
	pressed.texture = _button_atlas(layer, &"pressed")
	pressed.position = button_position + Vector2(0, 3)
	pressed.size = Vector2(90, 52)
	pressed.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pressed.stretch_mode = TextureRect.STRETCH_SCALE
	pressed.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pressed.hide()
	add_child(pressed)
	_add_button_label(pressed, layer)
	var error := TextureRect.new()
	error.texture = _button_atlas(layer, &"error")
	error.position = button_position
	error.size = Vector2(90, 52)
	error.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	error.stretch_mode = TextureRect.STRETCH_SCALE
	error.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	error.mouse_filter = Control.MOUSE_FILTER_IGNORE
	error.hide()
	add_child(error)
	_add_button_label(error, layer)
	buttons[layer] = {"normal": normal, "pressed": pressed, "error": error}

func _add_button_label(target: TextureRect, layer: String) -> void:
	var lines: PackedStringArray = String(BUTTON_LABELS[layer]).split("\n")
	var is_multiline := lines.size() > 1
	for line_index in lines.size():
		var label := Label.new()
		label.text = lines[line_index]
		label.set_anchors_preset(Control.PRESET_TOP_LEFT)
		if is_multiline:
			label.position = Vector2(14, 12 + line_index * 9)
			label.size = Vector2(62, 10)
			if layer == "Apresentacao" and line_index == 1:
				label.position = Vector2(1, 21)
		else:
			label.position = Vector2(14, 15)
			label.size = Vector2(62, 18)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.clip_text = true
		label.add_theme_font_override("font", load(PROJECT_FONT_PATH) as Font)
		var font_size := 7
		if is_multiline:
			font_size = 6
		label.add_theme_font_size_override("font_size", font_size)
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_color_override("font_outline_color", Color("071018"))
		label.add_theme_constant_override("outline_size", 1)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		target.add_child(label)

func _show_prompt() -> void:
	if prompt_index >= prompt_order.size():
		solved = true
		SoundEffects.play_task_complete()
		protocol_header.text = "PROTOCOLOS %d/%d" % [prompt_order.size(), prompt_order.size()]
		feedback.text = "Sucesso! Painel de camadas concluido."
		prompt_label.hide()
		prompt_subtitle.hide()
		monitor.texture = _computer_atlas(true)
		monitor.modulate = Color.WHITE
		monitor_screen.hide()
		prompt_backdrop.hide()
		mentor_context.emit("")
		mentor_message.emit("Painel de camadas concluído!", 5.0)
		completed.emit()
		return
	var item: Dictionary = prompt_order[prompt_index]
	protocol_header.text = "PROTOCOLOS %d/%d" % [prompt_index + 1, prompt_order.size()]
	prompt_label.show()
	prompt_label.text = item["text"] as String
	var subtitle := String(item.get("subtitle", ""))
	prompt_subtitle.text = subtitle
	prompt_subtitle.visible = not subtitle.is_empty()
	prompt_label.size.y = 42.0 if not subtitle.is_empty() else 60.0
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
		SoundEffects.play_correct()
		feedback.text = "Correto!"
		mentor_message.emit("Correto! Vamos para a próxima pista.", 2.5)
		await get_tree().create_timer(0.55).timeout
		# Um acerto limpa todos os estados visuais anteriores.
		_reset_button_states()
		prompt_index += 1
		input_locked = false
		_show_prompt()
	else:
		SoundEffects.play_error()
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
	protocol_header.text = "PROTOCOLOS %d/%d" % [prompt_order.size(), prompt_order.size()]
	feedback.text = "Sucesso! Painel de camadas concluido."
	prompt_label.hide()
	prompt_subtitle.hide()
	monitor.texture = _computer_atlas(true)
	monitor.modulate = Color.WHITE
	monitor_screen.hide()
	prompt_backdrop.hide()
