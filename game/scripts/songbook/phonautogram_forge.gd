class_name PhonautogramForge
extends RefCounted
## The traces that were already here, synthesised rather than recorded.
##
## ORISON_BIBLE III.2 G4: **the oldest traces have no author.** Something sang
## into the horn before anyone currently alive, and the building cannot tell you
## who. That is a fiction problem with an implementation to match - there IS no
## recording of these, because there was never a recording of anything. A
## phonautogram is a LINE, and every sound anyone ever gets from one is a
## reconstruction somebody computed from a picture.
##
## So this forge does what First Sounds did in 2008, minus the paper: it takes a
## trace's identity, derives the shape of a line from it, and turns that line
## into a pressure wave. Two people reading the same trace get the same line and
## therefore the same voice - the line is the only thing that is real - while the
## SPEED they read it at is still guessed fresh, so they may not agree on who it
## was. See PhonautogramReader. This class forges FOUND traces only; the
## 2026-08-14 owner correction gives player-made community versions one
## immutable, too-fast reconstruction instead.
##
## Nothing here tries to sound like a good recording. It is a voice the way a
## graph is a voice: a fundamental, a couple of formants that wander, breath, and
## the fact that whoever it was ran out of air in places.

const RATE := 22050
## Traces already in the building when the player arrives. Every one of them is
## a question with no answer in the bar - the label is what is written on the
## sleeve in pencil, and the pencil is not evidence of anything.
const FOUND := {
	"trace_room0": {
		"label": "no sleeve. found behind the pipes.",
		"seconds": 7.0, "root": 196.0, "breath": 0.30, "air": 0.55,
	},
	"trace_1610": {
		"label": "sleeve reads: WORS, and a date that has been rubbed out.",
		"seconds": 9.0, "root": 233.0, "breath": 0.22, "air": 0.75,
	},
	"trace_two_voices": {
		"label": "sleeve reads: for M. there is more than one person on it.",
		"seconds": 8.0, "root": 175.0, "breath": 0.34, "air": 0.40,
	},
	"trace_unlabelled": {
		"label": "no sleeve, no pencil, no date.",
		"seconds": 6.0, "root": 262.0, "breath": 0.18, "air": 0.85,
	},
}


## Build the wave a trace's line describes. Deterministic: the line is the only
## real thing, so the same id always yields the same voice.
static func forge(trace_id: String) -> AudioStreamWAV:
	var spec: Dictionary = FOUND.get(trace_id, {
		"seconds": 6.0, "root": 210.0, "breath": 0.25, "air": 0.6,
	})
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(trace_id)

	var seconds: float = float(spec["seconds"])
	var root: float = float(spec["root"])
	var breath: float = float(spec["breath"])
	var air: float = float(spec["air"])
	var count := int(RATE * seconds)

	# The contour: a handful of held notes, because whoever it was was singing
	# and not talking. Intervals are small - this is somebody's own tune, not a
	# scale anyone would recognise.
	var steps: Array[float] = []
	var here := 0.0
	for i in 9:
		steps.append(here)
		here += float([-2, -1, 0, 1, 2, 3][rng.randi() % 6])
		here = clampf(here, -4.0, 7.0)

	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	var f2_phase := 0.0
	var f3_phase := 0.0
	for i in count:
		var t := float(i) / float(RATE)
		var progress := t / seconds
		var note: float = steps[clampi(int(progress * steps.size()), 0,
				steps.size() - 1)]
		var freq: float = root * pow(2.0, note / 12.0)
		# Nobody holds a note flat. Vibrato, plus a slow sag as the breath goes.
		freq *= 1.0 + sin(t * 5.1) * 0.011
		freq *= 1.0 - fposmod(t, 2.6) / 2.6 * 0.018

		phase += TAU * freq / float(RATE)
		f2_phase += TAU * freq * 2.6 / float(RATE)
		f3_phase += TAU * freq * 4.1 / float(RATE)

		# A voice is a fundamental somebody is mostly not hearing and two
		# resonances they are. The formants wander because a mouth is not a
		# filter with a knob on it.
		var v := sin(phase) * 0.55
		v += sin(f2_phase) * 0.30 * (0.6 + 0.4 * sin(t * 0.9))
		v += sin(f3_phase) * 0.16 * (0.5 + 0.5 * sin(t * 1.4 + 2.0))
		# Breath, which is most of what survives on a bad trace.
		v += (rng.randf() * 2.0 - 1.0) * breath * 0.22

		# THEY RAN OUT OF AIR. A phrase envelope that does not quite make it to
		# the end of each line, because one person sang this in one take with no
		# way to hear it back and no reason to think anybody ever would.
		var phrase := fposmod(t, 2.6) / 2.6
		var env: float = smoothstep(0.0, 0.06, phrase) * (1.0 - smoothstep(air, 1.0, phrase))
		# And the whole thing fades at the ends of the cylinder.
		env *= smoothstep(0.0, 0.35, t) * (1.0 - smoothstep(seconds - 0.5, seconds, t))

		var s := int(clampf(v * env * 22000.0, -32000.0, 32000.0))
		data[i * 2] = s & 0xFF
		data[i * 2 + 1] = (s >> 8) & 0xFF

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav


## What is written on the sleeve, which is not the same as what is on the trace.
static func label_of(trace_id: String) -> String:
	var spec: Dictionary = FOUND.get(trace_id, {})
	return str(spec.get("label", "no sleeve."))


static func found_ids() -> Array:
	return FOUND.keys()
