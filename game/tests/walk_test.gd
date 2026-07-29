extends Node
## Headless building validation — not shipped gameplay. Run:
##   godot --headless --path game res://tests/WalkTest.tscn
## Asserts: every level has walkable floor, apartments have slabs, the
## front stair is physically climbable by the real player controller, the
## elevator travels B1..F06, and props/conductor are alive.
## Exits with the failure count as exit code.

var root: Node3D
var _failures := 0
var _arrivals := {}


func _record_arrival(node_id: String, _i: int, _a: float, _p: float,
		_s: float) -> void:
	if not _arrivals.has(node_id):
		_arrivals[node_id] = Time.get_ticks_msec()


func _both_radiators_reached() -> bool:
	return _arrivals.has("F02_B_RADIATOR_01") \
			and _arrivals.has("F05_B_RADIATOR_01")


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

	await _vertical_slice_checks()

	print("WALKTEST RESULT: %s" %
			("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	get_tree().quit(_failures)


func _vertical_slice_checks() -> void:
	# 4B detailed plan present in the shared model
	var ids := {}
	for fl in root.layout["floors"]:
		for r in fl["rooms"]:
			ids[r["id"]] = true
	for rid in ["F04_B_VESTIBULE", "F04_B_BATH", "F04_B_CLOSET",
			"F04_B_KITCHEN", "F04_B_ALCOVE"]:
		_check(ids.has(rid), "%s in layout" % rid)
	# bathroom wall physically separates main room from the service band
	var space := get_viewport().world_3d.direct_space_state
	var p := PhysicsRayQueryParameters3D.create(
			Vector3(-9.0, 10.9, -3.0), Vector3(-5.6, 10.9, -3.0))
	var hit := space.intersect_ray(p)
	_check(not hit.is_empty() and hit.position.x < -7.5,
			"4B bath wall present (hit x=%.2f)" %
			(hit.position.x if hit else 99.0))
	_check(_floor_below(Vector3(-12.8, 11.2, -8.0)), "4B alcove has a slab")

	# hero toaster: full mechanical cycle latch -> coils -> pop
	var toaster: ToasterProp = root.get_node_or_null("F04_B_TOASTER_01")
	_check(toaster != null, "toaster spawned in 4B kitchen")
	if toaster:
		toaster.start_cycle()
		await _until(func(): return toaster.cycles_completed >= 1, 12.0)
		_check(toaster.cycles_completed >= 1, "toaster completed a full cycle")
		_check(toaster.state == toaster.PState.IDLE,
				"toaster returned to IDLE")

	# networked propagation: same event reaches F05 later than F02 on H-B
	Conductor.propagation_mode = "network"
	Conductor.origin_node = "B1_BOILER_01"
	Conductor.infection = 1.0
	_arrivals.clear()
	AcousticGraphData.network_event.connect(_record_arrival)
	await _until(_both_radiators_reached, 8.0)
	AcousticGraphData.network_event.disconnect(_record_arrival)
	if _both_radiators_reached():
		var dt: int = _arrivals["F05_B_RADIATOR_01"] - _arrivals["F02_B_RADIATOR_01"]
		_check(dt > 30, "motif sweeps up riser H-B (F05 %d ms after F02)" % dt)
	else:
		_check(false, "propagation reached B-stack radiators")

	# the impossible door manifests only at severe infection
	var anomaly: DoorAnomalyProp = root.get_node_or_null("F04_B_DOOR_ANOMALY")
	_check(anomaly != null, "door anomaly spawned")
	if anomaly:
		await get_tree().create_timer(2.5).timeout
		_check(anomaly.is_manifest(), "door seam manifests at infection 1.0")
	Conductor.infection = 0.15

	await _call_case_checks(anomaly)


## Case 01 driven end-to-end through the in-building call interface.
func _call_case_checks(anomaly: DoorAnomalyProp) -> void:
	var ci: CallInterface = root.call_interface
	_check(ci != null, "call interface present")
	if ci == null:
		return
	ci.fast = true
	ci.enter(root.player)
	_check(root.player.call_locked, "player locked to desk during call")
	var ok: bool = await _until(func(): return not ci._isolate_btn.disabled, 15.0)
	_check(ok, "call: isolate unlocks after dialogue")
	ci.press_isolate(true)
	_check(ci.stage == CallInterface.Stage.ISOLATION, "call: stage ISOLATION")
	ok = await _until(func(): return not ci._capture_btn.disabled, 20.0)
	_check(ok, "call: capture unlocks after hearing breathing")
	ci.press_capture()
	ci.press_route()
	_check(Conductor.origin_node == "F04_B_MONITOR_01",
			"call: routing moves conductor origin to the 4B desk")
	ok = await _until(func(): return ci.stage == CallInterface.Stage.RESPONSE, 25.0)
	_check(ok, "call: reaches RESPONSE")
	ci.press_respond("complete")
	_check(ci.outcome == "complete", "call: outcome latched")
	ci.press_respond("interrupt")
	_check(ci.outcome == "complete", "call: second response rejected")
	ok = await _until(func(): return Conductor.infection >= 0.8, 15.0)
	_check(ok, "call: Complete raises building infection to 0.85")
	if anomaly:
		await get_tree().create_timer(2.5).timeout
		_check(anomaly.is_manifest(),
				"call: door anomaly manifests after Complete")
	ci.leave()
	_check(not root.player.call_locked, "player released after leaving desk")
	Conductor.infection = 0.15
	Conductor.origin_node = "B1_BOILER_01"


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
