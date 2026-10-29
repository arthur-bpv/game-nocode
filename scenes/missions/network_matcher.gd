extends Control

signal completed
signal mentor_message(message: String, duration: float)

@export_enum("subnet", "routing", "vlan") var lab_id := "subnet"

const LABS := {
	"subnet": {
		"title": "LABORATÓRIO DE SUB-REDES",
		"intro": "Associe cada setor ao menor bloco de endereços que comporta seus hosts.",
		"items": [
			{"label": "Suporte\n25 hosts", "target": "192.168.1.0/27"},
			{"label": "Engenharia\n50 hosts", "target": "192.168.1.64/26"},
			{"label": "Visitantes\n100 hosts", "target": "192.168.1.128/25"}
		],
		"targets": ["192.168.1.0/27", "192.168.1.64/26", "192.168.1.128/25"]
	},
	"routing": {
		"title": "MESA DE ROTAS",
		"intro": "Associe cada destino à rota mais específica disponível na tabela do roteador.",
		"items": [
			{"label": "Pacote para\n10.20.8.44", "target": "10.20.8.0/24 → R2"},
			{"label": "Pacote para\n10.20.60.9", "target": "10.20.0.0/16 → R1"},
			{"label": "Pacote para\n8.8.8.8", "target": "0.0.0.0/0 → Internet"}
		],
		"targets": ["10.20.8.0/24 → R2", "10.20.0.0/16 → R1", "0.0.0.0/0 → Internet"]
	},
	"vlan": {
		"title": "PATCH PANEL DE VLANs",
		"intro": "Conecte cada dispositivo à VLAN indicada pela política da empresa.",
		"items": [
			{"label": "PC Financeiro\nacesso restrito", "target": "VLAN 10 — Financeiro"},
			{"label": "Notebook visitante\nacesso à internet", "target": "VLAN 30 — Visitantes"},
			{"label": "Impressora do escritório", "target": "VLAN 20 — Operações"}
		],
		"targets": ["VLAN 10 — Financeiro", "VLAN 20 — Operações", "VLAN 30 — Visitantes"]
	}
}

var _lab: Dictionary
var _selected := -1
var _matched := 0
var _source_buttons: Array[Button] = []
var _target_buttons: Array[Button] = []
var _status: Label

func _ready() -> void:
	_lab = LABS[lab_id]
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()

func mentor_intro() -> String:
	return String(_lab["intro"])

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("08151c")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var content := VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 28)
	content.add_theme_constant_override("separation", 14)
	add_child(content)
	var title := Label.new()
	title.text = String(_lab["title"])
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("40e4ff"))
	content.add_child(title)
	var instruction := Label.new()
	instruction.text = "1. Selecione um cartão à esquerda.  2. Conecte-o ao destino correto à direita."
	instruction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(instruction)
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 32)
	content.add_child(columns)
	var sources := VBoxContainer.new()
	sources.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sources.add_theme_constant_override("separation", 10)
	columns.add_child(sources)
	var targets := VBoxContainer.new()
	targets.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	targets.add_theme_constant_override("separation", 10)
	columns.add_child(targets)
	for index in (_lab["items"] as Array).size():
		var button := Button.new()
		button.text = String(_lab["items"][index]["label"])
		button.custom_minimum_size = Vector2(0, 86)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(func() -> void: _select_source(index))
		sources.add_child(button)
		_source_buttons.append(button)
	for index in (_lab["targets"] as Array).size():
		var button := Button.new()
		button.text = String(_lab["targets"][index])
		button.custom_minimum_size = Vector2(0, 86)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(func() -> void: _place_on_target(index))
		targets.add_child(button)
		_target_buttons.append(button)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 15)
	content.add_child(_status)

func _select_source(index: int) -> void:
	if _source_buttons[index].disabled:
		return
	_selected = index
	for button in _source_buttons:
		button.modulate = Color.WHITE
	_source_buttons[index].modulate = Color("40e4ff")
	_status.text = "Cartão selecionado. Escolha o destino."

func _place_on_target(target_index: int) -> void:
	if _selected < 0 or _target_buttons[target_index].disabled:
		return
	var item: Dictionary = _lab["items"][_selected]
	if String(item["target"]) != String(_lab["targets"][target_index]):
		_status.text = "Esse destino não atende ao cartão selecionado. Tente outro."
		_status.add_theme_color_override("font_color", Color("ff8a8a"))
		return
	_source_buttons[_selected].disabled = true
	_source_buttons[_selected].modulate = Color("7ff0a4")
	_target_buttons[target_index].disabled = true
	_target_buttons[target_index].modulate = Color("7ff0a4")
	_matched += 1
	_selected = -1
	_status.text = "Conexão configurada corretamente."
	_status.add_theme_color_override("font_color", Color("7ff0a4"))
	if _matched == _source_buttons.size():
		mentor_message.emit("Laboratório concluído!", 3.0)
		completed.emit()
