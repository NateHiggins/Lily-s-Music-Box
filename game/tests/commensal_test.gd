extends Node
## Focused acceptance proof for the ruled waking commensal C1.

var _passed := 0
var _failed := 0


func _ready() -> void:
	OS.set_environment("DAYNIGHT", "0")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	RealityState.data.dream_seed = "1928000019280000"
	RealityState.data.dreams_had = 3
	var root: Node3D = load(
			"res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	await get_tree().create_timer(1.5).timeout
	var director: CommensalDirector = root.commensals
	_check("production root owns the one waking commensal director",
			director != null and director.get_parent() == root)
	if director == null:
		_finish()
		return
	var first := director.diagnostic_snapshot()
	var first_pressure: Dictionary = first.pressure.duplicate(true)
	var first_census: Dictionary = first.census.duplicate(true)
	var first_schedule: Dictionary = first.schedule.duplicate(true)
	director._derive_shift_state()
	var second := director.diagnostic_snapshot()
	_check("the same anchor/shift/seed reproduces pressure, census and schedule",
			first_pressure == second.pressure and first_census == second.census
			and first_schedule == second.schedule)

	var anchors: Dictionary = first.anchors
	_check("two distinct authored street-lamp markers flank the entry",
			anchors.lamps is Array and anchors.lamps.size() == 2
			and anchors.lamps[0] != anchors.lamps[1]
			and anchors.lamps.all(func(id): return str(id).begins_with(
					"F01_STREETLAMP_")))
	_check("4B kitchen provenance remains a fixture marker",
			str(anchors.kitchen).contains("4B_KITCHEN")
			and str(anchors.kitchen).contains("SINK"))
	_check("F02 mice retain both riser and fixture identity",
			not str(anchors.riser).is_empty()
			and str(anchors.riser_fixture).begins_with("F02_")
			and str(anchors.riser_fixture).contains("RADIATOR"))
	_check("weed placement comes from the named hoarding owner",
			str(anchors.hoarding) == "StreetEndHoardingFaces"
			and anchors.hoarding_transform is Transform3D)

	_check("C1 is exactly three visual batches",
			int(first.draw_batches) == 3
			and director.find_children("*", "MultiMeshInstance3D", true, false).size() == 3)
	_check("C1 creates no collision, lights or shadow casters",
			int(first.collision_nodes) == 0 and int(first.lights) == 0
			and int(first.shadow_casters) == 0)
	_check("creatures are instances, never per-creature nodes",
			director.moth_batch.get_child_count() == 0
			and director.roach_batch.get_child_count() == 0
			and director.weed_batch.get_child_count() == 0)
	_check("mouse scheduling cannot encode the Tenant cadence",
			int(first.mouse_cadence_positions) == 1
			and int(first.schedule.mouse_cadence_positions) == 1)

	# Owner gates: the F02 interior submits none of the F01/F04 visuals.
	root._apply_visibility(director._mouse_at)
	_check("F02 gates both street batches and the F04 skitter",
			not director.moth_batch.visible and not director.weed_batch.visible
			and not director.roach_batch.visible)
	# The street positions come from a lamp marker, never a test coordinate.
	root._apply_visibility((anchors.lamp_positions as Array)[0])
	director.force_night_for_test(true)
	_check("night street admits lamp moths and static flora",
			director.moth_batch.visible and director.weed_batch.visible)
	director.force_night_for_test(false)
	_check("daylight removes insects but not the weed",
			not director.moth_batch.visible and director.weed_batch.visible)

	# A protected switch verdict is delayed, then consumed once. Further on
	# verdicts in the shift prove habituation by doing nothing.
	director.force_night_for_test(true)
	root._apply_visibility(director._roach_at)
	director.reset_habituation_for_test()
	root.player.call_locked = true
	director._on_room_toggled(CommensalDirector.KITCHEN_ROOM, true)
	_check("call_locked forbids the attention event",
			director.roach_scatter_count == 0 and not director.roach_batch.visible)
	root.player.call_locked = false
	director.tick_for_test()
	_check("the still-fresh verdict releases after the protected window",
			director.roach_scatter_count == 1 and director.roach_batch.visible)
	director._on_room_toggled(CommensalDirector.KITCHEN_ROOM, false)
	director._on_room_toggled(CommensalDirector.KITCHEN_ROOM, true)
	_check("roach scatter habituates after one event per shift",
			director.roach_scatter_count == 1)

	# Mouse cue uses the same protection and the existing audio owner's pool.
	director._mouse_cued = false
	director._mouse_elapsed = float(director.schedule.mouse_delay_seconds)
	root.player.global_position = director._mouse_at
	root.player.call_locked = true
	director.tick_for_test()
	_check("protected windows also suppress the scheduled riser cue",
			not director._mouse_cued)
	root.player.call_locked = false
	director.tick_for_test()
	_check("the ambience owner accepts one sparse F02 riser cue",
			director._mouse_cued and root.ambient_soundscape._event_index > 0)

	# Measure the owner clock after all one-shot work has drained.
	var tick_started := Time.get_ticks_usec()
	for i in 64:
		director.tick_for_test()
	var average_tick_usec := float(Time.get_ticks_usec() - tick_started) / 64.0
	_check("low-Hz director tick stays at or below 0.1 ms (%.1f us)"
			% average_tick_usec, average_tick_usec <= 100.0)
	_finish()


func _check(label: String, condition: bool) -> void:
	if condition:
		_passed += 1
		print("[COMMENSAL TEST] PASS: " + label)
	else:
		_failed += 1
		printerr("[COMMENSAL TEST] FAIL: " + label)


func _finish() -> void:
	print("[COMMENSAL TEST] %d passed, %d failed" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)
