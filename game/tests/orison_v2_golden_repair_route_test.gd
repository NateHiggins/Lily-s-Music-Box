extends "res://tests/orison_v2_passage_route_test.gd"
## Continuous arrival, first-shift opening and first repair through real input.
## Recurrence and dream/wake remain separate gates.
var _reported_job: Dictionary = {}

func _init() -> void:
	route_label = "V2 GOLDEN PHYSICAL REPAIR"

func _prepare_player_start() -> void:
	# Keep the production arrival. This fixture must detect a blocked entrance,
	# not bypass it by placing the player beside the first stair.
	pass

func _route() -> void:
	if not await _open_first_shift(): return
	if not await _enter_2a(): return
	for point in [Vector3(-10.5,3.2,2.5),Vector3(-13.4,3.2,2.5),Vector3(-13.4,3.2,1.95)]:
		if not await _walk(point): return
	var mina: AnimatedResident = world.mina_routine.actor
	if not await _use(mina,mina.global_position+Vector3.UP*1.15,"physical_mina_complaint"): return
	if not _require(world.mina_gameplay.dialogue.visible and player.call_locked,
			"physical Mina opens the authored protected complaint dialogue"): return
	await get_tree().create_timer(.4).timeout
	var directory := OS.get_environment("SHOT_DIR")
	if not directory.is_empty():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(directory.path_join("mina_complaint_open.png"))
	for i in 30:
		if not world.mina_gameplay.dialogue.visible: break
		world.mina_gameplay.dialogue.choose(0)
		await get_tree().process_frame
	if not _require(not player.call_locked,"complaint releases movement"): return
	for point in [Vector3(-13.4,3.2,2.5),Vector3(-10.5,3.2,2.5),Vector3(-9.2,3.2,1.4)]:
		if not await _walk(point): return
	var detector: VantryPointProp = world.vantry_points.active_owner
	if not await _use(detector,detector.global_position-Vector3.UP*.05,"listening_head_inspection"): return
	_reported_job = world.work_orders.job_state(ChirpHunt.JOB_ID).duplicate(true)
	if not _require(_reported_job.stage == "awaiting_part" and _reported_job.evidence.size() == 3
			and world.chirp_hunt.fault_active(),"physical inspection diagnoses the still-chirping head"): return
	if not await _return_core(): return
	await super._route()
	if not failures.is_empty(): return
	if not await _walk(Vector3(2.3,0,-3.5)): return
	if not await _enter_2a(): return
	if not await _use(detector,detector.global_position-Vector3.UP*.05,"listening_head_repair"): return
	await get_tree().create_timer(.6).timeout
	var job: Dictionary = world.work_orders.job_state(ChirpHunt.JOB_ID)
	_require(job.stage == "repaired" and job.repair_result.quality == "good",
			"same physical head records a good repair through ordinary input")
	_require(world.maintenance_inventory.is_consumed("carbon_transmitter_capsule")
			and not world.maintenance_inventory.has_item("carbon_transmitter_capsule")
			and detector.is_repaired() and not world.chirp_hunt.fault_active(),
			"repair consumes the purchased capsule and quiets the source")
	var state := RealityState.case_state(MinaCaseGameplay.CASE_ID)
	_require(state.stage == "stabilized" and state.repair_count == 1 and state.recurrence_pending,
			"physical repair grants exactly the first temporary stabilization")
	_require(world.core_loop.boundary() == "conversation_pending",
			"repair earns conversation without prematurely closing the job")

func _open_first_shift() -> bool:
	var arrival := world.arrival_placement()
	var offset: Vector3 = player.global_position - arrival.position
	if not _require(Vector2(offset.x, offset.z).length() < .05 and absf(offset.y) < .12,
			"route begins at the untouched production arrival"): return false
	if not _require(world.first_shift_director.begin_first_shift(),
			"production first-shift owner commits the arrival"): return false
	# The caretaker desk occupies the watch room's south frontage. Enter the
	# working side through its authored core doorway, preserving the desk body.
	for point in [Vector3(0,0,-10.2),Vector3(0,0,-8.5),Vector3(2.3,0,-6.5),
			Vector3(2.3,0,-3.5),Vector3(0,0,-3),Vector3(0,0,-1.5),
			Vector3(-2,0,-1.5),Vector3(-2,0,-2.2)]:
		if not await _walk(point): return false
	var detector := world.adapter.resolve("F01_WATCHMAN_DETECTOR") as WatchmanClockProp
	if not _require(detector != null, "arrival watchman detector is mounted"): return false
	var detector_reach := detector.get_node("DetectorReach") as Area3D
	if not await _use(detector_reach, detector.to_global(Vector3(0,.20,.12)), "first_shift_clock_in"): return false
	if not _require(world.first_shift_director.ritual_phase() == FirstShiftDirector.PHASE_CLOCKED_IN
			and world.work_orders.job_stage(ChirpHunt.JOB_ID) == "issued",
			"physical detector offers the opening work order"): return false
	for point in [Vector3(-2,0,-1.5),Vector3(-3.25,0,-1.5),Vector3(-3.25,0,-.95)]:
		if not await _walk(point): return false
	var register := world.adapter.resolve("F01_NIGHT_REGISTER") as NightRegisterProp
	if not _require(register != null and register.slip_available(), "physical report is on the spindle"): return false
	var slip := register.get_node("Reach_slip") as Area3D
	if not await _use(slip, register.to_global(Vector3(-.185,.255,.055)), "first_shift_take_report"): return false
	if not _require(world.first_shift_director.ritual_phase() == FirstShiftDirector.PHASE_REPORT_ACCEPTED
			and world.work_orders.job_stage(ChirpHunt.JOB_ID) == "acknowledged",
			"taking the physical paper activates the existing first case"): return false
	for point in [Vector3(-3.25,0,-1.5),Vector3(0,0,-1.5),Vector3(0,0,-3),
			Vector3(2.3,0,-3.5)]:
		if not await _walk(point): return false
	return true

func _prepare_procurement() -> bool:
	var job: Dictionary = world.work_orders.job_state(ChirpHunt.JOB_ID)
	return _require(not _reported_job.is_empty() and job.stage == "awaiting_part"
			and job.evidence == _reported_job.evidence,
			"hardware errand uses the actually inspected job without reseeding")

func _enter_2a() -> bool:
	for point in [Vector3(2.3,1.6,1.3),Vector3(3.8,1.6,1.3),Vector3(3.8,3.2,-2.4),
			Vector3(3.8,3.2,-3.4),Vector3(0,3.2,-3),Vector3(0,3.2,0),Vector3(-3.2,3.2,0),
			Vector3(-4.65,3.2,0),Vector3(-6.4,3.2,0),Vector3(-8.5,3.2,0),Vector3(-9.2,3.2,1.4)]:
		if not await _walk(point): return false
		if point.is_equal_approx(Vector3(-4.65,3.2,0)):
			if not await _open_apartment_door("F02_DOOR_02"): return false
	return true

func _return_core() -> bool:
	for point in [Vector3(-8.5,3.2,0),Vector3(-6.4,3.2,0),Vector3(-3.2,3.2,0),Vector3(0,3.2,0),
			Vector3(0,3.2,-3),Vector3(3.8,3.2,-3.4),Vector3(3.8,3.2,-2.4),Vector3(3.8,1.6,1.3),
			Vector3(2.3,1.6,1.3),Vector3(2.3,0,-3.5)]:
		if not await _walk(point): return false
	return true
