extends Node

func _ready() -> void:
	var layout := get_node("../MapLayout") as Node2D
	var entities := get_node("../Entities") as Node2D
	var slot_script := load("res://scripts/study/map_task_slot.gd") as GDScript
	var seen_slots := {}
	for piece in layout.get_node("Pieces").get_children():
		if not piece is MapRoom:
			continue
		for anchor in piece.get_node("MissionSlots").get_children():
			if not anchor is MapMissionAnchor:
				continue
			if anchor.slot_id == &"" or seen_slots.has(anchor.slot_id):
				push_error("Slot físico vazio ou duplicado: %s" % anchor.slot_id)
				continue
			seen_slots[anchor.slot_id] = true
			var slot := Node2D.new()
			slot.name = String(anchor.slot_id)
			slot.set_script(slot_script)
			slot.set("slot_id", anchor.slot_id)
			slot.position = entities.to_local(anchor.global_position)
			entities.add_child(slot)
			var bounds: Rect2 = slot.floor_bounds(anchor.floor_bounds)
			if bounds.has_area():
				_add_task_floor(slot, bounds)
	var top_left := get_node("../MapTopLeft") as Marker2D
	var bottom_right := get_node("../MapBottomRight") as Marker2D
	var camera := get_node("../Entities/player/Player/Camera2D") as Camera2D
	camera.limit_left = roundi(top_left.global_position.x)
	camera.limit_top = roundi(top_left.global_position.y)
	camera.limit_right = roundi(bottom_right.global_position.x)
	camera.limit_bottom = roundi(bottom_right.global_position.y)

func _add_task_floor(slot: Node2D, bounds: Rect2) -> void:
	var platform := Polygon2D.new()
	platform.name = "TaskFloor"
	platform.z_as_relative = false
	platform.z_index = -1
	platform.polygon = _chamfered_rect(bounds, 12)
	platform.color = Color("263b44")
	platform.draw.connect(_draw_task_floor.bind(platform, bounds))
	slot.add_child(platform)

func _chamfered_rect(bounds: Rect2, cut: float) -> PackedVector2Array:
	var a := bounds.position
	var b := bounds.end
	return PackedVector2Array([
		a + Vector2(cut, 0), Vector2(b.x - cut, a.y),
		Vector2(b.x, a.y + cut), b - Vector2(0, cut),
		b - Vector2(cut, 0), Vector2(a.x + cut, b.y),
		Vector2(a.x, b.y - cut), a + Vector2(0, cut),
	])

func _draw_task_floor(platform: Polygon2D, bounds: Rect2) -> void:
	var surface := _chamfered_rect(bounds.grow(-4), 9)
	platform.draw_colored_polygon(surface, Color("334b54"))
	var rim := _chamfered_rect(bounds.grow(-2), 11)
	rim.append(rim[0])
	platform.draw_polyline(rim, Color("506873"), 2)
	# A quiet edge band separates the inlay from the regular floor tiles.
	for y in [bounds.position.y + 11, bounds.end.y - 13]:
		var left := Vector2(bounds.position.x + 15, y)
		var right := Vector2(bounds.end.x - 15, y)
		platform.draw_line(left, right, Color("39545e"), 2)
		platform.draw_rect(Rect2(left, Vector2(4, 2)), Color("80909a"))
		platform.draw_rect(Rect2(right - Vector2(4, 0), Vector2(4, 2)), Color("80909a"))
