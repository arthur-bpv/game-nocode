extends Control
class_name SettingsScreen

@onready var volume_screen: Control = $Volume

func _ready() -> void:
	volume_screen.back_requested.connect(_on_back_requested)
	volume_screen.open_screen()

func _on_back_requested() -> void:
	SceneTransition.change_scene("res://scenes/menu.tscn")
