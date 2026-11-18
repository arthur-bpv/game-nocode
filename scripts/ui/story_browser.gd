extends Control

signal back_requested
signal launch_requested(discipline: StudyDiscipline, topic: StudyTopic)

const UI_THEME := preload("res://assets/ui/netbot_theme.tres")
const TEXT := Color("#e4f0f4")
const MUTED := Color("#9bbcc7")
const CYAN := Color("#59e6ee")
const GOLD := Color("#e6c780")
const TEAL := Color("#8eeac6")
const LINE := Color("#285461")

const TOPIC_STATES := {
	&"not_started": ["○", "Não iniciado", MUTED],
	&"in_progress": ["◐", "Em andamento", CYAN],
	&"completed": ["✓", "Concluído", TEAL],
	&"unavailable": ["—", "Em breve", MUTED],
}
const TASK_STATES := {
	&"locked": ["▪", "Bloqueada", MUTED],
	&"available": ["›", "Disponível", CYAN],
	&"completed": ["✓", "Concluída", TEAL],
	&"unavailable": ["—", "Em breve", MUTED],
}

var _discipline: StudyDiscipline
var _topic: StudyTopic
var _margins: MarginContainer
var _shell: VBoxContainer
var _header: HBoxContainer
var _scroll: ScrollContainer
var _body: VBoxContainer
var _footer: HBoxContainer
var _launch_button: Button
var _cards: Array[Button] = []
var _focus_target: String


func _ready() -> void:
	name = "StoryBrowser"
	theme = UI_THEME
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_build_layout()
	resized.connect(_fit_width)
	StudySession.progress_changed.connect(_refresh_if_visible)
	hide()


func open(discipline_id: StringName = &"", topic_id: StringName = &"") -> void:
	_discipline = StudySession.catalog.find_discipline(discipline_id)
	_topic = _discipline.find_topic(topic_id) if _discipline != null else null
	show()
	_render()


func go_back() -> void:
	if _topic != null:
		_focus_target = "Topic_%s" % _topic.id
		_topic = null
	elif _discipline != null:
		_focus_target = "Discipline_%s" % _discipline.id
		_discipline = null
	else:
		hide()
		back_requested.emit()
		return
	_render()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var page := maxi(48, roundi(_scroll.size.y - 40))
	if event.is_action_pressed("ui_page_up", true):
		_scroll.scroll_vertical -= page
	elif event.is_action_pressed("ui_page_down", true):
		_scroll.scroll_vertical += page
	else:
		return
	get_viewport().set_input_as_handled()


func _build_layout() -> void:
	_margins = MarginContainer.new()
	_margins.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_margins.add_theme_constant_override("margin_top", 40)
	_margins.add_theme_constant_override("margin_bottom", 28)
	add_child(_margins)

	_shell = _vbox(24)
	_margins.add_child(_shell)
	_header = HBoxContainer.new()
	_header.add_theme_constant_override("separation", 24)
	_shell.add_child(_header)
	var back := _action("Voltar", go_back)
	back.name = "BackButton"
	_header.add_child(back)
	var breadcrumb := _label("NETBOT  /  MODO HISTÓRIA", 14, MUTED, true)
	breadcrumb.size_flags_horizontal = SIZE_EXPAND_FILL
	breadcrumb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_header.add_child(breadcrumb)

	var rule := ColorRect.new()
	rule.custom_minimum_size.y = 2
	rule.color = LINE
	rule.mouse_filter = MOUSE_FILTER_IGNORE
	_shell.add_child(rule)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_shell.add_child(_scroll)

	_body = _vbox(24)
	_body.size_flags_horizontal = SIZE_EXPAND_FILL
	_body.size_flags_vertical = SIZE_EXPAND_FILL
	_scroll.add_child(_body)
	_footer = HBoxContainer.new()
	_footer.alignment = BoxContainer.ALIGNMENT_END
	_shell.add_child(_footer)
	_launch_button = _action("Iniciar", _launch, true)
	_launch_button.name = "LaunchButton"
	_footer.add_child(_launch_button)


func _fit_width() -> void:
	var edge := maxi(22, roundi((size.x - 1256.0) * 0.5))
	_margins.add_theme_constant_override("margin_left", edge)
	_margins.add_theme_constant_override("margin_right", edge)
	var card_width := clampf(size.x - float(edge * 2) - 18.0, 180.0, 364.0)
	for card in _cards:
		card.custom_minimum_size.x = card_width
	var compact := size.y < 820.0
	_margins.add_theme_constant_override("margin_top", 20 if compact else 40)
	_shell.add_theme_constant_override("separation", 16 if compact else 24)
	_body.add_theme_constant_override("separation", 16 if compact else 24)


func _render() -> void:
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	_cards.clear()
	_footer.visible = _topic != null
	_body.alignment = BoxContainer.ALIGNMENT_CENTER if _topic == null else BoxContainer.ALIGNMENT_BEGIN
	if _topic != null:
		_render_topic()
	elif _discipline != null:
		_render_discipline()
	else:
		_render_catalog()
	_fit_width()
	_scroll.scroll_vertical = 0
	var focus := find_child(_focus_target, true, false) as Button if not _focus_target.is_empty() else null
	_focus_target = ""
	if focus == null or focus.disabled:
		if _topic != null and not _launch_button.disabled:
			focus = _launch_button
		elif not _cards.is_empty():
			focus = _cards[0]
		else:
			focus = _header.get_node("BackButton")
	focus.grab_focus()


func _refresh_if_visible() -> void:
	if not visible:
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null and is_ancestor_of(focus):
		_focus_target = String(focus.name)
	_render()


func _render_catalog() -> void:
	_add_hero("Disciplinas", "Escolha uma disciplina para explorar seus assuntos.", null, true)
	var cards := _card_grid()
	for discipline in StudySession.catalog.disciplines:
		var summary: Dictionary = StudySession.discipline_summary(discipline)
		var card := _add_card(
			cards, "Discipline_%s" % discipline.id, discipline.title, discipline.icon,
			_discipline_state(summary), _open_discipline.bind(discipline)
		)
		_add_progress(card, summary, "%d de %d assuntos concluídos", true)


func _render_discipline() -> void:
	_add_hero(_discipline.title, "Escolha um assunto para consultar suas atividades.", _discipline.icon)
	var summary: Dictionary = StudySession.discipline_summary(_discipline)
	var badge := _vbox(10)
	badge.name = "DisciplineProgress"
	var summary_panel := _panel(Color("#0c1f2c"))
	_body.add_child(summary_panel)
	var badge_row := HBoxContainer.new()
	badge_row.add_theme_constant_override("separation", 18)
	summary_panel.add_child(badge_row)
	if _discipline.badge_icon != null:
		var emblem := _icon(_discipline.badge_icon, 56)
		if not summary.earned:
			emblem.modulate = Color("#829ca5")
		badge_row.add_child(emblem)
	badge.size_flags_horizontal = SIZE_EXPAND_FILL
	badge_row.add_child(badge)
	var state := _discipline_state(summary)
	badge.add_child(_label("%s  %s" % [state[0], state[1]], 19, state[2]))
	_add_progress(badge, summary, "%d de %d assuntos obrigatórios concluídos", true)
	var cards := _card_grid()
	if _discipline.topics.is_empty():
		_body.add_child(_label("Nenhum assunto disponível.", 20, MUTED))
	for topic in _discipline.topics:
		var topic_summary: Dictionary = StudySession.topic_summary(_discipline, topic)
		var card := _add_card(cards, "Topic_%s" % topic.id, topic.title, topic.icon,
			TOPIC_STATES[topic_summary.state], _open_topic.bind(topic))
		_add_progress(card, topic_summary, "%d de %d atividades concluídas")


func _render_topic() -> void:
	_add_hero(_topic.title, _topic.description, _topic.icon)
	var summary: Dictionary = StudySession.topic_summary(_discipline, _topic)
	var section := _vbox(12)
	_body.add_child(section)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	section.add_child(header)
	var title := _label("Atividades", 16, CYAN, true)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(title)
	var counter := _label("%d de %d concluídas" % [summary.completed, summary.total], 18, MUTED)
	counter.autowrap_mode = TextServer.AUTOWRAP_OFF
	header.add_child(counter)
	for task in _topic.tasks:
		_add_task_row(section, task)
	if _topic.tasks.is_empty():
		section.add_child(_label("Atividades em breve.", 20, MUTED))
	_launch_button.disabled = not _can_launch()
	match StringName(summary.state):
		&"completed":
			_launch_button.text = "Revisar"
		&"in_progress":
			_launch_button.text = "Continuar"
		_:
			_launch_button.text = "Iniciar"
	if _launch_button.disabled:
		_launch_button.text = "Em breve"


func _add_hero(title: String, detail: String, art: Texture2D = null, centered: bool = false) -> void:
	var hero := HBoxContainer.new()
	hero.add_theme_constant_override("separation", 24)
	_body.add_child(hero)
	if art != null:
		hero.add_child(_icon(art, 96))
	var heading := _vbox(10)
	heading.alignment = BoxContainer.ALIGNMENT_CENTER
	heading.size_flags_horizontal = SIZE_EXPAND_FILL
	hero.add_child(heading)
	var name_label := _label(title, 40, TEXT)
	name_label.name = "StoryTitle"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT
	heading.add_child(name_label)
	if not detail.is_empty():
		var description := _label(detail, 21, MUTED)
		description.horizontal_alignment = name_label.horizontal_alignment
		heading.add_child(description)


func _card_grid() -> HFlowContainer:
	var grid := HFlowContainer.new()
	grid.alignment = FlowContainer.ALIGNMENT_CENTER
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	_body.add_child(grid)
	return grid


func _add_card(grid: HFlowContainer, node_name: String, title: String, art: Texture2D, state: Array, callback: Callable) -> VBoxContainer:
	var card := _action("", callback)
	card.name = node_name
	card.custom_minimum_size = Vector2(364, 292)
	card.tooltip_text = title
	card.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	grid.add_child(card)
	_cards.append(card)
	var inset := MarginContainer.new()
	inset.mouse_filter = MOUSE_FILTER_IGNORE
	inset.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		inset.add_theme_constant_override("margin_" + side, 18)
	card.add_child(inset)
	var content := _vbox(8)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	inset.add_child(content)
	var art_icon := _icon(art, 76)
	art_icon.size_flags_horizontal = SIZE_SHRINK_CENTER
	content.add_child(art_icon)
	var title_label := _label(title, 24, TEXT)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title_label)
	var status := _label("%s  %s" % [state[0], state[1]], 19, state[2])
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(status)
	return content


func _add_progress(parent: VBoxContainer, summary: Dictionary, caption: String, show_percent: bool = false) -> void:
	var progress := ProgressBar.new()
	progress.max_value = maxi(summary.total, 1)
	progress.value = summary.completed
	progress.show_percentage = false
	progress.custom_minimum_size.y = 10
	progress.mouse_filter = MOUSE_FILTER_IGNORE
	progress.add_theme_stylebox_override("background", _style(Color("#07131c"), LINE, 1))
	progress.add_theme_stylebox_override("fill", _style(TEAL if summary.completed == summary.total else CYAN, Color.TRANSPARENT, 0))
	parent.add_child(progress)
	var text := caption % [summary.completed, summary.total]
	if show_percent and summary.total > 0:
		text += " · %d%%" % roundi(100.0 * summary.completed / summary.total)
	var label := _label(text, 18, MUTED)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(label)


func _add_task_row(parent: VBoxContainer, task: StudyTask) -> void:
	var state: Array = TASK_STATES[StudySession.task_state_for(_discipline.id, _topic, task.id)]
	var panel := _panel(Color("#0b1925"), 12)
	panel.name = "Task_%s" % task.id
	parent.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	var glyph := _label(state[0], 24, state[2])
	glyph.custom_minimum_size.x = 24
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(glyph)
	var title := _label(task.title, 20)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	row.add_child(title)
	var status := _label(state[1], 18, state[2])
	status.name = "State"
	status.custom_minimum_size.x = 94
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(status)


func _open_discipline(discipline: StudyDiscipline) -> void:
	_discipline = discipline
	_render()


func _open_topic(topic: StudyTopic) -> void:
	_topic = topic
	_render()


func _can_launch() -> bool:
	if _topic == null:
		return false
	var map := _topic.map_scene if not _topic.map_scene.is_empty() else _discipline.map_scene
	if map.is_empty():
		return false
	for task in _topic.tasks:
		if StudySession.task_state_for(_discipline.id, _topic, task.id) in [&"available", &"completed"]:
			return true
	return false


func _launch() -> void:
	if _can_launch():
		launch_requested.emit(_discipline, _topic)


func _discipline_state(summary: Dictionary) -> Array:
	if summary.earned:
		return ["★", "Badge conquistada", GOLD]
	if summary.total == 0:
		return ["—", "Badge indisponível", MUTED]
	return ["◇", "Badge bloqueada", MUTED]


func _action(text: String, callback: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(150, 52)
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_stylebox_override("normal", _style(Color("#15576a") if primary else Color("#0d2230"), CYAN if primary else LINE))
	button.add_theme_stylebox_override("hover", _style(Color("#164450"), CYAN))
	button.add_theme_stylebox_override("pressed", _style(Color("#246371"), CYAN))
	button.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, CYAN, 3))
	button.mouse_default_cursor_shape = CURSOR_POINTING_HAND
	button.pressed.connect(callback)
	return button


func _panel(color: Color, margin: int = 18) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := _style(color, LINE, 1)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_BOTTOM, SIDE_TOP]:
		style.set_content_margin(side, margin)
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _style(fill: Color, border: Color, width: int = 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(4)
	return style


func _label(text: String, font_size: int, color: Color = TEXT, pixel: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.mouse_filter = MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	if not pixel:
		label.add_theme_font_override("font", ThemeDB.fallback_font)
	return label


func _vbox(spacing: int) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.mouse_filter = MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", spacing)
	return box


func _icon(texture: Texture2D, extent: float) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = Vector2(extent, extent)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = MOUSE_FILTER_IGNORE
	return icon
