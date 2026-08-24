extends Node
## Live-consumer proof for the first Service Round apparatus.

var failures := 0


func _ready() -> void:
	var radiator := RadiatorProp.new()
	radiator.name = "TestRadiator"
	radiator.unit = "TEST"
	add_child(radiator)
	await get_tree().process_frame

	radiator.set_supply_position(1.0, 0.0)
	radiator.set_vent_grade(4)
	var snapshot := radiator.maintenance_snapshot()
	radiator.preview_maintenance_step(
			{"id": "shut_supply"}, 0.0)
	_check(is_equal_approx(radiator.supply_position, 1.0),
			"working the visible wheel does not publish heat state before commit")
	radiator.preview_maintenance_step({"id": "seat_orifice"}, 0.72)
	_check(radiator.vent_grade == 4,
			"clocking the visible vent does not install an orifice before commit")
	radiator.restore_maintenance_snapshot(snapshot)
	_check(is_equal_approx(radiator.supply_position, 1.0)
			and radiator.vent_grade == 4,
			"abandonment restores both radiator facts")

	var completions: Array[Dictionary] = []
	radiator.maintenance_completed.connect(
			func(result: Dictionary) -> void: completions.append(result))
	radiator.apply_maintenance_result({
		"quality": "good",
		"note": "vent seated; supply returned fully open",
		"mechanism_patch": {"vent_grade": 2, "supply_position": 1.0},
	})
	_check(radiator.vent_grade == 2
			and is_equal_approx(radiator.supply_position, 1.0),
			"completed patch reaches the radiator's existing public setters")
	_check(completions.size() == 1 and str(completions[0].quality) == "good",
			"the mechanism reports completion without advancing a work order")
	_check(radiator.get_node_or_null("HandwheelReach") is Area3D
			and radiator.get_node_or_null("VentReach") is Area3D,
			"both literal service points remain ray-reachable")

	print("MAINTENANCE ACTIVITY LIVE TEST: %s" %
			("PASS" if failures == 0 else "FAIL (%d)" % failures))
	get_tree().quit(failures)


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  [live activity ok] ", label)
	else:
		failures += 1
		printerr("  [LIVE ACTIVITY FAIL] ", label)
