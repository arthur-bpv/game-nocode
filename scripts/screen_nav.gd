extends Node

@export var back_scene_path: String = ""

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		go_back()

func go_back():
	if back_scene_path != "":
		get_tree().change_scene_to_file(back_scene_path)
