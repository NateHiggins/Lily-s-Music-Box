class_name WasherProp
extends FunctionalProp
## A 1926 powered wringer washer, not a front-loader in fancy dress.
##
## The Orison cannot use Maytag's famous cast-aluminium Model 90 verbatim:
## covenant VIII.4 removes aluminium from this world. This is the equally
## contemporary galvanized-tub class sold in the 1926 Galloway catalog,
## with the parts maintenance and the Matching game actually touch left as
## mechanisms. Everything that never moves is merged by finish; a convincing
## silhouette is not permission to spend thirty draws on angle iron.

const METAL := Color(0.55, 0.56, 0.58)
const ENAMEL := Color(0.85, 0.84, 0.78)
const BRASS := Color(0.62, 0.48, 0.22)
const RUBBER := Color(0.09, 0.08, 0.07)
const WOOD := Color(0.28, 0.20, 0.14)

var _fixed: Node3D
var _lid: Node3D
var _gyrator: Node3D
var _yoke: Node3D
var _roller_lower: Node3D
var _roller_upper: Node3D
var _pressure_screw: Node3D
var _release_bar: Node3D
var _water: MeshInstance3D
var _agitate: AudioStreamPlayer3D
var _thump: AudioStreamPlayer3D
var _lid_tween: Tween
var _yoke_tween: Tween
var _roller_gap := 0.0
var _wringer_running := false
var _release_warning := 0.0


func warehouse_variants() -> Array[Dictionary]:
	return [{"label": "washer / 1926 powered wringer"}]


func _build_visual() -> void:
	_fixed = Node3D.new()
	_fixed.name = "StaticFrameAndTub"
	add_child(_fixed)

	# Four narrow feet and an honest frame leave daylight beneath the tub.
	# A solid cabinet is the visual sentence that made the old prop modern.
	for x in [-0.27, 0.27]:
		for z in [-0.27, 0.27]:
			_box(_fixed, Vector3(0.055, 0.34, 0.055),
					Vector3(x, 0.17, z), ENAMEL)
	_box(_fixed, Vector3(0.61, 0.055, 0.055), Vector3(0, 0.31, -0.27), ENAMEL)
	_box(_fixed, Vector3(0.61, 0.055, 0.055), Vector3(0, 0.31, 0.27), ENAMEL)
	_box(_fixed, Vector3(0.055, 0.055, 0.61), Vector3(-0.27, 0.31, 0), ENAMEL)
	_box(_fixed, Vector3(0.055, 0.055, 0.61), Vector3(0.27, 0.31, 0), ENAMEL)

	# Galvanized square wash tub: four separate walls and a bottom, so opening
	# the cover reveals a vessel rather than the top face of a box.
	_box(_fixed, Vector3(0.66, 0.46, 0.035), Vector3(0, 0.59, -0.312), METAL)
	_box(_fixed, Vector3(0.66, 0.46, 0.035), Vector3(0, 0.59, 0.312), METAL)
	_box(_fixed, Vector3(0.035, 0.46, 0.59), Vector3(-0.312, 0.59, 0), METAL)
	_box(_fixed, Vector3(0.035, 0.46, 0.59), Vector3(0.312, 0.59, 0), METAL)
	_box(_fixed, Vector3(0.625, 0.035, 0.625), Vector3(0, 0.377, 0), METAL)
	for z in [-0.33, 0.33]:
		_box(_fixed, Vector3(0.70, 0.035, 0.04), Vector3(0, 0.825, z), METAL)
	for x in [-0.33, 0.33]:
		_box(_fixed, Vector3(0.04, 0.035, 0.62), Vector3(x, 0.825, 0), METAL)

	# Motor, belt guard, drain and wall-fed fill hardware. Their exposed bolts
	# explain how the machine is serviced without adding a modern fascia.
	var motor := _cyl(_fixed, 0.12, 0.12, 0.30,
			Vector3(0.0, 0.23, 0.20), METAL)
	motor.rotation_degrees.z = 90.0
	_box(_fixed, Vector3(0.38, 0.25, 0.055),
			Vector3(0, 0.20, -0.30), ENAMEL)
	for x in [-0.14, 0.0, 0.14]:
		_cyl(_fixed, 0.010, 0.010, 0.016,
				Vector3(x, 0.22, -0.335), BRASS)
	var drain := _cyl(_fixed, 0.028, 0.028, 0.24,
			Vector3(0.27, 0.28, 0.22), METAL)
	drain.rotation_degrees.x = 90.0
	for x in [-0.105, 0.105]:
		_cyl(_fixed, 0.018, 0.018, 0.10,
				Vector3(x, 0.91, 0.30), BRASS)
		_box(_fixed, Vector3(0.10, 0.018, 0.022),
				Vector3(x, 0.96, 0.30), BRASS)
	var fill_cross := _cyl(_fixed, 0.020, 0.020, 0.25,
			Vector3(0, 0.90, 0.29), BRASS)
	fill_cross.rotation_degrees.z = 90.0
	var fill_drop := _cyl(_fixed, 0.021, 0.021, 0.18,
			Vector3(0, 0.84, 0.20), BRASS)
	fill_drop.rotation_degrees.x = 90.0

	_water = _box(self, Vector3(0.56, 0.008, 0.55),
			Vector3(0, 0.79, 0), Color(0.18, 0.28, 0.31))
	var water_mat := _water.material_override as StandardMaterial3D
	water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_mat.albedo_color.a = 0.52
	water_mat.roughness = 0.12

	# The removable-looking cover is hinged only so the maintenance API has a
	# stable, testable state. It opens toward the wall and stops before it.
	_lid = Node3D.new()
	_lid.name = "TubLid"
	_lid.position = Vector3(0, 0.845, 0.315)
	add_child(_lid)
	_box(_lid, Vector3(0.67, 0.028, 0.62), Vector3(0, 0, -0.30), METAL)
	# Stamped grip in the lid's own finish. A separate wood material bought no
	# silhouette and cost one draw on each of the only two machines.
	_box(_lid, Vector3(0.18, 0.025, 0.035), Vector3(0, 0.025, -0.58), METAL)

	_gyrator = Node3D.new()
	_gyrator.name = "Gyrator"
	_gyrator.position = Vector3(0, 0.405, 0)
	add_child(_gyrator)
	_cyl(_gyrator, 0.13, 0.18, 0.075, Vector3.ZERO, METAL)
	for i in 4:
		var fin := _box(_gyrator, Vector3(0.29, 0.035, 0.045),
				Vector3(0, 0.045, 0), METAL)
		fin.rotation.y = i * PI * 0.5
	merge_static(_gyrator)

	_build_wringer()
	retexture(self, [
		# Galvanized steel is zinc-skinned, not mirror-bright bare metal.  The
		# generic metal set crushed these broad faces to black under basement
		# light; zinc_liner keeps the oxidised grain visible without inventing
		# another material or turning the inherited machine into aluminium.
		[METAL, "zinc_liner", Color(0.82, 0.84, 0.82), 0.72],
		[ENAMEL, "enamel", Color(0.88, 0.87, 0.80), 0.90],
		[BRASS, "brass_dull", Color(0.78, 0.70, 0.49), 0.70],
		[RUBBER, "rubber_aged", Color.WHITE, 0.26],
		[WOOD, "wood_dark", Color(0.72, 0.62, 0.48), 0.50],
	])
	merge_static(_fixed)
	merge_static(_lid)

	var body := StaticBody3D.new()
	body.name = "WasherCollision"
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.70, 0.84, 0.70)
	collision.shape = shape
	collision.position = Vector3(0, 0.42, 0)
	body.add_child(collision)
	add_child(body)
	_service_area("LidReach", Vector3(0, 0.91, -0.38), Vector3(0.62, 0.28, 0.34))
	_service_area("ReleaseReach", Vector3(0, 1.13, -0.38), Vector3(0.56, 0.25, 0.32))
	_service_area("FeedReach", Vector3(0, 1.02, -0.48), Vector3(0.54, 0.34, 0.34))
	_service_area("CocksReach", Vector3(0, 0.94, 0.38), Vector3(0.48, 0.28, 0.28))
	_service_area("DrainReach", Vector3(0.31, 0.30, 0.24), Vector3(0.25, 0.38, 0.30))

	_agitate = make_emitter("agitate_loop", -23.0, true)
	_thump = make_emitter("thud", -17.0)


func _build_wringer() -> void:
	# Pivot at the right rear corner. The rolls sit over the tub at rest and
	# can swing into seven historical working positions rather than rotating
	# decoratively around their own centre.
	_yoke = Node3D.new()
	_yoke.name = "SwingingWringer"
	_yoke.position = Vector3(0.27, 0.83, 0.20)
	add_child(_yoke)
	_cyl(_yoke, 0.035, 0.035, 0.29, Vector3(0, 0.14, 0), METAL)
	_box(_yoke, Vector3(0.58, 0.075, 0.13),
			Vector3(-0.27, 0.18, -0.20), ENAMEL)
	for x in [-0.51, -0.03]:
		_box(_yoke, Vector3(0.075, 0.25, 0.15),
				Vector3(x, 0.21, -0.20), ENAMEL)
		_cyl(_yoke, 0.018, 0.018, 0.022,
				Vector3(x, 0.22, -0.285), BRASS)

	_roller_lower = Node3D.new()
	_roller_lower.name = "LowerRoller"
	_yoke.add_child(_roller_lower)
	var lower := _cyl(_roller_lower, 0.054, 0.054, 0.44,
			Vector3(-0.27, 0.16, -0.20), RUBBER)
	lower.rotation_degrees.z = 90.0
	_roller_upper = Node3D.new()
	_roller_upper.name = "UpperRoller"
	_yoke.add_child(_roller_upper)
	var upper := _cyl(_roller_upper, 0.058, 0.058, 0.44,
			Vector3(-0.27, 0.275, -0.20), RUBBER)
	upper.rotation_degrees.z = 90.0

	_pressure_screw = Node3D.new()
	_pressure_screw.name = "PressureScrew"
	_yoke.add_child(_pressure_screw)
	_cyl(_pressure_screw, 0.018, 0.018, 0.18,
			Vector3(-0.27, 0.41, -0.20), BRASS)
	var handle := _cyl(_pressure_screw, 0.013, 0.013, 0.19,
			Vector3(-0.27, 0.50, -0.20), WOOD)
	handle.rotation_degrees.z = 90.0

	_release_bar = Node3D.new()
	_release_bar.name = "SafetyRelease"
	_yoke.add_child(_release_bar)
	var release := _cyl(_release_bar, 0.014, 0.014, 0.49,
			Vector3(-0.27, 0.35, -0.29), BRASS)
	release.rotation_degrees.z = 90.0
	merge_static(_yoke, [_roller_lower, _roller_upper,
			_pressure_screw, _release_bar])


func _start_normal_function() -> void:
	state = PState.OPERATING


func set_lid_open(open: bool, duration := 0.35) -> void:
	if _lid_tween and _lid_tween.is_valid():
		_lid_tween.kill()
	var target := deg_to_rad(-82.0 if open else 0.0)
	if duration <= 0.0:
		_lid.rotation.x = target
		return
	_lid_tween = create_tween()
	_lid_tween.tween_property(_lid, "rotation:x", target, duration) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func set_wringer_swing(angle_degrees: float, duration := 0.45) -> void:
	if _yoke_tween and _yoke_tween.is_valid():
		_yoke_tween.kill()
	var target := deg_to_rad(clampf(angle_degrees, -75.0, 75.0))
	if duration <= 0.0:
		_yoke.rotation.y = target
		return
	_yoke_tween = create_tween()
	_yoke_tween.tween_property(_yoke, "rotation:y", target, duration) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func set_wringer_gap(gap: float) -> void:
	_roller_gap = clampf(gap, 0.0, 0.045)
	_roller_upper.position.y = _roller_gap


func set_wringer_running(running: bool) -> void:
	_wringer_running = running


func set_agitating(running: bool) -> void:
	state = PState.OPERATING if running else PState.IDLE
	if _agitate:
		if running and not _agitate.playing:
			_agitate.play()
		elif not running:
			_agitate.stop()


func set_draining(draining: bool) -> void:
	_water.visible = not draining


func trigger_safety_release() -> void:
	_release_warning = 1.0
	set_wringer_gap(0.040)


func set_service_pose() -> void:
	set_lid_open(true, 0.0)
	set_wringer_swing(42.0, 0.0)
	set_wringer_gap(0.028)


func get_service_state() -> Dictionary:
	return {
		"lid_open": absf(_lid.rotation.x) > 0.5,
		"wringer_angle": rad_to_deg(_yoke.rotation.y),
		"roller_gap": _roller_gap,
		"running": _wringer_running,
		"water_visible": _water.visible,
	}


func _perform_synced_event(_index: int, accent: float, _pitch: float) -> void:
	# The release gives before the impossible empty wring. It is small enough
	# to leave the player unsure until the rollers answer on the beat.
	_release_warning = maxf(_release_warning, accent)
	_wringer_running = true
	_thump.volume_db = -19.0 + linear_to_db(clampf(accent, 0.25, 1.0))
	_thump.pitch_scale = rng.randf_range(0.82, 0.96)
	_thump.play()
	if Conductor.infection > 0.6 and _agitate.playing:
		_agitate.pitch_scale = clampf(Conductor.bpm / 72.0, 0.72, 1.32)


func _process(delta: float) -> void:
	if state == PState.OPERATING:
		_gyrator.rotation.y += delta * 1.35
	if _wringer_running:
		_roller_lower.rotation.x += delta * 2.8
		_roller_upper.rotation.x -= delta * 2.8
	if _release_warning > 0.001:
		_release_bar.rotation.x = deg_to_rad(-8.0 * _release_warning)
		_release_warning = maxf(0.0, _release_warning - delta * 1.8)
	else:
		_release_bar.rotation.x = lerpf(_release_bar.rotation.x, 0.0,
				clampf(delta * 8.0, 0.0, 1.0))


func _service_area(area_name: String, at: Vector3, size: Vector3) -> void:
	var area := Area3D.new()
	area.name = area_name
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position = at
	area.add_child(collision)
	add_child(area)


func _box(parent: Node3D, size: Vector3, at: Vector3,
		color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = at
	node.material_override = _pmat(color, 0.58, 0.20)
	parent.add_child(node)
	return node


func _cyl(parent: Node3D, rt: float, rb: float, height: float,
		at: Vector3, color: Color) -> MeshInstance3D:
	return make_cyl(rt, rb, height, at, color, 0.58, 0.20, parent)
