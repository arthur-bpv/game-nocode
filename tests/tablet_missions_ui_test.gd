extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var session := root.get_node("StudySession")
	var world := (load("res://scenes/world/world.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame

	var tablet := world.get_node("CanvasLayer/TabletUi")
	tablet.open_ui()
	tablet._on_missions_pressed()
	await process_frame

	assert(tablet.get_node("%MissionsView").visible, "A visão de missões não foi exibida.")
	assert(not tablet.get_node("%StatusLabel").visible, "O texto genérico não deve competir com os cards.")
	assert(not tablet.map_rect.visible, "O mapa deve ficar oculto na aba de missões.")
	assert(tablet.get_node("%TopicTitle").text == session.current_topic().title, "O tema atual não foi identificado.")
	var total: int = session.current_topic().tasks.size()
	assert(tablet.get_node("%MissionList").get_child_count() == total, "Cada missão precisa de um card próprio.")
	assert(tablet.get_node("%MissionProgress").max_value == total, "O total da barra está incorreto.")
	assert(tablet.get_node("%MissionProgress").value == 0, "O progresso inicial deve começar vazio.")

	var first_card := tablet.get_node("%MissionList").get_child(0)
	assert(first_card.get_node("Content/Details/Title").text == session.current_topic().tasks[0].title)
	assert(first_card.get_node("Content/Details/State").text == "DISPONÍVEL")

	assert(session.complete(session.current_topic().tasks[0].id))
	await process_frame
	assert(tablet.get_node("%MissionProgress").value == 1, "A barra não acompanhou a primeira conclusão.")
	first_card = tablet.get_node("%MissionList").get_child(0)
	assert(first_card.get_node("Content/Details/State").text == "CONCLUÍDA")

	for index in range(1, total):
		assert(session.complete(session.current_topic().tasks[index].id))
		await process_frame
		assert(tablet.get_node("%MissionProgress").value == index + 1,
			"A barra deve avançar a cada missão concluída.")
	assert(tablet.get_node("%ProgressCount").text == "%d / %d" % [total, total])
	assert(tablet.get_node("%ProgressLabel").text == "TEMA CONCLUÍDO")

	world.queue_free()
	await process_frame
	print("Tablet missions UI checks passed: hierarchy, cards, states and progress footer.")
	quit(0)
