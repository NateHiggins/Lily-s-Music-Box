class_name ToasterProp
extends FunctionalProp
## Waters-Genter's 1926 Toastmaster Model 1-A-1: the new, expensive
## automatic toaster a New Yorker could actually buy in 1927. It is a
## single-slice nickel-plated machine with a mechanical clockwork timer,
## not the late-1970s two-slot box this prop used to be.
##
## The sliding crumb pan is deliberately NOT represented as factory work.
## The 1-A-1 had no pull-out tray. This thin folded pan is an Orison service
## retrofit under the pressed base: historically honest, visibly homemade,
## and a stable physical handle for the archaeology activity.

signal crumb_tray_changed(open: bool)

const LEVER_TRAVEL := 0.046
const TRAY_TRAVEL := 0.160
const LEVER_HOME_X := 0.137

const NICKEL := Color(0.72, 0.70, 0.66)
const BAKELITE := Color(0.141, 0.125, 0.114)
const CORD := Color(0.56, 0.35, 0.27)
const MICA := Color(0.58, 0.36, 0.12)
const GREASE := Color(0.22, 0.16, 0.09)
const CRUMB := Color(0.52, 0.29, 0.09)
const BURNT := Color(0.10, 0.055, 0.025)

var unit := ""
# Standard runs expose local -Z to the cook. 4B turns the toaster across
# its short worktop, so its superintendent-made pan exits the open end
# instead. This is set before _ready(), and therefore before the handle is
# built; rotating a finished tray would make its 215 mm pan cross the case.
var tray_axis := Vector3(0, 0, -1)
var _lever: Node3D
var _carriage: Node3D
var _crumb_tray: Node3D
var _tray_tween: Tween
var _tray_open := false
var _coil_mat: StandardMaterial3D
var _hum: AudioStreamPlayer3D
var _click: AudioStreamPlayer3D
var _pop: AudioStreamPlayer3D
var _release_on_next_event := false
var cycles_completed := 0
var _busy_tween: Tween


func _build_visual() -> void:
	var fixed := Node3D.new()
	fixed.name = "StaticCase"
	add_child(fixed)
	_build_case(fixed)
	_build_heater_cards(fixed)
	_build_controls(fixed)
	_build_carriage()
	_build_retrofit_tray()

	retexture(self, [
		[NICKEL, "nickel_plated", Color(0.94, 0.92, 0.86), 0.75],
		[BAKELITE, "bakelite_black", Color(0.82, 0.78, 0.72), 0.75],
		[CORD, "fabric_warm", Color(0.62, 0.48, 0.40), 0.35],
		[MICA, "mica_heater", Color(0.86, 0.73, 0.52), 0.45],
		[GREASE, "fx_grease", Color(0.42, 0.30, 0.18), 0.45],
	])
	# Casework is fixed; the carrier, lever and service pan must remain
	# separate because the hand and the director move them independently.
	merge_static(fixed)
	merge_static(_carriage)
	merge_static(_crumb_tray)

	_hum = make_emitter("hum_loop", -60.0, true)
	_click = make_emitter("tick", -10.0)
	_pop = make_emitter("pop", -8.0)
	var area := Area3D.new()
	area.name = "Interaction"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.30, 0.23, 0.22)
	shape.shape = box
	shape.position = Vector3(0, 0.11, 0.025)
	area.add_child(shape)
	add_child(area)


func _build_case(parent: Node3D) -> void:
	# The Henry Ford's measured 1-A-1 is 10.125 x 4.75 x 7.375 inches.
	# Feet and plate share that 187 mm total height; inflating the body to
	# the old 190 mm and then adding feet made it subtly too tall on a 900 mm
	# counter, exactly where the five-foot player's eye catches the error.
	for x in [-0.105, 0.105]:
		for z in [-0.045, 0.045]:
			_cyl_on(parent, 0.012, 0.014, 0.012,
					Vector3(x, 0.006, z), BAKELITE)
	_box_on(parent, Vector3(0.257, 0.012, 0.121),
			Vector3(0, 0.018, 0), NICKEL)
	_box_on(parent, Vector3(0.249, 0.132, 0.006),
			Vector3(0, 0.090, -0.0575), NICKEL)
	_box_on(parent, Vector3(0.249, 0.132, 0.006),
			Vector3(0, 0.090, 0.0575), NICKEL)
	_box_on(parent, Vector3(0.006, 0.132, 0.109),
			Vector3(-0.1215, 0.090, 0), NICKEL)
	_box_on(parent, Vector3(0.006, 0.132, 0.109),
			Vector3(0.1215, 0.090, 0), NICKEL)

	# Three stepped folds stand in for the pressed aerodynamic shoulder.
	# A single flat lid made the previous toaster read as a modern shoebox;
	# the narrowing courses put the 1920s silhouette back at room distance.
	for course in [
		[0.153, 0.249, 0.105],
		[0.162, 0.239, 0.086],
		[0.170, 0.226, 0.064],
	]:
		var y: float = course[0]
		var w: float = course[1]
		var d: float = course[2]
		_box_on(parent, Vector3(w, 0.008, (d - 0.026) * 0.5),
				Vector3(0, y, -(d + 0.026) * 0.25), NICKEL)
		_box_on(parent, Vector3(w, 0.008, (d - 0.026) * 0.5),
				Vector3(0, y, (d + 0.026) * 0.25), NICKEL)
	# One longitudinal slot, 210 x 20 mm. The raised lip is not decorative:
	# it keeps hand-cut bread away from the hot plated shell.
	_box_on(parent, Vector3(0.218, 0.009, 0.006),
			Vector3(0, 0.178, -0.013), NICKEL)
	_box_on(parent, Vector3(0.218, 0.009, 0.006),
			Vector3(0, 0.178, 0.013), NICKEL)
	for x in [-0.109, 0.109]:
		_box_on(parent, Vector3(0.006, 0.009, 0.032),
				Vector3(x, 0.178, 0), NICKEL)

	# Vent slots are recessed shadow, not black paint. A full Boolean cut is
	# wasted on a 12 cm appliance, but setting these cards behind the skin
	# gives the sidewalls real depth under the warehouse's flat light.
	for side in [-1.0, 1.0]:
		for row in 5:
			_box_on(parent, Vector3(0.176, 0.006, 0.003),
					Vector3(0, 0.060 + row * 0.016,
						side * 0.061), BAKELITE)
	# Pressed seams and corner screws keep the plated shell from becoming a
	# featureless mirror when its material catches a dark kitchen.
	for side in [-1.0, 1.0]:
		for x in [-0.104, 0.104]:
			var screw := _cyl_on(parent, 0.004, 0.004, 0.003,
					Vector3(x, 0.043, side * 0.0615), NICKEL)
			screw.rotation_degrees.x = 90.0

	# A short braided cord is enough to establish period construction. It
	# coils behind the case instead of pretending every kitchen outlet is at
	# the same local coordinate.
	_tube_between(parent, Vector3(-0.105, 0.032, -0.058),
			Vector3(-0.145, 0.022, -0.090), 0.006, CORD)
	_tube_between(parent, Vector3(-0.145, 0.022, -0.090),
			Vector3(-0.105, 0.018, -0.115), 0.006, CORD)
	_box_on(parent, Vector3(0.034, 0.018, 0.024),
			Vector3(-0.090, 0.018, -0.120), BAKELITE)
	for x in [-0.097, -0.083]:
		var pin := _cyl_on(parent, 0.002, 0.002, 0.018,
				Vector3(x, 0.018, -0.140), NICKEL)
		pin.rotation_degrees.x = 90.0


func _build_heater_cards(parent: Node3D) -> void:
	# Patent 1,698,146 specifies paired mica sheets with resistance wire
	# wrapped through their holes. The mica carries the new material; the
	# wire stays geometry so its glow can pulse without brightening the card.
	for z in [-0.034, 0.034]:
		_box_on(parent, Vector3(0.190, 0.098, 0.004),
				Vector3(0, 0.100, z), MICA)
	_coil_mat = StandardMaterial3D.new()
	_coil_mat.albedo_color = Color(0.09, 0.025, 0.012)
	_coil_mat.roughness = 0.62
	_coil_mat.emission_enabled = true
	_coil_mat.emission = Color(1.0, 0.22, 0.025)
	_coil_mat.emission_energy_multiplier = 0.0
	var glow := Node3D.new()
	glow.name = "ResistanceWire"
	add_child(glow)
	for z in [-0.037, 0.037]:
		for row in 7:
			var wire := _box_on(glow, Vector3(0.176, 0.003, 0.0025),
					Vector3(0, 0.067 + row * 0.012, z), BURNT)
			wire.material_override = _coil_mat
	merge_static(glow)


func _build_controls(parent: Node3D) -> void:
	# The patent has two jobs at opposite ends: the switch/carriage lever and
	# a clockwork timing lever with an adjustable stop. A modern rotary shade
	# dial was the wrong mechanism as well as the wrong decade.
	_lever = Node3D.new()
	_lever.name = "CarriageLever"
	_lever.position = Vector3(LEVER_HOME_X, 0.137, 0.002)
	add_child(_lever)
	_box_on(_lever, Vector3(0.034, 0.015, 0.026), Vector3.ZERO, BAKELITE)
	var lever_pin := _cyl_on(_lever, 0.006, 0.006, 0.018,
			Vector3(-0.018, 0, 0), NICKEL)
	lever_pin.rotation_degrees.z = 90.0

	_box_on(parent, Vector3(0.004, 0.078, 0.016),
			Vector3(-0.126, 0.103, 0.002), BAKELITE)
	_box_on(parent, Vector3(0.026, 0.014, 0.025),
			Vector3(-0.137, 0.121, 0.002), BAKELITE)
	for notch in 5:
		_box_on(parent, Vector3(0.004, 0.003, 0.025),
				Vector3(-0.128, 0.076 + notch * 0.013, 0.002), NICKEL)


func _build_carriage() -> void:
	_carriage = Node3D.new()
	_carriage.name = "BreadCarrier"
	_carriage.position = Vector3(0, 0.151, 0)
	add_child(_carriage)
	_box_on(_carriage, Vector3(0.188, 0.006, 0.025), Vector3.ZERO, NICKEL)
	for x in [-0.084, -0.042, 0.0, 0.042, 0.084]:
		_tube_between(_carriage, Vector3(x, -0.010, -0.020),
				Vector3(x, 0.026, 0.020), 0.0025, NICKEL)


func _build_retrofit_tray() -> void:
	_crumb_tray = Node3D.new()
	_crumb_tray.name = "OrisonRetrofitCrumbTray"
	_crumb_tray.position = Vector3(0, 0.027, 0)
	add_child(_crumb_tray)
	_box_on(_crumb_tray, Vector3(0.215, 0.005, 0.105),
			Vector3.ZERO, NICKEL)
	_box_on(_crumb_tray, Vector3(0.215, 0.012, 0.005),
			Vector3(0, 0.006, -0.050), NICKEL)
	_box_on(_crumb_tray, Vector3(0.215, 0.012, 0.005),
			Vector3(0, 0.006, 0.050), NICKEL)
	for x in [-0.105, 0.105]:
		_box_on(_crumb_tray, Vector3(0.005, 0.012, 0.100),
				Vector3(x, 0.006, 0), NICKEL)
	# Folded strip and mismatched pull: the whole point is that this pan came
	# from a superintendent's bench, not the Waters-Genter stamping line.
	if absf(tray_axis.x) > 0.5:
		var side := signf(tray_axis.x)
		_box_on(_crumb_tray, Vector3(0.010, 0.020, 0.082),
				Vector3(side * 0.112, 0.004, 0), NICKEL)
		_box_on(_crumb_tray, Vector3(0.016, 0.015, 0.038),
				Vector3(side * 0.121, 0.007, 0), BAKELITE)
	else:
		var front := signf(tray_axis.z)
		_box_on(_crumb_tray, Vector3(0.082, 0.020, 0.010),
				Vector3(0, 0.004, front * 0.058), NICKEL)
		_box_on(_crumb_tray, Vector3(0.038, 0.015, 0.016),
				Vector3(0, 0.007, front * 0.067), BAKELITE)
	_box_on(_crumb_tray, Vector3(0.120, 0.0015, 0.060),
			Vector3(-0.022, 0.004, -0.006), GREASE)

	# Deterministic per household. Fourteen identical crumb constellations
	# would make the retrofit feel stamped out, which it explicitly was not.
	var crumbs_rng := RandomNumberGenerator.new()
	crumbs_rng.seed = absi(hash(unit if unit != "" else "warehouse"))
	for i in 18:
		var sx := crumbs_rng.randf_range(0.005, 0.014)
		var sz := crumbs_rng.randf_range(0.004, 0.011)
		var crumb := _box_on(_crumb_tray,
				Vector3(sx, crumbs_rng.randf_range(0.002, 0.005), sz),
				Vector3(crumbs_rng.randf_range(-0.088, 0.088),
						0.006, crumbs_rng.randf_range(-0.038, 0.038)),
				BURNT if i % 7 == 0 else CRUMB)
		crumb.rotation.y = crumbs_rng.randf_range(-PI, PI)


func _box_on(parent: Node3D, size: Vector3, at: Vector3,
		color: Color) -> MeshInstance3D:
	var node := make_box(size, at, color)
	remove_child(node)
	parent.add_child(node)
	node.position = at
	return node


func _cyl_on(parent: Node3D, rt: float, rb: float, height: float,
		at: Vector3, color: Color) -> MeshInstance3D:
	return make_cyl(rt, rb, height, at, color, 0.55, 0.0, parent)


func _tube_between(parent: Node3D, a: Vector3, b: Vector3, radius: float,
		color: Color) -> MeshInstance3D:
	var delta := b - a
	var tube := _cyl_on(parent, radius, radius, delta.length(),
			(a + b) * 0.5, color)
	var direction := delta.normalized()
	var dot := Vector3.UP.dot(direction)
	if dot < -0.9999:
		tube.rotation_degrees.x = 180.0
	elif dot < 0.9999:
		tube.quaternion = Quaternion(Vector3.UP, direction)
	return tube


func interact_prompt() -> String:
	return "[E]  Press the carriage lever" if state == PState.IDLE \
			else "[E]  Test the latched carriage"


func interact(_player: Node) -> Dictionary:
	if state == PState.IDLE:
		start_cycle()
	else:
		_busy_response()
	return service_wire_card()


func service_wire_card() -> Dictionary:
	var carriage := "RAISED"
	var elements := "COLD"
	match state:
		PState.STARTING:
			carriage = "DESCENDING"
			elements = "ENERGIZING"
		PState.OPERATING:
			carriage = "LATCHED"
			elements = "HEATING"
		PState.COMPLETING:
			carriage = "RELEASING"
			elements = "COOLING"
		PState.FAULT:
			carriage = "HELD"
			elements = "FAULT"
	return PropServiceWire.card("toaster", {
		"carriage_state": carriage,
		"element_state": elements,
	})


func _busy_response() -> void:
	if _click:
		_click.pitch_scale = 0.72
		_click.play()
	if _busy_tween:
		_busy_tween.kill()
	# A repeated impatient hand cannot ratchet the lever sideways by killing a
	# previous response tween at its extreme.
	_lever.position.x = LEVER_HOME_X
	_busy_tween = create_tween()
	_busy_tween.tween_property(_lever, "position:x", LEVER_HOME_X - 0.004, 0.045)
	_busy_tween.tween_property(_lever, "position:x", LEVER_HOME_X + 0.003, 0.045)
	_busy_tween.tween_property(_lever, "position:x", LEVER_HOME_X, 0.06)


func _start_normal_function() -> void:
	state = PState.IDLE


func start_cycle() -> void:
	if state != PState.IDLE:
		return
	state = PState.STARTING
	print("[TOASTER] %s cycle start" % name)
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_CUBIC)
	tw.set_ease(Tween.EASE_IN)
	tw.tween_property(_lever, "position:y", 0.137 - LEVER_TRAVEL, 0.16)
	tw.parallel().tween_property(_carriage, "position:y", 0.064, 0.16)
	tw.tween_callback(_latched)


func _latched() -> void:
	_click.pitch_scale = 1.0
	_click.play()
	state = PState.OPERATING
	create_tween().tween_property(_hum, "volume_db", -28.0, 0.4)
	create_tween().tween_property(_coil_mat,
			"emission_energy_multiplier", 2.2, 1.4)
	var browning := get_tree().create_timer(5.0, false)
	browning.timeout.connect(_request_release)


func _request_release() -> void:
	if state != PState.OPERATING:
		return
	# At meaningful infection the clockwork waits for the conductor's next
	# event. The toaster still performs its normal function; it keeps time
	# with something else now.
	if Conductor.infection > 0.4:
		_release_on_next_event = true
	else:
		_release()


func _release() -> void:
	if state != PState.OPERATING:
		return
	state = PState.COMPLETING
	_release_on_next_event = false
	_click.pitch_scale = 0.8
	_click.play()
	create_tween().tween_property(_coil_mat,
			"emission_energy_multiplier", 0.0, 0.8)
	create_tween().tween_property(_hum, "volume_db", -60.0, 0.4)
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_BACK)
	tw.set_ease(Tween.EASE_OUT)
	tw.tween_property(_carriage, "position:y", 0.164, 0.075)
	tw.parallel().tween_property(_lever, "position:y", 0.141, 0.075)
	tw.tween_property(_carriage, "position:y", 0.151, 0.12)
	tw.parallel().tween_property(_lever, "position:y", 0.137, 0.12)
	tw.tween_callback(_cycle_done)
	_pop.play()


func _cycle_done() -> void:
	state = PState.IDLE
	cycles_completed += 1
	print("[TOASTER] %s pop (%d cycles)" % [name, cycles_completed])


## Stable maintenance API for the archaeology activity and inspection rig.
## It does not hijack the normal E interaction: the minigame owns when the
## player has been told to pull the retrofit rather than make toast.
func set_crumb_tray_open(open: bool, seconds := 0.35) -> void:
	if _crumb_tray == null:
		return
	_tray_open = open
	if _tray_tween and _tray_tween.is_valid():
		_tray_tween.kill()
	var target := Vector3(0, 0.027, 0) + \
			(tray_axis.normalized() * TRAY_TRAVEL if open else Vector3.ZERO)
	if seconds <= 0.0:
		_crumb_tray.position = target
		crumb_tray_changed.emit(open)
		return
	_tray_tween = create_tween()
	_tray_tween.set_trans(Tween.TRANS_CUBIC)
	_tray_tween.set_ease(Tween.EASE_OUT if open else Tween.EASE_IN)
	_tray_tween.tween_property(_crumb_tray, "position", target, seconds)
	_tray_tween.tween_callback(func(): crumb_tray_changed.emit(open))


func is_crumb_tray_open() -> bool:
	return _tray_open


func _perform_synced_event(_index: int, accent: float, _pitch: float) -> void:
	if _release_on_next_event:
		_release()
		return
	if state == PState.OPERATING:
		_coil_mat.emission_energy_multiplier = 2.2 + accent * 1.6
		create_tween().tween_property(_coil_mat,
				"emission_energy_multiplier", 2.2, 0.25)
	elif state == PState.IDLE:
		_click.pitch_scale = 1.15
		_click.volume_db = -16.0 + linear_to_db(clampf(accent, 0.2, 1.0))
		_click.play()
