extends StaticBody2D

const COLLISION_DATA_PATH := "res://assets/generated/collision_polygons.tres"

func _ready() -> void:
	var collision_data := load(COLLISION_DATA_PATH)
	if collision_data == null:
		push_error("Colisões do mapa ausentes. Execute tools/generate_collision_polygons.gd.")
		return
	for polygon in collision_data.polygons:
		var wall := CollisionPolygon2D.new()
		wall.build_mode = CollisionPolygon2D.BUILD_SEGMENTS
		wall.polygon = polygon
		add_child(wall)
