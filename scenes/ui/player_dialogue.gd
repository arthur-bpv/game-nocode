extends Control

@onready var message_label: Label = $Panel/Row/Content/Message
@onready var timer: Timer = $Timer
var _context_message := ""

func _ready() -> void:
	timer.timeout.connect(_restore_context)

# Entrada única para instruções da sala e, futuramente, dicas do jogador.
func say(message: String, duration: float = 5.0) -> void:
	if message.is_empty() or (visible and message_label.text == message):
		return
	message_label.text = message
	show()
	timer.start(duration)

func say_context(message: String) -> void:
	_context_message = message
	if message.is_empty():
		if timer.is_stopped():
			hide()
		return
	if visible and message_label.text == message:
		return
	timer.stop()
	message_label.text = message
	show()

func _restore_context() -> void:
	if _context_message.is_empty():
		hide()
	else:
		message_label.text = _context_message
		show()

func clear() -> void:
	timer.stop()
	_context_message = ""
	hide()
