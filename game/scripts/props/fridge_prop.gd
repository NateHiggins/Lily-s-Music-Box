class_name FridgeProp
extends FunctionalProp
## Kitchen refrigerator. Normal: compressor hum cycling on/off on a slow
## thermostat. Synced: compressor relay clicks land on motif events.

var _hum: AudioStreamPlayer3D
var _click: AudioStreamPlayer3D
var _running := true


func _build_visual() -> void:
	make_box(Vector3(0.72, 1.70, 0.70), Vector3(0, 0.85, 0),
			Color(0.88, 0.87, 0.84))
	make_box(Vector3(0.72, 0.02, 0.70), Vector3(0, 1.14, 0),
			Color(0.6, 0.6, 0.58))  # door split
	make_box(Vector3(0.03, 0.30, 0.04), Vector3(0.34, 1.35, 0.36),
			Color(0.55, 0.55, 0.52))  # handle
	_hum = make_emitter("hum_loop", -22.0, true)
	_click = make_emitter("tick", -12.0)


func _start_normal_function() -> void:
	state = PState.OPERATING
	_thermostat_loop()


func _thermostat_loop() -> void:
	while is_inside_tree():
		await get_tree().create_timer(rng.randf_range(35.0, 80.0), false).timeout
		if not is_inside_tree():
			return
		_running = not _running
		_click.pitch_scale = 0.9
		_click.play()
		create_tween().tween_property(_hum, "volume_db",
				-22.0 if _running else -50.0, 1.2)


func _perform_synced_event(_index: int, accent: float, _pitch: float) -> void:
	_click.pitch_scale = rng.randf_range(0.85, 0.95)
	_click.volume_db = -14.0 + linear_to_db(clampf(accent, 0.2, 1.0))
	_click.play()
	if not _running:
		_running = true
		create_tween().tween_property(_hum, "volume_db", -22.0, 0.6)
