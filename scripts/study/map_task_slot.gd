extends Node2D

signal open_requested(mission: Control)

var _nearby: Array[Node2D] = []
var _prompt: Label

@export var slot_id: StringName
var _task: StudyTask
var _mission: Control

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
	StudySession.progress_changed.connect(_refresh)
	if _task.presentation == StudyTask.Presentation.TABLET:
		_build_terminal()
	_refresh()

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
		_prompt.text = "[E] ABRIR ATIVIDADE" if available else "ATIVIDADE BLOQUEADA"
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
	area.body_entered.connect(func(body: Node2D):
		if body.is_in_group("player") and not _nearby.has(body):
			_nearby.append(body)
			_prompt.show()
	)
	area.body_exited.connect(func(body: Node2D):
		_nearby.erase(body)
		_prompt.visible = not _nearby.is_empty()
	)
	_prompt = Label.new()
	_prompt.position = Vector2(190, 140)
	_prompt.size = Vector2(300, 40)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_font_size_override("font_size", 20)
	_prompt.hide()
	add_child(_prompt)
	queue_redraw()

func _draw() -> void:
	if _task == null or _task.presentation != StudyTask.Presentation.TABLET:
		return
	# Totem provisório: substituir esta representação quando a arte estiver pronta.
	draw_rect(Rect2(312, 228, 56, 60), Color("394550"))
	draw_rect(Rect2(290, 180, 100, 72), Color("111b25"))
	draw_rect(Rect2(299, 189, 82, 48), Color("16b4ba"))
	draw_line(Vector2(340, 198), Vector2(340, 225), Color.WHITE, 4)
	draw_line(Vector2(330, 215), Vector2(340, 225), Color.WHITE, 4)
	draw_line(Vector2(350, 215), Vector2(340, 225), Color.WHITE, 4)

func _unhandled_input(event: InputEvent) -> void:
	if _task == null or _task.presentation != StudyTask.Presentation.TABLET:
		return
	if _nearby.is_empty() or not event.is_action_pressed("interact") or event.is_echo():
		return
	if StudySession.task_state(_task.id) not in [&"available", &"completed"]:
		return
	open_requested.emit(_mission)
	get_viewport().set_input_as_handled()
