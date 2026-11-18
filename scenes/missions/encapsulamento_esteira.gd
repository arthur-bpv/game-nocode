extends Control

signal completed

const ACCENT := Color("69edf0")
const MUTED := Color("b5c8d4")
const STAGES := [
	{
		"layer": "Aplicação", "piece": "Pedido HTTP",
		"hint": "O navegador quer abrir uma página. Qual ficha representa o pedido?",
		"result": "HTTP · solicita a página ao servidor",
		"feedback": "O navegador cria uma solicitação HTTP para pedir a página.",
	},
	{
		"layer": "Transporte", "piece": "Porta do serviço",
		"hint": "Qual ficha identifica o serviço que receberá os dados?",
		"result": "TCP · segmento com a porta do serviço",
		"feedback": "O TCP coloca os dados em um segmento. A porta de destino indica o serviço no servidor.",
	},
	{
		"layer": "Internet", "piece": "IP do servidor",
		"hint": "Qual ficha identifica o destino final da solicitação?",
		"result": "IP · pacote endereçado ao servidor",
		"feedback": "O pacote IP contém o segmento TCP e leva o endereço do servidor.",
	},
	{
		"layer": "Acesso à rede", "piece": "Quadro Ethernet",
		"hint": "O servidor está fora da rede local. Qual ficha prepara o envio ao roteador?",
		"result": "Ethernet · quadro entregue ao roteador",
		"feedback": "O quadro Ethernet leva o pacote IP ao roteador. O servidor continua sendo o destino final.",
	},
]

var _stage := 0
var _guided := true
var _hint_visible := false
var _has_completed := false

var _rows: Array[HBoxContainer] = []
var _row_statuses: Array[Label] = []
var _choices: Array[Button] = []
var _choice_row: HBoxContainer
var _instruction: Label
var _feedback: Label
var _hint: Button
var _replay: Button

func _ready() -> void:
	var content := VBoxContainer.new()
	content.mouse_filter = MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 8)
	add_child(content)
	content.set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	var title := Label.new()
	title.text = "Da página ao cabo"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", ACCENT)
	content.add_child(title)

	_instruction = _label("", 17, Color("e9f3f8"))
	_instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_instruction.custom_minimum_size.y = 44
	content.add_child(_instruction)

	for index in STAGES.size():
		_add_row(content, index)

	_choice_row = HBoxContainer.new()
	_choice_row.add_theme_constant_override("separation", 6)
	content.add_child(_choice_row)
	for index in STAGES.size():
		var choice := _button(STAGES[index].piece)
		choice.size_flags_horizontal = SIZE_EXPAND_FILL
		choice.pressed.connect(_choose.bind(index))
		_choice_row.add_child(choice)
		_choices.append(choice)

	_feedback = _label("", 17, MUTED)
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback.custom_minimum_size.y = 48
	content.add_child(_feedback)

	_hint = _button("Mostrar dica")
	_hint.pressed.connect(_show_hint)
	content.add_child(_hint)
	_replay = _button("Refazer sem dicas automáticas")
	_replay.pressed.connect(_restart)
	content.add_child(_replay)
	_refresh()

func _add_row(content: VBoxContainer, index: int) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 30
	row.add_theme_constant_override("separation", 18)
	content.add_child(row)
	_rows.append(row)

	var layer := _label("%02d  %s" % [index + 1, STAGES[index].layer], 17, Color("e9f3f8"))
	layer.custom_minimum_size.x = 180
	row.add_child(layer)
	var status := _label("", 17, MUTED)
	status.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(status)
	_row_statuses.append(status)

	var divider := ColorRect.new()
	divider.color = Color("2c4856")
	divider.custom_minimum_size.y = 1
	divider.mouse_filter = MOUSE_FILTER_IGNORE
	content.add_child(divider)

func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_override("font", ThemeDB.fallback_font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _button(value: String) -> Button:
	var button := Button.new()
	button.text = value
	button.add_theme_font_override("font", ThemeDB.fallback_font)
	button.add_theme_font_size_override("font_size", 16)
	button.size_flags_horizontal = SIZE_SHRINK_BEGIN
	return button

func _choose(index: int) -> void:
	if _stage == STAGES.size() or index < _stage:
		return
	if index != _stage:
		_set_feedback("Essa ficha entra na camada %s. Tente a ficha da etapa atual." % STAGES[index].layer, Color("ffd080"))
		return
	_set_feedback(STAGES[index].feedback, ACCENT)
	_stage += 1
	_hint_visible = false
	_refresh()
	if _stage == STAGES.size() and not _has_completed:
		_has_completed = true
		completed.emit()

func _refresh() -> void:
	var finished := _stage == STAGES.size()
	if finished:
		_instruction.text = "Enviado · Quadro Ethernet contém pacote IP, segmento TCP e dados HTTP."
	elif _guided or _hint_visible:
		_instruction.text = STAGES[_stage].hint
	else:
		_instruction.text = "Qual ficha pertence à camada destacada?"
	for index in STAGES.size():
		var status := _row_statuses[index]
		if index < _stage:
			status.text = STAGES[index].result
		else:
			status.text = "Selecione a ficha abaixo" if index == _stage else "—"
		status.add_theme_color_override("font_color", ACCENT if index == _stage else MUTED)
		_choices[index].disabled = index < _stage
	_choice_row.visible = not finished
	_hint.visible = not finished and not _guided and not _hint_visible
	_replay.visible = finished

func _set_feedback(message: String, color: Color) -> void:
	_feedback.text = message
	_feedback.add_theme_color_override("font_color", color)

func _show_hint() -> void:
	_hint_visible = true
	_refresh()

func _restart() -> void:
	_stage = 0
	_guided = false
	_hint_visible = false
	for index in [2, 0, 3, 1]:
		_choice_row.move_child(_choices[index], -1)
	_set_feedback("", MUTED)
	_refresh()
	_choices[2].grab_focus()

func restore_completed() -> void:
	if _has_completed:
		return
	_has_completed = true
	_stage = STAGES.size()
	_set_feedback(STAGES.back().feedback, ACCENT)
	_refresh()
