extends Node

## PvpNetwork autoload: real-time PvP transport plus the authoritative match
## server. The same node path ("/root/PvpNetwork") must exist on the client
## and the dedicated server so high-level RPCs resolve on both ends.
##
## Server mode is enabled with PVP_SERVER=1 in the environment or the
## --pvp-server user argument. The server binds a WebSocketMultiplayerPeer on
## $PORT (or GameBalance.PVP_SERVER_PORT), owns every match state machine, and
## never trusts client timing: rounds resolve on the server clock only.
##
## Client mode is a small state machine (PvpProtocol.STATE_*) driving the PvP
## lobby and battle scenes through the signals below. Disconnects during a
## match start a token-based auto-rejoin window.

signal pvp_state_changed(state: String)
signal pvp_error(code: String)
signal room_created(code: String)
signal match_found(payload: Dictionary)
signal countdown_tick(value: int)
signal question_received(index: int, text: String, seconds: int)
signal round_resolved(payload: Dictionary)
signal match_ended(payload: Dictionary)
signal opponent_reconnecting(seconds_left: int)
signal opponent_resumed()
signal connection_lost()

const PvpProtocol: GDScript = preload("res://scripts/pvp/pvp_protocol.gd")
const SERVER_CONFIG_PATH: String = "res://data/server_config.json"
const COUNTDOWN_START: int = 3
const COUNTDOWN_TICK_MS: int = 800
const CONNECT_TIMEOUT_MS: int = 10000
const RECONNECT_RETRY_MS: int = 1500
const REJOIN_GRACE_MS: int = 3000
const ROOM_CODE_ALPHABET: String = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const ROOM_CODE_LENGTH: int = 4
const NAME_MAX_LENGTH: int = 16

var is_server_mode: bool = false
# Guards the environment autodetection so tests can force server mode on
# secondary instances before _ready runs.
var _server_mode_resolved: bool = false
var server_port: int = GameBalance.PVP_SERVER_PORT
# Tests shrink this to keep the forfeit window fast.
var server_reconnect_seconds: float = GameBalance.PVP_RECONNECT_SECONDS

# --- client state ---
var client_state: String = PvpProtocol.STATE_OFFLINE
var client_url: String = ""
var match_token: String = ""
var match_payload: Dictionary = {}
var in_match: bool = false
var answered_current: bool = false
var current_question_index: int = -1
var auto_rejoin_active: bool = false
var reconnect_deadline_ms: int = 0
var reconnect_next_try_ms: int = 0
var connect_deadline_ms: int = 0
var _client_socket: WebSocketMultiplayerPeer = null
# Last-message mirrors: useful for UI echoes and for tests to poll instead of
# juggling signal closures.
var last_round_payload: Dictionary = {}
var last_round_index: int = -1
var last_end_payload: Dictionary = {}
var last_error: String = ""
var last_room_code: String = ""
var opponent_offline_seen: bool = false

# --- server state ---
var srv_queue: Array = []
var srv_rooms: Dictionary = {}
var srv_matches: Dictionary = {}
var srv_peer_match: Dictionary = {}
var srv_meta: Dictionary = {}
var srv_next_match_id: int = 1
var srv_rng: RandomNumberGenerator = RandomNumberGenerator.new()

func enable_server_mode() -> void:
	is_server_mode = true
	_server_mode_resolved = true

func _ready() -> void:
	srv_rng.randomize()
	if not _server_mode_resolved:
		var arguments: PackedStringArray = OS.get_cmdline_user_args()
		is_server_mode = OS.get_environment("PVP_SERVER") == "1" or arguments.has("--pvp-server")
		_server_mode_resolved = true
	if is_server_mode:
		_server_start()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func _process(_delta: float) -> void:
	if is_server_mode:
		_server_tick()
		return
	if auto_rejoin_active:
		_client_reconnect_tick()
	elif client_state == PvpProtocol.STATE_CONNECTING and Time.get_ticks_msec() >= connect_deadline_ms:
		_fail_connect_timeout()

# ------------------------------------------------------------------
# Client public API
# ------------------------------------------------------------------

func connect_to_server(url: String = "") -> bool:
	if is_server_mode:
		return false
	if client_state == PvpProtocol.STATE_CONNECTING:
		return false
	var target: String = _normalize_url(url)
	if target.is_empty():
		target = configured_server_url()
	if target.is_empty():
		pvp_error.emit(PvpProtocol.ERR_SERVER_UNREACHABLE)
		return false
	_close_socket()
	var socket: WebSocketMultiplayerPeer = WebSocketMultiplayerPeer.new()
	var tls_options: TLSOptions = TLSOptions.client() if target.begins_with("wss://") else null
	if socket.create_client(target, tls_options) != OK:
		pvp_error.emit(PvpProtocol.ERR_SERVER_UNREACHABLE)
		return false
	client_url = target
	_client_socket = socket
	multiplayer.multiplayer_peer = socket
	last_error = ""
	connect_deadline_ms = Time.get_ticks_msec() + CONNECT_TIMEOUT_MS
	_set_state(PvpProtocol.STATE_CONNECTING)
	return true

func disconnect_from_server() -> void:
	_reset_match_state()
	_close_socket()
	_set_state(PvpProtocol.STATE_OFFLINE)

func is_online() -> bool:
	return client_state != PvpProtocol.STATE_OFFLINE and client_state != PvpProtocol.STATE_CONNECTING

func get_display_name() -> String:
	var saved: String = str(SaveManager.current_data.get("player_name", ""))
	if not saved.is_empty():
		return saved
	var generated: String = LanguageManager.tf("pvp.default_name", [randi() % 9000 + 1000])
	SaveManager.set_player_name(generated)
	return generated

func set_display_name(value: String) -> String:
	var cleaned: String = value.strip_edges().substr(0, NAME_MAX_LENGTH)
	SaveManager.set_player_name(cleaned)
	return cleaned

func join_queue() -> bool:
	if client_state != PvpProtocol.STATE_CONNECTED:
		return false
	if GameManager.get_stamina() < GameBalance.STAMINA_PER_STAGE:
		pvp_error.emit(PvpProtocol.ERR_NOT_ENOUGH_STAMINA)
		return false
	_srv_join_queue.rpc_id(1, get_display_name(), GameManager.get_current_progress_stage(), _character_id())
	_set_state(PvpProtocol.STATE_QUEUED)
	return true

func create_room() -> bool:
	if client_state != PvpProtocol.STATE_CONNECTED:
		return false
	if GameManager.get_stamina() < GameBalance.STAMINA_PER_STAGE:
		pvp_error.emit(PvpProtocol.ERR_NOT_ENOUGH_STAMINA)
		return false
	_srv_create_room.rpc_id(1, get_display_name(), GameManager.get_current_progress_stage(), _character_id())
	_set_state(PvpProtocol.STATE_ROOM_WAITING)
	return true

func join_room(code: String) -> bool:
	if client_state != PvpProtocol.STATE_CONNECTED:
		return false
	var normalized: String = code.strip_edges().to_upper()
	if normalized.is_empty():
		return false
	if GameManager.get_stamina() < GameBalance.STAMINA_PER_STAGE:
		pvp_error.emit(PvpProtocol.ERR_NOT_ENOUGH_STAMINA)
		return false
	_srv_join_room.rpc_id(1, normalized, get_display_name(), GameManager.get_current_progress_stage(), _character_id())
	_set_state(PvpProtocol.STATE_QUEUED)
	return true

func cancel_matching() -> void:
	if client_state == PvpProtocol.STATE_QUEUED or client_state == PvpProtocol.STATE_ROOM_WAITING:
		_srv_cancel.rpc_id(1)
		_set_state(PvpProtocol.STATE_CONNECTED)

func submit_answer(index: int, answer: int) -> void:
	if not in_match or answered_current:
		return
	answered_current = true
	_srv_submit_answer.rpc_id(1, index, answer)

func leave_match() -> void:
	if in_match:
		_srv_leave.rpc_id(1)
	_reset_match_state()
	if client_state != PvpProtocol.STATE_OFFLINE:
		_set_state(PvpProtocol.STATE_CONNECTED)

# ------------------------------------------------------------------
# Client -> server RPCs
# ------------------------------------------------------------------

@rpc("any_peer", "call_remote", "reliable")
func _srv_join_queue(player_name: String, stage: int, character_id: String) -> void:
	if not is_server_mode:
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if _sender_busy(sender):
		return
	srv_meta[sender] = {"name": _clean_name(player_name), "stage": stage, "char_id": character_id}
	srv_queue.append(sender)
	_cli_queued.rpc_id(sender)
	if srv_queue.size() >= 2:
		var first: int = srv_queue.pop_front()
		var second: int = srv_queue.pop_front()
		_server_start_match(first, second)

@rpc("any_peer", "call_remote", "reliable")
func _srv_create_room(player_name: String, stage: int, character_id: String) -> void:
	if not is_server_mode:
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if _sender_busy(sender):
		return
	srv_meta[sender] = {"name": _clean_name(player_name), "stage": stage, "char_id": character_id}
	var code: String = _generate_room_code()
	srv_rooms[code] = {
		"peer": sender,
		"expires_ms": Time.get_ticks_msec() + int(GameBalance.PVP_ROOM_LIFETIME_SECONDS * 1000.0),
	}
	_cli_room_created.rpc_id(sender, code)

@rpc("any_peer", "call_remote", "reliable")
func _srv_join_room(code: String, player_name: String, stage: int, character_id: String) -> void:
	if not is_server_mode:
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if _sender_busy(sender):
		return
	var room: Dictionary = srv_rooms.get(code, {})
	if room.is_empty():
		_cli_error.rpc_id(sender, PvpProtocol.ERR_INVALID_ROOM)
		return
	var host: int = int(room["peer"])
	if host == sender or not _peer_online(host) or not srv_meta.has(host):
		srv_rooms.erase(code)
		_cli_error.rpc_id(sender, PvpProtocol.ERR_INVALID_ROOM)
		return
	srv_meta[sender] = {"name": _clean_name(player_name), "stage": stage, "char_id": character_id}
	srv_rooms.erase(code)
	_server_start_match(host, sender)

@rpc("any_peer", "call_remote", "reliable")
func _srv_cancel() -> void:
	if not is_server_mode:
		return
	var sender: int = multiplayer.get_remote_sender_id()
	srv_queue.erase(sender)
	srv_meta.erase(sender)
	for code in srv_rooms.keys().duplicate():
		if int(srv_rooms[code]["peer"]) == sender:
			srv_rooms.erase(code)

@rpc("any_peer", "call_remote", "reliable")
func _srv_submit_answer(index: int, answer: int) -> void:
	if not is_server_mode:
		return
	var sender: int = multiplayer.get_remote_sender_id()
	if not srv_peer_match.has(sender):
		return
	var match_state: Dictionary = srv_matches[int(srv_peer_match[sender])]
	if str(match_state["phase"]) != "question" or int(match_state["index"]) != index:
		return
	if not match_state["answers"].has(sender) or int(match_state["answers"][sender]) != -1:
		return
	match_state["answers"][sender] = answer
	for peer_id in match_state["answers"].keys():
		if int(match_state["answers"][peer_id]) == -1:
			return
	_server_resolve_round(match_state)

@rpc("any_peer", "call_remote", "reliable")
func _srv_rejoin(token: String) -> void:
	if not is_server_mode:
		return
	var sender: int = multiplayer.get_remote_sender_id()
	var match_id: int = _find_match_id_by_token(token)
	if match_id == 0:
		_cli_error.rpc_id(sender, PvpProtocol.ERR_DISCONNECTED)
		return
	var match_state: Dictionary = srv_matches[match_id]
	var old_peer: int = 0
	for peer_id in match_state["players"].keys():
		if str(match_state["players"][peer_id]["token"]) == token:
			old_peer = peer_id
	if old_peer == 0 or old_peer == sender:
		_cli_error.rpc_id(sender, PvpProtocol.ERR_DISCONNECTED)
		return
	var player: Dictionary = match_state["players"][old_peer]
	match_state["players"].erase(old_peer)
	match_state["players"][sender] = player
	match_state["answers"].erase(old_peer)
	match_state["answers"][sender] = -1
	srv_peer_match.erase(old_peer)
	srv_peer_match[sender] = match_id
	match_state["reconnect_token"] = ""
	if str(match_state["phase"]) == "reconnect":
		match_state["phase"] = "question"
	_cli_match_found.rpc_id(sender, _match_payload_for(match_id, sender, true))
	var other_id: int = _other_peer_id(match_state, sender)
	if other_id != 0 and _peer_online(other_id):
		_cli_opp_resumed.rpc_id(other_id)
	if str(match_state["phase"]) == "question":
		var remaining: int = int(ceil(float(int(match_state["deadline_ms"]) - Time.get_ticks_msec()) / 1000.0))
		if remaining < 3:
			match_state["deadline_ms"] = Time.get_ticks_msec() + REJOIN_GRACE_MS
			remaining = 3
		_cli_question.rpc_id(sender, int(match_state["index"]), str(match_state["question"].get("question_text", "")), remaining)
	else:
		_cli_countdown.rpc_id(sender, int(match_state["countdown_value"]))

@rpc("any_peer", "call_remote", "reliable")
func _srv_leave() -> void:
	if not is_server_mode:
		return
	var sender: int = multiplayer.get_remote_sender_id()
	srv_queue.erase(sender)
	srv_meta.erase(sender)
	for code in srv_rooms.keys().duplicate():
		if int(srv_rooms[code]["peer"]) == sender:
			srv_rooms.erase(code)
	if not srv_peer_match.has(sender):
		return
	var match_state: Dictionary = srv_matches.get(int(srv_peer_match[sender]), {})
	if match_state.is_empty():
		srv_peer_match.erase(sender)
		return
	_server_end_match(match_state, _other_peer_id(match_state, sender), PvpProtocol.END_REASON_YOU_LEFT)

# ------------------------------------------------------------------
# Server -> client RPCs
# ------------------------------------------------------------------

@rpc("authority", "call_remote", "reliable")
func _cli_queued() -> void:
	_set_state(PvpProtocol.STATE_QUEUED)

@rpc("authority", "call_remote", "reliable")
func _cli_room_created(code: String) -> void:
	last_room_code = code
	room_created.emit(code)
	_set_state(PvpProtocol.STATE_ROOM_WAITING)

@rpc("authority", "call_remote", "reliable")
func _cli_match_found(payload: Dictionary) -> void:
	match_payload = payload
	match_token = str(payload.get("token", ""))
	var resumed: bool = bool(payload.get("resumed", false))
	if not resumed and not auto_rejoin_active:
		if not GameManager.consume_stamina(GameBalance.STAMINA_PER_STAGE):
			_srv_leave.rpc_id(1)
			_set_state(PvpProtocol.STATE_CONNECTED)
			pvp_error.emit(PvpProtocol.ERR_NOT_ENOUGH_STAMINA)
			return
	auto_rejoin_active = false
	in_match = true
	answered_current = false
	_set_state(PvpProtocol.STATE_IN_MATCH if resumed else PvpProtocol.STATE_COUNTDOWN)
	match_found.emit(payload)

@rpc("authority", "call_remote", "reliable")
func _cli_countdown(value: int) -> void:
	countdown_tick.emit(value)

@rpc("authority", "call_remote", "reliable")
func _cli_question(index: int, text: String, seconds: int) -> void:
	answered_current = false
	current_question_index = index
	_set_state(PvpProtocol.STATE_IN_MATCH)
	question_received.emit(index, text, seconds)

@rpc("authority", "call_remote", "reliable")
func _cli_round(payload: Dictionary) -> void:
	last_round_payload = payload
	last_round_index = int(payload.get("index", -1))
	round_resolved.emit(payload)

@rpc("authority", "call_remote", "reliable")
func _cli_end(payload: Dictionary) -> void:
	in_match = false
	auto_rejoin_active = false
	answered_current = false
	last_end_payload = payload
	var reward: int = int(payload.get("reward_coins", 0))
	if reward > 0:
		GameManager.add_coins(reward)
	_set_state(PvpProtocol.STATE_RESULT)
	match_ended.emit(payload)

@rpc("authority", "call_remote", "reliable")
func _cli_opp_reconnecting(seconds_left: int) -> void:
	opponent_offline_seen = true
	opponent_reconnecting.emit(seconds_left)

@rpc("authority", "call_remote", "reliable")
func _cli_opp_resumed() -> void:
	opponent_offline_seen = false
	opponent_resumed.emit()

@rpc("authority", "call_remote", "reliable")
func _cli_error(code: String) -> void:
	last_error = code
	if auto_rejoin_active or in_match:
		_fail_reconnect()
	else:
		_set_state(PvpProtocol.STATE_CONNECTED)
	pvp_error.emit(code)

# ------------------------------------------------------------------
# Connection lifecycle (client)
# ------------------------------------------------------------------

func _on_connected_to_server() -> void:
	_set_state(PvpProtocol.STATE_CONNECTED)
	if auto_rejoin_active and not match_token.is_empty():
		_srv_rejoin.rpc_id(1, match_token)

func _on_connection_failed() -> void:
	_close_socket()
	if auto_rejoin_active:
		return
	_set_state(PvpProtocol.STATE_OFFLINE)
	pvp_error.emit(PvpProtocol.ERR_SERVER_UNREACHABLE)

func _on_server_disconnected() -> void:
	_close_socket()
	if in_match and not match_token.is_empty():
		auto_rejoin_active = true
		var now: int = Time.get_ticks_msec()
		reconnect_deadline_ms = now + int(GameBalance.PVP_RECONNECT_SECONDS * 1000.0)
		reconnect_next_try_ms = now + RECONNECT_RETRY_MS / 2
		_set_state(PvpProtocol.STATE_RECONNECTING)
		connection_lost.emit()
	else:
		_reset_match_state()
		_set_state(PvpProtocol.STATE_OFFLINE)
		pvp_error.emit(PvpProtocol.ERR_DISCONNECTED)

func _client_reconnect_tick() -> void:
	var now: int = Time.get_ticks_msec()
	if now >= reconnect_deadline_ms:
		_fail_reconnect()
		return
	if now >= reconnect_next_try_ms and client_state != PvpProtocol.STATE_CONNECTING:
		reconnect_next_try_ms = now + RECONNECT_RETRY_MS
		connect_to_server(client_url)

func _fail_connect_timeout() -> void:
	_close_socket()
	if auto_rejoin_active:
		reconnect_next_try_ms = Time.get_ticks_msec() + RECONNECT_RETRY_MS
		_set_state(PvpProtocol.STATE_RECONNECTING)
		return
	_set_state(PvpProtocol.STATE_OFFLINE)
	pvp_error.emit(PvpProtocol.ERR_SERVER_UNREACHABLE)

func _fail_reconnect() -> void:
	auto_rejoin_active = false
	in_match = false
	var opponent: String = str(match_payload.get("opponent_name", ""))
	match_payload = {}
	match_token = ""
	_close_socket()
	_set_state(PvpProtocol.STATE_OFFLINE)
	match_ended.emit({
		"win": false,
		"draw": false,
		"reason": PvpProtocol.ERR_DISCONNECTED,
		"reward_coins": 0,
		"opponent_name": opponent,
	})

# ------------------------------------------------------------------
# Server internals
# ------------------------------------------------------------------

func _server_start() -> void:
	var port_value: String = OS.get_environment("PORT")
	if not port_value.is_empty() and port_value.is_valid_int():
		server_port = int(port_value)
	var socket: WebSocketMultiplayerPeer = WebSocketMultiplayerPeer.new()
	if socket.create_server(server_port) != OK:
		push_error("PvP server could not bind port %d" % server_port)
		get_tree().quit(1)
		return
	multiplayer.multiplayer_peer = socket
	print("PvP server listening on port %d" % server_port)

func _server_tick() -> void:
	var now: int = Time.get_ticks_msec()
	for code in srv_rooms.keys().duplicate():
		var room: Dictionary = srv_rooms[code]
		if now >= int(room["expires_ms"]):
			srv_rooms.erase(code)
			if _peer_online(int(room["peer"])):
				_cli_error.rpc_id(int(room["peer"]), PvpProtocol.ERR_ROOM_EXPIRED)
	for match_id in srv_matches.keys().duplicate():
		var match_state: Dictionary = srv_matches[match_id]
		match str(match_state["phase"]):
			"countdown":
				if now >= int(match_state["next_tick_ms"]):
					var value: int = int(match_state["countdown_value"]) - 1
					if value >= 1:
						match_state["countdown_value"] = value
						match_state["next_tick_ms"] = now + COUNTDOWN_TICK_MS
						for peer_id in match_state["players"].keys():
							if _peer_online(peer_id):
								_cli_countdown.rpc_id(peer_id, value)
					else:
						_server_send_question(match_state)
			"question":
				if now >= int(match_state["deadline_ms"]):
					_server_resolve_round(match_state)
			"reconnect":
				if now >= int(match_state["reconnect_deadline_ms"]):
					var winner: int = 0
					for peer_id in match_state["players"].keys():
						if _peer_online(peer_id):
							winner = peer_id
					_server_end_match(match_state, winner, PvpProtocol.END_REASON_OPPONENT_FORFEIT)

func _server_start_match(first: int, second: int) -> void:
	var match_id: int = srv_next_match_id
	srv_next_match_id += 1
	var seed_value: int = srv_rng.randi()
	var min_stage: int = clampi(mini(_meta_stage(first), _meta_stage(second)), 1, 9999)
	var stage_data: Dictionary = DataManager.get_stage(min_stage)
	var params: Dictionary = {
		"min_number": int(stage_data.get("min_number", 1)),
		"max_number": int(stage_data.get("max_number", 10)),
		"question_types": stage_data.get("question_types", ["addition"]),
		"operation_ranges": stage_data.get("operation_ranges", {}),
	}
	var generator: QuestionGenerator = QuestionGenerator.new()
	generator.set_seed(seed_value)
	var players: Dictionary = {}
	for peer_id in [first, second]:
		players[peer_id] = {
			"token": "%d_%d" % [match_id, srv_rng.randi()],
			"name": str(srv_meta[peer_id]["name"]),
			"char_id": str(srv_meta[peer_id]["char_id"]),
			"hp": GameBalance.PVP_BASE_HP,
			"combo": 0,
		}
	srv_matches[match_id] = {
		"id": match_id,
		"players": players,
		"answers": {first: -1, second: -1},
		"seed": seed_value,
		"params": params,
		"generator": generator,
		"index": 0,
		"question": {},
		"phase": "countdown",
		"countdown_value": COUNTDOWN_START,
		"next_tick_ms": Time.get_ticks_msec() + COUNTDOWN_TICK_MS,
		"deadline_ms": 0,
		"reconnect_token": "",
		"reconnect_deadline_ms": 0,
	}
	srv_peer_match[first] = match_id
	srv_peer_match[second] = match_id
	srv_queue.erase(first)
	srv_queue.erase(second)
	for peer_id in [first, second]:
		_cli_match_found.rpc_id(peer_id, _match_payload_for(match_id, peer_id, false))
		_cli_countdown.rpc_id(peer_id, COUNTDOWN_START)

func _server_send_question(match_state: Dictionary) -> void:
	var question: Dictionary = match_state["generator"].generate(match_state["params"])
	match_state["question"] = question
	match_state["phase"] = "question"
	match_state["deadline_ms"] = Time.get_ticks_msec() + GameBalance.PVP_QUESTION_SECONDS * 1000
	for peer_id in match_state["players"].keys():
		match_state["answers"][peer_id] = -1
		if _peer_online(peer_id):
			_cli_question.rpc_id(peer_id, int(match_state["index"]), str(question.get("question_text", "")), GameBalance.PVP_QUESTION_SECONDS)

func _server_resolve_round(match_state: Dictionary) -> void:
	var correct_answer: int = int(match_state["question"].get("answer", 0))
	var player_ids: Array = match_state["players"].keys().duplicate()
	var correctness: Dictionary = {}
	for peer_id in player_ids:
		var submitted: int = int(match_state["answers"].get(peer_id, -1))
		correctness[peer_id] = submitted != -1 and submitted == correct_answer
	for peer_id in player_ids:
		var me: Dictionary = match_state["players"][peer_id]
		var other: Dictionary = match_state["players"][_other_peer_id(match_state, peer_id)]
		if bool(correctness[peer_id]):
			me["combo"] = int(me["combo"]) + 1
			other["hp"] = int(other["hp"]) - GameBalance.calculate_damage(GameBalance.PVP_BASE_ATTACK, int(me["combo"]))
		else:
			me["combo"] = 0
			me["hp"] = int(me["hp"]) - GameBalance.damage_taken(GameBalance.PVP_BASE_ATTACK, 0)
	for peer_id in player_ids:
		match_state["answers"][peer_id] = -1
	for peer_id in player_ids:
		if not _peer_online(peer_id):
			continue
		var other_id: int = _other_peer_id(match_state, peer_id)
		_cli_round.rpc_id(peer_id, {
			"index": int(match_state["index"]),
			"you_correct": bool(correctness[peer_id]),
			"opp_correct": bool(correctness[other_id]),
			"hp_you": int(match_state["players"][peer_id]["hp"]),
			"hp_opp": int(match_state["players"][other_id]["hp"]),
			"combo_you": int(match_state["players"][peer_id]["combo"]),
			"combo_opp": int(match_state["players"][other_id]["combo"]),
		})
	var hp_first: int = int(match_state["players"][player_ids[0]]["hp"])
	var hp_second: int = int(match_state["players"][player_ids[1]]["hp"])
	if hp_first <= 0 or hp_second <= 0:
		var winner: int = 0
		if hp_first > 0:
			winner = player_ids[0]
		elif hp_second > 0:
			winner = player_ids[1]
		_server_end_match(match_state, winner, PvpProtocol.END_REASON_HP)
		return
	match_state["index"] = int(match_state["index"]) + 1
	_server_send_question(match_state)

func _server_end_match(match_state: Dictionary, winner: int, reason: String) -> void:
	var player_ids: Array = match_state["players"].keys().duplicate()
	var draw: bool = winner == 0
	for peer_id in player_ids:
		var is_winner: bool = peer_id == winner
		var payload: Dictionary = {
			"win": is_winner and not draw,
			"draw": draw,
			"reason": reason,
			"reward_coins": GameBalance.PVP_LOSE_COINS,
			"opponent_name": str(match_state["players"][_other_peer_id(match_state, peer_id)]["name"]),
		}
		if not draw and is_winner:
			payload["reward_coins"] = GameBalance.PVP_WIN_COINS
		if _peer_online(peer_id):
			_cli_end.rpc_id(peer_id, payload)
	_cleanup_match(int(match_state["id"]))

func _srv_on_peer_disconnected(peer_id: int) -> void:
	srv_queue.erase(peer_id)
	srv_meta.erase(peer_id)
	for code in srv_rooms.keys().duplicate():
		if int(srv_rooms[code]["peer"]) == peer_id:
			srv_rooms.erase(code)
	if not srv_peer_match.has(peer_id):
		return
	var match_id: int = int(srv_peer_match[peer_id])
	var match_state: Dictionary = srv_matches.get(match_id, {})
	if match_state.is_empty() or not match_state["players"].has(peer_id):
		srv_peer_match.erase(peer_id)
		return
	if not _any_player_online(match_state):
		_cleanup_match(match_id)
		return
	match_state["phase"] = "reconnect"
	match_state["reconnect_token"] = str(match_state["players"][peer_id]["token"])
	match_state["reconnect_deadline_ms"] = Time.get_ticks_msec() + int(server_reconnect_seconds * 1000.0)
	var other_id: int = _other_peer_id(match_state, peer_id)
	if other_id != 0 and _peer_online(other_id):
		_cli_opp_reconnecting.rpc_id(other_id, int(ceil(server_reconnect_seconds)))

func _cleanup_match(match_id: int) -> void:
	var match_state: Dictionary = srv_matches.get(match_id, {})
	if not match_state.is_empty():
		for peer_id in match_state["players"].keys():
			srv_peer_match.erase(peer_id)
	srv_matches.erase(match_id)

# ------------------------------------------------------------------
# Signal forwarders
# ------------------------------------------------------------------

func _on_peer_connected(_peer_id: int) -> void:
	pass

func _on_peer_disconnected(peer_id: int) -> void:
	if is_server_mode:
		_srv_on_peer_disconnected(peer_id)

# ------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------

func configured_server_url() -> String:
	var env_url: String = OS.get_environment("PVP_SERVER_URL")
	if not env_url.strip_edges().is_empty():
		return _normalize_url(env_url.strip_edges())
	if FileAccess.file_exists(SERVER_CONFIG_PATH):
		var file: FileAccess = FileAccess.open(SERVER_CONFIG_PATH, FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				return _normalize_url(str(parsed.get("default_url", "")))
	return ""

func _normalize_url(raw: String) -> String:
	var value: String = raw.strip_edges()
	if value.is_empty():
		return ""
	if value.begins_with("ws://") or value.begins_with("wss://"):
		return value
	return "ws://" + value

func _set_state(state: String) -> void:
	if client_state == state:
		return
	client_state = state
	pvp_state_changed.emit(state)

func _reset_match_state() -> void:
	in_match = false
	answered_current = false
	current_question_index = -1
	auto_rejoin_active = false
	match_token = ""
	match_payload = {}
	last_round_payload = {}
	last_round_index = -1
	last_end_payload = {}
	last_room_code = ""
	opponent_offline_seen = false

func _close_socket() -> void:
	if _client_socket != null:
		_client_socket.close()
		_client_socket = null
	if not is_server_mode and multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()

func _character_id() -> String:
	return str(GameManager.get_selected_character().get("id", GameBalance.DEFAULT_CHARACTER_ID))

func _clean_name(value: String) -> String:
	var cleaned: String = value.strip_edges().substr(0, NAME_MAX_LENGTH)
	if cleaned.is_empty():
		cleaned = "Player"
	return cleaned

func _meta_stage(peer_id: int) -> int:
	var meta: Dictionary = srv_meta.get(peer_id, {})
	return int(meta.get("stage", 1))

func _sender_busy(sender: int) -> bool:
	return srv_peer_match.has(sender) or srv_queue.has(sender) or not _room_hosting(sender).is_empty()

func _room_hosting(sender: int) -> String:
	for code in srv_rooms.keys():
		if int(srv_rooms[code]["peer"]) == sender:
			return code
	return ""

func _peer_online(peer_id: int) -> bool:
	return multiplayer.get_peers().has(peer_id)

func _any_player_online(match_state: Dictionary) -> bool:
	for peer_id in match_state["players"].keys():
		if _peer_online(peer_id):
			return true
	return false

func _other_peer_id(match_state: Dictionary, peer_id: int) -> int:
	for candidate in match_state["players"].keys():
		if candidate != peer_id:
			return candidate
	return 0

func _match_payload_for(match_id: int, peer_id: int, resumed: bool) -> Dictionary:
	var match_state: Dictionary = srv_matches[match_id]
	var me: Dictionary = match_state["players"][peer_id]
	var other: Dictionary = match_state["players"][_other_peer_id(match_state, peer_id)]
	return {
		"opponent_name": str(other["name"]),
		"opponent_char": str(other["char_id"]),
		"seed": int(match_state["seed"]),
		"params": match_state["params"],
		"token": str(me["token"]),
		"hp": int(me["hp"]),
		"opponent_hp": int(other["hp"]),
		"index": int(match_state["index"]),
		"resumed": resumed,
	}

func _generate_room_code() -> String:
	var code: String = ""
	while true:
		code = ""
		for index in ROOM_CODE_LENGTH:
			code += ROOM_CODE_ALPHABET[srv_rng.randi() % ROOM_CODE_ALPHABET.length()]
		if not srv_rooms.has(code):
			break
	return code

func _find_match_id_by_token(token: String) -> int:
	for match_id in srv_matches.keys():
		var match_state: Dictionary = srv_matches[match_id]
		for peer_id in match_state["players"].keys():
			if str(match_state["players"][peer_id]["token"]) == token:
				return match_id
	return 0
