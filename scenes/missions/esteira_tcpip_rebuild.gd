extends Control

## Linha TCP/IP física, construída separadamente da atividade antiga.
## As bancadas são abertas pelas cabines, mas o pacote e a linha permanecem no mapa.

signal completed
signal mentor_message(message: String, duration: float)
signal mentor_context(message: String)

## Sprites em pixel art gerados no PixelLab para a linha e para o pacote.
const FACTORY_ART_EXTERNAL := "C:/Users/ifrn/Documents/ChatGPT/game-nocode/assets/sprites/esteira_tcpip_u_pixel_detailed.png"
const PACKET_ART := preload("res://assets/sprites/Pacote.png")
const ROUTING_CHALLENGE_GENERATOR := preload("res://scenes/missions/routing_challenge_generator.gd")

const STATIONS := [
	{"id": "application", "title": "APLICAÇÃO", "color": Color("ef4a4a")},
	{"id": "transport", "title": "TRANSPORTE", "color": Color("ff9c35")},
	{"id": "internet", "title": "INTERNET", "color": Color("d65ce3")},
	{"id": "access", "title": "ACESSO À REDE", "color": Color("3f8cff")},
]

@export var map_offset := Vector2(-330, -250)
@export var map_scale := 0.86
@export var factory_center := Vector2(390, 278)
@export var factory_size := Vector2(550, 550)
# Centros dos visores superiores das quatro cabines no sprite U:
# aplicação → transporte → internet → acesso. Estes pontos mantêm o pacote
# centralizado dentro da cabine quando ela o recebe.
@export var station_positions := [Vector2(205, 103), Vector2(205, 400), Vector2(570, 400), Vector2(570, 103)]
@export var station_interaction_radius := 96.0
@export_enum("Fácil", "Médio", "Difícil") var routing_difficulty := "Médio"

var _stage := 0
var _nearby_station := -1
var _world: Control
var _packet: Panel
var _packet_bands: HBoxContainer
var _station_indicators: Array[Control] = []
var _challenge: CanvasLayer
var _installed_headers: Array[String] = []
var _drag_piece: Label
var _drag_home := Vector2.ZERO
var _drag_offset := Vector2.ZERO
var _slots: Array[Panel] = []
var _slot_targets: Array[String] = []
var _slot_values: Array[String] = []
var _used_pieces: Dictionary = {}
var _used_homes: Dictionary = {}
var _transport_protocol := ""
var _route: Array[String] = []
var _routing_challenge: Dictionary = {}
var _routing_buttons: Dictionary = {}
var _routing_lines: Dictionary = {}
var _application_recipe: Dictionary = {}
var _application_message := "GET /index.html HTTP/1.1"

func _ready() -> void:
	name = "LinhaMontagemTCPIP"
	size = Vector2(780, 570)
	position = map_offset
	scale = Vector2.ONE * map_scale
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_factory_world()
	emit_signal("mentor_context", "A linha TCP/IP monta um único pacote em quatro etapas práticas.")
	emit_signal("mentor_message", "Aproxime-se da cabine de Aplicação e pressione [E] para iniciar a montagem.", 5.0)

func mentor_intro() -> String:
	return "Esta é a linha de montagem TCP/IP. Monte um pacote passando pelas quatro cabines."

func _process(_delta: float) -> void:
	if _challenge != null:
		return
	var player := _find_player_canvas_item()
	if player == null or _world == null:
		return
	var player_position := _world.get_global_transform_with_canvas().affine_inverse() * player.get_global_transform_with_canvas().origin
	var nearest := -1
	var shortest_distance := station_interaction_radius
	for index in STATIONS.size():
		var distance := player_position.distance_to(station_positions[index])
		if distance <= shortest_distance:
			shortest_distance = distance
			nearest = index
	if nearest == _nearby_station:
		return
	_nearby_station = nearest
	if _nearby_station >= 0:
		_announce_nearby_station(_nearby_station)

func _find_player_canvas_item() -> CanvasItem:
	for group_name in ["player", "players", "Player"]:
		var candidate := get_tree().get_first_node_in_group(group_name)
		if candidate is CanvasItem:
			return candidate as CanvasItem
	return null

func _announce_nearby_station(index: int) -> void:
	var station: Dictionary = STATIONS[index]
	var message := "Você se aproximou da cabine de %s." % station.title.capitalize()
	if index == _stage:
		message += " Pressione [E] para iniciar esta etapa."
	elif index < _stage:
		message += " Esta etapa já foi concluída."
	else:
		message += " Conclua a cabine atual antes de usá-la."
	emit_signal("mentor_message", message, 3.6)

func _try_interact_with_nearby_station() -> void:
	if _nearby_station < 0:
		return
	if _nearby_station == _stage:
		_open_station(_nearby_station)
	else:
		_announce_nearby_station(_nearby_station)

func _build_factory_world() -> void:
	_world = Control.new()
	_world.name = "FactoryWorld"
	_world.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_world.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_world)

	var factory := TextureRect.new()
	factory.name = "LinhaU"
	factory.position = factory_center - factory_size * 0.5
	factory.size = factory_size
	factory.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	factory.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	factory.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	factory.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var image := Image.load_from_file(FACTORY_ART_EXTERNAL)
	if image != null and not image.is_empty():
		factory.texture = ImageTexture.create_from_image(image)
	else:
		factory.texture = _make_fallback_factory_texture()
	_world.add_child(factory)

	for index in STATIONS.size():
		_create_station(index)
	_create_packet()
	_create_caption()

func _make_fallback_factory_texture() -> ImageTexture:
	var image := Image.create(512, 512, false, Image.FORMAT_RGBA8)
	image.fill(Color("07152400"))
	var rail := Color("17334f")
	var glow := Color("17e8ef")
	for x in range(32, 88):
		for y in range(40, 442):
			image.set_pixel(x, y, rail)
	for x in range(424, 480):
		for y in range(40, 442):
			image.set_pixel(x, y, rail)
	for x in range(55, 456):
		for y in range(400, 464):
			image.set_pixel(x, y, rail)
	for point in [Vector2i(104, 92), Vector2i(105, 300), Vector2i(307, 300), Vector2i(307, 92)]:
		for x in range(point.x, point.x + 104):
			for y in range(point.y, point.y + 84):
				image.set_pixel(x, y, Color("24445f"))
		for x in range(point.x + 12, point.x + 92):
			image.set_pixel(x, point.y + 10, glow)
	return ImageTexture.create_from_image(image)

func _create_station(index: int) -> void:
	var station: Dictionary = STATIONS[index]
	var button := Button.new()
	button.name = "Station_%s" % station.id
	button.position = station_positions[index] - Vector2(56, 32)
	button.size = Vector2(112, 64)
	# A cabine faz parte do sprite da fábrica. Este botão é uma área de interação
	# transparente: assim a arte continua visível em vez de virar um painel genérico.
	button.text = ""
	button.flat = true
	button.tooltip_text = ""
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.disabled = true
	_world.add_child(button)
	_create_station_indicator(index)

func _create_station_indicator(index: int) -> void:
	# O indicador substitui o pacote visível dentro da cabine: ele aponta qual
	# estação está recebendo o pacote, sem desenhar nenhuma película extra sobre a arte.
	var indicator := Panel.new()
	indicator.name = "IndicadorPacote_%s" % STATIONS[index].id
	indicator.position = station_positions[index] + Vector2(-52, -62)
	indicator.size = Vector2(104, 25)
	indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	indicator.z_index = 18
	indicator.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color("10263a")
	style.border_color = Color("20dce5")
	style.set_border_width_all(2)
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	indicator.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.text = "PACOTE  ▼"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color("d8ffff"))
	label.add_theme_color_override("font_outline_color", Color("07101c"))
	label.add_theme_constant_override("outline_size", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	indicator.add_child(label)
	_world.add_child(indicator)
	_station_indicators.append(indicator)

func _station_style(color: Color, dim: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(color.r, color.g, color.b, 0.10) if not dim else Color(0, 0, 0, 0)
	box.border_color = Color(color.r, color.g, color.b, 0.62) if not dim else Color(0, 0, 0, 0)
	box.set_border_width_all(1 if not dim else 0)
	box.corner_radius_top_left = 7
	box.corner_radius_top_right = 7
	box.corner_radius_bottom_left = 7
	box.corner_radius_bottom_right = 7
	box.shadow_color = Color("02060b")
	box.shadow_size = 2
	return box

func _create_packet() -> void:
	_packet = Panel.new()
	_packet.name = "PacoteEmMontagem"
	_packet.size = Vector2(46, 34)
	_packet.position = _packet_target(0)
	# Dentro da cabine o pacote fica oculto; o indicador acima dela mostra em qual
	# estação ele está. Ele aparece somente durante o deslocamento pela esteira.
	_packet.z_index = 8
	_packet.visible = false
	_packet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_packet.add_theme_stylebox_override("panel", _packet_style())
	_world.add_child(_packet)
	var visual := TextureRect.new()
	visual.position = Vector2(3, 0)
	visual.size = Vector2(40, 28)
	visual.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	visual.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visual.texture = PACKET_ART
	_packet.add_child(visual)
	_refresh_packet()
	_refresh_station_indicators()

func _packet_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0)
	box.border_color = Color(0, 0, 0, 0)
	box.set_border_width_all(0)
	return box

func _packet_target(index: int) -> Vector2:
	return _packet_point(station_positions[index])

func _packet_point(center: Vector2) -> Vector2:
	return center - _packet.size * 0.5

func _packet_path(from_station: int, to_station: int) -> Array[Vector2]:
	# A ligação entre as duas cabines de baixo não é uma reta: o pacote desce até
	# o centro dos roletes, percorre a esteira horizontal e só então sobe ao visor.
	var path: Array[Vector2] = []
	if from_station == 1 and to_station == 2:
		var belt_y := 444.0
		path.append(_packet_point(Vector2(station_positions[1].x, belt_y)))
		path.append(_packet_point(Vector2(station_positions[2].x, belt_y)))
	path.append(_packet_target(to_station))
	return path

func _make_packet_texture() -> ImageTexture:
	var image := Image.create(32, 22, false, Image.FORMAT_RGBA8)
	image.fill(Color("182e55"))
	for x in range(2, 30):
		image.set_pixel(x, 3, Color("1ce5ef"))
		image.set_pixel(x, 18, Color("28436e"))
	return ImageTexture.create_from_image(image)

func _create_caption() -> void:
	var caption := Label.new()
	caption.position = Vector2(250, 520)
	caption.size = Vector2(280, 24)
	caption.text = "LINHA DE MONTAGEM TCP/IP"
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 13)
	caption.add_theme_color_override("font_color", Color("76f8fb"))
	caption.add_theme_color_override("font_outline_color", Color("07101c"))
	caption.add_theme_constant_override("outline_size", 3)
	_world.add_child(caption)

func _refresh_packet() -> void:
	_packet.tooltip_text = "Pacote: " + ("vazio" if _installed_headers.is_empty() else ", ".join(_installed_headers))

func _refresh_station_indicators() -> void:
	for index in _station_indicators.size():
		_station_indicators[index].visible = index == _stage and _stage < STATIONS.size()

func _open_station(index: int) -> void:
	if index != _stage or _challenge != null:
		return
	match STATIONS[index].id:
		"application": _build_application_game()
		"transport": _build_transport_game()
		"internet": _build_internet_game()
		"access": _build_access_game()

func _complete_current_stage(message: String) -> void:
	_close_challenge()
	_installed_headers.append(STATIONS[_stage].title)
	_stage += 1
	_refresh_packet()
	emit_signal("mentor_message", message, 4.0)
	if _stage < STATIONS.size():
		for indicator in _station_indicators:
			indicator.visible = false
		var tween := create_tween()
		_packet.z_index = 20
		_packet.visible = true
		var path := _packet_path(_stage - 1, _stage)
		var segment_duration := 0.95 / float(path.size())
		for point in path:
			tween.tween_property(_packet, "position", point, segment_duration).set_trans(Tween.TRANS_SINE)
		tween.tween_callback(func() -> void:
			_packet.z_index = 8
			_packet.visible = false
			_refresh_station_indicators()
			emit_signal("mentor_message", "Pacote chegou à próxima cabine. Aproxime-se dela e pressione [E] para continuar.", 4.0)
		)
	else:
		_packet.visible = false
		_refresh_station_indicators()
		_finish_factory()

func _finish_factory() -> void:
	emit_signal("mentor_context", "Encapsulamento concluído: Aplicação → Transporte → Internet → Acesso à rede.")
	emit_signal("mentor_message", "Pacote totalmente encapsulado e enviado ao destino!", 5.0)
	completed.emit()

func _make_challenge(title: String, instruction: String, accent: Color) -> VBoxContainer:
	_challenge = CanvasLayer.new()
	_challenge.name = "Bancada"
	_challenge.layer = 80
	add_child(_challenge)
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.03, 0.06, 0.82)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_challenge.add_child(shade)
	var panel := PanelContainer.new()
	panel.position = Vector2(160, 72)
	panel.size = Vector2(640, 470)
	panel.add_theme_stylebox_override("panel", _window_style(accent))
	_challenge.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var heading := Label.new()
	heading.text = title
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 24)
	heading.add_theme_color_override("font_color", accent.lightened(0.2))
	box.add_child(heading)
	var helper := Label.new()
	helper.text = instruction
	helper.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	helper.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	helper.add_theme_font_size_override("font_size", 14)
	helper.add_theme_color_override("font_color", Color("d8eff4"))
	box.add_child(helper)
	return box

func _window_style(accent: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("0a1623")
	box.border_color = accent
	box.set_border_width_all(3)
	box.corner_radius_top_left = 12
	box.corner_radius_top_right = 12
	box.corner_radius_bottom_left = 12
	box.corner_radius_bottom_right = 12
	box.content_margin_left = 26
	box.content_margin_right = 26
	box.content_margin_top = 20
	box.content_margin_bottom = 20
	return box

func _make_slot(placeholder: String) -> Panel:
	var slot := Panel.new()
	slot.custom_minimum_size = Vector2(158, 60)
	slot.add_theme_stylebox_override("panel", _slot_style())
	var label := Label.new()
	label.name = "Text"
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.text = placeholder
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color("7e9ba8"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(label)
	slot.gui_input.connect(_slot_input.bind(slot))
	return slot

func _slot_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("07111c")
	box.border_color = Color("36576b")
	box.set_border_width_all(2)
	box.corner_radius_top_left = 6
	box.corner_radius_top_right = 6
	box.corner_radius_bottom_left = 6
	box.corner_radius_bottom_right = 6
	return box

func _make_action_button(text: String, accent: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(240, 44)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_stylebox_override("normal", _station_style(accent, false))
	button.add_theme_stylebox_override("hover", _station_style(accent.lightened(0.16), false))
	return button

func _add_close_hint(box: VBoxContainer) -> void:
	var hint := Label.new()
	hint.text = "ESC fecha a bancada sem perder a etapa."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color("74909e"))
	box.add_child(hint)

func _close_challenge() -> void:
	if _challenge != null:
		_challenge.queue_free()
		_challenge = null
	_drag_piece = null
	_used_pieces.clear()
	_used_homes.clear()

func _input(event: InputEvent) -> void:
	if _drag_piece != null:
		if event is InputEventMouseMotion:
			_drag_piece.global_position = event.position - _drag_offset
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_finish_drag(event.position)
	if event.is_action_pressed("ui_cancel") and _challenge != null:
		_close_challenge()
	if event.is_action_pressed("interact", false) and _challenge == null:
		_try_interact_with_nearby_station()

func _make_piece(text: String, accent: Color) -> Label:
	var piece := Label.new()
	piece.text = text
	piece.custom_minimum_size = Vector2(118, 46)
	piece.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	piece.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	piece.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	piece.add_theme_font_size_override("font_size", 12)
	piece.add_theme_color_override("font_color", Color("f4ffff"))
	piece.add_theme_stylebox_override("normal", _piece_style(accent))
	piece.mouse_filter = Control.MOUSE_FILTER_STOP
	piece.gui_input.connect(_piece_input.bind(piece))
	return piece

func _piece_style(accent: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = accent.darkened(0.48)
	box.border_color = accent.lightened(0.24)
	box.set_border_width_all(2)
	box.corner_radius_top_left = 5
	box.corner_radius_top_right = 5
	box.corner_radius_bottom_left = 5
	box.corner_radius_bottom_right = 5
	return box

func _piece_input(event: InputEvent, piece: Label) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_drag_piece = piece
		_drag_home = piece.global_position
		_drag_offset = get_viewport().get_mouse_position() - piece.global_position
		piece.z_index = 20
		get_viewport().set_input_as_handled()

func _finish_drag(mouse_position: Vector2) -> void:
	if _drag_piece == null:
		return
	var placed := false
	for index in _slots.size():
		var slot := _slots[index]
		if Rect2(slot.global_position, slot.size).has_point(mouse_position) and _slot_values[index].is_empty():
			_slot_values[index] = _drag_piece.text
			var text := slot.get_node("Text") as Label
			text.text = _drag_piece.text
			text.add_theme_color_override("font_color", Color("f4ffff"))
			_used_pieces[index] = _drag_piece
			_used_homes[index] = _drag_home
			_drag_piece.hide()
			placed = true
			break
	if not placed:
		_drag_piece.global_position = _drag_home
	_drag_piece.z_index = 0
	_drag_piece = null
	var solved := _slot_values == _slot_targets
	if _stage == 1 and _transport_protocol == "UDP":
		solved = not _slot_values.has("")
	if solved:
		if _stage == 0:
			_complete_current_stage("Mensagem HTTP criada e inserida no pacote.")
		elif _stage == 1:
			var ack := _challenge.find_child("TransportAction", true, false) as Button
			if ack != null:
				ack.disabled = false
		elif _stage == 3:
			_complete_current_stage("Quadro Ethernet montado. O pacote está pronto para transmissão local.")

func _slot_input(event: InputEvent, slot: Panel) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	var index := _slots.find(slot)
	if index < 0 or _slot_values[index].is_empty():
		return
	var piece := _used_pieces.get(index) as Label
	if is_instance_valid(piece):
		piece.show()
		piece.global_position = _used_homes.get(index, piece.global_position)
	_slot_values[index] = ""
	var text := slot.get_node("Text") as Label
	text.text = "solte aqui"
	text.add_theme_color_override("font_color", Color("7e9ba8"))
	_used_pieces.erase(index)
	_used_homes.erase(index)
	var action := _challenge.find_child("TransportAction", true, false) as Button
	if action != null:
		action.disabled = true

func _build_application_game() -> void:
	var recipes := [
		{"instruction": "Monte a solicitação para abrir a página inicial do servidor.", "target": ["GET", "/index.html", "HTTP/1.1"], "pieces": ["GET", "POST", "/index.html", "/login", "HTTP/1.1", "DNS"], "payload": "GET /index.html HTTP/1.1"},
		{"instruction": "Monte a solicitação para enviar dados de acesso ao servidor.", "target": ["POST", "/login", "HTTP/1.1"], "pieces": ["GET", "POST", "/index.html", "/login", "HTTP/1.1", "DNS"], "payload": "POST /login HTTP/1.1"},
		{"instruction": "Monte uma consulta DNS para encontrar o servidor do laboratório.", "target": ["DNS", "servidor.lab", "A"], "pieces": ["DNS", "A", "AAAA", "servidor.lab", "cliente.lab", "GET"], "payload": "DNS servidor.lab A"},
	]
	var rng := ChallengeSession.make_rng(&"esteira_tcpip/application", _stage)
	_application_recipe = ChallengeSession.choose_unused(&"esteira_tcpip/application/recipe", recipes, rng)
	_application_message = String(_application_recipe.get("payload", "GET /index.html HTTP/1.1"))
	var box := _make_challenge("CABINE 1 — MONTADOR DE MENSAGENS", String(_application_recipe.get("instruction", "Monte a mensagem.")), STATIONS[0].color)
	_slot_targets.clear()
	for value in Array(_application_recipe.get("target", [])):
		_slot_targets.append(String(value))
	_slot_values = ["", "", ""]
	_used_pieces.clear()
	_used_homes.clear()
	_slots.clear()
	var slots_row := HBoxContainer.new()
	slots_row.alignment = BoxContainer.ALIGNMENT_CENTER
	slots_row.custom_minimum_size.y = 76
	box.add_child(slots_row)
	for _target in _slot_targets:
		var slot := _make_slot("solte aqui")
		slots_row.add_child(slot)
		_slots.append(slot)
	var pieces_row := HBoxContainer.new()
	pieces_row.alignment = BoxContainer.ALIGNMENT_CENTER
	pieces_row.add_theme_constant_override("separation", 10)
	box.add_child(pieces_row)
	var pieces := ChallengeSession.shuffled(&"esteira_tcpip/application/pieces", Array(_application_recipe.get("pieces", [])), _stage)
	for text in pieces:
		pieces_row.add_child(_make_piece(String(text), STATIONS[0].color))
	_add_close_hint(box)

func _build_access_game() -> void:
	var box := _make_challenge("CABINE 4 — BANCADA ETHERNET", "Monte o quadro local: MAC de destino, MAC de origem e dados IPv4 vindos da camada Internet.", STATIONS[3].color)
	var rng := ChallengeSession.make_rng(&"esteira_tcpip/access", _stage)
	var destination_ip := String(_routing_challenge.get("destination_ip", "203.0.113.42"))
	var destination_mac := "MAC DEST\n%02X:%02X:%02X:%02X:%02X:%02X" % [rng.randi_range(0, 255), rng.randi_range(0, 255), rng.randi_range(0, 255), rng.randi_range(0, 255), rng.randi_range(0, 255), rng.randi_range(0, 255)]
	var source_mac := "MAC ORIG\n02:%02X:%02X:%02X:%02X:%02X" % [rng.randi_range(0, 255), rng.randi_range(0, 255), rng.randi_range(0, 255), rng.randi_range(0, 255), rng.randi_range(0, 255)]
	_slot_targets = [destination_mac, source_mac, "DADOS IPv4\n%s" % destination_ip]
	_slot_values = ["", "", ""]
	_used_pieces.clear()
	_used_homes.clear()
	_slots.clear()
	var slots_row := HBoxContainer.new()
	slots_row.alignment = BoxContainer.ALIGNMENT_CENTER
	slots_row.custom_minimum_size.y = 88
	box.add_child(slots_row)
	for _target in _slot_targets:
		var slot := _make_slot("encaixe\naqui")
		slots_row.add_child(slot)
		_slots.append(slot)
	var pieces_row := HBoxContainer.new()
	pieces_row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(pieces_row)
	var shuffled_access_pieces: Array = ChallengeSession.shuffled(&"esteira_tcpip/access/pieces", _slot_targets, _stage)
	for piece_text in shuffled_access_pieces:
		pieces_row.add_child(_make_piece(String(piece_text), STATIONS[3].color))
	_add_close_hint(box)

func _build_transport_game() -> void:
	var box := _make_challenge("CABINE 2 — ORGANIZADOR DE SEGMENTOS", "Escolha um trilho: TCP exige segmentos ordenados e confirmação; UDP envia os datagramas diretamente.", STATIONS[1].color)
	var choice_row := HBoxContainer.new()
	choice_row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(choice_row)
	var shuffled_protocols: Array = ChallengeSession.shuffled(&"esteira_tcpip/transport/protocols", ["TCP", "UDP"], _stage)
	for protocol in shuffled_protocols:
		var choice := _make_action_button(protocol + (" — ORDENAR + ACK" if protocol == "TCP" else " — ENVIO DIRETO"), STATIONS[1].color)
		choice.pressed.connect(_select_transport_protocol.bind(protocol, box))
		choice_row.add_child(choice)
	_add_close_hint(box)

func _select_transport_protocol(protocol: String, box: VBoxContainer) -> void:
	_transport_protocol = protocol
	_used_pieces.clear()
	_used_homes.clear()
	for child in box.get_children().duplicate():
		if child is HBoxContainer or child.name == "TransportAction":
			child.queue_free()
	var status := Label.new()
	status.text = "Trilho %s: os dados da Aplicação foram divididos em segmentos." % protocol
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(status)
	_slot_targets = _split_application_message(_application_message, 3)
	_slot_values = ["", "", ""]
	_slots.clear()
	var slots_row := HBoxContainer.new()
	slots_row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(slots_row)
	for _target in _slot_targets:
		var slot := _make_slot("SEQ ?")
		slots_row.add_child(slot)
		_slots.append(slot)
	var pieces_row := HBoxContainer.new()
	pieces_row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(pieces_row)
	for text in ChallengeSession.shuffled(&"esteira_tcpip/transport/segments", _slot_targets, _stage):
		pieces_row.add_child(_make_piece(String(text), STATIONS[1].color))
	var action := _make_action_button("CONFIRMAR ACK" if protocol == "TCP" else "DESPACHAR DATAGRAMAS", STATIONS[1].color)
	action.name = "TransportAction"
	action.disabled = true
	action.pressed.connect(_finish_transport)
	box.add_child(action)
	_add_close_hint(box)

func _split_application_message(message: String, segment_count: int) -> Array[String]:
	var segments: Array[String] = []
	var length: int = message.length()
	var step: int = maxi(1, ceili(float(length) / float(segment_count)))
	for index in segment_count:
		var start: int = index * step
		if start >= length:
			break
		segments.append(message.substr(start, mini(step, length - start)))
	return segments

func _finish_transport() -> void:
	var ready := _slot_values == _slot_targets
	if _transport_protocol == "UDP":
		ready = not _slot_values.has("")
	if ready:
		var detail := "TCP com números de sequência e ACK" if _transport_protocol == "TCP" else "UDP com datagramas enviados diretamente"
		_complete_current_stage("%s foi adicionado ao pacote." % detail)

func _build_internet_game() -> void:
	var routing_rng := ChallengeSession.make_rng(&"esteira_tcpip/routing", _stage)
	var seed_value := int(routing_rng.randi())
	var generator := ROUTING_CHALLENGE_GENERATOR.new()
	_routing_challenge = generator.generate(seed_value, routing_difficulty)
	_routing_buttons.clear()
	_routing_lines.clear()
	var destination_ip := String(_routing_challenge.get("destination_ip", "203.0.113.42"))
	var destination_network := String(_routing_challenge.get("destination_network", "203.0.113.0/24"))
	var box := _make_challenge("CABINE 3 — CENTRAL DE ROTEAMENTO", "Destino: %s. Consulte a tabela, selecione o próximo salto e construa uma rota disponível." % destination_ip, STATIONS[2].color)

	var content := HBoxContainer.new()
	content.custom_minimum_size = Vector2(0, 252)
	content.add_theme_constant_override("separation", 18)
	box.add_child(content)
	var topology := Control.new()
	topology.name = "RoutingTopology"
	topology.custom_minimum_size = Vector2(380, 250)
	topology.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topology.clip_contents = true
	content.add_child(topology)
	_build_routing_topology(topology)

	var table_panel := PanelContainer.new()
	table_panel.custom_minimum_size = Vector2(188, 250)
	table_panel.add_theme_stylebox_override("panel", _slot_style())
	content.add_child(table_panel)
	var table := VBoxContainer.new()
	table.add_theme_constant_override("separation", 5)
	table_panel.add_child(table)
	var table_title := Label.new()
	table_title.text = "TABELA DE ROTEAMENTO"
	table_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	table_title.add_theme_font_size_override("font_size", 12)
	table_title.add_theme_color_override("font_color", STATIONS[2].color.lightened(0.25))
	table.add_child(table_title)
	var seed_label := Label.new()
	seed_label.text = "SEED: %s · %s" % [seed_value, routing_difficulty]
	seed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	seed_label.add_theme_font_size_override("font_size", 9)
	seed_label.add_theme_color_override("font_color", Color("74909e"))
	table.add_child(seed_label)
	var network_label := Label.new()
	network_label.text = "DESTINO: %s" % destination_network
	network_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	network_label.add_theme_font_size_override("font_size", 11)
	network_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	table.add_child(network_label)
	for row_data in _routing_challenge.get("table_rows", []):
		var row := Label.new()
		row.text = "%s  →  %s" % [String(row_data.get("router", "")), String(row_data.get("next_hop", ""))]
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_theme_font_size_override("font_size", 13)
		row.add_theme_color_override("font_color", Color("d8eff4"))
		table.add_child(row)

	var route_label := Label.new()
	route_label.name = "RouteLabel"
	route_label.text = "ROTA: ORIGEM"
	route_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	route_label.add_theme_font_size_override("font_size", 16)
	box.add_child(route_label)
	var feedback := Label.new()
	feedback.name = "RouteFeedback"
	feedback.text = "Clique em um roteador conectado ao atual. Links tracejados estão indisponíveis."
	feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback.add_theme_font_size_override("font_size", 12)
	feedback.add_theme_color_override("font_color", Color("8faab9"))
	box.add_child(feedback)
	var undo := _make_action_button("DESFAZER ÚLTIMO SALTO", STATIONS[2].color)
	undo.custom_minimum_size = Vector2(220, 34)
	undo.pressed.connect(_undo_routing_step)
	box.add_child(undo)
	_route = ["ORIGEM"]
	_add_close_hint(box)

func _build_routing_topology(topology: Control) -> void:
	var positions: Dictionary = {}
	for node_data in _routing_challenge.get("nodes", []):
		positions[String(node_data.get("id", ""))] = node_data.get("position", Vector2.ZERO)
	for link_data in _routing_challenge.get("links", []):
		var from_id := String(link_data.get("from", ""))
		var to_id := String(link_data.get("to", ""))
		if not positions.has(from_id) or not positions.has(to_id):
			continue
		var line := Line2D.new()
		line.name = "Link_%s_%s" % [from_id, to_id]
		line.points = PackedVector2Array([positions[from_id], positions[to_id]])
		line.width = 4.0
		line.default_color = Color("3a6175") if bool(link_data.get("available", false)) else Color("7a3d4a")
		if not bool(link_data.get("available", false)):
			line.texture_mode = Line2D.LINE_TEXTURE_TILE
		topology.add_child(line)
		_routing_lines[_routing_link_key(from_id, to_id)] = line
	for node_data in _routing_challenge.get("nodes", []):
		var node_id := String(node_data.get("id", ""))
		var node := _make_action_button(String(node_data.get("label", node_id)), STATIONS[2].color)
		node.custom_minimum_size = Vector2(74, 36)
		node.size = Vector2(74, 36)
		var node_position: Vector2 = node_data.get("position", Vector2.ZERO)
		node.position = node_position - node.size * 0.5
		node.disabled = not bool(node_data.get("available", false)) or node_id == "ORIGEM"
		if not bool(node_data.get("available", false)):
			node.text += " ×"
			node.modulate = Color("86616a")
		node.pressed.connect(_pick_router.bind(node_id))
		topology.add_child(node)
		_routing_buttons[node_id] = node

func _routing_link_key(from_id: String, to_id: String) -> String:
	return from_id + "|" + to_id if from_id < to_id else to_id + "|" + from_id

func _routing_has_available_link(from_id: String, to_id: String) -> bool:
	for link_data in _routing_challenge.get("links", []):
		var link_from := String(link_data.get("from", ""))
		var link_to := String(link_data.get("to", ""))
		if (link_from == from_id and link_to == to_id) or (link_from == to_id and link_to == from_id):
			return bool(link_data.get("available", false))
	return false

func _routing_next_hop(router: String) -> String:
	for row_data in _routing_challenge.get("table_rows", []):
		if String(row_data.get("router", "")) == router:
			return String(row_data.get("next_hop", ""))
	return ""

func _pick_router(router: String) -> void:
	if _route.is_empty() or _challenge == null:
		return
	var current: String = _route.back()
	var label := _challenge.find_child("RouteLabel", true, false) as Label
	var feedback := _challenge.find_child("RouteFeedback", true, false) as Label
	if not _routing_has_available_link(current, router):
		if feedback != null:
			feedback.text = "Esse roteador não possui um link disponível a partir de %s." % current
			feedback.add_theme_color_override("font_color", Color("ff7b7b"))
		return
	var next_hop := _routing_next_hop(current)
	if next_hop != router:
		if feedback != null:
			feedback.text = "A tabela de %s indica outro próximo salto. Corrija a rota sem reiniciar." % current
			feedback.add_theme_color_override("font_color", Color("ffbf6b"))
		return
	_route.append(router)
	var line := _routing_lines.get(_routing_link_key(current, router)) as Line2D
	if line != null:
		line.default_color = Color("22e9f1")
		line.width = 6.0
	var node := _routing_buttons.get(router) as Button
	if node != null:
		node.modulate = Color("9fffff")
	if label != null:
		label.text = "ROTA: " + "  →  ".join(_route)
	if router == "DESTINO":
		_complete_current_stage("Rota válida encontrada. IPv4 %s foi inserido no pacote." % String(_routing_challenge.get("destination_ip", "")))
	elif feedback != null:
		feedback.text = "Salto confirmado. Consulte a linha de %s na tabela." % router
		feedback.add_theme_color_override("font_color", Color("8ff4d1"))

func _undo_routing_step() -> void:
	if _route.size() <= 1 or _challenge == null:
		return
	var removed: String = _route.pop_back()
	var previous: String = _route.back()
	var line := _routing_lines.get(_routing_link_key(previous, removed)) as Line2D
	if line != null:
		line.default_color = Color("3a6175")
		line.width = 4.0
	var node := _routing_buttons.get(removed) as Button
	if node != null:
		node.modulate = Color.WHITE
	var label := _challenge.find_child("RouteLabel", true, false) as Label
	if label != null:
		label.text = "ROTA: " + "  →  ".join(_route)
	var feedback := _challenge.find_child("RouteFeedback", true, false) as Label
	if feedback != null:
		feedback.text = "Último salto removido. Escolha outra conexão a partir de %s." % previous
		feedback.add_theme_color_override("font_color", Color("8faab9"))
