extends Control

signal completed
signal mentor_message(message: String, duration: float)
signal mentor_context(message: String)

const CABIN_TEXTURE_PATH := "res://assets/generated/esteira_cabine.png"
const CONVEYOR_SOURCE_PATH := "res://assets/sprites/Esteira.png"
const SPRITESHEET_PATH := "res://assets/sprites/esteirasprites.png"
const PACKAGE_TEXTURE_PATH := "res://assets/sprites/Pacote.png"
const CABIN_SCALE := Vector2(0.86, 0.86)
const PACKAGE_SCALE := Vector2(0.040, 0.040)
# Coordenadas da arte composta depois do recorte para 720 × 532.
const CABIN_BODIES: Array[Rect2] = [
	Rect2(108, 2, 100, 111), Rect2(301, 3, 99, 111), Rect2(498, 3, 99, 111),
	Rect2(222, 188, 334, 117), Rect2(201, 417, 99, 113),
	Rect2(393, 418, 100, 111), Rect2(591, 418, 99, 111),
]
const CABIN_WINDOWS: Array[Rect2] = [
	Rect2(116, 43, 83, 31), Rect2(310, 44, 82, 31), Rect2(506, 44, 83, 31),
	Rect2(234, 236, 308, 47), Rect2(208, 460, 83, 31),
	Rect2(403, 460, 81, 31), Rect2(600, 460, 81, 31),
]

# Regiões da folha de sprites (base 1476 x 1080, sem os títulos de referência).
const SHEET_SMALL_MACHINE := Rect2i(50, 466, 217, 210)
const SHEET_BELT_HORIZONTAL := Rect2i(35, 195, 168, 110)
const SHEET_BELT_VERTICAL := Rect2i(255, 158, 88, 171)
const SHEET_CURVE_TOP_LEFT := Rect2i(409, 156, 175, 178)
const SHEET_CURVE_TOP_RIGHT := Rect2i(615, 156, 170, 178)
const SHEET_CURVE_BOTTOM_LEFT := Rect2i(827, 156, 180, 180)
const SHEET_CURVE_BOTTOM_RIGHT := Rect2i(1048, 156, 175, 180)
const SHEET_ENTRY := Rect2i(950, 468, 218, 190)
const SHEET_EXIT := Rect2i(1220, 468, 205, 190)
const SHEET_PANEL := Rect2i(35, 818, 268, 162)
const SHEET_BUTTON_OFF := Rect2i(348, 864, 195, 96)
const SHEET_PACKAGE := Rect2i(844, 858, 110, 103)
const ORIGINAL_SMALL_MACHINE := Rect2i(1470, 0, 1340, 1530)
const ORIGINAL_HORIZONTAL_BELT := Rect2i(0, 600, 1400, 925)
const ORIGINAL_VERTICAL_BELT := Rect2i(8290, 1530, 930, 1685)
const ORIGINAL_TOP_RIGHT_CURVE := Rect2i(8100, 600, 1130, 1500)
const ORIGINAL_BOTTOM_LEFT_CURVE := Rect2i(1280, 3250, 1700, 1500)
const ORIGINAL_FACTORY_LAYOUT := Rect2i(0, 0, 9731, 7200)

# Ajustáveis pela cena da missão para futuros reposicionamentos no mapa.
@export var map_scale := 0.82
@export var map_offset := Vector2(-301, -195)

enum TaskState { IDLE, MOVING, ENTERING, PROCESSING, SUCCESS, ERROR, LEAVING, COMPLETED }

const STAGES: Array[Dictionary] = [
	{
		"layer": "1. APLICAÇÃO", "tcp": "TCP/IP: Aplicação",
		"concept": "Protocolos de aplicação definem como clientes e servidores trocam dados.",
		"prompt": "Um navegador precisa buscar uma página com confidencialidade e autenticação do servidor. Qual protocolo deve usar?",
		"choices": ["HTTPS", "DNS", "DHCP"], "answer": 1
	},
	{
		"layer": "2. APRESENTAÇÃO", "tcp": "TCP/IP: Aplicação",
		"concept": "No modelo TCP/IP, codificação e formato dos dados fazem parte da aplicação.",
		"prompt": "Uma API deve enviar “café ☕” sem perder acentos ou emoji. Qual codificação deve declarar na resposta?",
		"choices": ["UTF-8", "ASCII", "Binário sem charset"], "answer": 1
	},
	{
		"layer": "3. SESSÃO", "tcp": "TCP/IP: Aplicação",
		"concept": "No TCP/IP, o controle de sessão é tratado pelos protocolos e aplicações.",
		"prompt": "Após o login, o servidor precisa reconhecer as próximas requisições do mesmo usuário. O que identifica essa sessão?",
		"choices": ["Cookie/token de sessão", "Endereço MAC do servidor", "Máscara de sub-rede"], "answer": 1
	},
	{
		"layer": "4. TRANSPORTE", "tcp": "TCP/IP: Transporte",
		"concept": "O TCP usa números de sequência para remontar dados recebidos fora de ordem.",
		"prompt": "Chegaram segmentos TCP com início de sequência 3001, 1001 e 2001. Selecione a ordem para remontar os dados.",
		"choices": ["Seq 1001", "Seq 2001", "Seq 3001"], "answer": 0, "segments": true
	},
	{
		"layer": "5. REDE", "tcp": "TCP/IP: Internet",
		"concept": "Roteadores escolhem a rota mais específica que corresponde ao IP de destino.",
		"prompt": "Destino: 192.168.20.45. Rotas: 192.168.0.0/16 → GW-A; 192.168.20.0/24 → GW-B; padrão → GW-C. Qual gateway será usado?",
		"choices": ["GW-A", "GW-B", "GW-C"], "answer": 2
	},
	{
		"layer": "6. ENLACE", "tcp": "TCP/IP: Acesso à Rede",
		"concept": "Em uma LAN, o quadro Ethernet é endereçado ao próximo salto, não ao host remoto.",
		"prompt": "O servidor está em outra rede. Para enviar o primeiro quadro, qual MAC deve ser usado como destino?",
		"choices": ["MAC do computador emissor", "MAC do gateway padrão", "MAC do servidor remoto"], "answer": 2
	},
	{
		"layer": "7. FÍSICA", "tcp": "TCP/IP: Acesso à Rede",
		"concept": "A camada física representa bits como sinais adequados ao meio de transmissão.",
		"prompt": "Em um enlace de fibra óptica, qual forma física pode representar os bits transmitidos?",
		"choices": ["Pulsos de luz", "Endereços IP", "Números de porta TCP"], "answer": 1
	}
]

@export_category("Layout visual — Esteira")
@export var use_composed_factory_art := true
@export var cabin_centers: Array[Vector2] = [
	Vector2(130, 109), Vector2(360, 109), Vector2(590, 109), Vector2(360, 230),
	Vector2(130, 455), Vector2(360, 455), Vector2(590, 455)
]
@export var package_stops: Array[Vector2] = [
	Vector2(130, 175), Vector2(360, 175), Vector2(590, 175), Vector2(360, 300),
	Vector2(130, 520), Vector2(360, 520), Vector2(590, 520)
]
@export var top_belt_centers: Array[Vector2] = [Vector2(81, 175), Vector2(187, 175), Vector2(293, 175), Vector2(399, 175), Vector2(505, 175), Vector2(611, 175)]
@export var middle_belt_centers: Array[Vector2] = [Vector2(160, 300), Vector2(266, 300), Vector2(372, 300), Vector2(478, 300), Vector2(584, 300)]
@export var bottom_belt_centers: Array[Vector2] = [Vector2(182, 520), Vector2(288, 520), Vector2(394, 520), Vector2(500, 520), Vector2(606, 520)]
@export var vertical_belt_centers: Array[Vector2] = [Vector2(690, 237), Vector2(130, 353), Vector2(130, 459)]
@export var corner_centers: Array[Vector2] = [Vector2(690, 175), Vector2(690, 300), Vector2(130, 300), Vector2(130, 520)]
@export var corner_rotations: Array[float] = [0.0, PI * 0.5, PI, PI * 1.5]
var start_point := Vector2(28, 175)
var delivery_point := Vector2(688, 520)
@export var panel_rect := Rect2(12, 245, 112, 66)
@export var green_button_rect := Rect2(28, 270, 80, 32)

var state: int = TaskState.IDLE
var stage_index: int = 0
var package: Sprite2D
var cabin_sprites: Array[Sprite2D] = []
var cabin_lights: Array[ColorRect] = []
var cabin_window_points: Array[Vector2] = []
var cabin_exit_points: Array[Vector2] = []
var status_label: Label
var challenge_panel: PanelContainer
var challenge_step: Label
var challenge_camera: Camera2D
var previous_camera: Camera2D
var challenge_player: CharacterBody2D
var console_prompt: Label
var challenge_title: Label
var challenge_text: Label
var choice_labels: Array[Button] = []
var segment_order: Array[int] = []
var completed_once := false
var move_tween: Tween
var conveyor_on := false
var panel_sprite: Sprite2D

func _ready() -> void:
	size = Vector2(720, 550)
	position = map_offset
	scale = Vector2.ONE * map_scale
	# Toda a instalação fica atrás do jogador. A HUD do desafio usa CanvasLayer
	# próprio e, portanto, continua acima do mapa quando necessária.
	z_index = 0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sync_layout_markers()
	_build_visuals()
	_reset_task(false)
	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree():
			_close_challenge()
	)
	get_viewport().size_changed.connect(_frame_challenge)
	call_deferred("_keep_player_in_front")

func _sync_layout_markers() -> void:
	# Os Marker2D filhos de Layout ficam editáveis/arrastáveis no Godot.
	# Se algum marcador não existir, o valor exposto no Inspector é preservado.
	cabin_centers = _marker_positions("Cabin", cabin_centers)
	top_belt_centers = _marker_positions("TopBelt", top_belt_centers)
	middle_belt_centers = _marker_positions("MiddleBelt", middle_belt_centers)
	bottom_belt_centers = _marker_positions("BottomBelt", bottom_belt_centers)
	vertical_belt_centers = _marker_positions("VerticalBelt", vertical_belt_centers)
	corner_centers = _marker_positions("Corner", corner_centers)
	var panel_marker := get_node_or_null("Layout/Panel") as Marker2D
	if panel_marker != null:
		panel_rect.position = panel_marker.position
	var button_marker := get_node_or_null("Layout/PowerButton") as Marker2D
	if button_marker != null:
		green_button_rect.position = button_marker.position

func _sync_package_route(using_composed_art: bool) -> void:
	package_stops.clear()
	cabin_window_points.clear()
	cabin_exit_points.clear()
	for index in STAGES.size():
		var belt := top_belt_centers if index < 3 else (middle_belt_centers if index == 3 else bottom_belt_centers)
		var center := Vector2(cabin_centers[index].x, belt[0].y)
		var half_width := 60.0
		if using_composed_art:
			center = CABIN_WINDOWS[index].get_center()
			half_width = CABIN_BODIES[index].size.x * 0.5
		var direction := -1.0 if index == 3 else 1.0
		var side := Vector2((half_width + 8.0) * direction, 0)
		package_stops.append(center - side)
		cabin_window_points.append(center)
		cabin_exit_points.append(center + side)
	start_point = Vector2(maxf(14.0, top_belt_centers[0].x - 53.0), package_stops[0].y)
	delivery_point = Vector2(maxf(bottom_belt_centers[-1].x + 53.0, cabin_exit_points[-1].x), package_stops[-1].y)

func _marker_positions(prefix: String, defaults: Array[Vector2]) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for index in defaults.size():
		var marker := get_node_or_null("Layout/" + prefix + str(index + 1)) as Marker2D
		positions.append(marker.position if marker != null else defaults[index])
	return positions

func _keep_player_in_front() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null:
		player.z_index = maxi(player.z_index, 5)

func mentor_intro() -> String:
	return "Aproxime-se do console verde e pressione [E]. Acompanhe as sete cabines pelo painel lateral."

func _build_visuals() -> void:
	_build_conveyor_collision()
	var using_composed_art := use_composed_factory_art and _build_factory_sprite()
	_sync_package_route(using_composed_art)
	if using_composed_art:
		_build_cabin_lights()
	else:
		_build_original_sprite_belts()
		_build_cabins()
	_build_package()
	_build_challenge_panel()
	queue_redraw()

func _build_conveyor_collision() -> void:
	# As formas cobrem as correias e cabines da arte 720 × 532.
	var body := StaticBody2D.new()
	body.name = "ConveyorCollision"
	add_child(body)
	var footprints: Array[Rect2] = [
		Rect2(2, 45, 684, 68), Rect2(613, 45, 72, 260),
		Rect2(95, 240, 591, 65), Rect2(95, 240, 55, 289),
		Rect2(95, 460, 624, 69), Rect2(222, 188, 334, 118),
		Rect2(108, 2, 100, 113), Rect2(301, 2, 99, 113), Rect2(498, 3, 99, 112),
		Rect2(200, 417, 100, 112), Rect2(393, 417, 100, 112), Rect2(591, 417, 100, 112),
		panel_rect
	]
	for footprint in footprints:
		var shape := RectangleShape2D.new()
		shape.size = footprint.size
		var collision := CollisionShape2D.new()
		collision.shape = shape
		collision.position = footprint.get_center()
		body.add_child(collision)

func _load_runtime_texture(path: String) -> Texture2D:
	var image := Image.load_from_file(path)
	if image == null or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)

func _load_original_region(region: Rect2i, target_size: Vector2i) -> Texture2D:
	var source := Image.load_from_file(CONVEYOR_SOURCE_PATH)
	if source == null or source.is_empty():
		return null
	var factor := Vector2(float(source.get_width()) / 9731.0, float(source.get_height()) / 10415.0)
	var source_region := Rect2i(
		Vector2i(Vector2(region.position) * factor),
		Vector2i(Vector2(region.size) * factor)
	)
	var crop := source.get_region(source_region)
	crop.resize(target_size.x, target_size.y, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(crop)

func _build_factory_sprite() -> bool:
	# Arte completa enviada para a missão: preserva os cantos, proporções e
	# acabamento original, sem remontar a fábrica em pequenos trechos.
	var factory_texture := _load_original_region(ORIGINAL_FACTORY_LAYOUT, Vector2i(720, 532))
	if factory_texture == null:
		return false
	var factory := _sheet_sprite(factory_texture, Vector2(360, 266))
	factory.name = "FactoryArtwork"
	factory.z_index = 0
	_build_glass_foreground(factory_texture)
	return true

func _build_glass_foreground(factory_texture: Texture2D) -> void:
	# Redesenha a moldura sobre o pacote, deixando só a abertura do vidro livre.
	for index in CABIN_WINDOWS.size():
		var body := CABIN_BODIES[index]
		var glass := CABIN_WINDOWS[index]
		var strips: Array[Rect2] = [
			Rect2(body.position, Vector2(body.size.x, glass.position.y - body.position.y)),
			Rect2(body.position.x, glass.end.y, body.size.x, body.end.y - glass.end.y),
			Rect2(body.position.x, glass.position.y, glass.position.x - body.position.x, glass.size.y),
			Rect2(glass.end.x, glass.position.y, body.end.x - glass.end.x, glass.size.y),
		]
		for strip in strips:
			var frame := _sheet_sprite(factory_texture, strip.get_center())
			frame.region_enabled = true
			frame.region_rect = strip
			frame.z_index = 4

	var reflections := Node2D.new()
	reflections.name = "CentralCabinReflections"
	reflections.z_index = 5
	add_child(reflections)
	for x in [278, 301, 376, 399]:
		var glint := Polygon2D.new()
		glint.polygon = PackedVector2Array([
			Vector2(x + 25, 238), Vector2(x + 34, 238),
			Vector2(x + 9, 281), Vector2(x, 281),
		])
		glint.color = Color(0.78, 0.94, 1.0, 0.32)
		reflections.add_child(glint)

func _build_cabin_lights() -> void:
	# A arte composta tem dois LEDs fixos por cabine. A moldura cobre ambos
	# e o indicador dinâmico ocupa a mesma posição.
	var lamp_positions: Array[Vector2] = [
		Vector2(182, 95), Vector2(374, 96), Vector2(571, 96), Vector2(521, 291),
		Vector2(274, 510), Vector2(467, 511), Vector2(663, 511)
	]
	for lamp_position in lamp_positions:
		var housing := ColorRect.new()
		housing.position = lamp_position
		housing.size = Vector2(20, 10)
		housing.color = Color("202529")
		housing.mouse_filter = Control.MOUSE_FILTER_IGNORE
		housing.z_index = 5
		add_child(housing)

		var light := ColorRect.new()
		light.position = Vector2(3, 2)
		light.size = Vector2(14, 6)
		light.mouse_filter = Control.MOUSE_FILTER_IGNORE
		light.hide()
		housing.add_child(light)
		cabin_lights.append(light)

func _build_original_sprite_belts() -> void:
	# Peças proporcionais extraídas diretamente de Esteira.png. O desenho-base
	# abaixo apenas fecha os cantos do percurso em S entre esses módulos.
	var horizontal := _load_original_region(ORIGINAL_HORIZONTAL_BELT, Vector2i(106, 70))
	if horizontal != null:
		var belt_centers: Array[Vector2] = []
		belt_centers.append_array(top_belt_centers)
		belt_centers.append_array(middle_belt_centers)
		belt_centers.append_array(bottom_belt_centers)
		for belt_position in belt_centers:
			_sheet_sprite(horizontal, belt_position)
	var vertical := _load_original_region(ORIGINAL_VERTICAL_BELT, Vector2i(58, 106))
	if vertical != null:
		for index in vertical_belt_centers.size():
			var vertical_piece := _sheet_sprite(vertical, vertical_belt_centers[index])
			# VerticalBelt1 e VerticalBelt2 acompanham o sentido do percurso em S.
			vertical_piece.flip_v = index < 2
	# Uma curva por dobra real do percurso em S. O projeto contém Esteira.png,
	# mas não o arquivo esteirasprites.png; portanto os quatro cantos são
	# recortes da própria esteira, sem um fallback vazio.
	var corner := _load_original_region(ORIGINAL_TOP_RIGHT_CURVE, Vector2i(74, 74))
	if corner != null:
		for index in mini(corner_centers.size(), corner_rotations.size()):
			var corner_piece := _sheet_sprite(corner, corner_centers[index])
			corner_piece.rotation = corner_rotations[index]
			# Mantém as quinas na camada da missão (não atrás do mapa), mas antes
			# dos outros sprites da esteira para que sejam cobertas pelas retas,
			# cabines e pelo painel.
			corner_piece.z_index = 0
			move_child(corner_piece, 0)

func _load_sheet_region(region: Rect2i, target_size: Vector2i) -> Texture2D:
	var sheet := Image.load_from_file(SPRITESHEET_PATH)
	if sheet == null or sheet.is_empty():
		return null
	var factor := Vector2(float(sheet.get_width()) / 1476.0, float(sheet.get_height()) / 1080.0)
	var scaled_region := Rect2i(
		Vector2i(Vector2(region.position) * factor),
		Vector2i(Vector2(region.size) * factor)
	)
	var crop := sheet.get_region(scaled_region)
	crop.resize(target_size.x, target_size.y, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(crop)

func _sheet_sprite(texture: Texture2D, sprite_position: Vector2) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.position = sprite_position
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.z_index = 0
	add_child(sprite)
	return sprite

func _build_sheet_decoration() -> void:
	# Cada componente visual passa a vir da folha enviada, sem desenhar máquinas
	# ou correias novas por código.
	var horizontal := _load_sheet_region(SHEET_BELT_HORIZONTAL, Vector2i(104, 62))
	if horizontal != null:
		for belt_position in [Vector2(92, 175), Vector2(196, 175), Vector2(300, 175), Vector2(404, 175), Vector2(508, 175), Vector2(612, 175), Vector2(210, 520), Vector2(314, 520), Vector2(418, 520), Vector2(522, 520), Vector2(626, 520)]:
			_sheet_sprite(horizontal, belt_position)
	var vertical := _load_sheet_region(SHEET_BELT_VERTICAL, Vector2i(52, 104))
	if vertical != null:
		_sheet_sprite(vertical, Vector2(690, 215))
	var entry := _load_sheet_region(SHEET_ENTRY, Vector2i(54, 52))
	if entry != null:
		_sheet_sprite(entry, Vector2(27, 175))
	var exit_sprite := _load_sheet_region(SHEET_EXIT, Vector2i(54, 52))
	if exit_sprite != null:
		_sheet_sprite(exit_sprite, Vector2(689, 520))
	var panel := _load_sheet_region(SHEET_PANEL, Vector2i(112, 66))
	if panel != null:
		panel_sprite = _sheet_sprite(panel, panel_rect.get_center())
	var button := _load_sheet_region(SHEET_BUTTON_OFF, Vector2i(60, 30))
	if button != null:
		_sheet_sprite(button, green_button_rect.get_center())

func _build_source_belts() -> void:
	# O arquivo enviado é uma folha grande. Este recorte usa diretamente a
	# faixa de esteira do sprite, redimensionada sem suavização para o mapa.
	var source := Image.load_from_file(CONVEYOR_SOURCE_PATH)
	if source == null or source.is_empty():
		return
	var belt_image := source.get_region(Rect2i(20, 600, 1360, 920))
	belt_image.resize(224, 62, Image.INTERPOLATE_NEAREST)
	var belt_texture := ImageTexture.create_from_image(belt_image)
	for belt_position in [Vector2(142, 175), Vector2(366, 175), Vector2(590, 175), Vector2(540, 250), Vector2(230, 520), Vector2(454, 520), Vector2(625, 520)]:
		var belt := Sprite2D.new()
		belt.texture = belt_texture
		belt.position = belt_position
		belt.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		belt.z_index = 0
		add_child(belt)

func _build_cabins() -> void:
	var cabin_texture := _load_original_region(ORIGINAL_SMALL_MACHINE, Vector2i(142, 154))
	if cabin_texture == null:
		cabin_texture = _load_runtime_texture(CABIN_TEXTURE_PATH)
	for index in STAGES.size():
		var cabin := Sprite2D.new()
		# Todas as etapas usam o mesmo gabinete, sem distorção de escala.
		cabin.texture = cabin_texture
		cabin.position = cabin_centers[index]
		cabin.scale = CABIN_SCALE if cabin_texture != null else Vector2.ONE
		cabin.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		cabin.z_index = 0
		add_child(cabin)
		cabin_sprites.append(cabin)
		if cabin_texture == null:
			var fallback := ColorRect.new()
			fallback.position = cabin_centers[index] - Vector2(58, 60)
			fallback.size = Vector2(116, 116)
			fallback.color = Color("5c6068")
			fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(fallback)
		var name_label := Label.new()
		name_label.text = str(STAGES[index]["layer"]).trim_prefix(str(index + 1) + ". ")
		name_label.position = cabin_centers[index] + Vector2(-70, 68)
		name_label.size = Vector2(140, 16)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 8)
		name_label.add_theme_color_override("font_color", Color.WHITE)
		name_label.add_theme_color_override("font_outline_color", Color.BLACK)
		name_label.add_theme_constant_override("outline_size", 2)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(name_label)
		name_label.hide()
		var light := ColorRect.new()
		light.position = cabin_centers[index] + Vector2(-9, 55)
		light.size = Vector2(18, 8)
		light.color = Color("d72e2e")
		light.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(light)
		cabin_lights.append(light)

func _build_package() -> void:
	package = Sprite2D.new()
	package.texture = _load_runtime_texture(PACKAGE_TEXTURE_PATH)
	package.position = start_point
	package.scale = PACKAGE_SCALE
	package.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Mantém o pacote visível também quando ele para no visor.
	package.z_index = 3
	add_child(package)
	if package.texture == null:
		var fallback := Polygon2D.new()
		fallback.polygon = PackedVector2Array([Vector2(-22, -16), Vector2(22, -16), Vector2(28, 0), Vector2(0, 20), Vector2(-28, 0)])
		fallback.color = Color("bd7734")
		package.add_child(fallback)

func _build_challenge_panel() -> void:
	var hud := CanvasLayer.new()
	hud.name = "EsteiraChallengeHUD"
	hud.layer = 30
	add_child(hud)
	challenge_panel = PanelContainer.new()
	challenge_panel.name = "CabinPanel"
	challenge_panel.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	challenge_panel.hide()
	hud.add_child(challenge_panel)
	challenge_panel.anchor_left = 0.55
	challenge_panel.anchor_right = 1.0
	challenge_panel.anchor_top = 0.12
	challenge_panel.anchor_bottom = 0.88
	challenge_panel.offset_left = 12
	challenge_panel.offset_right = -24
	var style := StyleBoxFlat.new()
	style.bg_color = Color("0b1a25")
	style.border_color = Color("3697a6")
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_content_margin(side, 28)
	challenge_panel.add_theme_stylebox_override("panel", style)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	challenge_panel.add_child(layout)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	layout.add_child(header)
	var caption := _panel_label("ESTEIRA DE PACOTES  /  OSI + TCP/IP", 20, Color("79d7df"))
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(caption)
	var close_button := Button.new()
	close_button.text = "Fechar [Esc]"
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.add_theme_font_size_override("font_size", 18)
	close_button.pressed.connect(_close_challenge)
	header.add_child(close_button)

	challenge_step = _panel_label("", 21, Color("e1b956"))
	layout.add_child(challenge_step)
	challenge_title = _panel_label("", 32, Color("ecf7fc"))
	layout.add_child(challenge_title)
	challenge_text = _panel_label("", 25, Color("ecf7fc"))
	challenge_text.custom_minimum_size.y = 112
	challenge_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	layout.add_child(challenge_text)

	for option_index in 3:
		var choice := Button.new()
		choice.custom_minimum_size.y = 64
		choice.focus_mode = Control.FOCUS_NONE
		choice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		choice.add_theme_font_size_override("font_size", 23)
		layout.add_child(choice)
		choice_labels.append(choice)
		choice.pressed.connect(_choose_answer.bind(option_index + 1))

	status_label = _panel_label("", 21, Color("9fbdc9"))
	status_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(status_label)
	layout.add_child(_panel_label("[1] [2] [3]  Responder     •     [R]  Reiniciar", 17, Color("9fbdc9")))

	challenge_camera = Camera2D.new()
	challenge_camera.name = "ConveyorCamera"
	challenge_camera.enabled = false
	add_child(challenge_camera)
	console_prompt = _panel_label("[E] PAINEL DA ESTEIRA", 18, Color("eafcff"))
	console_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	console_prompt.position = panel_rect.position + Vector2(-232, 18)
	console_prompt.size.x = 220
	console_prompt.add_theme_color_override("font_outline_color", Color("0b1a25"))
	console_prompt.add_theme_constant_override("outline_size", 6)
	console_prompt.z_index = 4
	console_prompt.hide()
	add_child(console_prompt)

func _panel_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	var inset := StyleBoxEmpty.new()
	inset.content_margin_left = 3
	inset.content_margin_right = 3
	label.add_theme_stylebox_override("normal", inset)
	return label

func _draw() -> void:
	# Painel de controle no início da linha: botão verde liga, vermelho pausa.
	draw_rect(panel_rect, Color("18242d"), true)
	draw_rect(panel_rect, Color("8ba0ad"), false, 2.0)
	var green_color := Color("31e659") if conveyor_on else Color("1b9a42")
	draw_rect(green_button_rect, green_color, true)
	draw_rect(green_button_rect, Color.BLACK, false, 2.0)
	draw_string(ThemeDB.fallback_font, green_button_rect.position + Vector2(12, 23), "LIGAR", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.BLACK)

func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
	console_prompt.visible = not is_challenge_open() and _is_at_console(player)

func _is_at_console(player: CharacterBody2D) -> bool:
	if not is_instance_valid(player):
		return false
	var local_position := get_global_transform().affine_inverse() * player.global_position
	return panel_rect.grow(66.0).has_point(local_position)

func is_challenge_open() -> bool:
	return challenge_panel != null and challenge_panel.visible

func _input(event: InputEvent) -> void:
	if is_challenge_open() and event.is_action_pressed("ui_cancel") and not event.is_echo():
		_close_challenge()
		get_viewport().set_input_as_handled()

func _frame_challenge() -> void:
	if not is_challenge_open():
		return
	var viewport_size := get_viewport_rect().size
	var camera_zoom := minf(1.3, minf(viewport_size.x * 0.49 / (size.x * map_scale),
		viewport_size.y * 0.83 / (650.0 * map_scale)))
	challenge_camera.zoom = Vector2.ONE * camera_zoom
	var factory_center := get_global_transform() * Vector2(360, 312)
	# Centraliza a instalação no espaço à esquerda do painel.
	challenge_camera.global_position = factory_center + Vector2(viewport_size.x * 0.225 / camera_zoom, 0)
	challenge_camera.force_update_scroll()

func _open_challenge(player: CharacterBody2D) -> void:
	if is_challenge_open() or not player.is_physics_processing():
		return
	add_to_group("active_conveyor_challenge")
	challenge_player = player
	challenge_player.set_physics_process(false)
	mentor_context.emit("")
	previous_camera = get_viewport().get_camera_2d()
	challenge_panel.show()
	challenge_camera.enabled = true
	_frame_challenge()
	challenge_camera.make_current()

func _close_challenge() -> void:
	if not is_challenge_open():
		return
	challenge_panel.hide()
	remove_from_group("active_conveyor_challenge")
	challenge_camera.enabled = false
	if is_instance_valid(previous_camera) and previous_camera.is_inside_tree():
		previous_camera.make_current()
	previous_camera = null
	if is_instance_valid(challenge_player):
		challenge_player.set_physics_process(true)
	challenge_player = null

func _exit_tree() -> void:
	if is_instance_valid(challenge_player):
		challenge_player.set_physics_process(true)

func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or event.is_echo():
		return
	var player := get_tree().get_first_node_in_group("player") as CharacterBody2D
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		if is_challenge_open() or (_is_at_console(player) and player.is_physics_processing()):
			_reset_task(true)
			if is_challenge_open():
				_turn_conveyor_on()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact") and _is_at_console(player):
		if is_challenge_open() or not player.is_physics_processing():
			return
		if state == TaskState.COMPLETED:
			mentor_message.emit("Entrega concluída. Pressione [R] junto ao console para repetir.", 3.0)
		else:
			_open_challenge(player)
			_turn_conveyor_on()
		get_viewport().set_input_as_handled()
		return
	if not is_challenge_open() or state != TaskState.PROCESSING or not (event is InputEventKey) or not event.pressed:
		return
	if event.keycode in [KEY_1, KEY_2, KEY_3]:
		_choose_answer(event.keycode - KEY_1 + 1)
		get_viewport().set_input_as_handled()

func _choose_answer(option: int) -> void:
	if state != TaskState.PROCESSING:
		return
	var stage: Dictionary = STAGES[stage_index]
	if bool(stage.get("segments", false)):
		_handle_segment_choice(option)
	else:
		_validate_answer(option)

func _turn_conveyor_on() -> void:
	if state == TaskState.COMPLETED or conveyor_on:
		return
	conveyor_on = true
	queue_redraw()
	package.show()
	state = TaskState.MOVING
	_show_transit("O pacote está seguindo para a primeira cabine.")
	_move_package([start_point, package_stops[0]], 0.85, _move_package_into_current_cabin)

func _show_transit(message: String) -> void:
	challenge_step.text = "EM MOVIMENTO  /  %02d DE %02d" % [mini(stage_index + 1, STAGES.size()), STAGES.size()]
	challenge_title.text = String(STAGES[stage_index]["layer"]) if stage_index < STAGES.size() else "Saída da esteira"
	challenge_text.text = message
	status_label.text = "Acompanhe o pacote no mapa à esquerda."
	for choice in choice_labels:
		choice.hide()
		choice.disabled = true

func _move_package_into_current_cabin() -> void:
	state = TaskState.ENTERING
	package.z_index = 3
	_set_light(stage_index, Color("f4c842"), true)
	var target := cabin_window_points[stage_index]
	_move_package([package.position, target], 0.35, func() -> void:
		state = TaskState.PROCESSING
		_show_challenge()
	)

func _show_challenge() -> void:
	var stage: Dictionary = STAGES[stage_index]
	challenge_step.text = "CABINE %02d DE %02d  /  %s" % [stage_index + 1, STAGES.size(), stage["tcp"]]
	challenge_title.text = String(stage["layer"])
	challenge_text.text = String(stage["prompt"])
	for index in choice_labels.size():
		var choice := choice_labels[index]
		choice.text = "[%d]  %s" % [index + 1, stage["choices"][index]]
		choice.modulate = Color.WHITE
		choice.disabled = false
		choice.show()
	status_label.text = String(stage["concept"])

func _handle_segment_choice(segment: int) -> void:
	if segment_order.has(segment):
		_feedback_error("Esse segmento já foi escolhido. Monte a sequência novamente.")
		segment_order.clear()
		_refresh_segment_text()
		return
	segment_order.append(segment)
	_refresh_segment_text()
	if segment_order.size() == 3:
		if segment_order == [1, 2, 3]:
			_feedback_success()
		else:
			_feedback_error("Ordem incorreta. Selecione os segmentos em ordem crescente.")
			segment_order.clear()
			_refresh_segment_text()

func _refresh_segment_text() -> void:
	challenge_text.text = "Ordem escolhida: " + str(segment_order) + ". Ordene os segmentos do menor para o maior."
	for index in choice_labels.size():
		choice_labels[index].modulate = Color("4cf475") if segment_order.has(index + 1) else Color.WHITE

func _validate_answer(option: int) -> void:
	var stage: Dictionary = STAGES[stage_index]
	if option == int(stage["answer"]):
		_feedback_success()
	else:
		_feedback_error("Resposta incorreta. O pacote ficou retido para correção.")

func _feedback_success() -> void:
	if state != TaskState.PROCESSING:
		return
	state = TaskState.SUCCESS
	SoundEffects.play_correct()
	_set_light(stage_index, Color("38e34b"), true)
	status_label.text = "Correto! Cabine liberada."
	for choice in choice_labels:
		choice.disabled = true
	await get_tree().create_timer(0.6, false).timeout
	if state != TaskState.SUCCESS:
		return
	_leave_cabin()

func _feedback_error(message: String) -> void:
	state = TaskState.ERROR
	SoundEffects.play_error()
	_set_light(stage_index, Color("e43d3d"), true)
	status_label.text = message
	for choice in choice_labels:
		choice.disabled = true
	await get_tree().create_timer(0.7, false).timeout
	if state != TaskState.ERROR:
		return
	_set_light(stage_index, Color("f4c842"), true)
	state = TaskState.PROCESSING
	_show_challenge()
	status_label.text = "Tente novamente com [1], [2] ou [3]."

func _leave_cabin() -> void:
	state = TaskState.LEAVING
	package.z_index = 3
	var old_stage := stage_index
	stage_index += 1
	segment_order.clear()
	_show_transit("O pacote está seguindo para a próxima parada.")
	if stage_index >= STAGES.size():
		_move_package([package.position, cabin_exit_points[old_stage], delivery_point], 0.8, func() -> void:
			_finish_task()
		)
		return
	# O pacote deixa o visor e sai pelo lado oposto, seguindo o sentido da correia.
	var points: Array[Vector2] = [package.position, cabin_exit_points[old_stage]]
	if old_stage == 2:
		points.append(Vector2(corner_centers[0].x, cabin_exit_points[old_stage].y))
		points.append(Vector2(corner_centers[0].x, package_stops[stage_index].y))
	elif old_stage == 3:
		points.append(Vector2(corner_centers[2].x, cabin_exit_points[old_stage].y))
		points.append(Vector2(corner_centers[2].x, package_stops[stage_index].y))
	points.append(package_stops[stage_index])
	_move_package(points, 0.65, func() -> void:
		if state != TaskState.LEAVING:
			return
		_move_package_into_current_cabin()
	)

func _move_package(points: Array[Vector2], duration: float, callback: Callable) -> void:
	if move_tween != null and move_tween.is_valid():
		move_tween.kill()
	move_tween = create_tween()
	var distance := 0.0
	for index in range(1, points.size()):
		distance += points[index - 1].distance_to(points[index])
	var travel_time := maxf(duration, distance / 470.0)
	for index in range(1, points.size()):
		var segment_length := points[index - 1].distance_to(points[index])
		if segment_length > 0.0:
			move_tween.tween_property(package, "position", points[index], travel_time * segment_length / distance)
	move_tween.tween_callback(callback)

func _finish_task() -> void:
	state = TaskState.COMPLETED
	SoundEffects.play_task_complete()
	conveyor_on = false
	queue_redraw()
	stage_index = STAGES.size()
	_close_challenge()
	status_label.text = "Entrega concluída! O pacote passou pelas sete camadas."
	mentor_context.emit("")
	mentor_message.emit(status_label.text + " Pressione [R] para repetir.", 5.0)
	if not completed_once:
		completed_once = true
		completed.emit()

func _reset_task(user_requested: bool) -> void:
	if move_tween != null and move_tween.is_valid():
		move_tween.kill()
	state = TaskState.IDLE
	conveyor_on = false
	queue_redraw()
	stage_index = 0
	segment_order.clear()
	package.position = start_point
	package.visible = false
	for index in cabin_lights.size():
		_set_light(index, Color("d72e2e"))
	_show_transit("Pressione [E] no console para iniciar.")
	if user_requested:
		mentor_message.emit("Esteira reiniciada. O progresso da missão já concluída permanece salvo.", 3.0)



func _set_light(index: int, color: Color, lit: bool = false) -> void:
	if index >= 0 and index < cabin_lights.size():
		cabin_lights[index].color = color
		cabin_lights[index].visible = lit

func restore_completed() -> void:
	if package == null:
		return
	if move_tween != null and move_tween.is_valid():
		move_tween.kill()
	completed_once = true
	state = TaskState.COMPLETED
	conveyor_on = false
	queue_redraw()
	stage_index = STAGES.size()
	package.position = delivery_point
	for index in cabin_lights.size():
		_set_light(index, Color("38e34b"), true)
	package.show()
	_close_challenge()
	status_label.text = "Entrega já concluída. Pressione [R] para repetir a simulação."
