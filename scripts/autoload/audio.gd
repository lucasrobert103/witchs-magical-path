extends Node
## Music crossfades, looping ambience and a small pool of sound-effect voices.

const SFX_DIR := "res://assets/audio/sfx/"

var _music: Array[AudioStreamPlayer] = []
var _current := 0
var _music_path := ""
var _ambience: AudioStreamPlayer
var _voices: Array[AudioStreamPlayer] = []
var _cache := {}
var _music_tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		p.volume_db = -80.0
		add_child(p)
		_music.append(p)
	_ambience = AudioStreamPlayer.new()
	_ambience.bus = "Music"
	add_child(_ambience)
	for i in 12:
		var v := AudioStreamPlayer.new()
		v.bus = "SFX"
		add_child(v)
		_voices.append(v)
	Game.settings_changed.connect(_apply_volumes)
	_apply_volumes()

func _apply_volumes() -> void:
	var music := float(Game.settings.get("music", 0.75))
	var sfx := float(Game.settings.get("sfx", 0.9))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(music, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(maxf(sfx, 0.0001)))

func _load(path: String) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	var stream: AudioStream = load(path)
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	_cache[path] = stream
	return stream

func play_music(path: String, fade := 2.0, volume_db := -4.0) -> void:
	if path == _music_path:
		return
	_music_path = path
	var old := _music[_current]
	_current = 1 - _current
	var new := _music[_current]
	if _music_tween:
		_music_tween.kill()
	_music_tween = create_tween().set_parallel(true)
	if path != "":
		new.stream = _load(path)
		new.volume_db = -40.0
		new.play()
		_music_tween.tween_property(new, "volume_db", volume_db, fade)
	_music_tween.tween_property(old, "volume_db", -60.0, fade)
	_music_tween.chain().tween_callback(old.stop)

func stop_music(fade := 1.5) -> void:
	play_music("", fade)

func play_ambience(path: String, volume_db := -10.0) -> void:
	if path == "":
		_ambience.stop()
		return
	_ambience.stream = _load(path)
	_ambience.volume_db = volume_db
	_ambience.play()

func sfx(name: String, volume_db := 0.0, pitch_jitter := 0.06, pitch := 1.0) -> void:
	var path := SFX_DIR + name + ".wav"
	if not ResourceLoader.exists(path):
		return
	var stream: AudioStream = _cache.get(path)
	if stream == null:
		stream = load(path)
		_cache[path] = stream
	for v in _voices:
		if not v.playing:
			v.stream = stream
			v.volume_db = volume_db
			v.pitch_scale = pitch * (1.0 + randf_range(-pitch_jitter, pitch_jitter))
			v.play()
			return
	# All busy: steal the first voice.
	_voices[0].stream = stream
	_voices[0].volume_db = volume_db
	_voices[0].pitch_scale = pitch
	_voices[0].play()
