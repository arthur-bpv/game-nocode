extends Control
class_name PauseMenu

enum PendingAction { NONE, RETURN_TO_MENU, QUIT_GAME }

const MAIN_MENU_SCENE := "res://scenes/menu.tscn"

@onready var actions_panel: Control = %ActionsPanel
@onready var continue_button: Button = %ContinueButton
@onready var volume_screen: Control = %VolumeScreen
@onready var confirmation: Control = %ConfirmationModal

var _pending_action := PendingAction.NONE

func _ready() -> void:
	volume_screen.back_requested.connect(_show_actions)
	confirmation.confirmed.connect(_on_confirmation_confirmed)
	confirmation.cancelled.connect(_on_confirmation_cancelled)
	hide()

func open_pause() -> void:
	_pending_action = PendingAction.NONE
	confirmation.hide()
	_show_actions()
	show()
	_pause_world_music()
	BackgroundMusic.play_menu()
	SoundEffects.set_world_ambience_paused(true)
	get_tree().paused = true
	continue_button.grab_focus()

func resume_game() -> void:
	_pending_action = PendingAction.NONE
	confirmation.hide()
	volume_screen.hide()
	hide()
	get_tree().paused = false
	BackgroundMusic.pause_menu()
	_resume_world_music()
	SoundEffects.set_world_ambience_paused(false)

func handle_cancel() -> void:
	if confirmation.visible:
		confirmation.cancel()
	elif volume_screen.visible:
		_show_actions()
	else:
		resume_game()

func _on_continue_pressed() -> void:
	resume_game()

func _on_settings_pressed() -> void:
	actions_panel.hide()
	volume_screen.open_screen()

func _on_return_to_menu_pressed() -> void:
	_pending_action = PendingAction.RETURN_TO_MENU
	confirmation.ask("VOLTAR AO MENU", "O progresso não salvo será perdido.", "VOLTAR")

func _on_quit_pressed() -> void:
	_pending_action = PendingAction.QUIT_GAME
	confirmation.ask("SAIR DO JOGO", "Deseja fechar o NETBOT?", "SAIR")

func _show_actions() -> void:
	volume_screen.hide()
	actions_panel.show()
	if visible:
		continue_button.grab_focus()

func _on_confirmation_confirmed() -> void:
	match _pending_action:
		PendingAction.RETURN_TO_MENU:
			get_tree().paused = false
			hide()
			_pause_world_music()
			SoundEffects.set_world_ambience_enabled(false)
			SceneTransition.change_scene(MAIN_MENU_SCENE)
		PendingAction.QUIT_GAME:
			get_tree().paused = false
			SoundEffects.set_world_ambience_enabled(false)
			get_tree().quit()
	_pending_action = PendingAction.NONE

func _on_confirmation_cancelled() -> void:
	_pending_action = PendingAction.NONE
	continue_button.grab_focus()

func _pause_world_music() -> void:
	var world_music := get_tree().current_scene.get_node_or_null("WorldMusic") as AudioStreamPlayer
	if world_music != null:
		world_music.stream_paused = true

func _resume_world_music() -> void:
	var world_music := get_tree().current_scene.get_node_or_null("WorldMusic") as AudioStreamPlayer
	if world_music != null:
		world_music.stream_paused = false
