extends Node3D
## Nearby loaded collision diagnostic for the recorded book_hose_controls_02 capsule overlap.
const Stock = preload("res://scripts/building/v2_readable_library_stock.gd")
const Movable = preload("res://scripts/props/v2_library_movable.gd")
const Precision = preload("res://scripts/building/v2_contact_precision.gd")
# VariantWriter stores basis rows. Parse the original Variant strings rather
# than feeding those row triples to the column-vector Transform3D constructor.
const OWNER_VARIANT := "Transform3D(-1, 0, 8.742278e-08, 0, 1, 0, -8.742278e-08, 0, -1, 0.48500133, -3.2, -14.9897995)"
const BOOK_VARIANT := "Transform3D(0.584119, 0.74365175, -0.32524922, 0, 0.40071702, 0.91620183, 0.8116679, -0.5351709, 0.23406644, 0.5854539, -2.5712955, -13.917333)"
const EYE_VARIANT := "Transform3D(0.5841183, 0.74365234, -0.32524914, 0, 0.4007167, 0.91620207, 0.8116686, -0.5351704, 0.23406596, 0.43699533, -1.7810313, -13.72422)"
const COPY_ID := "nook_books__Volume0"
const SLOT_ROTATION := Quaternion(0,-.707106828689575,0,.707106828689575)
var precision := Precision.new()
var failures: Array[String] = []
var report: Dictionary = {"evidence_class":"INERT", "scope":"Staged pose/native overlap diagnostic", "failures":[]}

func _ready() -> void:
	call_deferred("_run")

func _exit_tree() -> void:
	precision.release()

func _run() -> void:
	if not _check(precision.bind(get_world_3d()),"native V2 space precision binds"):
		_finish(); return
	var stock := Stock.new()
	if not _check(stock.prepare(),"production native book hulls load"):
		_finish(); return
	if not _check(not stock.load_copy_programme().is_empty(),"production nook copy programme validates"):
		_finish(); return
	var hull := stock.closed_hulls.get(COPY_ID) as ConvexPolygonShape3D
	if not _check(hull != null and hull == stock.closed_hulls.get("wiring") and not hull.points.is_empty(),"recorded nook copy uses the exact loaded wiring closed hull"):
		_finish(); return
	var parsed_owner: Variant = str_to_var(OWNER_VARIANT)
	var parsed_book: Variant = str_to_var(BOOK_VARIANT)
	var parsed_eye: Variant = str_to_var(EYE_VARIANT)
	if not _check(parsed_owner is Transform3D and parsed_book is Transform3D and parsed_eye is Transform3D,"original Transform3D Variant strings parse"):
		_finish(); return
	var owner_pose: Transform3D = parsed_owner
	var book_pose: Transform3D = parsed_book
	var eye_pose: Transform3D = parsed_eye
	# The standing camera's local XZ is zero and inspection preserves the eye
	# origin. Infer the capsule axis from the contemporaneous eye, not an older
	# walking checkpoint. Yaw is immaterial for the upright symmetric capsule.
	var inferred_player_origin := eye_pose.origin - Vector3.UP * PlayerController.STANDING_EYE
	var player := PlayerController.new()
	player.name = "Player"
	player.transform = Transform3D(Basis.IDENTITY,inferred_player_origin)
	add_child(player)
	# This fixture stages the recorded position and holds it while querying.
	# The production collision shape, layer, mask and body stay enabled.
	player.set_physics_process(false)
	var shelf := Node3D.new()
	shelf.name = "RecordedCollectionFrame"
	shelf.transform = owner_pose
	add_child(shelf)
	var book := Movable.new()
	book.name = "RecordedWiringBook"
	book.shelf = shelf
	book.freeze = true
	book.transform = owner_pose.affine_inverse() * book_pose
	shelf.add_child(book)
	var solid := CollisionShape3D.new()
	solid.name = "ClosedBindingSolid"
	solid.shape = hull
	solid.transform = stock.closed_poses[COPY_ID]
	book.add_child(solid)
	book._solids.append(solid)
	for frame in 3: await get_tree().physics_frame
	_check(not player._shape.disabled and is_equal_approx(player._capsule.radius,PlayerController.BODY_RADIUS) and is_equal_approx(player._capsule.height,PlayerController.STANDING_HEIGHT) and player.collision_layer == 1,"full production standing capsule enabled")
	_check(player.get_collision_exceptions().is_empty() and book.get_collision_exceptions().is_empty() and book._query_exclusions() == [book.get_rid()],"only the queried book itself is excluded")
	var original: Transform3D = book.global_transform
	var current: Basis = book.basis
	var wanted := Basis(SLOT_ROTATION.normalized())
	var proposal: Basis = _next_gesture(current,wanted)
	var steps: int = _increments(current,proposal)
	var first := Transform3D(shelf.global_basis * current.slerp(proposal,1. / float(steps)),original.origin)
	var original_hits := _hits(book,solid,original)
	var first_hits := _hits(book,solid,first)
	var player_rid: int = player.get_rid().get_id()
	_check(_has_rid(original_hits,player_rid) and not book._clear_pose(original),"fresh current overlap names actual Player capsule")
	_check(_has_rid(first_hits,player_rid) and not book._clear_pose(first),"fresh first precision step overlaps actual Player capsule")
	var radius := 0.0
	for vertex in hull.points:
		radius = maxf(radius,(original.basis * (solid.transform * vertex)).length())
	var radial: Vector3 = original.origin - player._shape.global_position
	radial.y = 0.0
	var initial_separation := radial.length()
	var separation: float = PlayerController.BODY_RADIUS + radius + .002
	if not _check(radius > 0.0 and initial_separation > 0.0 and initial_separation < separation,"recorded origin requires radial clearance"):
		_finish(); return
	var clear_origin: Vector3 = original.origin + radial.normalized() * (separation - initial_separation)
	var clear_start := Transform3D(original.basis,clear_origin)
	var clear_first := Transform3D(first.basis,clear_origin)
	var clear_start_hits := _hits(book,solid,clear_start)
	var clear_first_hits := _hits(book,solid,clear_first)
	_check(clear_start_hits.is_empty() and book._clear_pose(clear_start),"clearance goal has no native overlap")
	_check(clear_first_hits.is_empty() and book._clear_pose(clear_first),"same first precision step clears after outward translation")
	var samples := 0
	var first_blocker: Array[Dictionary] = []
	var all_clear := true
	for gesture in 100:
		if _rotation_error(current,wanted).length() < .003: break
		proposal = _next_gesture(current,wanted)
		steps = _increments(current,proposal)
		for index in range(1,steps+1):
			var pose := Transform3D(shelf.global_basis * current.slerp(proposal,float(index)/float(steps)),clear_origin)
			samples += 1
			if not book._clear_pose(pose):
				first_blocker = _hits(book,solid,pose)
				all_clear = false
				break
		if not all_clear: break
		current = proposal
	var remaining := _rotation_error(current,wanted).length()
	_check(all_clear and samples > 0 and remaining < .003,"bounded original precision sweep clears to the original slot orientation")
	_check(book._last_motion.is_empty() and book.global_transform.is_equal_approx(original),"queries establish fresh overlap without moving book or consulting stale body sweep")
	report.merge({"player_pose_basis":"upright identity yaw for symmetric capsule","player_origin_inferred_from_standing_eye":str(inferred_player_origin),"recorded_inspection_eye":EYE_VARIANT,"recorded_owner_pose":OWNER_VARIANT,"recorded_book_pose":BOOK_VARIANT,"player_rid":player_rid,"capsule_radius":player._capsule.radius,"capsule_height":player._capsule.height,"capsule_pose":str(player._shape.global_transform),"book_pose":str(original),"slot_quaternion":str(SLOT_ROTATION),"native_vertices":hull.points.size(),"native_radius_m":radius,"before_separation_m":initial_separation,"goal_separation_m":separation,"goal_world":str(clear_origin),"goal_owner":str(shelf.to_local(clear_origin)),"original_hits":original_hits,"original_first_step":str(first),"original_first_step_hits":first_hits,"clearance_hits":clear_start_hits,"clearance_first_step_hits":clear_first_hits,"sweep_samples":samples,"first_sweep_blocker":first_blocker,"remaining_rotation_radians":remaining})
	_finish()

func _rotation_error(current: Basis, wanted: Basis) -> Vector3:
	var error := Quaternion(wanted * current.inverse()).normalized()
	var angle := error.get_angle()
	if angle > PI: angle -= TAU
	return Vector3.ZERO if absf(angle) < .000001 else error.get_axis() * angle

func _next_gesture(current: Basis, wanted: Basis) -> Basis:
	var error := _rotation_error(current,wanted)
	var axis := error.abs().max_axis_index()
	var unit := Vector3.ZERO
	unit[axis] = 1.0
	# Existing route input scales +/-20 px by .008 rad/px. The existing
	# body write orthonormalizes the requested basis and retains scale.
	var raw := Basis(unit,clampf(error[axis]/.008,-20.,20.)*.008) * current
	return raw.orthonormalized().scaled(current.get_scale())

func _increments(current: Basis, next: Basis) -> int:
	return maxi(1,ceili(current.get_rotation_quaternion().angle_to(next.get_rotation_quaternion())/.025))

func _hits(book: RigidBody3D, solid: CollisionShape3D, pose: Transform3D) -> Array[Dictionary]:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = solid.shape
	query.transform = pose * solid.transform
	query.margin = .00001
	query.collision_mask = book.collision_mask
	query.exclude = [book.get_rid()]
	var rows: Array[Dictionary] = []
	for hit: Dictionary in get_world_3d().direct_space_state.intersect_shape(query,8):
		var node: Node = hit.get("collider") as Node
		var rid: RID = hit.rid
		rows.append({"path":str(node.get_path()) if is_instance_valid(node) else "", "id":hit.collider_id, "rid":rid.get_id(), "shape":hit.shape})
	return rows

func _has_rid(rows: Array[Dictionary], rid: int) -> bool:
	for row: Dictionary in rows:
		if row.rid == rid: return true
	return false

func _check(ok: bool, label: String) -> bool:
	if not ok: failures.append(label)
	return ok

func _finish() -> void:
	var directory := OS.get_environment("SHOT_DIR")
	if _check(not directory.is_empty(),"fresh report directory supplied"):
		DirAccess.make_dir_recursive_absolute(directory)
		var file := FileAccess.open(directory.path_join("book_player_clearance.json"),FileAccess.WRITE)
		if _check(file != null,"diagnostic record opens"):
			report["failures"] = failures
			report["passed"] = failures.is_empty()
			file.store_string(JSON.stringify(report,"\t"))
			_check(file.get_error() == OK,"diagnostic record writes")
			file.close()
	print("BOOK PLAYER CLEARANCE: ","PASS" if failures.is_empty() else "FAIL"," ",failures)
	get_tree().quit(0 if failures.is_empty() else 1)
