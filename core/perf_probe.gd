extends Node
## Sonde de perf (--perf=<s>) : temps de frame réels après 2 s de chauffe ; imprime moyenne et 1 % bas puis quitte.

var duration := 20.0
var fighters: Callable
var _last := 0
var _times: Array[float] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if _last > 0:
		_measure((now - _last) / 1000000.0)
	_last = now


func _measure(real: float) -> void:
	if real > 0.03 and OS.has_environment("RIXE_SPIKES"):
		print("SPIKE %.0fms t=%.1f ts=%.2f" % [real * 1000.0, Time.get_ticks_msec() / 1000.0, Engine.time_scale])
	duration -= real
	if Time.get_ticks_msec() > 2000:
		_times.append(real)
	if duration > 0.0 or _times.is_empty():
		return
	var sorted := _times.duplicate()
	sorted.sort()
	var sum := func(a: float, b: float) -> float: return a + b
	var avg: float = sorted.size() / sorted.reduce(sum, 0.0)
	var low_n := maxi(1, sorted.size() / 100)
	var low: float = low_n / sorted.slice(sorted.size() - low_n).reduce(sum, 0.0)
	var rid := get_viewport().get_viewport_rid()
	var gpu := RenderingServer.viewport_get_measured_render_time_gpu(rid)
	var cpu := RenderingServer.viewport_get_measured_render_time_cpu(rid)
	print("PERF fps_moyen=%.1f fps_1pct_bas=%.1f rendu_gpu_ms=%.2f rendu_cpu_ms=%.2f combattants=%d frames=%d"
		% [avg, low, gpu, cpu, fighters.call(), sorted.size()])
	Prof.report(sorted.size())
	get_tree().quit()
