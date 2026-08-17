extends StaticBody2D

# The map is a single Sprite2D rather than a TileMap with physics data. Build
# segment colliders from its green floor area so every visible wall blocks the
# CharacterBody2D, including diagonal walls, without duplicating map geometry.
const GREEN_DIFFERENCE := 0.08
const POLYGON_SIMPLIFICATION := 2.0

func _ready() -> void:
	var map_sprite := get_parent() as Sprite2D
	if map_sprite == null or map_sprite.texture == null:
		push_error("WorldWalls precisa ser filho do Sprite2D do mapa.")
		return

	var map_image := map_sprite.texture.get_image()
	var floor_mask := BitMap.new()
	floor_mask.create(map_image.get_size())

	for y in map_image.get_height():
		for x in map_image.get_width():
			var pixel := map_image.get_pixel(x, y)
			# The walkable floor is green; walls/background are neutral gray.
			floor_mask.set_bitv(Vector2i(x, y), pixel.g - pixel.r > GREEN_DIFFERENCE)

	var map_center := Vector2(map_image.get_size()) * 0.5
	for outline in floor_mask.opaque_to_polygons(Rect2i(Vector2i.ZERO, map_image.get_size()), POLYGON_SIMPLIFICATION):
		var wall := CollisionPolygon2D.new()
		wall.build_mode = CollisionPolygon2D.BUILD_SEGMENTS
		var local_outline := PackedVector2Array()
		for point in outline:
			local_outline.append(point - map_center)
		wall.polygon = local_outline
		add_child(wall)
