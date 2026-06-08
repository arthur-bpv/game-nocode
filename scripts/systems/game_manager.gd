extends Node

signal player_died
signal level_completed

var current_level: int = 1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
