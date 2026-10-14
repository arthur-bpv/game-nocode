extends Node

const MENU_MUSIC := preload("res://assets/audio/Menu.mp3")

var _player: AudioStreamPlayer
var _menu_playing := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.name = "MenuMusicPlayer"
	_player.bus = &"Music"
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_player)

func play_menu() -> void:
	if _menu_playing and _player.playing:
		_player.stream_paused = false
		return
	var music_stream := MENU_MUSIC.duplicate() as AudioStreamMP3
	music_stream.loop = true
	_player.stream = music_stream
	_player.play()
	_menu_playing = true

func stop_menu() -> void:
	_player.stop()
	_menu_playing = false

func pause_menu() -> void:
	if _menu_playing and _player.playing:
		_player.stream_paused = true
