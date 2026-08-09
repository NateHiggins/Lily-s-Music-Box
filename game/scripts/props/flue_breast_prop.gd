class_name FlueBreastProp
extends FunctionalProp
## The sealed 1912 stove-pipe thimble on the room face of the C-stack
## chimney breast.  The masonry belongs to the Blender floor; this prop owns
## only the removable iron fitting and the damage made where heat met plaster.
##
## The flue is still the building's fast acoustic path.  A propagated knock
## reaches this loose closure before the floor radiator answers, but the plate
## moves only enough for its shadow edge to betray it.  Sound carries the beat;
## movement is the evidence a player may notice afterward.

@export var unit := "5C"

const CENTRE_Y := 1.44
const IRON := Color(0.34, 0.33, 0.31)
const SOOT := Color(0.19, 0.17, 0.15)

var _cap: Node3D
var _knock: AudioStreamPlayer3D
var _draft: AudioStreamPlayer3D
var _settle: Tween


func warehouse_variants() -> Array[Dictionary]:
	return [{"label": "sealed 1912 thimble", "properties": {"unit": "5C"}}]


func warehouse_rotation_y() -> float:
	# The authored front is local -Z so the room fitting projects away from
	# the breast.  Turn that face toward the shed's common viewing aisle.
	return PI


func _build_visual() -> void:
	var fixed := Node3D.new()
	fixed.name = "FixedThimble"
	add_child(fixed)

	# A 310 mm face is large enough for the old stove pipe and its reducing
	# rings without becoming fireplace furniture.  The circular soot bloom is
	# the former rectangular placeholder corrected into a heat-shaped deposit.
	var halo := make_cyl(0.205, 0.205, 0.002,
			Vector3(0, CENTRE_Y + 0.018, -0.002), SOOT, 0.90, 0.0, fixed)
	# Fourteen sides are useful on bolts; on a deposit they advertise the
	# primitive.  The soot edge should be irregular from texture, not polygonal.
	(halo.mesh as CylinderMesh).radial_segments = 32
	halo.rotation_degrees.x = 90
	halo.material_override = smat("soot", _soot_tint())

	# Hairline failures start at the hot iron and spend themselves in plaster.
	# They are separate geometry only until the soot batch is merged below.
	for entry in [
			[Vector2(-0.158, 0.112), 0.086, -31.0],
			[Vector2(0.161, 0.071), 0.074, 24.0],
			[Vector2(-0.139, -0.128), 0.063, 38.0],
			[Vector2(0.144, -0.119), 0.078, -34.0],
	]:
		var crack := _box_part(fixed, Vector3(float(entry[1]), 0.004, 0.002),
				Vector3(entry[0].x, CENTRE_Y + entry[0].y, -0.004), SOOT)
		crack.rotation_degrees.z = float(entry[2])
		crack.material_override = smat("soot", _soot_tint())

	# The dark tube sits behind three nested iron rings.  Buckley's 1911
	# fitting used rings that could be removed for different pipe diameters;
	# all remain here because the 1928 reopening closed the penetration.
	var throat := make_cyl(0.133, 0.133, 0.036,
			Vector3(0, CENTRE_Y, -0.038), IRON, 0.62, 0.35, fixed)
	throat.rotation_degrees.x = 90
	throat.material_override = smat("cast_iron", _iron_tint())
	for ring_spec in [[0.145, 0.010, -0.061], [0.108, 0.010, -0.068],
			[0.078, 0.008, -0.075]]:
		var ring := make_ring(float(ring_spec[0]), float(ring_spec[1]),
				Vector3(0, CENTRE_Y, float(ring_spec[2])), IRON,
				0.62, 0.35, fixed)
		ring.rotation_degrees.x = 90
		ring.material_override = smat("cast_iron", _iron_tint())

	# The closure is the only moving piece.  Keep it outside the static merge:
	# once merged, a plate cannot betray a knock with its shadow edge.
	_cap = Node3D.new()
	_cap.name = "ClosurePlate"
	_cap.position = Vector3(0, CENTRE_Y, -0.083)
	add_child(_cap)
	var closure := make_cyl(0.072, 0.072, 0.012, Vector3.ZERO,
			IRON, 0.62, 0.35, _cap)
	closure.rotation_degrees.x = 90
	closure.material_override = smat("cast_iron", _iron_tint())
	var pull := _box_part(_cap, Vector3(0.052, 0.018, 0.014),
			Vector3(0, -0.010, -0.013), IRON)
	pull.material_override = smat("cast_iron", _iron_tint())

	merge_static(fixed)
	merge_static(_cap)
	_knock = make_emitter("knock", -12.0)
	_knock.pitch_scale = 0.62  # muffled through a full masonry stack
	_draft = make_emitter("hum_loop", -60.0, true)
	_draft.pitch_scale = 0.35
	_draft.max_distance = 10.0


func _start_normal_function() -> void:
	state = PState.OPERATING
	_draft_loop()


func _draft_loop() -> void:
	# Five random timers launched in one frame could still cluster.  A floor-
	# derived first delay makes the ordinary building quiet by construction;
	# later breaths keep enough drift not to become a metronome.
	var floor_no := int(unit.left(1)) if unit.length() >= 1 else 5
	await get_tree().create_timer(3.0 + float(floor_no) * 2.7, false).timeout
	while is_inside_tree():
		await get_tree().create_timer(rng.randf_range(24.0, 48.0), false).timeout
		if not is_inside_tree() or state != PState.OPERATING:
			continue
		# This is resonance through an imperfect century-old closure, not an
		# open pipe into the room.  Six decibels below the inherited swell.
		create_tween().tween_property(_draft, "volume_db", -32.0, 1.7)
		await get_tree().create_timer(2.4, false).timeout
		if is_inside_tree():
			create_tween().tween_property(_draft, "volume_db", -60.0, 2.2)


func _perform_synced_event(_index: int, accent: float, pitch: float) -> void:
	_knock.volume_db = -12.0 + linear_to_db(clampf(accent, 0.2, 1.0))
	_knock.pitch_scale = clampf(0.62 * pow(2.0, pitch * 0.1 / 12.0), 0.5, 0.8)
	_knock.play()
	if _settle and _settle.is_valid():
		_settle.kill()
	_settle = create_tween()
	_settle.tween_method(set_knock_pose, 0.0,
			clampf(0.55 + accent * 0.45, 0.0, 1.0), 0.055)
	_settle.tween_method(set_knock_pose,
			clampf(0.55 + accent * 0.45, 0.0, 1.0), 0.0, 0.24) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Stable inspection/test pose.  The first two-millimetre attempt changed
## pixels but did not read in paired standing-distance renders.  Spinning a
## round plate was equally invisible, so the final three-millimetre settle
## rocks on one lip and lets its annular shadow betray the movement.
func set_knock_pose(amount: float) -> void:
	if not _cap:
		return
	var a := clampf(amount, 0.0, 1.0)
	# A loose bayonet closure also slips within its ring.  Two millimetres of
	# lateral error leaves the final concentric circles subtly wrong after the
	# sound, which reads more reliably than axial travel alone.
	_cap.position.x = 0.002 * a
	_cap.position.y = CENTRE_Y - 0.001 * a
	_cap.position.z = -0.083 - 0.003 * a
	_cap.rotation.x = deg_to_rad(1.60 * a)
	_cap.rotation.z = deg_to_rad(0.40 * a)


func visible_mesh_count() -> int:
	return find_children("*", "MeshInstance3D", true, false).size()


func _iron_tint() -> Color:
	match unit:
		"2C": return Color(0.78, 0.76, 0.72)
		"3C": return Color(0.66, 0.65, 0.62)
		"4C": return Color(0.73, 0.69, 0.63)
		"6C": return Color(0.62, 0.61, 0.58)
		_: return Color(0.70, 0.68, 0.64)


func _soot_tint() -> Color:
	match unit:
		"3C": return Color(0.78, 0.72, 0.66)
		"6C": return Color(0.62, 0.58, 0.54)
		_: return Color(0.70, 0.65, 0.60)


func _box_part(parent: Node3D, size: Vector3, at: Vector3,
		color: Color) -> MeshInstance3D:
	var part := make_box(size, at, color)
	# These coordinates are authored in the requested parent's space.  The
	# default keep_global_transform stranded the finger piece at prop origin
	# when its moving parent already had a 1.44 m / 83 mm transform.
	part.reparent(parent, false)
	return part
