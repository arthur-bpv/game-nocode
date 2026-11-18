extends PanelContainer

const ROW_HEIGHT := 28
const VISIBLE_ROWS := 6

@onready var _toggle: Button = %Toggle
@onready var _details: ScrollContainer = %Details
@onready var _rows: VBoxContainer = %Rows

var _completed := 0
var _total := 0

func _ready() -> void:
	_toggle.pressed.connect(_toggle_details)
	StudySession.progress_changed.connect(_refresh)
	_refresh()

func _refresh() -> void:
	for row in _rows.get_children():
		_rows.remove_child(row)
		row.queue_free()

	var tasks := StudySession.current_topic().tasks
	_total = tasks.size()
	_completed = 0
	for task in tasks:
		var state := StudySession.task_state(task.id)
		_add_row(task.title, state)
		if state == &"completed":
			_completed += 1
	if tasks.is_empty():
		var empty := _label("Nenhuma atividade neste tema", Color("94aab4"), 15)
		empty.custom_minimum_size.y = ROW_HEIGHT
		_rows.add_child(empty)
	_details.custom_minimum_size.y = mini(VISIBLE_ROWS, maxi(1, _total)) * ROW_HEIGHT
	_refresh_header()

func _add_row(task_title: String, state: StringName) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = ROW_HEIGHT
	row.add_theme_constant_override("separation", 10)
	_rows.add_child(row)

	var title := _label(task_title, Color("e8fcff"), 16)
	title.name = "Title"
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.tooltip_text = task_title
	row.add_child(title)
	var state_label := _label(
		GameplayTablet.MISSION_STATE_LABELS.get(state, "INDISPONÍVEL"),
		GameplayTablet.MISSION_STATE_COLORS.get(state, Color("87989e")), 13
	)
	state_label.name = "State"
	row.add_child(state_label)

func _label(value: String, color: Color, font_size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", ThemeDB.fallback_font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _toggle_details() -> void:
	_details.visible = not _details.visible
	_refresh_header()
	# Containers grow to fit their minimum size, so reset the panel when it folds.
	reset_size()

func _refresh_header() -> void:
	_toggle.text = "MISSÕES  %d/%d  [%s]" % [_completed, _total, "-" if _details.visible else "+"]
	_toggle.tooltip_text = "Recolher lista de missões" if _details.visible else "Expandir lista de missões"
