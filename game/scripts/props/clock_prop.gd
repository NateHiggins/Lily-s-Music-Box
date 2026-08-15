class_name ClockProp
extends FunctionalProp
## The two honest clocks the building owns.
##
## 4B has an ordinary second-hand eight-day drop-octagon.  It carries no
## signal and comes off the electrical graph for the same reason fourteen oak
## iceboxes did: a useful mechanism is not automatically a wired mechanism.
## The lobby clock is the opposite.  It receives Vantry house time, so VIII.2
## licenses its 1967 precision hardware — and its permanent four-minute error
## makes every clock set from the Handbook's reference wrong for a reason.

const ORDER_ID := "WO-CLOCK-001"
const ORDER_TITLE := "WORK ORDER 002 — WIND 4B"
const ORDER_TEXT := "The apartment clock is losing its spring. Hold the winding key until the movement takes a full charge."
const EIGHT_DAYS_SECONDS := 8.0 * 24.0 * 60.0 * 60.0
const MASTER_ERROR_MINUTES := 4.0

const OAK := Color(0.32, 0.19, 0.095)
const DARK_WOOD := Color(0.18, 0.105, 0.055)
const BRASS := Color(0.62, 0.47, 0.19)
const NICKEL := Color(0.66, 0.65, 0.61)
const ENAMEL := Color(0.78, 0.78, 0.72)
const PAPER := Color(0.89, 0.86, 0.77)
const BAKELITE := Color(0.09, 0.075, 0.06)
const INK := Color(0.075, 0.068, 0.058)

var unit := "4B"
var clock_variant := "drop_octagon"
var interval := 1.0
var spring_reserve := 0.18
var reserve_duration_seconds := EIGHT_DAYS_SECONDS
var work_orders: WorkOrders

var _hour: Node3D
var _minute: Node3D
var _second: Node3D
var _pendulum: Node3D
var _tick: AudioStreamPlayer3D
var _service_touch: AudioStreamPlayer3D
var _master_cover: MeshInstance3D
var _cover_tween: Tween
var _cover_rest := Vector3.ZERO
var _acc := 0.0
var _motion_time := 0.0
var _winding := false


func bind_order_spine(spine: WorkOrders) -> void:
	work_orders = spine


func warehouse_variants() -> Array[Dictionary]:
	return [
		{"label": "clock / 8-day drop octagon",
			"properties": {"unit": "4B", "clock_variant": "drop_octagon",
				"spring_reserve": 0.72}},
		{"label": "clock / Vantry lobby master",
			"properties": {"unit": "LOBBY", "clock_variant": "vantry_master",
				"spring_reserve": 1.0}},
	]


func _build_visual() -> void:
	var fixed := Node3D.new()
	fixed.name = "StaticCase"
	add_child(fixed)
	if clock_variant == "vantry_master":
		_build_master(fixed)
	else:
		_build_drop_octagon(fixed)
	_build_hands()
	_build_glass()
	_build_collision()
	retexture(self, [
		[OAK, "oak_quartered", Color(0.76, 0.62, 0.46), 0.82],
		[DARK_WOOD, "wood_dark", Color(0.64, 0.50, 0.38), 0.72],
		[BRASS, "brass_dull", Color(0.82, 0.72, 0.48), 0.62],
		[NICKEL, "nickel_plated", Color(0.78, 0.78, 0.74), 0.56],
		[ENAMEL, "enamel", Color(0.80, 0.81, 0.77), 0.66],
		[PAPER, "paper", Color(0.92, 0.88, 0.78), 0.68],
		[BAKELITE, "bakelite_black", Color(0.52, 0.46, 0.38), 0.64],
	])
	merge_static(fixed)
	if _pendulum:
		merge_static(_pendulum)
	_tick = make_emitter("tick", -29.0 if clock_variant == "vantry_master" else -26.0)
	_tick.max_distance = 8.0
	_service_touch = make_emitter("tick", -18.0)
	_service_touch.max_distance = 3.4


func _build_drop_octagon(fixed: Node3D) -> void:
	# Twelve-inch dial in a 16-inch octagonal case: the cheap American
	# schoolhouse/drop proportion that survived in catalogues into 1928.
	for i in 8:
		var a := TAU * float(i) / 8.0 + PI / 8.0
		var rail := _box(fixed, Vector3(0.165, 0.040, 0.082),
				Vector3(sin(a) * 0.204, cos(a) * 0.204, 0.0), OAK)
		rail.rotation.z = -a
	_box(fixed, Vector3(0.225, 0.335, 0.082),
			Vector3(0, -0.335, -0.002), OAK)
	_box(fixed, Vector3(0.165, 0.238, 0.010),
			Vector3(0, -0.335, 0.045), DARK_WOOD)
	var dial := _cyl(fixed, 0.158, 0.158, 0.009,
			Vector3(0, 0, 0.046), PAPER)
	dial.rotation_degrees.x = 90
	var bezel := make_ring(0.171, 0.011, Vector3(0, 0, 0.055), BRASS,
			0.50, 0.30, fixed)
	bezel.rotation_degrees.x = 90
	_build_marks(fixed, 0.129, 0.046)
	# Two keyholes: time train and strike train.  Only the time train is the
	# maintenance interaction; the second hole makes this a real movement.
	for kx in [-0.046, 0.046]:
		var key_ring := make_ring(0.010, 0.003, Vector3(kx, -0.040, 0.058),
				BRASS, 0.55, 0.30, fixed)
		key_ring.rotation_degrees.x = 90
		_box(fixed, Vector3(0.007, 0.020, 0.005),
				Vector3(kx, -0.040, 0.061), INK)
	_pendulum = Node3D.new()
	_pendulum.name = "PendulumRig"
	_pendulum.position = Vector3(0, -0.205, 0.055)
	add_child(_pendulum)
	_box(_pendulum, Vector3(0.009, 0.255, 0.008),
			Vector3(0, -0.112, 0), BRASS)
	var bob := _cyl(_pendulum, 0.051, 0.051, 0.012,
			Vector3(0, -0.225, 0.004), BRASS)
	bob.rotation_degrees.x = 90
	var reach := Marker3D.new()
	reach.name = "WindingReach"
	reach.position = Vector3(-0.046, -0.040, 0.085)
	add_child(reach)


func _build_master(fixed: Node3D) -> void:
	# Vantry's public secondary clock: an institutional enamel dial in a
	# moulded phenolic drum, with a locked brass bezel and no winding holes.
	var rear := _cyl(fixed, 0.235, 0.235, 0.082,
			Vector3(0, 0, -0.012), BAKELITE)
	rear.rotation_degrees.x = 90
	var dial := _cyl(fixed, 0.202, 0.202, 0.010,
			Vector3(0, 0, 0.043), ENAMEL)
	dial.rotation_degrees.x = 90
	var bezel := make_ring(0.217, 0.014, Vector3(0, 0, 0.054), BRASS,
			0.52, 0.30, fixed)
	bezel.rotation_degrees.x = 90
	_build_marks(fixed, 0.166, 0.046)
	# Four bezel screws and a sealed setting cover say service equipment,
	# not a decorative clock somebody can correct by hand.
	for i in 4:
		var a := TAU * float(i) / 4.0 + PI / 4.0
		var screw := _cyl(fixed, 0.007, 0.007, 0.005,
				Vector3(sin(a) * 0.207, cos(a) * 0.207, 0.065), NICKEL)
		screw.rotation_degrees.x = 90
	# The setting cover stays outside the merged case because it is the one
	# truthful thing a hand can test. It rattles but cannot expose or adjust the
	# authoritative house-time mechanism.
	_master_cover = make_box(Vector3(0.064, 0.030, 0.010),
			Vector3(0, -0.176, 0.063), BRASS)
	_cover_rest = _master_cover.position


func _build_marks(fixed: Node3D, radius: float, depth: float) -> void:
	for i in 12:
		var a := TAU * float(i) / 12.0
		var cardinal := i % 3 == 0
		var mark := _box(fixed,
				Vector3(0.010 if cardinal else 0.006,
					0.030 if cardinal else 0.017, 0.005),
				Vector3(sin(a) * radius, cos(a) * radius, depth + 0.006), INK)
		mark.rotation.z = -a


func _build_hands() -> void:
	_hour = _hand("HourHand", 0.083 if clock_variant == "drop_octagon" else 0.108,
			0.013, 0.068)
	_minute = _hand("MinuteHand", 0.122 if clock_variant == "drop_octagon" else 0.154,
			0.009, 0.071)
	_second = _hand("SecondHand", 0.136 if clock_variant == "drop_octagon" else 0.172,
			0.004, 0.075, Color(0.38, 0.075, 0.055))
	_show_time()


func _hand(title: String, length: float, width: float, depth: float,
		color := INK) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = title
	add_child(pivot)
	_box(pivot, Vector3(width, length, 0.006),
			Vector3(0, length * 0.42, depth), color)
	return pivot


func _build_glass() -> void:
	var glass := MeshInstance3D.new()
	glass.name = "ClockGlass"
	var quad := QuadMesh.new()
	quad.size = Vector2(0.318, 0.318) if clock_variant == "drop_octagon" \
			else Vector2(0.404, 0.404)
	glass.mesh = quad
	# Clear glazing is optical behavior, not a bitmap.  A generated plate
	# would bake a reflected room and make every clock repeat the same lie.
	var optical := StandardMaterial3D.new()
	optical.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	optical.albedo_color = Color(0.78, 0.84, 0.82, 0.12)
	optical.roughness = 0.18
	optical.metallic = 0.0
	optical.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass.material_override = optical
	glass.position.z = 0.082
	add_child(glass)


func _build_collision() -> void:
	var area := Area3D.new()
	area.name = "ClockReach"
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.48, 0.72 if clock_variant == "drop_octagon" else 0.50,
			0.16)
	cs.shape = shape
	cs.position.y = -0.15 if clock_variant == "drop_octagon" else 0.0
	area.add_child(cs)
	add_child(area)


func _box(parent: Node3D, size: Vector3, at: Vector3,
		color: Color) -> MeshInstance3D:
	var part := make_box(size, at, color)
	remove_child(part)
	parent.add_child(part)
	return part


func _cyl(parent: Node3D, top: float, bottom: float, height: float,
		at: Vector3, color: Color) -> MeshInstance3D:
	return make_cyl(top, bottom, height, at, color, 0.55, 0.0, parent)


func _start_normal_function() -> void:
	if clock_variant == "vantry_master":
		state = PState.OPERATING
		spring_reserve = 1.0
		return
	state = PState.OPERATING if spring_reserve > 0.0 else PState.OFF
	if work_orders:
		work_orders.issue(ORDER_ID, ORDER_TITLE, ORDER_TEXT, "4B wall clock")
		if work_orders.status(ORDER_ID) != "closed":
			work_orders.activate(ORDER_ID)


func _process(delta: float) -> void:
	var running := clock_variant == "vantry_master" or spring_reserve > 0.0
	if clock_variant != "vantry_master" and running:
		spring_reserve = maxf(0.0,
				spring_reserve - delta / maxf(0.05, reserve_duration_seconds))
		if spring_reserve <= 0.0:
			state = PState.OFF
	if not running:
		return
	state = PState.OPERATING if state != PState.INFECTED else state
	_motion_time += delta
	_show_time()
	if _pendulum:
		_pendulum.rotation.z = sin(_motion_time * PI * 2.0) * 0.075
	# Time keeps time — until the building offers a better tempo.
	var target := 1.0 if Conductor.infection < 0.4 else 60.0 / Conductor.bpm
	interval = lerpf(interval, target, delta * 0.05)
	_acc += delta
	if _acc >= interval:
		_acc = fmod(_acc, interval)
		_tick.pitch_scale = 0.96 if clock_variant == "vantry_master" \
				else (1.0 if int(Time.get_ticks_msec() / 1000.0) % 2 == 0 else 1.06)
		if not _tick.playing:
			_tick.play()


func _show_time() -> void:
	if _hour == null:
		return
	var t := Time.get_time_dict_from_system()
	var total_minutes := float(int(t.hour) * 60 + int(t.minute)) \
			+ float(t.second) / 60.0
	if clock_variant == "vantry_master":
		total_minutes += MASTER_ERROR_MINUTES
	var h := fmod(total_minutes / 60.0, 12.0)
	var m := fmod(total_minutes, 60.0)
	var sec := fmod(total_minutes * 60.0, 60.0)
	_hour.rotation.z = -TAU * h / 12.0
	_minute.rotation.z = -TAU * m / 60.0
	_second.rotation.z = -TAU * sec / 60.0


func interact_prompt() -> String:
	if clock_variant == "vantry_master":
		return "[E]  Try sealed Vantry setting cover"
	if _winding:
		return "Hold E — winding…"
	if spring_reserve >= 0.95:
		return "The eight-day movement is fully wound"
	return "Hold E — wind the clock"


func interact(player: Node) -> Dictionary:
	if clock_variant == "vantry_master":
		_service_touch.pitch_scale = 0.74
		_service_touch.play()
		_rattle_master_cover()
		return service_wire_card()
	if _winding:
		_service_touch.pitch_scale = 1.08
		_service_touch.play()
		return service_wire_card()
	_service_touch.pitch_scale = 0.92
	_service_touch.play()
	if player == null:
		finish_winding()
		return service_wire_card()
	_hold_to_wind()
	return service_wire_card()


func service_wire_card() -> Dictionary:
	if clock_variant == "vantry_master":
		return {
			"title": "VANTRY REFERENCE CLOCK",
			"body": "A SYNCHRONOUS MOTOR CAN DISTRIBUTE ONE TIME INDICATION THROUGH AN ALTERNATING-CURRENT SYSTEM STOP",
			"condition": "MOVEMENT LINE SYNCHRONIZED / SETTING COVER SEALED / READING FOUR MINUTES FAST",
			"stamp": "SERVICE NOTE",
			"card_id": "winding_clock",
			"source_ids": ["R051"],
		}
	return PropServiceWire.card("winding_clock", {
		"movement_state": "RUNNING" if spring_reserve > 0.0 else "STOPPED",
		"reserve_state": "%d PERCENT" % roundi(spring_reserve * 100.0),
	})


func _rattle_master_cover() -> void:
	if _master_cover == null:
		return
	if _cover_tween and _cover_tween.is_valid():
		_cover_tween.kill()
	_master_cover.position = _cover_rest
	_cover_tween = create_tween()
	_cover_tween.tween_property(_master_cover, "position:z",
			_cover_rest.z - 0.004, 0.055)
	_cover_tween.tween_property(_master_cover, "position:z",
			_cover_rest.z + 0.002, 0.07)
	_cover_tween.tween_property(_master_cover, "position:z",
			_cover_rest.z, 0.09)


func _hold_to_wind() -> void:
	_winding = true
	var held := 0.0
	while held < 0.85 and Input.is_action_pressed("interact") and is_inside_tree():
		var delta := get_process_delta_time()
		held += delta
		spring_reserve = minf(1.0, spring_reserve + delta / 0.85)
		await get_tree().process_frame
	_winding = false
	if spring_reserve >= 0.95:
		finish_winding()


func finish_winding() -> void:
	spring_reserve = 1.0
	state = PState.OPERATING
	if work_orders and work_orders.status(ORDER_ID) != "closed":
		work_orders.close(ORDER_ID,
				"MOVEMENT WOUND. The lobby reference remains four minutes fast.")


func set_spring_reserve(value: float) -> void:
	spring_reserve = clampf(value, 0.0, 1.0)
	state = PState.OPERATING if spring_reserve > 0.0 else PState.OFF


func winding_point() -> Vector3:
	var marker := get_node_or_null("WindingReach") as Marker3D
	return marker.global_position if marker else global_position


func displayed_offset_minutes() -> float:
	return MASTER_ERROR_MINUTES if clock_variant == "vantry_master" else 0.0


func _perform_synced_event(_index: int, accent: float, _pitch: float) -> void:
	# A clock cannot flash or jump.  Its only corrupted verb is advancing a
	# hand, small enough that the player can still doubt the remembered time.
	if _second:
		_second.rotation.z -= TAU / 60.0 * clampf(accent, 0.15, 1.0)
