extends SceneTree

const MAP_TEXTURE_PATH := "res://assets/sprites/Mapa.png"
const MAP_MASK_PATH := "res://assets/sprites/Mapa_anotacoes.png"
const OUTPUT_PATH := "res://assets/generated/collision_polygons.tres"
const POLYGON_SIMPLIFICATION := 2.0
const CollisionData := preload("res://scripts/resources/collision_polygon_data.gd")

func _initialize() -> void:
	_generate.call_deferred()

func _generate() -> void:
	var map_texture := load(MAP_TEXTURE_PATH) as Texture2D
	var mask_texture := load(MAP_MASK_PATH) as Texture2D
	if map_texture == null or mask_texture == null:
		push_error("Não foi possível carregar o mapa ou sua máscara anotada.")
		quit(1)
		return

	var map_image := map_texture.get_image()
	var mask_image := mask_texture.get_image()
	var map_scale := Vector2(map_image.get_size()) / Vector2(mask_image.get_size())
	if not is_equal_approx(map_scale.x, map_scale.y):
		push_error("Mapa e máscara anotada precisam ter a mesma proporção.")
		quit(1)
		return

	var floor_mask := BitMap.new()
	floor_mask.create(mask_image.get_size())
	var blocked_mask := BitMap.new()
	blocked_mask.create(mask_image.get_size())

	for y in mask_image.get_height():
		for x in mask_image.get_width():
			var annotation_pixel := mask_image.get_pixel(x, y)
			var map_position := Vector2i(
				mini(int((x + 0.5) * map_scale.x), map_image.get_width() - 1),
				mini(int((y + 0.5) * map_scale.y), map_image.get_height() - 1)
			)
			var map_pixel := map_image.get_pixelv(map_position)
			var bridges_annotation_gap := not _is_red(annotation_pixel) and _is_map_floor(map_pixel)
			var is_walkable := _is_walkable(annotation_pixel) or bridges_annotation_gap
			floor_mask.set_bitv(Vector2i(x, y), is_walkable)
			blocked_mask.set_bitv(Vector2i(x, y), not is_walkable)

	var map_center := Vector2(map_image.get_size()) * 0.5
	var polygons: Array[PackedVector2Array] = []
	for outline in floor_mask.opaque_to_polygons(Rect2i(Vector2i.ZERO, mask_image.get_size()), POLYGON_SIMPLIFICATION):
		polygons.append(_to_map_coordinates(outline, map_scale, map_center))
	for outline in blocked_mask.opaque_to_polygons(Rect2i(Vector2i.ZERO, mask_image.get_size()), POLYGON_SIMPLIFICATION):
		if not _touches_mask_border(outline, mask_image.get_size()):
			polygons.append(_to_map_coordinates(outline, map_scale, map_center))

	var data := CollisionData.new()
	data.polygons = polygons
	var error := ResourceSaver.save(data, OUTPUT_PATH)
	if error != OK:
		push_error("Falha ao salvar colisões: %s" % error)
		quit(1)
		return
	print("Generated %d collision polygons at %s" % [polygons.size(), OUTPUT_PATH])
	quit()

func _to_map_coordinates(outline: PackedVector2Array, map_scale: Vector2, map_center: Vector2) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	for point in outline:
		polygon.append(point * map_scale - map_center)
	return polygon

func _touches_mask_border(outline: PackedVector2Array, mask_size: Vector2i) -> bool:
	for point in outline:
		if point.x <= 0 or point.y <= 0 or point.x >= mask_size.x or point.y >= mask_size.y:
			return true
	return false

func _is_walkable(pixel: Color) -> bool:
	var is_yellow := pixel.r > 0.75 and pixel.g > 0.65 and pixel.b < 0.45
	var is_blue := pixel.b > 0.55 and pixel.r < 0.45 and pixel.g < 0.55
	var is_green := pixel.g > 0.70 and pixel.r < 0.45 and pixel.b < 0.45
	return is_yellow or is_blue or is_green

func _is_red(pixel: Color) -> bool:
	return pixel.r > 0.45 and pixel.g < 0.30 and pixel.b < 0.30

func _is_map_floor(pixel: Color) -> bool:
	return pixel.g - pixel.r > 0.08

