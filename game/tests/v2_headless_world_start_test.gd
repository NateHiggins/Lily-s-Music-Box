extends Node
## The full production V2 world starts under Godot's headless (dummy) renderer.
## That renderer keeps no MultiMesh instance data, so owners that read their
## poses back went through MultiMeshPoses. Before it, the front trim splice
## read every millwork pose as identity and refused startup. Writes a
## schema-2 runtime_contract to RECEIPT_DIR.
const MultiMeshPoses := preload("res://scripts/rendering/multimesh_poses.gd")
const Runtime := preload("res://scenes/building/orison_v2_runtime.tscn")

var checks: Array[Dictionary] = []
var failures: Array[String] = []
var started_ms := 0


func check(ok: bool, label: String, detail: Variant = null) -> bool:
	checks.append({"label": label, "ok": ok, "detail": str(detail) if detail != null else ""})
	if not ok:
		failures.append(label + ("" if detail == null else ": " + str(detail)))
		push_error("V2 HEADLESS WORLD START: " + label + " " + str(detail))
	return ok


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	started_ms = Time.get_ticks_msec()
	check(DisplayServer.get_name() == "headless", "this proof runs under the headless renderer", DisplayServer.get_name())
	_unit_checks()
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928, 11, 10, 20 * 60)
	var world: OrisonV2RuntimeRoot = Runtime.instantiate()
	add_child(world)
	await get_tree().create_timer(0.5).timeout
	if check(not world.startup_failed, "the full production V2 world starts headless", world.startup_failure_reason):
		_world_checks(world)
	world.shutdown_for_tests()
	remove_child(world)
	world.free()
	await get_tree().create_timer(0.25).timeout
	_write_receipt()
	print("V2 HEADLESS WORLD START: %s; %d checks; %d failures" % ["PASS" if failures.is_empty() else "FAIL", checks.size(), failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)


func _unit_checks() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = 3
	var a := Transform3D(Basis(Vector3.UP, 0.4), Vector3(1, 2, 3))
	var b := Transform3D(Basis.IDENTITY.scaled(Vector3(2, 1, 1)), Vector3(-4, 0, 9))
	MultiMeshPoses.set_pose(mm, 0, a)
	MultiMeshPoses.set_pose(mm, 2, b)
	check(MultiMeshPoses.pose(mm, 0).is_equal_approx(a) and MultiMeshPoses.pose(mm, 2).is_equal_approx(b),
			"poses written through MultiMeshPoses read back exactly")
	mm.instance_count = 5
	MultiMeshPoses.set_pose(mm, 4, a)
	check(MultiMeshPoses.pose(mm, 4).is_equal_approx(a) and MultiMeshPoses.pose(mm, 0).is_equal_approx(a),
			"growing the instance count keeps earlier poses")


func _world_checks(world: OrisonV2RuntimeRoot) -> void:
	check(world.adapter.root.has_meta("v2_native_front_trim_fittings"), "the front trim splice installed")
	# Millwork read back through the helper is real geometry, not identity.
	var batches: Array = world.adapter.root.find_children("HistoricMillwork", "MultiMeshInstance3D", true, false)
	var distinct := {}
	var read := 0
	for batch: MultiMeshInstance3D in batches:
		for index in mini(batch.multimesh.instance_count, 8):
			distinct[str(MultiMeshPoses.pose(batch.multimesh, index).origin.snapped(Vector3.ONE * 0.001))] = true
			read += 1
	check(batches.size() > 4 and distinct.size() > read / 2, "millwork poses read back as distinct real positions", [batches.size(), read, distinct.size()])
	# Radiator section collision is built from read-back poses: it must spread
	# along each radiator, not stack at one origin.
	var spread := 0
	var radiators := 0
	for area: Node in world.find_children("*", "Area3D", true, false):
		var shapes: Array = area.find_children("*", "CollisionShape3D", false, false)
		if shapes.size() < 4 or not area.get_parent() is MultiMeshInstance3D:
			continue
		radiators += 1
		var xs := {}
		for shape: CollisionShape3D in shapes:
			xs[snappedf(shape.transform.origin.x, 0.001)] = true
		if xs.size() == shapes.size():
			spread += 1
	check(radiators > 0 and spread == radiators, "radiator section collision spreads along each radiator", [radiators, spread])
	var faces := world.find_child("StreetEndHoardingFaces", true, false) as MultiMeshInstance3D
	if faces != null:
		check(not MultiMeshPoses.pose(faces.multimesh, 0).origin.is_zero_approx(), "street-end hoarding anchor is a real position")


func _hash(path: String) -> String:
	return FileAccess.get_file_as_string(path).replace("\r\n", "\n").sha256_text()


func _write_receipt() -> void:
	var out := OS.get_environment("RECEIPT_DIR")
	if out.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(out)
	var root := ProjectSettings.globalize_path("res://").get_base_dir().get_base_dir()
	var head: Array = []
	OS.execute("git", ["-C", root, "rev-parse", "HEAD"], head)
	var source: String = get_script().resource_path
	var status := "PASS" if failures.is_empty() else "FAIL"
	var inputs := {}
	for path: String in ["res://scripts/rendering/multimesh_poses.gd", "res://scripts/building/orison_v2_front_trim_fittings.gd", "res://scripts/building/orison_v2_millwork.gd", "res://scripts/props/radiator_prop.gd", "res://scripts/props/radiator_native_assembly.gd"]:
		inputs["game/" + path.trim_prefix("res://")] = _hash(path)
	var receipt := {"schema_version": 2, "evidence_kind": "runtime_contract", "selector": "v2", "production_runtime": true,
		"scope": "Full production V2 world startup under the headless (dummy) renderer, MultiMeshPoses round trips, and read-back millwork, radiator section collision and hoarding anchor poses. No route, save, frame timing or visual claim.",
		"execution": {"completed": true, "exit_code": 0 if failures.is_empty() else 1, "timed_out": false, "elapsed_s": (Time.get_ticks_msec() - started_ms) / 1000.0},
		"source": {"test_path": "game/" + source.trim_prefix("res://"), "test_sha256": _hash(source),
			"repository_head": str(head[0]).strip_edges() if not head.is_empty() else "", "runtime_inputs_sha256": inputs},
		"contracts": {"headless_startup": {"executed": true, "status": status}, "pose_readback": {"executed": true, "status": status}},
		"checks": checks, "failures": failures}
	FileAccess.open(out.path_join("runtime_contract.json"), FileAccess.WRITE).store_string(JSON.stringify(receipt, "\t"))
