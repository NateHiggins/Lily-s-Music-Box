class_name SpeakerProp
extends FunctionalProp
## Juno's / Rhea's salvaged playback speakers. Normal: quiet program hiss.
## Synced: the cone thumps the motif — the most literal body in the
## building, which is exactly why Juno owns four of them.

var _thump: AudioStreamPlayer3D


func _build_visual() -> void:
	make_box(Vector3(0.34, 0.55, 0.30), Vector3(0, 0.275, 0),
			Color(0.12, 0.11, 0.10))
	make_box(Vector3(0.24, 0.24, 0.02), Vector3(0, 0.36, 0.15),
			Color(0.20, 0.19, 0.18))  # woofer
	make_box(Vector3(0.10, 0.10, 0.02), Vector3(0, 0.12, 0.15),
			Color(0.22, 0.21, 0.20))  # tweeter
	var hiss := make_emitter("buzz_loop", -30.0, true)
	hiss.pitch_scale = 1.4
	_thump = make_emitter("knock", -12.0)
	_thump.pitch_scale = 0.5


func _start_normal_function() -> void:
	state = PState.OPERATING


func _perform_synced_event(_index: int, accent: float, pitch: float) -> void:
	_thump.volume_db = -12.0 + linear_to_db(clampf(accent, 0.2, 1.0))
	_thump.pitch_scale = clampf(0.5 * pow(2.0, pitch / 12.0), 0.35, 0.9)
	_thump.play()
