extends SceneTree

const ORIGIN := Vector2(-1792, -512)
const TILE_SET_PATH := "res://assets/sprites/map/netbot_station_tiles.tres"
const MAP_PATH := "res://scenes/world/maps/tile_station.tscn"
const CARDINAL := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
const BEVEL_MASKS := [6, 12, 9, 3]
const OBSERVATION_BAY := Rect2i(94, 2, 12, 4)
const SERVICE_ALCOVE := Rect2i(51, 67, 9, 4)
const SHORT_BEVELS := [
	Vector2i(OBSERVATION_BAY.position.x, OBSERVATION_BAY.position.y),
	Vector2i(OBSERVATION_BAY.end.x - 1, OBSERVATION_BAY.position.y),
	Vector2i(SERVICE_ALCOVE.position.x, SERVICE_ALCOVE.end.y - 1),
	Vector2i(SERVICE_ALCOVE.end.x - 1, SERVICE_ALCOVE.end.y - 1),
]
const ROOMS := [
	["CentralRoom", "sala_central", Rect2i(43, 4, 27, 27), 5, Vector2(0, 180), 0],
	["UpperLeftRoom", "sala_superior_esquerda", Rect2i(7, 4, 23, 26), 4, Vector2(-1250, 40), 1],
	["UpperRightRoom", "sala_superior_direita", Rect2i(86, 4, 28, 27), 2, Vector2(1054, -230), 0],
	["LowerLeftRoom", "sala_inferior_esquerda", Rect2i(9, 41, 25, 20), 0, Vector2(-1416, 1064), 2],
	["LowerCentralRoom", "sala_inferior_central", Rect2i(45, 41, 21, 27), 2, Vector2(-146, 860), 3],
	["SmallLowerRightRoom", "sala_inferior_centro_direita", Rect2i(73, 37, 14, 24), 0, Vector2(809, 1098), 1],
	["LowerRightRoom", "sala_inferior_direita", Rect2i(106, 39, 18, 19), 4, Vector2(1842, 912), 2],
]

func _initialize() -> void:
	_build.call_deferred()

func _build() -> void:
	var tiles := _make_tiles()
	var saved := ResourceSaver.save(tiles, TILE_SET_PATH)
	if saved != OK:
		quit(saved)
		return
	tiles.take_over_path(TILE_SET_PATH)
	var station := Node2D.new()
	station.name = "TileStation"
	var background := Polygon2D.new()
	background.name = "Background"
	background.color = Color("101b27")
	background.polygon = PackedVector2Array([
		Vector2(-2200, -900), Vector2(2460, -900), Vector2(2460, 1900), Vector2(-2200, 1900),
	])
	_add(station, station, background)
	var floor := _make_layer(station, "Floor", tiles, false)
	var walls := _make_layer(station, "Walls", tiles, true)
	var decor := _make_layer(station, "Details", tiles, false)
	var anchors := Node2D.new()
	anchors.name = "Pieces"
	_add(station, station, anchors)

	var walkable := {}
	for room in ROOMS:
		var bounds: Rect2i = room[2]
		_fill(walkable, bounds, room[3])
		_add_room_anchor(station, anchors, room)
		var center := bounds.get_center()
		for offset in [Vector2i(-3, -2), Vector2i(-2, -2), Vector2i(2, -2), Vector2i(3, -2)]:
			decor.set_cell(center + offset, 0, Vector2i(room[5], 3))

	# Observation bay and southern service alcove give their sectors distinct outlines.
	_fill(walkable, OBSERVATION_BAY, 1)
	_fill(walkable, SERVICE_ALCOVE, 1)

	# Straight halls, south spur, the east elbow and the short service connector.
	for bounds in [
		Rect2i(28, 15, 17, 5), Rect2i(68, 15, 20, 5), Rect2i(16, 28, 5, 15),
		Rect2i(32, 48, 15, 6), Rect2i(64, 48, 11, 6), Rect2i(97, 28, 6, 26),
		Rect2i(85, 48, 15, 6), Rect2i(100, 45, 8, 5), Rect2i(53, 29, 7, 14),
	]:
		_fill(walkable, bounds)

	var wall_cells := {}
	for cell: Vector2i in walkable:
		var tile := 1 if posmod(hash(Vector3i(cell.x, cell.y, 0)), 29) < 3 else 0
		floor.set_cell(cell, 0, Vector2i(tile, 0))
		for y in range(-1, 2):
			for x in range(-1, 2):
				var neighbor := cell + Vector2i(x, y)
				if not walkable.has(neighbor):
					wall_cells[neighbor] = true
	for cell: Vector2i in wall_cells:
		var mask := _floor_mask(cell, walkable)
		walls.set_cell(cell, 0, _wall_tile(cell, mask, walkable))

	var atlas := tiles.get_source(0) as TileSetAtlasSource
	var wall_art := atlas.texture.get_image()
	_add_bevel_finishes(station, walls, walkable, wall_art)
	_add_square_corners(station, walls, walkable, wall_art)

	for marking in [
		[Vector2i(36, 17), 6], [Vector2i(78, 17), 6], [Vector2i(39, 50), 6],
		[Vector2i(69, 50), 5], [Vector2i(91, 50), 6], [Vector2i(104, 47), 7],
		[Vector2i(18, 35), 3], [Vector2i(56, 36), 7], [Vector2i(99, 36), 2],
	]:
		floor.set_cell(marking[0], 0, Vector2i(marking[1], 0))

	for detail in [
		[Vector2i(50, 9), 4], [Vector2i(62, 9), 4],
		[Vector2i(13, 10), 7], [Vector2i(24, 10), 4],
		[Vector2i(93, 9), 4], [Vector2i(106, 9), 7],
		[Vector2i(14, 55), 4], [Vector2i(61, 62), 7], [Vector2i(81, 56), 4],
		[Vector2i(54, 33), 5], [Vector2i(58, 33), 5],
		[Vector2i(54, 38), 5], [Vector2i(58, 38), 5],
		[Vector2i(18, 34), 6], [Vector2i(99, 34), 6],
	]:
		decor.set_cell(detail[0], 0, Vector2i(detail[1], 3))

	var scene := PackedScene.new()
	saved = scene.pack(station)
	if saved == OK:
		saved = ResourceSaver.save(scene, MAP_PATH)
	station.free()
	quit(saved)

func _floor_mask(cell: Vector2i, walkable: Dictionary) -> int:
	var mask := 0
	for index in CARDINAL.size():
		if walkable.has(cell + CARDINAL[index]):
			mask |= 1 << index
	return mask

func _wall_tile(cell: Vector2i, mask: int, walkable: Dictionary) -> Vector2i:
	var bevel := BEVEL_MASKS.find(mask)
	if bevel >= 0:
		var tangent := Vector2i(1, -1 if bevel % 2 == 0 else 1)
		# Keep doorway corners square. The ends of the two alcoves use a single-cell bevel.
		if cell in SHORT_BEVELS or _is_bevel_neighbor(cell + tangent, mask, walkable) or _is_bevel_neighbor(cell - tangent, mask, walkable):
			return Vector2i(bevel, 5)
	if mask == 4:
		var phase := posmod(cell.x, 12)
		if phase < 3 and _has_window_span(cell - Vector2i(phase, 0), walkable):
			return Vector2i(phase, 4)
		if phase == 5:
			return Vector2i(3, 4)
		if phase == 8:
			return Vector2i(7, 4)
	elif mask == 1 and posmod(cell.x, 10) == 4:
		return Vector2i(4, 4)
	elif mask == 2 and posmod(cell.y, 9) == 4:
		return Vector2i(5, 4)
	elif mask == 8 and posmod(cell.y, 9) == 4:
		return Vector2i(6, 4)
	return Vector2i(mask % 8, 1 + mask / 8)

func _add_bevel_finishes(station: Node2D, walls: TileMapLayer, walkable: Dictionary, wall_art: Image) -> void:
	var profiles := {}
	var finishes := Node2D.new()
	finishes.name = "BevelFinishes"
	_add(station, station, finishes)
	for cell in walls.get_used_cells():
		var tile := walls.get_cell_atlas_coords(cell)
		if tile.y != 5:
			continue
		var angle := tile.x * PI / 2.0
		var tangent := Vector2i(Vector2(1, -1).rotated(angle).round())
		if walls.get_cell_atlas_coords(cell - tangent) == tile:
			continue
		var run := Node2D.new()
		run.name = "Chamfer_%d_%d" % [cell.x, cell.y]
		_add(station, finishes, run)
		var end_cell := cell
		while walls.get_cell_atlas_coords(end_cell + tangent) == tile:
			end_cell += tangent
		var start := _bevel_point(cell, Vector2(0, 32), angle)
		var end := _bevel_point(end_cell, Vector2(32, 0), angle)
		# Alcoves may connect two horizontal walls, so the join cannot use
		# one fixed horizontal and one fixed vertical edge.
		var start_out := _bevel_join_normal(cell, angle, Vector2(-1, 1), Vector2.UP, Vector2.LEFT, walkable)
		var end_out := _bevel_join_normal(end_cell, angle, Vector2(1, -1), Vector2.LEFT, Vector2.UP, walkable)

		var current := cell
		while true:
			_add_finish_polygon(station, run, "Floor_%d_%d" % [current.x, current.y], [
				_bevel_point(current, Vector2(0, 32), angle),
				_bevel_point(current, Vector2(32, 32), angle),
				_bevel_point(current, Vector2(32, 0), angle),
			], Color("324e55"))
			if current == end_cell:
				break
			current += tangent

		var face := _add_finish_polygon(station, run, "Face", [
			start, end, end + end_out * 32.0, start + start_out * 32.0,
		], Color.WHITE, true)
		var key := Vector4i(int(start_out.x), int(start_out.y), int(end_out.x), int(end_out.y))
		if not profiles.has(key):
			profiles[key] = _make_wall_profile(wall_art, start_out, end_out)
		face.texture = profiles[key]
		face.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		face.uv = PackedVector2Array([
			Vector2(0.5, 0.5), Vector2(1.5, 0.5), Vector2(1.5, 31.5), Vector2(0.5, 31.5),
		])

func _bevel_join_normal(cell: Vector2i, angle: float, probe: Vector2,
		with_floor: Vector2, without_floor: Vector2, walkable: Dictionary) -> Vector2:
	var has_floor := walkable.has(cell + Vector2i(probe.rotated(angle).round()))
	var normal := with_floor if has_floor else without_floor
	return normal.rotated(angle).round()

func _make_wall_profile(atlas: Image, start_out: Vector2, end_out: Vector2) -> ImageTexture:
	var profile := Image.create_empty(2, 32, false, Image.FORMAT_RGBA8)
	var directions := [Vector2i(start_out), Vector2i(end_out)]
	for column in directions.size():
		var outward: Vector2i = directions[column]
		for depth in 32:
			profile.set_pixel(column, depth, _wall_profile_pixel(atlas, outward, depth))
	return ImageTexture.create_from_image(profile)

func _wall_profile_pixel(atlas: Image, outward: Vector2i, depth: int) -> Color:
	var mask := 1 << CARDINAL.find(-outward)
	var tile_origin := Vector2i(mask % 8, 1 + mask / 8) * 32
	var inner := (Vector2i(16, 16) - outward * 16).clamp(Vector2i.ZERO, Vector2i(31, 31))
	return atlas.get_pixelv(tile_origin + inner + outward * depth)

func _add_square_corners(station: Node2D, walls: TileMapLayer, walkable: Dictionary, wall_art: Image) -> void:
	var corners := Node2D.new()
	corners.name = "SquareWallCorners"
	corners.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_add(station, station, corners)
	var textures := {}
	for cell in walls.get_used_cells():
		# The empty atlas tile already provides collision outside the corner.
		if walls.get_cell_atlas_coords(cell) != Vector2i(0, 1):
			continue
		for diagonal in [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1), Vector2i(1, -1)]:
			if not walkable.has(cell + diagonal):
				continue
			var horizontal := Vector2i(diagonal.x, 0)
			var vertical := Vector2i(0, diagonal.y)
			if _floor_mask(cell + horizontal, walkable) != (1 << CARDINAL.find(vertical)):
				continue
			if _floor_mask(cell + vertical, walkable) != (1 << CARDINAL.find(horizontal)):
				continue
			if not textures.has(diagonal):
				textures[diagonal] = _make_corner_texture(wall_art, horizontal, vertical)
			var corner := Sprite2D.new()
			corner.name = "Corner_%d_%d" % [cell.x, cell.y]
			corner.texture = textures[diagonal]
			corner.position = walls.position + walls.map_to_local(cell)
			_add(station, corners, corner)
			break

func _make_corner_texture(atlas: Image, horizontal: Vector2i, vertical: Vector2i) -> ImageTexture:
	var image := Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var depth_x := 31 - x if horizontal.x > 0 else x
			var depth_y := 31 - y if vertical.y > 0 else y
			var color := _wall_profile_pixel(atlas, -vertical, depth_y) if depth_x <= depth_y else _wall_profile_pixel(atlas, -horizontal, depth_x)
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)

func _bevel_point(cell: Vector2i, point: Vector2, angle: float) -> Vector2:
	var half := Vector2(16, 16)
	return ORIGIN + Vector2(cell) * 32.0 + half + (point - half).rotated(angle).round()

func _add_finish_polygon(station: Node2D, run: Node2D, label: String,
		points: PackedVector2Array, color: Color, antialias := false) -> Polygon2D:
	var polygon := Polygon2D.new()
	polygon.name = label
	polygon.polygon = points
	polygon.color = color
	polygon.antialiased = antialias
	_add(station, run, polygon)
	return polygon

func _is_bevel_neighbor(cell: Vector2i, mask: int, walkable: Dictionary) -> bool:
	return not walkable.has(cell) and _floor_mask(cell, walkable) == mask

func _has_window_span(first: Vector2i, walkable: Dictionary) -> bool:
	for index in 3:
		var cell := first + Vector2i(index, 0)
		if walkable.has(cell) or not walkable.has(cell + Vector2i.DOWN):
			return false
		if walkable.has(cell + Vector2i.UP) or walkable.has(cell + Vector2i.LEFT) or walkable.has(cell + Vector2i.RIGHT):
			return false
	return true

func _make_tiles() -> TileSet:
	var tiles := TileSet.new()
	tiles.tile_size = Vector2i(32, 32)
	tiles.add_physics_layer()
	tiles.set_physics_layer_collision_layer(0, 1)
	var source := TileSetAtlasSource.new()
	source.texture = load("res://assets/sprites/map/netbot_station_tiles.png")
	source.texture_region_size = tiles.tile_size
	tiles.add_source(source, 0)
	for y in 6:
		for x in (4 if y == 5 else 8):
			var cell := Vector2i(x, y)
			source.create_tile(cell)
			if y in [1, 2, 4, 5]:
				var data := source.get_tile_data(cell, 0)
				data.add_collision_polygon(0)
				var points := PackedVector2Array([
					Vector2(-16, -16), Vector2(16, -16), Vector2(16, 16), Vector2(-16, 16),
				])
				if y == 5:
					data.modulate = Color.TRANSPARENT
					points.remove_at(2)
					for index in points.size():
						points[index] = points[index].rotated(x * PI / 2.0).round()
				data.set_collision_polygon_points(0, 0, points)
	return tiles

func _make_layer(station: Node2D, layer_name: String, tiles: TileSet, solid: bool) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = layer_name
	layer.position = ORIGIN
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.tile_set = tiles
	layer.collision_enabled = solid
	_add(station, station, layer)
	return layer

func _fill(cells: Dictionary, bounds: Rect2i, bevel: int = 0) -> void:
	for y in range(bounds.position.y, bounds.end.y):
		for x in range(bounds.position.x, bounds.end.x):
			var dx := mini(x - bounds.position.x, bounds.end.x - 1 - x)
			var dy := mini(y - bounds.position.y, bounds.end.y - 1 - y)
			if dx + dy >= bevel:
				cells[Vector2i(x, y)] = true

func _add_room_anchor(station: Node2D, parent: Node2D, definition: Array) -> void:
	var room := MapRoom.new()
	room.name = definition[0]
	room.area_id = StringName(definition[1])
	room.position = definition[4]
	_add(station, parent, room)
	var slots := Node2D.new()
	slots.name = "MissionSlots"
	_add(station, room, slots)
	var anchor := MapMissionAnchor.new()
	anchor.name = "Primary"
	anchor.slot_id = StringName(definition[1] + "_principal")
	_add(station, slots, anchor)

func _add(station: Node2D, parent: Node, child: Node) -> void:
	parent.add_child(child)
	child.owner = station
