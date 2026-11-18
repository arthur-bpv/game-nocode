extends Node2D

signal room_changed(slot_id: StringName)

# Each entrance gives the first and last cell across the opening and the
# direction into the room. The same cells define the physical door and route.
const ENTRANCES := {
	&"sala_inferior_central_principal": [
		[Vector2i(53, 40), Vector2i(59, 40), Vector2i.DOWN],
		[Vector2i(44, 48), Vector2i(44, 53), Vector2i.RIGHT],
		[Vector2i(66, 48), Vector2i(66, 53), Vector2i.LEFT],
	],
	&"sala_inferior_esquerda_principal": [
		[Vector2i(16, 40), Vector2i(20, 40), Vector2i.DOWN],
		[Vector2i(34, 48), Vector2i(34, 53), Vector2i.LEFT],
	],
	&"sala_superior_esquerda_principal": [
		[Vector2i(16, 30), Vector2i(20, 30), Vector2i.UP],
		[Vector2i(30, 15), Vector2i(30, 19), Vector2i.LEFT],
	],
	&"sala_central_principal": [
		[Vector2i(54, 14), Vector2i(58, 14), Vector2i.UP],
	],
	&"sala_superior_direita_principal": [
		[Vector2i(85, 15), Vector2i(85, 19), Vector2i.RIGHT],
		[Vector2i(97, 31), Vector2i(102, 31), Vector2i.UP],
	],
	&"sala_inferior_direita_principal": [
		[Vector2i(105, 45), Vector2i(105, 49), Vector2i.RIGHT],
	],
	&"sala_inferior_centro_direita_principal": [
		[Vector2i(78, 47), Vector2i(82, 47), Vector2i.UP],
	],
}
# Partitions separate the north activity bays from the central circulation
# hall and from the lower corridor. The gaps are the entrances above.
const PARTITIONS := [
	Rect2i(43, 14, 11, 1),
	Rect2i(59, 14, 11, 1),
	Rect2i(73, 47, 5, 1),
	Rect2i(83, 47, 4, 1),
]
const CARDINAL := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

@onready var _floor: TileMapLayer = $"../MapLayout/Floor"
@onready var _walls: TileMapLayer = $"../MapLayout/Walls"
@onready var _player: CharacterBody2D = $"../Entities/player/Player"
@onready var _tablet: Control = $"../CanvasLayer/TabletUi"

var _grid := AStarGrid2D.new()
var _gates: Dictionary = {}
var _room_cells: Dictionary = {}
var _number_by_slot: Dictionary = {}
var _target_slot: StringName
var _guide: Node2D
var _destination: Label
var _path: Array[Vector2i] = []
var _from := Vector2i(-1, -1)
var _current_room: StringName

func _ready() -> void:
	if StudySession.topic_id != StudySession.DEFAULT_TOPIC_ID:
		set_physics_process(false)
		return

	var details := $"../MapLayout/Details" as TileMapLayer
	for partition in PARTITIONS:
		for x in range(partition.position.x, partition.end.x):
			var cell := Vector2i(x, partition.position.y)
			_floor.erase_cell(cell)
			details.erase_cell(cell)
			_walls.set_cell(cell, 0, Vector2i(3, 1))

	_grid.region = _floor.get_used_rect()
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	_grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	_grid.update()
	_grid.fill_solid_region(_grid.region, true)
	for cell in _floor.get_used_cells():
		if _walls.get_cell_source_id(cell) == -1:
			_grid.set_point_solid(cell, false)

	var tasks := StudySession.current_topic().tasks
	for index in tasks.size():
		var task := tasks[index]
		var slot := task.map_slot
		_number_by_slot[slot] = index + 1
		_gates[slot] = []
		for opening in ENTRANCES.get(slot, []):
			_add_gate(slot, opening[0], opening[1], opening[2])

	# With all entrances temporarily solid in the path grid, find each room's
	# interior. This lets guidance stop when the player enters through any door.
	for slot in _gates:
		var gates: Array = _gates[slot]
		if not gates.is_empty():
			_room_cells[slot] = _room_interior(gates[0].entry + gates[0].inward)

	_guide = Node2D.new()
	_guide.name = "PathGuide"
	_guide.z_index = -1
	_guide.draw.connect(_draw_path)
	add_child(_guide)
	_destination = _make_label($"../CanvasLayer", 22)
	_destination.name = "RouteDestination"
	_destination.anchor_left = 0.5
	_destination.anchor_right = 0.5
	_destination.anchor_top = 1.0
	_destination.anchor_bottom = 1.0
	_destination.offset_left = -160
	_destination.offset_right = 160
	_destination.offset_top = -44
	_destination.offset_bottom = -12
	_destination.hide()

	StudySession.progress_changed.connect(_refresh)
	_refresh()

func _add_gate(slot: StringName, first: Vector2i, last: Vector2i, inward: Vector2i) -> void:
	var body := StaticBody2D.new()
	body.name = "Sala%02d_Porta%d" % [_number_by_slot[slot], _gates[slot].size() + 1]
	body.collision_mask = 0
	var center := (_cell_position(first) + _cell_position(last)) * 0.5
	var horizontal := first.y == last.y
	var tiles := maxi(last.x - first.x, last.y - first.y) + 1
	var tile_size := _floor.tile_set.tile_size.x
	var span := tiles * tile_size + 2.0
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(span, 20) if horizontal else Vector2(20, span)
	var collision := CollisionShape2D.new()
	collision.name = "Collision"
	collision.shape = rectangle
	body.add_child(collision)
	add_child(body)
	body.position = center

	var label := _make_label(body, 11)
	label.position.y = -27 if horizontal else -15
	var entry := Vector2i((first + last) / 2)
	var cells := Rect2i(first, last - first + Vector2i.ONE)
	var door := {
		"body": body, "collision": collision, "label": label,
		"cells": cells, "entry": entry, "inward": inward, "locked": true,
	}
	_gates[slot].append(door)
	_grid.fill_solid_region(cells, true)
	body.draw.connect(_draw_gate.bind(door, span, horizontal))

func _make_label(parent: Node, font_size: int) -> Label:
	var label := Label.new()
	label.position.x = -68
	label.size.x = 136
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("e8fcff"))
	label.add_theme_color_override("font_outline_color", Color("0b1820"))
	label.add_theme_constant_override("outline_size", 4)
	parent.add_child(label)
	return label

func _room_interior(entry: Vector2i) -> Dictionary:
	var seen: Dictionary = {entry: true}
	var pending: Array[Vector2i] = [entry]
	var cursor := 0
	while cursor < pending.size():
		var current := pending[cursor]
		cursor += 1
		for direction in CARDINAL:
			var next: Vector2i = current + direction
			if _grid.is_in_boundsv(next) and not _grid.is_point_solid(next) and not seen.has(next):
				seen[next] = true
				pending.append(next)
	return seen

func _refresh() -> void:
	for task in StudySession.current_topic().tasks:
		var slot := task.map_slot
		var locked := StudySession.task_state(task.id) not in [&"available", &"completed"]
		for door in _gates[slot]:
			door.locked = locked
			door.collision.set_deferred("disabled", not locked)
			door.label.text = "Sala %02d · %s" % [_number_by_slot[slot], "Fechada" if locked else "Aberta"]
			_grid.fill_solid_region(door.cells, locked)
			door.body.queue_redraw()

	var next := StudySession.next_available_task()
	_target_slot = next.map_slot if next != null else &""
	_destination.text = "Siga para a sala %02d" % _number_by_slot[_target_slot] if next != null else ""
	_from = Vector2i(-1, -1)
	_path.clear()
	_update_path()

func _physics_process(_delta: float) -> void:
	_update_path()
	var show_guide := not _path.is_empty() and not get_tree().paused and not _tablet.visible
	_guide.visible = show_guide
	_destination.visible = show_guide

func _update_path() -> void:
	var from := _floor.local_to_map(_floor.to_local(_player.global_position))
	if from == _from:
		return
	_from = from
	var room: StringName = &""
	for slot in _room_cells:
		if _room_cells[slot].has(from):
			room = slot
			break
	if room != _current_room:
		_current_room = room
		room_changed.emit(room)
	var interior: Dictionary = _room_cells.get(_target_slot, {})
	if interior.has(from) or not _grid.is_in_boundsv(from) or _grid.is_point_solid(from):
		_path.clear()
	else:
		var path_index := _path.find(from)
		if path_index >= 0:
			_path = _path.slice(path_index)
		else:
			_recalculate_path(from)
	_guide.queue_redraw()

func _recalculate_path(from: Vector2i) -> void:
	_path.clear()
	for door in _gates.get(_target_slot, []):
		var candidate := _grid.get_id_path(from, door.entry + door.inward)
		if not candidate.is_empty() and (_path.is_empty() or candidate.size() < _path.size()):
			_path = candidate

func _cell_position(cell: Vector2i) -> Vector2:
	return to_local(_floor.to_global(_floor.map_to_local(cell)))

func _draw_gate(door: Dictionary, span: float, horizontal: bool) -> void:
	var body := door.body as StaticBody2D
	body.draw_set_transform(Vector2.ZERO, 0.0 if horizontal else PI * 0.5)
	var left := -span * 0.5
	var surface := Rect2(left, -10, span, 20)
	var edge := Color("f5b66a") if door.locked else Color("8eeac0")
	if door.locked:
		body.draw_rect(surface, Color("17252d"))
		body.draw_rect(surface.grow(-2), Color("485d68"))
		body.draw_line(Vector2(left + 3, -7), Vector2(-left - 3, -7), Color("7c939c"), 2.0)
		for x in range(ceili(left + 31), floori(-left - 21), 24):
			body.draw_line(Vector2(x, -4), Vector2(x, 5), Color("253741"), 2.0)
	else:
		body.draw_rect(Rect2(left, -5, span, 10), Color("253741"))
		body.draw_line(Vector2(left, -4), Vector2(-left, -4), Color("688692"), 2.0)
		body.draw_line(Vector2(left, 4), Vector2(-left, 4), Color("688692"), 2.0)
	for jamb in [left, -left - 16]:
		body.draw_rect(Rect2(jamb, -13, 16, 26), Color("233740"))
		body.draw_rect(Rect2(jamb + 3, -10, 10, 20), Color("4a6371"))
		body.draw_rect(Rect2(jamb + 5, -3, 6, 6), edge)
	body.draw_set_transform(Vector2.ZERO)

func _draw_path() -> void:
	# Anchor straight-run chevrons to map cells so trimming the route doesn't shift them.
	for index in range(1, _path.size() - 1):
		var cell := _path[index]
		var before := cell - _path[index - 1]
		var onwards := _path[index + 1] - cell
		var axis := cell.x if onwards.x != 0 else cell.y
		if axis % 3 != 0 and before == onwards:
			continue
		var direction := Vector2(onwards)
		var center := _cell_position(cell)
		var left := center - direction * 6.0 + direction.orthogonal() * 8.0
		var tip := center + direction * 5.0
		var right := center - direction * 6.0 - direction.orthogonal() * 8.0
		var arrow := PackedVector2Array([left, tip, right])
		_guide.draw_polyline(arrow, Color("0d2530"), 7.0)
		_guide.draw_polyline(arrow, Color("b3f4e1"), 3.0)
