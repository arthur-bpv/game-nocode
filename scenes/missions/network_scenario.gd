extends Control

signal completed
signal mentor_message(message: String, duration: float)

@export_enum("ipv4", "routing", "vlan", "services_security") var lesson_id := "ipv4"

const LESSONS := {
	"ipv4": {
		"title": "CENTRAL DE ENDEREÇAMENTO IPv4",
		"intro": "Abra o terminal e resolva cenários de IPv4 e sub-redes.",
		"questions": [
			{"text": "A rede 192.168.10.0/24 foi dividida em sub-redes /26. Quantos endereços utilizáveis há em cada sub-rede?", "choices": ["62", "126", "254"], "answer": 0},
			{"text": "Qual gateway pertence à mesma sub-rede do host 10.0.5.34/27?", "choices": ["10.0.5.1", "10.0.5.33", "10.0.5.65"], "answer": 1},
			{"text": "Um host recebeu 172.16.8.190/26. Qual é o endereço de rede?", "choices": ["172.16.8.128", "172.16.8.190", "172.16.8.255"], "answer": 0}
		]
	},
	"routing": {
		"title": "CENTRAL DE DECISÕES DE ROTEAMENTO",
		"intro": "Leia a situação de cada pacote e escolha a regra de roteamento que resolve o caminho.",
		"questions": [
			{"text": "Um roteador possui 10.20.0.0/16 via R1 e 10.20.8.0/24 via R2. Para 10.20.8.75, qual rota vence?", "choices": ["10.20.8.0/24 via R2", "10.20.0.0/16 via R1", "Rota padrão"], "answer": 0},
			{"text": "Não há rota específica para 200.10.5.4, mas há 0.0.0.0/0 via Internet. Como o pacote deve seguir?", "choices": ["Pela rota padrão", "Descartado imediatamente", "Para o gateway da LAN"], "answer": 0},
			{"text": "Qual informação um roteador consulta para decidir o próximo salto de um pacote IP?", "choices": ["Endereço IP de destino", "Endereço MAC de origem", "Número da porta TCP de origem"], "answer": 0}
		]
	},
	"vlan": {
		"title": "PAINEL DE SWITCHING E VLANs",
		"intro": "Abra o terminal e configure a segmentação lógica da rede.",
		"questions": [
			{"text": "Dois PCs na VLAN 20 precisam comunicar por um enlace entre switches. Que tipo de porta transporta a VLAN 20 entre eles?", "choices": ["Trunk", "Access", "Console"], "answer": 0},
			{"text": "Um PC da VLAN 10 precisa alcançar um servidor na VLAN 30. Qual recurso é necessário?", "choices": ["Roteamento inter-VLAN", "Outro cabo direto", "Aumentar o MTU"], "answer": 0},
			{"text": "Em qual tabela um switch aprende a associação entre MAC e porta?", "choices": ["Tabela MAC/CAM", "Tabela ARP do cliente", "Tabela DNS"], "answer": 0}
		]
	},
	"services_security": {
		"title": "CENTRAL DE SERVIÇOS E SEGURANÇA",
		"intro": "Abra o terminal e identifique o serviço ou a proteção adequada.",
		"questions": [
			{"text": "Qual serviço traduz o nome intranet.empresa.local para um endereço IP?", "choices": ["DNS", "DHCP", "NTP"], "answer": 0},
			{"text": "Qual protocolo entrega automaticamente IP, máscara e gateway a uma estação?", "choices": ["DHCP", "HTTPS", "SSH"], "answer": 0},
			{"text": "Para administrar um roteador remotamente com criptografia, qual protocolo deve ser usado?", "choices": ["SSH", "Telnet", "FTP"], "answer": 0}
		]
	}
}

var _lesson: Dictionary
var _question_index := 0
var _question_label: Label
var _feedback_label: Label
var _choices: Array[Button] = []

func _ready() -> void:
	_lesson = LESSONS[lesson_id]
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_show_question()

func mentor_intro() -> String:
	return String(_lesson.get("intro", "Abra a atividade no terminal."))

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("071217")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var content := VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 34)
	content.add_theme_constant_override("separation", 18)
	add_child(content)

	var title := Label.new()
	title.text = String(_lesson["title"])
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("40e4ff"))
	content.add_child(title)

	_question_label = Label.new()
	_question_label.custom_minimum_size = Vector2(0, 110)
	_question_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_question_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_question_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_question_label.add_theme_font_size_override("font_size", 17)
	content.add_child(_question_label)

	for index in 3:
		var choice := Button.new()
		choice.custom_minimum_size = Vector2(0, 54)
		choice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		choice.add_theme_font_size_override("font_size", 15)
		choice.pressed.connect(func() -> void: _answer(index))
		content.add_child(choice)
		_choices.append(choice)

	_feedback_label = Label.new()
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback_label.add_theme_font_size_override("font_size", 14)
	content.add_child(_feedback_label)

func _show_question() -> void:
	var questions: Array = _lesson["questions"]
	var question: Dictionary = questions[_question_index]
	_question_label.text = "CENÁRIO %d/%d\n%s" % [_question_index + 1, questions.size(), question["text"]]
	for index in _choices.size():
		_choices[index].text = "%d. %s" % [index + 1, question["choices"][index]]
		_choices[index].disabled = false
	_feedback_label.text = ""

func _answer(index: int) -> void:
	var questions: Array = _lesson["questions"]
	var question: Dictionary = questions[_question_index]
	if index != int(question["answer"]):
		_feedback_label.text = "Revise o cenário e tente outra alternativa."
		_feedback_label.add_theme_color_override("font_color", Color("ff8a8a"))
		return
	_question_index += 1
	if _question_index < questions.size():
		_feedback_label.text = "Correto. Preparando o próximo cenário…"
		_feedback_label.add_theme_color_override("font_color", Color("7ff0a4"))
		await get_tree().create_timer(0.55).timeout
		_show_question()
		return
	for choice in _choices:
		choice.hide()
	_question_label.text = "MÓDULO CONCLUÍDO"
	_feedback_label.text = "Você concluiu os cenários deste conteúdo."
	_feedback_label.add_theme_color_override("font_color", Color("7ff0a4"))
	mentor_message.emit("Módulo concluído!", 3.0)
	completed.emit()
