class_name BoxFanProp
extends FunctionalProp
## Serialized as `boxfan` because that is the old layout name; visibly this is
## a second-hand 1920-27 portable fan.  It carries no signal, so the divergence
## licenses nothing later.  A RUNNING fan may answer the motif through its own
## motor speed.  An OFF fan stays off.  Only Sacha's evidence fan can violate
## that contract: after the player leaves its room, its plug is found on the
## floor while its rotor continues to turn.

const BODY := Color(0.19, 0.20, 0.19)
const GUARD := Color(0.47, 0.48, 0.46)
const BLADE := Color(0.20, 0.14, 0.09)
const BAKELITE := Color(0.10, 0.085, 0.07)
const CORD := Color(0.12, 0.10, 0.085)
const BRASS := Color(0.52, 0.39, 0.18)

const STEP_RPM := [0.0, 10.5, 15.0, 19.5]
const STEP_PITCH := [0.0, 0.48, 0.60, 0.72]

@export var unit := ""
@export var fan_variant := "plain"
@export var room_id := ""

var _hum: AudioStreamPlayer3D
var _rotor: Node3D
var _selector: Node3D
var _plug: Node3D
var _plugged := true
var _speed_step := 1
var _rpm := 0.0
var _target_rpm := 0.0
var _motif_offset := 0.0

# 0 ordinary, 1 wait for first room exit, 2 wait for return, 3 exhibit,
# 4 wait for a second exit before silently restoring the plug.
var _possession_phase := 0
var _possession_seconds := 0.0
var _before_possession_step := 0


func warehouse_variants() -> Array[Dictionary]:
	return [
		{"unit": "2C", "fan_variant": "juno_black"},
		{"unit": "5C", "fan_variant": "iris_green"},
		{"unit": "6A", "fan_variant": "sacha_nickel"},
		{"unit": "4B", "fan_variant": "landlord_plain"},
	]


func _build_visual() -> void:
	var static_body := Node3D.new()
	static_body.name = "StaticCarcass"
	add_child(static_body)

	# Couch/Westinghouse proportions: the old cage diameter was already right.
	# What made it toy-sized was the absence of the 11 kg base, deep motor and
	# guard.  Preserve the honest 440 mm sweep and put the missing mass back.
	_box_on(static_body, Vector3(0.31, 0.045, 0.23),
			Vector3(0, 0.023, 0.035), BODY)
	_box_on(static_body, Vector3(0.24, 0.035, 0.17),
			Vector3(0, 0.052, 0.025), BODY)
	_cyl_on(static_body, 0.032, 0.046, 0.18,
			Vector3(0, 0.145, 0.045), BODY)
	_box_on(static_body, Vector3(0.25, 0.045, 0.055),
			Vector3(0, 0.225, 0.045), BODY)
	# Tilt trunnions are visible mechanisms, but fixed for this inexpensive
	# household model.  A false animated joint would promise an interaction.
	for x in [-0.105, 0.105]:
		var trunnion := _cyl_on(static_body, 0.030, 0.030, 0.035,
				Vector3(x, 0.275, 0.04), GUARD)
		trunnion.rotation_degrees.z = 90.0

	# Motor shaft points local -Z, the same direction as the air and the
	# appliance front.  Front and rear guards give the cage real depth.
	var motor := _cyl_on(static_body, 0.082, 0.095, 0.17,
			Vector3(0, 0.305, 0.035), BODY)
	motor.rotation_degrees.x = 90.0
	for z in [-0.105, 0.115]:
		for radius in [0.215, 0.145, 0.075]:
			var ring := make_ring(radius, 0.006 if radius < 0.20 else 0.009,
					Vector3(0, 0.305, z), GUARD, 0.48, 0.45, static_body)
			ring.rotation_degrees.x = 90.0
		for i in 6:
			var angle := TAU * float(i) / 6.0
			_tube_between(static_body, Vector3(0, 0.305, z),
					Vector3(cos(angle) * 0.21, 0.305 + sin(angle) * 0.21, z),
					0.0045, GUARD)
	# Four vents make the rear can read as a motor rather than a drum.
	for i in 4:
		var a := TAU * float(i) / 4.0
		_tube_between(static_body,
				Vector3(cos(a) * 0.070, 0.305 + sin(a) * 0.070, 0.122),
				Vector3(cos(a) * 0.088, 0.305 + sin(a) * 0.088, 0.122),
				0.008, BAKELITE)
	# A handle is useful evidence that this is portable, not plant machinery.
	_tube_between(static_body, Vector3(-0.105, 0.492, 0.06),
			Vector3(-0.105, 0.545, 0.06), 0.009, BAKELITE)
	_tube_between(static_body, Vector3(-0.105, 0.545, 0.06),
			Vector3(0.105, 0.545, 0.06), 0.009, BAKELITE)
	_tube_between(static_body, Vector3(0.105, 0.545, 0.06),
			Vector3(0.105, 0.492, 0.06), 0.009, BAKELITE)
	# The cord terminates.  Its last short length belongs to the movable plug;
	# the broad loop can stay fixed without pretending to be cloth simulation.
	_tube_between(static_body, Vector3(-0.09, 0.035, 0.13),
			Vector3(-0.20, 0.018, 0.24), 0.007, CORD)
	_tube_between(static_body, Vector3(-0.20, 0.018, 0.24),
			Vector3(-0.08, 0.018, 0.32), 0.007, CORD)

	_build_rotor()
	_build_selector()
	_build_plug()
	_build_interaction()

	retexture(self, [
		[BODY, "cast_iron", _body_tint()],
		[GUARD, "metal", _guard_tint()],
		[BLADE, "bakelite_black", _blade_tint()],
		[BAKELITE, "bakelite_black", Color.WHITE],
		[CORD, "linen", Color(0.20, 0.16, 0.12)],
		[BRASS, "brass_dull", Color.WHITE],
	])
	merge_static(static_body)
	merge_static(_rotor)
	merge_static(_selector)
	merge_static(_plug)

	_hum = make_emitter("buzz_loop", -80.0, false)
	_hum.pitch_scale = STEP_PITCH[_speed_step]
	set_speed_step(_speed_step, true)


func _build_rotor() -> void:
	_rotor = Node3D.new()
	_rotor.name = "Rotor"
	_rotor.position = Vector3(0, 0.305, -0.052)
	add_child(_rotor)
	# Two overlapping paddles per blade turn a rectangle into the broad,
	# shouldered Micarta blade visible in 1920s catalogues.  They merge into
	# one moving draw, so silhouette costs no extra submission at runtime.
	for i in 4:
		var angle := TAU * float(i) / 4.0
		for part in 2:
			var paddle := _box_on(_rotor,
					Vector3(0.082 + part * 0.020, 0.125, 0.010),
					Vector3(0, 0.092 + part * 0.055, 0), BLADE)
			paddle.rotation_degrees = Vector3(0, 11.0, rad_to_deg(angle) - 13.0)
			paddle.position = paddle.position.rotated(Vector3.FORWARD, angle)
	_cyl_on(_rotor, 0.033, 0.033, 0.025, Vector3.ZERO, BLADE).rotation_degrees.x = 90


func _build_selector() -> void:
	_selector = Node3D.new()
	_selector.name = "SpeedSelector"
	_selector.position = Vector3(0.095, 0.086, -0.075)
	add_child(_selector)
	var stem := _cyl_on(_selector, 0.020, 0.020, 0.026,
			Vector3.ZERO, BAKELITE)
	stem.rotation_degrees.x = 90.0
	_box_on(_selector, Vector3(0.055, 0.020, 0.024),
			Vector3(0, 0, -0.020), BAKELITE)


func _build_plug() -> void:
	_plug = Node3D.new()
	_plug.name = "AttachmentPlug"
	add_child(_plug)
	_box_on(_plug, Vector3(0.055, 0.033, 0.070), Vector3.ZERO, BAKELITE)
	for x in [-0.014, 0.014]:
		_box_on(_plug, Vector3(0.007, 0.012, 0.030),
				Vector3(x, 0, -0.048), BRASS)
	_tube_between(_plug, Vector3(0, 0, 0.035),
			Vector3(0, 0, 0.105), 0.007, CORD)
	set_plugged(true, true)


func _build_interaction() -> void:
	var area := Area3D.new()
	area.name = "Interaction"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.48, 0.56, 0.34)
	shape.shape = box
	shape.position = Vector3(0, 0.27, 0)
	area.add_child(shape)
	add_child(area)
	for spec in [
		["SelectorReach", Vector3(0.095, 0.086, -0.11)],
		["HandleReach", Vector3(0, 0.545, 0.06)],
		["PlugReach", Vector3(-0.08, 0.035, 0.30)],
	]:
		var anchor := Marker3D.new()
		anchor.name = spec[0]
		anchor.position = spec[1]
		add_child(anchor)


func interact_prompt() -> String:
	return "[E]  Fan speed %d — turn to %d" % [_speed_step,
			(_speed_step + 1) % 4]


func interact(_player: Node) -> void:
	if _possession_phase in [2, 3, 4]:
		return
	set_speed_step((_speed_step + 1) % 4)


func set_speed_step(step: int, immediate := false) -> void:
	_speed_step = clampi(step, 0, 3)
	_target_rpm = STEP_RPM[_speed_step]
	state = PState.OFF if _speed_step == 0 else PState.OPERATING
	if _selector:
		var angle := deg_to_rad(-45.0 + 30.0 * float(_speed_step))
		if immediate:
			_selector.rotation.y = angle
		else:
			create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT) \
					.tween_property(_selector, "rotation:y", angle, 0.12)
	if immediate:
		_rpm = _target_rpm
	_update_hum()


func speed_step() -> int:
	return _speed_step


func set_plugged(plugged: bool, immediate := false) -> void:
	_plugged = plugged
	if _plug == null:
		return
	# Plugged: the plug disappears toward the wall behind the base. Unplugged:
	# exposed prongs lie in front where a returning player can inspect them.
	var target := Vector3(-0.08, 0.045, 0.31) if plugged \
			else Vector3(0.29, 0.030, -0.16)
	var turn := Vector3(90, 0, 0) if plugged else Vector3(0, -35, 78)
	if immediate:
		_plug.position = target
		_plug.rotation_degrees = turn
	else:
		create_tween().set_parallel(true) \
				.tween_property(_plug, "position", target, 0.18)
		create_tween().tween_property(_plug, "rotation_degrees", turn, 0.18)


func is_plugged() -> bool:
	return _plugged


func _start_normal_function() -> void:
	# Unlike the prototype, normal operation is an authored switch position,
	# not an unconditional _process side effect.
	set_speed_step(_speed_step, true)


func _process(delta: float) -> void:
	_update_possession(delta)
	var wanted := _target_rpm + _motif_offset
	_rpm = move_toward(_rpm, wanted, delta * (18.0 if wanted > _rpm else 7.0))
	_motif_offset = move_toward(_motif_offset, 0.0, delta * 5.0)
	if _rotor and _rpm > 0.01:
		# The rotor disk lies in XY; its shaft is local Z. The old UP-axis turn
		# swung the disk itself through the cage rather than spinning its blades.
		_rotor.rotate_object_local(Vector3.FORWARD, _rpm * delta)
	_update_hum()


func _perform_synced_event(_index: int, accent: float, pitch: float) -> void:
	if _speed_step == 0 or _possession_phase > 0:
		return
	_motif_offset = accent * 4.0 * signf(pitch + 0.5)


## Direct possession requests are Sacha's evidence mechanism. The other three
## fans still bend while running, but never contradict their switch or cord.
func possess_fit(beats := 4) -> void:
	if unit != "6A" or _possession_phase > 0:
		return
	_before_possession_step = _speed_step
	_possession_seconds = maxf(0.7, 0.35 * float(beats))
	_possession_phase = 1
	# If nobody is in the room, the first safe handoff is already available.
	if _current_player_room() != room_id:
		_begin_unplugged_fit()


func possession_phase() -> int:
	return _possession_phase


func _update_possession(delta: float) -> void:
	if _possession_phase == 0:
		return
	var player_room := _current_player_room()
	if _possession_phase == 1 and player_room != room_id:
		_begin_unplugged_fit()
	elif _possession_phase == 2 and player_room == room_id:
		_possession_phase = 3
	elif _possession_phase == 3:
		_possession_seconds -= delta
		if _possession_seconds <= 0.0:
			# It dies honestly while the impossible unplugged state remains in
			# view. The building waits for a second room exit before cleaning up.
			_target_rpm = 0.0
			_possession_phase = 4
	elif _possession_phase == 4 and player_room != room_id:
		set_plugged(true)
		set_speed_step(_before_possession_step)
		_possession_phase = 0


func _begin_unplugged_fit() -> void:
	set_plugged(false, true)
	state = PState.INFECTED
	_target_rpm = STEP_RPM[maxi(2, _before_possession_step)]
	_possession_phase = 2


func _current_player_room() -> String:
	var roots := get_tree().get_nodes_in_group("building_root")
	if roots.is_empty():
		return ""
	var building: Node = roots[0]
	if not building.has_method("room_at_world") or building.get("player") == null:
		return ""
	return String(building.room_at_world(building.player.global_position))


func _update_hum() -> void:
	if _hum == null:
		return
	var audible := _rpm > 0.20
	if audible and not _hum.playing:
		_hum.play()
	_hum.volume_db = lerpf(-48.0, -25.0, clampf(_rpm / STEP_RPM[3], 0.0, 1.0)) \
			if audible else -80.0
	_hum.pitch_scale = maxf(0.35, STEP_PITCH[maxi(1, _speed_step)] \
			+ (_rpm - _target_rpm) * 0.012)
	if not audible and _hum.playing:
		_hum.stop()


func _body_tint() -> Color:
	match fan_variant:
		"iris_green": return Color(0.34, 0.43, 0.34)
		"sacha_nickel": return Color(0.63, 0.62, 0.57)
		"landlord_plain": return Color(0.47, 0.39, 0.31)
		_: return Color(0.31, 0.31, 0.29)


func _guard_tint() -> Color:
	return Color(0.70, 0.68, 0.62) if fan_variant == "sacha_nickel" \
			else Color(0.48, 0.47, 0.43)


func _blade_tint() -> Color:
	return Color(0.42, 0.29, 0.18) if fan_variant == "landlord_plain" \
			else Color(0.25, 0.21, 0.17)


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
