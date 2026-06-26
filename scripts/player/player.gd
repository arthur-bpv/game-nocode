extends CharacterBody2D

const SPEED := 150.0

@export var stats: Resource

func _physics_process(_dadelta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * SPEED
	move_and_slide()
	_update_facing(direction)

func _update_facing(direction: Vector2) -> void:
	if direction != Vector2.ZERO:
		$AnimatedSprite2D.flip_h = direction.x < 0
