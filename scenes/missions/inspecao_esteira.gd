extends Control

signal completed
signal close_requested
signal mentor_message(message: String, duration: float)
signal mentor_context(message: String)

const INITIAL_WAIT := 60.0
const RETURN_SECONDS_PER_REPORTED_DEFECT := 15.0
const BOX_TOTAL := 3
# Listas internas da esteira; usadas apenas pela lógica da atividade.
const TCP := [
	"GET /pagina.html HTTP/1.1",
	"GET /index.html HTTP/1.1",
	"GET /imagem.png HTTP/1.1",
	"GET /documento.pdf HTTP/1.1",
	"GET /video.mp4 HTTP/1.1"
]
const UDP := [
	"PLAYER_01.POSITION X:120 Y:085",
	"AUDIO;Player_01;FRAME_025",
	"VIDEO;Player_01;FRAME_025",
	"CONSULTA DNS: servidor.local",
	"CONSULTA DNS: jogo-rede.local"
]
const HTTP := [
	"GET /pagina.html HTTP/1.1",
	"GET /index.html HTTP/1.1",
	"GET /imagem.png HTTP/1.1",
	"GET /documento.pdf HTTP/1.1",
	"GET /video.mp4 HTTP/1.1"
]
const DNS := [
	"PLAYER_01.POSITION X:120 Y:085",
	"AUDIO;Player_01;FRAME_025",
	"VIDEO;Player_01;FRAME_025",
	"CONSULTA DNS: servidor.local",
	"CONSULTA DNS: jogo-rede.local"
]
const DEFECTS := [
	["Dados corrompidos/incompletos", "Endereço IP inválido ou incorreto"],
	[],
	["Protocolo de aplicação incorreto", "Caminho inacessível/congestionado"]
]
const DEFECT_OPTIONS := [
	"Dados corrompidos/incompletos",
	"Endereço IP inválido ou incorreto",
	"Protocolo de aplicação incorreto",
	"Caminho inacessível/congestionado"
]
const CONVEYOR_WALL_TEXTURE := preload("res://assets/sprites/EsteiraParede.png")
const TABLET_FRAME_TEXTURE := preload("res://assets/sprites/tablet_frame.png")
const INSPECTION_PACKAGE_TEXTURE := preload("res://assets/sprites/Pacote.png")

var queue_index := 0
var active_defects: Array = []
var pending_return_defects: Array = []
var round_defects: Array = []
var returning := false
var package_visible := false
var remaining := INITIAL_WAIT
var phase := "waiting"
var completed_once := false
var packet_generated_for := -1
var packet_request := ""
var shown_request := ""
var real_ip := ""
var shown_ip := ""
var expected_application_protocol := ""
var shown_application_protocol := ""
var expected_transport_protocol := ""
var shown_transport_protocol := ""

var map_sprite: TextureRect
var map_timer: Label
var status_label: Label
var timer_label: Label
var package_label: Label
var inspect_hint_label: Label
var inspection_tab: PanelContainer
var package_label_panel: PanelContainer
var tab_request_label: Label
var tab_destination_label: Label
var tab_application_label: Label
var tab_transport_label: Label
var packet_label_value: Label
var defect_menu: VBoxContainer
var submit_button: Button
var approve_button: Button
var feedback_label: Label
var package_drawer: TextureButton
var defect_toggles: Dictionary = {}

func _ready() -> void:
	add_to_group("inspection_tasks")
	# Tamanho da atividade ajustado à abertura útil da moldura do tablet.
	size = Vector2(1120, 734)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_inspection_screen()
	_randomize_round_defects()
	_start_wait(INITIAL_WAIT, false)

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close_task()
		get_viewport().set_input_as_handled()

func is_inspection_active() -> bool:
	return visible

func close_task() -> void:
	close_requested.emit()

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
	backdrop.position = Vector2(160, 100)
	backdrop.size = Vector2(800, 534)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	# A abertura transparente da arte é a área útil da task. A moldura deve
	# acompanhar esse retângulo, não o tamanho reduzido do MissionHost.
	var tablet_frame := Sprite2D.new()
	tablet_frame.texture = TABLET_FRAME_TEXTURE
	const TASK_WINDOW := Rect2(160, 100, 800, 534)
	const TABLET_OPENING_SIZE := Vector2(815, 561)
	const TABLET_OPENING_CENTER := Vector2(908.5, 479.5)
	var texture_center := TABLET_FRAME_TEXTURE.get_size() / 2.0
	tablet_frame.scale = TASK_WINDOW.size / TABLET_OPENING_SIZE
	tablet_frame.position = TASK_WINDOW.get_center() - (
		TABLET_OPENING_CENTER - texture_center
	) * tablet_frame.scale
	tablet_frame.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	tablet_frame.z_index = 1
	add_child(tablet_frame)

	# A moldura do tablet é o único contorno externo da atividade.

	var title := Label.new()
	title.text = "LINHA DE INSPEÇÃO DE PACOTES"
	title.position = Vector2(194, 112)
	title.size = Vector2(690, 36)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("40e4ff"))
	add_child(title)

	var machine := PanelContainer.new()
	machine.position = Vector2(180, 160)
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

	# Reutiliza o mesmo sprite de pacote que percorre a esteira didática.
	package_drawer = TextureButton.new()
	package_drawer.texture_normal = INSPECTION_PACKAGE_TEXTURE
	package_drawer.ignore_texture_size = true
	package_drawer.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	package_drawer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	package_drawer.position = Vector2(145, 204)
	package_drawer.size = Vector2(142, 112)
	package_drawer.tooltip_text = "Clique no pacote para inspecioná-lo"
	package_drawer.pressed.connect(_open_package_tab)
	machine_view.add_child(package_drawer)
	package_drawer.name = "Package"
	package_drawer.hide()

	var info := VBoxContainer.new()
	info.position = Vector2(630, 160)
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

	inspect_hint_label = Label.new()
	inspect_hint_label.text = "Clique no pacote para inspecioná-lo."
	inspect_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspect_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inspect_hint_label.add_theme_font_size_override("font_size", 12)
	inspect_hint_label.add_theme_color_override("font_color", Color("d8eff3"))
	inspect_hint_label.hide()
	info.add_child(inspect_hint_label)

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
	close_button.position = Vector2(920, 108)
	close_button.size = Vector2(34, 34)
	close_button.z_index = 2
	close_button.add_theme_font_size_override("font_size", 18)
	close_button.tooltip_text = "Fechar inspeção"
	close_button.pressed.connect(func() -> void: close_requested.emit())
	add_child(close_button)

	_build_package_tab()

func _build_package_tab() -> void:
	# Painel central com moldura externa e moldura interna.
	inspection_tab = PanelContainer.new()
	inspection_tab.position = Vector2(260, 232)
	inspection_tab.size = Vector2(600, 270)
	inspection_tab.add_theme_stylebox_override("panel", _panel_style(Color("0a151a"), Color("40e4ff"), 3))
	add_child(inspection_tab)

	var outer_content := Control.new()
	inspection_tab.add_child(outer_content)
	var inner_panel := PanelContainer.new()
	inner_panel.position = Vector2(8, 8)
	inner_panel.size = Vector2(584, 254)
	inner_panel.add_theme_stylebox_override("panel", _panel_style(Color("101b20"), Color("2cc8d8"), 2))
	outer_content.add_child(inner_panel)
	var tab_content := Control.new()
	inner_panel.add_child(tab_content)

	var tab_title := Label.new()
	tab_title.text = "DADOS DA TRANSMISSÃO"
	tab_title.position = Vector2(20, 18)
	tab_title.size = Vector2(330, 24)
	tab_title.add_theme_font_size_override("font_size", 17)
	tab_title.add_theme_color_override("font_color", Color("40e4ff"))
	tab_content.add_child(tab_title)

	tab_request_label = _tab_data_label(Vector2(20, 58), Vector2(320, 58))
	tab_destination_label = _tab_data_label(Vector2(20, 120), Vector2(320, 28))
	tab_application_label = _tab_data_label(Vector2(20, 152), Vector2(320, 40))
	tab_transport_label = _tab_data_label(Vector2(20, 198), Vector2(320, 28))
	tab_content.add_child(tab_request_label)
	tab_content.add_child(tab_destination_label)
	tab_content.add_child(tab_application_label)
	tab_content.add_child(tab_transport_label)

	package_label_panel = PanelContainer.new()
	package_label_panel.position = Vector2(366, 58)
	package_label_panel.size = Vector2(194, 132)
	package_label_panel.add_theme_stylebox_override("panel", _panel_style(Color("18242b"), Color("ede0b5"), 2))
	tab_content.add_child(package_label_panel)
	var label_content := Control.new()
	package_label_panel.add_child(label_content)
	var label_title := Label.new()
	label_title.text = "ETIQUETA DO PACOTE"
	label_title.position = Vector2(8, 14)
	label_title.size = Vector2(178, 22)
	label_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label_title.add_theme_font_size_override("font_size", 13)
	label_title.add_theme_color_override("font_color", Color("ede0b5"))
	label_content.add_child(label_title)
	packet_label_value = Label.new()
	packet_label_value.position = Vector2(8, 52)
	packet_label_value.size = Vector2(178, 52)
	packet_label_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	packet_label_value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	packet_label_value.add_theme_font_size_override("font_size", 13)
	packet_label_value.add_theme_color_override("font_color", Color.WHITE)
	label_content.add_child(packet_label_value)

	var close_tab := Button.new()
	close_tab.text = "X"
	close_tab.position = Vector2(544, 10)
	close_tab.size = Vector2(30, 30)
	close_tab.add_theme_font_size_override("font_size", 16)
	close_tab.tooltip_text = "Fechar aba"
	close_tab.pressed.connect(func() -> void: _close_package_tab())
	tab_content.add_child(close_tab)
	inspection_tab.hide()

func _tab_data_label(label_position: Vector2, label_size: Vector2) -> Label:
	var label := Label.new()
	label.position = label_position
	label.size = label_size
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color("e8fcff"))
	return label

func _open_package_tab() -> void:
	if phase != "inspection" or inspection_tab == null:
		return
	_refresh_packet_tab()
	inspection_tab.show()

func _close_package_tab() -> void:
	if inspection_tab != null:
		inspection_tab.hide()

func _prepare_packet_for_current_box() -> void:
	if packet_generated_for == queue_index:
		_apply_packet_faults()
		return
	var all_requests: Array = []
	all_requests.append_array(TCP)
	all_requests.append_array(UDP)
	packet_request = all_requests.pick_random()
	real_ip = "192.168.0." + str(randi_range(1, 254))
	expected_transport_protocol = "TCP" if TCP.has(packet_request) else "UDP"
	if HTTP.has(packet_request):
		expected_application_protocol = "HTTP"
	elif packet_request == "PLAYER_01.POSITION X:120 Y:085":
		expected_application_protocol = "Protocolo de aplicação do jogo"
	elif packet_request == "AUDIO;Player_01;FRAME_025":
		expected_application_protocol = "Protocolo de aplicação de áudio do jogo"
	elif packet_request == "VIDEO;Player_01;FRAME_025":
		expected_application_protocol = "Protocolo de aplicação de vídeo do jogo"
	else:
		expected_application_protocol = "DNS"
	packet_generated_for = queue_index
	_apply_packet_faults()

func _apply_packet_faults() -> void:
	shown_request = packet_request
	shown_ip = real_ip
	shown_application_protocol = expected_application_protocol
	shown_transport_protocol = expected_transport_protocol
	if active_defects.has("Dados corrompidos/incompletos"):
		shown_request = _damage_request_text(packet_request)
	if active_defects.has("Endereço IP inválido ou incorreto"):
		var invalid_octet := randi_range(1, 254)
		if "192.168.0." + str(invalid_octet) == real_ip:
			invalid_octet = 1 if invalid_octet == 254 else invalid_octet + 1
		shown_ip = "192.168.0." + str(invalid_octet)
	if active_defects.has("Protocolo de aplicação incorreto"):
		shown_application_protocol = "DNS" if expected_application_protocol == "HTTP" else "HTTP"
	if active_defects.has("Caminho inacessível/congestionado"):
		shown_transport_protocol = "UDP" if expected_transport_protocol == "TCP" else "TCP"

func _damage_request_text(original: String) -> String:
	# Metade das vezes a perda de dados gera uma lacuna; na outra metade,
	# caracteres do conteúdo são corrompidos sem exibir um rótulo explicativo.
	if randi_range(0, 1) == 0:
		var start := maxi(1, original.length() / 3)
		var amount := maxi(2, original.length() / 5)
		return original.substr(0, start) + " --- " + original.substr(start + amount)
	var damaged := original
	var replacements := ["#", "@", "%", "?", "&"]
	for index in range(2):
		var character_index := randi_range(0, maxi(damaged.length() - 1, 0))
		damaged = damaged.substr(0, character_index) + replacements.pick_random() + damaged.substr(character_index + 1)
	return damaged

func _refresh_packet_tab() -> void:
	if tab_request_label == null:
		return
	tab_request_label.text = "Requisição: " + shown_request
	tab_destination_label.text = "Destinatário: " + shown_ip
	tab_application_label.text = "Protocolo de Aplicação: " + shown_application_protocol
	tab_transport_label.text = "Protocolo de Transporte: " + shown_transport_protocol
	packet_label_value.text = "Destinatário real:\n" + real_ip

func _panel_style(background: Color, border: Color, border_width: int = 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
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
	if inspection_tab != null:
		inspection_tab.hide()
	active_defects.clear()
	_close_package_tab()
	_configure_choices(false)
	feedback_label.text = ""
	submit_button.disabled = true
	approve_button.disabled = true
	mentor_context.emit("Pacote retorna em 01:00." if is_return else "Próximo pacote chega em 02:00.")
	_refresh_ui()

func _open_inspection() -> void:
	active_defects = pending_return_defects.duplicate() if returning else round_defects[queue_index].duplicate()
	_prepare_packet_for_current_box()
	var current_box := queue_index + 1
	status_label.text = "PACOTE %d DE %d — ANALISE VISUALMENTE" % [current_box, BOX_TOTAL]
	package_label.text = "O pacote saiu da abertura. Revise os dados e marque as falhas que encontrar."
	feedback_label.text = ""
	# As opções permanecem disponíveis mesmo para pacotes corretos:
	# cabe ao jogador decidir se aprova ou se reenvia.
	_configure_choices(true)
	# A decisão é do jogador: ambas as ações ficam disponíveis, mesmo se houver falhas.
	submit_button.disabled = false
	approve_button.disabled = false
	mentor_context.emit("Pacote pronto para inspeção. Use o menu de seleção.")

func _refresh_ui() -> void:
	if timer_label == null:
		return
	var map_time := get_map_timer_text()
	map_timer.text = map_time
	timer_label.text = map_time
	if package_drawer != null:
		package_drawer.visible = package_visible
	if inspect_hint_label != null:
		inspect_hint_label.visible = phase == "inspection"
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

func _selected_defects() -> Array:
	var selected: Array = []
	for defect in DEFECT_OPTIONS:
		var toggle := defect_toggles.get(defect.to_lower()) as CheckButton
		if toggle != null and toggle.button_pressed:
			selected.append(defect)
	return selected

func _submit_defects() -> void:
	if phase != "inspection":
		return
	var reported := _selected_defects()
	if reported.is_empty():
		feedback_label.text = "Selecione ao menos uma falha para reenviar o pacote."
		return
	# Ao reenviar um pacote correto com falhas marcadas, essas falhas passam
	# a existir no retorno. Em um pacote defeituoso, marcar uma falha a corrige.
	if active_defects.is_empty():
		pending_return_defects = reported.duplicate()
	else:
		pending_return_defects = active_defects.duplicate()
		for defect in reported:
			pending_return_defects.erase(defect)
	var return_wait := RETURN_SECONDS_PER_REPORTED_DEFECT * float(reported.size())
	feedback_label.text = "Pacote reenviado. Retorno em %02d segundos." % int(return_wait)
	_start_wait(return_wait, true)

func _approve_box() -> void:
	if phase != "inspection":
		return
	# Aprovar um pacote defeituoso reinicia toda a rodada; as próximas três
	# caixas são sorteadas novamente e a primeira chega em um minuto.
	if not active_defects.is_empty():
		_restart_round()
		return
	queue_index += 1
	returning = false
	packet_generated_for = -1
	if queue_index >= BOX_TOTAL:
		_finish_shift()
	else:
		_start_wait(INITIAL_WAIT, false)

func _randomize_round_defects() -> void:
	round_defects.clear()
	for box_index in range(BOX_TOTAL):
		var available := DEFECT_OPTIONS.duplicate()
		available.shuffle()
		# Cada caixa recebe uma combinação independente de zero a quatro falhas.
		var defect_count := randi_range(0, DEFECT_OPTIONS.size())
		round_defects.append(available.slice(0, defect_count))

func _restart_round() -> void:
	queue_index = 0
	returning = false
	packet_generated_for = -1
	pending_return_defects.clear()
	_randomize_round_defects()
	_start_wait(INITIAL_WAIT, false)
	mentor_message.emit("Pacote aprovado com falhas. A rodada foi reiniciada.", 3.0)

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
