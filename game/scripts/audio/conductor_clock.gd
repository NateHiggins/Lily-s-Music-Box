extends Node
## Autoload "Conductor": the unseen conductor. Tracks BPM, beats, bars and
## the looping infection motif, and *requests* functional events from props
## via signals. It never animates transforms directly — every subscriber
## translates requests through its own mechanical limits (see
## FunctionalProp and prop_catalog.json).

signal beat(index: int)
signal bar(index: int)
signal motif_event(event_index: int, accent: float, pitch: float)
signal motif_gap(event_index: int)  # the implied-but-absent fifth event

const REF_BPM := 72.0
## incomplete_knock: short - short - pause - long - (missing), at 72 BPM.
const MOTIF := [
	{"t": 0.00, "accent": 1.00, "pitch": 0.0},
	{"t": 0.22, "accent": 0.55, "pitch": 3.0},
	{"t": 0.44, "accent": 0.55, "pitch": 2.0},
	{"t": 0.92, "accent": 0.85, "pitch": -2.0},
]
const MOTIF_GAP_T := 1.14
const MOTIF_LOOP := 1.90

var bpm := 72.0
var infection := 0.15:
	set(v):
		infection = clampf(v, 0.0, 1.0)
var timing_drift := 0.01

var _beat_acc := 0.0
var _beat_i := 0
var _motif_t := 0.0
var _motif_next := 0
var _gap_fired := false


func _process(delta: float) -> void:
	var beat_len := 60.0 / bpm
	_beat_acc += delta
	while _beat_acc >= beat_len:
		_beat_acc -= beat_len
		_beat_i += 1
		beat.emit(_beat_i)
		if _beat_i % 4 == 0:
			bar.emit(_beat_i / 4)

	var scale := REF_BPM / bpm
	_motif_t += delta
	while _motif_next < MOTIF.size() and _motif_t >= MOTIF[_motif_next].t * scale:
		var ev: Dictionary = MOTIF[_motif_next]
		motif_event.emit(_motif_next, ev.accent, ev.pitch)
		_motif_next += 1
	if not _gap_fired and _motif_t >= MOTIF_GAP_T * scale:
		_gap_fired = true
		motif_gap.emit(MOTIF.size())
	if _motif_t >= MOTIF_LOOP * scale:
		_motif_t = fmod(_motif_t, MOTIF_LOOP * scale)
		_motif_next = 0
		_gap_fired = false
