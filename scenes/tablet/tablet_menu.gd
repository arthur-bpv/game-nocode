extends Control
class_name GameplayTablet

@onready var map_button: Button = %MapButton
@onready var status_label: Label = %StatusLabel

func _ready() -> void:
	hide()

func open_ui() -> void:
	if visible:
		return
	show()
	_set_player_movement(false)
	map_button.grab_focus()
	_show_section("MAPA", "Mapa do ambiente disponível em breve.")

func close_ui() -> void:
	if not visible:
		return
	hide()
	_set_player_movement(true)

func toggle_ui() -> void:
	if visible:
		close_ui()
	else:
		open_ui()

func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("toggle_tablet"):
		return
	if event is InputEventKey and event.echo:
		return
	toggle_ui()
	get_viewport().set_input_as_handled()

func _set_player_movement(enabled: bool) -> void:
	for node in get_tree().get_nodes_in_group("player"):
		node.set_physics_process(enabled)

func _on_map_pressed() -> void:
	_show_section("MAPA", "Mapa do ambiente disponível em breve.")

func _on_missions_pressed() -> void:
	_show_section("MISSÕES", "Acompanhe aqui as tasks do tema atual.")

func _on_tutorial_pressed() -> void:
	_show_section("TUTORIAL", "Tutoriais do ambiente disponíveis em breve.")

func _show_section(title: String, message: String) -> void:
	%SectionTitle.text = title
	status_label.text = message
