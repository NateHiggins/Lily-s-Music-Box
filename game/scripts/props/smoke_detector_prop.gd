class_name SmokeDetectorProp
extends FunctionalProp
## Ceiling smoke detector: the low-battery chirp everyone ignores. Its
## ordinary function is annoyance; infection just makes the annoyance
## land on the downbeats.

var _chirp: AudioStreamPlayer3D


func _build_visual() -> void:
	make_box(Vector3(0.12, 0.03, 0.12), Vector3(0, -0.015, 0),
			Color(0.9, 0.89, 0.86))
	_chirp = make_emitter("tick", -14.0)
	_chirp.pitch_scale = 2.3
	_chirp.max_distance = 18.0


func _start_normal_function() -> void:
	state = PState.OPERATING
	_low_battery_loop()


func _low_battery_loop() -> void:
	while is_inside_tree():
		await get_tree().create_timer(rng.randf_range(50.0, 95.0), false).timeout
		if is_inside_tree() and state == PState.OPERATING:
			_chirp.play()


func _perform_synced_event(_index: int, accent: float, _pitch: float) -> void:
	if accent > 0.9:  # only the downbeats earn a chirp
		_chirp.play()
