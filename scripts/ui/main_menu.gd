extends Control

const STORY_BROWSER := preload("res://scripts/ui/story_browser.gd")
const PROFILE_SCREEN := preload("res://scripts/ui/player_profile.gd")
const LAN_SCREEN := preload("res://scripts/lan/screen.gd")

var _story: Control
var _profile: Control
var _lan: VBoxContainer

@onready var _content: VBoxContainer = $Center/Panel/Content
@onready var _modes: HBoxContainer = $Center/Panel/Content/ModeButtons
@onready var singleplayer_button: Button = %SingleplayerButton
@onready var confirmation: Control = %ConfirmationModal

func _ready() -> void:
	BackgroundMusic.play_menu()
	singleplayer_button.grab_focus()
	confirmation.confirmed.connect(_quit_game)
	if PlayerData.story_topic != &"":
		var discipline := PlayerData.story_discipline
		var topic := PlayerData.story_topic
		PlayerData.story_discipline = &""
		PlayerData.story_topic = &""
		_open_story.call_deferred(discipline, topic)

func _on_singleplayer_pressed() -> void:
	_open_story()

func _open_story(discipline_id: StringName = &"", topic_id: StringName = &"") -> void:
	$Center.hide()
	if _story == null:
		_story = STORY_BROWSER.new()
		add_child(_story)
		_story.back_requested.connect(_return_from_story)
		_story.launch_requested.connect(_start_story)
	_story.open(discipline_id, topic_id)

func _return_from_story() -> void:
	_story.hide()
	_show_modes()

func _start_story(discipline: StudyDiscipline, topic: StudyTopic) -> void:
	if StudySession.topic_summary(discipline, topic).state == &"unavailable":
		return
	if StudySession.select(discipline.id, topic.id):
		PlayerData.story_discipline = discipline.id
		PlayerData.story_topic = topic.id
		BackgroundMusic.stop_menu()
		SceneTransition.change_scene(topic.map_scene if not topic.map_scene.is_empty() else discipline.map_scene)

func _on_profile_pressed() -> void:
	$Center.hide()
	if _profile == null:
		_profile = PROFILE_SCREEN.new()
		add_child(_profile)
		_profile.back_requested.connect(_return_from_profile)
	_profile.open()

func _return_from_profile() -> void:
	_profile.hide()
	_show_modes()
	%ProfileButton.grab_focus()

func _on_multiplayer_pressed() -> void:
	_modes.hide()
	$Center/Panel/Content/MenuActions.hide()
	$Center/Panel/Content/Subtitle.text = "MULTIPLAYER LAN"
	_lan = LAN_SCREEN.new()
	_content.add_child(_lan)
	_lan.back_requested.connect(_return_from_lan)

func _return_from_lan() -> void:
	_content.remove_child(_lan)
	_lan.queue_free()
	_lan = null
	_show_modes()

func _show_modes() -> void:
	$Center.show()
	_modes.show()
	$Center/Panel/Content/MenuActions.show()
	$Center/Panel/Content/Subtitle.text = "SELECIONE UM MODO DE JOGO"
	singleplayer_button.grab_focus()

func _on_quit_pressed() -> void:
	confirmation.ask("SAIR DO JOGO", "Deseja fechar o NETBOT?", "SAIR")

func _quit_game() -> void:
	get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel") or event.is_echo():
		return
	if confirmation.visible:
		confirmation.cancel()
	elif _story != null and _story.visible:
		_story.go_back()
	elif _profile != null and _profile.visible:
		_return_from_profile()
	elif _lan != null:
		_lan.go_back()
	else:
		return
	get_viewport().set_input_as_handled()
