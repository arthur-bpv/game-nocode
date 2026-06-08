extends CharacterBody2D

@onready var sprite = $Sprite2D

var speed = 200

func _process(delta):

	if Input.is_action_pressed("left"):
		position.x -= speed * delta
		sprite.scale.x = -1

	if Input.is_action_pressed("right"):
		position.x += speed * delta
		sprite.scale.x = 1
