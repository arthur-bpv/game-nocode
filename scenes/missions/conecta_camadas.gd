extends Control

# ============================================================
# CONFIGURAÇÃO DAS IMAGENS
# ============================================================

const OSI_IMG := "res://assets/ui/classifica/classifica_osi.png"
const TCP_IMG := "res://assets/ui/classifica/classifica_tcp.png"

const CABINET_WIDTH := 300.0


# ============================================================
# CAMADAS
# ============================================================

const OSI_CAMADAS := [
	"aplicacao",
	"apresentacao",
	"sessao",
	"transporte",
	"rede",
	"enlace",
	"fisica"
]

const TCP_CAMADAS := [
	"aplicacao",
	"transporte",
	"internet",
	"acesso_a_rede"
]


# ============================================================
# POSIÇÕES DOS CONECTORES NAS IMAGENS
# ============================================================

const OSI_BURACOS := {
	"aplicacao": Rect2(4279, 512, 174, 452),
	"apresentacao": Rect2(4279, 1280, 174, 453),
	"sessao": Rect2(4279, 2134, 174, 452),
	"transporte": Rect2(4279, 2948, 174, 452),
	"rede": Rect2(4279, 3735, 174, 452),
	"enlace": Rect2(4279, 4628, 174, 452),
	"fisica": Rect2(4279, 5368, 174, 452),
}

const TCP_BURACOS := {
	"aplicacao": Rect2(245, 574, 223, 932),
	"transporte": Rect2(245, 1864, 223, 931),
	"internet": Rect2(245, 3329, 223, 932),
	"acesso_a_rede": Rect2(245, 4694, 223, 932),
}


# ============================================================
# CORRESPONDÊNCIA OSI -> TCP/IP
# ============================================================

const MAPA_OSI_TCP := {
	"aplicacao": "aplicacao",
	"apresentacao": "aplicacao",
	"sessao": "aplicacao",
	"transporte": "transporte",
	"rede": "internet",
	"enlace": "acesso_a_rede",
	"fisica": "acesso_a_rede",
}


# ============================================================
# CORES DOS CABOS
# ============================================================

const CORES := {
	"aplicacao": Color(0.87, 0.02, 0.02),
	"apresentacao": Color(1.0, 0.57, 0.13),
	"sessao": Color(0.1, 1.0, 0.03),
	"transporte": Color(1.0, 0.07, 0.65),
	"rede": Color(0.64, 0.1, 0.85),
	"enlace": Color(0.17, 0.29, 0.9),
	"fisica": Color(1.0, 0.87, 0.13),
}


# ============================================================
# ESTADO DO JOGO
# ============================================================

var _osi_jacks: Dictionary = {}
var _tcp_jacks: Dictionary = {}
var _connected: Dictionary = {}

var _dragging_from: String = ""
var _drag_pos: Vector2 = Vector2.ZERO


# ============================================================
# FEEDBACK VISUAL
# ============================================================

var _feedback_panel: PanelContainer
var _feedback_label: Label

var _feedback_timer: Timer
var _feedback_tween: Tween

# ============================================================
# READY
# ============================================================

func _ready() -> void:
	$CloseButton.pressed.connect(
		func() -> void:
			hide()
	)

	_criar_feedback()
	_build()


# ============================================================
# CONSTRUIR INTERFACE
# ============================================================

func _build() -> void:
	var osi_cabinet: TextureRect = $OsiCabinet as TextureRect
	var tcp_cabinet: TextureRect = $TcpCabinet as TextureRect

	var osi_tex: Texture2D = load(OSI_IMG) as Texture2D
	var tcp_tex: Texture2D = load(TCP_IMG) as Texture2D

	if osi_tex == null:
		push_error(
			"Não foi possível carregar a imagem OSI: " + OSI_IMG
		)
		return

	if tcp_tex == null:
		push_error(
			"Não foi possível carregar a imagem TCP/IP: " + TCP_IMG
		)
		return

	osi_cabinet.texture = osi_tex
	tcp_cabinet.texture = tcp_tex

	osi_cabinet.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tcp_cabinet.expand_mode = TextureRect.EXPAND_IGNORE_SIZE

	osi_cabinet.stretch_mode = TextureRect.STRETCH_SCALE
	tcp_cabinet.stretch_mode = TextureRect.STRETCH_SCALE

	var width: float = CABINET_WIDTH

	var osi_size: Vector2 = osi_tex.get_size()
	var tcp_size: Vector2 = tcp_tex.get_size()

	var osi_scale: float = width / osi_size.x
	var tcp_scale: float = width / tcp_size.x

	osi_cabinet.size = Vector2(
		width,
		osi_size.y * osi_scale
	)

	tcp_cabinet.size = Vector2(
		width,
		tcp_size.y * tcp_scale
	)

	_osi_jacks.clear()
	_tcp_jacks.clear()

	for camada_variant in OSI_CAMADAS:
		var camada: String = str(camada_variant)
		var hole: Rect2 = OSI_BURACOS[camada]

		_osi_jacks[camada] = Rect2(
			osi_cabinet.position + hole.position * osi_scale,
			hole.size * osi_scale
		)

	for camada_variant in TCP_CAMADAS:
		var camada: String = str(camada_variant)
		var hole: Rect2 = TCP_BURACOS[camada]

		_tcp_jacks[camada] = Rect2(
			tcp_cabinet.position + hole.position * tcp_scale,
			hole.size * tcp_scale
		)


# ============================================================
# CRIAR PAINEL DE FEEDBACK
# ============================================================

func _criar_feedback() -> void:
	_feedback_panel = PanelContainer.new()

	_feedback_panel.name = "FeedbackPanel"

	_feedback_panel.set_anchors_preset(
		Control.PRESET_CENTER
	)

	_feedback_panel.custom_minimum_size = Vector2(
		520.0,
		120.0
	)

	_feedback_panel.position = Vector2(
		-260.0,
		-60.0
	)

	_feedback_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_feedback_panel.visible = false

	_feedback_panel.z_index = 100

	add_child(_feedback_panel)


	# ========================================================
	# ESTILO DO PAINEL
	# ========================================================

	var estilo: StyleBoxFlat = StyleBoxFlat.new()

	estilo.bg_color = Color(
		0.03,
		0.04,
		0.06,
		0.88
	)

	estilo.border_color = Color(
		0.35,
		0.75,
		1.0,
		0.85
	)

	estilo.set_border_width_all(2)

	estilo.corner_radius_top_left = 18
	estilo.corner_radius_top_right = 18
	estilo.corner_radius_bottom_left = 18
	estilo.corner_radius_bottom_right = 18

	estilo.shadow_color = Color(
		0.0,
		0.0,
		0.0,
		0.45
	)

	estilo.shadow_size = 12

	estilo.content_margin_left = 28.0
	estilo.content_margin_right = 28.0
	estilo.content_margin_top = 20.0
	estilo.content_margin_bottom = 20.0

	_feedback_panel.add_theme_stylebox_override(
		"panel",
		estilo
	)


	# ========================================================
	# LABEL
	# ========================================================

	_feedback_label = Label.new()

	_feedback_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	_feedback_label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)

	_feedback_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)

	_feedback_label.add_theme_font_size_override(
		"font_size",
		26
	)

	_feedback_label.add_theme_color_override(
		"font_color",
		Color.WHITE
	)

	_feedback_label.add_theme_color_override(
		"font_shadow_color",
		Color(0.0, 0.0, 0.0, 0.75)
	)

	_feedback_label.add_theme_constant_override(
		"shadow_offset_x",
		2
	)

	_feedback_label.add_theme_constant_override(
		"shadow_offset_y",
		2
	)

	_feedback_panel.add_child(
		_feedback_label
	)


	# ========================================================
	# TIMER
	# ========================================================

	_feedback_timer = Timer.new()

	_feedback_timer.one_shot = true
	_feedback_timer.wait_time = 3.0

	add_child(_feedback_timer)

	_feedback_timer.timeout.connect(
		_esconder_feedback
	)


# ============================================================
# MOSTRAR FEEDBACK
# ============================================================

func _mostrar_feedback(
	titulo: String,
	mensagem: String,
	sucesso: bool
) -> void:

	if _feedback_tween != null:
		if _feedback_tween.is_valid():
			_feedback_tween.kill()

	_feedback_timer.stop()

	_feedback_label.text = (
		titulo + "\n" + mensagem
	)

	if sucesso:
		_feedback_label.add_theme_color_override(
			"font_color",
			Color(0.55, 1.0, 0.65)
		)
	else:
		_feedback_label.add_theme_color_override(
			"font_color",
			Color(1.0, 0.45, 0.45)
		)

	_feedback_panel.visible = true

	_feedback_panel.modulate.a = 0.0

	_feedback_panel.scale = Vector2(
		0.88,
		0.88
	)

	_feedback_panel.pivot_offset = (
		_feedback_panel.size / 2.0
	)

	_feedback_tween = create_tween()

	_feedback_tween.set_parallel(true)

	_feedback_tween.tween_property(
		_feedback_panel,
		"modulate:a",
		1.0,
		0.18
	)

	_feedback_tween.tween_property(
		_feedback_panel,
		"scale",
		Vector2.ONE,
		0.22
	).set_trans(
		Tween.TRANS_BACK
	).set_ease(
		Tween.EASE_OUT
	)

	_feedback_timer.start()


# ============================================================
# ESCONDER FEEDBACK
# ============================================================

func _esconder_feedback() -> void:
	if _feedback_panel == null:
		return

	if _feedback_tween != null:
		if _feedback_tween.is_valid():
			_feedback_tween.kill()

	_feedback_tween = create_tween()

	_feedback_tween.tween_property(
		_feedback_panel,
		"modulate:a",
		0.0,
		0.35
	)

	_feedback_tween.tween_callback(
		func() -> void:
			_feedback_panel.visible = false
	)


# ============================================================
# NOMES BONITOS DAS CAMADAS
# ============================================================

func _nome_camada(
	camada: String
) -> String:

	match camada:

		"aplicacao":
			return "Aplicação"

		"apresentacao":
			return "Apresentação"

		"sessao":
			return "Sessão"

		"transporte":
			return "Transporte"

		"rede":
			return "Rede"

		"enlace":
			return "Enlace"

		"fisica":
			return "Física"

		"internet":
			return "Internet"

		"acesso_a_rede":
			return "Acesso à Rede"

		_:
			return camada.capitalize()


# ============================================================
# ENTRADA DO MOUSE
# ============================================================

func _gui_input(
	event: InputEvent
) -> void:

	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = (
			event as InputEventMouseButton
		)

		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return

		# ====================================================
		# COMEÇOU A PUXAR O CABO
		# ====================================================

		if mouse_event.pressed:

			for camada_variant in _osi_jacks:
				var camada: String = str(
					camada_variant
				)

				var jack: Rect2 = _osi_jacks[
					camada
				]

				if (
					jack.has_point(
						mouse_event.position
					)
					and
					not _connected.has(
						camada
					)
				):
					_dragging_from = camada

					_drag_pos = (
						mouse_event.position
					)

					$WireLayer.queue_redraw()

					break


		# ====================================================
		# SOLTOU O CABO
		# ====================================================

		elif _dragging_from != "":

			var hit: String = ""

			for camada_variant in _tcp_jacks:
				var camada: String = str(
					camada_variant
				)

				var jack: Rect2 = _tcp_jacks[
					camada
				]

				if jack.has_point(
					mouse_event.position
				):
					hit = camada
					break


			# =================================================
			# ENCAIXOU EM ALGUMA CAMADA TCP/IP
			# =================================================

			if hit != "":

				var resposta_correta: String = str(
					MAPA_OSI_TCP[
						_dragging_from
					]
				)

				if resposta_correta == hit:

					_connected[
						_dragging_from
					] = hit

					_mostrar_feedback(
						"CONEXÃO CORRETA!",
						"%s → %s" % [
							_nome_camada(
								_dragging_from
							),
							_nome_camada(
								hit
							)
						],
						true
					)


					# =========================================
					# MISSÃO COMPLETA
					# =========================================

					if (
						_connected.size()
						==
						OSI_CAMADAS.size()
					):
						$VictorySound.play()
						_mostrar_feedback(
							"MISSÃO COMPLETA!",
							"Todas as camadas foram conectadas corretamente.",
							true
						)
						_animar_player_vitoria()
						var world: Node = get_tree().current_scene
						if world.has_method("efeito_raio"):
							world.efeito_raio()
				else:

					_mostrar_feedback(
						"CONEXÃO INCORRETA!",
						"%s não corresponde a %s.\nTente novamente." % [
							_nome_camada(
								_dragging_from
							),
							_nome_camada(
								hit
							)
						],
						false
					)


			_dragging_from = ""

			$WireLayer.queue_redraw()


	# ========================================================
	# MOVIMENTO DO CABO
	# ========================================================

	elif (
		event is InputEventMouseMotion
		and
		_dragging_from != ""
	):
		var motion_event: InputEventMouseMotion = (
			event as InputEventMouseMotion
		)

		_drag_pos = motion_event.position

		$WireLayer.queue_redraw()

func _animar_player_vitoria() -> void:
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D

	if player == null:
		push_warning("Player não encontrado no grupo 'player'.")
		return

	var rotacao_inicial: float = player.rotation

	var tween: Tween = create_tween()

	tween.tween_property(
		player,
		"rotation",
		rotacao_inicial + TAU,
		1.0
	).set_trans(
		Tween.TRANS_QUAD
	).set_ease(
		Tween.EASE_IN_OUT
	)

	tween.tween_callback(
		func() -> void:
			player.rotation = rotacao_inicial
	)
