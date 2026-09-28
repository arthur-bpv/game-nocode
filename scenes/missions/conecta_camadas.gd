extends Control

signal completed

# Rects reais (px nativos) dos pinos ja desenhados na arte de cada armario
# (achados analisando classifica_osi.png / classifica_tcp.png por cor).
# Mapa OSI -> TCP/IP e a equivalencia classica entre os dois modelos.

const OSI_IMG := "res://assets/ui/classifica/classifica_osi_sem_texto.png"
const TCP_IMG := "res://assets/ui/classifica/classifica_tcp_sem_texto.png"
const CABINET_WIDTH := 300.0
# Coordenadas de autoria independem da resolução importada da textura.
const OSI_SOURCE_SIZE := Vector2(4898, 6258)
const TCP_SOURCE_SIZE := Vector2(4734, 6211)

const OSI_CAMADAS := ["aplicacao", "apresentacao", "sessao", "transporte", "rede", "enlace", "fisica"]
const TCP_CAMADAS := ["aplicacao", "transporte", "internet", "acesso_a_rede"]

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
var _dragging_from: String = ""
var _drag_pos: Vector2 = Vector2.ZERO
var _feedback_tween: Tween

@onready var _feedback_panel: PanelContainer = $FeedbackPanel
@onready var _feedback_label: Label = $FeedbackPanel/FeedbackLabel
@onready var _feedback_timer: Timer = $FeedbackTimer
@onready var _victory_sound: AudioStreamPlayer = $VictorySound

func _ready() -> void:
	$CloseButton.pressed.connect(func(): hide())
	_feedback_timer.timeout.connect(_hide_feedback)
	_build()

func _build() -> void:
	var osi_cabinet := $OsiCabinet as TextureRect
	var tcp_cabinet := $TcpCabinet as TextureRect

	var osi_tex: Texture2D = load(OSI_IMG)
	var tcp_tex: Texture2D = load(TCP_IMG)

	osi_cabinet.texture = osi_tex
	tcp_cabinet.texture = tcp_tex
	# expand_mode default (KEEP_SIZE) usa o tamanho nativo da textura como
	# minimo, ignorando .size. Os PNGs sao gigantes (ate 4898x6258px).
	osi_cabinet.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tcp_cabinet.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	osi_cabinet.stretch_mode = TextureRect.STRETCH_SCALE
	tcp_cabinet.stretch_mode = TextureRect.STRETCH_SCALE

	var width: float = CABINET_WIDTH
	var osi_scale: float = width / OSI_SOURCE_SIZE.x
	var tcp_scale: float = width / TCP_SOURCE_SIZE.x
	osi_cabinet.size = Vector2(width, OSI_SOURCE_SIZE.y * osi_scale)
	tcp_cabinet.size = Vector2(width, TCP_SOURCE_SIZE.y * tcp_scale)

	for camada in OSI_CAMADAS:
		var hole: Rect2 = OSI_BURACOS[camada]
		_osi_jacks[camada] = Rect2(osi_cabinet.position + hole.position * osi_scale, hole.size * osi_scale)
	for camada in TCP_CAMADAS:
		var hole: Rect2 = TCP_BURACOS[camada]
		_tcp_jacks[camada] = Rect2(tcp_cabinet.position + hole.position * tcp_scale, hole.size * tcp_scale)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			for camada in _osi_jacks:
				if _osi_jacks[camada].has_point(event.position) and not _connected.has(camada):
					_dragging_from = camada
					_drag_pos = event.position
					$WireLayer.queue_redraw()
					break
		elif _dragging_from != "":
			var hit := ""
			for camada in _tcp_jacks:
				if _tcp_jacks[camada].has_point(event.position):
					hit = camada
					break
			if hit != "":
				if MAPA_OSI_TCP[_dragging_from] == hit:
					_connected[_dragging_from] = hit
					$StatusLabel.text = "Certo: %s -> %s" % [_dragging_from, hit]
					_show_feedback("CONEXÃO CORRETA!", "%s → %s" % [NOMES_CAMADAS[_dragging_from], NOMES_CAMADAS[hit]], true)
					if _connected.size() == OSI_CAMADAS.size():
						$StatusLabel.text = "Missão completa!"
						_show_feedback("MISSÃO COMPLETA!", "Todas as camadas foram conectadas.", true)
						_victory_sound.play()
						completed.emit()
				else:
					$StatusLabel.text = "Errado: %s não conecta em %s" % [_dragging_from, hit]
					_show_feedback("CONEXÃO INCORRETA!", "%s não corresponde a %s. Tente novamente." % [NOMES_CAMADAS[_dragging_from], NOMES_CAMADAS[hit]], false)
			_dragging_from = ""
			$WireLayer.queue_redraw()
	elif event is InputEventMouseMotion and _dragging_from != "":
		_drag_pos = event.position
		$WireLayer.queue_redraw()


func restore_completed() -> void:
	_connected = MAPA_OSI_TCP.duplicate()
	_dragging_from = ""
	# O slot também restaura o estado logo após o sinal completed. Nesse caso,
	# mantém o feedback final até o timer terminar.
	if _feedback_timer.is_stopped():
		_feedback_panel.hide()
	$StatusLabel.text = "Missão completa!"
	$WireLayer.queue_redraw()

func _show_feedback(title: String, detail: String, success: bool) -> void:
	if _feedback_tween != null and _feedback_tween.is_valid():
		_feedback_tween.kill()
	_feedback_timer.stop()
	_feedback_label.text = title + "\n" + detail
	_feedback_label.add_theme_color_override("font_color", Color("8dffa6") if success else Color("ff8080"))
	_feedback_panel.show()
	_feedback_panel.modulate.a = 0.0
	_feedback_panel.scale = Vector2(0.94, 0.94)
	_feedback_panel.pivot_offset = _feedback_panel.size / 2.0
	_feedback_tween = create_tween().set_parallel(true)
	_feedback_tween.tween_property(_feedback_panel, "modulate:a", 1.0, 0.18)
	_feedback_tween.tween_property(_feedback_panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_feedback_timer.start()

func _hide_feedback() -> void:
	if _feedback_tween != null and _feedback_tween.is_valid():
		_feedback_tween.kill()
	_feedback_tween = create_tween()
	_feedback_tween.tween_property(_feedback_panel, "modulate:a", 0.0, 0.25)
	_feedback_tween.tween_callback(_feedback_panel.hide)
