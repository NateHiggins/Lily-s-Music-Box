class_name MotifRenderer
extends Node
## Renders a MotifDefinition through a TranslationProfile. One renderer per
## sound source ("body"). Emits signals for every audible event so visuals
## (lamp, radiator shake, waveform) can react without knowing about audio.
##
## Each renderer owns a private mix bus (created at runtime) carrying its
## stereo pan; the bus sends into the profile's shared bus ("Room"/"Caller"/
## "UI"), which is where reverb / phone-line coloration live.

signal event_played(event_index: int, accent: float, pitch_semitones: float)
signal loop_started(iteration: int)
signal playback_finished

const VOICE_COUNT := 6

@export var profile: TranslationProfile
@export var motif: MotifDefinition

## 0..1. Scales loudness, event reliability and (for hum) obviousness.
@export var infection_intensity := 0.5
@export var tempo_scale := 1.0
@export var drift_multiplier := 1.0
@export var volume_offset_db := 0.0

## When true, implied-but-absent events are voiced too (used for the
## "Complete" outcome and for the caller finishing the motif herself).
@export var include_missing_events := false

var playing := false
var looping := false
var iteration := 0

var _t := 0.0
var _schedule: Array = []  # [{time, index, accent, pitch}] sorted by time
var _next := 0
var _voices: Array[AudioStreamPlayer] = []
var _cursor := 0
var _hum: AudioStreamPlayer = null
var _hum_amp := 0.0
var _hum_pitch := 0.0
var _bus_name := ""
var _rng := RandomNumberGenerator.new()
var _singles: Array = []  # scripted one-off events: [{delay, index}]


func _ready() -> void:
	_rng.randomize()
	if profile == null:
		push_warning("MotifRenderer '%s' has no profile" % name)
		return
	_bus_name = AudioEnv.make_source_bus("src_%s_%d" % [profile.id, get_instance_id()], profile.bus, profile.pan)
	for i in VOICE_COUNT:
		var p := AudioStreamPlayer.new()
		p.bus = _bus_name
		add_child(p)
		_voices.append(p)
	if profile.render_mode == TranslationProfile.RenderMode.HUM:
		_hum = AudioStreamPlayer.new()
		_hum.bus = _bus_name
		_hum.stream = AudioFactory.get_stream(profile.timbre)
		_hum.volume_db = -60.0
		add_child(_hum)


func _exit_tree() -> void:
	if _bus_name != "":
		AudioEnv.free_source_bus(_bus_name)


func play(loop := true) -> void:
	if profile == null or motif == null:
		return
	playing = true
	looping = loop
	iteration = 0
	_t = 0.0
	_build_schedule()
	if _hum and not _hum.playing:
		_hum.play()
	loop_started.emit(iteration)


func stop() -> void:
	playing = false
	looping = false
	_schedule.clear()
	if _hum:
		_hum.stop()


## Voice a single motif event now (or after delay), independent of looping.
## Used for scripted beats: the player's hum completing the motif, the
## radiator's answering knock, an early interrupt.
func play_single_event(index: int, delay := 0.0) -> void:
	if motif == null or index >= motif.event_count():
		return
	_singles.append({"delay": delay, "index": index})
	if _hum and not _hum.playing:
		_hum.play()


func set_motif(m: MotifDefinition) -> void:
	motif = m  # picked up at the next loop boundary; mid-loop schedule finishes


func fade_out(duration: float) -> void:
	var tw := create_tween()
	tw.tween_property(self, "volume_offset_db", -40.0, duration)
	tw.tween_callback(stop)


func output_bus() -> String:
	return _bus_name


func loop_position() -> float:
	if not playing or motif == null:
		return -1.0
	return clampf(_t / (motif.loop_duration * tempo_scale), 0.0, 1.0)


func _build_schedule() -> void:
	_schedule.clear()
	_next = 0
	var inf := clampf(infection_intensity, 0.0, 1.0)
	for i in motif.event_count():
		if motif.is_missing(i) and profile.omit_missing_events and not include_missing_events:
			continue
		if profile.partial_below_infection > 0.0 and inf < profile.partial_below_infection \
				and i >= profile.partial_event_count:
			continue
		var reliability := clampf(profile.event_reliability * lerpf(0.6, 1.0, inf), 0.0, 1.0)
		if _rng.randf() > reliability:
			continue
		var drift := profile.timing_drift * drift_multiplier
		var t := motif.event_times[i] * tempo_scale + _rng.randf_range(-drift, drift)
		# Bodies with poor dynamics flatten accents toward uniform loudness.
		var accent := lerpf(1.0, motif.accent_at(i), profile.accent_accuracy)
		accent *= _rng.randf_range(0.92, 1.0)
		var pitch := motif.pitch_at(i) * profile.pitch_expression \
				+ _rng.randf_range(-profile.pitch_instability, profile.pitch_instability)
		_schedule.append({"time": maxf(t, 0.0), "index": i, "accent": accent, "pitch": pitch})
	_schedule.sort_custom(func(a, b): return a.time < b.time)


func _process(delta: float) -> void:
	_process_singles(delta)
	if _hum:
		_update_hum(delta)
	if not playing or motif == null:
		return
	_t += delta
	while _next < _schedule.size() and _schedule[_next].time <= _t:
		_trigger(_schedule[_next])
		_next += 1
	var dur := motif.loop_duration * tempo_scale
	if _t >= dur:
		if looping:
			iteration += 1
			_t = fmod(_t, dur)
			_build_schedule()
			loop_started.emit(iteration)
		elif _next >= _schedule.size():
			playing = false
			playback_finished.emit()


func _process_singles(delta: float) -> void:
	if _singles.is_empty():
		return
	var due: Array = []
	for ev in _singles:
		ev.delay -= delta
		if ev.delay <= 0.0:
			due.append(ev)
	for ev in due:
		_singles.erase(ev)
		if motif == null:
			continue
		var i: int = ev.index
		_trigger({
			"time": 0.0,
			"index": i,
			"accent": motif.accent_at(i),
			"pitch": motif.pitch_at(i) * maxf(profile.pitch_expression, 0.5),
		})


func _trigger(ev: Dictionary) -> void:
	if profile.render_mode == TranslationProfile.RenderMode.HUM:
		# The continuous drone expresses this event via _update_hum's envelope.
		_hum_amp = maxf(_hum_amp, ev.accent)
		_hum_pitch = ev.pitch
		event_played.emit(ev.index, ev.accent, ev.pitch)
		return
	var v := _voices[_cursor]
	_cursor = (_cursor + 1) % _voices.size()
	v.stream = AudioFactory.get_stream(profile.timbre)
	v.pitch_scale = clampf(pow(2.0, ev.pitch / 12.0), 0.3, 3.0)
	var inf_gain := lerpf(-8.0, 0.0, clampf(infection_intensity, 0.0, 1.0))
	v.volume_db = profile.base_volume_db + volume_offset_db + inf_gain \
			+ linear_to_db(clampf(ev.accent, 0.08, 1.0))
	v.play()
	event_played.emit(ev.index, ev.accent, ev.pitch)


## Rhythm as amplitude swells, pitch contour as slow frequency bends.
## The hum can't do sharp percussion — that limitation *is* its character.
func _update_hum(delta: float) -> void:
	_hum_amp = maxf(_hum_amp - delta * 2.2, 0.0)
	var base := 0.22 if (playing or not _singles.is_empty()) else 0.0
	var inf := clampf(infection_intensity, 0.0, 1.0)
	var amp := clampf(base + _hum_amp * lerpf(0.3, 1.0, inf), 0.0, 1.2)
	var target_db := profile.base_volume_db + volume_offset_db + linear_to_db(maxf(amp, 0.02))
	_hum.volume_db = lerpf(_hum.volume_db, target_db, 1.0 - exp(-delta * 14.0))
	var target_pitch := pow(2.0, _hum_pitch / 12.0)
	_hum.pitch_scale = clampf(lerpf(_hum.pitch_scale, target_pitch, 1.0 - exp(-delta * 5.0)), 0.5, 2.0)
	if not playing and _singles.is_empty() and _hum.playing and _hum.volume_db < -55.0:
		_hum.stop()
