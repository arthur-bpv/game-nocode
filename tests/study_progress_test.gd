extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var catalog = load("res://data/study/catalog.tres")
	assert(catalog != null)
	assert(catalog.validate().is_empty())
	var progress = load("res://scripts/study/task_progress.gd").new()
	var topic = catalog.disciplines[0].topics[0].duplicate(true)
	var second = topic.tasks[0].duplicate(true)
	second.id = &"second"
	topic.tasks.append(second)
	assert(progress.state(&"redes", topic, topic.tasks[0].id) == &"available")
	assert(progress.state(&"redes", topic, &"second") == &"locked")
	assert(not progress.complete(&"redes", topic, &"second"))
	assert(progress.complete(&"redes", topic, topic.tasks[0].id))
	assert(progress.state(&"redes", topic, &"second") == &"available")
	assert(progress.state(&"other", topic, &"second") == &"locked")
	assert(not progress.complete(&"redes", topic, &"unknown"))
	var restored = load("res://scripts/study/task_progress.gd").new()
	assert(restored.restore(progress.snapshot()))
	assert(restored.state(&"redes", topic, topic.tasks[0].id) == &"completed")
	assert(not restored.restore({"version": 999}))
	assert(restored.state(&"redes", topic, &"second") == &"available")
	second.enabled = false
	assert(restored.state(&"redes", topic, &"second") == &"unavailable")
	assert(not restored.complete(&"redes", topic, &"second"))
	second.enabled = true
	var third = second.duplicate(true)
	third.id = &"third"
	topic.tasks.append(third)
	assert(restored.state(&"redes", topic, &"third") == &"locked")
	assert(restored.complete(&"redes", topic, &"second"))
	assert(restored.state(&"redes", topic, &"third") == &"available")
	assert(restored.complete(&"redes", topic, &"third"))
	assert(restored.state(&"redes", topic, &"third") == &"completed")
	topic.sequential = false
	assert(restored.state(&"new_discipline", topic, &"third") == &"available")
	assert(not restored.restore({"version": 1, "completed": {"redes": {"osi": [42]}}}))
	var independent = restored.snapshot()
	independent.completed.clear()
	assert(restored.state(&"redes", topic, &"third") == &"completed")
	var invalid = catalog.duplicate(true)
	invalid.disciplines.append(invalid.disciplines[0])
	assert(not invalid.validate().is_empty())
	invalid = catalog.duplicate(true)
	invalid.disciplines[0].topics[0].tasks[0].mission_scene = "res://missing.tscn"
	assert(not invalid.validate().is_empty())
	print("Study progress checks passed.")
	quit()
