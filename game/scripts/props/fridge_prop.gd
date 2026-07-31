class_name FridgeProp
extends FunctionalProp
## Kitchen refrigerator. Normal: compressor hum cycling on/off on a slow
## thermostat. Synced: compressor relay clicks land on motif events.

var _hum: AudioStreamPlayer3D
var _click: AudioStreamPlayer3D
var _running := true


func _build_visual() -> void:
	## Rounded-shoulder 1950s refrigerator, matching the Blender library:
	## stepped crown, proud door face, vertical chrome handle, latch, badge.
	var body := Color(0.88, 0.87, 0.84)
	make_box(Vector3(0.60, 0.06, 0.58), Vector3(0, 0.03, 0),
			Color(0.09, 0.09, 0.09))                     # plinth
	make_box(Vector3(0.66, 1.46, 0.64), Vector3(0, 0.79, 0), body)
	make_box(Vector3(0.63, 0.08, 0.61), Vector3(0, 1.56, 0), body)
	make_box(Vector3(0.57, 0.06, 0.55), Vector3(0, 1.63, 0), body)
	make_box(Vector3(0.46, 0.04, 0.44), Vector3(0, 1.68, 0), body)
	make_box(Vector3(0.62, 1.40, 0.024), Vector3(0, 0.80, 0.332), body)
	make_box(Vector3(0.56, 1.32, 0.012), Vector3(0, 0.80, 0.351), body)
	make_cyl(0.016, 0.016, 0.46, Vector3(0.24, 0.95, 0.395),
			Color(0.80, 0.82, 0.85), 0.12, 1.0)          # chrome handle
	for hz in [0.74, 1.16]:
		make_box(Vector3(0.03, 0.02, 0.045), Vector3(0.24, hz, 0.375),
				Color(0.80, 0.82, 0.85))
	make_box(Vector3(0.08, 0.06, 0.05), Vector3(0.24, 0.96, 0.36),
			Color(0.80, 0.82, 0.85))                     # latch body
	make_box(Vector3(0.18, 0.06, 0.008), Vector3(0, 1.33, 0.358),
			Color(0.62, 0.55, 0.30))                     # maker's badge
	retexture(self, [
		[Color(0.88, 0.87, 0.84), "appliance", Color.WHITE],
		[Color(0.80, 0.82, 0.85), "chrome", Color.WHITE],
		[Color(0.62, 0.55, 0.30), "brass", Color.WHITE],
		[Color(0.09, 0.09, 0.09), "metal", Color(0.25, 0.25, 0.28)],
	])
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
