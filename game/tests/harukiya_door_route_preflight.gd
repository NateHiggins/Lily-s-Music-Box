extends Node3D
## Nearby fitted-leaf diagnostic. No floor, casing, motor or attendance claim.
const Factory := preload("res://scripts/building/orison_v2_domestic_doors.gd")
const LAYOUT := "res://data/orison_v2_blockout.json"
const COMPLETION := "res://data/orison_v2/completion_interiors.json"
const ROUTES := ["res://data/orison_v2/rhea_sato_routine.json",
	"res://data/orison_v2/transient_guests_routine.json"]
var failures: Array[String] = []
var rows: Array[Dictionary] = []
var inputs: Dictionary = {}

func _ready() -> void:
	_run.call_deferred()

func _check(ok: bool, label: String) -> void:
	if not ok: failures.append(label); push_error(label)

func _run() -> void:
	var directory := OS.get_environment("SHOT_DIR")
	if directory.is_empty() or DirAccess.make_dir_recursive_absolute(directory) != OK:
		get_tree().quit(2); return
	for path: String in [get_script().resource_path, LAYOUT, COMPLETION,
		"res://scripts/building/orison_v2_domestic_doors.gd", "res://scripts/building/orison_v2_fitted_door.gd",
		"res://scripts/props/door_prop.gd", "res://assets/props/domestic_door_leaves.glb",
		"res://assets/props/door_knob_set.glb", "res://assets/props/door_butt_hinge.glb"] + ROUTES:
		inputs[path] = FileAccess.get_sha256(path)
	var prior: Dictionary = RealityState.data
	var owned := RealityState.begin_preview_campaign(self)
	_check(owned, "exclusive nonpersistent door fixture")
	if not owned: get_tree().quit(2); return
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT))
	var completion: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(COMPLETION))
	for route_path: String in ROUTES:
		var route: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(route_path))
		var chain: Array = []
		for candidate: Array in route.paths:
			if candidate[0][0] == "kitchen" and candidate[-1][0] == "private_hall": chain = candidate
		_check(chain.size() == 5, "five-point repaired kitchen chain " + route.resident)
		if chain.size() != 5: continue
		var identity := "F0" + str(route.unit)[0] + "_D_PRIVATE_HALL_BATH_DOOR"
		var record: Dictionary = {}
		var spec: Dictionary = {}
		for item: Dictionary in layout.doors:
			if item.id == identity: record = item
		for item: Dictionary in completion.doors:
			if item.id == identity: spec = item.duplicate(true)
		_check(not record.is_empty() and not spec.is_empty(), "original door records " + identity)
		if record.is_empty() or spec.is_empty(): continue
		# Production anchor transform in the authored blockout frame, no scale.
		var anchor := Node3D.new(); anchor.name = identity
		anchor.position = Vector3(record.center[0], chain[0][2], record.center[1])
		anchor.rotation.y = float(record.yaw)
		var placeholder := Node3D.new(); placeholder.name = "Hinge"; anchor.add_child(placeholder)
		add_child(anchor)
		# Explicit initial open fixture; original geometry/hinge/stop remain owned by factory.
		spec.leaf_state = "open"
		_check(Factory.new().mount_specs(OrisonV2AnchorAdapter.new(self), layout, {identity: spec}), "production fitted door mounted " + identity)
		await get_tree().physics_frame; await get_tree().physics_frame
		var door := anchor.get_node_or_null(identity + "_Leaf") as DoorProp
		_check(door != null and door.open and not door._moving, "actual leaf fully open " + identity)
		if door == null: anchor.queue_free(); continue
		var points: Array[Vector3] = []
		for node: Array in chain: points.append(Vector3(node[1], node[2], node[3]))
		var original := points.duplicate(); original.remove_at(3)
		for label: String in ["original_negative", "repaired", "early_turn_forward", "early_turn_reverse"]:
			var probe := original if label == "original_negative" else points.duplicate()
			# Bound the route motor's existing 4cm waypoint-pop shortcut in both directions.
			if label.begins_with("early_turn"):
				var neighbour: Vector3 = points[2] if label.ends_with("forward") else points[4]
				probe[3] = points[3].move_toward(neighbour, .04)
			var result := _inspect_path(probe)
			result.merge({"door": identity, "label": label, "points": probe,
				"anchor": anchor.transform, "leaf": door._body.global_transform,
				"angle": door._body.rotation.y, "stop": door.motion_target_angle(true)})
			rows.append(result)
			_check(not result.clear if label == "original_negative" else result.clear, "native leaf clearance " + identity + "/" + label)
		anchor.queue_free(); await get_tree().physics_frame; await get_tree().physics_frame
	_check(RealityState.end_preview_campaign(self) and is_same(prior, RealityState.data), "campaign custody restored")
	for path: String in inputs: _check(inputs[path] == FileAccess.get_sha256(path), "frozen input " + path)
	var file := FileAccess.open(directory.path_join("door_clearance.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"evidence_kind": "diagnostic", "passed": failures.is_empty(),
		"scope": "actual fitted open leaves only in authored frame; no floor/casing/motor/attendance proof",
		"capsule_radius": .30, "capsule_height": 1.40, "sample_spacing_max": .01,
		"continuous_sweep_both_directions": true, "waypoint_early_turn_m": .04,
		"inputs": inputs, "rows": rows, "failures": failures}, "\t")); file.close()
	print("HARUKIYA DOOR PREFLIGHT: ", "PASS" if failures.is_empty() else "FAIL", " rows=", rows.size())
	get_tree().quit(0 if failures.is_empty() else 1)

func _inspect_path(points: Array) -> Dictionary:
	var capsule := CapsuleShape3D.new(); capsule.radius = .30; capsule.height = 1.40
	var query := PhysicsShapeQueryParameters3D.new(); query.shape = capsule; query.collision_mask = 1
	var space := get_world_3d().direct_space_state
	var blocked: Array[Dictionary] = []; var sweeps: Array[Dictionary] = []; var samples := 0
	for index in range(1, points.size()):
		var a: Vector3 = points[index - 1] + Vector3.UP * .95
		var b: Vector3 = points[index] + Vector3.UP * .95
		var steps := maxi(1, ceili(a.distance_to(b) / .01))
		for step in range(steps + 1):
			query.transform = Transform3D(Basis.IDENTITY, a.lerp(b, float(step) / steps)); query.motion = Vector3.ZERO
			var hits := space.intersect_shape(query, 8); samples += 1
			if not hits.is_empty(): blocked.append({"edge": index, "fraction": float(step) / steps, "body": str(hits[0].collider.name)})
		for reverse: bool in [false, true]:
			query.transform = Transform3D(Basis.IDENTITY, b if reverse else a); query.motion = (a - b) if reverse else (b - a)
			var sweep := space.cast_motion(query)
			sweeps.append({"edge": index, "reverse": reverse, "safe_fraction": sweep[0]})
	var clear := blocked.is_empty()
	for sweep: Dictionary in sweeps: clear = clear and sweep.safe_fraction >= .999999
	return {"clear": clear, "samples": samples, "blocked": blocked, "sweeps": sweeps}
