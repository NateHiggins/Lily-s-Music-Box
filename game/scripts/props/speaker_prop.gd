class_name SpeakerProp
extends FunctionalProp
## Juno's / Rhea's salvaged playback speakers. Normal: quiet program hiss.
## Synced: the cone thumps the motif — the most literal body in the
## building, which is exactly why Juno owns four of them.

var _thump: AudioStreamPlayer3D


## Optional looping ambience stream key, set from the marker.
var bed := ""


func _build_visual() -> void:
	if bed != "":
		var bed_p := make_emitter(bed, -24.0, true)
		if bed_p:
			bed_p.max_distance = 9.0
	## Studio monitor, salvage grade: veneer cabinet, real conical woofer
	## with dust cap, horn tweeter, bass port and one missing grille peg.
	make_box(Vector3(0.34, 0.55, 0.30), Vector3(0, 0.275, 0),
			Color(0.20, 0.14, 0.10))
	make_box(Vector3(0.30, 0.51, 0.015), Vector3(0, 0.275, 0.148),
			Color(0.10, 0.095, 0.09))                    # baffle
	var surround := make_ring(0.105, 0.014, Vector3(0, 0.36, 0.155),
			Color(0.16, 0.15, 0.14), 0.8)
	surround.rotation_degrees = Vector3(90, 0, 0)
	var cone := make_cyl(0.10, 0.028, 0.05, Vector3(0, 0.36, 0.135),
			Color(0.24, 0.23, 0.21), 0.85)
	cone.rotation_degrees = Vector3(-90, 0, 0)
	var cap := make_cyl(0.026, 0.020, 0.018, Vector3(0, 0.36, 0.158),
			Color(0.30, 0.29, 0.27), 0.5)
	cap.rotation_degrees = Vector3(-90, 0, 0)
	var horn := make_cyl(0.052, 0.016, 0.035, Vector3(0, 0.115, 0.152),
			Color(0.32, 0.31, 0.30), 0.4, 0.3)
	horn.rotation_degrees = Vector3(-90, 0, 0)
	var port := make_cyl(0.030, 0.030, 0.02, Vector3(0.09, 0.115, 0.152),
			Color(0.05, 0.05, 0.05), 0.9)
	port.rotation_degrees = Vector3(-90, 0, 0)
	for py in [0.08, 0.55]:
		make_cyl(0.006, 0.006, 0.012, Vector3(-0.13, py, 0.152),
				Color(0.5, 0.45, 0.3), 0.4, 0.5)         # grille pegs
	retexture(self, [
		[Color(0.20, 0.14, 0.10), "wood_dark", Color.WHITE],
		[Color(0.24, 0.23, 0.21), "paper", Color(0.58, 0.55, 0.50)],
		[Color(0.5, 0.45, 0.3), "brass", Color.WHITE],
		[Color(0.32, 0.31, 0.30), "bakelite", Color.WHITE],
	])
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
