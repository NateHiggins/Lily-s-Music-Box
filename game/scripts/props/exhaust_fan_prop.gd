class_name ExhaustFanProp
extends FunctionalProp
## One of four 1928 ILG-pattern central roof ventilators. The former square
## bathroom fan was a private postwar object in one privileged flat; these
## motors draw twenty-three passive ceiling registers through four shared
## sheet-metal risers. Electricity is power, not signal: nothing about this
## ordinary induction motor receives the Divergence's forty-year licence.
##
## Normal sound is deliberately staggered. A roof full of identical loops
## starting on the same frame sounds synthetic; one tired motor comes on,
## its whir appears at the bathrooms on that riser, then coasts away.

const PAINT := Color(0.35, 0.37, 0.36)
const IRON := Color(0.17, 0.18, 0.17)
const PANEL := Color(0.46, 0.47, 0.43)
const BRASS := Color(0.48, 0.35, 0.16)
const RUBBER := Color(0.10, 0.095, 0.085)

@export var riser := "V-A"
@export var fan_variant := "west_weathered"

var _rotor: Node3D
var _louver: Node3D
var _motor_hum: AudioStreamPlayer3D
var _duct_emitters: Array[AudioStreamPlayer3D] = []
var _rpm := 0.0
var _target_rpm := 0.0
var _motif_kick := 0.0


func _build_visual() -> void:
	var carcass := Node3D.new()
	carcass.name = "StaticCarcass"
	add_child(carcass)

	# A 720 mm curb still clears every measured roof route, but finally reads
	# as plant serving a six-storey riser rather than a domestic wall fitting.
	_box_on(carcass, Vector3(0.72, 0.16, 0.72), Vector3(0, 0.08, 0), PAINT)
	_box_on(carcass, Vector3(0.58, 0.48, 0.58), Vector3(0, 0.39, 0), PAINT)
	# Bell mouth and rain cap leave a real discharge gap on all four sides.
	_cyl_on(carcass, 0.34, 0.28, 0.20, Vector3(0, 0.70, 0), PAINT)
	_cyl_on(carcass, 0.43, 0.43, 0.065, Vector3(0, 0.91, 0), PAINT)
	for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
		var brace_at := Vector3(cos(angle) * 0.25, 0.80, sin(angle) * 0.25)
		var brace := _box_on(carcass, Vector3(0.045, 0.19, 0.045),
				brace_at, IRON)
		brace.rotation.y = -angle

	# The external motor and belt case are what distinguish central plant from
	# a decorative roof vent. The small brass plate has no generated lettering;
	# provenance is carried by the form and material, never hallucinated type.
	var motor := _cyl_on(carcass, 0.105, 0.12, 0.33,
			Vector3(0.24, 0.46, 0.03), IRON)
	motor.rotation_degrees.z = 90.0
	_box_on(carcass, Vector3(0.12, 0.38, 0.24),
			Vector3(0.31, 0.42, 0.02), IRON)
	_box_on(carcass, Vector3(0.31, 0.30, 0.025),
			Vector3(-0.10, 0.42, -0.302), PANEL)
	_box_on(carcass, Vector3(0.13, 0.055, 0.010),
			Vector3(-0.10, 0.47, -0.320), BRASS)
	for x in [-0.27, 0.27]:
		for z in [-0.27, 0.27]:
			_cyl_on(carcass, 0.035, 0.035, 0.025,
					Vector3(x, 0.012, z), RUBBER)

	_build_rotor()
	_build_louver()
	_build_service_anchors()
	retexture(self, [
		# The patent specifies enameled sheet metal. `metal` made the broad
		# horizontal hood reflect the night away and read black; painted trim
		# keeps the iron substrate in the form without baking false brightness.
		[PAINT, "trim", _paint_tint()],
		[IRON, "cast_iron", Color(0.38, 0.39, 0.37)],
		[PANEL, "trim", _panel_tint()],
		[BRASS, "brass_dull", Color.WHITE],
		[RUBBER, "rubber_aged", Color(0.36, 0.34, 0.30)],
	])
	merge_static(carcass)
	merge_static(_rotor)
	merge_static(_louver)

	_motor_hum = make_emitter("hum_loop", -80.0, false)
	_motor_hum.pitch_scale = _base_pitch()
	_build_duct_emitters()


func _build_rotor() -> void:
	_rotor = Node3D.new()
	_rotor.name = "VerticalRotor"
	_rotor.position = Vector3(0, 0.70, 0)
	add_child(_rotor)
	for i in 4:
		var angle := TAU * float(i) / 4.0
		var blade := _box_on(_rotor, Vector3(0.10, 0.018, 0.24),
				Vector3(0, 0, -0.12), PANEL)
		blade.rotation.y = angle + deg_to_rad(18.0)
		blade.position = blade.position.rotated(Vector3.UP, angle)
	_cyl_on(_rotor, 0.045, 0.045, 0.055, Vector3.ZERO, IRON)


func _build_louver() -> void:
	_louver = Node3D.new()
	_louver.name = "GravityLouver"
	_louver.position = Vector3(0, 0.50, -0.322)
	add_child(_louver)
	for i in 4:
		_box_on(_louver, Vector3(0.26, 0.045, 0.012),
				Vector3(0, -0.075 + i * 0.050, 0), PANEL)


func _build_service_anchors() -> void:
	for spec in [
		["ServicePlateReach", Vector3(-0.10, 0.47, -0.34)],
		["BeltGuardReach", Vector3(0.31, 0.42, -0.10)],
	]:
		var marker := Marker3D.new()
		marker.name = spec[0]
		marker.position = spec[1]
		add_child(marker)


func _build_duct_emitters() -> void:
	# Only audio is repeated. Geometry remains one batched grille surface per
	# finish and floor, while the sound is heard from the room it physically
	# enters rather than from a motor twenty metres overhead.
	for node_id in AcousticGraphData.nodes:
		var data: Dictionary = AcousticGraphData.nodes[node_id]
		if str(data.get("riser", "")) != riser \
				or not str(node_id).ends_with("_VENT_REGISTER"):
			continue
		var emitter := make_emitter("hum_loop", -80.0, false)
		emitter.name = "Duct_%s" % node_id
		emitter.position = to_local(AcousticGraphData.node_pos(node_id))
		emitter.unit_size = 1.6
		emitter.max_distance = 6.5
		emitter.pitch_scale = _base_pitch() * 0.82
		_duct_emitters.append(emitter)


func _start_normal_function() -> void:
	state = PState.IDLE
	call_deferred("_automatic_cycle")


func _automatic_cycle() -> void:
	var stack_index := maxi(0, riser.unicode_at(riser.length() - 1) - 65)
	await get_tree().create_timer(4.0 + stack_index * 7.0, false).timeout
	while is_inside_tree():
		set_running(true)
		await get_tree().create_timer(38.0 + stack_index * 4.0, false).timeout
		if not is_inside_tree():
			return
		set_running(false)
		await get_tree().create_timer(27.0 + stack_index * 6.0, false).timeout


func set_running(on: bool, immediate := false) -> void:
	state = PState.OPERATING if on else PState.IDLE
	_target_rpm = 8.0 if on else 0.0
	var louver_angle := deg_to_rad(-24.0) if on else 0.0
	if immediate:
		_rpm = _target_rpm
		_louver.rotation.x = louver_angle
	else:
		create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT) \
				.tween_property(_louver, "rotation:x", louver_angle, 0.65)
	_set_audio_running(on, immediate)


func is_running() -> bool:
	return state == PState.OPERATING


func duct_emitter_count() -> int:
	return _duct_emitters.size()


func _process(delta: float) -> void:
	var wanted := _target_rpm + _motif_kick
	_rpm = move_toward(_rpm, wanted, delta * (4.0 if wanted > _rpm else 1.8))
	_motif_kick = move_toward(_motif_kick, 0.0, delta * 2.4)
	if _rotor and _rpm > 0.01:
		_rotor.rotate_object_local(Vector3.UP, _rpm * delta)


func _perform_synced_event(_index: int, accent: float, pitch: float) -> void:
	if state != PState.OPERATING:
		return
	_motif_kick = accent * (1.2 + absf(pitch) * 0.03)
	_motor_hum.pitch_scale = _base_pitch() + accent * 0.08
	create_tween().tween_property(_motor_hum, "pitch_scale", _base_pitch(), 0.8)


func _set_audio_running(on: bool, immediate: bool) -> void:
	var all_emitters: Array[AudioStreamPlayer3D] = [_motor_hum]
	all_emitters.append_array(_duct_emitters)
	for i in all_emitters.size():
		var emitter := all_emitters[i]
		if on and not emitter.playing:
			emitter.play()
		var target := (-35.0 if i == 0 else -46.0) if on else -80.0
		if immediate:
			emitter.volume_db = target
		else:
			create_tween().tween_property(emitter, "volume_db", target,
					0.8 if on else 1.8)
		if not on:
			_stop_after_fade(emitter, 0.0 if immediate else 1.85)


func _stop_after_fade(emitter: AudioStreamPlayer3D, seconds: float) -> void:
	if seconds > 0.0:
		await get_tree().create_timer(seconds, false).timeout
	if is_instance_valid(emitter) and state != PState.OPERATING:
		emitter.stop()


func _base_pitch() -> float:
	match riser:
		"V-B": return 0.58
		"V-C": return 0.54
		"V-D": return 0.61
		_: return 0.56


func _paint_tint() -> Color:
	match fan_variant:
		"south_repainted": return Color(0.50, 0.52, 0.48)
		"east_oxidised": return Color(0.36, 0.38, 0.35)
		"north_belt": return Color(0.42, 0.43, 0.40)
		_: return Color(0.39, 0.40, 0.38)


func _panel_tint() -> Color:
	return Color(0.55, 0.54, 0.48) if fan_variant == "south_repainted" \
			else Color(0.44, 0.44, 0.40)


func _box_on(parent: Node3D, size: Vector3, at: Vector3,
		color: Color) -> MeshInstance3D:
	var part := make_box(size, at, color)
	part.reparent(parent)
	return part


func _cyl_on(parent: Node3D, top: float, bottom: float, height: float,
		at: Vector3, color: Color) -> MeshInstance3D:
	return make_cyl(top, bottom, height, at, color, 0.62, 0.12, parent)
