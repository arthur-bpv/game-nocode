extends Control

# Rects reais (px nativos) dos pinos ja desenhados na arte de cada armario
# (achados analisando classifica_osi.png / classifica_tcp.png por cor).
# Mapa OSI -> TCP/IP e a equivalencia classica entre os dois modelos.

const OSI_IMG := "res://assets/ui/classifica/classifica_osi.png"
const TCP_IMG := "res://assets/ui/classifica/classifica_tcp.png"
const CABINET_WIDTH := 300.0

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

var _osi_jacks: Dictionary = {}
var _tcp_jacks: Dictionary = {}
var _connected: Dictionary = {}
var _dragging_from: String = ""
var _drag_pos: Vector2 = Vector2.ZERO

func _ready() -> void:
	$CloseButton.pressed.connect(func(): hide())
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
	var osi_scale: float = width / osi_tex.get_size().x
	var tcp_scale: float = width / tcp_tex.get_size().x
	osi_cabinet.size = Vector2(width, osi_tex.get_size().y * osi_scale)
	tcp_cabinet.size = Vector2(width, tcp_tex.get_size().y * tcp_scale)

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
					if _connected.size() == OSI_CAMADAS.size():
						$StatusLabel.text = "Missão completa!"
				else:
					$StatusLabel.text = "Errado: %s não conecta em %s" % [_dragging_from, hit]
			_dragging_from = ""
			$WireLayer.queue_redraw()
	elif event is InputEventMouseMotion and _dragging_from != "":
		_drag_pos = event.position
		$WireLayer.queue_redraw()
