extends Control

var _floor_runs: Array[Rect2] = []
var _wall_runs: Array[Rect2] = []
var _bounds := Rect2()
var _player: Node2D
var _last_position := Vector2.INF

func configure(floor_layer: TileMapLayer, wall_layer: TileMapLayer, player: Node2D) -> void:
	_floor_runs = _build_runs(floor_layer)
	_wall_runs = _build_runs(wall_layer)
	_bounds = Rect2()
	for area in _floor_runs + _wall_runs:
		_bounds = area if not _bounds.has_area() else _bounds.merge(area)
	_player = player
	_last_position = Vector2.INF
	queue_redraw()

func has_layout() -> bool:
	return _bounds.has_area()

func map_area() -> Rect2:
	if not has_layout():
		return Rect2()
	var available := (size - Vector2(32, 32)).max(Vector2.ZERO)
	var fitted := _bounds.size * minf(available.x / _bounds.size.x, available.y / _bounds.size.y)
	return Rect2((size - fitted) * 0.5, fitted)

func world_to_map_position(point: Vector2) -> Vector2:
	if not has_layout():
		return Vector2.ZERO
	var area := map_area()
	return area.position + (point - _bounds.position) * area.size / _bounds.size

func player_position() -> Vector2:
	if not is_instance_valid(_player):
		return Vector2.ZERO
	return world_to_map_position(_player.global_position)

func _process(_delta: float) -> void:
	if not is_visible_in_tree() or not is_instance_valid(_player):
		return
	if _last_position != _player.global_position:
		_last_position = _player.global_position
		queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("101b27"))
	draw_rect(Rect2(Vector2.ZERO, size), Color("344c60"), false, 2.0)
	if not has_layout():
		return
	for area in _floor_runs:
		_draw_run(area, Color("355a62"))
	for area in _wall_runs:
		_draw_run(area, Color("7597aa"))
	if is_instance_valid(_player):
		var marker := player_position()
		if map_area().grow(0.5).has_point(marker):
			draw_rect(Rect2(marker - Vector2(7, 7), Vector2(14, 14)), Color("111c2a"))
			draw_rect(Rect2(marker - Vector2(4, 4), Vector2(8, 8)), Color("ff8a75"))

func _draw_run(area: Rect2, color: Color) -> void:
	var start := world_to_map_position(area.position)
	draw_rect(Rect2(start, world_to_map_position(area.end) - start), color)

func _build_runs(layer: TileMapLayer) -> Array[Rect2]:
	var runs: Array[Rect2] = []
	if layer == null or layer.tile_set == null:
		return runs
	var rows := {}
	for cell in layer.get_used_cells():
		if not rows.has(cell.y):
			rows[cell.y] = []
		rows[cell.y].append(cell.x)
	var half_tile := Vector2(layer.tile_set.tile_size) * 0.5
	for y: int in rows:
		var columns: Array = rows[y]
		columns.sort()
		var first: int = columns[0]
		var last := first
		for index in range(1, columns.size()):
			var column: int = columns[index]
			if column != last + 1:
				runs.append(_run_bounds(layer, first, last, y, half_tile))
				first = column
			last = column
		runs.append(_run_bounds(layer, first, last, y, half_tile))
	return runs

func _run_bounds(layer: TileMapLayer, first: int, last: int, row: int, half_tile: Vector2) -> Rect2:
	var start := layer.to_global(layer.map_to_local(Vector2i(first, row)) - half_tile)
	var end := layer.to_global(layer.map_to_local(Vector2i(last, row)) + half_tile)
	return Rect2(start, end - start)
