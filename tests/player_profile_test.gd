extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var profile_script := load("res://scripts/ui/player_profile.gd") as GDScript
	var notice_scene := load("res://scenes/ui/discipline_badge_notice.tscn") as PackedScene
	assert(profile_script != null and notice_scene != null)
	var profile: Control = profile_script.new()
	root.add_child(profile)
	profile.open()
	await process_frame

	var session := root.get_node("StudySession")
	var discipline: StudyDiscipline = session.current_discipline()
	var earned := profile.find_child("EarnedBadges", true, false)
	var locked := profile.find_child("LockedBadges", true, false)
	assert(earned.get_child_count() == 0 and locked.get_child_count() == 1)
	var first: Button = locked.get_child(0)
	assert(root.gui_get_focus_owner() == profile.find_child("Back", true, false))
	_press_key(KEY_TAB)
	assert(root.gui_get_focus_owner() == first)
	_press_key(KEY_ENTER)
	var detail := profile.find_child("BadgeRequirement", true, false) as Label
	assert(discipline.title in detail.text and first.button_pressed)

	var notice: Control = notice_scene.instantiate()
	root.add_child(notice)
	assert(not notice.visible)
	notice.show_badge(discipline)
	assert(notice.visible and notice.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	assert(notice.get_node("%BadgeName").text == discipline.title)
	assert(notice.get_node("%BadgeIcon").texture != null)
	notice.get_node("HideTimer").timeout.emit()
	assert(not notice.visible)

	for topic in discipline.topics:
		assert(session.select(discipline.id, topic.id))
		for task in topic.tasks:
			if task.enabled:
				assert(session.complete(task.id))
	await process_frame
	assert(earned.get_child_count() == 1 and locked.get_child_count() == 0)
	var topics := profile.find_child("TopicBadges", true, false)
	assert(topics.get_child_count() == discipline.topics.size())

	profile.queue_free()
	notice.queue_free()
	await create_timer(0.2).timeout
	print("Player profile checks passed.")
	quit()

func _press_key(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = true
	root.push_input(event)
	event.pressed = false
	root.push_input(event)
