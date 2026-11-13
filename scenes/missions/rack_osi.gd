extends Control

signal completed
signal mentor_message(message: String, duration: float)

const BLOCK_ORDER := [
	"Aplicacao",
	"Apresentacao",
	"Sessao",
	"Transporte",
	"Rede",
	"Enlace",
	"Fisica",
]
const BLOCK_LABELS := {
	"Aplicacao": "APLICAÇÃO",
	"Apresentacao": "APRESENTAÇÃO",
	"Sessao": "SESSÃO",
	"Transporte": "TRANSPORTE",
	"Rede": "REDE",
	"Enlace": "ENLACE",
	"Fisica": "FÍSICA",
}
const BLOCK_COLORS := {
	"Aplicacao": Color("e50914"),
	"Apresentacao": Color("ff9418"),
	"Sessao": Color("34e51b"),
	"Transporte": Color("ec149a"),
	"Rede": Color("9129dc"),
	"Enlace": Color("2d56de"),
	"Fisica": Color("f4d328"),
}
# As sete aberturas do sprite novo foram desenhadas em uma grade regular.
@export_group("Rack Slots")
@export var slot_size := Vector2(134, 30)

var dragging_block: TextureRect
var drag_offset := Vector2.ZERO
var start_positions: Dictionary = {}
var installed: Dictionary = {}
var solved := false

@onready var rack: TextureRect = $Rack
@onready var status_label: Label = $StatusLabel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rack.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var shuffled_starts: Array = ChallengeSession.shuffled(&"rack_osi/start_positions", BLOCK_ORDER)
	var source_positions: Array[Vector2] = []
	for source_name in BLOCK_ORDER:
		var source_block := get_node_or_null(source_name) as TextureRect
		if source_block != null:
			source_positions.append(source_block.position)
	for index in BLOCK_ORDER.size():
		var target_block := get_node_or_null(BLOCK_ORDER[index]) as TextureRect
		if target_block != null:
			var source_index := BLOCK_ORDER.find(shuffled_starts[index])
			if source_index >= 0 and source_index < source_positions.size():
				target_block.position = source_positions[source_index]
	for block_name in BLOCK_ORDER:
		var block := get_node_or_null(block_name) as TextureRect
		if block == null:
			push_error("Bloco ausente: " + block_name)
			continue
		block.mouse_filter = Control.MOUSE_FILTER_IGNORE
		block.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		block.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_add_block_label(block, block_name)
		start_positions[block_name] = block.position
	status_label.text = "Arraste as camadas para as baias corretas do rack OSI."
	status_label.hide()

func mentor_intro() -> String:
	return "Arraste as camadas para as baias corretas do rack OSI."


func _add_block_label(block: TextureRect, block_name: String) -> void:
	var label := Label.new()
	label.name = "LayerLabel"
	label.text = BLOCK_LABELS[block_name]
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11 if label.text.length() > 10 else 14)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color("05080c"))
	label.add_theme_constant_override("outline_size", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	block.add_child(label)


func _input(event: InputEvent) -> void:
	if solved or not event is InputEventMouse:
		return
	var local_pointer := get_local_mouse_position()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_start_drag(local_pointer)
			if dragging_block != null:
				get_viewport().set_input_as_handled()
		elif dragging_block != null:
			_finish_drag(local_pointer)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and dragging_block != null:
		dragging_block.position = local_pointer - drag_offset
		get_viewport().set_input_as_handled()


func _start_drag(local_pointer: Vector2) -> void:
	for block_name in BLOCK_ORDER:
		if installed.has(block_name):
			continue
		var block := get_node_or_null(block_name) as TextureRect
		if block != null and block.get_rect().has_point(local_pointer):
			dragging_block = block
			drag_offset = local_pointer - block.position
			move_child(block, get_child_count() - 1)
			block.z_index = 5
			status_label.text = "Solte %s na baia correspondente." % BLOCK_LABELS[block_name]
			return


func _finish_drag(local_pointer: Vector2) -> void:
	if dragging_block == null:
		return
	var block := dragging_block
	dragging_block = null
	var block_name := String(block.name)
	var rack_pointer := rack.get_transform().affine_inverse() * local_pointer
	if _slot_rect(block_name).grow(6.0).has_point(rack_pointer):
		_insert_block(block_name)
	else:
		block.position = start_positions[block_name]
		block.z_index = 0
		SoundEffects.play_error()
		status_label.text = "Essa não é a baia de %s." % BLOCK_LABELS[block_name]
		mentor_message.emit(status_label.text, 3.0)


func _slot_rect(block_name: String) -> Rect2:
	var slot_marker := rack.get_node_or_null("Slots/" + block_name) as Marker2D
	if slot_marker != null:
		return Rect2(slot_marker.position - slot_size * 0.5, slot_size)
	# Reserva para cenas antigas que ainda não têm os marcadores visuais.
	var index := BLOCK_ORDER.find(block_name)
	return Rect2(Vector2(58, 79 + 44 * index), slot_size)


func _insert_block(block_name: String, announce := true, check_completion := true) -> void:
	if installed.has(block_name):
		return
	var block := get_node_or_null(block_name) as TextureRect
	if block == null:
		return
	block.hide()
	block.z_index = 0
	installed[block_name] = true

	var slot := _slot_rect(block_name)
	var marker := TextureRect.new()
	marker.name = "Installed" + block_name
	marker.texture = block.texture
	marker.position = slot.position
	marker.size = slot.size
	marker.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	marker.stretch_mode = TextureRect.STRETCH_SCALE
	marker.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rack.add_child(marker)

	var label := Label.new()
	label.text = BLOCK_LABELS[block_name]
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 9 if label.text.length() > 10 else 11)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 2)
	label.clip_text = false
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.add_child(label)

	if announce:
		SoundEffects.play_correct()
		status_label.text = "Sucesso! %s foi instalada." % BLOCK_LABELS[block_name]
		mentor_message.emit(status_label.text, 3.0)
	if check_completion and installed.size() == BLOCK_ORDER.size():
		_complete_task()


func _complete_task() -> void:
	solved = true
	SoundEffects.play_task_complete()
	status_label.text = "Rack OSI montado! Missão concluída."
	mentor_message.emit(status_label.text, 5.0)
	completed.emit()


func restore_completed() -> void:
	if solved and installed.size() == BLOCK_ORDER.size():
		return
	for block_name in BLOCK_ORDER:
		_insert_block(block_name, false, false)
	solved = true
	status_label.text = "Rack OSI montado! Missão concluída."
