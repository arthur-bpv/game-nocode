extends "res://scenes/missions/network_repair_panel.gd"

const WireLayer := preload("res://scenes/missions/conecta_camadas_wires.gd")
const JACK_SIZE := Vector2(28, 29)

const OSI_CAMADAS := ["aplicacao", "apresentacao", "sessao", "transporte", "rede", "enlace", "fisica"]
const TCP_CAMADAS := ["aplicacao", "transporte", "internet", "acesso_a_rede"]

const MAPA_OSI_TCP := {
	"aplicacao": "aplicacao",
	"apresentacao": "aplicacao",
	"sessao": "aplicacao",
	"transporte": "transporte",
	"rede": "internet",
	"enlace": "acesso_a_rede",
	"fisica": "acesso_a_rede",
}

const CORES := {
	"aplicacao": Color(0.87, 0.02, 0.02),
	"apresentacao": Color(1.0, 0.57, 0.13),
	"sessao": Color(0.1, 1.0, 0.03),
	"transporte": Color(1.0, 0.07, 0.65),
	"rede": Color(0.64, 0.1, 0.85),
	"enlace": Color(0.17, 0.29, 0.9),
	"fisica": Color(1.0, 0.87, 0.13),
}
const NOMES_CAMADAS := {
	"aplicacao": "Aplicação",
	"apresentacao": "Apresentação",
	"sessao": "Sessão",
	"transporte": "Transporte",
	"rede": "Rede",
	"enlace": "Enlace",
	"fisica": "Física",
	"internet": "Internet",
	"acesso_a_rede": "Acesso à Rede",
}

var _osi_jacks: Dictionary = {}
var _tcp_jacks: Dictionary = {}
var _connected: Dictionary = {}
var _dragging_from := ""
var _drag_pos := Vector2.ZERO
var _board: Control
var _wires: Control

func _ready() -> void:
	setup("Correspondência OSI e TCP/IP", "Arraste cada fio de uma camada OSI até a camada equivalente no TCP/IP.")
	_board = Control.new()
	_board.name = "ConnectionBoard"
	_board.custom_minimum_size = Vector2(680, 276)
	_board.draw.connect(_draw_board)
	_board.gui_input.connect(_handle_board_input)
	interaction.add_child(_board)
	_add_heading("OSI", 16)
	_add_heading("TCP/IP", 470)

	for index in OSI_CAMADAS.size():
		var layer: String = OSI_CAMADAS[index]
		var row_y := 43.0 + 35.0 * index
		_add_label(NOMES_CAMADAS[layer], 16, row_y)
		_osi_jacks[layer] = Rect2(Vector2(220, row_y) - JACK_SIZE * 0.5, JACK_SIZE)
	for index in TCP_CAMADAS.size():
		var layer: String = TCP_CAMADAS[index]
		var row_y := 55.0 + 62.0 * index
		_add_label(NOMES_CAMADAS[layer], 470, row_y)
		_tcp_jacks[layer] = Rect2(Vector2(452, row_y) - JACK_SIZE * 0.5, JACK_SIZE)

	_wires = WireLayer.new()
	_wires.name = "WireLayer"
	_wires.mission = self
	_wires.mouse_filter = MOUSE_FILTER_IGNORE
	_board.add_child(_wires)
	_wires.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	visibility_changed.connect(_cancel_hidden_drag)
	_refresh_wires()

func _add_heading(caption: String, x: float) -> void:
	var heading := _add_label(caption, x, 16, 15)
	heading.add_theme_color_override("font_color", ACCENT)

func _add_label(caption: String, x: float, y: float, font_size: int = 18) -> Label:
	var label := make_label(caption, font_size)
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.position = Vector2(x, y - 12)
	_board.add_child(label)
	return label

func _draw_board() -> void:
	for panel in [Rect2(0, 0, 239, 276), Rect2(436, 0, 244, 276)]:
		_board.draw_rect(panel, Color("101e2b"))
		_board.draw_rect(panel.grow(-1), Color("345461"), false, 1)
	for layer in _osi_jacks:
		var center: Vector2 = _osi_jacks[layer].get_center()
		_board.draw_circle(center, 9, Color("09131c"), true, -1, true)
		_board.draw_arc(center, 8, 0, TAU, 20, CORES[layer], 2, true)
	for jack: Rect2 in _tcp_jacks.values():
		_board.draw_circle(jack.get_center(), 9, Color("09131c"), true, -1, true)
		_board.draw_arc(jack.get_center(), 8, 0, TAU, 20, ACCENT, 2, true)

func _handle_board_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			for layer in _osi_jacks:
				if _osi_jacks[layer].has_point(event.position) and not _connected.has(layer):
					_dragging_from = layer
					_drag_pos = event.position
					_wires.queue_redraw()
					return
		elif not _dragging_from.is_empty():
			var source := _dragging_from
			_dragging_from = ""
			for layer in _tcp_jacks:
				if _tcp_jacks[layer].has_point(event.position):
					_connect_wire(source, layer)
					break
			_refresh_wires()
	elif event is InputEventMouseMotion and not _dragging_from.is_empty():
		_drag_pos = event.position.clamp(Vector2.ZERO, _board.size)
		_wires.queue_redraw()

func _connect_wire(source: String, target: String) -> void:
	if MAPA_OSI_TCP[source] != target:
		SoundEffects.play_error()
		show_feedback("Tente de novo — %s não corresponde a %s." % [NOMES_CAMADAS[source], NOMES_CAMADAS[target]], false)
		return
	_connected[source] = target
	SoundEffects.play_correct()
	if _connected.size() == OSI_CAMADAS.size():
		show_feedback("Missão completa — todas as camadas foram conectadas.", true)
		finish()
	else:
		show_feedback("Acerto — %s → %s." % [NOMES_CAMADAS[source], NOMES_CAMADAS[target]], true)

func _cancel_hidden_drag() -> void:
	if not is_visible_in_tree() and not _dragging_from.is_empty():
		_dragging_from = ""
		_wires.queue_redraw()

func _refresh_wires() -> void:
	_wires.queue_redraw()

func restore_completed() -> void:
	_connected = MAPA_OSI_TCP.duplicate()
	_dragging_from = ""
	if not finished:
		finished = true
		show_feedback("Missão completa — todas as camadas foram conectadas.", true)
	_refresh_wires()
