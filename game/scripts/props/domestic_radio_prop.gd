class_name DomesticRadioProp
extends FunctionalProp
## One domestic receiver, configured from domestic_radios.json. The profile
## chooses a historically grounded silhouette; this prop owns only its local
## switch, tuning pose and bounded programme murmur. It neither originates nor
## routes the building's broadcast and writes no persistence.

const WOOD := Color(0.22, 0.105, 0.045)
const DARK_WOOD := Color(0.105, 0.052, 0.028)
const BLACK := Color(0.035, 0.038, 0.040)
const BRASS := Color(0.55, 0.39, 0.16)
const CLOTH := Color(0.30, 0.245, 0.17)
const PAPER := Color(0.72, 0.61, 0.43)

var radio_profile: Dictionary = {}
var unit := ""
var family := ""
var powered := false
var tuning := 0.42
var _tuning_knob: Node3D
var _dial: MeshInstance3D
var _programme: AudioStreamPlayer3D


func configure(spec: Dictionary) -> void:
	radio_profile = spec.duplicate(true)
	unit = str(spec.get("unit", ""))
	family = str(spec.get("family", "three_dial_battery"))
	name = "DomesticRadio_%s" % unit
	prop_type = "speaker"
	set_meta("unit", unit)
	set_meta("radio_family", family)
	set_meta("radio_condition", str(spec.get("condition", "serviceable")))


func _build_visual() -> void:
	match family:
		"crosley_pup": _build_pup()
		"atwater_kent_44": _build_metal_ac()
		"marconiphone_v2": _build_mahogany_receiver()
		"crystal_set": _build_crystal()
		"radiola_table": _build_radio_table()
		"homebrew_regenerative": _build_homebrew()
		"portable_four_valve": _build_portable()
		_: _build_three_dial()
	_build_speaker(str(radio_profile.get("speaker", "cone")))
	_programme = make_emitter("murmur_loop", -31.0)
	_programme.max_distance = 5.5
	_programme.unit_size = 1.2
	_programme.stop()


func _start_normal_function() -> void:
	state = PState.OFF


func interact_prompt() -> String:
	return "[E] Switch %s's wireless %s" % [unit, "off" if powered else "on"]


func interact(_actor: Node = null) -> Dictionary:
	powered = not powered
	state = PState.OPERATING if powered else PState.OFF
	if _programme != null:
		if powered:
			_programme.play()
		else:
			_programme.stop()
	if _tuning_knob != null:
		_tuning_knob.rotation.z = -0.48 if powered else 0.0
	return {"action":"radio_power", "unit":unit, "powered":powered,
			"family":family}


func _perform_synced_event(_index: int, accent: float, pitch: float) -> void:
	if not powered:
		return
	tuning = fposmod(tuning + 0.07 + accent * 0.03, 1.0)
	if _tuning_knob != null:
		_tuning_knob.rotation.z = lerpf(-0.75, 0.75, tuning)
	if _programme != null:
		_programme.pitch_scale = clampf(1.0 + pitch * 0.012, 0.82, 1.18)


func public_state() -> Dictionary:
	return {"unit":unit, "family":family, "powered":powered,
			"tuning":tuning, "reach":5.5}


func _build_three_dial() -> void:
	make_box(Vector3(0.48, 0.23, 0.24), Vector3(0, 0.115, 0), WOOD)
	make_box(Vector3(0.44, 0.18, 0.012), Vector3(0, 0.13, -0.126), BLACK)
	for x in [-0.145, 0.0, 0.145]:
		_dial_face(x, 0.155, -0.136, 0.052)
	_knob(-0.14, 0.075, -0.142)
	_knob(0.14, 0.075, -0.142)


func _build_pup() -> void:
	make_box(Vector3(0.18, 0.19, 0.13), Vector3(0, 0.095, 0), BLACK)
	_dial_face(0, 0.115, -0.071, 0.055)
	_knob(-0.052, 0.048, -0.077)
	_knob(0.052, 0.048, -0.077)
	make_cyl(0.023, 0.023, 0.075, Vector3(0, 0.235, 0), Color(0.12, 0.12, 0.11), 0.30)


func _build_metal_ac() -> void:
	make_box(Vector3(0.55, 0.19, 0.27), Vector3(0, 0.095, 0), BLACK)
	make_box(Vector3(0.48, 0.115, 0.010), Vector3(0, 0.105, -0.141), Color(0.085, 0.09, 0.09))
	make_box(Vector3(0.31, 0.040, 0.008), Vector3(0, 0.135, -0.148), PAPER)
	_knob(-0.19, 0.063, -0.149)
	_knob(0.19, 0.063, -0.149)
	_knob(0, 0.063, -0.149)


func _build_mahogany_receiver() -> void:
	make_box(Vector3(0.45, 0.24, 0.28), Vector3(0, 0.12, 0), DARK_WOOD)
	make_box(Vector3(0.39, 0.18, 0.012), Vector3(0, 0.135, -0.146), BLACK)
	for x in [-0.12, 0.0, 0.12]:
		_dial_face(x, 0.145, -0.154, 0.045)
	_knob(-0.12, 0.062, -0.158)
	_knob(0.12, 0.062, -0.158)


func _build_crystal() -> void:
	make_box(Vector3(0.34, 0.055, 0.23), Vector3(0, 0.028, 0), WOOD)
	# Ebonite tuner block, binding posts and the exposed cat's-whisker arm are
	# the silhouette. A crystal set is not merely a very small cabinet radio.
	make_box(Vector3(0.17, 0.11, 0.12), Vector3(-0.055, 0.105, 0), BLACK)
	_dial_face(-0.055, 0.115, -0.066, 0.043)
	for x in [-0.145, 0.115, 0.155]:
		make_cyl(0.013, 0.013, 0.045, Vector3(x, 0.09, 0.07), BRASS, 0.30)
	var detector := Node3D.new()
	detector.position = Vector3(0.095, 0.075, -0.025)
	add_child(detector)
	var arm := make_box(Vector3(0.012, 0.18, 0.012), Vector3.ZERO, BRASS)
	remove_child(arm); detector.add_child(arm); arm.position.y = 0.09
	detector.rotation.z = -0.55
	make_cyl(0.027, 0.027, 0.042, Vector3(0.145, 0.075, -0.025),
			Color(0.36, 0.22, 0.10), 0.45)


func _build_homebrew() -> void:
	make_box(Vector3(0.50, 0.045, 0.29), Vector3(0, 0.023, 0), WOOD)
	make_box(Vector3(0.47, 0.19, 0.030), Vector3(0, 0.125, -0.115), BLACK)
	for x in [-0.14, 0, 0.14]:
		_dial_face(x, 0.145, -0.135, 0.047)
		# Exposed valve envelopes make Juno's altered chassis readable even at
		# apartment distance; the dark bases keep them mechanical, not candles.
		make_cyl(0.025, 0.021, 0.085, Vector3(x, 0.105, 0.055),
				Color(0.28, 0.20, 0.13), 0.16)
		make_cyl(0.031, 0.031, 0.025, Vector3(x, 0.065, 0.055), BLACK, 0.32)
	for x in [-0.19, 0.19]:
		make_cyl(0.009, 0.009, 0.045, Vector3(x, 0.065, 0.08), BRASS, 0.30)
	for i in 7:
		var turn := make_ring(0.060, 0.006, Vector3(-0.205,
				0.065 + i * 0.012, 0.0), BRASS, 0.25, 0.90)
		turn.rotation.z = PI * 0.5


func _build_portable() -> void:
	make_box(Vector3(0.39, 0.25, 0.18), Vector3(0, 0.125, 0), Color(0.085, 0.055, 0.035))
	make_box(Vector3(0.35, 0.19, 0.012), Vector3(0, 0.13, -0.101), CLOTH)
	make_box(Vector3(0.20, 0.025, 0.025), Vector3(0, 0.285, 0), BRASS)
	make_box(Vector3(0.025, 0.065, 0.025), Vector3(-0.10, 0.265, 0), BRASS)
	make_box(Vector3(0.025, 0.065, 0.025), Vector3(0.10, 0.265, 0), BRASS)
	_knob(-0.13, 0.065, -0.111)
	_knob(0.13, 0.065, -0.111)


func _build_radio_table() -> void:
	make_box(Vector3(0.58, 0.33, 0.25), Vector3(0, 0.165, 0), WOOD)
	make_box(Vector3(0.50, 0.19, 0.012), Vector3(0, 0.215, -0.131), CLOTH)
	make_box(Vector3(0.42, 0.052, 0.009), Vector3(0, 0.085, -0.137), PAPER)
	_knob(-0.18, 0.055, -0.143)
	_knob(0.18, 0.055, -0.143)


func _build_speaker(kind: String) -> void:
	if kind in ["headphones", "amplifier_patch", "integrated_table", "lid_speaker"]:
		if kind == "headphones":
			make_cyl(0.065, 0.065, 0.012, Vector3(0.22, 0.035, 0), BLACK, 0.35)
		return
	if kind.contains("horn"):
		var horn := make_cyl(0.16, 0.055, 0.23, Vector3(0.37, 0.22, 0), BRASS, 0.42)
		horn.rotation.x = PI * 0.5
	if kind.contains("cone") or kind == "cone":
		var cone := make_cyl(0.15, 0.035, 0.055, Vector3(-0.38, 0.20, -0.02), CLOTH, 0.65)
		cone.rotation.x = PI * 0.5


func _dial_face(x: float, y: float, z: float, radius: float) -> void:
	var face := make_cyl(radius, radius, 0.010, Vector3(x, y, z), PAPER, 0.60)
	face.rotation.x = PI * 0.5


func _knob(x: float, y: float, z: float) -> void:
	var pivot := Node3D.new()
	pivot.position = Vector3(x, y, z)
	add_child(pivot)
	var knob := make_cyl(0.022, 0.022, 0.025, Vector3.ZERO, BLACK, 0.28)
	remove_child(knob)
	pivot.add_child(knob)
	knob.rotation.x = PI * 0.5
	if _tuning_knob == null:
		_tuning_knob = pivot
