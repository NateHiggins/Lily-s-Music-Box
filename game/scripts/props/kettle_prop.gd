class_name KettleProp
extends FunctionalProp
## A c.1925 GE/Hotpoint electric kettle: a formed metal vessel with an
## exposed heating well, detachable cloth lead and a chained whistle cap.
## It is not a modern cordless jug in an old colour. Electric kettles and
## kettle whistles both predate the Orison; no divergence is needed here.
##
## Six households share the mechanism but not the biography. The finish is
## selected before _ready(), while all service motion stays on the prop so a
## later work order never has to replace dressing with a second kettle.

signal lid_changed(open: bool)
signal whistle_changed(open: bool)

const BODY_NICKEL := Color(0.72, 0.70, 0.66)
const BODY_COPPER := Color(0.55, 0.31, 0.18)
const BAKELITE := Color(0.141, 0.125, 0.114)
const RUBBER := Color(0.20, 0.18, 0.16)
const WOOD := Color(0.27, 0.15, 0.08)
const BRASS := Color(0.48, 0.37, 0.19)
const MINERAL := Color(0.62, 0.61, 0.52)

var unit := ""
var case_id := ""
var heat_time := 22.0  # tests shorten the water, not the animation
var cycles_completed := 0

var _vessel: Node3D
var _lid: Node3D
var _whistle_cap: Node3D
var _steam: GPUParticles3D
var _hum: AudioStreamPlayer3D
var _whistle: AudioStreamPlayer3D
var _click: AudioStreamPlayer3D
var _body_color := BODY_NICKEL
var _cycle_generation := 0
var _whistle_on_next := false
var _lid_open := false
var _whistle_open := false
var _lifted := false


func warehouse_variants() -> Array[Dictionary]:
	return [
		{"label": "kettle · polished nickel", "properties": {"unit": "1A"}},
		{"label": "kettle · aged copper", "properties": {"unit": "3D"}},
	]


func _build_visual() -> void:
	_body_color = BODY_COPPER if unit in ["3D", "4C", "6C"] else BODY_NICKEL
	_vessel = Node3D.new()
	_vessel.name = "Vessel"
	add_child(_vessel)

	var fixed := Node3D.new()
	fixed.name = "StaticVessel"
	_vessel.add_child(fixed)
	_build_vessel(fixed)
	_build_bail_and_lead(fixed)
	_build_lid()
	_build_whistle()
	_build_water(fixed)

	retexture(self, [
		[BODY_NICKEL, "nickel_plated", _nickel_tint(), 0.72],
		[BODY_COPPER, "copper_aged", _copper_tint(), 0.72],
		[BAKELITE, "bakelite_black", _bakelite_tint(), 0.70],
		[RUBBER, "rubber_aged", Color(0.42, 0.39, 0.35), 0.55],
		[WOOD, "wood_dark", Color(0.48, 0.31, 0.18), 0.55],
		[BRASS, "brass_dull", Color(0.72, 0.58, 0.32), 0.55],
		[MINERAL, "enamel", Color(0.58, 0.60, 0.55), 0.48],
	])
	# Four fixed finishes + two lid finishes + one whistle + one water/mineral
	# surface is the hard eight-mesh contract. Every primitive below those
	# owners is collapsed only after it has its runtime texture.
	merge_static(fixed)
	merge_static(_lid)
	merge_static(_whistle_cap)

	_build_steam()
	_build_service_anchors()
	_hum = make_emitter("hum_loop", -60.0, true)
	_hum.pitch_scale = 1.28
	_whistle = make_emitter("whistle_loop", -60.0)
	_whistle.max_distance = 30.0
	_click = make_emitter("tick", -13.0)


func _build_vessel(parent: Node3D) -> void:
	# The museum example is 170 mm across and 250 mm overall. This body stays
	# at 180 mm: 4B has 50 mm to its crosswise toaster and no more to lend us.
	_cyl_on(parent, 0.074, 0.079, 0.018, Vector3(0, 0.009, 0), _body_color)
	_cyl_on(parent, 0.090, 0.078, 0.055, Vector3(0, 0.045, 0), _body_color)
	_cyl_on(parent, 0.090, 0.090, 0.070, Vector3(0, 0.1075, 0), _body_color)
	_cyl_on(parent, 0.062, 0.090, 0.050, Vector3(0, 0.1675, 0), _body_color)
	_cyl_on(parent, 0.061, 0.061, 0.020, Vector3(0, 0.2025, 0), _body_color)
	make_ring(0.082, 0.004, Vector3(0, 0.075, 0), _body_color, 0.4, 0.5, parent)
	make_ring(0.063, 0.004, Vector3(0, 0.196, 0), _body_color, 0.4, 0.5, parent)

	# Three short cones read as a soldered tapered spout instead of the old
	# rectangular block. It points toward local -Z, the cook-facing side.
	_tube_between(parent, Vector3(0, 0.145, -0.068),
			Vector3(0, 0.165, -0.118), 0.027, _body_color)
	_tube_between(parent, Vector3(0, 0.165, -0.116),
			Vector3(0, 0.192, -0.158), 0.022, _body_color)
	_tube_between(parent, Vector3(0, 0.192, -0.157),
			Vector3(0, 0.207, -0.184), 0.018, _body_color)

	# The visible heating well and side terminal are the period mechanism.
	_cyl_on(parent, 0.071, 0.071, 0.018, Vector3(0, 0.022, 0), _body_color)
	_box_on(parent, Vector3(0.052, 0.035, 0.030),
			Vector3(0.073, 0.048, 0.020), BAKELITE)
	for x in [-0.046, 0.046]:
		_cyl_on(parent, 0.010, 0.012, 0.014, Vector3(x, 0.007, 0.0), BAKELITE)
	# Teresa's long use is inside the vessel: a waterline, not generic dirt
	# painted over every exterior surface.
	if unit == "1D":
		make_ring(0.053, 0.004, Vector3(0, 0.199, 0), MINERAL,
				0.75, 0.0, parent)
	# A shallow deterministic dent breaks only the households who would keep
	# a damaged vessel. It shares the body finish, so costs no extra draw.
	if unit in ["1D", "4B", "4C"]:
		_cyl_on(parent, 0.013, 0.017, 0.003,
				Vector3(0.079, 0.112, 0.018), _body_color).rotation_degrees.z = 90.0


func _build_bail_and_lead(parent: Node3D) -> void:
	# Brass ears carry a wooden bail. Five straight pieces are a deliberate
	# low-poly steam-bent arc: clear silhouette, no cloth or cable physics.
	for x in [-0.073, 0.073]:
		_cyl_on(parent, 0.010, 0.010, 0.025,
				Vector3(x, 0.165, 0), _body_color).rotation_degrees.z = 90.0
	var points := [
		Vector3(-0.082, 0.168, 0), Vector3(-0.078, 0.235, 0),
		Vector3(-0.040, 0.272, 0), Vector3(0.040, 0.272, 0),
		Vector3(0.078, 0.235, 0), Vector3(0.082, 0.168, 0)]
	for i in points.size() - 1:
		_tube_between(parent, points[i], points[i + 1], 0.008, WOOD)

	# A short detachable lead coils behind the kettle rather than claiming a
	# universal outlet position. The terminal block and plug are Bakelite.
	_tube_between(parent, Vector3(0.084, 0.045, 0.022),
			Vector3(0.120, 0.025, 0.060), 0.006, RUBBER)
	_tube_between(parent, Vector3(0.120, 0.025, 0.060),
			Vector3(0.087, 0.016, 0.105), 0.006, RUBBER)
	_box_on(parent, Vector3(0.038, 0.020, 0.026),
			Vector3(0.075, 0.018, 0.117), BAKELITE)
	for x in [0.067, 0.083]:
		var pin := _cyl_on(parent, 0.002, 0.002, 0.018,
				Vector3(x, 0.018, 0.137), BAKELITE)
		pin.rotation_degrees.x = 90.0


func _build_lid() -> void:
	_lid = Node3D.new()
	_lid.name = "Lid"
	_lid.position = Vector3(0, 0.213, 0.055)  # back-edge hinge for service pose
	_vessel.add_child(_lid)
	_cyl_on(_lid, 0.052, 0.060, 0.014,
			Vector3(0, 0.007, -0.055), _body_color)
	make_ring(0.057, 0.003, Vector3(0, 0.002, -0.055),
			_body_color, 0.45, 0.5, _lid)
	# Teresa's replacement knob is the wrong squat hexagonal shape. It remains
	# Bakelite, but its proportions say repair without inventing a new finish.
	var knob_radius := 0.018 if unit == "1D" else 0.013
	_cyl_on(_lid, knob_radius, knob_radius * 0.82, 0.026,
			Vector3(0, 0.028, -0.055), BAKELITE)


func _build_whistle() -> void:
	_whistle_cap = Node3D.new()
	_whistle_cap.name = "ChainedWhistleCap"
	_whistle_cap.position = Vector3(0, 0.207, -0.184)
	_vessel.add_child(_whistle_cap)
	var cap := _cyl_on(_whistle_cap, 0.020, 0.020, 0.027,
			Vector3.ZERO, BRASS)
	cap.rotation_degrees.x = 90.0
	make_ring(0.020, 0.003, Vector3(0, 0, -0.013), BRASS,
			0.65, 0.3, _whistle_cap).rotation_degrees.x = 90.0
	# The chain is coarse enough to survive room distance and shares one
	# material/draw with the cap. Its slight droop makes "chained" legible.
	var chain := [Vector3(0.018, -0.002, 0), Vector3(0.029, -0.020, 0.008),
		Vector3(0.021, -0.041, 0.017), Vector3(0.006, -0.055, 0.022)]
	for i in chain.size() - 1:
		_tube_between(_whistle_cap, chain[i], chain[i + 1], 0.002, BRASS)


func _build_water(parent: Node3D) -> void:
	# A mineral-grey disc sits just below the neck. With the lid shut it is
	# invisible; in service pose it supplies the depth cue the old solid box
	# could never have.
	_cyl_on(parent, 0.052, 0.052, 0.002,
			Vector3(0, 0.198, 0), MINERAL)


func _build_steam() -> void:
	_steam = GPUParticles3D.new()
	_steam.name = "Steam"
	_steam.position = Vector3(0, 0.216, -0.205)
	_steam.amount = 7
	_steam.lifetime = 1.35
	_steam.visibility_aabb = AABB(Vector3(-0.25, -0.05, -0.25),
			Vector3(0.5, 0.75, 0.5))
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0, 1, 0)
	process.initial_velocity_min = 0.16
	process.initial_velocity_max = 0.28
	process.gravity = Vector3(0, 0.05, 0)
	process.scale_min = 0.035
	process.scale_max = 0.075
	_steam.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2(0.07, 0.07)
	var steam_mat := StandardMaterial3D.new()
	steam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	steam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	steam_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	steam_mat.albedo_color = Color(0.78, 0.80, 0.76, 0.18)
	quad.material = steam_mat
	_steam.draw_pass_1 = quad
	_steam.emitting = false
	_vessel.add_child(_steam)


func _build_service_anchors() -> void:
	# One interaction volume is enough physics. Named marker anchors keep the
	# four service reaches auditable without adding eight collision objects to
	# every kettle on a frame already limited by scene submission.
	var area := Area3D.new()
	area.name = "Interaction"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.30, 0.32, 0.36)
	shape.shape = box
	shape.position = Vector3(0, 0.15, -0.035)
	area.add_child(shape)
	add_child(area)
	for spec in [
		["HandleReach", Vector3(0, 0.272, 0)],
		["LidReach", Vector3(0, 0.235, -0.055)],
		["WhistleReach", Vector3(0, 0.207, -0.205)],
		["PlugReach", Vector3(0.075, 0.035, 0.135)],
	]:
		var anchor := Marker3D.new()
		anchor.name = spec[0]
		anchor.position = spec[1]
		add_child(anchor)


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


func _nickel_tint() -> Color:
	if unit == "1A":
		return Color(1.0, 0.98, 0.92)
	if unit == "1D":
		return Color(0.52, 0.51, 0.48)  # never polished, twice boiled daily
	if unit == "4B":
		return Color(0.70, 0.68, 0.62)
	return Color(0.84, 0.82, 0.76)


func _copper_tint() -> Color:
	if unit == "6C":
		return Color(0.82, 0.60, 0.38)  # old but deliberately maintained
	if unit == "4C":
		return Color(0.55, 0.39, 0.28)  # shared object, handled hard
	return Color(0.72, 0.48, 0.29)


func _bakelite_tint() -> Color:
	return Color(0.48, 0.34, 0.23) if unit == "1D" else Color(0.75, 0.68, 0.58)


func interact_prompt() -> String:
	if state == PState.IDLE:
		return "[E]  Put the kettle on"
	if state in [PState.OPERATING, PState.COMPLETING]:
		return "[E]  Take it off the boil"
	return ""


func interact(_player: Node) -> void:
	if state == PState.IDLE:
		set_lid_open(false, 0.15)
		set_whistle_open(false, 0.12)
		_lift_gesture(false)
		_switch_on()
	elif state in [PState.OPERATING, PState.COMPLETING]:
		_switch_off()
		_lift_gesture(true)


func _start_normal_function() -> void:
	state = PState.IDLE


func _switch_on() -> void:
	_cycle_generation += 1
	var this_cycle := _cycle_generation
	state = PState.OPERATING
	_click.play()
	if not _hum.playing:
		_hum.play()
	create_tween().tween_property(_hum, "volume_db", -24.0, 2.0)
	var boil := get_tree().create_timer(heat_time, false)
	boil.timeout.connect(_request_whistle.bind(this_cycle))
	print("[KETTLE] %s on (cycle %d)" % [unit, this_cycle])


func _request_whistle(generation: int) -> void:
	# State alone cannot reject a timer from an interrupted cycle: if the
	# kettle was switched off and on again, it is OPERATING for the wrong
	# timer too. The generation makes that old future harmless.
	if generation != _cycle_generation or state != PState.OPERATING:
		return
	if Conductor.infection > 0.4:
		_whistle_on_next = true
	else:
		_begin_whistle()


func _begin_whistle() -> void:
	if state != PState.OPERATING:
		return
	state = PState.COMPLETING
	_whistle_on_next = false
	_steam.emitting = true
	_whistle.volume_db = -30.0
	_whistle.play()
	create_tween().tween_property(_whistle, "volume_db", -11.0, 3.0)
	print("[KETTLE] %s whistling" % unit)


func _switch_off() -> void:
	_cycle_generation += 1  # invalidate the un-cancellable SceneTreeTimer
	var completed := state == PState.COMPLETING
	state = PState.IDLE
	_whistle_on_next = false
	_steam.emitting = false
	if completed:
		cycles_completed += 1
	_click.play()
	create_tween().tween_property(_hum, "volume_db", -60.0, 0.8)
	var tw := create_tween()
	tw.tween_property(_whistle, "volume_db", -60.0, 1.0)
	tw.tween_callback(_whistle.stop)
	print("[KETTLE] %s off (%d boils)" % [unit, cycles_completed])


func set_lid_open(open: bool, seconds := 0.25) -> void:
	_lid_open = open
	var angle := deg_to_rad(-78.0) if open else 0.0
	create_tween().set_trans(Tween.TRANS_CUBIC).tween_property(
			_lid, "rotation:x", angle, seconds)
	lid_changed.emit(open)


func set_whistle_open(open: bool, seconds := 0.20) -> void:
	_whistle_open = open
	var angle := deg_to_rad(-62.0) if open else 0.0
	create_tween().set_trans(Tween.TRANS_CUBIC).tween_property(
			_whistle_cap, "rotation:x", angle, seconds)
	whistle_changed.emit(open)


func set_lifted(lifted: bool, seconds := 0.22) -> void:
	_lifted = lifted
	create_tween().set_trans(Tween.TRANS_CUBIC).tween_property(
			_vessel, "position:y", 0.055 if lifted else 0.0, seconds)


func _lift_gesture(open_cap_after: bool) -> void:
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(_vessel, "position:y", 0.028, 0.10)
	tw.tween_property(_vessel, "position:y", 0.0, 0.16)
	if open_cap_after:
		tw.tween_callback(set_whistle_open.bind(true, 0.20))


func set_service_pose() -> void:
	set_lid_open(true, 0.01)
	set_whistle_open(true, 0.01)
	set_lifted(true, 0.01)


func get_service_state() -> Dictionary:
	return {"lid_open": _lid_open, "whistle_open": _whistle_open,
			"lifted": _lifted, "cycle_generation": _cycle_generation,
			"case_id": case_id}


func _perform_synced_event(_index: int, accent: float, _pitch: float) -> void:
	if _whistle_on_next:
		_begin_whistle()
		return
	if state == PState.OPERATING:
		_click.volume_db = -17.0 + linear_to_db(clampf(accent, 0.2, 1.0))
		_click.play()
