extends Control

signal completed

const ACCENT := Color("69edf0")

@onready var title: Label = %Title
@onready var instruction: Label = %Instruction
@onready var interaction: VBoxContainer = %Interaction
@onready var feedback: Label = %Feedback

var finished := false

func setup(panel_title: String, directions: String) -> void:
	title.text = panel_title
	instruction.text = directions
	_set_body_font(instruction, 17)
	_set_body_font(feedback, 16)

func _set_body_font(control: Control, font_size: int) -> void:
	control.add_theme_font_override("font", ThemeDB.fallback_font)
	control.add_theme_font_size_override("font_size", font_size)

func make_label(caption: String, font_size: int = 17) -> Label:
	var label := Label.new()
	label.text = caption
	_set_body_font(label, font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func make_button(caption: String) -> Button:
	var button := Button.new()
	button.text = caption
	_set_body_font(button, 16)
	return button

func show_feedback(message: String, success: bool) -> void:
	feedback.text = message
	feedback.add_theme_color_override("font_color", ACCENT if success else Color("ffd080"))

func finish() -> void:
	if finished:
		return
	finished = true
	SoundEffects.play_task_complete()
	completed.emit()
