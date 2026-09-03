extends SceneTree

const WORLD_SCENE := "res://scenes/world/world.tscn"

var transition_started := false
var transition_finished := false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var transition := root.get_node("SceneTransition")
	transition.transition_started.connect(_on_transition_started)
	transition.transition_finished.connect(_on_transition_finished)
	transition.change_scene(WORLD_SCENE)
	await process_frame
	assert(transition_started, "A transição não sinalizou o início.")
	assert(transition.get_child(0).visible, "O loading minimalista não ficou visível.")

	var frames_waited := 0
	while not transition_finished and frames_waited < 600:
		await process_frame
		frames_waited += 1
	assert(transition_finished, "A transição não terminou dentro do limite.")
	assert(current_scene != null and current_scene.name == "World", "A cena final não é o mundo.")
	assert(not transition.get_child(0).visible, "O loading não foi ocultado ao terminar.")
	print("Scene transition runtime checks passed in %d frames." % frames_waited)
	quit(0)

func _on_transition_started(_scene_path: String) -> void:
	transition_started = true

func _on_transition_finished(_scene_path: String) -> void:
	transition_finished = true
