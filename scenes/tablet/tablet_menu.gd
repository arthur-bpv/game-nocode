extends Control

@export var pregame_mode: bool = false

func _ready():
	$HomePanel/MapaButton.pressed.connect(_on_placeholder_pressed.bind($HomePanel/StatusLabel))
	$HomePanel/GearButton.pressed.connect(_on_gear_pressed)
	$HomePanel/CloseButton.pressed.connect(_close_ui)

	$SettingsPanel/CloseButton.pressed.connect(_close_ui)
	$SettingsPanel/MissoesButton.pressed.connect(_on_placeholder_pressed.bind($SettingsPanel/StatusLabel))
	$SettingsPanel/TutorialButton.pressed.connect(_on_placeholder_pressed.bind($SettingsPanel/StatusLabel))
	$SettingsPanel/MapaButton.pressed.connect(_on_placeholder_pressed.bind($SettingsPanel/StatusLabel))
	$SettingsPanel/BottomButton.pressed.connect(_on_bottom_button_pressed)

	for color_button in $SettingsPanel/ColorRow.get_children():
		color_button.pressed.connect(_on_color_selected.bind(color_button.self_modulate))

	_apply_pregame_mode()

func _apply_pregame_mode():
	$SettingsPanel/CloseButton.visible = not pregame_mode
	if pregame_mode:
		$SettingsPanel/BottomButton.text = "Iniciar"
		_show_settings_panel()
	else:
		$SettingsPanel/BottomButton.text = "Voltar"
		_show_home_panel()

func open_ui():
	if visible:
		return
	show()
	_set_player_movement(false)

func _close_ui():
	if pregame_mode:
		return
	hide()
	_set_player_movement(true)

func _set_player_movement(enabled: bool):
	for node in get_tree().get_nodes_in_group("player"):
		node.set_physics_process(enabled)

func _unhandled_input(event):
	if pregame_mode:
		return
	if event.is_action_pressed("toggle_tablet"):
		if visible:
			_close_ui()
		else:
			open_ui()
		get_viewport().set_input_as_handled()
		return
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_close_ui()
		get_viewport().set_input_as_handled()

func _show_home_panel():
	$HomePanel.show()
	$SettingsPanel.hide()

func _show_settings_panel():
	$HomePanel.hide()
	$SettingsPanel.show()

func _on_gear_pressed():
	_show_settings_panel()

func _on_bottom_button_pressed():
	if pregame_mode:
		get_tree().change_scene_to_file("res://scenes/world/world.tscn")
	else:
		_show_home_panel()

func _on_color_selected(color: Color):
	PlayerData.player_color = color
	$SettingsPanel/StatusLabel.text = "Cor selecionada!"

func _on_placeholder_pressed(status_label: Label):
	status_label.text = "Em breve!"
