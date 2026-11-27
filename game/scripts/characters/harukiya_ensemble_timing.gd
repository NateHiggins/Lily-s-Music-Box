extends RefCounted
## Score-local cues. Sampling a frame never changes a resident's schedule or memory.
const PHRASE_REST := 1.5
const LOOK_AHEAD := .45
const RELEASE := .40

var lead_entries := PackedFloat64Array()
var harmony_entries := PackedFloat64Array()


func prepare(voices: Dictionary) -> void:
	lead_entries = _entries(voices.get("adela_voss", []))
	harmony_entries = _entries(voices.get("lily", []))


static func _entries(cues: Array) -> PackedFloat64Array:
	var entries := PackedFloat64Array()
	var previous_end := -INF
	for cue: Dictionary in cues:
		var at := float(cue.start)
		if at - previous_end >= PHRASE_REST:
			entries.append(at)
		previous_end = float(cue.end)
	return entries


func look_to_lead(performer: String, seconds: float) -> float:
	var entries: PackedFloat64Array
	if performer == "lily":
		entries = harmony_entries
	elif performer == "stacy":
		entries = lead_entries
	else:
		return 0.0
	var index := entries.bsearch(seconds + LOOK_AHEAD, false) - 1
	if index < 0:
		return 0.0
	var offset := seconds - entries[index]
	return smoothstep(-LOOK_AHEAD, -.16, offset) * (1.0 - smoothstep(.05, RELEASE, offset))


static func frame_seconds(frame: int, fps: int, duration: float) -> float:
	if fps <= 0:
		return 0.0
	return clampf(float(frame) / float(fps), 0.0, duration)


static func audible_seconds(last: float, position: float, since_mix: float, latency: float, duration: float) -> float:
	# Audio queries can straddle a mix boundary. Keep hand and mouth cues in order.
	return clampf(maxf(last, position + since_mix - latency), 0.0, duration)
