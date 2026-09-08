extends Control
class_name GameplayTablet

var _active_mission: Control

@onready var map_button: Button = %MapButton
@onready var status_label: Label = %StatusLabel

func _ready() -> void:
	hide()
	StudySession.progress_changed.connect(_refresh_missions)

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
	_leave_mission()
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
	_refresh_missions(true)

func _on_tutorial_pressed() -> void:
	_show_section("TUTORIAL", "Tutoriais do ambiente disponíveis em breve.")

func _show_section(title: String, message: String) -> void:
	%SectionTitle.text = title
	status_label.text = message


func _refresh_missions(force: bool = false) -> void:
	if not force and %SectionTitle.text != "MISSÕES":
		return
	var topic := StudySession.current_topic()
	var lines := PackedStringArray([topic.title])
	var labels := {&"available": "Disponível", &"locked": "Bloqueada", &"completed": "Concluída", &"unavailable": "Em breve"}
	for task in topic.tasks:
		lines.append("%s — %s" % [task.title, labels[StudySession.task_state(task.id)]])
	_show_section("MISSÕES", "\n\n".join(lines))


func open_mission(mission: Control) -> void:
	open_ui()
	_active_mission = mission
	$ScreenCenter/Screen/Content/Body.hide()
	var host := $ScreenCenter/Screen/Content/MissionHost
	host.show()
	if mission.get_parent() != host:
		mission.reparent(host)
	mission.position = Vector2.ZERO
	mission.show()
	# O tablet oferece o botão de fechar; evita dois X para a mesma tela.
	var local_close := mission.get_node_or_null("CloseButton")
	if local_close != null:
		local_close.hide()
	$ScreenCenter/Screen/Content/Header/CloseButton.grab_focus()

func _leave_mission() -> void:
	if is_instance_valid(_active_mission):
		_active_mission.hide()
	_active_mission = null
	$ScreenCenter/Screen/Content/MissionHost.hide()
	$ScreenCenter/Screen/Content/Body.show()
