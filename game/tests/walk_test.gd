extends Node
## Headless building validation — not shipped gameplay. Run:
##   godot --headless --path game res://tests/WalkTest.tscn
## Asserts: every level has walkable floor, apartments have slabs, the
## front stair is physically climbable by the real player controller, the
## elevator travels B1..F06, and props/conductor are alive.
## Exits with the failure count as exit code.

var root: Node3D
var _failures := 0


func _ready() -> void:
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	_run()


func _run() -> void:
	await get_tree().create_timer(0.6).timeout
	root.show_all_floors = true

	var levels: Dictionary = root.layout["meta"]["levels"]
	for fid in levels:
		var z: float = levels[fid]
		var p := Vector3(4.3, z + 1.5, 0.0) if fid != "ROOF" \
				else Vector3(0.0, z + 1.5, 8.0)
		_check(_floor_below(p), "%s has walkable floor" % fid)
	_check(_floor_below(Vector3(-9.5, 11.2, -4.8)), "apartment 4B has a slab")
	_check(_floor_below(Vector3(9.5, 11.2, -4.8)), "apartment 4C has a slab")
	_check(_floor_below(Vector3(0.0, -1.3, 5.0)), "basement corridor floor")

	var props := 0
	for c in root.get_children():
		if c is FunctionalProp:
			props += 1
	_check(props >= 25, "functional props spawned (%d)" % props)

	var beat_before: int = Conductor._beat_i
	await get_tree().create_timer(2.0).timeout
	_check(Conductor._beat_i > beat_before, "conductor clock is beating")

	# --- physically climb the front stair F01 -> F02 with the real player
	var pl: PlayerController = root.player
	pl.global_position = Vector3(0.4, 0.15, 6.0)
	pl.velocity = Vector3.ZERO
	await _goto(pl, Vector2(-2.5, 5.9), 5.0)   # west up flight 1 to landing
	await _goto(pl, Vector2(-2.5, 4.0), 3.0)   # across landing to flight 2
	await _goto(pl, Vector2(1.6, 4.0), 6.0)    # east up flight 2 onto F02
	pl.autopilot = Vector3.ZERO
	_check(pl.global_position.y > 2.9,
			"front stair climbable (player at y=%.2f)" % pl.global_position.y)

	# --- elevator travel across full range
	root.elevator.travel_to("F06")
	await _until(func(): return not root.elevator.moving, 25.0)
	_check(root.elevator.current == "F06", "elevator reached F06")
	root.elevator.travel_to("B1")
	await _until(func(): return not root.elevator.moving, 25.0)
	_check(root.elevator.current == "B1", "elevator reached B1")

	_check(AcousticGraphData.nodes.size() >= 25,
			"acoustic graph loaded (%d nodes)" % AcousticGraphData.nodes.size())
	_check(not AcousticGraphData.neighbors("F04_B_RADIATOR_01").is_empty(),
			"4B radiator connected to heating network")

	print("WALKTEST RESULT: %s" %
			("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	get_tree().quit(_failures)


func _floor_below(from: Vector3) -> bool:
	var params := PhysicsRayQueryParameters3D.create(from, from + Vector3(0, -2.2, 0))
	return not get_viewport().world_3d.direct_space_state \
			.intersect_ray(params).is_empty()


## Waypoint steering: drive toward an XZ target until close or timed out,
## so the climb follows the actual stair geometry instead of blind timing.
func _goto(pl: PlayerController, target: Vector2, timeout: float) -> void:
	var t := 0.0
	while t < timeout:
		var pos := Vector2(pl.global_position.x, pl.global_position.z)
		if pos.distance_to(target) < 0.3:
			break
		var dir := (target - pos).normalized()
		pl.autopilot = Vector3(dir.x, 0, dir.y)
		await get_tree().create_timer(0.1).timeout
		t += 0.1
	pl.autopilot = Vector3.ZERO


func _until(cond: Callable, timeout: float) -> bool:
	var t := 0.0
	while t < timeout and not cond.call():
		await get_tree().create_timer(0.25).timeout
		t += 0.25
	return cond.call()


func _check(cond: bool, label: String) -> void:
	if cond:
		print("  [ok] %s" % label)
	else:
		_failures += 1
		printerr("  [FAIL] %s" % label)
