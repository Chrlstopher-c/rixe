class_name NetLink
extends Node
## Lien vers le relais : un WebSocket par joueur, rôle hôte ou invité, messages = dictionnaires sérialisés.

signal joined(peer_here: bool)
signal peer_changed(here: bool)
signal received(msg: Dictionary)
signal failed(reason: String)

const PING_EVERY := 3.0
## Nouvelles tentatives si la connexion tombe avant l'accueil du relais (réseau qui hoquette).
const RETRIES := 3
const REASONS := {4001: "Ce code est déjà pris", 4002: "La partie est complète", 4004: "Aucune partie avec ce code"}

var role := ""
var code := ""
var rtt := 0.0
var peer_here := false
var _ws := WebSocketPeer.new()
var _open := false
var _done := false
var _ping_t := 0.0
var _ping_sent := 0
var _base := ""
var _tries := 0
var _retry_t := -1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func open(room: String, as_role: String, base: String = RelayConfig.url()) -> void:
	code = room.to_upper()
	role = as_role
	_base = base
	_connect()


func _connect() -> void:
	_ws = WebSocketPeer.new()
	_ws.inbound_buffer_size = 1 << 20
	_ws.outbound_buffer_size = 1 << 20
	var err := _ws.connect_to_url("%s/room/%s?role=%s" % [_base, code, role])
	if err != OK:
		push_warning("connexion au relais impossible : %s" % error_string(err))
		_fail("Relais injoignable")


func is_host() -> bool:
	return role == "host"


func ready_to_play() -> bool:
	return _open and peer_here


func send(msg: Dictionary) -> void:
	if _open and peer_here:
		_ws.send(var_to_bytes(msg))


func close() -> void:
	_done = true
	_ws.close(1000, "fin")


func _process(delta: float) -> void:
	if _done:
		return
	if _retry_t >= 0.0:
		_retry_t -= delta
		if _retry_t < 0.0:
			_connect()
		return
	_ws.poll()
	match _ws.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			_read()
			_keepalive(delta)
		WebSocketPeer.STATE_CLOSED:
			var c := _ws.get_close_code()
			if not _open and not REASONS.has(c) and _tries < RETRIES:
				_tries += 1
				_retry_t = 0.5 * _tries
				push_warning("relais : connexion coupée avant l'accueil (code %d), nouvel essai" % c)
				return
			_fail(REASONS.get(c, "Connexion perdue" if _open else "Relais injoignable"))


func _read() -> void:
	while _ws.get_available_packet_count() > 0:
		var pkt := _ws.get_packet()
		if _ws.was_string_packet():
			_control(pkt.get_string_from_utf8())
			continue
		var msg: Variant = bytes_to_var(pkt)
		if msg is Dictionary:
			received.emit(msg)


func _control(text: String) -> void:
	if text == "pong":
		rtt = (Time.get_ticks_msec() - _ping_sent) / 1000.0
		return
	var data: Variant = JSON.parse_string(text)
	if not data is Dictionary:
		return
	match String(data.get("t", "")):
		"hello":
			_open = true
			peer_here = bool(data.get("peer", false))
			joined.emit(peer_here)
		"peer":
			peer_here = bool(data.get("on", false))
			peer_changed.emit(peer_here)


func _keepalive(delta: float) -> void:
	_ping_t -= delta
	if _ping_t <= 0.0:
		_ping_t = PING_EVERY
		_ping_sent = Time.get_ticks_msec()
		_ws.send_text("ping")


func _fail(reason: String) -> void:
	if _done:
		return
	_done = true
	_open = false
	failed.emit(reason)
