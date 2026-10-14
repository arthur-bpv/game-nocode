extends Node

# Centraliza os efeitos para que eles continuem ativos ao trocar de cena.
const ACERTO := preload("res://assets/audio/efeitos sonoros/Acerto.mp3")
const CLICK := preload("res://assets/audio/efeitos sonoros/Click.mp3")
const ERRO := preload("res://assets/audio/efeitos sonoros/Erro.mp3")
# O arquivo de áudio recebido possui este nome (com "z"), por isso o caminho
# mantém a grafia real do asset.
const FINALIZAR_TASK := preload("res://assets/audio/efeitos sonoros/Finzalizartask.mp3")
const FOGO := preload("res://assets/audio/efeitos sonoros/Fogo.mp3")
const GLITCH := preload("res://assets/audio/efeitos sonoros/Glitch.mp3")
const ROBO_VOA := preload("res://assets/audio/efeitos sonoros/Robovoa.mp3")
const TABLET := preload("res://assets/audio/efeitos sonoros/Tablet.mp3")
const WORLD_AMBIENCE_VOLUME_DB := -18.0

var _fire_loop: AudioStreamPlayer
var _robot_loop: AudioStreamPlayer
var _glitch_timer: Timer
var _tablet_open := false
var _world_ambience_enabled := false
var _click_callback := Callable(self, "play_click")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fire_loop = _create_loop(FOGO)
	_robot_loop = _create_loop(ROBO_VOA)
	_glitch_timer = Timer.new()
	_glitch_timer.one_shot = true
	_glitch_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_glitch_timer.timeout.connect(_on_glitch_timeout)
	add_child(_glitch_timer)
	get_tree().node_added.connect(_on_node_added)
	call_deferred("_connect_existing_buttons")


func _create_loop(source: AudioStream) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	var stream := source.duplicate() as AudioStream
	if stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	player.stream = stream
	player.bus = &"SFX"
	player.volume_db = WORLD_AMBIENCE_VOLUME_DB
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)
	return player


func _play(source: AudioStream) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = source
	player.bus = &"SFX"
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func play_correct() -> void:
	_play(ACERTO)


func play_error() -> void:
	_play(ERRO)


func play_task_complete() -> void:
	_play(FINALIZAR_TASK)


func play_click() -> void:
	_play(CLICK)


func play_tablet() -> void:
	_play(TABLET)


func set_world_ambience_enabled(enabled: bool) -> void:
	_world_ambience_enabled = enabled
	if not enabled:
		_fire_loop.stop()
		_robot_loop.stop()
		return
	set_world_ambience_paused(get_tree().paused)


func set_world_ambience_paused(is_paused: bool) -> void:
	if not _world_ambience_enabled:
		return
	_set_loop_paused(_fire_loop, is_paused)
	_set_loop_paused(_robot_loop, is_paused)


func _set_loop_paused(player: AudioStreamPlayer, is_paused: bool) -> void:
	player.stream_paused = is_paused
	if not is_paused and not player.playing:
		player.play()


func set_tablet_open(is_open: bool) -> void:
	_tablet_open = is_open
	if _tablet_open:
		_schedule_glitch()
	else:
		_glitch_timer.stop()


func _schedule_glitch() -> void:
	if _tablet_open:
		_glitch_timer.start(randf_range(4.0, 11.0))


func _on_glitch_timeout() -> void:
	if not _tablet_open:
		return
	_play(GLITCH)
	_schedule_glitch()


func _on_node_added(node: Node) -> void:
	_register_button(node)


func _connect_existing_buttons() -> void:
	_register_buttons_recursive(get_tree().root)


func _register_buttons_recursive(node: Node) -> void:
	_register_button(node)
	for child in node.get_children():
		_register_buttons_recursive(child)


func _register_button(node: Node) -> void:
	var button := node as BaseButton
	if button != null and not button.pressed.is_connected(_click_callback):
		button.pressed.connect(_click_callback)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"interact") and not event.is_echo():
		play_click()
