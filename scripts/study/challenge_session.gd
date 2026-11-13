extends Node

## Fonte única de aleatoriedade das tarefas educacionais.
## A seed é exibida e pode ser reutilizada durante testes para reproduzir
## exatamente os mesmos desafios de uma sessão.

signal session_started(seed_value: int)

var session_seed: int = 0
var _used_keys: Dictionary = {}


func _ready() -> void:
	start_new_session()


func start_new_session(seed_override: int = -1) -> int:
	if seed_override >= 0:
		session_seed = seed_override
	else:
		var seed_rng := RandomNumberGenerator.new()
		seed_rng.randomize()
		session_seed = int(seed_rng.randi())
	_used_keys.clear()
	session_started.emit(session_seed)
	return session_seed


func make_rng(scope: StringName, round_index: int = 0) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	var scope_hash := int(String(scope).hash())
	rng.seed = int(session_seed + scope_hash + round_index * 104729)
	return rng


func choose_unused(scope: StringName, values: Array, rng: RandomNumberGenerator) -> Variant:
	if values.is_empty():
		return null
	var used: Array = _used_keys.get(scope, [])
	var candidates: Array = []
	for value in values:
		if not used.has(value):
			candidates.append(value)
	if candidates.is_empty():
		used.clear()
		candidates = values.duplicate()
	var choice: Variant = candidates[rng.randi_range(0, candidates.size() - 1)]
	used.append(choice)
	_used_keys[scope] = used
	return choice


func shuffled(scope: StringName, values: Array, round_index: int = 0) -> Array:
	var result: Array = values.duplicate()
	var rng := make_rng(scope, round_index)
	for index in range(result.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var temporary: Variant = result[index]
		result[index] = result[swap_index]
		result[swap_index] = temporary
	return result


func describe_seed() -> String:
	return "Seed da sessão: %s" % session_seed
