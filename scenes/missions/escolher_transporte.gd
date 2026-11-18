extends "res://scenes/missions/network_repair_panel.gd"

const TRANSMISSIONS := [
	["Enviar um arquivo de atualização. Todos os dados precisam chegar completos e na ordem.", 0,
		"Essa transferência precisa de entrega confiável e ordenada."],
	["Transmitir voz ao vivo. Priorize baixa latência; pequenas perdas são aceitáveis.", 1,
		"Nesta transmissão, esperar pela retransmissão pode prejudicar a conversa."],
	["Enviar comandos de configuração. A entrega deve ser confiável e manter a ordem.", 0,
		"Os comandos precisam chegar de forma confiável e ordenada."],
	["Enviar posições de jogadores continuamente. Uma atualização nova pode substituir uma antiga perdida.", 1,
		"Aqui, a atualização mais recente é mais útil do que recuperar uma antiga."],
]
const ROUND_TOTAL := 3

var round_index := 0
var options: Array[Button] = []
var confirm: Button
var _progress: Label
var _request: Label
var _selected := -1
var _sending := false

func _ready() -> void:
	setup("Restaurar transporte", "Escolha o protocolo conforme a prioridade de cada solicitação.")
	_progress = make_label("", 17)
	_progress.add_theme_color_override("font_color", ACCENT)
	interaction.add_child(_progress)

	var card := PanelContainer.new()
	card.custom_minimum_size.y = 80
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color("101e2b")
	card_style.border_color = Color("345461")
	card_style.set_border_width_all(1)
	card_style.set_corner_radius_all(4)
	card.add_theme_stylebox_override("panel", card_style)
	interaction.add_child(card)
	var padding := MarginContainer.new()
	padding.add_theme_constant_override("margin_left", 14)
	padding.add_theme_constant_override("margin_right", 14)
	card.add_child(padding)
	_request = make_label("")
	padding.add_child(_request)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	interaction.add_child(actions)
	for caption in ["TCP", "UDP"]:
		var option := make_button(caption)
		option.toggle_mode = true
		option.size_flags_horizontal = SIZE_EXPAND_FILL
		option.pressed.connect(_select.bind(options.size()))
		options.append(option)
		actions.add_child(option)
	confirm = make_button("Confirmar")
	confirm.pressed.connect(_confirm_selection)
	actions.add_child(confirm)

	_refresh()

func _select(index: int) -> void:
	if _sending or finished:
		return
	_selected = index
	_refresh()

func _confirm_selection() -> void:
	if confirm.disabled:
		return
	var transmission: Array = TRANSMISSIONS[round_index]
	if _selected != transmission[1]:
		SoundEffects.play_error()
		show_feedback("Erro — " + transmission[2], false)
		return
	SoundEffects.play_correct()
	show_feedback("Acerto — transmissão liberada.", true)
	_sending = true
	_refresh()
	create_tween().tween_callback(_advance).set_delay(0.5)

func _advance() -> void:
	if finished:
		return
	round_index += 1
	_sending = false
	_selected = -1
	if round_index == ROUND_TOTAL:
		show_feedback("Concluída — três transmissões liberadas.", true)
		finish()
	_refresh()

func _refresh() -> void:
	_progress.text = "Transmissão %d de %d" % [mini(round_index + 1, ROUND_TOTAL), ROUND_TOTAL]
	_request.text = "Módulo de transporte restaurado." if finished else TRANSMISSIONS[round_index][0]
	confirm.disabled = _selected < 0 or _sending or finished
	for index in options.size():
		options[index].set_pressed_no_signal(index == _selected)
		options[index].disabled = _sending or finished

func restore_completed() -> void:
	if finished:
		return
	finished = true
	round_index = ROUND_TOTAL
	show_feedback("Concluída — três transmissões liberadas.", true)
	_refresh()
