extends RefCounted
## External test helper awaiting root integration. No run or runtime proof yet.
## Call after all sixteen source packs pass and the all16 cache is installed.
const AssetsScript := preload("res://scripts/dream/critters/dream_critter_blender_assets.gd")


static func run_checks(admitted: RefCounted, report_check: Callable) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var listener := _manifest(1, "crystal_listener")
	var crab := _manifest(2, "fold_crab")
	var euplotes := _manifest(7, "euplotes")
	if listener.is_empty() or crab.is_empty() or euplotes.is_empty():
		_record(results, report_check, false, "ancillary controls load actual delivered manifests", "")
		return results
	var cache := AssetsScript.new()
	var valid_props: Array = cache._read_pose_rows(listener.prop_anchors, 5, "Listener props")
	_record(results, report_check, valid_props.size() == 19 and cache.error.is_empty(),
		"actual listener prop anchors satisfy nineteen poses", cache.error)
	var bad_props: Array = listener.prop_anchors.duplicate(true)
	bad_props.pop_back()
	cache = AssetsScript.new()
	_record(results, report_check, cache._read_pose_rows(bad_props, 5, "Listener props").is_empty()
		and not cache.error.is_empty(), "missing listener phase-anchor row refused", cache.error)
	bad_props = listener.prop_anchors.duplicate(true)
	bad_props[8][2][0] = INF
	cache = AssetsScript.new()
	_record(results, report_check, cache._read_pose_rows(bad_props, 5, "Listener props").is_empty()
		and not cache.error.is_empty(), "non-finite listener anchor refused", cache.error)
	cache = AssetsScript.new()
	var valid_joints: Array = cache._read_rest_chains(crab.rest_joint_chains, 8, 5, "Fold joints")
	_record(results, report_check, valid_joints.size() == 19 and valid_joints[0].size() == 40
		and cache.error.is_empty(), "actual Fold eight joint chains become forty atlas rows", cache.error)
	var bad_joints: Array = crab.rest_joint_chains.duplicate(true)
	bad_joints[6].pop_back()
	cache = AssetsScript.new()
	_record(results, report_check, cache._read_rest_chains(bad_joints, 8, 5, "Fold joints").is_empty()
		and not cache.error.is_empty(), "truncated Fold chain refused", cache.error)
	bad_joints = crab.rest_joint_chains.duplicate(true)
	bad_joints[0][2] = bad_joints[0][1].duplicate()
	cache = AssetsScript.new()
	_record(results, report_check, cache._read_rest_chains(bad_joints, 8, 5, "Fold joints").is_empty()
		and not cache.error.is_empty(), "zero-length Fold joint segment refused", cache.error)
	var bad_mouth: Array = crab.rest_manipulator_chains.duplicate(true)
	bad_mouth[1][2][1] = NAN
	cache = AssetsScript.new()
	_record(results, report_check, cache._read_rest_chains(bad_mouth, 2, 3, "Fold mouths").is_empty()
		and not cache.error.is_empty(), "non-finite Fold mouth rest point refused", cache.error)
	cache = AssetsScript.new()
	_record(results, report_check, cache._valid_binding(2, Vector2(-20, 0.52))
		and cache._valid_binding(2, Vector2(-21, 1))
		and not cache._valid_binding(2, Vector2(-19, 0.52))
		and not cache._valid_binding(2, Vector2(-7, 0.52))
		and not cache._valid_binding(2, Vector2(8, 0.52)),
		"Fold jaw roles admitted while undeclared role gaps are refused", "")
	_record(results, report_check, cache._valid_binding(7, Vector2(-7, 1))
		and not cache._valid_binding(7, Vector2(-8, 1))
		and not cache._valid_binding(7, Vector2(0, 1)),
		"Euplotes has six oral branches and no CPU foot roles", "")
	var row: Dictionary = admitted.templates[2][1]
	cache = AssetsScript.new()
	_record(results, report_check, cache._validate_fold_endpoints(row, "admitted Fold LOD1"),
		"actual Fold GLB retains endpoints and mouth rest geometry", cache.error)
	var moved: Dictionary = row.duplicate(true)
	var poses: Array = []
	for pose: PackedVector3Array in row.pose_positions:
		poses.append(pose.duplicate())
	moved.pose_positions = poses
	var jaw_vertex := -1
	for vertex in (row.leg_bind as PackedVector2Array).size():
		if int(roundf(row.leg_bind[vertex].x)) == -20:
			jaw_vertex = vertex
			break
	if jaw_vertex >= 0:
		var corrupted_pose: PackedVector3Array = moved.pose_positions[8]
		corrupted_pose[jaw_vertex] += Vector3(0.01, 0, 0)
		moved.pose_positions[8] = corrupted_pose
		cache = AssetsScript.new()
		_record(results, report_check, not cache._validate_fold_endpoints(moved, "corrupted Fold law_half")
			and not cache.error.is_empty(), "moving Fold jaw in crease atlas refused", cache.error)
	else:
		_record(results, report_check, false, "moving Fold jaw negative has actual source role", "")
	# These corrupt a temporary manifest only. The GLB and production manifests
	# remain untouched; refusal is required before importing that valid GLB.
	var bad_crab: Dictionary = crab.duplicate(true)
	bad_crab.rest_joint_chains[0][0][0] += 0.05
	_manifest_refusal(results, report_check, bad_crab, 2, "fold_crab", "shifted canonical Fold socket refused")
	bad_crab = crab.duplicate(true)
	bad_crab.foot_anchors[18][7][1] += 0.05
	_manifest_refusal(results, report_check, bad_crab, 2, "fold_crab", "moving Fold phase foot anchor refused")
	var bad_euplotes: Dictionary = euplotes.duplicate(true)
	bad_euplotes.cirrus_controls[13] = 6
	_manifest_refusal(results, report_check, bad_euplotes, 7, "euplotes", "wrong fourteen-to-eight Euplotes mapping refused")
	return results


static func _manifest(kind: int, species: String) -> Dictionary:
	var path := "res://assets/dream/critters_blender/%s/%s.manifest.json" % [species, species]
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not value is Dictionary or int(value.get("species_id", -1)) != kind:
		return {}
	return value


static func _manifest_refusal(results: Array[Dictionary], report_check: Callable,
		manifest: Dictionary, kind: int, species: String, label: String) -> void:
	var directory := "user://blender_decoder_negative_controls"
	var made := DirAccess.make_dir_recursive_absolute(directory)
	if made != OK and made != ERR_ALREADY_EXISTS:
		_record(results, report_check, false, label, "cannot create owned test fixture directory")
		return
	var path := directory.path_join("case_%d_%d.json" % [kind, Time.get_ticks_usec()])
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_record(results, report_check, false, label, "cannot create owned temporary manifest")
		return
	file.store_string(JSON.stringify(manifest))
	file.flush()
	var written := file.get_error() == OK
	file.close()
	var cache := AssetsScript.new()
	var result: Dictionary = {}
	if written:
		result = cache._read_template(path, "res://assets/dream/critters_blender/" + species + "/", kind, 1)
	var removed := DirAccess.remove_absolute(path) == OK
	_record(results, report_check, written and removed and result.is_empty() and not cache.error.is_empty(),
		label, cache.error)


static func _record(results: Array[Dictionary], report_check: Callable,
		passed: bool, label: String, error: String) -> void:
	results.append({"passed": passed, "label": label, "decoder_error": error})
	report_check.call(passed, label)
