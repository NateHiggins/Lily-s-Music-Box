extends Node3D
## Synthetic World3D contract controls. Actual F01 actor/lift and the existing
## 4D/Passage regressions remain separate required consumer runs.

class UnbuiltDoor:
	extends DoorProp
	func _ready() -> void:
		pass


const START := Vector3(-0.5, 0.03, 0)
const GOAL := Vector3(0.5, 0.03, 0)
var checks: Array = []
var failures := 0
var viewport: SubViewport
var nav: ResidentNav
var floor_body: StaticBody3D


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.size = Vector2i(64, 64)
	add_child(viewport)
	floor_body = _box(viewport, "SupportFloor", Vector3(0, -0.10, 0), Vector3(8, 0.20, 8))
	nav = ResidentNav.new()
	viewport.add_child(nav)
	nav.build(_layout())
	await _settle()
	_check("before validation retains graph", not _direct(START, GOAL))
	nav.validate_with_collision(viewport.find_world_3d())
	_check("validated clear short segment uses exact endpoints", _direct(START, GOAL))
	_check("reverse clear short segment uses exact endpoints", _direct(GOAL, START))
	_check("length bound retains graph", not _direct(Vector3(-0.7, 0.03, 0), Vector3(0.7, 0.03, 0)))
	_check("exact maximum length is admitted", _direct(Vector3(-0.625, 0.03, 0), Vector3(0.625, 0.03, 0)))
	_check("just beyond maximum length retains graph", not _direct(Vector3(-0.625, 0.03, 0), Vector3(0.6251, 0.03, 0)))
	_check("foot above upper bound retains graph", not _direct(START + Vector3.UP * 0.051, GOAL + Vector3.UP * 0.051))
	# The physical floor extends to +/-4, but the authored slab ends at +/-3.
	# These centres fit the plan while the conservative .33 m rim does not.
	_check("authored outer slab rim prevents outward shortcut", not _direct(Vector3(2, 0.03, 0), Vector3(2.8, 0.03, 0)))
	_check("authored outer slab rim prevents reverse shortcut", not _direct(Vector3(2.8, 0.03, 0), Vector3(2, 0.03, 0)))
	_check("different endpoint height retains graph", not _direct(START, GOAL + Vector3.UP * 0.02))
	_check("slab datum is not an actor foot offset", not _direct(START - Vector3.UP * 0.03, GOAL - Vector3.UP * 0.03))
	_check("envelope contains production Body capsule", _contains_body_contract())
	await _public_refusal_controls()

	# This obstacle is off the centre shin/chest rays, but within the envelope.
	var jamb := _box(viewport, "OffCentreJamb", Vector3(0, 0.8, 0.25), Vector3(0.08, 0.3, 0.08))
	await _settle()
	var centre_ray := PhysicsRayQueryParameters3D.create(START + Vector3.UP * 0.8, GOAL + Vector3.UP * 0.8)
	_check("jamb control leaves centre ray clear", viewport.find_world_3d().direct_space_state.intersect_ray(centre_ray).is_empty())
	_check("new current-world side obstruction prevents shortcut", not _direct(START, GOAL))
	jamb.queue_free()
	await _settle()
	_check("removed side obstruction restores shortcut", _direct(START, GOAL))

	var overlap := _box(viewport, "StartOverlap", START + Vector3.UP * 0.8, Vector3(0.1, 0.2, 0.1))
	await _settle()
	_check("initial overlap prevents shortcut", not _direct(START, GOAL))
	_check("final overlap prevents reverse shortcut", not _direct(GOAL, START))
	overlap.queue_free()
	await _settle()

	# Real DoorProp type/ancestry, with construction disabled only in this
	# synthetic control. This makes no claim about actual leaf state changes.
	var door_owner := UnbuiltDoor.new()
	viewport.add_child(door_owner)
	door_owner.set_process(false)
	door_owner.set_physics_process(false)
	_box(door_owner, "ClosedLeafControl", Vector3(0, 0.8, 0), Vector3(0.08, 1.5, 0.8))
	await _settle()
	_check("legacy graph rays excuse DoorProp control", not nav._ray_blocked(viewport.find_world_3d().direct_space_state, START, GOAL))
	_check("physical closed leaf prevents shortcut", not _direct(START, GOAL))
	door_owner.queue_free()
	await _settle()

	var entry: Dictionary = nav.floors["F01"]
	# Supply the authored fixture slabs on the original-source omission too.
	entry["slabs"] = _layout()["floors"][0]["slabs"].duplicate(true)
	entry.walls = [{"a": [0.0, -2.0], "b": [0.0, 2.0], "t": 0.18, "openings": []}]
	_check("authored wall blocks shortcut without runtime wall", not _direct(START, GOAL))
	entry.walls = []
	entry.slabs[0].holes = [[-0.02, -0.02, 0.02, 0.02]]
	_check("narrow authored hole blocks complete segment", not _direct(START, GOAL))
	entry.slabs[0].holes = [[-0.02, 0.25, 0.02, 0.27]]
	_check("off-centre authored hole blocks envelope footprint", not _direct(START, GOAL))
	entry.slabs[0].holes = []
	var saved_slabs: Array = entry.slabs
	entry.slabs = []
	_check("missing authored support retains graph", not _direct(START, GOAL))
	entry.slabs = saved_slabs
	floor_body.queue_free()
	floor_body = null
	await _settle()
	_check("missing physical floor prevents shortcut", not _direct(START, GOAL))
	floor_body = _box(viewport, "RestoredFloor", Vector3(0, -0.10, 0), Vector3(8, 0.20, 8))
	await _settle()
	_check("restored physical floor admits shortcut", _direct(START, GOAL))
	floor_body.queue_free()
	floor_body = null
	await _settle()
	var left_support := _box(viewport, "FloorBeforeUnmodelledGap", Vector3(-1.93, -0.10, 0), Vector3(4, 0.20, 8))
	var right_support := _box(viewport, "FloorAfterUnmodelledGap", Vector3(2.13, -0.10, 0), Vector3(4, 0.20, 8))
	await _settle()
	_check("sampled runtime floor gap prevents shortcut", not _direct(START, GOAL))
	left_support.queue_free()
	right_support.queue_free()
	floor_body = _box(viewport, "FinalSupportFloor", Vector3(0, -0.10, 0), Vector3(8, 0.20, 8))
	await _settle()

	# Rebuild and failed revalidation must revoke admission, even in this world.
	nav.build({"floors": []})
	_check("build revokes direct admission", not _direct(START, GOAL))
	nav.validate_with_collision(viewport.find_world_3d())
	_check("fresh validation admits shortcut", _direct(START, GOAL))
	if nav.has_method("_direct_segment_clear"):
		nav.validate_with_collision(null)
		_check("null revalidation revokes admission", not _direct(START, GOAL))
	else:
		_check("null revalidation revokes admission", false)
	nav.validate_with_collision(viewport.find_world_3d())
	var unrelated_world := World3D.new()
	nav.validate_with_collision(unrelated_world)
	_check("validation in another World3D cannot admit this route", not _direct(START, GOAL))
	unrelated_world = null
	nav.validate_with_collision(viewport.find_world_3d())
	var retired_world: WeakRef = weakref(viewport.find_world_3d())
	viewport.remove_child(nav)
	add_child(nav)
	_check("tree exit and different world revoke admission", not _direct(START, GOAL))
	viewport.queue_free()
	viewport = null
	floor_body = null
	await _settle()
	_check("navigation does not retain retired World3D", retired_world.get_ref() == null)
	_check("retired-world route retains graph", not _direct(START, GOAL))
	nav.queue_free()
	nav = null
	await _settle()
	var folder := OS.get_environment("SHOT_DIR")
	if folder != "":
		var file := FileAccess.open(folder.path_join("resident_nav_direct_segment.json"), FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify({"checks": checks, "failures": failures,
				"scope": "Synthetic short-segment collision/support/World3D admission controls; no actor travel, actual F01, visual or performance acceptance."}, "\t"))
	print("[RESIDENT DIRECT] %d/%d passed" % [checks.size() - failures, checks.size()])
	get_tree().quit(failures)


func _public_refusal_controls() -> void:
	# Valid endpoints exercise route() itself. These would fail if route()
	# unconditionally returned [from, to], regardless of its private predicate.
	var far_start := Vector3(-0.7, 0.03, 0)
	var far_goal := Vector3(0.7, 0.03, 0)
	var long_path := nav.route(far_start, far_goal)
	_check("public long route refuses shortcut while reaching valid goal", long_path.size() > 2
		and long_path[0] == far_start and long_path[-1] == far_goal)
	var entry: Dictionary = nav.floors.F01
	var graph: AStar3D = entry.astar
	var side_a := Vector3(-0.5, 0.0, 0.65)
	var side_b := Vector3(0.5, 0.0, 0.65)
	graph.add_point(11, side_a)
	graph.add_point(12, side_b)
	graph.connect_points(11, 12)
	entry.points.append({"id": 11, "at": Vector2(side_a.x, -side_a.z), "tag": "fixture_detour"})
	entry.points.append({"id": 12, "at": Vector2(side_b.x, -side_b.z), "tag": "fixture_detour"})
	var blocker := _box(viewport, "PublicShortcutObstacle", Vector3(0, 0.8, 0), Vector3(0.15, 1.6, 0.15))
	await _settle()
	_check("public negative has blocked shortcut and valid alternate geometry",
		not _public_capsule_clear(PackedVector3Array([START, GOAL])))
	var path := nav.route(START, GOAL)
	_check("public blocked-shortcut route uses graph and reaches valid goal", path.size() > 2
		and path[0] == START and path[-1] == GOAL)
	_check("public alternate route independently clears the full capsule", path.size() > 2 and _public_capsule_clear(path))
	blocker.queue_free()
	await _settle()
	graph.remove_point(11)
	graph.remove_point(12)
	entry.points.pop_back()
	entry.points.pop_back()


func _public_capsule_clear(path: PackedVector3Array) -> bool:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.33
	shape.height = 1.65
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.margin = 0.001
	query.collide_with_areas = false
	var space := viewport.find_world_3d().direct_space_state
	for i in range(path.size() - 1):
		var a := Vector3(path[i].x, 0.03, path[i].z)
		var b := Vector3(path[i + 1].x, 0.03, path[i + 1].z)
		query.motion = Vector3.ZERO
		query.transform = Transform3D(Basis(), a + Vector3.UP * 0.825)
		if not space.intersect_shape(query, 1).is_empty(): return false
		query.transform.origin = b + Vector3.UP * 0.825
		if not space.intersect_shape(query, 1).is_empty(): return false
		query.transform.origin = a + Vector3.UP * 0.825
		query.motion = b - a
		var fractions := space.cast_motion(query)
		if fractions.size() != 2 or fractions[0] < 1.0 or fractions[1] < 1.0: return false
	return true


func _layout() -> Dictionary:
	return {"floors": [{"id": "F01", "z": 0.0,
		"rooms": [{"id": "PUBLIC", "kind": "room", "rect": [-3.0, -3.0, 3.0, 3.0]}],
		"walls": [], "markers": [],
		"slabs": [{"rect": [-3.0, -3.0, 3.0, 3.0], "z_top": 0.0, "holes": []}]}]}


func _box(parent: Node, label: String, at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = label
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	body.position = at
	parent.add_child(body)
	return body


func _direct(from: Vector3, to: Vector3) -> bool:
	# Negative controls deliberately place endpoints in collision or remove
	# the floor. Query shortcut admission there; a public route must remain
	# loud when no physically valid endpoint can be attached. Positive cases
	# still prove route() returns the exact requested two-point path.
	if nav.has_method("_direct_segment_clear") and not nav._direct_segment_clear(nav.floors.F01, from, to):
		return false
	var path := nav.route(from, to)
	return path.size() == 2 and path[0] == from and path[1] == to


func _contains_body_contract() -> bool:
	if not nav.has_method("_direct_segment_clear"): return false
	# Contract dimensions read from both actual actor constructors. The separate
	# F01 consumer fixture extracts its actual owner's shape and sweeps that shape.
	var constants: Dictionary = nav.get_script().get_script_constant_map()
	var radius := float(constants.get("DIRECT_RADIUS", 0.0))
	var height := float(constants.get("DIRECT_HEIGHT", 0.0))
	return absf(radius - 0.28) + 0.28 <= radius + 0.000001 \
		and absf((height - radius) - (1.55 - 0.28)) + 0.28 <= radius + 0.000001


func _settle() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame


func _check(label: String, passed: bool) -> void:
	checks.append({"label": label, "passed": passed})
	if not passed: failures += 1
	print("[RESIDENT DIRECT] %s %s" % ["PASS" if passed else "FAIL", label])
