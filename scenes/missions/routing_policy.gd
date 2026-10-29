extends Control

signal completed
signal mentor_message(message: String, duration: float)

const CASES := [
	{
		"title": "FILIAL REMOTA",
		"topology": "HQ ─── enlace único ─── Filial\nA rede 172.20.4.0/24 nunca muda.",
		"goal": "Escolha como instalar a rota para a filial.",
		"answer": "Rota estática",
		"explanation": "Uma rota estática é simples e previsível quando há um único caminho estável."
	},
	{
		"title": "CAMPUS COM REDUNDÂNCIA",
		"topology": "R1 ─── R2\n ╲     ╱\n  R3\nHá vários caminhos entre os prédios.",
		"goal": "Escolha a estratégia que reage a falhas automaticamente.",
		"answer": "OSPF dinâmico",
		"explanation": "OSPF troca informações entre roteadores e recalcula caminhos quando a topologia muda."
	},
	{
		"title": "LINK PRINCIPAL INDISPONÍVEL",
		"topology": "Internet ─── R1 ─── R2\n              ╲────── backup ──────╱",
		"goal": "Qual abordagem evita editar manualmente cada roteador após uma falha?",
		"answer": "Protocolo dinâmico",
		"explanation": "Protocolos dinâmicos convergem para uma rota alternativa após detectar a falha."
	}
]

const CHOICES := ["Rota estática", "OSPF dinâmico", "Protocolo dinâmico"]

var _case_index := 0
var _case_label: Label
var _goal_label: Label
var _feedback: Label
var _buttons: Array[Button] = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_show_case()

func mentor_intro() -> String:
	return "Use o console do roteador para decidir quando uma rota estática basta e quando a rede exige roteamento dinâmico."

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("08131c")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var content := VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 34)
	content.add_theme_constant_override("separation", 14)
	add_child(content)
	var title := Label.new()
	title.text = "CONSOLE DE POLÍTICAS DE ROTEAMENTO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("40e4ff"))
	content.add_child(title)
	_case_label = Label.new()
	_case_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_case_label.add_theme_font_size_override("font_size", 17)
	_case_label.add_theme_color_override("font_color", Color("d5f2ff"))
	content.add_child(_case_label)
	_goal_label = Label.new()
	_goal_label.custom_minimum_size = Vector2(0, 70)
	_goal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_goal_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_goal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_goal_label)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 10)
	content.add_child(buttons)
	for index in CHOICES.size():
		var button := Button.new()
		button.text = CHOICES[index]
		button.custom_minimum_size = Vector2(165, 64)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(func() -> void: _configure(index))
		buttons.add_child(button)
		_buttons.append(button)
	_feedback = Label.new()
	_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback.add_theme_font_size_override("font_size", 15)
	content.add_child(_feedback)

func _show_case() -> void:
	var current: Dictionary = CASES[_case_index]
	_case_label.text = "%s\n%s" % [String(current["title"]), String(current["topology"])]
	_goal_label.text = "%d/%d — %s" % [_case_index + 1, CASES.size(), String(current["goal"])]
	_feedback.text = "Selecione a configuração mais adequada."
	for button in _buttons:
		button.disabled = false

func _configure(index: int) -> void:
	var current: Dictionary = CASES[_case_index]
	if CHOICES[index] != String(current["answer"]):
		_feedback.text = "Essa decisão não atende ao cenário. Reavalie a estabilidade e a redundância da topologia."
		_feedback.add_theme_color_override("font_color", Color("ff8a8a"))
		return
	_feedback.text = String(current["explanation"])
	_feedback.add_theme_color_override("font_color", Color("7ff0a4"))
	for button in _buttons:
		button.disabled = true
	await get_tree().create_timer(1.4).timeout
	_case_index += 1
	if _case_index < CASES.size():
		_show_case()
		return
	_case_label.text = "POLÍTICA APLICADA"
	_goal_label.text = "Você distinguiu cenários de roteamento estático e dinâmico."
	_feedback.text = "Console concluído."
	mentor_message.emit("Você configurou a estratégia certa para cada topologia!", 3.0)
	completed.emit()
