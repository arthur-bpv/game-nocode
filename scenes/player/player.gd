extends CharacterBody2D

@export var speed: float = 220.0

var _estava_colidindo: bool = false


func _physics_process(_delta: float) -> void:
	var direction: Vector2 = Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)

	velocity = direction * speed

	move_and_slide()

	_verificar_colisao_parede()


func _verificar_colisao_parede() -> void:
	var esta_colidindo: bool = get_slide_collision_count() > 0

	if esta_colidindo and not _estava_colidindo:
		if has_node("WallHitSound"):
			$WallHitSound.play()
		else:
			print("não encontrado")

	_estava_colidindo = esta_colidindo
