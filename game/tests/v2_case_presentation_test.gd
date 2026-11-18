extends Node
## Case presentation in V2 (v1r_case_presentation_20261109): one reality
## controller per case flat, on the right flat, bending gravity and arming its
## loop while the case's rule is live, and restoring what it registered.

var _fails := 0
var _checks := 0


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("  [FAIL] ", label)


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var world := (load("res://scenes/building/orison_v2_runtime.tscn") as PackedScene).instantiate()
	add_child(world)
	while not world.startup_failed and world.startup_ms <= 0.0:
		await get_tree().process_frame
	_check(not world.startup_failed, "the V2 world starts")
	if world.startup_failed:
		_finish(world)
		return
	_check(world.global_transform.is_equal_approx(Transform3D.IDENTITY),
		"the V2 root sits at the origin, so controller bounds are world bounds")
	var expected := 0
	for case_id: String in RealityCases.definitions:
		if str(RealityCases.definition(case_id).get("unit", "")).length() >= 2:
			expected += 1
	var controllers: Dictionary = world.reality_controllers
	print("[V2 CASE PRESENTATION] controllers %d of %d case flats" % [controllers.size(), expected])
	_check(controllers.size() == expected, "every case flat has a controller")
	_check(get_tree().get_nodes_in_group("apartment_reality_controllers").size() == controllers.size(),
		"the controllers are in the group the player and director read")

	for case_id: String in controllers:
		var controller: ApartmentRealityController = controllers[case_id]
		var center: Vector3 = (controller.room_min + controller.room_max) * 0.5
		center.y = controller.room_min.y + 1.0
		_check(world.unit_at_world(center) == controller.unit,
			"%s's controller stands in %s (found %s)" % [case_id, controller.unit, world.unit_at_world(center)])
		_check(controller.contains_point(center), "%s contains its own centre" % case_id)

	# Live rule: gravity bends inside the flat and only there; the player feels it.
	# Drive a real gravity case live through RealityRules, as a case stage would.
	var bent := ""
	for case_id: String in controllers:
		if "gravity" in RealityRules.definitions.get(case_id, {}).get("rule_types", []):
			bent = case_id
			break
	_check(bent != "", "a case flat carries a gravity rule")
	if bent != "":
		RealityRules._refresh(bent, {"stage": RealityRules.LIVE_STAGES[0], "manifestation_intensity": 1.0})
		_check(not RealityRules.local_gravity(bent).is_equal_approx(Vector3.DOWN), bent + "'s live rule tilts gravity")
		var controller: ApartmentRealityController = controllers[bent]
		var inside: Vector3 = (controller.room_min + controller.room_max) * 0.5
		inside.y = controller.room_min.y + 1.0
		_check(not controller.gravity_at(inside).is_equal_approx(Vector3.DOWN), "a live rule bends gravity in " + controller.unit)
		_check(controller.gravity_at(controller.room_max + Vector3(5, 0, 5)).is_equal_approx(Vector3.DOWN),
			"gravity is ordinary outside the flat")
		var player: PlayerController = world.player
		player.global_position = inside
		_check(not player._reality_gravity().is_equal_approx(Vector3.DOWN), "the player feels the flat's gravity")
		# Restore: a registered prop goes back when the case stabilises.
		var marker := Node3D.new()
		world.add_child(marker)
		marker.global_position = inside
		controller.register_node(marker)
		marker.global_position = inside + Vector3(0.7, 0.0, 0.0)
		RealityRules._refresh(bent, {"stage": "unseen"})
		_check(marker.global_position.is_equal_approx(inside), "a stabilised case restores what it registered")
		_check(controller.gravity_at(inside).is_equal_approx(Vector3.DOWN), "gravity returns when the case stabilises")
		player.global_position = Vector3.ZERO

	var looped := 0
	for case_id: String in controllers:
		var controller: ApartmentRealityController = controllers[case_id]
		if controller._thresholds.is_empty():
			continue
		looped += 1
		controller._on_rule_changed(case_id, {"active": true, "intensity": 1.0, "rule_types": ["topology"]})
		var armed := true
		for threshold in controller._thresholds:
			armed = armed and threshold.enabled and controller.contains_point(threshold.global_position)
		_check(armed, "%s's loop thresholds arm inside its flat" % case_id)
		controller._on_rule_changed(case_id, {"active": false, "intensity": 0.0, "rule_types": []})
	print("[V2 CASE PRESENTATION] flats with a loop: %d" % looped)
	_finish(world)


func _finish(world: Node) -> void:
	var ok := _fails == 0
	print("[V2 CASE PRESENTATION] RESULT: %s (%d checks, %d failures)" % ["PASS" if ok else "FAIL", _checks, _fails])
	if world.has_method("shutdown_for_tests"):
		world.shutdown_for_tests()
	get_tree().quit(0 if ok else 1)
