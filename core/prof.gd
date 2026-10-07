class_name Prof
## Profilage léger (RIXE_PROF=1) : temps cumulé par section, imprimé à la sortie par la sonde de perf.

static var on := OS.has_environment("RIXE_PROF")
static var _acc := {}
static var _start := {}


static func begin(key: String) -> void:
	if on:
		_start[key] = Time.get_ticks_usec()


static func end(key: String) -> void:
	if on and _start.has(key):
		_acc[key] = _acc.get(key, 0) + Time.get_ticks_usec() - _start[key]


static func report(frames: int) -> void:
	if not on:
		return
	var keys := _acc.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return _acc[a] > _acc[b])
	for k in keys:
		print("PROF %-18s %7.3f ms/frame" % [k, _acc[k] / 1000.0 / maxf(frames, 1)])
