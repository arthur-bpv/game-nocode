extends Control

var _disciplines: OptionButton
var _topics: OptionButton

@onready var singleplayer_button: Button = %SingleplayerButton
@onready var confirmation: Control = %ConfirmationModal

func _ready() -> void:
	_build_study_selection()
	singleplayer_button.grab_focus()
	confirmation.confirmed.connect(_quit_game)

func _on_singleplayer_pressed() -> void:
	var discipline := StudySession.catalog.disciplines[_disciplines.selected]
	var topic := discipline.topics[_topics.selected]
	if StudySession.select(discipline.id, topic.id):
		SceneTransition.change_scene(discipline.map_scene)

func _on_quit_pressed() -> void:
	confirmation.ask("SAIR DO JOGO", "Deseja fechar o NETBOT?", "SAIR")

func _quit_game() -> void:
	get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and confirmation.visible:
		confirmation.cancel()
		get_viewport().set_input_as_handled()


func _build_study_selection() -> void:
	var content := $Center/Panel/Content
	_disciplines = OptionButton.new()
	_disciplines.name = "DisciplineSelection"
	_disciplines.tooltip_text = "Disciplina"
	content.add_child(_disciplines)
	content.move_child(_disciplines, 2)
	_topics = OptionButton.new()
	_topics.name = "TopicSelection"
	_topics.tooltip_text = "Tema"
	content.add_child(_topics)
	content.move_child(_topics, 3)
	for discipline in StudySession.catalog.disciplines:
		_disciplines.add_item(discipline.title)
		if discipline.id == StudySession.discipline_id:
			_disciplines.select(_disciplines.item_count - 1)
	_disciplines.item_selected.connect(_populate_topics)
	_populate_topics(_disciplines.selected)

func _populate_topics(index: int) -> void:
	_topics.clear()
	if index < 0:
		singleplayer_button.disabled = true
		return
	for topic in StudySession.catalog.disciplines[index].topics:
		_topics.add_item(topic.title)
		if topic.id == StudySession.topic_id:
			_topics.select(_topics.item_count - 1)
	singleplayer_button.disabled = _topics.item_count == 0
