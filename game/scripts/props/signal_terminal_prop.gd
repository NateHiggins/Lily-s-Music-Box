class_name SignalTerminalProp
extends FunctionalProp
## THE VANTRY REMOTE SIGNAL DESK in 4B.
##
## The marker id keeps the old MONITOR token because it is a binding key: the
## call runner, acoustic graph and virus director already address
## F04_B_MONITOR_01. The semantic kind is separate so five ordinary character
## displays cannot inherit this unique machine again. Visually it is a
## compact receiver/transmitter built into a second-hand oak radio cabinet:
## valves and a cathode scope because signal technology diverged, stamped
## brass, Bakelite and cloth cable because everything around the signal did not.
##
## Gameplay verbs remain outside this prop in CallInterface. This is their
## physical witness: scope = isolate, meter pair = capture, patch field = route,
## amber annunciator = a person waiting on the line.

var _screen_mats: Array[StandardMaterial3D] = []
var _valve_mat: StandardMaterial3D
var _scope_mat: StandardMaterial3D
var _line_mat: StandardMaterial3D
var _incoming_label: Label3D
var _meter_needles: Array[Node3D] = []
var _stage := "idle"


func _build_visual() -> void:
	var fixed := Node3D.new()
	fixed.name = "FixedInstrument"
	add_child(fixed)
	var oak := smat("wood_dark", Color(0.48, 0.38, 0.28), 0.65)
	var brass := smat("brass_dull", Color(0.72, 0.66, 0.52), 0.55)
	var black := smat("bakelite_black", Color(0.62, 0.60, 0.56), 0.42)
	var nickel := smat("nickel_plated", Color(0.55, 0.53, 0.48), 0.55)
	var copper := smat("copper_aged", Color(0.52, 0.47, 0.42), 0.40)

	# The desk is only 580 mm deep. A 380 mm cabinet leaves a real wrist rest
	# and keeps the worker's chair from becoming collision furniture.
	_box(fixed, Vector3(0.38, 0.27, 1.02), Vector3(0, 0.135, 0), oak)
	_box(fixed, Vector3(0.018, 0.225, 0.94), Vector3(0.199, 0.142, 0), brass)
	_box(fixed, Vector3(0.40, 0.035, 1.06), Vector3(-0.01, 0.018, 0), black)
	# Upper ventilated bridge: the valves are behind a guard, not decorative
	# laboratory glass standing loose where a hurried hand can break them.
	_box(fixed, Vector3(0.25, 0.055, 0.62), Vector3(-0.055, 0.315, 0), oak)
	for z in [-0.27, -0.18, 0.18, 0.27]:
		var rail := make_cyl(0.008, 0.008, 0.28,
				Vector3(0.08, 0.385, z), Color.WHITE, 0.5, 0.2, fixed)
		rail.rotation_degrees = Vector3(0, 0, 90)
		rail.material_override = nickel

	# Scope bezel at left, two moving-coil meters above the patch field.
	var bezel := make_ring(0.116, 0.013, Vector3(0.211, 0.165, -0.255),
			Color.WHITE, 0.45, 0.25, fixed)
	bezel.rotation_degrees = Vector3(0, 0, 90)
	bezel.material_override = nickel
	for z in [0.045, 0.265]:
		_box(fixed, Vector3(0.015, 0.115, 0.175),
				Vector3(0.211, 0.190, z), black)
		_box(fixed, Vector3(0.008, 0.090, 0.145),
				Vector3(0.220, 0.192, z), brass)
	# Tuning and gain knobs. Their unequal diameters make the jobs readable
	# by touch and silhouette, without a generated word or modern icon.
	for spec in [[0.030, -0.405], [0.041, -0.035], [0.030, 0.420]]:
		var knob := make_cyl(spec[0], spec[0] * 0.94, 0.035,
				Vector3(0.225, 0.078, spec[1]), Color.WHITE, 0.36, 0.0, fixed)
		knob.rotation_degrees = Vector3(0, 0, 90)
		knob.material_override = black
	# Six sockets, three occupied: a physical route diagram the player learns
	# before the UI ever asks them to push a captured rhythm into the building.
	_box(fixed, Vector3(0.014, 0.090, 0.35),
			Vector3(0.211, 0.065, 0.215), black)
	for i in 6:
		var jack := make_cyl(0.012, 0.012, 0.020,
				Vector3(0.225, 0.065, 0.075 + i * 0.057),
				Color.WHITE, 0.40, 0.25, fixed)
		jack.rotation_degrees = Vector3(0, 0, 90)
		jack.material_override = copper
	# Carbon handset on a cradle along the cabinet's right shoulder.
	_box(fixed, Vector3(0.08, 0.055, 0.29),
			Vector3(-0.02, 0.315, 0.43), black)
	for z in [0.31, 0.55]:
		var cup := make_cyl(0.050, 0.043, 0.058,
				Vector3(-0.02, 0.315, z), Color.WHITE, 0.38, 0.0, fixed)
		cup.rotation_degrees = Vector3(90, 0, 0)
		cup.material_override = black

	# All fixed primitives collapse to one draw per real finish. The old twin
	# monitors cost fourteen individual boxes and cylinders before their glow.
	merge_static(fixed)

	_build_scope()
	_build_meters()
	_build_valves()
	_build_annunciator()
	var pool := OmniLight3D.new()
	pool.name = "ScopePool"
	pool.light_color = Color(0.38, 0.68, 0.55)
	pool.light_energy = 0.24
	pool.omni_range = 1.65
	pool.omni_attenuation = 2.1
	pool.shadow_enabled = false
	pool.position = Vector3(0.30, 0.20, -0.18)
	add_child(pool)


func _box(parent: Node3D, size: Vector3, at: Vector3,
		mat: StandardMaterial3D) -> MeshInstance3D:
	var mesh := make_box(size, at, Color.WHITE)
	mesh.material_override = mat
	mesh.reparent(parent)
	return mesh


func _build_scope() -> void:
	_scope_mat = StandardMaterial3D.new()
	_scope_mat.albedo_color = Color(0.015, 0.035, 0.025)
	_scope_mat.roughness = 0.24
	_scope_mat.emission_enabled = true
	_scope_mat.emission = Color(0.17, 0.62, 0.39)
	_scope_mat.emission_energy_multiplier = 0.55
	var glass := make_cyl(0.098, 0.098, 0.012,
			Vector3(0.224, 0.165, -0.255), Color.WHITE, 0.2)
	glass.name = "SignalScope"
	glass.rotation_degrees = Vector3(0, 0, 90)
	glass.material_override = _scope_mat
	_screen_mats.append(_scope_mat)


func _build_meters() -> void:
	for z in [0.045, 0.265]:
		var pivot := Node3D.new()
		pivot.name = "MeterNeedle"
		pivot.position = Vector3(0.228, 0.165, z)
		add_child(pivot)
		var needle := make_box(Vector3(0.008, 0.070, 0.008),
				Vector3.ZERO, Color(0.20, 0.045, 0.025))
		needle.position.y = 0.032
		needle.reparent(pivot)
		pivot.rotation.x = -0.38
		_meter_needles.append(pivot)


func _build_valves() -> void:
	var bank := Node3D.new()
	bank.name = "ValveBank"
	add_child(bank)
	_valve_mat = StandardMaterial3D.new()
	_valve_mat.albedo_color = Color(0.24, 0.18, 0.12, 0.72)
	_valve_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_valve_mat.roughness = 0.22
	_valve_mat.emission_enabled = true
	_valve_mat.emission = Color(0.82, 0.25, 0.06)
	_valve_mat.emission_energy_multiplier = 0.22
	for z in [-0.20, 0.0, 0.20]:
		var valve := make_cyl(0.026, 0.032, 0.125,
				Vector3(0.02, 0.385, z), Color.WHITE, 0.24, 0.0, bank)
		valve.material_override = _valve_mat
	merge_static(bank)


func _build_annunciator() -> void:
	_line_mat = StandardMaterial3D.new()
	_line_mat.albedo_color = Color(0.16, 0.07, 0.02)
	_line_mat.emission_enabled = true
	_line_mat.emission = Color(1.0, 0.36, 0.06)
	_line_mat.emission_energy_multiplier = 0.12
	var lamp := make_cyl(0.018, 0.018, 0.018,
			Vector3(0.226, 0.070, -0.365), Color.WHITE, 0.25)
	lamp.name = "LineAnnunciator"
	lamp.rotation_degrees = Vector3(0, 0, 90)
	lamp.material_override = _line_mat


func _start_normal_function() -> void:
	state = PState.OPERATING


func set_console_stage(next: String) -> void:
	_stage = next
	var scope_energy: float = float({"idle": 0.45, "call": 0.72, "isolate": 1.05,
			"capture": 1.30, "route": 1.55, "response": 1.05,
			"outcome": 0.60, "incoming": 1.65}.get(next, 0.55))
	_scope_mat.emission_energy_multiplier = scope_energy
	_line_mat.emission_energy_multiplier = 1.6 if next in ["incoming", "call"] \
			else 0.12
	var targets: Array = {
		"idle": [-0.38, -0.38], "call": [-0.18, -0.30],
		"isolate": [0.10, -0.18], "capture": [0.38, 0.15],
		"route": [0.62, 0.42], "response": [0.18, 0.62],
		"outcome": [-0.05, -0.08], "incoming": [0.52, 0.22],
	}.get(next, [-0.38, -0.38])
	for i in _meter_needles.size():
		create_tween().tween_property(_meter_needles[i], "rotation:x",
				float(targets[i]), 0.22)


func _perform_synced_event(_index: int, accent: float, _pitch: float) -> void:
	var base := _scope_mat.emission_energy_multiplier
	_scope_mat.emission_energy_multiplier = base + accent * 0.85
	_valve_mat.emission_energy_multiplier = 0.22 + accent * 0.42
	if Conductor.infection > 0.7:
		_scope_mat.emission = Color(0.18, 0.90, 0.70)
	create_tween().tween_property(_scope_mat, "emission_energy_multiplier",
			base, 0.24)
	create_tween().tween_property(_valve_mat, "emission_energy_multiplier",
			0.22, 0.32)


func show_incoming_call() -> void:
	set_console_stage("incoming")
	if _incoming_label == null:
		_incoming_label = Label3D.new()
		_incoming_label.name = "IncomingCallAlert"
		_incoming_label.text = "LINE REQUEST\nM. CHEN"
		_incoming_label.font_size = 32
		_incoming_label.pixel_size = 0.00115
		_incoming_label.modulate = Color(0.66, 1.0, 0.78)
		_incoming_label.outline_modulate = Color(0.005, 0.02, 0.01)
		_incoming_label.outline_size = 8
		_incoming_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_incoming_label.position = Vector3(0.233, 0.165, -0.255)
		_incoming_label.rotation.y = -PI / 2.0
		_incoming_label.double_sided = false
		add_child(_incoming_label)
	_incoming_label.visible = true
