class_name BoilerProp
extends FunctionalProp
## The basement boiler: the building's low-frequency register. Normal:
## continuous hum. Synced: deep pressure thuds — sparse, heavy, late.

var _thud: AudioStreamPlayer3D


func _build_visual() -> void:
	make_box(Vector3(1.6, 1.9, 1.6), Vector3(0, 0.95, 0), Color(0.35, 0.3, 0.28))
	make_box(Vector3(0.2, 1.2, 0.2), Vector3(0.7, 2.4, 0), Color(0.3, 0.28, 0.27))
	var hum := make_emitter("hum_loop", -12.0, true)
	hum.max_distance = 40.0
	_thud = make_emitter("thud", -4.0)
	_thud.max_distance = 45.0


func _start_normal_function() -> void:
	state = PState.OPERATING


func _perform_synced_event(_index: int, accent: float, _pitch: float) -> void:
	_thud.volume_db = -6.0 + linear_to_db(clampf(accent, 0.3, 1.0))
	_thud.pitch_scale = rng.randf_range(0.9, 1.05)
	_thud.play()
