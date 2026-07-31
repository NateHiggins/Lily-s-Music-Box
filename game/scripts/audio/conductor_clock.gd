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
## Always fires on the clock regardless of propagation mode — for UI and
## phone-side audio that listen to the *idea*, not to a building node.
signal motif_tick(event_index: int, accent: float, pitch: float)
## Continuous analysis from the authored viral seed. Systems which need
## envelopes rather than discrete knocks can listen without decoding audio.
signal viral_seed_frame(features: Dictionary)
signal viral_seed_state(active: bool)

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

## "network": motif events are injected at origin_node and travel the
## acoustic graph with real per-node delays (props hear them via
## AcousticGraphData.network_event). "global": legacy broadcast.
var propagation_mode := "network"
var origin_node := "B1_BOILER_01"

## Live motif (starts as MOTIF; the Interrupt outcome warps it).
var motif_events: Array = []
var motif_mutations := 0


func _ready() -> void:
	for ev in MOTIF:
		motif_events.append(ev.duplicate())


## The idea survives, damaged: timings wander inside tolerance, one accent
## inverts. Bodies keep interpreting whatever the motif has become.
func mutate_motif() -> void:
	motif_mutations += 1
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in range(1, motif_events.size()):
		motif_events[i].t = maxf(0.05, motif_events[i].t
				+ rng.randf_range(-0.05, 0.05))
	var j := rng.randi_range(1, motif_events.size() - 1)
	motif_events[j].accent = clampf(1.0 - motif_events[j].accent * 0.6, 0.2, 1.0)
	motif_events.sort_custom(func(a, b): return a.t < b.t)
	print("[CONDUCTOR] motif mutated (x%d)" % motif_mutations)

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
	while _motif_next < motif_events.size() \
			and _motif_t >= motif_events[_motif_next].t * scale:
		var ev: Dictionary = motif_events[_motif_next]
		motif_tick.emit(_motif_next, ev.accent, ev.pitch)
		if propagation_mode == "network":
			AcousticGraphData.propagate(origin_node, _motif_next,
					ev.accent, ev.pitch)
		else:
			motif_event.emit(_motif_next, ev.accent, ev.pitch)
		_motif_next += 1
	if not _gap_fired and _motif_t >= MOTIF_GAP_T * scale:
		_gap_fired = true
		motif_gap.emit(MOTIF.size())
	if _motif_t >= MOTIF_LOOP * scale:
		_motif_t = fmod(_motif_t, MOTIF_LOOP * scale)
		_motif_next = 0
		_gap_fired = false
