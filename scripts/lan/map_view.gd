extends Control

var layout: Dictionary
var role := 0
var targets: Dictionary = {}
var avatars: Dictionary = {}

func ingest(positions: Array) -> void:
	for entry in positions:
		var index := int(entry.role)
		var point := Vector2(entry.x, entry.y)
		targets[index] = point
		if not avatars.has(index):
			avatars[index] = point

func _process(delta: float) -> void:
	for index in targets:
		var current: Vector2 = avatars[index]
		avatars[index] = current.lerp(targets[index], 1.0 - exp(-delta * 18.0))
	queue_redraw()

func _draw() -> void:
	if layout.is_empty():
		return
	var map_size := Vector2(layout.width, layout.height)
	var scale_factor := minf(size.x / map_size.x, size.y / map_size.y)
	var offset := (size - map_size * scale_factor) * 0.5
	draw_set_transform(offset, 0, Vector2.ONE * scale_factor)
	draw_rect(Rect2(Vector2.ZERO, map_size), Color("#142933"))
	draw_rect(Rect2(Vector2.ZERO, map_size), Color("#4d7080"), false, 2)
	for wall in layout.walls:
		draw_rect(Rect2(wall[0], wall[1], wall[2], wall[3]), Color("#517180"))
	var center := Vector2(layout.terminal[0], layout.terminal[1])
	draw_arc(center, layout.interaction_radius, 0, TAU, 48, Color("#7e8b52"), 2, true)
	draw_rect(Rect2(center - Vector2(16, 13), Vector2(32, 26)), Color("#e8c665"))
	for index in avatars:
		draw_circle(avatars[index], 12, Color("#74dbdf") if index == role else Color("#ecaa79"))
