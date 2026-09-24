extends Control

const WORLD_SCENE := "res://scenes/world/world.tscn"

@onready var singleplayer_button: Button = %SingleplayerButton
@onready var confirmation: Control = %ConfirmationModal

func _ready() -> void:
	singleplayer_button.grab_focus()
	confirmation.confirmed.connect(_quit_game)

func _on_singleplayer_pressed() -> void:
	SceneTransition.change_scene(WORLD_SCENE)

func _on_quit_pressed() -> void:
	confirmation.ask("SAIR DO JOGO", "Deseja fechar o NETBOT?", "SAIR")

func _quit_game() -> void:
	get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and confirmation.visible:
		confirmation.cancel()
		get_viewport().set_input_as_handled()
