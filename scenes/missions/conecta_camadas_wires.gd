extends Control

# Desenha acima dos armários e dos labels sem alterar as áreas de clique.
func _draw() -> void:
	var mission := get_parent()
	for osi_layer in mission._connected:
		var tcp_layer: String = mission._connected[osi_layer]
		_draw_wire(
			mission._osi_jacks[osi_layer].get_center(),
			mission._tcp_jacks[tcp_layer].get_center(),
			mission.CORES.get(osi_layer, Color.WHITE)
		)
	if mission._dragging_from != "":
		_draw_wire(
			mission._osi_jacks[mission._dragging_from].get_center(),
			mission._drag_pos,
			mission.CORES.get(mission._dragging_from, Color.WHITE)
		)

func _draw_wire(start: Vector2, finish: Vector2, color: Color) -> void:
	var points := _curve(start, finish)
	var shadow := PackedVector2Array()
	for point in points:
		shadow.append(point + Vector2(2, 3))
	draw_polyline(shadow, Color(0, 0, 0, 0.3), 10.0, true)
	draw_polyline(points, Color(0.05, 0.05, 0.05), 8.0, true)
	draw_polyline(points, color, 6.0, true)
	var highlight := color.lightened(0.35)
	highlight.a = 0.7
	draw_polyline(points, highlight, 2.0, true)
	_draw_tip(start, points[1], color)
	_draw_tip(finish, points[points.size() - 2], color)

func _curve(start: Vector2, finish: Vector2) -> PackedVector2Array:
	var distance_x := absf(finish.x - start.x)
	# Os conectores ficam próximos: os controles não podem cruzar um pelo outro.
	var control_x := minf(80.0, distance_x * 0.4)
	var direction := signf(finish.x - start.x)
	var sag := minf(32.0, distance_x * 0.12 + absf(finish.y - start.y) * 0.05)
	var first_control := start + Vector2(control_x * direction, sag)
	var second_control := finish + Vector2(-control_x * direction, sag)
	var points := PackedVector2Array()
	for index in range(25):
		points.append(start.bezier_interpolate(first_control, second_control, finish, float(index) / 24.0))
	return points

func _draw_tip(tip: Vector2, neighbor: Vector2, color: Color) -> void:
	var delta := neighbor - tip
	if delta.length_squared() < 0.001:
		return
	var direction := delta.normalized()
	var side := Vector2(-direction.y, direction.x)
	draw_colored_polygon(PackedVector2Array([
		tip - direction * 13.0,
		tip + side * 8.0,
		tip - side * 8.0,
	]), Color(0.05, 0.05, 0.05))
	draw_colored_polygon(PackedVector2Array([
		tip - direction * 10.0,
		tip + side * 6.0,
		tip - side * 6.0,
	]), color)
