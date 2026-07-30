class_name PropAudio
extends RefCounted
## Procedural sounds for functional props, synthesized once at startup.
## Mono 22050 Hz keeps dozens of positional emitters cheap.

const RATE := 22050
static var _cache: Dictionary = {}


static func get_stream(key: String) -> AudioStreamWAV:
	if not _cache.has(key):
		_cache[key] = _build(key)
	return _cache[key]


## Tests and editor hot-reloads can explicitly release the synthesized bank
## after all players have stopped. Runtime keeps the cache for the session.
static func clear_cache() -> void:
	_cache.clear()


static func _build(key: String) -> AudioStreamWAV:
	match key:
		"knock":
			return _partials(0.24, [[167, 16, 1.0], [316, 22, 0.55],
					[521, 30, 0.35], [943, 44, 0.22]], 0.006)
		"tick":
			return _partials(0.07, [[850, 70, 1.0], [1900, 120, 0.4]], 0.002)
		"thud":
			return _partials(0.5, [[48, 8, 1.0], [92, 14, 0.5],
					[140, 20, 0.25]], 0.01)
		"bell":
			return _partials(1.2, [[880, 2.4, 1.0], [1758, 3.4, 0.5],
					[2640, 5.0, 0.2]], 0.001)
		"pop":
			return _partials(0.22, [[210, 26, 1.0], [95, 16, 0.6],
					[1400, 90, 0.35]], 0.004)
		"creak":
			return _creak()
		"whistle_loop":
			return _whistle()
		"breath":
			return _breath()
		"vocal":
			return _vocal()
		"murmur_loop":
			return _murmur_loop()
		"hum_loop":
			return _hum([50, 100, 150], [0.6, 0.35, 0.18], 2.0)
		"buzz_loop":
			return _hum([100, 200, 300, 411], [0.5, 0.3, 0.2, 0.08], 1.0)
		"agitate_loop":
			return _agitate()
		_:
			push_warning("PropAudio: unknown key %s" % key)
			return _partials(0.1, [[440, 20, 1.0]], 0.0)


static func _partials(dur: float, parts: Array, noise_t: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for p in parts:
			v += p[2] * sin(TAU * p[0] * t) * exp(-p[1] * t)
		if t < noise_t:
			v += rng.randf_range(-0.8, 0.8) * (1.0 - t / noise_t)
		s[i] = v
	return _pack(s)


static func _hum(freqs: Array, amps: Array, dur: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for j in freqs.size():
			v += amps[j] * sin(TAU * freqs[j] * t)
		s[i] = v * (1.0 + 0.06 * sin(TAU * 1.0 * t))
	return _pack(s, true)


static func _agitate() -> AudioStreamWAV:
	var n := int(2.5 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp += 0.06 * (rng.randf_range(-1, 1) - lp)
		var slosh := 0.5 + 0.5 * sin(TAU * 1.2 * t)  # 1.2 Hz drum reversal
		s[i] = lp * 6.0 * slosh + 0.15 * sin(TAU * 60.0 * t)
	# crossfade tail into head for a clean loop
	var fade := int(0.2 * RATE)
	for i in fade:
		var w := float(i) / fade
		s[i] = s[i] * w + s[n - fade + i] * (1.0 - w)
	s.resize(n - fade)
	return _pack(s, true)


## Kettle whistle: breathy near-pure tone with a slow wobble, loopable.
static func _whistle() -> AudioStreamWAV:
	var n := int(1.0 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 212
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := 1180.0 * (1.0 + 0.012 * sin(TAU * 3.0 * t))
		lp += 0.3 * (rng.randf_range(-1.0, 1.0) - lp)
		s[i] = sin(TAU * f * t) * 0.85 + 0.3 * sin(TAU * f * 2.0 * t) \
				+ 0.18 * lp
	return _pack(s, true)


## Dry timber creak: a gliding squeal with grain noise.
static func _creak() -> AudioStreamWAV:
	var n := int(0.34 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1927
	var phase := 0.0
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := 320.0 * exp(-t * 2.0) + 140.0
		phase += TAU * f / RATE
		lp += 0.12 * (rng.randf_range(-1.0, 1.0) - lp)
		var env := minf(t / 0.04, 1.0) * minf((0.34 - t) / 0.10, 1.0)
		var grain := 0.6 + 0.4 * sin(TAU * 23.0 * t)
		s[i] = env * (sin(phase) * grain + 0.25 * lp)
	return _pack(s)


## One filtered exhalation — the caller's breathing carrying the motif.
static func _breath() -> AudioStreamWAV:
	var n := int(0.22 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / RATE
		var w := rng.randf_range(-1.0, 1.0)
		lp += 0.16 * (w - lp)
		lp2 += 0.16 * (lp - lp2)
		s[i] = lp2 * pow(sin(PI * t / 0.22), 1.6)
	return _pack(s)


## Placeholder hummed note (the player's voice answering the motif).
static func _vocal() -> AudioStreamWAV:
	var n := int(0.38 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var phase := 0.0
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := 196.0 * pow(2.0, 0.25 * sin(TAU * 5.4 * t) / 12.0)
		phase += TAU * f / RATE
		lp += 0.08 * (rng.randf_range(-1.0, 1.0) - lp)
		var env := minf(t / 0.05, 1.0) * minf((0.38 - t) / 0.12, 1.0)
		s[i] = env * (sin(phase) + 0.25 * sin(2.0 * phase) + 0.35 * lp)
	return _pack(s)


## Speech-shaped band noise: the caller's wordless voice on a bad line.
static func _murmur_loop() -> AudioStreamWAV:
	var n := int(6.0 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 555
	var hi := 0.0
	var lo := 0.0
	var env := 0.0
	for i in n:
		var t := float(i) / RATE
		var w := rng.randf_range(-1.0, 1.0)
		hi += 0.25 * (w - hi)
		lo += 0.04 * (w - lo)
		var syllab := maxf(0.0, sin(TAU * 2.7 * t) * sin(TAU * 0.9 * t + 0.6))
		var gate := 1.0 if sin(TAU * 0.23 * t) > -0.35 else 0.0
		env += 0.004 * (syllab * gate - env)
		s[i] = (hi - lo) * env * 3.0
	var fade := int(0.3 * RATE)
	for i in fade:
		var w2 := float(i) / fade
		s[i] = s[i] * w2 + s[n - fade + i] * (1.0 - w2)
	s.resize(n - fade)
	return _pack(s, true)


static func _pack(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var peak := 0.0001
	for v in samples:
		peak = maxf(peak, absf(v))
	var gain := 0.6 / peak
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i] * gain, -1, 1) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = bytes
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = samples.size()
	return wav
