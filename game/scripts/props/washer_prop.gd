class_name WasherProp
extends FunctionalProp
## Basement laundry machine blockout. Normal: agitate loop cycling through
## phases. Synced: a drum thump lands on motif accents, and at high
## infection the agitation tempo locks to the conductor.

var _agitate: AudioStreamPlayer3D
var _thump: AudioStreamPlayer3D


func _build_visual() -> void:
	## Coin-laundry front-loader: enamel cabinet, chrome porthole with a
	## dark drum behind it, program dial, kick plate, hinged soap hatch.
	var enamel := Color(0.85, 0.85, 0.83)
	make_box(Vector3(0.68, 0.89, 0.68), Vector3(0, 0.505, 0), enamel)
	make_box(Vector3(0.68, 0.06, 0.68), Vector3(0, 0.03, 0),
			Color(0.22, 0.22, 0.24))                     # kick plate
	make_box(Vector3(0.68, 0.10, 0.66), Vector3(0, 1.00, -0.01), enamel)
	var ring := make_ring(0.155, 0.022, Vector3(0, 0.52, 0.345),
			Color(0.78, 0.80, 0.83), 0.15, 1.0)
	ring.rotation_degrees = Vector3(90, 0, 0)
	var glass := make_cyl(0.135, 0.145, 0.05, Vector3(0, 0.52, 0.335),
			Color(0.10, 0.11, 0.12), 0.1)
	glass.rotation_degrees = Vector3(90, 0, 0)
	var hinge := make_cyl(0.016, 0.016, 0.09, Vector3(-0.185, 0.52, 0.345),
			Color(0.78, 0.80, 0.83), 0.2, 1.0)
	hinge.rotation_degrees = Vector3(0, 0, 0)
	make_cyl(0.036, 0.036, 0.035, Vector3(0.21, 1.00, 0.26),
			Color(0.30, 0.30, 0.33), 0.35)               # program dial
	make_box(Vector3(0.012, 0.02, 0.05), Vector3(0.21, 1.035, 0.26),
			Color(0.9, 0.9, 0.88))                       # dial pointer
	make_box(Vector3(0.16, 0.035, 0.10), Vector3(-0.18, 1.005, 0.24),
			Color(0.75, 0.75, 0.72))                     # soap hatch
	retexture(self, [
		[Color(0.85, 0.85, 0.83), "enamel", Color.WHITE],
		[Color(0.78, 0.80, 0.83), "chrome", Color.WHITE],
		[Color(0.30, 0.30, 0.33), "bakelite", Color.WHITE],
		[Color(0.75, 0.75, 0.72), "enamel", Color(0.93, 0.93, 0.91)],
		[Color(0.22, 0.22, 0.24), "metal", Color(0.35, 0.35, 0.38)],
	])
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
