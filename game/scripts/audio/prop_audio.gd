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
