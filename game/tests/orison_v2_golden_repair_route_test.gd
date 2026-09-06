extends "res://tests/orison_v2_passage_route_test.gd"
## Continuous first repair route. Complaint is public case-owner activation;
## physical resident encounter, recurrence and dream/wake are separate gates.
var _reported_job: Dictionary = {}

func _init() -> void:
	route_label = "V2 GOLDEN PHYSICAL REPAIR"

func _route() -> void:
	if not await _enter_2a(): return
	RealityState.ensure_case(MinaCaseGameplay.CASE_ID,"mina_vale")
	RealityCases.interact_with_resident("mina_vale")
	for i in 30:
		if not world.mina_gameplay.dialogue.visible: break
		world.mina_gameplay.dialogue.choose(0)
		await get_tree().process_frame
	if not _require(not player.call_locked,"complaint releases movement"): return
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

func _prepare_procurement() -> bool:
	var job: Dictionary = world.work_orders.job_state(ChirpHunt.JOB_ID)
	return _require(not _reported_job.is_empty() and job.stage == "awaiting_part"
			and job.evidence == _reported_job.evidence,
			"hardware errand uses the actually inspected job without reseeding")

func _enter_2a() -> bool:
	for point in [Vector3(2.3,1.6,1.3),Vector3(3.8,1.6,1.3),Vector3(3.8,3.2,-2.4),
			Vector3(3.8,3.2,-3.4),Vector3(0,3.2,-3),Vector3(0,3.2,0),Vector3(-3.2,3.2,0),
			Vector3(-6.4,3.2,0),Vector3(-8.5,3.2,0),Vector3(-9.2,3.2,1.4)]:
		if not await _walk(point): return false
	return true

func _return_core() -> bool:
	for point in [Vector3(-8.5,3.2,0),Vector3(-6.4,3.2,0),Vector3(-3.2,3.2,0),Vector3(0,3.2,0),
			Vector3(0,3.2,-3),Vector3(3.8,3.2,-3.4),Vector3(3.8,3.2,-2.4),Vector3(3.8,1.6,1.3),
			Vector3(2.3,1.6,1.3),Vector3(2.3,0,-3.5)]:
		if not await _walk(point): return false
	return true
