extends Node3D
## Nearby diagnostic: exact native bedding and capsule geometry, no whole-world,
## floor, door, route-owner, natural attendance or artistic acceptance claim.
const Furniture := preload("res://scripts/building/orison_v2_domestic_furniture.gd")
const Completion := "res://data/orison_v2/completion_interiors.json"
const CASES := [
	{"bed": "3D_bed", "route": "res://data/orison_v2/rhea_sato_routine.json", "y": 6.4},
	{"bed": "4D_bed", "route": "res://data/orison_v2/transient_guests_routine.json", "y": 9.6}]
var failures: Array[String] = []
var rows: Array[Dictionary] = []
var inputs: Dictionary = {}
var started := Time.get_ticks_msec()

func _ready() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	if not ok: failures.append(message); push_error(message)

func _run() -> void:
	var directory := OS.get_environment("SHOT_DIR")
	if directory.is_empty() or DirAccess.make_dir_recursive_absolute(directory) != OK:
		get_tree().quit(2); return
	for path: String in [get_script().resource_path, Furniture.PATH, Completion,
		"res://assets/props/bedding.glb", "res://assets/props/bedding.glb.import",
		"res://scripts/building/orison_v2_domestic_furniture.gd"]:
		inputs[path] = FileAccess.get_sha256(path)
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Furniture.PATH))
	var completion: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Completion))
	var factory := Furniture.new()
	for spec: Dictionary in CASES:
		inputs[spec.route] = FileAccess.get_sha256(spec.route)
		var template := ""
		for item: Dictionary in completion.furniture:
			if item.id == spec.bed: template = str(item.template)
		var record: Dictionary = {}
		for item: Dictionary in source.furniture:
			if item.id == template: record = item.duplicate(true)
		_check(not record.is_empty(), "actual template available: " + str(spec.bed))
		if record.is_empty(): continue
		record.id = spec.bed
		var body := StaticBody3D.new(); body.name = spec.bed
		add_child(body)
		# Exact installed identity basis and origin recorded by roster_runtime_02.
		# Both authored anchor yaws cancel the blockout's PI yaw.
		body.global_transform = Transform3D(Basis.IDENTITY, Vector3(14.45, spec.y, -.849998))
		factory._add_bed(body, record)
		var count := 0
		for child in body.get_children():
			if child is CollisionShape3D:
				count += 1
				_check(child.shape is ConcavePolygonShape3D and child.transform.is_equal_approx(Transform3D.IDENTITY), "original native collision transform " + str(spec.bed))
		_check(count == 4, "four original native collision parts " + str(spec.bed))
		await get_tree().physics_frame; await get_tree().physics_frame
		var route: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(spec.route))
		var door := Vector3.ZERO; var bed := Vector3.ZERO; var old := Vector3.ZERO
		for chain: Array in route.paths:
			for node: Array in chain:
				if str(node[0]).ends_with("main_bed_door_b"): door = Vector3(node[1], node[2], node[3])
				if node[0] == "bed": bed = Vector3(node[1], node[2], node[3])
				if node[0] == "bed_approach": old = Vector3(node[1], node[2], node[3])
		_check(door != Vector3.ZERO and bed != Vector3.ZERO and old != Vector3.ZERO, "original route points found " + str(spec.bed))
		var paths := {
			"original_direct_negative": [door, bed],
			"first_repair_negative": [door, Vector3(-13.42, spec.y, -9.70), bed],
			"wider_single": [door, Vector3(-13.20, spec.y, -9.96), bed],
			"wider_deep_single": [door, Vector3(-13.20, spec.y, -10.06), bed],
			"wider_dogleg": [door, Vector3(-13.20, spec.y, -9.55), Vector3(-13.20, spec.y, -9.96), bed]}
		for label: String in paths:
			var result := _inspect_path(paths[label])
			result.merge({"bed": spec.bed, "template": template, "variant": factory._bed_variant(record),
				"label": label, "route_points": paths[label], "transform": body.global_transform, "shape_count": count})
			rows.append(result)
			if label.ends_with("negative"): _check(not result.clear, "negative control reproduces " + str(spec.bed) + "/" + label)
			else: _check(result.clear, "candidate native bed clearance " + str(spec.bed) + "/" + label)
		body.queue_free(); await get_tree().physics_frame; await get_tree().physics_frame
	var stable := true
	for path: String in inputs: stable = stable and FileAccess.get_sha256(path) == inputs[path]
	_check(stable, "all consumed source inputs stayed frozen")
	var output := {"evidence_kind": "diagnostic", "scope": "native bed only; no floor, doors or route walking", "passed": failures.is_empty(),
		"capsule_radius": .30, "capsule_height": 1.40, "floor_offset": .25, "sample_spacing_max": .01,
		"continuous_sweep_both_directions": true, "route_to_world": "(-x, y, -z-11.65), matching installed runtime02",
		"inputs": inputs, "rows": rows, "failures": failures, "elapsed_ms": Time.get_ticks_msec() - started}
	var file := FileAccess.open(directory.path_join("bed_clearance.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(output, "\t")); file.close()
	print("HARUKIYA BED PREFLIGHT: ", "PASS" if failures.is_empty() else "FAIL", " rows=", rows.size())
	get_tree().quit(0 if failures.is_empty() else 1)

func _world(point: Vector3) -> Vector3:
	return Vector3(-point.x, point.y, -point.z - 11.65)

func _inspect_path(points: Array) -> Dictionary:
	var shape := CapsuleShape3D.new(); shape.radius = .30; shape.height = 1.40
	var query := PhysicsShapeQueryParameters3D.new(); query.shape = shape; query.collision_mask = 1
	var space := get_world_3d().direct_space_state
	var blocked: Array[Dictionary] = []; var sweeps: Array[Dictionary] = []; var samples := 0
	for index in range(1, points.size()):
		var a := _world(points[index - 1]) + Vector3.UP * .95
		var b := _world(points[index]) + Vector3.UP * .95
		var steps := maxi(1, ceili(a.distance_to(b) / .01))
		for step in range(steps + 1):
			query.transform = Transform3D(Basis.IDENTITY, a.lerp(b, float(step) / steps)); query.motion = Vector3.ZERO
			var hits := space.intersect_shape(query, 8); samples += 1
			if not hits.is_empty(): blocked.append({"edge": index, "fraction": float(step) / steps, "position": query.transform.origin, "body": str(hits[0].collider.name)})
		for reverse: bool in [false, true]:
			query.transform = Transform3D(Basis.IDENTITY, b if reverse else a)
			query.motion = (a - b) if reverse else (b - a)
			var sweep := space.cast_motion(query)
			sweeps.append({"edge": index, "reverse": reverse, "safe_fraction": sweep[0], "unsafe_fraction": sweep[1]})
	var clear := blocked.is_empty()
	for sweep: Dictionary in sweeps: clear = clear and sweep.safe_fraction >= .999999
	return {"clear": clear, "samples": samples, "blocked": blocked, "sweeps": sweeps}
