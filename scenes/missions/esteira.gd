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
@export var map_offset := Vector2(-255, -195)

enum TaskState { IDLE, MOVING, ENTERING, PROCESSING, SUCCESS, ERROR, LEAVING, COMPLETED }

const STAGES: Array[Dictionary] = [
	{
		"layer": "1. APLICAÇÃO", "tcp": "TCP/IP: Aplicação",
		"concept": "Protocolos usados diretamente por programas.",
		"prompt": "Abrir uma página web segura.",
		"choices": ["HTTPS", "SMTP", "FTP"], "answer": 1
	},
	{
		"layer": "2. APRESENTAÇÃO", "tcp": "TCP/IP: Aplicação",
		"concept": "Codifica e prepara os dados.",
		"prompt": "Preservar ç, ã e emoji na mensagem.",
		"choices": ["UTF-8", "ASCII", "Somente números"], "answer": 1
	},
	{
		"layer": "3. SESSÃO", "tcp": "TCP/IP: Aplicação",
		"concept": "Mantém a comunicação entre as partes.",
		"prompt": "Selecione a sessão que ainda pode continuar.",
		"choices": ["ID 42 — ativa", "ID 17 — encerrada", "ID 08 — expirada"], "answer": 1
	},
	{
		"layer": "4. TRANSPORTE", "tcp": "TCP/IP: Transporte",
		"concept": "Organiza segmentos para uma entrega confiável.",
		"prompt": "Segmentos recebidos: 3, 1, 2. Pressione as teclas na ordem correta.",
		"choices": ["1", "2", "3"], "answer": 0, "segments": true
	},
	{
		"layer": "5. REDE", "tcp": "TCP/IP: Internet",
		"concept": "Escolhe a rota de destino usando IP.",
		"prompt": "Destino 10.20.8.44. Tabela: 10.20.8.0/24 → R2.",
		"choices": ["R1", "R2", "R3"], "answer": 2
	},
	{
		"layer": "6. ENLACE", "tcp": "TCP/IP: Acesso à Rede",
		"concept": "Entrega quadros ao próximo dispositivo.",
		"prompt": "Próximo salto: SW-2 (MAC 7C:8A:10:01).",
		"choices": ["00:AA:21:19", "FF:FF:FF:FF", "7C:8A:10:01"], "answer": 3
	},
	{
		"layer": "7. FÍSICA", "tcp": "TCP/IP: Acesso à Rede",
		"concept": "Converte bits em sinais no meio físico.",
		"prompt": "Bits 10110010. Convenção: 1 = alto; 0 = baixo.",
		"choices": ["alto/baixo/alto/alto/baixo/baixo/alto/baixo", "baixo/alto/baixo/baixo/alto/alto/baixo/alto", "sinal constante"], "answer": 1
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
var nearby_cabin: int = -1
var package: Sprite2D
var cabin_sprites: Array[Sprite2D] = []
var cabin_lights: Array[ColorRect] = []
var cabin_window_points: Array[Vector2] = []
var stage_label: Label
var tcp_label: Label
var status_label: Label
var challenge_panel: ColorRect
var challenge_title: Label
var challenge_text: Label
var choice_labels: Array[Button] = []
var segment_order: Array[int] = []
var completed_once := false
var move_tween: Tween
var conveyor_on := false
var has_started := false
var paused_state := -1
var paused_target := Vector2.ZERO
var paused_callback := Callable()
var move_target := Vector2.ZERO
var move_callback := Callable()
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
	_sync_package_route()

func _sync_package_route() -> void:
	# A rota não possui coordenadas verticais fixas: acompanha as peças que foram
	# reposicionadas visualmente na cena, inclusive a esteira inferior.
	if top_belt_centers.is_empty() or middle_belt_centers.is_empty() or bottom_belt_centers.is_empty() or cabin_centers.size() < 7:
		return
	package_stops = [
		Vector2(cabin_centers[0].x, _belt_y_at(cabin_centers[0].x, top_belt_centers)),
		Vector2(cabin_centers[1].x, _belt_y_at(cabin_centers[1].x, top_belt_centers)),
		Vector2(cabin_centers[2].x, _belt_y_at(cabin_centers[2].x, top_belt_centers)),
		Vector2(cabin_centers[3].x, _belt_y_at(cabin_centers[3].x, middle_belt_centers)),
		Vector2(cabin_centers[4].x, _belt_y_at(cabin_centers[4].x, bottom_belt_centers)),
		Vector2(cabin_centers[5].x, _belt_y_at(cabin_centers[5].x, bottom_belt_centers)),
		Vector2(cabin_centers[6].x, _belt_y_at(cabin_centers[6].x, bottom_belt_centers))
	]
	cabin_window_points = cabin_centers.duplicate()
	# A janela da máquina central é um pouco abaixo do centro do sprite.
	if cabin_window_points.size() > 3:
		cabin_window_points[3] += Vector2(0, 13)
	start_point = Vector2(top_belt_centers[0].x - 53.0, top_belt_centers[0].y)
	delivery_point = Vector2(bottom_belt_centers[bottom_belt_centers.size() - 1].x + 53.0, bottom_belt_centers[bottom_belt_centers.size() - 1].y)

func _belt_y_at(x: float, belt_centers: Array[Vector2]) -> float:
	var closest := belt_centers[0]
	for belt_center in belt_centers:
		if absf(belt_center.x - x) < absf(closest.x - x):
			closest = belt_center
	return closest.y

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
	return "Esta é a esteira didática OSI/TCP-IP. Leve o pacote por sete cabines e pressione [E] em cada etapa."

func _build_visuals() -> void:
	_build_header()
	_build_conveyor_collision()
	var using_composed_art := use_composed_factory_art and _build_factory_sprite()
	if using_composed_art:
		_build_cabin_lights()
	else:
		_build_original_sprite_belts()
		_build_cabins()
	_build_package()
	_build_challenge_panel()
	queue_redraw()

func _build_conveyor_collision() -> void:
	# A esteira é somente visual. Assim o jogador pode atravessar as correias
	# e alcançar livremente todas as cabines.
	pass

func _build_header() -> void:
	var title := Label.new()
	title.text = "ESTEIRA DE PACOTES — OSI / TCP-IP"
	title.position = Vector2(0, 0)
	title.size = Vector2(size.x, 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 3)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)
	title.hide()

	stage_label = Label.new()
	stage_label.position = Vector2(18, 26)
	stage_label.size = Vector2(300, 20)
	stage_label.add_theme_font_size_override("font_size", 10)
	stage_label.add_theme_color_override("font_color", Color("f8dd78"))
	stage_label.add_theme_color_override("font_outline_color", Color.BLACK)
	stage_label.add_theme_constant_override("outline_size", 2)
	stage_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage_label)
	stage_label.hide()

	tcp_label = Label.new()
	tcp_label.position = Vector2(350, 26)
	tcp_label.size = Vector2(350, 20)
	tcp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tcp_label.add_theme_font_size_override("font_size", 9)
	tcp_label.add_theme_color_override("font_color", Color("8edcf2"))
	tcp_label.add_theme_color_override("font_outline_color", Color.BLACK)
	tcp_label.add_theme_constant_override("outline_size", 2)
	tcp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tcp_label)
	tcp_label.hide()

	status_label = Label.new()
	status_label.position = Vector2(18, 448)
	status_label.size = Vector2(684, 22)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 10)
	status_label.add_theme_color_override("font_color", Color.WHITE)
	status_label.add_theme_color_override("font_outline_color", Color.BLACK)
	status_label.add_theme_constant_override("outline_size", 2)
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(status_label)
	status_label.hide()

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
	var glass_overlay_texture := _load_factory_glass_overlay()
	if glass_overlay_texture != null:
		var glass_overlay := _sheet_sprite(glass_overlay_texture, Vector2(360, 266))
		glass_overlay.name = "FactoryGlassOverlay"
		# Molduras na frente do pacote; somente o vidro recebe transparência.
		glass_overlay.z_index = 2
	return true

func _load_factory_glass_overlay() -> Texture2D:
	var source := Image.load_from_file(CONVEYOR_SOURCE_PATH)
	if source == null or source.is_empty():
		return null
	var factor := Vector2(float(source.get_width()) / 9731.0, float(source.get_height()) / 10415.0)
	var source_region := Rect2i(
		Vector2i(Vector2(ORIGINAL_FACTORY_LAYOUT.position) * factor),
		Vector2i(Vector2(ORIGINAL_FACTORY_LAYOUT.size) * factor)
	)
	var overlay := source.get_region(source_region)
	overlay.resize(720, 532, Image.INTERPOLATE_NEAREST)
	for y in overlay.get_height():
		for x in overlay.get_width():
			var pixel := overlay.get_pixel(x, y)
			# Azul e ciano pertencem aos visores; a moldura e a máquina seguem opacas.
			if pixel.b > 0.5 and pixel.b > pixel.r + 0.08 and pixel.b > pixel.g + 0.05:
				pixel.a = 0.42
				overlay.set_pixel(x, y, pixel)
	return ImageTexture.create_from_image(overlay)

func _build_cabin_lights() -> void:
	# A arte composta contém LEDs fixos. Máscaras neutras os apagam até a
	# cabine realmente processar uma resposta; a seguir um LED é exibido acima.
	for index in cabin_centers.size():
		var is_central := index == 3
		var lamp_offset := Vector2(128, 38) if is_central else Vector2(20, 37)
		if is_central:
			lamp_offset = Vector2(128, 6)
		var lamp_position := cabin_centers[index] + lamp_offset
		var light := ColorRect.new()
		light.position = lamp_position + Vector2(2, 2)
		light.size = Vector2(20, 8)
		light.color = Color("38e34b")
		light.mouse_filter = Control.MOUSE_FILTER_IGNORE
		light.z_index = 3
		light.hide()
		add_child(light)
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
	# Acima da arte enquanto viaja; ao entrar na cabine, fica sob o vidro.
	package.z_index = 3
	add_child(package)
	if package.texture == null:
		var fallback := Polygon2D.new()
		fallback.polygon = PackedVector2Array([Vector2(-22, -16), Vector2(22, -16), Vector2(28, 0), Vector2(0, 20), Vector2(-28, 0)])
		fallback.color = Color("bd7734")
		package.add_child(fallback)

func _build_challenge_panel() -> void:
	# O desafio pertence à HUD, não ao mapa: assim não herda a escala da sala
	# nem fica escondido atrás de cabines, paredes ou do jogador.
	var hud := CanvasLayer.new()
	hud.name = "EsteiraChallengeHUD"
	hud.layer = 30
	add_child(hud)

	challenge_panel = ColorRect.new()
	challenge_panel.set_anchors_preset(Control.PRESET_CENTER)
	challenge_panel.offset_left = -310
	challenge_panel.offset_top = -145
	challenge_panel.offset_right = 310
	challenge_panel.offset_bottom = 145
	challenge_panel.color = Color(0.025, 0.065, 0.095, 0.98)
	challenge_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	challenge_panel.z_index = 30
	challenge_panel.hide()
	hud.add_child(challenge_panel)

	var top_line := ColorRect.new()
	top_line.position = Vector2(0, 0)
	top_line.size = Vector2(620, 6)
	top_line.color = Color("23d6ec")
	top_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	challenge_panel.add_child(top_line)

	var frame := ReferenceRect.new()
	frame.position = Vector2(8, 8)
	frame.size = Vector2(604, 274)
	frame.border_color = Color("23d6ec")
	frame.border_width = 3.0
	frame.editor_only = false
	challenge_panel.add_child(frame)

	challenge_title = Label.new()
	challenge_title.position = Vector2(20, 22)
	challenge_title.size = Vector2(580, 34)
	challenge_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	challenge_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	challenge_title.add_theme_font_size_override("font_size", 18)
	challenge_title.add_theme_color_override("font_color", Color("35edff"))
	challenge_title.add_theme_color_override("font_outline_color", Color.BLACK)
	challenge_title.add_theme_constant_override("outline_size", 4)
	challenge_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	challenge_panel.add_child(challenge_title)

	challenge_text = Label.new()
	challenge_text.position = Vector2(30, 66)
	challenge_text.size = Vector2(560, 66)
	challenge_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	challenge_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	challenge_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	challenge_text.add_theme_font_size_override("font_size", 17)
	challenge_text.add_theme_color_override("font_color", Color.WHITE)
	challenge_text.add_theme_color_override("font_outline_color", Color.BLACK)
	challenge_text.add_theme_constant_override("outline_size", 3)
	challenge_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	challenge_panel.add_child(challenge_text)

	for option_index in 3:
		var option_box := ColorRect.new()
		option_box.position = Vector2(20 + option_index * 200, 154)
		option_box.size = Vector2(180, 94)
		option_box.color = Color("123646")
		option_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		challenge_panel.add_child(option_box)
		var choice := Button.new()
		choice.position = Vector2(8, 8)
		choice.size = Vector2(164, 78)
		choice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		choice.add_theme_font_size_override("font_size", 13)
		choice.add_theme_color_override("font_color", Color("f4f8ff"))
		choice.add_theme_color_override("font_outline_color", Color.BLACK)
		choice.add_theme_constant_override("outline_size", 3)
		choice.tooltip_text = "Clique para selecionar esta resposta."
		option_box.add_child(choice)
		choice_labels.append(choice)
		choice.pressed.connect(func() -> void:
			if state != TaskState.PROCESSING:
				return
			var stage: Dictionary = STAGES[stage_index]
			if bool(stage.get("segments", false)):
				_handle_segment_choice(option_index + 1)
			else:
				_validate_answer(option_index + 1)
		)

func _draw() -> void:
	# Painel de controle no início da linha: botão verde liga, vermelho pausa.
	draw_rect(panel_rect, Color("18242d"), true)
	draw_rect(panel_rect, Color("8ba0ad"), false, 2.0)
	var green_color := Color("31e659") if conveyor_on else Color("1b9a42")
	draw_rect(green_button_rect, green_color, true)
	draw_rect(green_button_rect, Color.BLACK, false, 2.0)
	draw_string(ThemeDB.fallback_font, green_button_rect.position + Vector2(12, 23), "LIGAR", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.BLACK)

func _process(_delta: float) -> void:
	if conveyor_on and (state == TaskState.MOVING or state == TaskState.ENTERING or state == TaskState.LEAVING):
		package.position.y += sin(Time.get_ticks_msec() * 0.012) * 0.18
	var panel_action := _panel_action_under_player()
	if panel_action != 0 and state != TaskState.PROCESSING:
		if conveyor_on:
			status_label.text = "A esteira já está ligada."
		else:
			status_label.text = "Pressione E para ligar a esteira."
			mentor_context.emit("Pressione [E] no botão verde para ligar a esteira.")
		return
	if state != TaskState.PROCESSING and state != TaskState.COMPLETED:
		var previous := nearby_cabin
		nearby_cabin = _cabine_under_player()
		if nearby_cabin != previous and nearby_cabin >= 0:
			mentor_context.emit("Cabine " + str(nearby_cabin + 1) + ". Pressione [E] quando o pacote estiver aqui.")

func _panel_action_under_player() -> int:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var slot := get_parent() as Node2D
	if player == null or slot == null:
		return 0
	var local_position := get_global_transform().affine_inverse() * player.global_position
	if green_button_rect.grow(16.0).has_point(local_position):
		return 1
	if panel_rect.grow(20.0).has_point(local_position):
		return 1
	return 0

func _cabine_under_player() -> int:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	var slot := get_parent() as Node2D
	if player == null or slot == null:
		return -1
	var local_position := get_global_transform().affine_inverse() * player.global_position
	for index in cabin_centers.size():
		# As áreas ficam na frente de cada máquina. A cabine central recebe a
		# mesma largura das demais e uma faixa um pouco maior abaixo dela.
		var zone: Rect2
		if index == 3:
			zone = Rect2(cabin_centers[index] + Vector2(-76, 0), Vector2(152, 74))
		elif index >= 4:
			zone = Rect2(cabin_centers[index] + Vector2(-76, -15), Vector2(152, 60))
		else:
			zone = Rect2(cabin_centers[index] + Vector2(-76, -12), Vector2(152, 45))
		if zone.has_point(local_position):
			return index
	return -1

func _input(event: InputEvent) -> void:
	if challenge_panel != null and challenge_panel.visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_close_challenge()
		get_viewport().set_input_as_handled()

func _close_challenge() -> void:
	if state != TaskState.PROCESSING and state != TaskState.ERROR:
		return
	segment_order.clear()
	challenge_panel.hide()
	state = TaskState.IDLE
	_set_light(stage_index, Color("f4c842"))
	status_label.text = "Desafio fechado. Volte à cabine e pressione [E] para tentar novamente."
	mentor_context.emit("")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R:
		# R reinicia a simulação inclusive depois da conclusão. completed_once
		# permanece verdadeiro, portanto o progresso salvo da missão não é perdido.
		_reset_task(true)
		get_viewport().set_input_as_handled()
		return
	if not event.is_action_pressed("interact") or event.is_echo():
		if state == TaskState.PROCESSING:
			_handle_choice_input(event)
		return
	var panel_action := _panel_action_under_player()
	if panel_action != 0:
		_turn_conveyor_on()
		get_viewport().set_input_as_handled()
		return
	if not conveyor_on:
		status_label.text = "Ligue a esteira no painel verde antes de processar o pacote."
		return
	if state == TaskState.IDLE and nearby_cabin == stage_index:
		_enter_current_cabin()
		get_viewport().set_input_as_handled()
	elif state == TaskState.IDLE and nearby_cabin >= 0:
		_feedback_error("O pacote ainda não chegou a esta cabine.")
		get_viewport().set_input_as_handled()

func _handle_choice_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var option := 0
	if event.keycode == KEY_1:
		option = 1
	elif event.keycode == KEY_2:
		option = 2
	elif event.keycode == KEY_3:
		option = 3
	else:
		return
	var stage: Dictionary = STAGES[stage_index]
	if bool(stage.get("segments", false)):
		_handle_segment_choice(option)
	else:
		_validate_answer(option)

func _turn_conveyor_on() -> void:
	if state == TaskState.COMPLETED:
		mentor_message.emit("Esta esteira já concluiu a entrega.", 3.0)
		return
	if conveyor_on:
		return
	conveyor_on = true
	queue_redraw()
	if paused_state >= 0:
		state = paused_state
		var callback := paused_callback
		var target := paused_target
		paused_state = -1
		paused_callback = Callable()
		_move_package([package.position, target], 0.55, callback)
		status_label.text = "Esteira religada. O pacote continua o percurso."
		return
	if not has_started:
		has_started = true
		package.visible = true
		state = TaskState.MOVING
		status_label.text = "Esteira ligada. O pacote está seguindo para a cabine 1."
		_move_package([start_point, package_stops[0]], 0.85, func() -> void:
			if state != TaskState.MOVING:
				return
			_move_package_into_current_cabin()
		)
	else:
		status_label.text = "Esteira ligada. O pacote está aguardando a próxima cabine."

func _turn_conveyor_off() -> void:
	if not conveyor_on:
		return
	if state == TaskState.PROCESSING:
		status_label.text = "Conclua o desafio atual antes de interromper a esteira."
		return
	conveyor_on = false
	if state == TaskState.MOVING or state == TaskState.ENTERING or state == TaskState.LEAVING:
		paused_state = state
		paused_target = move_target
		paused_callback = move_callback
		if move_tween != null and move_tween.is_valid():
			move_tween.kill()
	queue_redraw()
	status_label.text = "Esteira desligada. O progresso do pacote foi preservado."
	mentor_message.emit(status_label.text, 3.0)

func _enter_current_cabin() -> void:
	if state != TaskState.IDLE:
		return
	state = TaskState.PROCESSING
	_set_light(stage_index, Color("f4c842"))
	status_label.text = "Processando pacote na cabine…"
	mentor_context.emit("")
	_show_challenge()

func _move_package_into_current_cabin() -> void:
	state = TaskState.ENTERING
	package.z_index = 3
	_set_light(stage_index, Color("f4c842"))
	status_label.text = "Pacote entrando na cabine…"
	var target := cabin_window_points[stage_index]
	_move_package([package.position, target], 0.35, func() -> void:
		if state != TaskState.ENTERING:
			return
		package.z_index = 1
		state = TaskState.IDLE
		status_label.text = "Pacote dentro da cabine " + str(stage_index + 1) + ". Aproxime-se e pressione [E]."
		mentor_context.emit("Cabine " + str(stage_index + 1) + " pronta. Pressione [E] para iniciar o desafio.")
	)

func _show_challenge() -> void:
	var stage: Dictionary = STAGES[stage_index]
	challenge_panel.show()
	challenge_title.text = String(stage["layer"]) + "  •  " + String(stage["tcp"])
	challenge_text.text = String(stage["prompt"])
	for index in choice_labels.size():
		var choice := choice_labels[index]
		choice.text = "[" + str(index + 1) + "] " + String(stage["choices"][index])
		choice.modulate = Color.WHITE
	status_label.text = String(stage["concept"]) + "  Escolha com [1], [2] ou [3]."
	mentor_message.emit(status_label.text, 4.0)

func _handle_segment_choice(segment: int) -> void:
	if segment_order.has(segment):
		_feedback_error("Esse segmento já foi escolhido. Reinicie a ordem: 1, 2, 3.")
		segment_order.clear()
		_refresh_segment_text()
		return
	segment_order.append(segment)
	_refresh_segment_text()
	if segment_order.size() == 3:
		if segment_order == [1, 2, 3]:
			_feedback_success()
		else:
			_feedback_error("Ordem incorreta. Os segmentos voltaram para 3, 1, 2.")
			segment_order.clear()
			_refresh_segment_text()

func _refresh_segment_text() -> void:
	challenge_text.text = "Ordem escolhida: " + str(segment_order) + ". Forme 1, 2, 3."
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
	_set_light(stage_index, Color("38e34b"), true)
	status_label.text = "Correto! Cabine liberada."
	challenge_panel.hide()
	mentor_message.emit("Correto! O pacote seguirá para a próxima camada.", 2.5)
	await get_tree().create_timer(0.6).timeout
	if state != TaskState.SUCCESS:
		return
	_leave_cabin()

func _feedback_error(message: String) -> void:
	state = TaskState.ERROR
	_set_light(stage_index, Color("e43d3d"), true)
	status_label.text = message
	mentor_message.emit(message, 2.5)
	await get_tree().create_timer(0.7).timeout
	if state != TaskState.ERROR:
		return
	_set_light(stage_index, Color("f4c842"))
	state = TaskState.PROCESSING
	status_label.text = "Tente novamente com [1], [2] ou [3]."

func _leave_cabin() -> void:
	state = TaskState.LEAVING
	package.z_index = 3
	var old_stage := stage_index
	stage_index += 1
	if stage_index >= STAGES.size():
		_move_package([package.position, package_stops[old_stage], delivery_point], 0.8, func() -> void:
			_finish_task()
		)
		return
	# O pacote deixa o visor e retorna primeiro para a correia da etapa atual.
	var points: Array[Vector2] = [package.position, package_stops[old_stage]]
	if old_stage == 2:
		points.append(corner_centers[0])
		points.append(corner_centers[1])
	elif old_stage == 3:
		points.append(corner_centers[2])
		points.append(corner_centers[3])
	points.append(package_stops[stage_index])
	_move_package(points, 0.65, func() -> void:
		if state != TaskState.LEAVING:
			return
		_update_header()
		_move_package_into_current_cabin()
	)

func _move_package(points: Array[Vector2], duration: float, callback: Callable) -> void:
	move_target = points[points.size() - 1]
	move_callback = callback
	if move_tween != null and move_tween.is_valid():
		move_tween.kill()
	move_tween = create_tween()
	var segments := maxi(points.size() - 1, 1)
	for index in range(1, points.size()):
		move_tween.tween_property(package, "position", points[index], duration / float(segments)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	move_tween.tween_callback(func() -> void:
		move_callback = Callable()
		callback.call()
	)

func _finish_task() -> void:
	state = TaskState.COMPLETED
	conveyor_on = false
	queue_redraw()
	stage_index = STAGES.size()
	_update_header()
	challenge_panel.hide()
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
	has_started = false
	paused_state = -1
	paused_callback = Callable()
	queue_redraw()
	stage_index = 0
	nearby_cabin = -1
	segment_order.clear()
	package.position = start_point
	package.visible = false
	for index in cabin_lights.size():
		_set_light(index, Color("d72e2e"))
	challenge_panel.hide()
	_update_header()
	status_label.text = "Pacote pronto. Vá até a cabine 1 (Aplicação) e pressione [E]."
	if user_requested:
		mentor_message.emit("Esteira reiniciada. O progresso da missão já concluída permanece salvo.", 3.0)

func _update_header() -> void:
	if stage_index >= STAGES.size():
		stage_label.text = "ETAPA 7/7 — ENTREGA"
		tcp_label.text = "TCP/IP: pacote entregue"
		return
	var stage: Dictionary = STAGES[stage_index]
	stage_label.text = "ETAPA " + str(stage_index + 1) + "/7 — " + String(stage["layer"])
	tcp_label.text = String(stage["tcp"])

func _set_light(index: int, color: Color, lit: bool = false) -> void:
	if index >= 0 and index < cabin_lights.size():
		cabin_lights[index].color = color
		cabin_lights[index].visible = lit

func restore_completed() -> void:
	if package == null:
		return
	completed_once = true
	state = TaskState.COMPLETED
	conveyor_on = false
	queue_redraw()
	stage_index = STAGES.size()
	package.position = delivery_point
	for index in cabin_lights.size():
		_set_light(index, Color("38e34b"), true)
	challenge_panel.hide()
	_update_header()
	status_label.text = "Entrega já concluída. Pressione [R] para repetir a simulação."
