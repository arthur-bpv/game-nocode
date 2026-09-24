extends Control


func _draw() -> void:
	var root: Control = get_parent() as Control

	# Cabos já conectados
	for osi_camada_variant in root._connected:
		var osi_camada: String = str(osi_camada_variant)
		var tcp_camada: String = str(root._connected[osi_camada])

		var inicio: Vector2 = root._osi_jacks[osi_camada].get_center()
		var fim: Vector2 = root._tcp_jacks[tcp_camada].get_center()

		var cor: Color = root.CORES.get(
			osi_camada,
			Color.WHITE
		)

		_desenhar_cabo_curvado(
			inicio,
			fim,
			cor
		)

	# Cabo que está sendo arrastado
	if root._dragging_from != "":
		var inicio_drag: Vector2 = root._osi_jacks[
			root._dragging_from
		].get_center()

		var fim_drag: Vector2 = root._drag_pos

		var cor_drag: Color = root.CORES.get(
			root._dragging_from,
			Color.WHITE
		)

		_desenhar_cabo_curvado(
			inicio_drag,
			fim_drag,
			cor_drag
		)


func _desenhar_cabo_curvado(
	inicio: Vector2,
	fim: Vector2,
	cor: Color
) -> void:

	var pontos: PackedVector2Array = _gerar_curva(
		inicio,
		fim
	)

	if pontos.size() < 2:
		return

	# ========================================================
	# SOMBRA
	# ========================================================

	var pontos_sombra: PackedVector2Array = PackedVector2Array()

	for ponto: Vector2 in pontos:
		pontos_sombra.append(
			ponto + Vector2(2.0, 3.0)
		)

	draw_polyline(
		pontos_sombra,
		Color(0.0, 0.0, 0.0, 0.30),
		11.0,
		true
	)

	# ========================================================
	# BORDA ESCURA
	# ========================================================

	draw_polyline(
		pontos,
		Color(0.05, 0.05, 0.05, 1.0),
		9.0,
		true
	)

	# ========================================================
	# CABO PRINCIPAL
	# ========================================================

	draw_polyline(
		pontos,
		cor,
		6.0,
		true
	)

	# ========================================================
	# BRILHO CENTRAL
	# ========================================================

	var brilho: Color = cor.lightened(0.35)
	brilho.a = 0.75

	draw_polyline(
		pontos,
		brilho,
		2.0,
		true
	)

	# ========================================================
	# PONTA DO LADO OSI
	# ========================================================

	_desenhar_ponta_triangular(
		inicio,
		pontos[1],
		cor
	)

	# ========================================================
	# PONTA DO LADO TCP/IP
	# ========================================================

	var ultimo_indice: int = pontos.size() - 1

	_desenhar_ponta_triangular(
		fim,
		pontos[ultimo_indice - 1],
		cor
	)


func _gerar_curva(
	inicio: Vector2,
	fim: Vector2
) -> PackedVector2Array:

	var pontos: PackedVector2Array = PackedVector2Array()

	var distancia_x: float = absf(
		fim.x - inicio.x
	)

	# Quanto os pontos de controle avançam horizontalmente.
	var controle_x: float = maxf(
		distancia_x * 0.35,
		80.0
	)

	# Quanto o cabo "cai" no meio.
	# Aumente para deixar mais pendurado.
	var queda: float = minf(
		80.0,
		distancia_x * 0.12
	)

	var controle_1: Vector2 = Vector2(
		inicio.x + controle_x,
		inicio.y + queda
	)

	var controle_2: Vector2 = Vector2(
		fim.x - controle_x,
		fim.y + queda
	)

	# Quanto maior, mais suave a curva.
	var segmentos: int = 32

	for i: int in range(segmentos + 1):
		var t: float = float(i) / float(segmentos)

		var ponto: Vector2 = inicio.bezier_interpolate(
			controle_1,
			controle_2,
			fim,
			t
		)

		pontos.append(ponto)

	return pontos


func _desenhar_ponta_triangular(
	ponta: Vector2,
	outro_ponto: Vector2,
	cor: Color
) -> void:

	var diferenca: Vector2 = outro_ponto - ponta

	if diferenca.length_squared() <= 0.001:
		return

	var direcao: Vector2 = diferenca.normalized()

	var perpendicular: Vector2 = Vector2(
		-direcao.y,
		direcao.x
	)

	var comprimento: float = 14.0
	var largura: float = 9.0

	# ========================================================
	# BORDA DA PONTA
	# ========================================================

	var comprimento_borda: float = comprimento + 3.0
	var largura_borda: float = largura + 3.0

	var ponta_externa_borda: Vector2 = (
		ponta - direcao * comprimento_borda
	)

	var base_borda_1: Vector2 = (
		ponta + perpendicular * largura_borda
	)

	var base_borda_2: Vector2 = (
		ponta - perpendicular * largura_borda
	)

	var pontos_borda: PackedVector2Array = PackedVector2Array([
		ponta_externa_borda,
		base_borda_1,
		base_borda_2
	])

	draw_colored_polygon(
		pontos_borda,
		Color(0.05, 0.05, 0.05, 1.0)
	)

	# ========================================================
	# PARTE COLORIDA DA PONTA
	# ========================================================

	var ponta_externa: Vector2 = (
		ponta - direcao * comprimento
	)

	var base_1: Vector2 = (
		ponta + perpendicular * largura
	)

	var base_2: Vector2 = (
		ponta - perpendicular * largura
	)

	var pontos_triangulo: PackedVector2Array = PackedVector2Array([
		ponta_externa,
		base_1,
		base_2
	])

	draw_colored_polygon(
		pontos_triangulo,
		cor
	)
