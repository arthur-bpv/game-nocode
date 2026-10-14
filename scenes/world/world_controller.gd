extends Node

@onready var tablet: Control = get_node("../TabletUi")
@onready var pause_menu: Control = get_node("../Pause")

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if tablet.visible:
		tablet.close_ui()
	elif pause_menu.visible:
		pause_menu.handle_cancel()
	else:
		pause_menu.open_pause()
	get_viewport().set_input_as_handled()


func _ready() -> void:
	BackgroundMusic.stop_menu()
	SoundEffects.set_world_ambience_enabled(true)
	for slot in get_tree().get_nodes_in_group("study_task_slots"):
		slot.open_requested.connect(_open_task)


func _exit_tree() -> void:
	SoundEffects.set_world_ambience_enabled(false)

func _open_task(mission: Control) -> void:
	if not tablet.visible and not pause_menu.visible:
		tablet.open_mission(mission)
