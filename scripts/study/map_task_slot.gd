extends Node2D

signal open_requested(mission: Control)

const INSPECTION_STATION_TEXTURE := preload("res://assets/sprites/Analisar_Pacotes.png")
# Encostada na parede superior do setor, deixando a área livre para o jogador.
# Parte superior embutida na parede: ficam expostos somente a saída e os roletes.
const INSPECTION_STATION_POSITION := Vector2(-41, -426)
const TASK_TERMINAL_TEXTURE := preload("res://assets/sprites/task_terminal.png")
# Cabinet texture, ground footprint, and platform relative to the terminal.
const TCPIP_TERMINALS := {
	&"conecta_camadas": [preload("res://assets/sprites/tcpip_patch_panel.png"), Rect2(-58, -11, 116, 36), Rect2(-92, -78, 184, 184)],
	&"encapsulamento_esteira": [TASK_TERMINAL_TEXTURE, Rect2(-38, 16, 76, 40), Rect2(-70, -96, 140, 206)],
	&"escolher_transporte": [preload("res://assets/sprites/tcpip_transport_selector.png"), Rect2(-30, -4, 60, 54), Rect2(-86, -82, 172, 198)],
	&"reparar_encapsulamento": [preload("res://assets/sprites/tcpip_encapsulation_module.png"), Rect2(-52, -24, 104, 66), Rect2(-82, -86, 164, 202)],
}

var _nearby: Array[Node2D] = []
var _prompt: Label
var _timer_label: Label
var _task_beacon: Label
var _equipment_sprite: Sprite2D
var _replay_button: Button
var _last_state: StringName

@export var slot_id: StringName
var _task: StudyTask
var _mission: Control
var _intro_shown := false
var _uses_room_guide := false
var _inspection_station := false

func floor_bounds(default_bounds: Rect2) -> Rect2:
	if _task == null:
		return Rect2()
	if _inspection_station:
		return Rect2(INSPECTION_STATION_POSITION + Vector2(-100, 0), Vector2(200, 148))
	var terminal: Array = TCPIP_TERMINALS.get(_task.id, [])
	if _task.presentation == StudyTask.Presentation.TABLET:
		if not terminal.is_empty():
			var bounds: Rect2 = terminal[2]
			bounds.position += _task.terminal_offset
			return bounds
		return Rect2(_task.terminal_offset - Vector2(96, 64), Vector2(192, 128))
	return default_bounds

func _ready() -> void:
	add_to_group("study_task_slots")
	for task in StudySession.current_topic().tasks:
		if task.map_slot == slot_id and task.enabled:
			_task = task
			break
	if _task == null:
		return
	_uses_room_guide = StudySession.topic_id == StudySession.DEFAULT_TOPIC_ID and get_node_or_null("../../TcpIpRoute") != null
	_mission = _create_mission()
	if _mission == null:
		return
	StudySession.progress_changed.connect(_refresh)

	_inspection_station = _task.id == &"inspecao_pacotes"
	if _inspection_station:
		_build_inspection_station()
	elif _task.presentation == StudyTask.Presentation.TABLET:
		_build_terminal()
	else:
		_build_physical_controls()
		if not _uses_room_guide and _mission.has_method("mentor_intro"):
			_build_intro_area()
	_refresh()

func _create_mission() -> Control:
	var scene := load(_task.mission_scene) as PackedScene
	if scene == null:
		return null
	var instance := scene.instantiate()
	var mission := instance as Control
	if mission == null or not mission.has_signal("completed"):
		push_error("Missão precisa ser Control e emitir completed: " + _task.mission_scene)
		instance.free()
		return null
	mission.set_meta("study_task_id", _task.id)
	mission.set_meta("study_task_slot", self)
	if _task.presentation == StudyTask.Presentation.TABLET:
		mission.hide()
	add_child(mission)
	move_child(mission, 0)
	mission.connect("completed", _on_completed)
	if mission.has_signal("mentor_message"):
		mission.connect("mentor_message", _on_mentor_message)
	if mission.has_signal("mentor_context"):
		mission.connect("mentor_context", _on_mentor_context)
	return mission

func restart_mission() -> Control:
	if _mission == null or StudySession.task_state(_task.id) != &"completed" or _mission.get_parent() != self:
		return null
	var replacement := _create_mission()
	if replacement == null:
		return null
	remove_child(_mission)
	_mission.queue_free()
	_mission = replacement
	_on_mentor_context("")
	_refresh()
	return _mission

func _process(_delta: float) -> void:
	if not _inspection_station or _timer_label == null or not is_instance_valid(_mission):
		return
	if _mission.has_method("get_map_timer_text"):
		_timer_label.text = _mission.call("get_map_timer_text")

func _build_inspection_station() -> void:
	# O equipamento físico ocupa somente uma pequena área da sala:
	# abertura preta na parede, esteira curta e contador na faixa verde.
	_mission.hide()
	var sprite := Sprite2D.new()
	sprite.name = "EsteiraParede"
	sprite.texture = INSPECTION_STATION_TEXTURE
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# A arte original usa resolução maior que a do equipamento no mapa.
	sprite.scale = Vector2(0.0625, 0.0625)
	sprite.position = INSPECTION_STATION_POSITION
	add_child(sprite)
	_equipment_sprite = sprite
	_add_task_beacon(INSPECTION_STATION_POSITION + Vector2(-31, -50))
	_add_equipment_body(INSPECTION_STATION_POSITION, Rect2(-30, 7, 60, 24))

	_timer_label = Label.new()
	_timer_label.name = "Timer"
	# O contador fica no trilho de scanner iluminado do novo sprite.
	# Painel auxiliar externo: fica à direita, sem ocultar o scanner.
	_timer_label.position = INSPECTION_STATION_POSITION + Vector2(-11, -60)
	_timer_label.size = Vector2(56, 20)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_timer_label.add_theme_font_override("font", ThemeDB.fallback_font)
	_timer_label.add_theme_font_size_override("font_size", 12)
	_timer_label.add_theme_color_override("font_color", Color("d9ffff"))
	_timer_label.add_theme_color_override("font_outline_color", Color("061018"))
	_timer_label.add_theme_constant_override("outline_size", 2)
	var timer_style := StyleBoxFlat.new()
	timer_style.bg_color = Color("102a38")
	timer_style.border_color = Color("17ddeb")
	timer_style.set_border_width_all(2)
	timer_style.corner_radius_top_left = 3
	timer_style.corner_radius_top_right = 3
	timer_style.corner_radius_bottom_left = 3
	timer_style.corner_radius_bottom_right = 3
	_timer_label.add_theme_stylebox_override("normal", timer_style)
	add_child(_timer_label)

	var area := Area2D.new()
	area.name = "InspectionInteraction"
	area.position = INSPECTION_STATION_POSITION
	area.collision_layer = 0
	area.collision_mask = 1
	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	var circle := CircleShape2D.new()
	circle.radius = 72.0
	shape.shape = circle
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(func(body: Node2D) -> void:
		if body.is_in_group("player") and not _nearby.has(body):
			_nearby.append(body)
			_show_intro_once(body)
			_refresh_prompt()
	)
	area.body_exited.connect(func(body: Node2D) -> void:
		_nearby.erase(body)
		_refresh_prompt()
	)
	if _uses_room_guide:
		return
	_prompt = Label.new()
	_prompt.position = INSPECTION_STATION_POSITION + Vector2(-100, 48)
	_prompt.size = Vector2(200, 22)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 12)
	_prompt.add_theme_color_override("font_color", Color("d8eff3"))
	_prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	_prompt.add_theme_constant_override("outline_size", 3)
	_prompt.text = "[E] INSPECIONAR ESTEIRA"
	_prompt.hide()
	add_child(_prompt)

func _build_intro_area() -> void:
	var area := Area2D.new()
	area.name = "MentorIntroArea"
	var mission_scale := maxf(absf(_mission.scale.x), absf(_mission.scale.y))
	area.position = _mission.position + _mission.size * _mission.scale * 0.5
	area.collision_layer = 0
	area.collision_mask = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = maxf(_mission.size.x, _mission.size.y) * mission_scale * 0.7
	shape.shape = circle
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(_show_intro_once)

func _build_physical_controls() -> void:
	var anchor := Vector2.ZERO
	match _task.id:
		&"rack_osi":
			var rack := _mission.get_node("Rack") as Control
			anchor = rack.position + Vector2(rack.size.x * 0.5, 0)
		&"sinais_osi":
			var monitor := _mission.get_node("Layout/Monitor") as Marker2D
			anchor = monitor.position + Vector2(90, 0)
			_add_equipment_body(anchor, Rect2(-78, 119, 156, 29))
			anchor.y -= 30
		_:
			return
	_add_task_beacon(to_local(_mission.get_global_transform() * anchor) - Vector2(0, 17))
	_replay_button = Button.new()
	_replay_button.name = "ReplayTask"
	_replay_button.text = "Refazer"
	_replay_button.position = _task_beacon.position + Vector2(34, 0)
	_replay_button.add_theme_font_size_override("font_size", 13)
	_replay_button.focus_mode = Control.FOCUS_NONE
	_replay_button.pressed.connect(restart_mission)
	add_child(_replay_button)

func _show_intro_once(body: Node2D) -> void:
	if _uses_room_guide or _intro_shown or not body.is_in_group("player"):
		return
	if StudySession.task_state(_task.id) != &"available":
		return
	_intro_shown = true
	var introduction := (
		String(_mission.call("mentor_intro"))
		if _mission.has_method("mentor_intro")
		else "Você encontrou a atividade “%s”. Aproxime-se do terminal e pressione [E] para começar." % _task.title
	)
	_on_mentor_message(introduction, 6.0)

func _on_mentor_message(message: String, duration: float = 5.0) -> void:
	var dialogue := _active_dialogue()
	if dialogue != null:
		dialogue.say(message, duration)

func _on_mentor_context(message: String) -> void:
	var dialogue := _active_dialogue()
	if dialogue != null:
		dialogue.say_context(message)

func _active_dialogue() -> Node:
	var dialogue := get_tree().get_first_node_in_group("player_dialogue")
	if dialogue != null and _uses_room_guide and dialogue.room_slot != slot_id:
		return null
	return dialogue

func _on_completed() -> void:
	StudySession.complete(_task.id)

func _refresh() -> void:
	var state := StudySession.task_state(_task.id)
	var available := state == &"available" or state == &"completed"
	if _task.presentation == StudyTask.Presentation.MAP:
		_mission.visible = available
	elif not available:
		_mission.hide()
	if _prompt != null:
		_prompt.text = "ATIVIDADE BLOQUEADA"
		if available:
			_prompt.text = "[E] INSPECIONAR ESTEIRA" if _inspection_station else "[E] ABRIR ATIVIDADE"
	if _task_beacon != null:
		_task_beacon.text = "✓" if state == &"completed" else ("!" if available else "–")
		_task_beacon.modulate = Color("8eeac0") if state == &"completed" else (Color.WHITE if available else Color("8195a2"))
	if _equipment_sprite != null:
		_equipment_sprite.modulate = Color.WHITE if available else Color("8496a1")
	if _timer_label != null:
		_timer_label.visible = available
	if _replay_button != null:
		_replay_button.visible = state == &"completed"
	_mission.process_mode = Node.PROCESS_MODE_INHERIT if available else Node.PROCESS_MODE_DISABLED
	if state != _last_state and state == &"completed" and _mission.has_method("restore_completed"):
		_mission.restore_completed()
	_last_state = state

func _build_terminal() -> void:
	_mission.hide()
	var terminal_sprite := Sprite2D.new()
	terminal_sprite.name = "TaskTerminalSprite"
	var terminal: Array = TCPIP_TERMINALS.get(_task.id, [])
	terminal_sprite.texture = TASK_TERMINAL_TEXTURE if terminal.is_empty() else terminal[0]
	terminal_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	terminal_sprite.position = _task.terminal_offset + Vector2(0, 4)
	terminal_sprite.scale = Vector2(2, 2)
	add_child(terminal_sprite)
	if not terminal.is_empty():
		_equipment_sprite = terminal_sprite
		_add_equipment_body(_task.terminal_offset, terminal[1])
	if _task.show_task_beacon or not terminal.is_empty():
		var badge_y: float = terminal[2].position.y + 24 if not terminal.is_empty() else -61
		_add_task_beacon(_task.terminal_offset + Vector2(0, badge_y))
	var area := Area2D.new()
	area.name = "TerminalInteraction"
	area.position = _task.terminal_offset
	area.collision_layer = 0
	area.collision_mask = 1
	var shape := CollisionShape2D.new()
	shape.name = "CollisionShape2D"
	if terminal.is_empty():
		var circle := CircleShape2D.new()
		circle.radius = 140
		shape.shape = circle
	else:
		var range_shape := RectangleShape2D.new()
		range_shape.size = Vector2(168, 150)
		area.position.y += 8
		shape.shape = range_shape
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(func(body: Node2D) -> void:
		if body.is_in_group("player") and not _nearby.has(body):
			_nearby.append(body)
			_refresh_prompt()
	)
	area.body_exited.connect(func(body: Node2D) -> void:
		_nearby.erase(body)
		_refresh_prompt()
	)
	if _uses_room_guide:
		return
	_prompt = Label.new()
	_prompt.position = _task.terminal_offset + Vector2(-150, -90)
	if _task_beacon != null:
		_prompt.position.y -= 24
	_prompt.size = Vector2(300, 40)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 20)
	_prompt.hide()
	add_child(_prompt)

func _add_equipment_body(origin: Vector2, footprint: Rect2) -> void:
	var body := StaticBody2D.new()
	body.name = "TerminalBody"
	body.position = origin + footprint.get_center()
	body.collision_mask = 0
	var collider := CollisionShape2D.new()
	collider.name = "CollisionShape2D"
	var rectangle := RectangleShape2D.new()
	rectangle.size = footprint.size
	collider.shape = rectangle
	body.add_child(collider)
	add_child(body)

func _add_task_beacon(center: Vector2) -> void:
	_task_beacon = Label.new()
	_task_beacon.name = "TaskBeacon"
	_task_beacon.position = center - Vector2(14, 14)
	_task_beacon.size = Vector2(28, 28)
	_task_beacon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_task_beacon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_task_beacon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_task_beacon.add_theme_font_size_override("font_size", 18)
	_task_beacon.add_theme_color_override("font_color", Color("bdffff"))
	var background := StyleBoxFlat.new()
	background.bg_color = Color("0d2530")
	background.border_color = Color("5bdcde")
	background.set_border_width_all(2)
	background.set_corner_radius_all(4)
	_task_beacon.add_theme_stylebox_override("normal", background)
	add_child(_task_beacon)

func _refresh_prompt() -> void:
	if _prompt != null:
		_prompt.visible = not _nearby.is_empty()


func _unhandled_input(event: InputEvent) -> void:
	if _task == null:
		return
	if _nearby.is_empty() or not event.is_action_pressed("interact") or event.is_echo():
		return
	if StudySession.task_state(_task.id) not in [&"available", &"completed"]:
		return
	if _task.presentation == StudyTask.Presentation.TABLET:
		open_requested.emit(_mission)
	get_viewport().set_input_as_handled()
