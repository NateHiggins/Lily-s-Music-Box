class_name WasherProp
extends FunctionalProp
## Basement laundry machine blockout. Normal: agitate loop cycling through
## phases. Synced: a drum thump lands on motif accents, and at high
## infection the agitation tempo locks to the conductor.

var _agitate: AudioStreamPlayer3D
var _thump: AudioStreamPlayer3D


func _build_visual() -> void:
	make_box(Vector3(0.68, 0.95, 0.68), Vector3(0, 0.475, 0), Color(0.85, 0.85, 0.83))
	make_box(Vector3(0.5, 0.06, 0.5), Vector3(0, 0.98, 0), Color(0.4, 0.4, 0.42))
	_agitate = make_emitter("agitate_loop", -14.0, prop_type == "washer")
	_thump = make_emitter("thud", -10.0)


func _start_normal_function() -> void:
	state = PState.OPERATING


func _perform_synced_event(_index: int, accent: float, _pitch: float) -> void:
	_thump.volume_db = -12.0 + linear_to_db(clampf(accent, 0.2, 1.0))
	_thump.play()
	if Conductor.infection > 0.6 and _agitate.playing:
		# drum reversal rate drifts toward the conductor's tempo
		_agitate.pitch_scale = clampf(Conductor.bpm / 72.0, 0.7, 1.4)
