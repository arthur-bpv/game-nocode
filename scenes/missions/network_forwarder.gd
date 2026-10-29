extends Control

signal completed
signal mentor_message(message: String, duration: float)

@export_enum("routing", "switching") var simulator_id := "routing"

const SIMULATORS := {
	"routing": {
		"title": "SIMULADOR DE ROTEAMENTO",
		"intro": "Use a tabela de rotas para encaminhar cada pacote pelo próximo salto correto.",
		"table": "10.10.0.0/16 → R1\n10.10.20.0/24 → R2\n0.0.0.0/0 → Internet",
		"rounds": [
			{"packet": "Destino 10.10.20.44", "answer": "R2"},
			{"packet": "Destino 10.10.55.8", "answer": "R1"},
			{"packet": "Destino 8.8.8.8", "answer": "Internet"}
		], "choices": ["R1", "R2", "Internet"]
	},
	"switching": {
		"title": "SIMULADOR DE ENCAMINHAMENTO",
		"intro": "Consulte a tabela MAC e envie o quadro pela porta adequada do switch.",
		"table": "AA:10 → porta 1\nBB:20 → porta 2\nCC:30 → porta 3",
		"rounds": [
			{"packet": "Quadro para BB:20", "answer": "Porta 2"},
			{"packet": "Quadro para CC:30", "answer": "Porta 3"},
			{"packet": "Quadro para AA:10", "answer": "Porta 1"}
		], "choices": ["Porta 1", "Porta 2", "Porta 3"]
	}
}

var _simulator: Dictionary
var _round := 0
var _packet_label: Label
var _feedback: Label
var _buttons: Array[Button] = []

func _ready() -> void:
	_simulator = SIMULATORS[simulator_id]
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_show_round()

func mentor_intro() -> String:
	return String(_simulator["intro"])

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("0a111a")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var content := VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 42)
	content.add_theme_constant_override("separation", 18)
	add_child(content)
	var title := Label.new()
	title.text = String(_simulator["title"])
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("40e4ff"))
	content.add_child(title)
	var table := Label.new()
	table.text = "TABELA ATIVA\n" + String(_simulator["table"])
	table.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	table.add_theme_color_override("font_color", Color("c4e9ff"))
	table.add_theme_font_size_override("font_size", 16)
	content.add_child(table)
	_packet_label = Label.new()
	_packet_label.custom_minimum_size = Vector2(0, 88)
	_packet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_packet_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_packet_label.add_theme_font_size_override("font_size", 20)
	content.add_child(_packet_label)
	var choices := HBoxContainer.new()
	choices.alignment = BoxContainer.ALIGNMENT_CENTER
	choices.add_theme_constant_override("separation", 16)
	content.add_child(choices)
	for index in (_simulator["choices"] as Array).size():
		var button := Button.new()
		button.custom_minimum_size = Vector2(155, 66)
		button.add_theme_font_size_override("font_size", 16)
		button.pressed.connect(func() -> void: _forward(index))
		choices.add_child(button)
		_buttons.append(button)
	_feedback = Label.new()
	_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback.add_theme_font_size_override("font_size", 15)
	content.add_child(_feedback)

func _show_round() -> void:
	var rounds: Array = _simulator["rounds"]
	_packet_label.text = "QUADRO %d/%d\n%s" % [_round + 1, rounds.size(), rounds[_round]["packet"]]
	for index in _buttons.size():
		_buttons[index].text = String(_simulator["choices"][index])
		_buttons[index].show()
	_feedback.text = "Selecione o encaminhamento."

func _forward(index: int) -> void:
	var rounds: Array = _simulator["rounds"]
	if String(_simulator["choices"][index]) != String(rounds[_round]["answer"]):
		_feedback.text = "Encaminhamento incorreto: consulte a tabela e tente novamente."
		_feedback.add_theme_color_override("font_color", Color("ff8a8a"))
		return
	_round += 1
	if _round < rounds.size():
		_feedback.text = "Encaminhado. Preparando o próximo quadro…"
		_feedback.add_theme_color_override("font_color", Color("7ff0a4"))
		await get_tree().create_timer(0.45).timeout
		_show_round()
		return
	for button in _buttons:
		button.hide()
	_packet_label.text = "FLUXO ENTREGUE COM SUCESSO"
	_feedback.text = "Todas as decisões de encaminhamento foram corretas."
	_feedback.add_theme_color_override("font_color", Color("7ff0a4"))
	mentor_message.emit("Simulação concluída!", 3.0)
	completed.emit()
