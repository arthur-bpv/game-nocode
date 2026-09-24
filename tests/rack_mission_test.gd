extends SceneTree

var _failed := false
var _completed_count := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene := load("res://scenes/missions/rack_osi.tscn") as PackedScene
	_check(scene != null, "A cena da missão do rack não pôde ser carregada.")
	if scene == null:
		quit(1)
		return
	var mission := scene.instantiate()
	root.add_child(mission)
	mission.completed.connect(func(): _completed_count += 1)
	await process_frame

	for block_name in mission.BLOCK_ORDER:
		var block := mission.get_node(block_name) as TextureRect
		var start_position := block.position
		mission._start_drag(block.get_rect().get_center())
		_check(mission.dragging_block == block, "O bloco %s não iniciou o arraste." % block_name)

		var wrong_drop := Vector2(400, 430)
		mission._finish_drag(wrong_drop)
		_check(block.position == start_position, "O bloco %s não voltou à origem após um encaixe inválido." % block_name)

		mission._start_drag(block.get_rect().get_center())
		var slot_center: Vector2 = mission.rack.position + mission._slot_rect(block_name).get_center()
		mission._finish_drag(slot_center)
		_check(mission.installed.has(block_name), "O bloco %s não foi instalado na baia correta." % block_name)

	_check(mission.solved, "A missão não foi marcada como concluída.")
	_check(_completed_count == 1, "A missão deve emitir completed exatamente uma vez.")

	mission.restore_completed()
	_check(_completed_count == 1, "Restaurar progresso não deve emitir completed novamente.")
	for block_name in mission.BLOCK_ORDER:
		_check(not mission.get_node(block_name).visible, "Bloco concluído voltou a aparecer: %s" % block_name)

	mission.queue_free()
	await process_frame

	var restored_mission := scene.instantiate()
	root.add_child(restored_mission)
	var restore_completed_count := 0
	restored_mission.completed.connect(func(): restore_completed_count += 1)
	await process_frame
	restored_mission.restore_completed()
	_check(restored_mission.solved, "Uma missão concluída não foi restaurada em uma instância nova.")
	_check(restore_completed_count == 0, "Restaurar uma instância nova não deve emitir completed.")
	restored_mission.queue_free()
	await process_frame

	if _failed:
		quit(1)
		return
	print("Rack mission checks passed: drag, invalid drop, completion and restore.")
	quit(0)


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
