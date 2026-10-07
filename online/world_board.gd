class_name WorldBoard
extends Node
## Classement mondial : envoie le score de fin de partie au Worker (sous le pseudo) et lit le top 20 par tableau.

signal updated(board: String)

## Tableaux déjà lus : clé → liste de {name, score, at} ; absent = jamais lu, null = injoignable.
var cache := {}
## Désactivé pendant les tests (comme les réglages) sauf si un test le force.
var enabled := Settings.persist


static func base_url() -> String:
	return RelayConfig.url().replace("wss://", "https://").replace("ws://", "http://")


func submit(board: String, score: float) -> void:
	if not enabled or score <= 0.0:
		return
	var body := JSON.stringify({"board": board, "name": Names.load_nick(), "score": score})
	_request(base_url() + "/scores", HTTPClient.METHOD_POST, body, func(_data: Variant) -> void: fetch(board))


func fetch(board: String) -> void:
	if not enabled:
		return
	_request(base_url() + "/scores?board=" + board.uri_encode(), HTTPClient.METHOD_GET, "",
		func(data: Variant) -> void:
			cache[board] = data.get("top", []) if data is Dictionary else null
			updated.emit(board))


func _request(url: String, method: int, body: String, done: Callable) -> void:
	var http := HTTPRequest.new()
	http.timeout = 8.0
	add_child(http)
	http.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, raw: PackedByteArray) -> void:
		http.queue_free()
		if result != HTTPRequest.RESULT_SUCCESS:
			push_warning("classement mondial injoignable (%d)" % result)
			done.call(null)
			return
		var data: Variant = JSON.parse_string(raw.get_string_from_utf8())
		if code >= 400:
			push_warning("classement mondial : réponse %d" % code)
		done.call(data))
	var err := http.request(url, ["Content-Type: application/json"], method, body)
	if err != OK:
		push_warning("classement mondial : requête impossible (%s)" % error_string(err))
		http.queue_free()
		done.call(null)
