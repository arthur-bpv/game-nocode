extends Node2D

const INITIAL_WAIT := 120.0
const RETURN_WAIT := 60.0
const BOX_TOTAL := 3
const DEFECTS := [
	["Lacre rompido", "Etiqueta ilegível"],
	[],
	["Caixa amassada", "Etiqueta divergente"]
]

var queue_index := 0
var active_defects: Array = []
var current_box := 0
var returning := false
var gate_open := false
var box_visible := false
var box_x := -180.0
var remaining := INITIAL_WAIT
var phase := "waiting"

var status_label: Label
var timer_label: Label
var package_label: Label
var input: LineEdit
var submit_button: Button
var approve_button: Button
var feedback_label: Label

func _ready() -> void:
	queue_redraw()
	_build_terminal()
	_start_wait(INITIAL_WAIT, false)

func _build_terminal() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var panel := PanelContainer.new()
	panel.position = Vector2(835, 75)
	panel.size = Vector2(400, 545)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("17242d")
	style.border_color = Color("40e4ff")
	style.set_border_width_all(3)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	panel.add_theme_stylebox_override("panel", style)
	canvas.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	panel.add_child(content)
	var title := Label.new()
	title.text = "TERMINAL DE INSPEÇÃO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("40e4ff"))
	content.add_child(title)
	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 17)
	content.add_child(status_label)
	timer_label = Label.new()
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.add_theme_font_size_override("font_size", 36)
	timer_label.add_theme_color_override("font_color", Color("ffd866"))
	content.add_child(timer_label)
	var separator := HSeparator.new()
	content.add_child(separator)
	package_label = Label.new()
	package_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	package_label.add_theme_font_size_override("font_size", 16)
	content.add_child(package_label)
	input = LineEdit.new()
	input.placeholder_text = "Falhas separadas por vírgula"
	input.editable = false
	input.text_submitted.connect(func(_text): _submit_defects())
	content.add_child(input)
	submit_button = Button.new()
	submit_button.text = "REENVIAR PARA CORREÇÃO"
	submit_button.disabled = true
	submit_button.pressed.connect(_submit_defects)
	content.add_child(submit_button)
	approve_button = Button.new()
	approve_button.text = "APROVAR PACOTE"
	approve_button.disabled = true
	approve_button.pressed.connect(_approve_box)
	content.add_child(approve_button)
	feedback_label = Label.new()
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.add_theme_font_size_override("font_size", 15)
	content.add_child(feedback_label)

func _start_wait(duration: float, is_return: bool) -> void:
	remaining = duration
	returning = is_return
	gate_open = false
	box_visible = false
	box_x = -180.0
	phase = "waiting"
	input.editable = false
	submit_button.disabled = true
	approve_button.disabled = true
	input.text = ""
	package_label.text = "Esteira livre. Aguarde o próximo pacote."
	feedback_label.text = ""
	status_label.text = "PACOTE EM CORREÇÃO" if is_return else "PRÓXIMO PACOTE EM TRIAGEM"
	queue_redraw()

func _process(delta: float) -> void:
	if phase == "waiting":
		remaining = maxf(0.0, remaining - delta)
		if remaining <= 0.0:
			phase = "opening_gate"
			gate_open = true
			status_label.text = "ALÇAPÃO ABERTO — pacote liberado"
	elif phase == "opening_gate":
		box_x = move_toward(box_x, 370.0, delta * 390.0)
		if box_x >= 370.0:
			phase = "inspection"
			box_visible = true
			_open_inspection()
	_update_timer()
	queue_redraw()

func _update_timer() -> void:
	var minutes := int(remaining / 60.0)
	var seconds := int(remaining) % 60
	timer_label.text = "%02d:%02d" % [minutes, seconds] if phase == "waiting" else "PRONTO"

func _open_inspection() -> void:
	active_defects = [] if returning else DEFECTS[queue_index].duplicate()
	current_box = queue_index + 1
	status_label.text = "PACOTE %d DE %d — ANALISE VISUALMENTE" % [current_box, BOX_TOTAL]
	var visible_notes := "Nenhuma falha aparente." if active_defects.is_empty() else "Sinais visíveis: %s" % ", ".join(active_defects)
	package_label.text = "Pacote #%d\n%s\n\nSe houver falhas, digite exatamente os nomes encontrados e reenvie." % [current_box, visible_notes]
	input.editable = not active_defects.is_empty()
	submit_button.disabled = active_defects.is_empty()
	approve_button.disabled = not active_defects.is_empty()
	feedback_label.text = "Pacote sem defeitos: aprove-o." if active_defects.is_empty() else "Identifique todas as falhas antes de reenviar."

func _submit_defects() -> void:
	if phase != "inspection" or active_defects.is_empty():
		return
	var reported: Array = []
	for item in input.text.split(",", false):
		reported.append(item.strip_edges().to_lower())
	var expected: Array = []
	for defect in active_defects:
		expected.append(String(defect).to_lower())
	reported.sort()
	expected.sort()
	if reported == expected:
		feedback_label.text = "Falhas registradas. O pacote volta corrigido em 01:00."
		_start_wait(RETURN_WAIT, true)
	else:
		feedback_label.text = "Relatório incompleto ou incorreto. Revise o pacote e tente novamente."

func _approve_box() -> void:
	if phase != "inspection" or not active_defects.is_empty():
		return
	queue_index += 1
	returning = false
	if queue_index >= BOX_TOTAL:
		_finish_shift()
	else:
		_start_wait(INITIAL_WAIT, false)

func _finish_shift() -> void:
	phase = "complete"
	gate_open = false
	box_visible = false
	status_label.text = "TURNO CONCLUÍDO"
	timer_label.text = "3/3"
	package_label.text = "Todos os três pacotes foram analisados e liberados."
	feedback_label.text = "Excelente trabalho."
	input.editable = false
	submit_button.disabled = true
	approve_button.disabled = true
	queue_redraw()

func _draw() -> void:
	# Background and industrial floor.
	draw_rect(Rect2(0, 0, 1280, 720), Color("5f6473"))
	draw_rect(Rect2(0, 455, 1280, 265), Color("385e49"))
	# Inspection room and walls, modeled after the supplied layout.
	draw_rect(Rect2(270, 70, 455, 410), Color("090c0e"))
	draw_rect(Rect2(278, 78, 439, 94), Color("8e94a5"))
	draw_rect(Rect2(278, 178, 439, 294), Color("315f48"))
	draw_rect(Rect2(0, 340, 270, 115), Color("0a0b0d"))
	draw_rect(Rect2(8, 350, 250, 94), Color("8e94a5"))
	draw_rect(Rect2(725, 340, 110, 115), Color("0a0b0d"))
	draw_rect(Rect2(735, 350, 100, 94), Color("8e94a5"))
	# Conveyor and rollers.
	draw_rect(Rect2(0, 490, 820, 125), Color("111820"))
	draw_rect(Rect2(0, 500, 820, 105), Color("4e5966"))
	for x in range(0, 820, 24):
		draw_line(Vector2(x, 505), Vector2(x, 600), Color("29313b"), 3)
	# Gate at the conveyor entrance.
	var gate_height := 12.0 if gate_open else 112.0
	draw_rect(Rect2(170, 388, 16, gate_height), Color("101419"))
	draw_rect(Rect2(174, 392, 8, gate_height - 6), Color("788092"))
	# Player marker.
	draw_circle(Vector2(115, 430), 26, Color("202932"))
	draw_circle(Vector2(115, 422), 15, Color("3cf1ff"))
	draw_rect(Rect2(99, 450, 32, 40), Color("202932"))
	# Package.
	if phase == "opening_gate" or phase == "inspection":
		draw_rect(Rect2(box_x, 514, 114, 76), Color("9a683b"))
		draw_rect(Rect2(box_x + 5, 519, 104, 66), Color("c68a51"), false, 3)
		draw_line(Vector2(box_x + 57, 514), Vector2(box_x + 57, 590), Color("ede0b5"), 7)
		draw_rect(Rect2(box_x + 20, 532, 25, 19), Color.WHITE)
	# Labels in the world.
	draw_string(ThemeDB.fallback_font, Vector2(35, 665), "OPERADOR", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("d8eff3"))
	draw_string(ThemeDB.fallback_font, Vector2(315, 130), "SALA DE INSPEÇÃO", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("e6ecf5"))
