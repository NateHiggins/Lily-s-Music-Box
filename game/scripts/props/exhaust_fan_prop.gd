class_name ExhaustFanProp
extends FunctionalProp
## Bathroom ceiling exhaust fan: tired little whir that wavers with the
## motif when the building is listening.

var _whir: AudioStreamPlayer3D


func _build_visual() -> void:
	make_box(Vector3(0.28, 0.04, 0.28), Vector3(0, -0.02, 0),
			Color(0.85, 0.85, 0.82))
	make_box(Vector3(0.20, 0.02, 0.20), Vector3(0, -0.045, 0),
			Color(0.4, 0.4, 0.42))
	_whir = make_emitter("buzz_loop", -30.0, true)
	_whir.pitch_scale = 1.15
	_whir.max_distance = 10.0


func _start_normal_function() -> void:
	state = PState.OPERATING


func _perform_synced_event(_index: int, accent: float, _pitch: float) -> void:
	_whir.pitch_scale = 1.15 + accent * 0.25
	create_tween().tween_property(_whir, "pitch_scale", 1.15, 0.4)
