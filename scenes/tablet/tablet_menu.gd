extends Control
class_name GameplayTablet

const MISSION_STATE_LABELS := {
	&"available": "DISPONÍVEL",
	&"locked": "BLOQUEADA",
	&"completed": "CONCLUÍDA",
	&"unavailable": "EM BREVE",
}
const MISSION_STATE_COLORS := {
	&"available": Color("36e4ef"),
	&"locked": Color("87989e"),
	&"completed": Color("61e294"),
	&"unavailable": Color("59676c"),
}

var _active_mission: Control

@onready var map_button: Button = %MapButton
@onready var status_label: Label = %StatusLabel
@onready var missions_view: VBoxContainer = %MissionsView
@onready var mission_list: VBoxContainer = %MissionList
@onready var topic_title: Label = %TopicTitle
@onready var progress_label: Label = %ProgressLabel
@onready var progress_count: Label = %ProgressCount
@onready var mission_progress: ProgressBar = %MissionProgress
@onready var map_rect: TextureRect = $ScreenCenter/Screen/Content/Body/Section/SectionContent/TextureRect
@onready var player_marker: ColorRect = $ScreenCenter/Screen/Content/Body/Section/SectionContent/TextureRect/PlayerMarker
@onready var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
@onready var map_top_left: Node2D = get_tree().get_first_node_in_group("map_top_left") as Node2D
@onready var map_bottom_right: Node2D = get_tree().get_first_node_in_group("map_bottom_right") as Node2D

func _process(_delta: float) -> void:
	if player == null or map_rect == null or player_marker == null:
		return
	if map_top_left == null or map_bottom_right == null:
		return
	if map_rect.texture == null:
		return

	var world_map_bounds := Rect2(
		map_top_left.global_position,
		map_bottom_right.global_position - map_top_left.global_position
	)
	if world_map_bounds.size.x <= 0.0 or world_map_bounds.size.y <= 0.0:
		return

	var normalized_position := (
		player.global_position - world_map_bounds.position
	) / world_map_bounds.size

	normalized_position = normalized_position.clamp(Vector2.ZERO, Vector2.ONE)

	# Área ocupada de verdade pela imagem dentro do TextureRect.
	var texture_size := map_rect.texture.get_size()
	var scale_factor := minf(
		map_rect.size.x / texture_size.x,
		map_rect.size.y / texture_size.y
	)

	var drawn_size := texture_size * scale_factor
	var drawn_position := (map_rect.size - drawn_size) / 2.0

	player_marker.position = (
		drawn_position
		+ normalized_position * drawn_size
		- player_marker.size / 2.0
	)

func _ready() -> void:
	hide()
	StudySession.progress_changed.connect(_refresh_missions)

func open_ui() -> void:
	if visible:
		return
	show()
	_set_player_movement(false)
	_on_map_pressed()
	map_button.grab_focus()

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
	_show_section("MAPA", "Mapa do ambiente disponível em breve.", true)

func _on_missions_pressed() -> void:
	%SectionTitle.text = "MISSÕES"
	map_rect.visible = false
	status_label.visible = false
	missions_view.visible = true
	_refresh_missions(true)

func _on_tutorial_pressed() -> void:
	_show_section(
		"TUTORIAL",
		"Tutoriais do ambiente disponíveis em breve.",
		false
	)

func _show_section(title: String, message: String, show_map: bool = false) -> void:
	%SectionTitle.text = title
	missions_view.visible = false
	map_rect.visible = show_map
	status_label.visible = true
	status_label.text = message


func _refresh_missions(force: bool = false) -> void:
	if not force and %SectionTitle.text != "MISSÕES":
		return
	var topic := StudySession.current_topic()
	topic_title.text = topic.title
	_clear_mission_list()

	var completed := 0
	for index in topic.tasks.size():
		var task = topic.tasks[index]
		var state := StudySession.task_state(task.id)
		if state == &"completed":
			completed += 1
		mission_list.add_child(_build_mission_card(task, index, state))

	var total := topic.tasks.size()
	if total == 0:
		var empty_label := Label.new()
		empty_label.text = "NENHUMA ATIVIDADE NESTE TEMA"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_color_override("font_color", Color("87989e"))
		empty_label.add_theme_font_size_override("font_size", 10)
		mission_list.add_child(empty_label)

	mission_progress.max_value = maxi(total, 1)
	mission_progress.value = completed
	progress_count.text = "%d / %d" % [completed, total]
	var topic_completed := total > 0 and completed == total
	progress_label.text = "TEMA CONCLUÍDO" if topic_completed else "PROGRESSO DO TEMA"
	progress_label.add_theme_color_override(
		"font_color",
		Color("61e294") if topic_completed else Color("94c7cc")
	)
	mission_progress.add_theme_stylebox_override(
		"fill",
		_make_progress_style(Color("61e294") if topic_completed else Color("14d1de"))
	)


func _clear_mission_list() -> void:
	for child in mission_list.get_children():
		mission_list.remove_child(child)
		child.queue_free()


func _build_mission_card(task: StudyTask, index: int, state: StringName) -> PanelContainer:
	var color: Color = MISSION_STATE_COLORS.get(state, Color("87989e"))
	var card := PanelContainer.new()
	card.name = "Mission_%s" % task.id
	card.custom_minimum_size = Vector2(0, 68)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.set_meta("task_id", task.id)
	card.set_meta("state", state)
	card.add_theme_stylebox_override("panel", _make_card_style(color, state))

	var content := HBoxContainer.new()
	content.name = "Content"
	content.add_theme_constant_override("separation", 12)
	card.add_child(content)

	var number := Label.new()
	number.name = "Index"
	number.custom_minimum_size = Vector2(38, 0)
	number.text = "%02d" % (index + 1)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	number.add_theme_color_override("font_color", color)
	number.add_theme_font_size_override("font_size", 14)
	content.add_child(number)

	var details := VBoxContainer.new()
	details.name = "Details"
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.alignment = BoxContainer.ALIGNMENT_CENTER
	details.add_theme_constant_override("separation", 5)
	content.add_child(details)

	var title := Label.new()
	title.name = "Title"
	title.text = task.title
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_color_override("font_color", Color("e8fcff") if state != &"unavailable" else Color("829196"))
	title.add_theme_font_size_override("font_size", 12)
	details.add_child(title)

	var state_label := Label.new()
	state_label.name = "State"
	state_label.text = MISSION_STATE_LABELS.get(state, "INDISPONÍVEL")
	state_label.add_theme_color_override("font_color", color)
	state_label.add_theme_font_size_override("font_size", 9)
	details.add_child(state_label)

	return card


func _make_card_style(color: Color, state: StringName) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.content_margin_left = 10.0
	style.content_margin_top = 8.0
	style.content_margin_right = 10.0
	style.content_margin_bottom = 8.0
	style.bg_color = Color("08161a")
	style.bg_color = style.bg_color.lerp(color, 0.08 if state != &"completed" else 0.12)
	style.border_width_left = 4
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(color, 0.62)
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_right = 7
	style.corner_radius_bottom_left = 7
	return style


func _make_progress_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_right = 5
	style.corner_radius_bottom_left = 5
	return style


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
