extends Node
## Autoload Sfx : joue les bruitages en 2D (atténuation à distance, variation de hauteur), suit le ralenti.

const POOL := 24
const SOUNDS := ["rifle", "shotgun", "railgun", "impact", "flesh", "gore", "jump", "air_jump", "land", "dash",
	"shell", "swing", "punch", "slowmo", "pickup", "round"]

var streams := {}
var _players: Array[AudioStreamPlayer2D] = []
var _flat: AudioStreamPlayer
var music: AudioStreamPlayer
const MUSIC_DB := -11.0
var _next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for s in SOUNDS:
		streams[s] = load("res://assets/sfx/%s.wav" % s)
	for i in POOL:
		var p := AudioStreamPlayer2D.new()
		p.max_distance = 900.0
		p.attenuation = 1.6
		add_child(p)
		_players.append(p)
	_flat = AudioStreamPlayer.new()
	add_child(_flat)
	music = AudioStreamPlayer.new()
	var track: AudioStreamWAV = load("res://assets/music/combat.wav")
	track.loop_mode = AudioStreamWAV.LOOP_FORWARD
	track.loop_end = int(track.get_length() * track.mix_rate)
	music.stream = track
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
	_flat.stream = streams.get(name)
	_flat.volume_db = volume_db
	_flat.play()


func start_music() -> void:
	if not music.playing:
		music.play()


func _process(delta: float) -> void:
	AudioServer.playback_speed_scale = clampf(Engine.time_scale, 0.45, 1.0)
	var goal := MUSIC_DB - (9.0 if Engine.time_scale < 0.6 else 0.0)
	music.volume_db = move_toward(music.volume_db, goal, delta * 40.0)
