extends Control

signal completed
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
var _round_index := 0

var status_label: Label
var timer_label: Label
var package_label: Label
var inspection_tab: VBoxContainer
var tab_request_label: Label
var tab_destination_label: Label
var tab_application_label: Label
var tab_transport_label: Label
var packet_label_value: Label
var defect_menu: VBoxContainer
var submit_button: Button
var approve_button: Button
var feedback_label: Label
var package_drawer: Button
var defect_toggles: Dictionary = {}

func _ready() -> void:
	_build_inspection_screen()
	_randomize_round_defects()
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
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	add_child(content)
	content.set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	var title := Label.new()
	title.text = "Inspeção de pacotes"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color("69edf0"))
	content.add_child(title)

	var header := HBoxContainer.new()
	content.add_child(header)
	status_label = _body_label(17)
	status_label.size_flags_horizontal = SIZE_EXPAND_FILL
	header.add_child(status_label)
	timer_label = _body_label(19)
	timer_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	timer_label.add_theme_color_override("font_color", Color("69edf0"))
	header.add_child(timer_label)

	package_label = _body_label(17)
	package_label.custom_minimum_size.y = 44
	content.add_child(package_label)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	content.add_child(columns)

	var packet := VBoxContainer.new()
	packet.custom_minimum_size.x = 315
	packet.size_flags_horizontal = SIZE_EXPAND_FILL
	columns.add_child(packet)
	package_drawer = _button("Ver dados do pacote")
	package_drawer.pressed.connect(_toggle_package_tab)
	packet.add_child(package_drawer)

	inspection_tab = VBoxContainer.new()
	inspection_tab.add_theme_constant_override("separation", 6)
	packet.add_child(inspection_tab)
	tab_request_label = _body_label(16)
	tab_destination_label = _body_label(16)
	tab_application_label = _body_label(16)
	tab_transport_label = _body_label(16)
	packet_label_value = _body_label(16)
	for item in [tab_request_label, tab_destination_label, tab_application_label, tab_transport_label, packet_label_value]:
		inspection_tab.add_child(item)
	inspection_tab.hide()

	var decision := VBoxContainer.new()
	decision.custom_minimum_size.x = 315
	decision.size_flags_horizontal = SIZE_EXPAND_FILL
	decision.add_theme_constant_override("separation", 6)
	columns.add_child(decision)
	defect_menu = VBoxContainer.new()
	decision.add_child(defect_menu)
	submit_button = _button("Reenviar para correção")
	submit_button.pressed.connect(_submit_defects)
	decision.add_child(submit_button)
	approve_button = _button("Aprovar pacote")
	approve_button.pressed.connect(_approve_box)
	decision.add_child(approve_button)
	feedback_label = _body_label(16)
	feedback_label.add_theme_color_override("font_color", Color("69edf0"))
	content.add_child(feedback_label)

func _body_label(font_size: int) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", ThemeDB.fallback_font)
	label.add_theme_font_size_override("font_size", font_size)
	return label

func _button(caption: String) -> Button:
	var button := Button.new()
	button.text = caption
	button.add_theme_font_override("font", ThemeDB.fallback_font)
	button.add_theme_font_size_override("font_size", 16)
	return button

func _toggle_package_tab() -> void:
	if phase != "inspection":
		return
	if inspection_tab.visible:
		_close_package_tab()
		return
	_refresh_packet_tab()
	inspection_tab.show()
	package_drawer.text = "Ocultar dados do pacote"

func _close_package_tab() -> void:
	if inspection_tab != null:
		inspection_tab.hide()
		package_drawer.text = "Ver dados do pacote"

func _prepare_packet_for_current_box() -> void:
	if packet_generated_for == queue_index:
		_apply_packet_faults()
		return
	var all_requests: Array = []
	all_requests.append_array(TCP)
	all_requests.append_array(UDP)
	var rng := ChallengeSession.make_rng(&"inspecao_pacotes/packet", _round_index * BOX_TOTAL + queue_index)
	packet_request = ChallengeSession.choose_unused(&"inspecao_pacotes/requests", all_requests, rng)
	real_ip = "192.168.0." + str(rng.randi_range(1, 254))
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
	var rng := ChallengeSession.make_rng(&"inspecao_pacotes/faults", _round_index * BOX_TOTAL + queue_index)
	shown_request = packet_request
	shown_ip = real_ip
	shown_application_protocol = expected_application_protocol
	shown_transport_protocol = expected_transport_protocol
	if active_defects.has("Dados corrompidos/incompletos"):
		shown_request = _damage_request_text(packet_request, rng)
	if active_defects.has("Endereço IP inválido ou incorreto"):
		var invalid_octet := rng.randi_range(1, 254)
		if "192.168.0." + str(invalid_octet) == real_ip:
			invalid_octet = 1 if invalid_octet == 254 else invalid_octet + 1
		shown_ip = "192.168.0." + str(invalid_octet)
	if active_defects.has("Protocolo de aplicação incorreto"):
		shown_application_protocol = "DNS" if expected_application_protocol == "HTTP" else "HTTP"
	if active_defects.has("Caminho inacessível/congestionado"):
		shown_transport_protocol = "UDP" if expected_transport_protocol == "TCP" else "TCP"

func _damage_request_text(original: String, rng: RandomNumberGenerator) -> String:
	# Metade das vezes a perda de dados gera uma lacuna; na outra metade,
	# caracteres do conteúdo são corrompidos sem exibir um rótulo explicativo.
	if rng.randi_range(0, 1) == 0:
		var start := maxi(1, original.length() / 3)
		var amount := maxi(2, original.length() / 5)
		return original.substr(0, start) + " --- " + original.substr(start + amount)
	var damaged := original
	var replacements := ["#", "@", "%", "?", "&"]
	for index in range(2):
		var character_index := rng.randi_range(0, maxi(damaged.length() - 1, 0))
		damaged = damaged.substr(0, character_index) + replacements[rng.randi_range(0, replacements.size() - 1)] + damaged.substr(character_index + 1)
	return damaged

func _refresh_packet_tab() -> void:
	if tab_request_label == null:
		return
	tab_request_label.text = "Requisição: " + shown_request
	tab_destination_label.text = "Destinatário: " + shown_ip
	tab_application_label.text = "Protocolo de Aplicação: " + shown_application_protocol
	tab_transport_label.text = "Protocolo de Transporte: " + shown_transport_protocol
	packet_label_value.text = "Destinatário real:\n" + real_ip

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
	var countdown := get_map_timer_text()
	mentor_context.emit(("Pacote retorna em %s." if is_return else "Próximo pacote chega em %s.") % countdown)
	_refresh_ui()

func _open_inspection() -> void:
	active_defects = pending_return_defects.duplicate() if returning else round_defects[queue_index].duplicate()
	_prepare_packet_for_current_box()
	var current_box := queue_index + 1
	status_label.text = "PACOTE %d DE %d" % [current_box, BOX_TOTAL]
	package_label.text = "Abra os dados do pacote e marque as falhas que encontrar."
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
	timer_label.text = map_time
	if package_drawer != null:
		package_drawer.visible = package_visible
	submit_button.visible = phase == "inspection"
	approve_button.visible = phase == "inspection"
	if phase == "waiting":
		status_label.text = "PACOTE EM CORREÇÃO" if returning else "PRÓXIMO PACOTE EM TRIAGEM"
		package_label.text = "A esteira está livre. O contador indica quando chega o próximo pacote."
	elif phase == "arriving":
		status_label.text = "ALÇAPÃO ABERTO"
		package_label.text = "O pacote está saindo da parede."
	elif phase == "complete":
		status_label.text = "TURNO CONCLUÍDO"
		package_label.text = "As três caixas foram analisadas e liberadas."
		timer_label.text = "3/3"

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
	var heading := _body_label(16)
	heading.text = "Falhas encontradas:"
	defect_menu.add_child(heading)
	for defect in DEFECT_OPTIONS:
		var toggle := CheckButton.new()
		toggle.text = defect
		toggle.add_theme_font_override("font", ThemeDB.fallback_font)
		toggle.add_theme_font_size_override("font_size", 15)
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
	var rng := ChallengeSession.make_rng(&"inspecao_pacotes/defects", _round_index)
	round_defects.clear()

	for box_index in range(BOX_TOTAL):
		var available: Array = DEFECT_OPTIONS.duplicate()
		available = ChallengeSession.shuffled(&"inspecao_pacotes/defect_order_%s" % box_index, available, _round_index)

		# Cada caixa recebe uma combinação independente de zero a quatro falhas.
		var defect_count := rng.randi_range(0, DEFECT_OPTIONS.size())
		round_defects.append(available.slice(0, defect_count))

	_round_index += 1

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
