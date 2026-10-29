extends Control

signal completed
signal mentor_message(message: String, duration: float)

const QUERIES := [
	{"site": "portal.ifrn.edu.br", "tld": "TLD .BR", "authority": "AUTORITATIVO\nIFRN.EDU.BR"},
	{"site": "www.exemplo.com", "tld": "TLD .COM", "authority": "AUTORITATIVO\nEXEMPLO.COM"},
	{"site": "docs.rede.net", "tld": "TLD .NET", "authority": "AUTORITATIVO\nREDE.NET"}
]
const DECOY_STATIONS := [
	"CACHE DNS", "TLD .ORG", "TLD .GOV", "AUTORITATIVO\nOUTRA.NET",
	"AUTORITATIVO\nEXEMPLO.ORG", "SERVIDOR\nESPELHO", "ZONA\nINEXISTENTE"
]

var _step := 0
var _selected_track := 0
var _busy := false
var _train_progress := -0.35
var _query: Dictionary
var _route: Array[String] = []
var _stations: Array[String] = []
var _status: Label
var _lever_status: Label
var _travel: Label
var _send_button: Button
var _title: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clip_contents = true
	_setup_round()
	_build_ui()
	queue_redraw()

func mentor_intro() -> String:
	return "Há cinco ramais: quatro fazem parte da consulta e um é um desvio. Eles mudam de lugar a cada rodada: leia os rótulos e guie o pacote-trem do servidor raiz ao TLD, servidor autoritativo e site."

func _setup_round() -> void:
	_query = QUERIES.pick_random()
	_route = [
		"ROOT SERVER",
		String(_query["tld"]),
		String(_query["authority"]),
		"SITE\n" + String(_query["site"])
	]
	_stations = _route.duplicate()
	var decoys: Array[String] = []
	for station in DECOY_STATIONS:
		if station not in _route:
			decoys.append(station)
	decoys.shuffle()
	for index in 1:
		_stations.append(decoys[index])
	_stations.shuffle()
	_selected_track = randi_range(0, _stations.size() - 1)
	if _title != null:
		_title.text = "TRILHOS DNS: " + String(_query["site"])

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("07131a")
	# O tabuleiro é desenhado pelo Control pai; este fundo precisa ficar atrás dele.
	background.show_behind_parent = true
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	_title = Label.new()
	_title.position = Vector2(18, 13)
	_title.size = Vector2(644, 25)
	_title.text = "TRILHOS DNS: " + String(_query["site"])
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 15)
	_title.add_theme_color_override("font_color", Color("40e4ff"))
	add_child(_title)
	_travel = Label.new()
	_travel.position = Vector2(24, 239)
	_travel.size = Vector2(632, 22)
	_travel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_travel.text = "PACOTE-TREM PRONTO NA ESTAÇÃO"
	_travel.add_theme_font_size_override("font_size", 14)
	add_child(_travel)
	_lever_status = Label.new()
	_lever_status.position = Vector2(24, 268)
	_lever_status.size = Vector2(632, 22)
	_lever_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lever_status.add_theme_font_size_override("font_size", 15)
	_lever_status.add_theme_color_override("font_color", Color("ffd45b"))
	add_child(_lever_status)
	var controls := HBoxContainer.new()
	controls.position = Vector2(143, 300)
	controls.size = Vector2(394, 46)
	controls.add_theme_constant_override("separation", 8)
	add_child(controls)
	var left := Button.new()
	left.text = "◀ Alavanca"
	left.custom_minimum_size = Vector2(125, 46)
	left.add_theme_font_size_override("font_size", 12)
	left.pressed.connect(func() -> void: _move_lever(-1))
	controls.add_child(left)
	_send_button = Button.new()
	_send_button.text = "LIBERAR"
	_send_button.custom_minimum_size = Vector2(118, 46)
	_send_button.add_theme_font_size_override("font_size", 12)
	_send_button.pressed.connect(_send_train)
	controls.add_child(_send_button)
	var right := Button.new()
	right.text = "Alavanca ▶"
	right.custom_minimum_size = Vector2(125, 46)
	right.add_theme_font_size_override("font_size", 12)
	right.pressed.connect(func() -> void: _move_lever(1))
	controls.add_child(right)
	_status = Label.new()
	_status.position = Vector2(32, 356)
	_status.size = Vector2(616, 45)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 13)
	add_child(_status)
	_update_controls()

func _move_lever(direction: int) -> void:
	if _busy:
		return
	_selected_track = posmod(_selected_track + direction, _stations.size())
	_status.text = "Alavanca reposicionada. Confira o destino antes de liberar o trem."
	_status.add_theme_color_override("font_color", Color("d5f2ff"))
	_update_controls()
	queue_redraw()

func _send_train() -> void:
	var expected_track := _stations.find(_route[_step])
	if _busy:
		return
	_busy = true
	_send_button.disabled = true
	if _selected_track != expected_track:
		_travel.text = "⚠ PACOTE DESCARRILOU — TIMEOUT DNS"
		_status.text = "Esse trilho não corresponde à próxima etapa da resolução. A consulta expirou; reiniciando do cliente…"
		_status.add_theme_color_override("font_color", Color("ff8a8a"))
		queue_redraw()
		await get_tree().create_timer(1.7).timeout
		_step = 0
		_train_progress = -0.35
		_setup_round()
		_busy = false
		_travel.text = "PACOTE-TREM DE VOLTA AO CLIENTE"
		_update_controls()
		queue_redraw()
		return
	await _travel_to_station(_selected_track)
	_step += 1
	_travel.text = "✓ Trem chegou a %s" % _stations[_selected_track].replace("\n", " ")
	_status.text = "Resposta recebida. Configure o próximo trilho."
	_status.add_theme_color_override("font_color", Color("7ff0a4"))
	queue_redraw()
	if _step == _route.size():
		_travel.text = "✓ ENDEREÇO RESOLVIDO — SITE ENTREGUE"
		_status.text = "A cadeia DNS foi percorrida sem timeout."
		mentor_message.emit("Excelente! Você guiou a consulta do servidor raiz até o servidor autoritativo e o site.", 4.0)
		completed.emit()
		return
	_selected_track = randi_range(0, _stations.size() - 1)
	_busy = false
	_update_controls()

func _travel_to_station(destination: int) -> void:
	_travel.text = "PACOTE-TREM EM MOVIMENTO…"
	var target := float(destination)
	var tween := create_tween()
	var move_train := func(value: float) -> void:
		_train_progress = value
		queue_redraw()
	tween.tween_method(move_train, _train_progress, target, 0.75)
	await tween.finished

func _update_controls() -> void:
	_lever_status.text = "DESTINO ATUAL — RAMAL %s: %s" % [char(65 + _selected_track), _stations[_selected_track].replace("\n", " ")]
	_send_button.disabled = _busy or _step >= _route.size()

func _draw() -> void:
	var viewport := size
	var board := Rect2(20, 55, viewport.x - 40, 166)
	draw_rect(board, Color("0d202b"), true)
	draw_rect(board, Color("215b6b"), false, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(34, 77), "PÁTIO DE RESOLUÇÃO DNS  •  5 RAMAIS", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("74ddea"))
	# Linha-tronco vertical e cinco desvios paralelos: nenhum ramal cruza outro.
	var trunk_x := 112.0
	var first_row := 90.0
	var row_gap := 27.0
	var rail_start := 142.0
	var rail_end := viewport.x - 64.0
	draw_line(Vector2(trunk_x - 4, first_row - 8), Vector2(trunk_x - 4, first_row + row_gap * 4 + 8), Color("a9c1ce"), 2.5)
	draw_line(Vector2(trunk_x + 4, first_row - 8), Vector2(trunk_x + 4, first_row + row_gap * 4 + 8), Color("a9c1ce"), 2.5)
	for sleeper_y in range(int(first_row - 6), int(first_row + row_gap * 4 + 8), 9):
		draw_line(Vector2(trunk_x - 9, sleeper_y), Vector2(trunk_x + 9, sleeper_y), Color("5f7480"), 2.0)
	for index in _stations.size():
		var row_y := first_row + row_gap * index
		var selected := index == _selected_track
		var rail_color := Color("ffd45b") if selected else Color("8198a4")
		# Desvio curto até o ramal e os dois trilhos paralelos.
		draw_line(Vector2(trunk_x, row_y), Vector2(rail_start, row_y), rail_color, 3.0)
		draw_line(Vector2(rail_start, row_y - 3), Vector2(rail_end, row_y - 3), rail_color, 2.0)
		draw_line(Vector2(rail_start, row_y + 3), Vector2(rail_end, row_y + 3), rail_color, 2.0)
		for sleeper_x in range(int(rail_start), int(rail_end), 15):
			draw_line(Vector2(sleeper_x, row_y - 6), Vector2(sleeper_x, row_y + 6), Color("536a75"), 1.5)
		var badge_color := Color("ffd45b") if selected else Color("344a59")
		draw_circle(Vector2(rail_end + 18, row_y), 10.0, badge_color)
		draw_string(ThemeDB.fallback_font, Vector2(rail_end + 11, row_y + 4), char(65 + index), HORIZONTAL_ALIGNMENT_CENTER, 15, 10, Color("07131a"))
		if _stations[index] in _route.slice(0, _step):
			draw_circle(Vector2(rail_start + 8, row_y), 4.0, Color("7ff0a4"))
	var train_y := first_row if _train_progress < 0.0 else first_row + row_gap * _train_progress
	var train_x := trunk_x - 28.0 if _train_progress < 0.0 else trunk_x + 22.0
	# Locomotiva: caldeira, cabine, chaminé, vagão e quatro rodas.
	draw_rect(Rect2(train_x - 36, train_y - 17, 30, 20), Color("376b80"))
	draw_rect(Rect2(train_x - 2, train_y - 22, 34, 25), Color("42e5f2"))
	draw_circle(Vector2(train_x + 32, train_y - 8), 11.0, Color("42e5f2"))
	draw_rect(Rect2(train_x + 20, train_y - 31, 7, 12), Color("d6fbff"))
	draw_rect(Rect2(train_x - 27, train_y - 14, 13, 10), Color("b8f8ff"))
	for wheel_x in [train_x - 26, train_x - 12, train_x + 8, train_x + 28]:
		draw_circle(Vector2(wheel_x, train_y + 6), 6.0, Color("111b25"))
		draw_circle(Vector2(wheel_x, train_y + 6), 2.0, Color("b8f8ff"))
	# Alavanca ao lado da linha-tronco aponta para o ramal atualmente selecionado.
	var lever_y := first_row + row_gap * _selected_track
	draw_circle(Vector2(trunk_x + 18, lever_y), 8.0, Color("ffd45b"))
	draw_line(Vector2(trunk_x + 18, lever_y), Vector2(rail_start - 6, lever_y), Color("ffd45b"), 4.0)
