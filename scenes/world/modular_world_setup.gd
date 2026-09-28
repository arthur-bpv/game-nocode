extends Node

func _ready() -> void:
	var layout := get_node("../MapLayout") as Node2D
	var entities := get_node("../Entities") as Node2D
	var slot_script := load("res://scripts/study/map_task_slot.gd") as GDScript
	var seen_slots := {}
	for piece in layout.get_node("Pieces").get_children():
		if not piece is MapRoom:
			continue
		for anchor in piece.get_node("MissionSlots").get_children():
			if not anchor is MapMissionAnchor:
				continue
			if anchor.slot_id == &"" or seen_slots.has(anchor.slot_id):
				push_error("Slot físico vazio ou duplicado: %s" % anchor.slot_id)
				continue
			seen_slots[anchor.slot_id] = true
			var slot := Node2D.new()
			slot.name = String(anchor.slot_id)
			slot.set_script(slot_script)
			slot.set("slot_id", anchor.slot_id)
			entities.add_child(slot)
			slot.global_position = anchor.global_position
	var top_left := get_node("../MapTopLeft") as Marker2D
	var bottom_right := get_node("../MapBottomRight") as Marker2D
	var camera := get_node("../Entities/player/Player/Camera2D") as Camera2D
	camera.limit_left = roundi(top_left.global_position.x)
	camera.limit_top = roundi(top_left.global_position.y)
	camera.limit_right = roundi(bottom_right.global_position.x)
	camera.limit_bottom = roundi(bottom_right.global_position.y)
