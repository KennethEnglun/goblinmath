class_name PvpProtocol
extends RefCounted

## Shared wire-protocol constants for real-time PvP. Transport uses Godot's
## high-level MultiplayerAPI over a WebSocketMultiplayerPeer: every message
## type below maps to one RPC method on the PvpNetwork autoload (whose node
## path is identical on client and server). The constants stay centralized so
## client, server, and tests reference the same vocabulary.

# Client -> server.
const MSG_JOIN_QUEUE: String = "join_queue"
const MSG_CREATE_ROOM: String = "create_room"
const MSG_JOIN_ROOM: String = "join_room"
const MSG_CANCEL_MATCHING: String = "cancel"
const MSG_SUBMIT_ANSWER: String = "submit"
const MSG_REJOIN: String = "rejoin"
const MSG_LEAVE: String = "leave"

# Server -> client.
const MSG_QUEUED: String = "queued"
const MSG_ROOM_CREATED: String = "room_created"
const MSG_MATCH_FOUND: String = "match"
const MSG_COUNTDOWN: String = "countdown"
const MSG_QUESTION: String = "question"
const MSG_ROUND: String = "round"
const MSG_END: String = "end"
const MSG_OPPONENT_RECONNECTING: String = "opp_reconnecting"
const MSG_ERROR: String = "error"

# Error codes (MSG_ERROR "code").
const ERR_SERVER_UNREACHABLE: String = "server_unreachable"
const ERR_INVALID_ROOM: String = "invalid_room"
const ERR_ROOM_EXPIRED: String = "room_expired"
const ERR_NOT_ENOUGH_STAMINA: String = "not_enough_stamina"
const ERR_DISCONNECTED: String = "disconnected"

# Match end reasons (MSG_END "reason").
const END_REASON_HP: String = "hp"
const END_REASON_OPPONENT_FORFEIT: String = "opponent_forfeit"
const END_REASON_YOU_LEFT: String = "you_left"

# Client state machine (PvpNetwork).
const STATE_OFFLINE: String = "offline"
const STATE_CONNECTING: String = "connecting"
const STATE_CONNECTED: String = "connected"
const STATE_QUEUED: String = "queued"
const STATE_ROOM_WAITING: String = "room_waiting"
const STATE_COUNTDOWN: String = "countdown"
const STATE_IN_MATCH: String = "in_match"
const STATE_RECONNECTING: String = "reconnecting"
const STATE_RESULT: String = "result"
