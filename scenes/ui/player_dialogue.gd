extends Control

@onready var message_label: Label = $Panel/Row/Content/Message
@onready var timer: Timer = $Timer
var _context_message := ""
var room_slot: StringName
var _room_hint := ""
var _overlay_enabled := true

func _ready() -> void:
	timer.timeout.connect(_restore_context)

func set_room_hint(slot_id: StringName, title: String, hint: String) -> void:
	if room_slot == slot_id:
		return
	room_slot = slot_id
	_room_hint = hint
	$Panel/Row/Content/Speaker.text = title
	$Panel/Row/Portrait.hide()
	clear()

func set_overlay_enabled(enabled: bool) -> void:
	_overlay_enabled = enabled
	if not enabled:
		clear()
	else:
		_restore_context()

# Entrada única para instruções da sala e, futuramente, dicas do jogador.
func say(message: String, duration: float = 5.0) -> void:
	if not _overlay_enabled or message.is_empty() or (visible and message_label.text == message):
		return
	message_label.text = message
	show()
	timer.start(duration)

func say_context(message: String) -> void:
	if _context_message == message:
		return
	_context_message = message
	if not timer.is_stopped():
		return
	_restore_context()

func _restore_context() -> void:
	var message := _room_hint if _context_message.is_empty() else _context_message
	if _overlay_enabled and not message.is_empty():
		message_label.text = message
		show()
	else:
		hide()

func clear() -> void:
	timer.stop()
	_context_message = ""
	_restore_context()
