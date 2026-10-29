extends Control

signal completed
signal mentor_message(message: String, duration: float)

var _phase := 0
var _topology: Label
var _status: Label
var _action_a: Button
var _action_b: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_show_phase()

func mentor_intro() -> String:
	return "Compare uma rota estática com uma rede OSPF: provoque uma falha e observe qual configuração consegue encontrar o caminho alternativo."

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("09151d")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var content := VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 34)
	content.add_theme_constant_override("separation", 17)
	add_child(content)
	var title := Label.new()
	title.text = "CENTRO DE CONVERGÊNCIA OSPF"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("40e4ff"))
	content.add_child(title)
	_topology = Label.new()
	_topology.custom_minimum_size = Vector2(0, 150)
	_topology.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_topology.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_topology.add_theme_font_size_override("font_size", 19)
	_topology.add_theme_color_override("font_color", Color("d5f2ff"))
	content.add_child(_topology)
	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 16)
	content.add_child(controls)
	_action_a = Button.new()
	_action_a.custom_minimum_size = Vector2(230, 65)
	_action_a.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_action_a.pressed.connect(func() -> void: _choose(0))
	controls.add_child(_action_a)
	_action_b = Button.new()
	_action_b.custom_minimum_size = Vector2(230, 65)
	_action_b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_action_b.pressed.connect(func() -> void: _choose(1))
	controls.add_child(_action_b)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 15)
	content.add_child(_status)

func _show_phase() -> void:
	match _phase:
		0:
			_topology.text = "CLIENTE ─── R1 ─── R3 ─── SERVIDOR\n             ╲          ╱\n              └── R2 ──┘"
			_action_a.text = "Instalar rota estática\nvia R1 → R3"
			_action_b.text = "Ativar OSPF nos três roteadores"
			_status.text = "A rede tem dois caminhos possíveis. Qual configuração aprende ambos?"
		1:
			_topology.text = "CLIENTE ─── R1  ✕  R3 ─── SERVIDOR\n             ╲          ╱\n              └── R2 ──┘"
			_action_a.text = "Editar manualmente\na rota estática"
			_action_b.text = "Aguardar OSPF\nconvergir por R2"
			_status.text = "O enlace principal falhou. Escolha a reação automática correta."
		2:
			_topology.text = "CLIENTE ─── R1 ─── R2 ─── R3 ─── SERVIDOR\n\nROTA ALTERNATIVA ATIVA"
			_action_a.hide()
			_action_b.hide()
			_status.text = "OSPF convergiu: os roteadores anunciaram a falha e instalaram o caminho alternativo."
			_status.add_theme_color_override("font_color", Color("7ff0a4"))

func _choose(choice: int) -> void:
	if _phase == 0:
		if choice != 1:
			_status.text = "A rota estática funciona, mas não anuncia nem descobre automaticamente o caminho alternativo."
			_status.add_theme_color_override("font_color", Color("ff8a8a"))
			return
		_phase = 1
		_status.add_theme_color_override("font_color", Color("d5f2ff"))
		_show_phase()
		return
	if _phase == 1:
		if choice != 1:
			_status.text = "Isso exigiria intervenção humana. Em uma topologia dinâmica, deixe o protocolo recalcular a rota."
			_status.add_theme_color_override("font_color", Color("ff8a8a"))
			return
		_phase = 2
		_show_phase()
		mentor_message.emit("A rede convergiu pelo caminho alternativo sem configuração manual.", 3.5)
		completed.emit()
