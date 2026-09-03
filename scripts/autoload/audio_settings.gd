extends Node

signal settings_changed(bus_name: StringName, volume: float, muted: bool)

const SETTINGS_PATH := "user://settings.cfg"
const BUS_NAMES: Array[StringName] = [&"Master", &"Music", &"SFX"]
const DEFAULT_VOLUMES := {&"Master": 0.8, &"Music": 0.7, &"SFX": 0.8}

var _volumes: Dictionary = {}
var _muted: Dictionary = {}

func _ready() -> void:
	_load_settings()
	_apply_all()

func get_volume(bus_name: StringName) -> float:
	return float(_volumes.get(bus_name, DEFAULT_VOLUMES.get(bus_name, 0.8)))

func is_muted(bus_name: StringName) -> bool:
	return bool(_muted.get(bus_name, false))

func set_volume(bus_name: StringName, value: float, save := true) -> void:
	if not BUS_NAMES.has(bus_name):
		push_warning("Bus de áudio desconhecido: %s" % bus_name)
		return
	_volumes[bus_name] = clampf(value, 0.0, 1.0)
	_apply_bus(bus_name)
	if save:
		_save_settings()
	settings_changed.emit(bus_name, get_volume(bus_name), is_muted(bus_name))

func set_muted(bus_name: StringName, muted: bool, save := true) -> void:
	if not BUS_NAMES.has(bus_name):
		return
	_muted[bus_name] = muted
	_apply_bus(bus_name)
	if save:
		_save_settings()
	settings_changed.emit(bus_name, get_volume(bus_name), muted)

func reset_defaults() -> void:
	for bus_name in BUS_NAMES:
		_volumes[bus_name] = DEFAULT_VOLUMES[bus_name]
		_muted[bus_name] = false
	_apply_all()
	_save_settings()

func _load_settings() -> void:
	var config := ConfigFile.new()
	var error := config.load(SETTINGS_PATH)
	for bus_name in BUS_NAMES:
		_volumes[bus_name] = DEFAULT_VOLUMES[bus_name]
		_muted[bus_name] = false
	if error != OK:
		return
	for bus_name in BUS_NAMES:
		var key := String(bus_name).to_lower()
		_volumes[bus_name] = clampf(float(config.get_value("audio", key + "_volume", DEFAULT_VOLUMES[bus_name])), 0.0, 1.0)
		_muted[bus_name] = bool(config.get_value("audio", key + "_muted", false))

func _save_settings() -> void:
	var config := ConfigFile.new()
	for bus_name in BUS_NAMES:
		var key := String(bus_name).to_lower()
		config.set_value("audio", key + "_volume", get_volume(bus_name))
		config.set_value("audio", key + "_muted", is_muted(bus_name))
	var error := config.save(SETTINGS_PATH)
	if error != OK:
		push_error("Não foi possível salvar as configurações de áudio: %s" % error)

func _apply_all() -> void:
	for bus_name in BUS_NAMES:
		_apply_bus(bus_name)

func _apply_bus(bus_name: StringName) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		push_warning("Bus de áudio ausente: %s" % bus_name)
		return
	var value := maxf(get_volume(bus_name), 0.0001)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(value))
	AudioServer.set_bus_mute(bus_index, is_muted(bus_name))
