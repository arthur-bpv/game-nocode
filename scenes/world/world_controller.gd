extends Node

const DISCIPLINE_BADGE_NOTICE := preload("res://scenes/ui/discipline_badge_notice.tscn")

const COMPLETION_NOTICE := preload("res://scenes/ui/study_completion_notice.tscn")
const ROOM_HINTS := {
	&"rack_osi": "Arraste as camadas para as baias do rack, na ordem do modelo OSI.",
	&"sinais_osi": "Leia a pista no monitor. Pise junto ao botão da camada e pressione [E].",
	&"conecta_camadas": "No painel, pressione [E] e ligue cada camada OSI à camada TCP/IP correspondente.",
	&"encapsulamento_esteira": "No terminal, pressione [E] e acompanhe as etapas do envio de uma página.",
	&"escolher_transporte": "No seletor, pressione [E] e escolha TCP ou UDP para cada envio.",
	&"reparar_encapsulamento": "No módulo, pressione [E] e encaixe as camadas na ordem do envio.",
	&"inspecao_pacotes": "No scanner, pressione [E]. Confira os dados antes de aprovar ou reenviar cada pacote.",
}

@onready var tablet: Control = get_node("../TabletUi")
@onready var pause_menu: Control = get_node("../Pause")
@onready var task_progress_hud: Control = get_node("../TaskProgressHud")

var _notice: Control
var _notice_timer: Timer
var _pending_completion: StudyTask
var _current_room: StringName
var _badge_notice: Control
var _pending_badge: StudyDiscipline

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel") or event.is_echo():
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
	tablet.visibility_changed.connect(_refresh_hud_visibility)
	pause_menu.visibility_changed.connect(_refresh_hud_visibility)
	_badge_notice = DISCIPLINE_BADGE_NOTICE.instantiate()
	add_child(_badge_notice)
	StudySession.discipline_badge_earned.connect(_on_discipline_badge_earned)
	var route := get_node_or_null("../../TcpIpRoute")
	if route != null and StudySession.topic_id == StudySession.DEFAULT_TOPIC_ID:
		_notice = COMPLETION_NOTICE.instantiate()
		add_child(_notice)
		for label_name in ["Heading", "CompletedTitle", "NextRoom"]:
			_notice.get_node("%" + label_name).add_theme_font_override("font", ThemeDB.fallback_font)
		_notice_timer = _notice.get_node("Timer")
		_notice_timer.timeout.connect(_notice.hide)
		route.room_changed.connect(_on_room_changed)
		StudySession.progress_changed.connect(_refresh_room)
		StudySession.task_completed.connect(_on_task_completed)
	_refresh_hud_visibility()
	for slot in get_tree().get_nodes_in_group("study_task_slots"):
		slot.open_requested.connect(_open_task)

func _refresh_hud_visibility() -> void:
	var map_visible := not tablet.visible and not pause_menu.visible
	task_progress_hud.visible = map_visible
	if map_visible and _pending_badge != null:
		_badge_notice.show_badge(_pending_badge)
		_pending_badge = null
	elif not map_visible:
		_badge_notice.hide()
	if _notice == null:
		return
	$"../PlayerDialogue".set_overlay_enabled(map_visible)
	if not map_visible:
		_notice.hide()
		_notice_timer.stop()
	elif _pending_completion != null:
		_show_completion.call_deferred()

func _on_discipline_badge_earned(discipline_id: StringName) -> void:
	_pending_badge = StudySession.catalog.find_discipline(discipline_id)
	_refresh_hud_visibility()

func _on_room_changed(slot_id: StringName) -> void:
	_current_room = slot_id
	_refresh_room()

func _refresh_room() -> void:
	var tasks := StudySession.current_topic().tasks
	for index in tasks.size():
		var task := tasks[index]
		if task.map_slot == _current_room and StudySession.task_state(task.id) in [&"available", &"completed"]:
			$"../PlayerDialogue".set_room_hint(_current_room, "Sala %02d · %s" % [index + 1, task.title], ROOM_HINTS[task.id])
			return
	$"../PlayerDialogue".set_room_hint(&"", "", "")

func _on_task_completed(task_id: StringName) -> void:
	_pending_completion = StudySession.current_topic().find_task(task_id)
	_show_completion.call_deferred()

func _show_completion() -> void:
	if _pending_completion == null or tablet.visible or pause_menu.visible:
		return
	var next := StudySession.next_available_task()
	_notice.get_node("%Heading").text = "Atividade concluída" if next != null else "Tema concluído"
	_notice.get_node("%CompletedTitle").text = _pending_completion.title
	var room: Label = _notice.get_node("%NextRoom")
	if next != null:
		var number := StudySession.current_topic().tasks.find(next) + 1
		room.text = "Sala %02d liberada · %s" % [number, next.title]
	room.visible = next != null
	_pending_completion = null
	_notice.show()
	_notice_timer.start()

func _exit_tree() -> void:
	SoundEffects.set_world_ambience_enabled(false)

func _open_task(mission: Control) -> void:
	if not tablet.visible and not pause_menu.visible and not get_tree().paused:
		tablet.open_mission(mission)
