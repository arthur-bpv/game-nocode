extends Node2D

signal open_requested(mission: Control)

const INSPECTION_STATION_TEXTURE := preload("res://assets/sprites/EsteiraParede.png")
const INSPECTION_STATION_POSITION := Vector2(0, -348)

var _nearby: Array[Node2D] = []
var _prompt: Label
var _timer_label: Label
var _inspection_overlay: CanvasLayer

@export var slot_id: StringName
var _task: StudyTask
var _mission: Control
var _intro_shown := false
var _inspection_station := false

func _ready() -> void:
	add_to_group("study_task_slots")
	for task in StudySession.current_topic().tasks:
		if task.map_slot == slot_id and task.enabled:
			_task = task
			break
	if _task == null:
		return
	var scene := load(_task.mission_scene) as PackedScene
	if scene == null:
		return
	var instance := scene.instantiate()
	_mission = instance as Control
	if _mission == null or not _mission.has_signal("completed"):
		push_error("Missão precisa ser Control e emitir completed: " + _task.mission_scene)
		instance.free()
		return
	add_child(_mission)
	_mission.connect("completed", _on_completed)
	if _mission.has_signal("mentor_message"):
		_mission.connect("mentor_message", _on_mentor_message)
	if _mission.has_signal("mentor_context"):
		_mission.connect("mentor_context", _on_mentor_context)
	if _mission.has_signal("close_requested"):
		_mission.connect("close_requested", _close_inspection_overlay)
	StudySession.progress_changed.connect(_refresh)

	_inspection_station = _task.id == &"inspecao_pacotes"
	if _inspection_station:
		_build_inspection_station()
	elif _task.presentation == StudyTask.Presentation.TABLET:
		_build_terminal()
	elif _mission.has_method("mentor_intro"):
		_build_intro_area()
	_refresh()

func _process(_delta: float) -> void:
	if not _inspection_station or _timer_label == null or not is_instance_valid(_mission):
		return
	if _mission.has_method("get_map_timer_text"):
		_timer_label.text = _mission.call("get_map_timer_text")

func _build_inspection_station() -> void:
	# O equipamento físico ocupa somente uma pequena área da sala:
	# abertura preta na parede, esteira curta e contador na faixa verde.
	_mission.hide()
	_inspection_overlay = CanvasLayer.new()
	_inspection_overlay.name = "InspectionOverlay"
	_inspection_overlay.layer = 40
	add_child(_inspection_overlay)
	var sprite := Sprite2D.new()
	sprite.name = "EsteiraParede"
	sprite.texture = INSPECTION_STATION_TEXTURE
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2(0.72, 0.72)
	sprite.position = INSPECTION_STATION_POSITION
	add_child(sprite)

	_timer_label = Label.new()
	_timer_label.name = "Timer"
	# O visor verde da arte ocupa a faixa superior da esteira.
	_timer_label.position = INSPECTION_STATION_POSITION + Vector2(-34, -43)
	_timer_label.size = Vector2(68, 23)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_timer_label.add_theme_font_size_override("font_size", 11)
	_timer_label.add_theme_color_override("font_color", Color("07140a"))
	_timer_label.add_theme_color_override("font_outline_color", Color("c8ffd0"))
	_timer_label.add_theme_constant_override("outline_size", 1)
	add_child(_timer_label)

	var area := Area2D.new()
	area.name = "InspectionInteraction"
	area.position = INSPECTION_STATION_POSITION
	area.collision_layer = 0
	area.collision_mask = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 56.0
	shape.shape = circle
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

func _open_inspection_overlay() -> void:
	if _inspection_overlay == null or not is_instance_valid(_mission):
		return
	if _mission.get_parent() != _inspection_overlay:
		_mission.reparent(_inspection_overlay)
	_mission.position = Vector2(240, 105)
	_mission.show()
	get_viewport().set_input_as_handled()

func _close_inspection_overlay() -> void:
	if not is_instance_valid(_mission):
		return
	_mission.hide()
	if _mission.get_parent() != self:
		_mission.reparent(self)

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
	area.body_entered.connect(func(body: Node2D) -> void:
		if _intro_shown or not body.is_in_group("player"):
			return
		if StudySession.task_state(_task.id) != &"available":
			return
		_intro_shown = true
		_on_mentor_message(_mission.call("mentor_intro"), 6.0)
	)

func _on_mentor_message(message: String, duration: float = 5.0) -> void:
	var dialogue := get_tree().get_first_node_in_group("player_dialogue")
	if dialogue != null:
		dialogue.say(message, duration)

func _on_mentor_context(message: String) -> void:
	var dialogue := get_tree().get_first_node_in_group("player_dialogue")
	if dialogue != null:
		dialogue.say_context(message)

func _on_completed() -> void:
	StudySession.complete(_task.id)

func _refresh() -> void:
	var state := StudySession.task_state(_task.id)
	var available := state == &"available" or state == &"completed"
	if _task.presentation == StudyTask.Presentation.MAP and not _inspection_station:
		_mission.visible = available
	elif not available:
		_mission.hide()
	if _prompt != null:
		_prompt.text = "[E] INSPECIONAR ESTEIRA" if _inspection_station else ("[E] ABRIR ATIVIDADE" if available else "ATIVIDADE BLOQUEADA")
	_mission.process_mode = Node.PROCESS_MODE_INHERIT if available else Node.PROCESS_MODE_DISABLED
	if state == &"completed" and _mission.has_method("restore_completed"):
		_mission.restore_completed()

func _build_terminal() -> void:
	_mission.hide()
	var area := Area2D.new()
	area.position = Vector2(340, 230)
	area.collision_layer = 0
	area.collision_mask = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 140
	shape.shape = circle
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
	_prompt = Label.new()
	_prompt.position = Vector2(190, 140)
	_prompt.size = Vector2(300, 40)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 20)
	_prompt.hide()
	add_child(_prompt)
	queue_redraw()

func _refresh_prompt() -> void:
	if _prompt != null:
		_prompt.visible = not _nearby.is_empty()


func _draw() -> void:
	if _task == null or _task.presentation != StudyTask.Presentation.TABLET:
		return
	# Totem visual da atividade aberta pelo tablet.
	draw_rect(Rect2(312, 228, 56, 60), Color("394550"))
	draw_rect(Rect2(290, 180, 100, 72), Color("111b25"))
	draw_rect(Rect2(299, 189, 82, 48), Color("16b4ba"))
	draw_line(Vector2(340, 198), Vector2(340, 225), Color.WHITE, 4)
	draw_line(Vector2(330, 215), Vector2(340, 225), Color.WHITE, 4)
	draw_line(Vector2(350, 215), Vector2(340, 225), Color.WHITE, 4)

func _unhandled_input(event: InputEvent) -> void:
	if _task == null:
		return
	if _nearby.is_empty() or not event.is_action_pressed("interact") or event.is_echo():
		return
	if StudySession.task_state(_task.id) not in [&"available", &"completed"]:
		return
	if _inspection_station:
		_open_inspection_overlay()
	elif _task.presentation == StudyTask.Presentation.TABLET:
		open_requested.emit(_mission)
	get_viewport().set_input_as_handled()
