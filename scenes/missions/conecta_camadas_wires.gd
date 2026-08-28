extends Control

# Camada separada só pra desenhar o fio. Godot desenha pai antes dos
# filhos, entao desenhar na raiz fazia o fio passar por baixo dos
# TextureRect dos armarios. Esse no e o ultimo filho -> desenha por cima.

func _draw() -> void:
	var root = get_parent()
	for osi_camada in root._connected:
		var tcp_camada: String = root._connected[osi_camada]
		draw_line(
			root._osi_jacks[osi_camada].get_center(),
			root._tcp_jacks[tcp_camada].get_center(),
			root.CORES.get(osi_camada, Color.WHITE),
			4.0, true
		)
	if root._dragging_from != "":
		draw_line(
			root._osi_jacks[root._dragging_from].get_center(),
			root._drag_pos,
			Color.WHITE, 3.0, true
		)
