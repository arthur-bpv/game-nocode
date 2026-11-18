extends Control

signal back_requested

const PROFILE_THEME := preload("res://assets/ui/netbot_theme.tres")
const PANEL := Color("0d2230")
const OUTLINE := Color("24515d")
const CYAN := Color("59e6ee")
const MUTED := Color("8fb6bf")
const GOLD := Color("e6c780")
const WHITE := Color("e7f7fa")

var _padding: MarginContainer
var _back: Button
var _scroll: ScrollContainer
var _earned: VBoxContainer
var _locked: VBoxContainer
var _topics: VBoxContainer
var _earned_empty: Label
var _locked_empty: Label
var _topics_empty: Label
var _requirement: Label
var _selected_key := ""
var _badge_selection := ButtonGroup.new()

func _ready() -> void:
	theme = PROFILE_THEME
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_padding = MarginContainer.new()
	add_child(_padding)
	_padding.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_padding.add_theme_constant_override("margin_top", 40)
	_padding.add_theme_constant_override("margin_bottom", 36)

	var screen := VBoxContainer.new()
	screen.add_theme_constant_override("separation", 22)
	_padding.add_child(screen)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 24)
	screen.add_child(header)
	_back = Button.new()
	_back.name = "Back"
	_back.text = "Voltar"
	_back.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_back.pressed.connect(back_requested.emit)
	header.add_child(_back)
	var title := _label("Perfil", 27, CYAN, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(title)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	screen.add_child(_scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 16)
	_scroll.add_child(content)
	content.add_child(_label("Conquistas", 32, WHITE))
	_earned = _add_section(content, "Badges conquistadas", "EarnedBadges", GOLD)
	_earned_empty = _label("Nenhuma badge de disciplina conquistada.", 22, MUTED)
	content.add_child(_earned_empty)
	_locked = _add_section(content, "Badges bloqueadas", "LockedBadges", CYAN)
	_locked_empty = _label("Nenhuma badge de disciplina bloqueada.", 22, MUTED)
	content.add_child(_locked_empty)
	_requirement = _label("", 23, WHITE)
	_requirement.name = "BadgeRequirement"
	var details := PanelContainer.new()
	details.add_theme_stylebox_override("panel", _panel(PANEL, OUTLINE, 16))
	details.add_child(_requirement)
	content.add_child(details)
	_topics = _add_section(content, "Distintivos de assunto", "TopicBadges", CYAN)
	_topics_empty = _label("Nenhum distintivo de assunto conquistado.", 22, MUTED)
	content.add_child(_topics_empty)

	resized.connect(_update_padding)
	StudySession.progress_changed.connect(_refresh_if_visible)
	_update_padding()
	hide()

func open() -> void:
	show()
	_refresh()
	_back.grab_focus()

func _update_padding() -> void:
	var margin := maxi(20, roundi((size.x - 960.0) * 0.5))
	_padding.add_theme_constant_override("margin_left", margin)
	_padding.add_theme_constant_override("margin_right", margin)

func _add_section(parent: VBoxContainer, title: String, list_name: String, color: Color) -> VBoxContainer:
	parent.add_child(_label(title, 18, color, true))
	var list := VBoxContainer.new()
	list.name = list_name
	list.add_theme_constant_override("separation", 10)
	parent.add_child(list)
	return list

func _refresh_if_visible() -> void:
	if visible:
		_refresh()

func _refresh() -> void:
	var focus := get_viewport().gui_get_focus_owner()
	var focused_key: String = ""
	if focus != null and is_ancestor_of(focus) and focus.has_meta("badge_key"):
		focused_key = focus.get_meta("badge_key")
	for list in [_earned, _locked, _topics]:
		for child in list.get_children():
			list.remove_child(child)
			child.queue_free()
	_requirement.text = "Selecione uma badge ou um distintivo para ver seu requisito."
	for discipline in StudySession.catalog.disciplines:
		var summary := StudySession.discipline_summary(discipline)
		var total: int = summary.total
		if total > 0 or summary.earned:
			_add_discipline_badge(discipline, summary, focused_key)
		for topic in discipline.topics:
			if StudySession.topic_completed(discipline.id, topic.id):
				var key := "%s/%s" % [discipline.id, topic.id]
				var detail := "%s · %s\nRequisito: conclua as atividades obrigatórias deste assunto." % [topic.title, discipline.title]
				_add_badge(_topics, key, topic.title, "Distintivo de assunto conquistado", detail, topic.icon, true, focused_key)
	_earned_empty.visible = _earned.get_child_count() == 0
	_locked_empty.visible = _locked.get_child_count() == 0
	_topics_empty.visible = _topics.get_child_count() == 0

func _add_discipline_badge(discipline: StudyDiscipline, summary: Dictionary, focused_key: String) -> void:
	var earned: bool = summary.earned
	var title := "Conclusão de %s" % discipline.title
	var status := "✓ Conquistada" if earned else "Bloqueada"
	var detail := "%s\nDisciplina: %s\nRequisito: conclua todos os assuntos obrigatórios da disciplina.\n%s · %d de %d assuntos obrigatórios concluídos." % [
		title, discipline.title, status, summary.completed, summary.total,
	]
	_add_badge(
		_earned if earned else _locked,
		String(discipline.id), title, "%s · %d/%d assuntos" % [status, summary.completed, summary.total],
		detail, discipline.badge_icon, earned, focused_key
	)

func _add_badge(parent: VBoxContainer, key: String, title: String, status: String, detail: String, icon: Texture2D, earned: bool, focused_key: String) -> void:
	var button := Button.new()
	button.toggle_mode = true
	button.button_group = _badge_selection
	button.set_meta("badge_key", key)
	button.tooltip_text = title
	button.accessibility_name = "%s, %s" % [title, status]
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size.y = 88
	button.add_theme_stylebox_override("normal", _panel(PANEL, OUTLINE, 0))
	button.add_theme_stylebox_override("hover", _panel(Color("123346"), CYAN, 0))
	button.add_theme_stylebox_override("pressed", _panel(Color("143c46"), CYAN, 0))
	var focus_style := _panel(Color.TRANSPARENT, CYAN, 0)
	button.add_theme_stylebox_override("focus", focus_style)
	button.pressed.connect(_select_badge.bind(key, detail))
	parent.add_child(button)
	var margins := MarginContainer.new()
	margins.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(margins)
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margins.add_theme_constant_override("margin_left", 16)
	margins.add_theme_constant_override("margin_right", 16)
	margins.add_theme_constant_override("margin_top", 8)
	margins.add_theme_constant_override("margin_bottom", 8)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 16)
	margins.add_child(row)
	var emblem := TextureRect.new()
	emblem.texture = icon
	emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	emblem.custom_minimum_size = Vector2(58, 58)
	emblem.modulate = Color.WHITE if earned else Color("718c95")
	emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(emblem)
	var copy := VBoxContainer.new()
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.add_theme_constant_override("separation", 2)
	row.add_child(copy)
	copy.add_child(_label(title, 25, WHITE))
	copy.add_child(_label(status, 21, GOLD if earned else MUTED))
	margins.minimum_size_changed.connect(func() -> void:
		button.custom_minimum_size.y = maxf(88, margins.get_combined_minimum_size().y)
	)
	if _selected_key == key:
		button.set_pressed_no_signal(true)
		_requirement.text = detail
	if focused_key == key:
		button.grab_focus()

func _select_badge(key: String, detail: String) -> void:
	_selected_key = key
	_requirement.text = detail
	_scroll.ensure_control_visible.call_deferred(_requirement)

func _label(text: String, point_size: int, color: Color, pixel: bool = false) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", point_size)
	label.add_theme_color_override("font_color", color)
	if not pixel:
		label.add_theme_font_override("font", ThemeDB.fallback_font)
	return label

func _panel(color: Color, border: Color, padding: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_content_margin(side, padding)
	return style
