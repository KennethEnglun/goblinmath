extends Node

## Real-time PvP integration test. Boots an authoritative PvpNetwork server
## and two clients in isolated per-viewport MultiplayerAPI domains over a real
## loopback WebSocket, then walks the full matchmaking, room-code, combat,
## reconnect-resume, forfeit, and error flows.

const PVP_SCRIPT: GDScript = preload("res://scripts/managers/pvp_network.gd")
const PvpProtocol: GDScript = preload("res://scripts/pvp/pvp_protocol.gd")

var failures: int = 0
var server: Node
var client_a: Node
var client_b: Node
var server_port: int = 0
# SceneTree only auto-polls the root MultiplayerAPI; per-viewport domains used
# by this test need explicit polls every frame.
var _domain_apis: Array[SceneMultiplayer] = []

func _ready() -> void:
	call_deferred("_run_flow")

func _run_flow() -> void:
	var original_save_path: String = SaveManager.storage_path
	var suite_save_path: String = "/private/tmp/candymaths_pvp_suite_%d.json" % OS.get_process_id()
	SaveManager.storage_path = suite_save_path
	_cleanup_save_files(suite_save_path)
	GameManager.player_state = SaveManager.create_new_save()

	server_port = randi_range(25000, 45000)
	OS.set_environment("PORT", str(server_port))
	var server_domain: SubViewport = _make_domain("PvpServerDomain")
	server = _spawn_pvp(server_domain, true)
	server.server_reconnect_seconds = 2.0
	var domain_a: SubViewport = _make_domain("PvpClientADomain")
	client_a = _spawn_pvp(domain_a, false)
	var domain_b: SubViewport = _make_domain("PvpClientBDomain")
	client_b = _spawn_pvp(domain_b, false)

	await _test_quick_match_full_battle()
	await _reset_clients_to_lobby()
	await _test_room_code_flow()
	await _reset_clients_to_lobby()
	await _test_reconnect_resume()
	await _reset_clients_to_lobby()
	await _test_forfeit_on_give_up()
	await _reset_clients_to_lobby()
	await _test_invalid_room_error()
	_check(GameManager.get_stamina() == GameBalance.STAMINA_MAX - 8, "PvP consumed exactly 8 stamina across 4 matches")

	for domain: SubViewport in [server_domain, domain_a, domain_b]:
		domain.queue_free()
	if failures == 0:
		print("PVP_FLOW_TESTS_PASS")
	else:
		print("PVP_FLOW_TESTS_FAIL: %d" % failures)
	_cleanup_save_files(suite_save_path)
	SaveManager.storage_path = original_save_path
	get_tree().quit(failures)

# ------------------------------------------------------------------
# Scenarios
# ------------------------------------------------------------------

func _test_quick_match_full_battle() -> void:
	if not await _connect_clients():
		return
	var coins_before: int = GameManager.get_coins()
	_check(client_a.join_queue(), "Client A can join the quick-match queue")
	_check(client_b.join_queue(), "Client B can join the quick-match queue")
	if not await _wait_for_match_started():
		return
	var payload_a: Dictionary = client_a.match_payload
	var payload_b: Dictionary = client_b.match_payload
	_check(int(payload_a.get("seed", 0)) == int(payload_b.get("seed", 0)), "Both clients share the match seed")
	_check(int(payload_a.get("hp", 0)) == GameBalance.PVP_BASE_HP and int(payload_b.get("hp", 0)) == GameBalance.PVP_BASE_HP, "Both fighters start at full HP")
	_check(str(payload_a.get("opponent_name", "")) != "", "Match payload carries an opponent name")

	var match_state: Dictionary = _server_match()
	if match_state.is_empty():
		_check(false, "Server owns a live match")
		return
	if not await _wait_for_client_question(0):
		return
	_check(str(_server_match().get("phase", "")) == "question", "Server resolves countdown into the first question")
	var first_text: String = str(_server_match().get("question", {}).get("question_text", ""))
	_check(not first_text.is_empty(), "First question text arrives")
	_check(client_a.current_question_index == 0 and client_b.current_question_index == 0, "Both clients are on question 0")
	_check(str(_server_match()["question"]["question_text"]) == first_text, "Server question text is stable while both answer")

	# A always answers correctly, B always misses -> B loses after ~2 rounds.
	var rounds: int = 0
	while client_a.client_state != PvpProtocol.STATE_RESULT and rounds < 8:
		rounds += 1
		if not await _play_round(true, false):
			return
	await _wait_frames(4)
	var end_a: Dictionary = client_a.last_end_payload
	var end_b: Dictionary = client_b.last_end_payload
	_check(bool(end_a.get("win", false)), "A wins the mirrored duel")
	_check(not bool(end_b.get("win", true)) and not bool(end_b.get("draw", true)), "B loses the mirrored duel")
	_check(str(end_a.get("reason", "")) == PvpProtocol.END_REASON_HP, "Duel ends on HP")
	_check(int(end_a.get("reward_coins", 0)) == GameBalance.PVP_WIN_COINS, "Winner earns PVP_WIN_COINS")
	_check(int(end_b.get("reward_coins", 0)) == GameBalance.PVP_LOSE_COINS, "Loser earns PVP_LOSE_COINS")
	_check(GameManager.get_coins() - coins_before == GameBalance.PVP_WIN_COINS + GameBalance.PVP_LOSE_COINS, "Rewards are credited once per player")

	client_a.leave_match()
	client_b.leave_match()
	await _wait_frames(2)
	_check(client_a.client_state == PvpProtocol.STATE_CONNECTED, "A returns to the lobby state")
	_check(client_b.client_state == PvpProtocol.STATE_CONNECTED, "B returns to the lobby state")

func _test_room_code_flow() -> void:
	var coins_before: int = GameManager.get_coins()
	_check(client_a.create_room(), "A can open a room")
	var got_code: Callable = func() -> bool: return not client_a.last_room_code.is_empty()
	if not await _wait_until(got_code, 6000, "A receives a room code"):
		return
	var code: String = client_a.last_room_code
	_check(code.length() == 4, "Room code has 4 characters")
	_check(client_b.join_room(code.to_lower()), "Room codes are case-insensitive on join")
	if not await _wait_for_match_started():
		return
	var match_state: Dictionary = _server_match()
	if not await _wait_for_client_question(int(match_state["index"])):
		return
	if not await _play_round(true, true):
		return
	var hp_a: int = int(client_a.last_round_payload.get("hp_you", -1))
	var hp_b: int = int(client_b.last_round_payload.get("hp_you", -1))
	_check(hp_a == GameBalance.PVP_BASE_HP - 10 and hp_b == GameBalance.PVP_BASE_HP - 10, "Symmetric correct answers deal mirrored damage")
	client_b.leave_match()
	await _wait_frames(3)
	_check(bool(client_a.last_end_payload.get("win", false)) and str(client_a.last_end_payload.get("reason", "")) == PvpProtocol.END_REASON_YOU_LEFT, "Leaving hands the win to the opponent")
	_check(GameManager.get_coins() - coins_before == GameBalance.PVP_WIN_COINS + GameBalance.PVP_LOSE_COINS, "Forfeit rewards still pay both sides")
	client_a.leave_match()
	await _wait_frames(2)

func _test_reconnect_resume() -> void:
	_check(client_a.create_room(), "A opens a room for the reconnect test")
	var got_code: Callable = func() -> bool: return not client_a.last_room_code.is_empty()
	if not await _wait_until(got_code, 6000, "A gets a room code (reconnect test)"):
		return
	_check(client_b.join_room(client_a.last_room_code), "B joins the reconnect room")
	if not await _wait_for_match_started():
		return
	if not await _wait_for_client_question(0):
		return
	# Simulate B losing network without closing the match state client-side.
	client_b._close_socket()
	client_b._on_server_disconnected()
	var offline_flag: Callable = func() -> bool: return client_a.opponent_offline_seen
	if not await _wait_until(offline_flag, 4000, "A is told the opponent is reconnecting"):
		return
	_check(client_b.client_state == PvpProtocol.STATE_RECONNECTING, "B enters the rejoin window")
	var rejoined: Callable = func() -> bool:
		return client_b.client_state == PvpProtocol.STATE_IN_MATCH and bool(client_b.match_payload.get("resumed", false))
	if not await _wait_until(rejoined, 8000, "B auto-rejoins into the running match"):
		return
	await _wait_frames(3)
	_check(not client_a.opponent_offline_seen, "A sees the opponent resume")
	_check(int(client_b.match_payload.get("hp", -1)) == GameBalance.PVP_BASE_HP, "B's HP survives the reconnect")
	_check(not client_b.match_token.is_empty() and client_b.match_token != client_a.match_token, "B rejoins with its own match token")
	if not await _play_round(false, true):
		return
	client_b.leave_match()
	await _wait_frames(3)
	_check(bool(client_a.last_end_payload.get("win", false)), "A wins after B leaves post-resume")
	client_a.leave_match()
	await _wait_frames(2)

func _test_forfeit_on_give_up() -> void:
	_check(client_a.create_room(), "A opens a room for the forfeit test")
	var got_code: Callable = func() -> bool: return not client_a.last_room_code.is_empty()
	if not await _wait_until(got_code, 6000, "A gets a room code (forfeit test)"):
		return
	_check(client_b.join_room(client_a.last_room_code), "B joins the forfeit room")
	if not await _wait_for_match_started():
		return
	if not await _wait_for_client_question(0):
		return
	client_b._close_socket()
	client_b._on_server_disconnected()
	client_b.auto_rejoin_active = false
	var forfeit_done: Callable = func() -> bool: return client_a.client_state == PvpProtocol.STATE_RESULT
	var won_by_forfeit: bool = await _wait_until(forfeit_done, 8000, "A wins by forfeit inside the reconnect window")
	if won_by_forfeit:
		_check(str(client_a.last_end_payload.get("reason", "")) == PvpProtocol.END_REASON_OPPONENT_FORFEIT, "Forfeit reason is reported")
		_check(int(client_a.last_end_payload.get("reward_coins", 0)) == GameBalance.PVP_WIN_COINS, "Forfeit win pays the winner")
	client_a.leave_match()
	await _wait_frames(2)

func _test_invalid_room_error() -> void:
	_check(client_a.join_room("ZZZZ"), "A can attempt a bogus room code")
	var error_seen: Callable = func() -> bool: return not client_a.last_error.is_empty()
	var errored: bool = await _wait_until(error_seen, 6000, "Bogus room code surfaces an error")
	if errored:
		_check(client_a.last_error == PvpProtocol.ERR_INVALID_ROOM, "Bogus room code reports invalid_room")
		_check(client_a.client_state == PvpProtocol.STATE_CONNECTED, "A recovers to the lobby after the error")

# ------------------------------------------------------------------
# Flow helpers
# ------------------------------------------------------------------

func _reset_clients_to_lobby() -> void:
	client_a.leave_match()
	client_b.leave_match()
	await _wait_frames(2)

func _connect_clients() -> bool:
	var url: String = "ws://127.0.0.1:%d" % server_port
	if not client_a.connect_to_server(url):
		_check(false, "Client A socket opens")
		return false
	if not client_b.connect_to_server(url):
		_check(false, "Client B socket opens")
		return false
	var predicate: Callable = func() -> bool:
		return client_a.client_state == PvpProtocol.STATE_CONNECTED and client_b.client_state == PvpProtocol.STATE_CONNECTED
	return await _wait_until(predicate, 8000, "Both clients connect to the local server")

func _wait_for_match_started() -> bool:
	var predicate: Callable = func() -> bool:
		return client_a.in_match and client_b.in_match and not _server_match().is_empty()
	return await _wait_until(predicate, 9000, "Server matches the two players")

func _wait_for_client_question(expected_index: int) -> bool:
	var predicate: Callable = func() -> bool:
		var match_state: Dictionary = _server_match()
		return str(match_state.get("phase", "")) == "question" \
			and int(match_state.get("index", -1)) == expected_index \
			and client_a.current_question_index == expected_index \
			and client_b.current_question_index == expected_index
	return await _wait_until(predicate, 9000, "Both clients receive question %d" % expected_index)

func _play_round(a_correct: bool, b_correct: bool) -> bool:
	var match_state: Dictionary = _server_match()
	if match_state.is_empty() or str(match_state.get("phase", "")) != "question":
		_check(false, "Round attempted while no question is live")
		return false
	var index: int = int(match_state["index"])
	var answer: int = int(match_state["question"]["answer"])
	client_a.submit_answer(index, answer if a_correct else answer + 1)
	client_b.submit_answer(index, answer if b_correct else answer + 1)
	var predicate: Callable = func() -> bool:
		return client_a.last_round_index == index \
			and client_b.last_round_index == index
	return await _wait_until(predicate, 6000, "Round %d resolves for both clients" % index)

# ------------------------------------------------------------------
# Infrastructure helpers
# ------------------------------------------------------------------

func _make_domain(domain_name: String) -> SubViewport:
	var viewport: SubViewport = SubViewport.new()
	viewport.name = domain_name
	get_tree().root.add_child(viewport)
	var api: SceneMultiplayer = SceneMultiplayer.new()
	get_tree().set_multiplayer(api, viewport.get_path())
	_domain_apis.append(api)
	return viewport

func _spawn_pvp(domain: SubViewport, as_server: bool) -> Node:
	var node: Node = Node.new()
	node.name = "PvpNetwork"
	node.set_script(PVP_SCRIPT)
	if as_server:
		node.enable_server_mode()
	domain.add_child(node)
	return node

func _server_match() -> Dictionary:
	for match_id in server.srv_matches.keys():
		return server.srv_matches[match_id]
	return {}

func _wait_until(predicate: Callable, timeout_ms: int, message: String) -> bool:
	var deadline: int = Time.get_ticks_msec() + timeout_ms
	while Time.get_ticks_msec() < deadline:
		_poll_domains()
		if predicate.call():
			return true
		await get_tree().process_frame
	failures += 1
	push_error("FAIL (timeout): " + message)
	return false

func _poll_domains() -> void:
	for api in _domain_apis:
		api.poll()

func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error("FAIL: " + message)

func _wait_frames(count: int) -> void:
	for index in count:
		_poll_domains()
		await get_tree().process_frame

func _cleanup_save_files(base_path: String) -> void:
	for path: String in [base_path, base_path + ".bak", base_path + ".tmp", base_path + ".recover.tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
