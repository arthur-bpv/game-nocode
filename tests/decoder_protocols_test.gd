extends SceneTree

const EXPECTED := {
	"FIBRA ÓPTICA": "Fisica",
	"USB": "Fisica",
	"ETHERNET": "Enlace",
	"PPP": "Enlace",
	"IPV4": "Rede",
	"IPV6": "Rede",
	"TCP": "Transporte",
	"UDP": "Transporte",
	"RPC": "Sessao",
	"NETBIOS": "Sessao",
	"SSL": "Apresentacao",
	"TLS": "Apresentacao",
	"HTTPS": "Aplicacao",
	"DHCP": "Aplicacao",
}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var mission := (load("res://scenes/missions/sinais_osi.tscn") as PackedScene).instantiate() as Control
	root.add_child(mission)
	await process_frame
	assert(mission.PROMPTS.size() == EXPECTED.size())
	assert(mission.prompt_order.size() == mission.ROUND_LENGTH)
	var round: Array = mission.prompt_order.duplicate()
	var round_layers := {}
	for item in round:
		round_layers[item["answer"]] = true
	assert(round_layers.size() == 7)
	assert(mission.monitor.size == Vector2(180, 155))
	var font: Font = mission.prompt_label.get_theme_font("font")
	assert(font.resource_path == mission.PROJECT_FONT_PATH)
	assert(font.has_char(0x00D3)) # Ó em FIBRA ÓPTICA
	for button_data in mission.buttons.values():
		var button := button_data["normal"] as TextureRect
		assert(not Rect2(mission.monitor.position, mission.monitor.size).intersects(Rect2(button.position, button.size)))
	var seen := {}
	for item in mission.PROMPTS:
		var protocol := String(item["text"])
		assert(protocol == protocol.to_upper() and EXPECTED.has(protocol))
		assert(item["answer"] == EXPECTED[protocol])
		assert(not seen.has(protocol))
		seen[protocol] = true
		mission.prompt_order = [item]
		mission.prompt_index = 0
		mission._show_prompt()
		await process_frame
		assert(mission.prompt_label.text == protocol)
		assert(mission.prompt_label.get_visible_line_count() == mission.prompt_label.get_line_count())
		assert(mission.prompt_subtitle.visible == (protocol == "PPP"))
		if protocol == "PPP":
			assert(mission.prompt_subtitle.text == "POINT-TO-POINT")
	assert(seen.size() == EXPECTED.size())
	mission.prompt_order = round
	mission.prompt_index = 0
	mission._show_prompt()
	assert(mission.protocol_header.text == "PROTOCOLOS 1/7")
	var completions := []
	mission.completed.connect(func(): completions.append(true))
	for index in range(round.size()):
		mission._press(String(round[index]["answer"]))
		await create_timer(0.65).timeout
		assert(mission.prompt_index == index + 1)
		assert(mission.solved == (index == round.size() - 1))
	assert(completions.size() == 1)
	assert(mission.protocol_header.text == "PROTOCOLOS 7/7")
	mission.queue_free()
	await process_frame
	print("Decoder protocol checks passed: 14-item pool, seven-layer round, completion, font and layout.")
	quit()
