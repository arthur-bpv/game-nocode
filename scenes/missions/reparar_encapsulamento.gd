extends "res://scenes/missions/network_repair_panel.gd"

const NAMES := ["Dados da aplicação", "Segmento TCP", "Pacote IP", "Quadro Ethernet"]
const NOTES := [
	"Mensagem que será enviada.",
	"Acrescenta informações de transporte.",
	"Acrescenta IPs de origem e destino.",
	"Prepara a transmissão no enlace local.",
]
const HINTS := [
	"Comece com a mensagem original da aplicação.",
	"O segmento TCP deve conter os dados da aplicação.",
	"O pacote IP deve conter o segmento TCP.",
	"O quadro Ethernet deve conter o pacote IP.",
]
const CARD_ORDER := [2, 0, 3, 1]
const LAYER_COLORS := [Color("32636d"), Color("38747b"), Color("43858a"), Color("52a0a1")]

var order: Array[int] = [-1, -1, -1, -1]
var cards: Array[Button] = []
var slots: Array[Button] = []
var send: Button
var clear: Button
var depth := 0
var _sending := false
var _diagram_offset := 0.0
var _diagram: Control
var _editor: VBoxContainer

func _ready() -> void:
	setup("Reparar encapsulamento", "Organize a preparação da mensagem, da aplicação até o enlace.")
	var context := make_label("Relatório de diagnóstico   ·   TCP → IP → Ethernet", 16)
	context.add_theme_color_override("font_color", ACCENT)
	interaction.add_child(context)

	_editor = VBoxContainer.new()
	_editor.add_theme_constant_override("separation", 8)
	interaction.add_child(_editor)
	cards.resize(NAMES.size())
	var choices := _make_grid()
	for index in CARD_ORDER:
		var card := make_button(NAMES[index] + "\n" + NOTES[index])
		card.custom_minimum_size.y = 60
		card.size_flags_horizontal = SIZE_EXPAND_FILL
		card.pressed.connect(_place.bind(index))
		choices.add_child(card)
		cards[index] = card

	var positions := _make_grid()
	for index in NAMES.size():
		var slot := make_button("")
		slot.size_flags_horizontal = SIZE_EXPAND_FILL
		slot.pressed.connect(_remove.bind(index))
		positions.add_child(slot)
		slots.append(slot)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	_editor.add_child(actions)
	send = make_button("Testar envio")
	send.pressed.connect(_test_order)
	actions.add_child(send)
	clear = make_button("Limpar")
	clear.pressed.connect(_clear_order)
	actions.add_child(clear)

	_diagram = Control.new()
	_diagram.custom_minimum_size.y = 226
	_diagram.mouse_filter = MOUSE_FILTER_IGNORE
	_diagram.draw.connect(_draw_layers)
	interaction.add_child(_diagram)
	_diagram.hide()
	_refresh()

func _make_grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	_editor.add_child(grid)
	return grid

func _place(index: int) -> void:
	if _sending or finished or index in order:
		return
	var position := order.find(-1)
	if position >= 0:
		order[position] = index
		_refresh()

func _remove(position: int) -> void:
	if _sending or finished:
		return
	order[position] = -1
	_refresh()

func _clear_order() -> void:
	if _sending or finished:
		return
	order.fill(-1)
	feedback.text = ""
	_refresh()

func _test_order() -> void:
	if send.disabled:
		return
	for position in order.size():
		if order[position] != position:
			SoundEffects.play_error()
			show_feedback("Erro na posição %d — %s" % [position + 1, HINTS[position]], false)
			return
	_sending = true
	_refresh()
	_editor.hide()
	_diagram.show()
	_show_depth(1)
	show_feedback("Acerto — preparando a mensagem para envio.", true)
	SoundEffects.play_correct()
	var animation := create_tween()
	for layer in range(2, NAMES.size() + 1):
		animation.tween_callback(_show_depth.bind(layer)).set_delay(0.23)
	animation.tween_method(_move_diagram, 0.0, 42.0, 0.27)
	animation.tween_callback(_complete_send)

func _complete_send() -> void:
	show_feedback("Concluída — quadro Ethernet enviado.", true)
	finish()

func _refresh() -> void:
	for index in NAMES.size():
		cards[index].disabled = index in order or _sending or finished
		cards[index].modulate.a = 0.0 if index in order else 1.0
		slots[index].disabled = order[index] == -1 or _sending or finished
		var value: String = NAMES[order[index]] if order[index] >= 0 else "Vazio"
		slots[index].text = "%d · %s" % [index + 1, value]
	send.disabled = -1 in order or _sending or finished
	clear.disabled = order.count(-1) == NAMES.size() or _sending or finished

func _show_depth(layer_count: int) -> void:
	depth = layer_count
	_diagram.queue_redraw()

func _move_diagram(offset: float) -> void:
	_diagram_offset = offset
	_diagram.queue_redraw()

func _draw_layers() -> void:
	var font := ThemeDB.fallback_font
	var center_x := _diagram.size.x * 0.5 + _diagram_offset
	for index in range(depth - 1, -1, -1):
		var width := 300.0 + index * 92.0
		var rect := Rect2(center_x - width * 0.5, 84.0 - index * 24.0, width, 42.0 + index * 44.0)
		_diagram.draw_rect(rect, Color("152732"))
		_diagram.draw_rect(rect, LAYER_COLORS[index], false, 2)
		_diagram.draw_string(font, rect.position + Vector2(12, 17), NAMES[index], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)

func restore_completed() -> void:
	if finished:
		return
	finished = true
	order.assign([0, 1, 2, 3])
	_refresh()
	_editor.hide()
	_diagram.show()
	_show_depth(NAMES.size())
	show_feedback("Concluída — quadro Ethernet enviado.", true)
