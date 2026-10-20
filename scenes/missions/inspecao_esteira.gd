extends Control

signal completed
signal close_requested
signal mentor_message(message: String, duration: float)
signal mentor_context(message: String)

const INITIAL_WAIT := 120.0
const RETURN_WAIT := 60.0
const BOX_TOTAL := 3
const DEFECTS := [
	["Lacre rompido", "Etiqueta ilegível"],
	[],
	["Caixa amassada", "Etiqueta divergente"]
]
const DEFECT_OPTIONS := [
	"Lacre rompido", "Etiqueta ilegível", "Caixa amassada",
	"Etiqueta divergente", "Embalagem molhada", "Produto errado"
]
const CONVEYOR_WALL_TEXTURE := preload("res://assets/sprites/EsteiraParede.png")

var queue_index := 0
var active_defects: Array = []
var returning := false
var package_visible := false
var remaining := INITIAL_WAIT
var phase := "waiting"
var completed_once := false

var map_sprite: TextureRect
var map_timer: Label
var status_label: Label
var timer_label: Label
var package_label: Label
var defect_menu: VBoxContainer
var submit_button: Button
var approve_button: Button
var feedback_label: Label
var package_drawer: PanelContainer
var defect_toggles: Dictionary = {}

func _ready() -> void:
	size = Vector2(800, 520)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_inspection_screen()
	_start_wait(INITIAL_WAIT, false)

func mentor_intro() -> String:
	return "A esteira de inspeção fica na parede. O contador verde mostra quando o próximo pacote chegará. Pressione [E] para abrir a inspeção."

func get_map_timer_text() -> String:
	if phase == "complete":
		return "3/3"
	if phase == "inspection":
		return "PRONTO"
	var minutes := int(remaining / 60.0)
	var seconds := int(remaining) % 60
	return "%02d:%02d" % [minutes, seconds]

func is_package_ready() -> bool:
	return phase == "inspection"

func _build_inspection_screen() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color("101b20")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	var title := Label.new()
	title.text = "LINHA DE INSPEÇÃO DE PACOTES"
	title.position = Vector2(34, 22)
	title.size = Vector2(732, 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("40e4ff"))
	add_child(title)

	var machine := PanelContainer.new()
	machine.position = Vector2(36, 82)
	machine.size = Vector2(430, 338)
	machine.add_theme_stylebox_override("panel", _panel_style(Color("0b1217"), Color("40e4ff")))
	add_child(machine)
	var machine_view := Control.new()
	machine.add_child(machine_view)

	var machine_label := Label.new()
	machine_label.text = "ESTEIRA — SAÍDA NA PAREDE"
	machine_label.position = Vector2(24, 18)
	machine_label.size = Vector2(382, 28)
	machine_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	machine_label.add_theme_font_size_override("font_size", 16)
	machine_label.add_theme_color_override("font_color", Color("e8fcff"))
	machine_view.add_child(machine_label)

	map_sprite = TextureRect.new()
	map_sprite.texture = CONVEYOR_WALL_TEXTURE
	map_sprite.position = Vector2(103, 67)
	map_sprite.size = Vector2(224, 224)
	map_sprite.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	map_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	machine_view.add_child(map_sprite)

	map_timer = Label.new()
	map_timer.position = Vector2(113, 83)
	map_timer.size = Vector2(212, 100)
	map_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	map_timer.add_theme_font_size_override("font_size", 22)
	map_timer.add_theme_color_override("font_color", Color("101419"))
	map_timer.add_theme_color_override("font_outline_color", Color("d6ffd7"))
	map_timer.add_theme_constant_override("outline_size", 1)
	map_timer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	machine_view.add_child(map_timer)

	package_drawer = PanelContainer.new()
	package_drawer.position = Vector2(166, 244)
	package_drawer.size = Vector2(100, 62)
	package_drawer.add_theme_stylebox_override("panel", _panel_style(Color("c68a51"), Color("ede0b5")))
	machine_view.add_child(package_drawer)
	var package_mark := Label.new()
	package_mark.text = "PACOTE"
	package_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	package_mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	package_mark.add_theme_font_size_override("font_size", 13)
	package_mark.add_theme_color_override("font_color", Color("25170c"))
	package_drawer.add_child(package_mark)
	package_drawer.name = "Package"
	package_drawer.hide()

	var info := VBoxContainer.new()
	info.position = Vector2(488, 82)
	info.size = Vector2(276, 338)
	info.add_theme_constant_override("separation", 10)
	add_child(info)

	var terminal_title := Label.new()
	terminal_title.text = "TERMINAL DE INSPEÇÃO"
	terminal_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	terminal_title.add_theme_font_size_override("font_size", 19)
	terminal_title.add_theme_color_override("font_color", Color("40e4ff"))
	info.add_child(terminal_title)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 14)
	info.add_child(status_label)

	timer_label = Label.new()
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.add_theme_font_size_override("font_size", 28)
	timer_label.add_theme_color_override("font_color", Color("ffd866"))
	info.add_child(timer_label)

	package_label = Label.new()
	package_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	package_label.add_theme_font_size_override("font_size", 13)
	info.add_child(package_label)

	defect_menu = VBoxContainer.new()
	defect_menu.add_theme_constant_override("separation", 1)
	info.add_child(defect_menu)

	submit_button = Button.new()
	submit_button.text = "REENVIAR PARA CORREÇÃO"
	submit_button.pressed.connect(_submit_defects)
	info.add_child(submit_button)

	approve_button = Button.new()
	approve_button.text = "APROVAR PACOTE"
	approve_button.pressed.connect(_approve_box)
	info.add_child(approve_button)

	feedback_label = Label.new()
	feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	feedback_label.add_theme_font_size_override("font_size", 12)
	feedback_label.add_theme_color_override("font_color", Color("d8eff3"))
	info.add_child(feedback_label)

	var close_button := Button.new()
	close_button.text = "X"
	close_button.position = Vector2(750, 16)
	close_button.size = Vector2(34, 34)
	close_button.add_theme_font_size_override("font_size", 18)
	close_button.tooltip_text = "Fechar inspeção"
	close_button.pressed.connect(func() -> void: close_requested.emit())
	add_child(close_button)

func _panel_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style

func _process(delta: float) -> void:
	if phase == "waiting":
		remaining = maxf(0.0, remaining - delta)
		if remaining <= 0.0:
			phase = "arriving"
			mentor_message.emit("O alçapão abriu: um pacote está saindo da parede.", 3.0)
	elif phase == "arriving":
		phase = "inspection"
		package_visible = true
		_open_inspection()
	_refresh_ui()

func _start_wait(duration: float, is_return: bool) -> void:
	remaining = duration
	returning = is_return
	package_visible = false
	phase = "waiting"
	active_defects.clear()
	_configure_choices(false)
	feedback_label.text = ""
	submit_button.disabled = true
	approve_button.disabled = true
	mentor_context.emit("Pacote retorna em 01:00." if is_return else "Próximo pacote chega em 02:00.")
	_refresh_ui()

func _open_inspection() -> void:
	active_defects = [] if returning else DEFECTS[queue_index].duplicate()
	var current_box := queue_index + 1
	status_label.text = "PACOTE %d DE %d — ANALISE VISUALMENTE" % [current_box, BOX_TOTAL]
	package_label.text = "O pacote saiu da abertura. Selecione as falhas que encontrou." if not active_defects.is_empty() else "Nenhuma falha aparente. Aprove o pacote."
	feedback_label.text = ""
	_configure_choices(not active_defects.is_empty())
	submit_button.disabled = active_defects.is_empty()
	approve_button.disabled = not active_defects.is_empty()
	mentor_context.emit("Pacote pronto para inspeção. Use o menu de seleção.")

func _refresh_ui() -> void:
	if timer_label == null:
		return
	var map_time := get_map_timer_text()
	map_timer.text = map_time
	timer_label.text = map_time
	if package_drawer != null:
		package_drawer.visible = package_visible
	if phase == "waiting":
		status_label.text = "PACOTE EM CORREÇÃO" if returning else "PRÓXIMO PACOTE EM TRIAGEM"
		package_label.text = "A esteira está livre. O temporizador da faixa verde continua contando."
	elif phase == "arriving":
		status_label.text = "ALÇAPÃO ABERTO"
		package_label.text = "O pacote está saindo da parede."
	elif phase == "complete":
		status_label.text = "TURNO CONCLUÍDO"
		package_label.text = "As três caixas foram analisadas e liberadas."
		timer_label.text = "3/3"
		map_timer.text = "3/3"

func _configure_choices(enabled: bool) -> void:
	if defect_menu == null:
		return
	for child in defect_menu.get_children():
		child.queue_free()
	defect_toggles.clear()
	if not enabled:
		defect_menu.hide()
		return
	defect_menu.show()
	var heading := Label.new()
	heading.text = "Falhas encontradas:"
	heading.add_theme_font_size_override("font_size", 13)
	defect_menu.add_child(heading)
	for defect in DEFECT_OPTIONS:
		var toggle := CheckButton.new()
		toggle.text = defect
		toggle.add_theme_font_size_override("font_size", 12)
		defect_menu.add_child(toggle)
		defect_toggles[defect.to_lower()] = toggle

func _submit_defects() -> void:
	if phase != "inspection" or active_defects.is_empty():
		return
	var reported: Array = []
	for name in defect_toggles:
		var toggle := defect_toggles[name] as CheckButton
		if toggle.button_pressed:
			reported.append(name)
	var expected: Array = []
	for defect in active_defects:
		expected.append(String(defect).to_lower())
	reported.sort()
	expected.sort()
	if reported == expected:
		feedback_label.text = "Falhas registradas. O pacote volta corrigido em 01:00."
		_start_wait(RETURN_WAIT, true)
	else:
		feedback_label.text = "Seleção incorreta. Revise o pacote e ajuste as opções."

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
	package_visible = false
	_configure_choices(false)
	submit_button.disabled = true
	approve_button.disabled = true
	feedback_label.text = "Excelente trabalho."
	mentor_context.emit("")
	if not completed_once:
		completed_once = true
		completed.emit()
	_refresh_ui()

func restore_completed() -> void:
	completed_once = true
	queue_index = BOX_TOTAL
	phase = "complete"
	package_visible = false
	if feedback_label != null:
		_configure_choices(false)
		submit_button.disabled = true
		approve_button.disabled = true
		feedback_label.text = "Atividade concluída."
		_refresh_ui()
