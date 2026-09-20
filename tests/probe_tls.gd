extends Node

const REMOTE_URL: String = "wss://goblinmath-production-639a.up.railway.app"
const ECHO_URL: String = "wss://ws.postman-echo.com/raw"

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	await _probe("known-good echo server", ECHO_URL, true)
	await _probe("production server (verified TLS)", REMOTE_URL, true)
	await _probe("production server (insecure TLS)", REMOTE_URL, false)
	get_tree().quit(0)

func _probe(label: String, url: String, verify: bool) -> void:
	var ws: WebSocketPeer = WebSocketPeer.new()
	var options: TLSOptions = TLSOptions.client() if verify else TLSOptions.client_unsafe()
	var err: Error = ws.connect_to_url(url, options)
	print("[%s] connect_to_url err=%d" % [label, err])
	var deadline: int = Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < deadline:
		ws.poll()
		var state: int = ws.get_ready_state()
		if state == WebSocketPeer.STATE_OPEN:
			print("[%s] OPEN — websocket handshake works" % label)
			ws.close()
			await get_tree().create_timer(0.5).timeout
			return
		if state == WebSocketPeer.STATE_CLOSED:
			print("[%s] CLOSED code=%d reason=%s" % [label, ws.get_close_code(), ws.get_close_reason()])
			return
		await get_tree().create_timer(0.25).timeout
	print("[%s] TIMEOUT still state=%d" % [label, ws.get_ready_state()])
