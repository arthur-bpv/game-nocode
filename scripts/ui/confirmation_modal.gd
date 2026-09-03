extends Control
class_name ConfirmationModal

signal confirmed
signal cancelled

@onready var title_label: Label = %TitleLabel
@onready var message_label: Label = %MessageLabel
@onready var confirm_button: Button = %ConfirmButton

func _ready() -> void:
	hide()

func ask(title: String, message: String, confirm_text := "CONFIRMAR") -> void:
	title_label.text = title
	message_label.text = message
	confirm_button.text = confirm_text
	show()
	confirm_button.grab_focus()

func cancel() -> void:
	if not visible:
		return
	hide()
	cancelled.emit()

func _on_confirm_pressed() -> void:
	hide()
	confirmed.emit()

func _on_cancel_pressed() -> void:
	cancel()
