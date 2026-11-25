extends Node

signal received(message: Dictionary)
signal disconnected

const VERSION := 1

var origin := ""
var session := ""
var _socket: WebSocketPeer
var _serial := 0
var _received_open := false
var _last_probe := 0
var _probe_id := ""
var _measure := OS.get_environment("NETBOT_LAN_MEASURE") == "1"

func request(path: String, method: int, credential := "", data := {}) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = 6.0
	http.body_size_limit = 8192
	http.max_redirects = 0
	add_child(http)
	var headers := PackedStringArray(["Accept: application/json", "Content-Type: application/json"])
	if not credential.is_empty():
		headers.append("Authorization: Bearer " + credential)
	var started := http.request(origin + path, headers, method, JSON.stringify(data) if not data.is_empty() else "")
	if started != OK:
		http.queue_free()
		return {"status": 0, "code": "unreachable"}
	var response: Array = await http.request_completed
	http.queue_free()
	if response[0] != HTTPRequest.RESULT_SUCCESS:
		return {"status": 0, "code": "certificate" if response[0] == HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR else "unreachable"}
	var parsed: Variant = JSON.parse_string(response[3].get_string_from_utf8()) if not response[3].is_empty() else null
	var result: Dictionary = parsed if parsed is Dictionary else {}
	result.status = response[1]
	return result

func open_socket(ticket: String) -> Error:
	close_socket()
	_socket = WebSocketPeer.new()
	_socket.handshake_headers = PackedStringArray(["Authorization: Bearer " + ticket])
	_socket.inbound_buffer_size = 32768
	_socket.outbound_buffer_size = 16384
	return _socket.connect_to_url("wss" + origin.substr(5) + "/v1/ws")

func close_socket() -> void:
	if _socket != null:
		_socket.close()
		_socket = null
	_received_open = false

func send_action(kind: String, data := {}) -> String:
	if _socket == null or _socket.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return ""
	var message := {"version": VERSION, "type": kind, "payload": data}
	if kind != "input":
		_serial += 1
		message.id = str(_serial)
	_socket.send_text(JSON.stringify(message))
	return message.get("id", "")

func _process(_delta: float) -> void:
	if _socket == null:
		return
	_socket.poll()
	match _socket.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			if not _received_open:
				_received_open = true
				send_action("hello")
			if _measure and Time.get_ticks_msec() - _last_probe >= 1000:
				_last_probe = Time.get_ticks_msec()
				_probe_id = send_action("ping")
			while _socket != null and _socket.get_available_packet_count() > 0:
				var parsed: Variant = JSON.parse_string(_socket.get_packet().get_string_from_utf8())
				if parsed is Dictionary:
					if _measure and parsed.get("type") == "pong" and parsed.get("id") == _probe_id:
						print("netbot_lan rtt_ms=", Time.get_ticks_msec() - _last_probe)
					received.emit(parsed)
		WebSocketPeer.STATE_CLOSED:
			_socket = null
			_received_open = false
			disconnected.emit()
