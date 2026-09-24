extends Node2D

func efeito_raio() -> void:
	var efeito: CanvasModulate = $LightningEffect

	var tween: Tween = create_tween()

	# Primeiro clarão
	tween.tween_property(
		efeito,
		"color",
		Color(0.65, 0.75, 1.0),
		0.08
	)

	# Escurece
	tween.tween_property(
		efeito,
		"color",
		Color(0.15, 0.18, 0.30),
		0.10
	)

	# Segundo clarão
	tween.tween_property(
		efeito,
		"color",
		Color(0.85, 0.90, 1.0),
		0.06
	)

	# Escurece novamente
	tween.tween_property(
		efeito,
		"color",
		Color(0.20, 0.22, 0.32),
		0.12
	)

	# Mantém uma tonalidade azulada por alguns segundos
	tween.tween_property(
		efeito,
		"color",
		Color(0.45, 0.55, 0.80),
		2.2
	)

	# Volta ao normal
	tween.tween_property(
		efeito,
		"color",
		Color.WHITE,
		0.45
	)
