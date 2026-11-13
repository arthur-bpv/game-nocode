extends RefCounted
class_name RoutingChallengeGenerator

## Gera a lógica de uma sessão de roteamento separadamente da interface.
## A mesma seed sempre produz a mesma topologia para facilitar testes.

const DOCUMENTATION_NETWORKS := ["192.0.2", "198.51.100", "203.0.113"]

func generate(seed_value: int, difficulty: String = "Médio") -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var config: Dictionary = _difficulty_config(difficulty)
	var prefixes: Array = config.get("prefixes", [24])
	var prefix: int = int(prefixes[rng.randi_range(0, prefixes.size() - 1)])
	var network_base: String = DOCUMENTATION_NETWORKS[rng.randi_range(0, DOCUMENTATION_NETWORKS.size() - 1)]
	# O último octeto precisa pertencer à sub-rede exibida. Para /26, por
	# exemplo, 110 ficaria fora de x.x.x.0/26 e tornaria a consulta enganosa.
	var last_host: int = maxi(2, (1 << (32 - prefix)) - 2)
	var host: int = rng.randi_range(2, last_host)
	var destination_network: String = "%s.0/%d" % [network_base, prefix]
	var destination_ip: String = "%s.%d" % [network_base, host]

	var router_count: int = rng.randi_range(int(config.get("min_routers", 3)), int(config.get("max_routers", 4)))
	var route_router_count: int = mini(rng.randi_range(int(config.get("min_hops", 1)), int(config.get("max_hops", 2))), router_count)
	var router_ids: Array[String] = []
	for index in router_count:
		router_ids.append("R%d" % (index + 1))
	_shuffle(router_ids, rng)
	var route: Array[String] = ["ORIGEM"]
	for index in route_router_count:
		route.append(router_ids[index])
	route.append("DESTINO")

	var nodes: Array[Dictionary] = []
	for index in route.size():
		var x: float = 42.0 + 326.0 * float(index) / float(maxi(1, route.size() - 1))
		var y: float = 126.0 + rng.randf_range(-18.0, 18.0)
		nodes.append({"id": route[index], "label": route[index], "position": Vector2(x, y), "available": true})
	var unused_ids: Array[String] = []
	for router in router_ids:
		if not route.has(router):
			unused_ids.append(router)
	for index in unused_ids.size():
		var x: float = rng.randf_range(96.0, 300.0)
		var y: float = 48.0 if index % 2 == 0 else 208.0
		var unavailable: bool = index == 0 and int(config.get("unavailable_routers", 0)) > 0
		nodes.append({"id": unused_ids[index], "label": unused_ids[index], "position": Vector2(x, y), "available": not unavailable})

	var links: Array[Dictionary] = []
	for index in route.size() - 1:
		links.append({"from": route[index], "to": route[index + 1], "available": true})
	for index in unused_ids.size():
		var attached_to: String = route[rng.randi_range(0, route.size() - 2)]
		var available: bool = _node_is_available(nodes, unused_ids[index])
		links.append({"from": attached_to, "to": unused_ids[index], "available": available})
		if int(config.get("unavailable_links", 0)) > 0 and index < int(config.get("unavailable_links", 0)):
			var second_to: String = route[rng.randi_range(1, route.size() - 1)]
			if second_to != attached_to:
				links.append({"from": unused_ids[index], "to": second_to, "available": false})

	var table_rows: Array[Dictionary] = []
	for index in route.size() - 1:
		table_rows.append({
			"router": route[index],
			"network": destination_network,
			"next_hop": route[index + 1],
		})

	return {
		"seed": seed_value,
		"difficulty": difficulty,
		"destination_ip": destination_ip,
		"destination_network": destination_network,
		"nodes": nodes,
		"links": links,
		"route": route,
		"table_rows": table_rows,
	}

func _difficulty_config(difficulty: String) -> Dictionary:
	match difficulty:
		"Fácil":
			return {"min_routers": 3, "max_routers": 4, "min_hops": 1, "max_hops": 2, "unavailable_routers": 0, "unavailable_links": 0, "prefixes": [24]}
		"Difícil":
			return {"min_routers": 6, "max_routers": 8, "min_hops": 3, "max_hops": 5, "unavailable_routers": 1, "unavailable_links": 2, "prefixes": [24, 25, 26]}
		_:
			return {"min_routers": 4, "max_routers": 6, "min_hops": 2, "max_hops": 3, "unavailable_routers": 1, "unavailable_links": 1, "prefixes": [24, 25]}

func _node_is_available(nodes: Array[Dictionary], node_id: String) -> bool:
	for node in nodes:
		if String(node.get("id", "")) == node_id:
			return bool(node.get("available", false))
	return false

func _shuffle(items: Array[String], rng: RandomNumberGenerator) -> void:
	for index in range(items.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, index)
		var previous: String = items[index]
		items[index] = items[swap_index]
		items[swap_index] = previous
