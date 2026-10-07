extends Node
## Autoload Sfx : joue les bruitages en 2D (atténuation à distance, variation de hauteur), suit le ralenti,
## et mélange la musique en couches synchrones (calme, combat, tension) selon l'action.

const POOL := 24
const SOUNDS := ["rifle", "shotgun", "railgun", "impact", "flesh", "gore", "jump", "air_jump", "land", "dash",
	"shell", "swing", "punch", "slowmo", "pickup", "round", "ricochet",
	"reload_out", "reload_in", "dry", "pistol", "smg", "sniper", "launcher", "explosion", "slash", "tink",
	"hit", "headshot"]

var streams := {}
var _players: Array[AudioStreamPlayer2D] = []
var _flat: Array[AudioStreamPlayer] = []
var _flat_i := 0
var music: AudioStreamPlayer
const MUSIC_DB := -11.0
const LAYERS := ["calme", "combat", "tension"]
## Silence d'une couche éteinte (dB).
const MUTE_DB := -50.0
## Intensité de l'action (0-1) : tirs à l'écran, coups reçus ; retombe seule.
var heat := 0.0
## Dernier debout (un seul bot, vie basse, fin de chrono) : couche tension.
var tension := false
var _sync := AudioStreamSynchronized.new()
var _layer_db: Array[float] = [0.0, MUTE_DB, MUTE_DB]
var _lowpass := AudioEffectLowPassFilter.new()
var _music_bus := -1
var _voice_bus := ""
## Ambiance musicale en cours (thème d'arène) ; réverbération des bruitages selon le lieu.
var theme := ""
var _reverb := AudioEffectReverb.new()
## Écho par carte : galeries et halls résonnent, le plein air reste sec.
const PLACES := {"mine": 0.32, "usine": 0.22, "foret": 0.12, "toits": 0.06, "plateformes": 0.08, "survie": 0.05}
var _next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for s in SOUNDS:
		streams[s] = load("res://assets/sfx/%s.wav" % s)
	_setup_sfx_bus()
	for i in POOL:
		var p := AudioStreamPlayer2D.new()
		p.max_distance = 900.0
		p.attenuation = 1.6
		p.bus = "Sfx"
		add_child(p)
		_players.append(p)
	for i in 4:
		var f := AudioStreamPlayer.new()
		add_child(f)
		_flat.append(f)
	_setup_music()


func _setup_sfx_bus() -> void:
	AudioServer.add_bus()
	var i := AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, "Sfx")
	AudioServer.set_bus_send(i, "Master")
	_reverb.room_size = 0.75
	_reverb.damping = 0.5
	_reverb.dry = 1.0
	_reverb.wet = 0.08
	AudioServer.add_bus_effect(i, _reverb)


## Lieu de la manche : plus ou moins d'écho sur les bruitages.
func set_place(map: String) -> void:
	_reverb.wet = PLACES.get(map, 0.08)


## Ambiance musicale du thème (mêmes trois couches, autre tonalité et autre tempo) ; relancée si elle change.
func set_theme(name: String) -> void:
	if name == theme or not ResourceLoader.exists("res://assets/music/%s/calme.wav" % name):
		return
	theme = name
	var playing := music.playing
	_load_layers()
	if playing:
		music.play()


func _load_layers() -> void:
	_sync.stream_count = LAYERS.size()
	for i in LAYERS.size():
		var track: AudioStreamWAV = load("res://assets/music/%s/%s.wav" % [theme, LAYERS[i]])
		track.loop_mode = AudioStreamWAV.LOOP_FORWARD
		track.loop_end = int(track.get_length() * track.mix_rate)
		_sync.set_sync_stream(i, track)
		_sync.set_sync_stream_volume(i, _layer_db[i])


func _setup_music() -> void:
	theme = "crepuscule"
	_load_layers()
	AudioServer.add_bus()
	_music_bus = AudioServer.bus_count - 1
	AudioServer.set_bus_name(_music_bus, "Music")
	AudioServer.set_bus_send(_music_bus, "Master")
	_lowpass.cutoff_hz = 20000.0
	AudioServer.add_bus_effect(_music_bus, _lowpass)
	music = AudioStreamPlayer.new()
	music.stream = _sync
	music.bus = "Music"
	music.volume_db = MUSIC_DB
	add_child(music)


func play(name: String, at: Vector2, volume_db: float = 0.0, pitch_var: float = 0.08) -> void:
	var stream: AudioStream = streams.get(name)
	if stream == null:
		push_warning("son inconnu : " + name)
		return
	var p := _players[_next]
	_next = (_next + 1) % POOL
	p.stream = stream
	p.global_position = at
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.play()


func play_ui(name: String, volume_db: float = 0.0) -> void:
	var f := _flat[_flat_i]
	_flat_i = (_flat_i + 1) % _flat.size()
	f.stream = streams.get(name)
	f.volume_db = volume_db
	f.play()


func start_music() -> void:
	if not music.playing:
		music.play()


## Bus de l'annonceur : réverbération d'arène et compression, créé à la première demande.
func voice_bus() -> String:
	if _voice_bus != "":
		return _voice_bus
	AudioServer.add_bus()
	var i := AudioServer.bus_count - 1
	_voice_bus = "Voice"
	AudioServer.set_bus_name(i, _voice_bus)
	AudioServer.set_bus_send(i, "Master")
	var comp := AudioEffectCompressor.new()
	comp.threshold = -18.0
	comp.ratio = 4.0
	comp.gain = 4.0
	AudioServer.add_bus_effect(i, comp)
	var verb := AudioEffectReverb.new()
	verb.room_size = 0.7
	verb.damping = 0.4
	verb.wet = 0.22
	verb.dry = 0.9
	AudioServer.add_bus_effect(i, verb)
	return _voice_bus


## Chauffe la musique (tir à l'écran ≈ 0,06, coup reçu ≈ 0,25).
func add_heat(amount: float) -> void:
	heat = minf(heat + amount, 1.0)


func _process(delta: float) -> void:
	var real: float = Juice.real_delta(delta)
	AudioServer.playback_speed_scale = clampf(Engine.time_scale, 0.45, 1.0)
	heat = maxf(heat - real * 0.08, 0.0)
	var slow := Engine.time_scale < 0.6
	var fight := lerpf(MUTE_DB, 0.0, clampf(heat * 2.5, 0.0, 1.0))
	var goals: Array[float] = [-4.0 * heat, fight, 4.0 if tension else MUTE_DB]
	for i in LAYERS.size():
		var speed := 60.0 if goals[i] > _layer_db[i] else 14.0
		_layer_db[i] = move_toward(_layer_db[i], goals[i], real * speed)
		_sync.set_sync_stream_volume(i, _layer_db[i])
	_lowpass.cutoff_hz = move_toward(_lowpass.cutoff_hz, 700.0 if slow else 20000.0, real * 200000.0)
	music.volume_db = move_toward(music.volume_db, MUSIC_DB - (4.0 if slow else 0.0), real * 40.0)
