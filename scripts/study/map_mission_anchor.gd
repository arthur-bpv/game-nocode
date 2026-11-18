@tool
class_name MapMissionAnchor
extends Marker2D

# A room can expose more than one independent place for a mission.
@export var slot_id: StringName
@export var floor_bounds := Rect2(-96, -64, 192, 128)
