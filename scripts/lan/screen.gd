extends VBoxContainer

signal back_requested

const CLIENT := preload("res://scripts/lan/client.gd")
const MAP_VIEW := preload("res://scripts/lan/map_view.gd")
const MAP_FILE := "res://data/lan/inspection.json"
const ERRORS := {
	"unreachable": "Servidor inacessível. Confira o endereço e a rede.",
	"certificate": "Falha ao validar o certificado HTTPS do servidor.",
	"incompatible_version": "Servidor e jogo usam versões incompatíveis.",
	"incompatible_map": "O mapa do servidor é incompatível.",
	"unavailable": "Serviço temporariamente indisponível. Tente novamente.",
	"invalid_message": "Ação inválida. Confira os dados.",
	"login_denied": "Login recusado. Você pode tentar novamente.",
	"attempt_expired": "O login expirou. Tente novamente.",
	"session_expired": "Sessão encerrada. Entre novamente.",
	"nickname_required": "Informe um apelido.",
	"invalid_nickname": "Use um apelido de 1 a 24 caracteres.",
	"invalid_room_name": "Informe um nome para a sala.",
	"invalid_code": "Informe o código de seis caracteres.",
	"room_missing": "Sala inexistente ou expirada.",
	"room_expired": "O convite expirou.",
	"room_closed": "A sala foi fechada pelo anfitrião ou perdeu a conexão durante o início.",
	"room_full": "A sala já está cheia.",
	"match_started": "A sala já iniciou uma partida.",
	"not_ready": "O anfitrião pode iniciar quando os dois estiverem prontos.",
	"already_in_room": "Sua conta já ocupa um lugar em outra sala.",
	"account_connected": "Sua conta ainda está conectada. Aguarde alguns segundos.",
	"match_unavailable": "Não foi possível recuperar o resultado da partida.",
	"terminal_unavailable": "Aproxime-se do terminal com a atividade em andamento.",
	"invalid_action": "Esta ação não está disponível nesta etapa ou para seu papel.",
	"wrong_answer": "O diagnóstico não corresponde à leitura. Confira com seu colega.",
	"rate_limit": "Muitas tentativas. Aguarde e tente novamente.",
}

var _net: Node
var _body: VBoxContainer
var _status: Label
var _generation := 0
var _attempt := {}
var _account := {}
var _layout := {}
var _room := {}
var _match := ""
var _role := 0
var _remote_position := Vector2.INF
var _measure := OS.get_environment("NETBOT_LAN_MEASURE") == "1"
var _map: Control
var _seq := 0
var _elapsed := 0.0
var _phase := ""
var _reconnect_deadline := 0
var _connect_deadline := 0
var _retry_at := 0
var _ready_button: Button
var _start_button: Button
var _roster: Label
var _task_label: Label

func _ready() -> void:
	add_theme_constant_override("separation", 10)
	_net = CLIENT.new()
	add_child(_net)
	_net.received.connect(_on_message)
	_net.disconnected.connect(_on_disconnect)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 8)
	add_child(_body)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)
	var config := ConfigFile.new()
	if config.load("user://netbot_lan.cfg") == OK:
		_net.origin = config.get_value("lan", "server", "")
	if _net.origin.is_empty():
		_net.origin = OS.get_environment("NETBOT_LAN_URL")
	_login_form()

func _change(phase: String, status := "") -> void:
	_phase = phase
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	_map = null
	_status.text = status

func _label(value: String) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_child(label)
	return label

func _field(hint: String, length: int, value := "") -> LineEdit:
	var field := LineEdit.new()
	field.placeholder_text = hint
	field.tooltip_text = hint
	field.text = value
	field.max_length = length
	_body.add_child(field)
	return field

func _button(title: String, pressed: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.pressed.connect(pressed)
	_body.add_child(button)
	return button

func _error(code: String) -> String:
	return ERRORS.get(code, "Não foi possível concluir a ação.")

func _login_form(status := "") -> void:
	_change("login", status)
	var address := _field("https://servidor.do.laboratorio", 255, _net.origin)
	_button("ENTRAR COM SUAP IFRN", func(): _login(address.text))
	_button("VOLTAR", go_back)
	address.grab_focus()

func _login(value: String) -> void:
	var pattern := RegEx.create_from_string("^https://([a-zA-Z0-9.-]+|\\[[a-fA-F0-9:]+\\])(:[0-9]{1,5})?/?$")
	value = value.strip_edges().trim_suffix("/")
	if pattern.search(value) == null:
		_status.text = "Informe o endereço HTTPS do laboratório."
		return
	_generation += 1
	var generation := _generation
	_net.origin = value
	_change("waiting", "Conectando ao servidor…")
	_button("CANCELAR", _cancel_login)
	var health: Dictionary = await _net.request("/healthz", HTTPClient.METHOD_GET)
	if generation != _generation:
		return
	if health.status != 200 or health.get("version") != _net.VERSION:
		_login_form(_error(health.get("code", "incompatible_version")))
		return
	var attempt: Dictionary = await _net.request("/v1/auth/attempts", HTTPClient.METHOD_POST)
	if generation != _generation:
		if attempt.status == 201:
			_net.request("/v1/auth/attempts/" + str(attempt.id), HTTPClient.METHOD_DELETE, attempt.redeem_token)
		return
	if attempt.status != 201:
		_login_form(_error(attempt.get("code", "unavailable")))
		return
	_attempt = attempt
	var config := ConfigFile.new()
	config.set_value("lan", "server", _net.origin)
	config.save("user://netbot_lan.cfg")
	if not str(attempt.browser_url).begins_with(_net.origin + "/v1/auth/browser?") or OS.shell_open(attempt.browser_url) != OK:
		_cancel_login()
		_status.text = "Não foi possível abrir o navegador."
		return
	_status.text = "Conclua o login SUAP no navegador e volte ao NETBOT."
	var deadline := Time.get_ticks_msec() + int(attempt.expires_in) * 1000
	while generation == _generation and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(2).timeout
		if generation != _generation:
			return
		var result: Dictionary = await _net.request("/v1/auth/attempts/" + str(attempt.id) + "/redeem", HTTPClient.METHOD_POST, attempt.redeem_token)
		if generation != _generation:
			return
		if result.status == 202:
			continue
		_attempt.clear()
		if result.status != 200:
			_login_form(_error(result.get("code", "unavailable")))
			return
		_net.session = result.token
		_account = result.account
		if str(_account.nickname).is_empty():
			_nickname()
		else:
			_open_connection()
		return
	_attempt.clear()
	_login_form(_error("attempt_expired"))

func _cancel_login() -> void:
	_generation += 1
	if not _attempt.is_empty():
		_net.request("/v1/auth/attempts/" + str(_attempt.id), HTTPClient.METHOD_DELETE, _attempt.redeem_token)
		_attempt.clear()
	_login_form("Login cancelado.")

func _nickname(status := "") -> void:
	_change("nickname", status)
	var field := _field("Apelido no NETBOT", 24, str(_account.nickname))
	_button("SALVAR APELIDO", func(): _save_nickname(field.text))
	_button("ENCERRAR SESSÃO", _logout)
	field.grab_focus()

func _save_nickname(value: String) -> void:
	_change("busy", "Salvando apelido…")
	var result: Dictionary = await _net.request("/v1/profile", HTTPClient.METHOD_PUT, _net.session, {"nickname": value})
	if result.status == 200:
		_account = result
		_open_connection()
	elif result.status == 401:
		_session_expired()
	else:
		_nickname(_error(result.get("code", "unavailable")))

func _open_connection() -> void:
	_change("connecting", "Conectando à partida…" if not _match.is_empty() else "Conectando ao lobby…")
	_retry_at = 0
	_connect_deadline = 0
	var generation := _generation
	var result: Dictionary = await _net.request("/v1/tickets", HTTPClient.METHOD_POST, _net.session)
	if generation != _generation:
		return
	if result.status == 401:
		_session_expired()
		return
	if result.status != 201 or _net.open_socket(result.get("ticket", "")) != OK:
		_schedule_retry(result.get("code", "unreachable"))
		return
	_connect_deadline = Time.get_ticks_msec() + 7000

func _schedule_retry(code: String) -> void:
	_connect_deadline = 0
	if not _match.is_empty() and Time.get_ticks_msec() < _reconnect_deadline:
		_change("retry", "Conexão perdida. Tentando recuperar seu lugar…")
		_retry_at = Time.get_ticks_msec() + 2500
		return
	_change("offline", _error(code))
	_button("RECONECTAR", _open_connection)
	_button("ENCERRAR SESSÃO", _logout)

func _on_disconnect() -> void:
	if _phase in ["login", "waiting", "busy", "result", "offline", "retry", "nickname"]:
		return
	if _phase != "connecting" and not _match.is_empty():
		_reconnect_deadline = Time.get_ticks_msec() + 36000
	_room.clear()
	_schedule_retry("unreachable")

func _session_expired() -> void:
	_net.close_socket()
	_net.session = ""
	_room.clear()
	_login_form(_error("session_expired"))

func _logout() -> void:
	_generation += 1
	_change("busy", "Encerrando sessão…")
	var response: Dictionary = await _net.request("/v1/session", HTTPClient.METHOD_DELETE, _net.session)
	if response.status != 204 and response.status != 401:
		_change("offline", _error(response.get("code", "unavailable")))
		_button("TENTAR ENCERRAR SESSÃO", _logout)
		_button("VOLTAR SEM CONFIRMAR ENCERRAMENTO", _exit_to_menu)
		return
	_exit_to_menu()

func _exit_to_menu() -> void:
	_net.close_socket()
	_net.session = ""
	_match = ""
	_room.clear()
	back_requested.emit()

func _rooms(status := "") -> void:
	_room.clear()
	_change("rooms", status)
	_label("Jogador: " + str(_account.nickname))
	var name := _field("Nome da sala", 32)
	_button("CRIAR SALA", func(): _net.send_action("create_room", {"name": name.text.strip_edges()}))
	var code := _field("Código de seis caracteres", 6)
	_button("ENTRAR COM CÓDIGO", func(): _net.send_action("join_room", {"code": code.text.strip_edges().to_upper()}))
	_button("ALTERAR APELIDO", func(): _net.close_socket(); _nickname())
	_button("ENCERRAR SESSÃO E VOLTAR", _logout)

func _lobby() -> void:
	_change("lobby")
	_label("%s  ·  Código %s" % [_room.name, _room.code])
	_roster = _label("")
	_ready_button = _button("MARCAR PRONTO", func():
		for entry in _room.players:
			if entry.id == _account.id:
				_net.send_action("set_ready", {"ready": not entry.ready})
	)
	_start_button = _button("INICIAR PARTIDA", func(): _net.send_action("start_match"))
	_button("SAIR DA SALA", func(): _net.send_action("leave"))
	_update_lobby()

func _update_lobby() -> void:
	var roster := PackedStringArray()
	var host := false
	var all_ready: bool = _room.players.size() == 2 and _room.state == "lobby"
	for entry in _room.players:
		roster.append("%s · %s" % [entry.nickname, "pronto" if entry.ready else "aguardando"])
		all_ready = all_ready and entry.ready and entry.connected
		if entry.id == _account.id:
			host = int(entry.role) == 0
			_ready_button.text = "DESMARCAR PRONTO" if entry.ready else "MARCAR PRONTO"
	_roster.text = "\n".join(roster)
	_ready_button.disabled = _room.state != "lobby"
	_start_button.visible = host
	_start_button.disabled = not all_ready

func _start_map(data: Dictionary) -> void:
	_match = data.id
	_role = int(data.role)
	_seq = int(data.get("seq", 0))
	_remote_position = Vector2.INF
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MAP_FILE))
	_layout = parsed if parsed is Dictionary else {}
	if _layout.get("version", "") != data.map:
		_change("game", _error("incompatible_map"))
		_button("SAIR DA SALA", func(): _net.send_action("leave"))
		return
	_change("game", "Aguardando carregamento dos dois jogadores…")
	_map = MAP_VIEW.new()
	_map.layout = _layout
	_map.role = _role
	_map.custom_minimum_size = Vector2(510, 295)
	_body.add_child(_map)
	_task_label = _label("Mova-se com WASD ou com as setas até o terminal.")
	if _role == 0:
		_button("LER TERMINAL", func(): _net.send_action("interact"))
	else:
		var choices := OptionButton.new()
		choices.add_item("Cabo com falha de continuidade")
		choices.add_item("Porta do switch desligada")
		choices.add_item("Endereço IP duplicado")
		_body.add_child(choices)
		_button("REGISTRAR DIAGNÓSTICO", func():
			_net.send_action("submit_answer", {"answer": ["cabo", "porta", "ip"][choices.selected]})
		)
	_button("ABANDONAR PARTIDA", func(): _net.send_action("leave"))
	if not data.get("resume", false):
		_net.send_action("map_loaded", {"map": _layout.version})

func _result(data: Dictionary) -> void:
	var outcomes := {"completed": "Inspeção concluída em cooperação.", "abandoned": "Partida abandonada.", "interrupted": "Partida interrompida pelo reinício do servidor."}
	_change("result")
	_label(outcomes.get(data.outcome, "Partida encerrada."))
	if not data.persisted:
		_label("O servidor não conseguiu gravar o resultado.")
	_button("ENCERRAR SESSÃO E VOLTAR AO MENU", _logout)

func _on_message(message: Dictionary) -> void:
	var data: Dictionary = message.get("payload", {})
	match message.get("type"):
		"welcome":
			_connect_deadline = 0
			_account = data
			if _match.is_empty():
				_rooms()
			else:
				_net.send_action("resume_match", {"match_id": _match})
				_connect_deadline = Time.get_ticks_msec() + 7000
		"room_state":
			_room = data
			if _phase == "lobby":
				_update_lobby()
			elif _phase == "rooms":
				_lobby()
			elif _phase == "game":
				_status.text = "Gravando resultado…" if data.state == "saving" else ""
				for entry in data.players:
					if not entry.connected and data.state == "playing":
						_status.text = "Partida pausada. Aguardando reconexão."
		"match_started":
			_connect_deadline = 0
			_start_map(data)
		"snapshot":
			if is_instance_valid(_map):
				_map.ingest(data.positions)
				if _measure:
					for entry in data.positions:
						if int(entry.role) != _role:
							var point := Vector2(entry.x, entry.y)
							if _remote_position != Vector2.INF and point != _remote_position:
								print("netbot_lan remote match=", _match, " role=", int(entry.role), " seq=", int(entry.ack), " at_ms=", _wall_ms())
							_remote_position = point
		"task_state":
			if _phase == "game" and is_instance_valid(_map):
				if _role == 0:
					_task_label.text = data.get("reading", "Leia o terminal e compartilhe a leitura com seu colega.")
				else:
					_task_label.text = "Registre o diagnóstico usando a leitura do colega." if data.stage == 1 else "Aguarde a leitura do terminal pelo colega."
		"peer_disconnected":
			_status.text = "Partida pausada. Aguardando reconexão."
		"match_finished":
			_connect_deadline = 0
			_result(data)
		"left":
			if _match.is_empty():
				_rooms()
		"error":
			var code: String = data.get("code", "")
			if code in ["room_closed", "room_expired"]:
				_rooms(_error(code))
			elif _phase == "connecting":
				_net.close_socket()
				if code in ["account_connected", "unavailable"]:
					_schedule_retry(code)
				else:
					_connect_deadline = 0
					_change("offline", _error(code))
					_button("ENCERRAR SESSÃO", _logout)
			else:
				_status.text = _error(code)

func _process(delta: float) -> void:
	var now := Time.get_ticks_msec()
	if _retry_at > 0 and now >= _retry_at:
		_open_connection()
	if _connect_deadline > 0 and now >= _connect_deadline:
		_net.close_socket()
		_schedule_retry("unreachable")
	if _phase != "game" or not is_instance_valid(_map):
		return
	_elapsed += delta
	if _elapsed < 0.05:
		return
	_elapsed = 0.0
	_seq += 1
	var motion := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if _measure:
		print("netbot_lan input match=", _match, " role=", _role, " seq=", _seq, " at_ms=", _wall_ms())
	_net.send_action("input", {"seq": _seq, "x": motion.x, "y": motion.y})

func _wall_ms() -> int:
	return int(Time.get_unix_time_from_system() * 1000)

func go_back() -> void:
	match _phase:
		"login":
			back_requested.emit()
		"waiting":
			_cancel_login()
		"lobby":
			_net.send_action("leave")
		"game", "busy":
			pass
		_:
			if not _net.session.is_empty():
				_logout()
