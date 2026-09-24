extends Control

signal completed

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
const SLOT_LEFT := 0.12
const SLOT_RIGHT := 0.88
const SLOT_TOP := 0.35
const SLOT_BOTTOM := 0.95

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
	for block_name in BLOCK_ORDER:
		var block := get_node_or_null(block_name) as TextureRect
		if block == null:
			push_error("Bloco ausente: " + block_name)
			continue
		block.mouse_filter = Control.MOUSE_FILTER_IGNORE
		block.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		start_positions[block_name] = block.position
	status_label.text = "Arraste as camadas para as baias corretas do rack OSI."


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
		status_label.text = "Essa não é a baia de %s." % BLOCK_LABELS[block_name]


func _slot_rect(block_name: String) -> Rect2:
	var slots_position := Vector2(rack.size.x * SLOT_LEFT, rack.size.y * SLOT_TOP)
	var slots_size := Vector2(
		rack.size.x * (SLOT_RIGHT - SLOT_LEFT),
		rack.size.y * (SLOT_BOTTOM - SLOT_TOP)
	)
	var slot_height := slots_size.y / float(BLOCK_ORDER.size())
	var index := BLOCK_ORDER.find(block_name)
	return Rect2(
		slots_position + Vector2(0, slot_height * index),
		Vector2(slots_size.x, slot_height)
	)


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
	var marker := ColorRect.new()
	marker.name = "Installed" + block_name
	marker.color = BLOCK_COLORS[block_name]
	marker.position = slot.position + Vector2(8.0, slot.size.y * 0.16)
	marker.size = Vector2(slot.size.x - 16.0, slot.size.y * 0.68)
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rack.add_child(marker)

	var label := Label.new()
	label.text = BLOCK_LABELS[block_name]
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.add_child(label)

	if announce:
		status_label.text = "Sucesso! %s foi instalada." % BLOCK_LABELS[block_name]
	if check_completion and installed.size() == BLOCK_ORDER.size():
		_complete_task()


func _complete_task() -> void:
	solved = true
	status_label.text = "Rack OSI montado! Missão concluída."
	completed.emit()


func restore_completed() -> void:
	if solved and installed.size() == BLOCK_ORDER.size():
		return
	for block_name in BLOCK_ORDER:
		_insert_block(block_name, false, false)
	solved = true
	status_label.text = "Rack OSI montado! Missão concluída."
