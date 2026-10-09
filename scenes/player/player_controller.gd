extends CharacterBody2D

const SPEED := 460.0
const COLLISION_RECOVERY_MARGIN := 2.0

func _ready() -> void:
	safe_margin = COLLISION_RECOVERY_MARGIN

func _physics_process(_delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * SPEED
	move_and_slide()
