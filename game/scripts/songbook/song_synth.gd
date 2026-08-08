class_name SongSynth
extends RefCounted
## The backing track, synthesised at load.
##
## Per the audio invariant the Orison's sound is procedural unless it is
## a catalogued, attributed asset with a gitignored source — and the
## brief asks Phase 1 for an "instrumental placeholder" anyway. So this
## renders LAST TRAIN HOME rather than shipping a wav: 84 BPM, F minor,
## i–VI–III–VII, drum machine and fretless bass under a chorused
## electric piano, with the melody guide on a separate stream so it can
## be loud in previews and near-silent while somebody is actually
## singing (the brief is specific about that).
##
## Rendered one bar per chord and stitched, because four bars of
## synthesis and fifty-two array copies is fast and fifty-two bars of
## per-sample GDScript is not.
##
## PropAudio's rule — a missing sound is silence and a warning, never an
## invented test tone — is not in tension with this. That rule is about
## sound EFFECTS falling back to sine waves nobody authored. This is an
## authored arrangement that happens to be computed.

const RATE := 22050
const BPM := 84.0
const BEAT := 60.0 / BPM
const BAR := BEAT * 4.0

# F minor: i - VI - III - VII. [bass root, triad...]
const PROG := [
	{"bass": 87.31, "triad": [349.23, 415.30, 523.25]},   # Fm
	{"bass": 69.30, "triad": [277.18, 349.23, 415.30]},   # Db
	{"bass": 103.83, "triad": [415.30, 523.25, 622.25]},  # Ab
	{"bass": 77.78, "triad": [311.13, 392.00, 466.16]},   # Eb
]
# Which chord each bar of the 52-bar form sits on, and whether the
# section is playing full band. Intro and outro thin out; the bridge
# drops the drums, because a bridge that does not drop something is a
# chorus with different words.
const FORM_BARS := 52


static func _env(t: float, attack: float, decay: float) -> float:
	if t < attack:
		return t / maxf(0.0001, attack)
	return maxf(0.0, 1.0 - (t - attack) / maxf(0.0001, decay))


## One bar of backing for a given chord, at a given density.
static func _bar(chord: Dictionary, density: float,
		drums: bool) -> PackedFloat32Array:
	var n := int(BAR * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var bass_f: float = float(chord.bass)
	var triad: Array = chord.triad
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		# fretless bass: root, with a soft attack and a fifth-bar slide
		var be := _env(fmod(t, BEAT * 2.0), 0.02, BEAT * 1.9)
		v += sin(TAU * bass_f * t) * be * 0.34
		v += sin(TAU * bass_f * 2.0 * t) * be * 0.07
		# chorused electric piano: triad, two detuned voices
		var pe := _env(fmod(t, BEAT * 2.0), 0.012, BEAT * 1.8)
		for f in triad:
			var ff: float = float(f)
			v += sin(TAU * ff * t) * pe * 0.055 * density
			v += sin(TAU * ff * 1.004 * t + 0.7) * pe * 0.045 * density
		if drums:
			var b := fmod(t, BEAT)
			var beat_i := int(t / BEAT) % 4
			# kick on 1 and 3
			if beat_i == 0 or beat_i == 2:
				var ke := _env(b, 0.002, 0.16)
				v += sin(TAU * (52.0 + 40.0 * ke) * b) * ke * 0.55
			# clap on 2 and 4
			if beat_i == 1 or beat_i == 3:
				var ce := _env(b, 0.001, 0.10)
				v += (randf() * 2.0 - 1.0) * ce * 0.16
			# closed hat on eighths
			var h := fmod(t, BEAT * 0.5)
			var he := _env(h, 0.001, 0.035)
			v += (randf() * 2.0 - 1.0) * he * 0.05
		out[i] = clampf(v, -1.0, 1.0)
	return out


## The melody guide: a restrained digital bell on the phrase contour, so
## a first-timer has something to aim at. Separate stream, separate bus.
static func _guide_bar(chord: Dictionary) -> PackedFloat32Array:
	var n := int(BAR * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var triad: Array = chord.triad
	for i in n:
		var t := float(i) / RATE
		var step := int(t / BEAT) % 4
		var f: float = float(triad[step % triad.size()])
		var e := _env(fmod(t, BEAT), 0.004, BEAT * 0.85)
		var v := sin(TAU * f * t) * e * 0.22
		v += sin(TAU * f * 2.0 * t) * e * 0.06
		out[i] = clampf(v, -1.0, 1.0)
	return out


static func _to_wav(frames: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(frames.size() * 2)
	for i in frames.size():
		var s := int(clampf(frames[i], -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, s)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	return wav


## Returns {backing, guide} — two AudioStreamWAVs of identical length.
static func render() -> Dictionary:
	var bars: Array[PackedFloat32Array] = []
	var guides: Array[PackedFloat32Array] = []
	for c in PROG:
		bars.append(_bar(c, 1.0, true))
		guides.append(_guide_bar(c))
	var thin: Array[PackedFloat32Array] = []
	for c in PROG:
		thin.append(_bar(c, 0.55, false))
	var back := PackedFloat32Array()
	var guide := PackedFloat32Array()
	for b in FORM_BARS:
		var chord := b % 4
		# intro (0-3), bridge (36-39) and outro (48-51) drop the kit
		var sparse: bool = b < 4 or (b >= 36 and b < 40) or b >= 48
		back.append_array(thin[chord] if sparse else bars[chord])
		guide.append_array(guides[chord])
	return {"backing": _to_wav(back), "guide": _to_wav(guide),
			"length": float(FORM_BARS) * BAR}
