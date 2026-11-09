extends Control

const ATLAS := preload("res://assets/ui/pixellab/ui-atlas.png")
const STORY_ART := preload("res://assets/ui/pixellab/modo-historia.png")
const MULTIPLAYER_ART := preload("res://assets/ui/pixellab/modo-multiplayer.png")

var _form: VBoxContainer
var _disciplines: OptionButton
var _topics: OptionButton
var _trail: VBoxContainer
var _feedback: Label
var _nickname: LineEdit
var _room_field: LineEdit
var _password: LineEdit
var _capacity: SpinBox

@onready var _content: VBoxContainer = $Center/Panel/Content
@onready var _modes: HBoxContainer = $Center/Panel/Content/ModeButtons
@onready var singleplayer_button: Button = %SingleplayerButton
@onready var confirmation: Control = %ConfirmationModal

func _ready() -> void:
	BackgroundMusic.play_menu()
	_form = VBoxContainer.new()
	_form.add_theme_constant_override("separation", 12)
	_content.add_child(_form)
	_content.move_child(_form, _modes.get_index() + 1)
	_form.hide()
	singleplayer_button.grab_focus()
	confirmation.confirmed.connect(_quit_game)

func _on_singleplayer_pressed() -> void:
	_open_form("MODO HISTÓRIA", STORY_ART)
	_build_study_selection()
	_trail = VBoxContainer.new()
	_trail.add_theme_constant_override("separation", 6)
	_form.add_child(_trail)
	_refresh_trail()
	var start := _add_button(_form, "INICIAR PARTIDA", _start_story)
	start.disabled = _topics.item_count == 0
	_topics.item_selected.connect(func(_index: int) -> void: start.disabled = false)
	_disciplines.item_selected.connect(func(_index: int) -> void: start.disabled = _topics.item_count == 0)
	_add_button(_form, "VOLTAR", _show_modes)
	_disciplines.grab_focus()

func _start_story() -> void:
	var discipline := StudySession.catalog.disciplines[_disciplines.selected]
	var topic := discipline.topics[_topics.selected]
	if StudySession.select(discipline.id, topic.id):
		BackgroundMusic.stop_menu()
		SceneTransition.change_scene(topic.map_scene if not topic.map_scene.is_empty() else discipline.map_scene)

func _on_multiplayer_pressed() -> void:
	_open_form("MULTIPLAYER / IDENTIFICAÇÃO", MULTIPLAYER_ART)
	_nickname = _add_field("Nome no jogo", 24)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 16)
	_form.add_child(actions)
	_add_button(actions, "CRIAR SALA", _choose_room_flow.bind(true))
	_add_button(actions, "ENTRAR COM CÓDIGO", _choose_room_flow.bind(false))
	_add_button(_form, "VOLTAR", _show_modes)
	_feedback = _add_label("")
	_nickname.grab_focus()

func _choose_room_flow(creating: bool) -> void:
	var nickname := _nickname.text.strip_edges()
	if nickname.is_empty():
		_feedback.text = "Digite seu nome no jogo."
		return
	_open_form("MULTIPLAYER / " + ("NOVA SALA" if creating else "CONVITE"), MULTIPLAYER_ART)
	_add_label("Jogador: %s  /  Prévia local" % nickname)
	_room_field = _add_field("Nome da sala" if creating else "Código de seis caracteres", 32 if creating else 6)
	if creating:
		_build_study_selection()
		_capacity = SpinBox.new()
		_capacity.min_value = 2
		_capacity.max_value = 4
		_capacity.value = 4
		_capacity.prefix = "Limite de jogadores:"
		_form.add_child(_capacity)
	_password = _add_field("Senha da sala (opcional)", 64)
	_password.secret = true
	_add_button(_form, "REVISAR SALA", _review_room.bind(creating))
	_add_button(_form, "VOLTAR", _on_multiplayer_pressed)
	_feedback = _add_label("")
	_room_field.grab_focus()

func _review_room(creating: bool) -> void:
	var room := _room_field.text.strip_edges()
	if creating:
		if room.is_empty() or _topics.selected < 0:
			_feedback.text = "Informe o nome da sala e selecione o tema."
			return
		_feedback.text = "Sala privada: %s · 1/%d jogadores · %s\n%s\nPrévia local. Servidor ainda não conectado." % [
			room, int(_capacity.value), "com senha" if not _password.text.is_empty() else "sem senha",
			_topics.get_item_text(_topics.selected)]
	else:
		var code_pattern := RegEx.create_from_string("^[A-Za-z0-9]{6}$")
		if code_pattern.search(room) == null:
			_feedback.text = "Informe um código válido de seis caracteres."
			return
		_feedback.text = "Código %s · Prévia local. Servidor ainda não conectado." % room.to_upper()
	_password.clear()

func _open_form(title: String, texture: Texture2D) -> void:
	_clear_form()
	_modes.hide()
	$Center/Panel/Content/Subtitle.text = title
	_form.show()
	var art := TextureRect.new()
	art.texture = texture
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.custom_minimum_size.y = 96
	_form.add_child(art)

func _clear_form() -> void:
	_trail = null
	for child in _form.get_children():
		_form.remove_child(child)
		child.queue_free()

func _show_modes() -> void:
	_clear_form()
	_form.hide()
	_modes.show()
	$Center/Panel/Content/Subtitle.text = "SELECIONE UM MODO DE JOGO"
	singleplayer_button.grab_focus()

func _on_quit_pressed() -> void:
	confirmation.ask("SAIR DO JOGO", "Deseja fechar o NETBOT?", "SAIR")

func _quit_game() -> void:
	get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if confirmation.visible:
		confirmation.cancel()
	elif _form.visible:
		_show_modes()
	else:
		return
	get_viewport().set_input_as_handled()

func _build_study_selection() -> void:
	_disciplines = OptionButton.new()
	_disciplines.name = "DisciplineSelection"
	_disciplines.tooltip_text = "Disciplina"
	_form.add_child(_disciplines)
	_topics = OptionButton.new()
	_topics.name = "TopicSelection"
	_topics.tooltip_text = "Tema"
	_form.add_child(_topics)
	for discipline in StudySession.catalog.disciplines:
		_disciplines.add_item(discipline.title)
		if discipline.id == StudySession.discipline_id:
			_disciplines.select(_disciplines.item_count - 1)
	_disciplines.item_selected.connect(_populate_topics)
	_topics.item_selected.connect(func(_index: int) -> void: _refresh_trail())
	_populate_topics(_disciplines.selected)

func _populate_topics(index: int) -> void:
	_topics.clear()
	if index >= 0:
		for topic in StudySession.catalog.disciplines[index].topics:
			_topics.add_item(topic.title)
			if topic.id == StudySession.topic_id:
				_topics.select(_topics.item_count - 1)
	_refresh_trail()

func _refresh_trail() -> void:
	if _trail == null:
		return
	for child in _trail.get_children():
		_trail.remove_child(child)
		child.queue_free()
	if _topics.selected < 0:
		return
	var discipline := StudySession.catalog.disciplines[_disciplines.selected]
	var topic := discipline.topics[_topics.selected]
	var completed := StudySession.topic_completed(discipline.id, topic.id)
	for task in topic.tasks:
		if not task.enabled:
			continue
		var optional := task.always_available
		var marker := Rect2(167, 126, 34, 34) if completed and not optional else Rect2(108, 126, 34, 34)
		_add_trail_row(task.title + (" (opcional)" if optional else ""), marker)
	_add_trail_row("Distintivo conquistado" if completed else "Conclua as missões obrigatórias na mesma partida", Rect2(237, 122, 42, 42))

func _add_trail_row(text: String, region: Rect2) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_trail.add_child(row)
	var icon := TextureRect.new()
	var texture := AtlasTexture.new()
	texture.atlas = ATLAS
	texture.region = region
	icon.texture = texture
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(32, 30)
	row.add_child(icon)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	row.add_child(label)

func _add_field(placeholder: String, max_length: int) -> LineEdit:
	var input := LineEdit.new()
	input.placeholder_text = placeholder
	input.tooltip_text = placeholder
	input.max_length = max_length
	_form.add_child(input)
	return input

func _add_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 13)
	_form.add_child(label)
	return label

func _add_button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)
	return button
