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

	var annunciator := OtisProp.new()
	annunciator.name = "TestLobbyAnnunciator"
	annunciator.prop_type = "otis"
	add_child(annunciator)
	await get_tree().process_frame
	_check(annunciator.get_node_or_null("DispatchReach") is PropControlArea
			and annunciator.get_node_or_null("CallHardwareReach") is PropControlArea
			and annunciator.control_prompt("dispatch").contains("lift")
			and annunciator.control_prompt("service").contains("annunciator"),
			"lift dispatch and call-hardware service remain separate ray targets")
	_check(annunciator.interact_control("service", null)
			and annunciator._service_panel != null
			and annunciator._service_panel._director.active_run != null
			and annunciator._panel == null,
			"the call-hardware target opens the shared activity, not the lift game")
	annunciator._service_panel._director.abort()
	var annunciator_snapshot := annunciator.maintenance_snapshot()
	annunciator.preview_maintenance_step({"id": "hold_armature"}, 0.44)
	annunciator.preview_maintenance_step({"id": "square_contact"}, 0.63)
	_check(annunciator.stuck_flag
			and is_equal_approx(annunciator.contact_alignment, 0.32),
			"working the visible flags and contacts publishes no state before commit")
	annunciator.restore_maintenance_snapshot(annunciator_snapshot)
	var annunciator_results: Array[Dictionary] = []
	annunciator.maintenance_completed.connect(
			func(result: Dictionary) -> void: annunciator_results.append(result))
	annunciator.apply_maintenance_result({
		"quality": "good",
		"note": "flag armature freed; contact bank tested",
		"mechanism_patch": {"stuck_flag": false, "contact_alignment": 0.63},
	})
	_check(not annunciator.stuck_flag
			and is_equal_approx(annunciator.contact_alignment, 0.63)
			and is_equal_approx(annunciator.bank_reset, 1.0),
			"final commit alone frees, squares and resets the call bank")
	_check(annunciator_results.size() == 1
			and str(annunciator_results[0].quality) == "good",
			"annunciator reports a mechanism result without touching the lift game")

	var production_scene := load(
			"res://scenes/building/orison_root.tscn") as PackedScene
	var production_root: Node = production_scene.instantiate()
	add_child(production_root)
	await get_tree().process_frame
	await get_tree().process_frame
	var production_board := production_root.find_child(
			"LobbyPorterBoard", true, false) as OtisProp
	_check(production_board != null
			and production_board.get_node_or_null("DispatchReach") is PropControlArea
			and production_board.get_node_or_null(
					"CallHardwareReach") is PropControlArea,
			"the production lobby owns this same two-target porter board")

	print("MAINTENANCE ACTIVITY LIVE TEST: %s" %
			("PASS" if failures == 0 else "FAIL (%d)" % failures))
	get_tree().quit(failures)


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  [live activity ok] ", label)
	else:
		failures += 1
		printerr("  [LIVE ACTIVITY FAIL] ", label)
