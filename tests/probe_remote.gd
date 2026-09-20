extends Node

## One-off remote smoke test: connect the real PvpNetwork autoload to the
## deployed Railway server, join the queue, and verify the server acks.

const REMOTE_URL: String = "wss://goblinmath-production-639a.up.railway.app"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var connected: bool = PvpNetwork.connect_to_server(REMOTE_URL)
	print("connect_to_server -> ", connected)
	var deadline: int = Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < deadline and PvpNetwork.client_state != PvpProtocol.STATE_CONNECTED:
		await get_tree().process_frame
	print("state after connect wait: ", PvpNetwork.client_state)
	if PvpNetwork.client_state != PvpProtocol.STATE_CONNECTED:
		print("REMOTE_PROBE_FAIL: no websocket connection")
		get_tree().quit(1)
		return
	var queued: bool = PvpNetwork.join_queue()
	print("join_queue -> ", queued)
	deadline = Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline and PvpNetwork.client_state != PvpProtocol.STATE_QUEUED:
		await get_tree().process_frame
	if PvpNetwork.client_state == PvpProtocol.STATE_QUEUED:
		print("REMOTE_PROBE_PASS: connected + queued ack received from production server")
		get_tree().quit(0)
	else:
		print("REMOTE_PROBE_FAIL: no queued ack, state=", PvpNetwork.client_state, " last_error=", PvpNetwork.last_error)
		get_tree().quit(1)
