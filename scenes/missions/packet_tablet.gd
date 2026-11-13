extends Control

signal completed

const STEPS := [
	{
		"name": "Resolver o domínio",
		"question": "Você digitou portal.exemplo. Qual serviço encontra o endereço IP desse nome?",
		"choices": ["DHCP", "DNS", "HTTPS"], "answer": 1,
		"hint": "O navegador precisa traduzir um nome em endereço IP."
	},
	{
		"name": "Escolher o próximo salto",
		"question": "O IP do site está fora da rede local. Para onde o computador envia o primeiro quadro?",
		"choices": ["Gateway padrão", "Switch como destino final", "Servidor DNS"], "answer": 0,
		"hint": "Procure o roteador que dá saída para outras redes."
	},
	{
		"name": "Abrir o site com segurança",
		"question": "Qual protocolo protege a comunicação entre o navegador e o site?",
		"choices": ["HTTP", "FTP", "HTTPS"], "answer": 2,
		"hint": "A conexão precisa de criptografia e autenticação do servidor."
	}
]
const STATION_NAMES := ["DNS", "ROTA", "HTTPS"]
const PACKET := preload("res://assets/sprites/Pacote.png")

var stops: Array[Vector2] = [Vector2(49, 191), Vector2(131, 191), Vector2(213, 191), Vector2(260, 191)]
var step_index := 0
var packet: Sprite2D
var answers: Array[Button] = []
var replay: Button
var _step_label: Label
var _question: Label
var _feedback: Label
var _preview: Control
var _moving := false
var _completed_once := false
var _steps: Array = []

func _ready() -> void:
	_steps = STEPS.duplicate(true)
	for step_value in _steps:
		var step := step_value as Dictionary
		var original_choices: Array = step["choices"] as Array
		var correct_choice: Variant = original_choices[int(step["answer"])]
		step["choices"] = ChallengeSession.shuffled(StringName("packet_tablet/" + String(step["name"])), original_choices)
		step["answer"] = (step["choices"] as Array).find(correct_choice)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 22)
	add_child(columns)
	columns.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_preview = Control.new()
	_preview.custom_minimum_size = Vector2(280, 340)
	_preview.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columns.add_child(_preview)
	_preview.draw.connect(_draw_preview)

	packet = Sprite2D.new()
	packet.texture = PACKET
	packet.scale = Vector2.ONE * (35.0 / PACKET.get_width())
	packet.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_preview.add_child(packet)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	columns.add_child(content)
	content.add_child(_label("ESTEIRA DE PACOTES", 16, Color("6ddbe4")))
	content.add_child(_label("Abra um site com segurança", 24, Color("edf9ff")))
	_step_label = _label("", 17, Color("80d9df"))
	content.add_child(_step_label)
	_question = _label("", 18, Color("edf9ff"))
	_question.custom_minimum_size.y = 82
	content.add_child(_question)

	for index in 3:
		var button := Button.new()
		button.custom_minimum_size.y = 42
		button.add_theme_font_size_override("font_size", 16)
		button.pressed.connect(_choose.bind(index))
		content.add_child(button)
		answers.append(button)
	_feedback = _label("", 16, Color("d4e4eb"))
	_feedback.custom_minimum_size.y = 48
	content.add_child(_feedback)
	replay = Button.new()
	replay.text = "Repetir percurso"
	replay.pressed.connect(_reset)
	content.add_child(replay)
	_reset()

func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", ThemeDB.fallback_font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _draw_preview() -> void:
	_preview.draw_style_box(_window_style(), Rect2(Vector2.ZERO, _preview.size))
	var font := ThemeDB.fallback_font
	_preview.draw_string(font, Vector2(16, 34), "JANELA DA ESTEIRA", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("6ddbe4"))
	_preview.draw_string(font, Vector2(16, 59), "Acompanhe o mesmo pacote", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("b6ccd4"))
	_preview.draw_rect(Rect2(17, 177, 248, 29), Color("334852"))
	for x in range(19, 265, 12):
		_preview.draw_line(Vector2(x, 178), Vector2(x, 205), Color("56717e"))
	for index in STATION_NAMES.size():
		var x := stops[index].x
		var color := Color("64e4a7") if index < step_index else Color("60dce6") if index == step_index else Color("47636f")
		_preview.draw_rect(Rect2(x - 28, 155, 56, 71), Color("253940"))
		_preview.draw_rect(Rect2(x - 24, 171, 48, 40), Color("0d2730"))
		_preview.draw_rect(Rect2(x - 28, 155, 56, 71), color, false, 2.0)
		_preview.draw_string(font, Vector2(x - 30, 254), STATION_NAMES[index], HORIZONTAL_ALIGNMENT_CENTER, 60, 14, color)

func _window_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("102027")
	style.border_color = Color("365760")
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	return style

func _choose(index: int) -> void:
	if _moving or step_index >= _steps.size():
		return
	var step: Dictionary = _steps[step_index]
	if index != step["answer"]:
		_feedback.text = "Tente novamente. " + String(step["hint"])
		SoundEffects.play_error()
		return
	SoundEffects.play_correct()
	_moving = true
	for button in answers:
		button.disabled = true
	_feedback.text = "Correto. Pacote em trânsito…"
	var tween := create_tween()
	tween.tween_property(packet, "position", stops[step_index + 1], 0.42)
	await tween.finished
	step_index += 1
	_moving = false
	_refresh()
	if step_index == _steps.size():
		SoundEffects.play_task_complete()
		if not _completed_once:
			_completed_once = true
			completed.emit()

func _refresh() -> void:
	var finished := step_index == _steps.size()
	for button in answers:
		button.visible = not finished
		button.disabled = finished
	replay.visible = finished
	_preview.queue_redraw()
	if finished:
		_step_label.text = "PERCURSO CONCLUÍDO"
		_question.text = "Você resolveu o domínio, encaminhou o pacote e escolheu uma conexão segura."
		_feedback.text = "Entrega concluída."
		return
	var step: Dictionary = _steps[step_index]
	_step_label.text = "%d / %d  ·  %s" % [step_index + 1, _steps.size(), step["name"]]
	_question.text = step["question"]
	for index in answers.size():
		answers[index].text = step["choices"][index]
	_feedback.text = ""

func _reset() -> void:
	step_index = 0
	packet.position = stops[0]
	_refresh()

func restore_completed() -> void:
	if _completed_once:
		return
	_completed_once = true
	step_index = _steps.size()
	packet.position = stops[step_index]
	_refresh()
