extends SceneTree

const MENU := "res://scenes/menu.tscn"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var session := root.get_node("StudySession")
	var transition := root.get_node("SceneTransition")
	var discipline: StudyDiscipline = session.current_discipline()
	assert(change_scene_to_file(MENU) == OK)
	await scene_changed
	current_scene.get_node("%SingleplayerButton").pressed.emit()

	_press_card("Discipline_redes")
	_press_card("Topic_tcp_ip_modelo_osi")
	assert(_button("LaunchButton").text == "Iniciar")
	_cancel()
	assert(_button("Topic_tcp_ip_modelo_osi").has_focus())
	_press_card("Topic_tcp_ip_modelo_osi")
	_button("LaunchButton").pressed.emit()
	await transition.transition_finished
	assert(current_scene.scene_file_path == discipline.topics[0].map_scene)
	assert(session.task_state(&"sinais_osi") == &"locked")
	assert(session.complete(&"rack_osi"))
	await _return_from_world()
	assert(_button("LaunchButton").text == "Continuar")
	_button("LaunchButton").pressed.emit()
	await transition.transition_finished
	assert(session.task_state(&"sinais_osi") == &"available")
	for task in discipline.topics[0].tasks.slice(1):
		assert(session.complete(task.id))
	assert(session.discipline_summary(discipline).completed == 1)

	await _return_from_world()
	assert(_button("LaunchButton").text == "Revisar")
	_cancel()
	_press_card("Topic_routing")
	_button("LaunchButton").pressed.emit()
	await transition.transition_finished
	assert(current_scene.scene_file_path == discipline.topics[1].map_scene)
	var tablet := current_scene.get_node("CanvasLayer/TabletUi")
	tablet.open_ui()
	for task in discipline.topics[1].tasks:
		assert(session.complete(task.id))
	var notice := current_scene.get_node("CanvasLayer/UiController/DisciplineBadgeNotice") as Control
	assert(not notice.visible)
	tablet.close_ui()
	assert(notice.visible and session.badge_earned(discipline.id))

	await _return_from_world()
	_cancel()
	_cancel()
	assert(_button("Discipline_redes").has_focus())
	_cancel()
	current_scene.get_node("%ProfileButton").pressed.emit()
	var earned := current_scene.find_child("EarnedBadges", true, false)
	assert(earned != null and earned.get_child_count() == 1)
	_cancel()
	assert(current_scene.get_node("%ProfileButton").has_focus())

	print("Story menu flow passed: levels, transitions, resume, badge notice and profile.")
	quit()

func _button(node_name: String) -> Button:
	return current_scene.find_child(node_name, true, false) as Button

func _press_card(node_name: String) -> void:
	var card := _button(node_name)
	assert(card != null and card.visible)
	card.grab_focus()
	_action(&"ui_accept")

func _cancel() -> void:
	_action(&"ui_cancel")

func _action(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	root.push_input(event)
	event.pressed = false
	root.push_input(event)

func _return_from_world() -> void:
	var pause := current_scene.get_node("CanvasLayer/Pause")
	pause.open_pause()
	pause._on_return_to_menu_pressed()
	pause._on_confirmation_confirmed()
	await root.get_node("SceneTransition").transition_finished
	await process_frame
