class_name NetLink
extends Node
## Lien vers le relais : un WebSocket par joueur, place 0 = hôte, 1 à 3 = invités ; messages = dictionnaires
## sérialisés, diffusés par le relais à tous les autres avec la place de l'expéditeur (clé « _from » à la réception).

signal joined(peer_here: bool)
signal peer_changed(slot: int, here: bool)
signal received(msg: Dictionary)
signal failed(reason: String)

const PING_EVERY := 3.0
## Nouvelles tentatives si la connexion tombe avant l'accueil du relais (réseau qui hoquette).
const RETRIES := 3
## Une connexion qui ne s'établit pas dans ce délai est abandonnée (sous Windows, un refus peut ne jamais remonter).
const CONNECT_TIMEOUT := 6.0
const REASONS := {4001: "Ce code est déjà pris", 4002: "La partie est complète", 4004: "Aucune partie avec ce code"}

var role := ""
var code := ""
var rtt := 0.0
var peer_here := false
## Ma place dans le salon et celles des autres joueurs présents.
var slot := -1
var peers: Array[int] = []
## Nombre de joueurs maximum (choisi par l'hôte à la création du salon).
var max_players := 2
var _ws := WebSocketPeer.new()
var _open := false
var _done := false
var _ping_t := 0.0
var _ping_sent := 0
var _base := ""
var _tries := 0
var _retry_t := -1.0
var _connect_ms := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func open(room: String, as_role: String, base: String = RelayConfig.url(), max_count: int = 2) -> void:
	code = room.to_upper()
	role = as_role
	max_players = max_count
	_base = base
	_connect()


func _connect() -> void:
	_connect_ms = Time.get_ticks_msec()
	_ws = WebSocketPeer.new()
	_ws.inbound_buffer_size = 1 << 20
	_ws.outbound_buffer_size = 1 << 20
	var err := _ws.connect_to_url("%s/room/%s?role=%s&max=%d" % [_base, code, role, max_players])
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
	if _ws.get_ready_state() == WebSocketPeer.STATE_CONNECTING:
		if Time.get_ticks_msec() - _connect_ms > CONNECT_TIMEOUT * 1000.0:
			push_warning("relais : pas de réponse en %.0f s" % CONNECT_TIMEOUT)
			_ws.close()
			_lost(-1)
		return
	match _ws.get_ready_state():
		WebSocketPeer.STATE_OPEN:
			_read()
			_keepalive(delta)
		WebSocketPeer.STATE_CLOSED:
			_lost(_ws.get_close_code())


## Connexion tombée : nouvel essai si on n'a pas encore été accueilli, sinon échec avec la raison lisible.
func _lost(c: int) -> void:
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
		if pkt.size() < 2:
			continue
		var msg: Variant = bytes_to_var(pkt.slice(1))
		if msg is Dictionary:
			msg["_from"] = int(pkt[0])
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
			slot = int(data.get("slot", 0))
			peers.clear()
			for p in data.get("peers", []):
				peers.append(int(p))
			peer_here = not peers.is_empty()
			joined.emit(peer_here)
		"peer":
			var who := int(data.get("slot", -1))
			var on := bool(data.get("on", false))
			if on and not who in peers:
				peers.append(who)
			elif not on:
				peers.erase(who)
			peer_here = not peers.is_empty()
			peer_changed.emit(who, on)


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
