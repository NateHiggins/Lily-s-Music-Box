class_name AudioFactory
extends RefCounted
## Synthesizes every sound in the prototype as AudioStreamWAV at startup.
## No recorded assets, no network — the project must run offline from a
## clean checkout. Streams are cached by key; TranslationProfile.timbre
## selects one. Peak levels are normalized so the master limiter is a
## safety net, not a crutch.

const RATE := 44100
const PEAK := 0.62  # normalized peak for all one-shots/loops (headroom for stacking)

static var _cache: Dictionary = {}


static func get_stream(key: String) -> AudioStreamWAV:
	if not _cache.has(key):
		_cache[key] = _build(key)
	return _cache[key]


static func _build(key: String) -> AudioStreamWAV:
	match key:
		"knock":
			return _knock()
		"tone":
			return _tone()
		"breath":
			return _breath()
		"vocal":
			return _vocal()
		"click":
			return _click()
		"hum_loop":
			return _hum_loop()
		"room_tone_loop":
			return _room_tone_loop()
		"murmur_loop":
			return _murmur_loop()
		"phone_static_loop":
			return _phone_static_loop()
		_:
			push_warning("AudioFactory: unknown timbre '%s', using tone" % key)
			return _tone()


## Metallic radiator impact: inharmonic decaying partials + a short noise
## transient. Inharmonicity is what reads as "pipe" instead of "drum".
static func _knock() -> AudioStreamWAV:
	var n := int(0.26 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var partials := [[167.0, 16.0, 1.0], [316.0, 22.0, 0.55], [521.0, 30.0, 0.35], [943.0, 44.0, 0.22]]
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for p in partials:
			v += p[2] * sin(TAU * p[0] * t) * exp(-p[1] * t)
		if t < 0.006:
			v += rng.randf_range(-1.0, 1.0) * (1.0 - t / 0.006) * 0.8
		s[i] = v
	return _pack(s)


## Clean digital notification tone (computer). Pitch contour is applied at
## playback via pitch_scale, so this is the neutral root.
static func _tone() -> AudioStreamWAV:
	var n := int(0.16 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		var env := minf(t / 0.008, 1.0) * exp(-11.0 * t)
		s[i] = env * (sin(TAU * 660.0 * t) + 0.35 * sin(TAU * 1320.0 * t))
	return _pack(s)


## Soft filtered noise burst — one exhalation-shaped push of air.
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
		var env := pow(sin(PI * t / 0.22), 1.6)
		s[i] = lp2 * env
	return _pack(s)


## Placeholder human hum: sine with vibrato and a little breathiness.
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
		var vib := 0.25 * sin(TAU * 5.4 * t)  # semitones of vibrato
		var f := 196.0 * pow(2.0, vib / 12.0)
		phase += TAU * f / RATE
		var w := rng.randf_range(-1.0, 1.0)
		lp += 0.08 * (w - lp)
		var env := minf(t / 0.05, 1.0) * minf((0.38 - t) / 0.12, 1.0)
		s[i] = env * (sin(phase) + 0.25 * sin(2.0 * phase) + 0.35 * lp)
	return _pack(s)


## Dry UI/interrupt tick.
static func _click() -> AudioStreamWAV:
	var n := int(0.05 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		s[i] = sin(TAU * 1900.0 * t) * exp(-90.0 * t)
	return _pack(s)


## Seamless mains-hum loop (50 Hz + harmonics; integer cycles per loop).
## The renderer modulates its volume/pitch live to express the motif.
static func _hum_loop() -> AudioStreamWAV:
	var dur := 2.0
	var n := int(dur * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		var wobble := 1.0 + 0.08 * sin(TAU * 1.0 * t)
		s[i] = wobble * (0.6 * sin(TAU * 50.0 * t) + 0.35 * sin(TAU * 100.0 * t) + 0.18 * sin(TAU * 150.0 * t))
	return _pack(s, true)


## Very quiet low rumble for the apartment.
static func _room_tone_loop() -> AudioStreamWAV:
	var n := int(4.0 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9001
	var brown := 0.0
	var lp := 0.0
	for i in n:
		brown = brown * 0.998 + rng.randf_range(-1.0, 1.0) * 0.02
		lp += 0.05 * (brown - lp)
		s[i] = lp * 8.0
	_loopify(s, int(0.25 * RATE))
	return _pack(s, true)


## Speech-shaped band noise: the caller's voice as heard through a bad line.
## Syllabic amplitude modulation sells "someone is talking" without words.
static func _murmur_loop() -> AudioStreamWAV:
	var n := int(6.0 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 555
	var lp_hi := 0.0
	var lp_lo := 0.0
	var env_s := 0.0
	for i in n:
		var t := float(i) / RATE
		var w := rng.randf_range(-1.0, 1.0)
		lp_hi += 0.25 * (w - lp_hi)   # ~2 kHz-ish
		lp_lo += 0.04 * (w - lp_lo)   # ~300 Hz-ish
		var band := lp_hi - lp_lo
		var syllab := maxf(0.0, sin(TAU * 2.7 * t) * sin(TAU * 0.9 * t + 0.6))
		var gate := 1.0 if sin(TAU * 0.23 * t) > -0.35 else 0.0
		env_s += 0.004 * (syllab * gate - env_s)
		s[i] = band * env_s * 3.0
	_loopify(s, int(0.3 * RATE))
	return _pack(s, true)


## Faint line hiss under the whole call.
static func _phone_static_loop() -> AudioStreamWAV:
	var n := int(3.0 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 31415
	var lp := 0.0
	for i in n:
		lp += 0.5 * (rng.randf_range(-1.0, 1.0) - lp)
		s[i] = lp
	_loopify(s, int(0.2 * RATE))
	return _pack(s, true)


## Crossfade the tail into the head so noise-based loops don't click.
static func _loopify(s: PackedFloat32Array, fade: int) -> void:
	var n := s.size()
	for i in fade:
		var w := float(i) / fade
		s[i] = s[i] * w + s[n - fade + i] * (1.0 - w)
	s.resize(n - fade)


static func _pack(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var peak := 0.0001
	for v in samples:
		peak = maxf(peak, absf(v))
	var gain := PEAK / peak
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var v := int(clampf(samples[i] * gain, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav
