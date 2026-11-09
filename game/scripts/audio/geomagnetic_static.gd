extends AudioStreamPlayer3D
## Radio static on the aurora nights (Lily's sun_storms ruling, 2026-11-04: tie the
## storm to the aurora already scheduled, nothing new in the sky). While the aurora
## or STEVE shows, the ghost radio picks up the storm: a hiss under the music,
## crackling bursts, and now and then a falling whistle, as long lines and wireless
## sets did in the great storms. Generated, so there is no recording to license.

const AURORA_SLOTS := [20, 21] # aurora, steve (data/weather/phenomena.json)
const RATE := 22050.0

var level := 0.0
## The bus the static plays on. V1 hears it on the ghost radio; a V2 set
## hears it on its own programme's bus.
var bus_name := "GhostRadio"
var _playback: AudioStreamGeneratorPlayback
var _burst := 0.0
var _whistle := -1.0
var _phase := 0.0
var _hiss_state := 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = RATE
	generator.buffer_length = 0.25
	stream = generator
	bus = bus_name
	unit_size = 6.0
	_rng.seed = 1929

func _process(_delta: float) -> void:
	level = _storm_level()
	if level <= 0.001:
		if playing: stop()
		return
	if not playing:
		play(); _playback = get_stream_playback()
	if _playback == null: return
	var frames := _playback.get_frames_available()
	for i in frames:
		_playback.push_frame(Vector2.ONE * _sample())

func _storm_level() -> float:
	var weather := get_tree().get_first_node_in_group("weather_manager")
	if weather == null: return 0.0
	var levels: PackedFloat32Array = weather.get("_spectacle_levels")
	var strongest := 0.0
	for slot: int in AURORA_SLOTS:
		if slot < levels.size(): strongest = maxf(strongest, levels[slot])
	return clampf(strongest, 0.0, 1.0)

func _sample() -> float:
	# Hiss: filtered white noise.
	_hiss_state = lerpf(_hiss_state, _rng.randf_range(-1.0, 1.0), 0.35)
	var out := _hiss_state * 0.05 * level
	# Crackle: rare bursts that decay over a few milliseconds.
	if _rng.randf() < 0.0006 * level: _burst = _rng.randf_range(0.3, 1.0)
	_burst *= 0.996
	out += _rng.randf_range(-1.0, 1.0) * _burst * 0.35 * level
	# A whistler: a tone falling from about 6 kHz to a few hundred Hz over a second.
	if _whistle < 0.0 and _rng.randf() < 0.000006 * level: _whistle = 0.0
	if _whistle >= 0.0:
		var t := _whistle / RATE
		var frequency := 300.0 + 5700.0 / (1.0 + 9.0 * t)
		_phase += TAU * frequency / RATE
		out += sin(_phase) * 0.08 * level * clampf(1.0 - t, 0.0, 1.0)
		_whistle += 1.0
		if t > 1.2: _whistle = -1.0
	return out
