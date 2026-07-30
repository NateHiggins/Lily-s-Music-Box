class_name BoilerProp
extends FunctionalProp
## The basement boiler: the building's low-frequency register. Normal:
## continuous hum. Synced: deep pressure thuds — sparse, heavy, late.

var _thud: AudioStreamPlayer3D


func _build_visual() -> void:
	## Riveted vertical boiler: drum with band seams, domed crown, fire
	## door with dogged latch, pressure gauge, relief pipe and flue.
	var iron := Color(0.35, 0.30, 0.28)
	make_cyl(0.80, 0.84, 1.9, Vector3(0, 0.95, 0), iron, 0.55, 0.3)
	make_cyl(0.55, 0.80, 0.35, Vector3(0, 2.07, 0), iron, 0.55, 0.3)
	for bz in [0.45, 1.05, 1.65]:
		var band := make_ring(0.82, 0.018, Vector3(0, bz, 0),
				Color(0.28, 0.24, 0.22), 0.5, 0.4)
		band.rotation_degrees = Vector3(0, 0, 0)
	var door := make_cyl(0.24, 0.24, 0.10, Vector3(0, 0.62, -0.80),
			Color(0.24, 0.21, 0.19), 0.5, 0.4)
	door.rotation_degrees = Vector3(90, 0, 0)
	var dring := make_ring(0.27, 0.02, Vector3(0, 0.62, -0.78),
			Color(0.22, 0.19, 0.17), 0.5, 0.4)
	dring.rotation_degrees = Vector3(90, 0, 0)
	make_cyl(0.012, 0.012, 0.30, Vector3(0.22, 0.62, -0.83),
			Color(0.62, 0.55, 0.30), 0.35, 0.7).rotation_degrees = \
			Vector3(0, 0, 90)                            # latch bar
	var gauge := make_cyl(0.07, 0.07, 0.04, Vector3(0.45, 1.55, -0.72),
			Color(0.9, 0.9, 0.86), 0.2)
	gauge.rotation_degrees = Vector3(90, 0, 0)
	var gring := make_ring(0.075, 0.012, Vector3(0.45, 1.55, -0.71),
			Color(0.62, 0.55, 0.30), 0.3, 0.7)
	gring.rotation_degrees = Vector3(90, 0, 0)
	make_cyl(0.10, 0.10, 1.2, Vector3(0.55, 2.65, 0.30), iron, 0.5, 0.3)
	make_cyl(0.045, 0.045, 0.9, Vector3(-0.55, 2.45, -0.25),
			Color(0.30, 0.28, 0.27), 0.45, 0.4)          # relief pipe
	retexture(self, [
		[Color(0.35, 0.30, 0.28), "metal", Color(0.46, 0.41, 0.39), 0.7],
		[Color(0.28, 0.24, 0.22), "metal", Color(0.40, 0.36, 0.34), 0.7],
		[Color(0.24, 0.21, 0.19), "metal", Color(0.36, 0.33, 0.31)],
		[Color(0.22, 0.19, 0.17), "metal", Color(0.34, 0.31, 0.29)],
		[Color(0.62, 0.55, 0.30), "brass", Color.WHITE],
		[Color(0.9, 0.9, 0.86), "porcelain", Color.WHITE],
		[Color(0.30, 0.28, 0.27), "metal", Color(0.44, 0.42, 0.41)],
	])
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
