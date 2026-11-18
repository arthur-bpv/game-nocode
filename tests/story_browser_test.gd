extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var script := load("res://scripts/ui/story_browser.gd") as GDScript
	assert(script != null, "O modo história precisa de uma interface dedicada.")
	var browser = script.new()
	root.add_child(browser)
	browser.open()
	await process_frame
	var discipline := _button(browser, "Discipline_redes")
	assert(discipline.has_focus())
	assert(browser.find_child("Task_rack_osi", true, false) == null)
	_click(discipline)
	await process_frame
	var topic := _button(browser, "Topic_tcp_ip_modelo_osi")
	var routing := _button(browser, "Topic_routing")
	assert(topic != routing)
	assert(topic.has_focus())
	_accept()
	await process_frame

	var launch := _button(browser, "LaunchButton")
	assert(launch.text == "Iniciar" and launch.has_focus())
	var first: Node = browser.find_child("Task_rack_osi", true, false)
	var second: Node = browser.find_child("Task_sinais_osi", true, false)
	assert(first.get_index() < second.get_index())
	assert(second.find_child("State", true, false).text == "Bloqueada")
	var launches: Array[StringName] = []
	browser.launch_requested.connect(func(_discipline, selected_topic): launches.append(selected_topic.id))
	_accept()
	assert(launches == [&"tcp_ip_modelo_osi"])

	browser.go_back()
	await process_frame
	assert(_button(browser, "Topic_tcp_ip_modelo_osi").has_focus())
	browser.go_back()
	await process_frame
	assert(_button(browser, "Discipline_redes").has_focus())
	browser.open(&"redes", &"routing")
	await process_frame
	assert(_button(browser, "LaunchButton").has_focus())
	assert(browser.find_child("Task_rack_osi", true, false) == null)
	browser.queue_free()
	print("Story browser navigation and task checks passed.")
	quit()


func _button(browser: Control, node_name: String) -> Button:
	var result := browser.find_child(node_name, true, false) as Button
	assert(result != null, "Botão ausente: " + node_name)
	return result


func _click(button: Button) -> void:
	var pointer := InputEventMouseButton.new()
	pointer.button_index = MOUSE_BUTTON_LEFT
	pointer.pressed = true
	pointer.position = button.get_global_rect().get_center()
	root.push_input(pointer, true)
	pointer.pressed = false
	root.push_input(pointer, true)


func _accept() -> void:
	var key := InputEventAction.new()
	key.action = &"ui_accept"
	key.pressed = true
	root.push_input(key)
	key.pressed = false
	root.push_input(key)
