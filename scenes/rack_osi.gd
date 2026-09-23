extends Control

signal completed

const BLOCK_ORDER := ["Aplicacao", "Apresentacao", "Sessao", "Transporte", "Rede", "Enlace", "Fisica"]
const BLOCK_COLORS := {"Aplicacao": Color("#e50914"), "Apresentacao": Color("#ff9418"), "Sessao": Color("#34e51b"), "Transporte": Color("#ec149a"), "Rede": Color("#9129dc"), "Enlace": Color("#2d56de"), "Fisica": Color("#f4d328")}
const SLOT_LEFT := 0.12
const SLOT_RIGHT := 0.88
const SLOT_TOP := 0.35
const SLOT_BOTTOM := 0.95

var dragging_block: TextureRect = null
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
		block.show()
		block.mouse_filter = Control.MOUSE_FILTER_IGNORE
		block.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		start_positions[block_name] = block.position
	status_label.show()
	status_label.text = "Arraste as camadas para o rack OSI."

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
			_finish_drag()
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
			status_label.text = "Solte %s na baia correspondente." % block_name
			return

func _finish_drag() -> void:
	var block := dragging_block
	dragging_block = null
	var block_name: String = String(block.name)
	var target := _slot_rect(block_name)
	if target.grow(6.0).has_point(rack.get_local_mouse_position()):
		_insert_block(block_name)
	else:
		block.position = start_positions[block_name]
		block.z_index = 0
		status_label.text = "Essa não é a baia de %s." % block_name

func _slot_rect(block_name: String) -> Rect2:
	var position := Vector2(rack.size.x * SLOT_LEFT, rack.size.y * SLOT_TOP)
	var slots_size := Vector2(rack.size.x * (SLOT_RIGHT - SLOT_LEFT), rack.size.y * (SLOT_BOTTOM - SLOT_TOP))
	var height := slots_size.y / float(BLOCK_ORDER.size())
	var index := BLOCK_ORDER.find(block_name)
	return Rect2(position + Vector2(0, height * index), Vector2(slots_size.x, height))

func _insert_block(block_name: String) -> void:
	var block := get_node_or_null(block_name) as TextureRect
	block.hide()
	installed[block_name] = true
	var marker := ColorRect.new()
	marker.color = BLOCK_COLORS[block_name]
	var slot := _slot_rect(block_name)
	marker.position = slot.position + Vector2(10, slot.size.y * 0.29)
	marker.size = Vector2(slot.size.x - 20, slot.size.y * 0.38)
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rack.add_child(marker)
	status_label.text = "Sucesso! %s foi inserido no rack." % block_name
	if installed.size() == BLOCK_ORDER.size():
		_complete_task()

func _complete_task() -> void:
	solved = true
	if StudySession.task_state(&"rack_osi") == &"available":
		StudySession.complete(&"rack_osi")
	status_label.text = "Rack OSI montado! Missão concluída."
	completed.emit()

func restore_completed() -> void:
	solved = false
