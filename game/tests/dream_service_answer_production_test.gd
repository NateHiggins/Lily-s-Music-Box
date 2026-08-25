extends Node
## SR5 production proof: SR4's real WorkOrders transitions and production
## mechanisms cause the shared waking Dream owners to answer.

var failures := 0
var root: Node
var orders: WorkOrders
var round: ServiceRoundDirector
var encroachment: ApartmentEncroachment


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	RealityState.ensure_case(ServiceRoundDirector.CASE_ID,
			ServiceRoundDirector.RESIDENT_ID)
	var packed := load("res://scenes/building/orison_root.tscn") as PackedScene
	root = packed.instantiate()
	add_child(root)
	await get_tree().process_frame
	await get_tree().process_frame
	orders = root.work_orders
	round = root.service_round
	encroachment = root.apartment_encroachment
	_check(round != null and encroachment != null
			and round.route_beat.is_connected(
					encroachment._on_service_round_beat),
			"production binds the waking route to the existing Dream owner")

	_close_previous_job()
	round.answer_incoming_call()
	round.dialogue.choose(0)
	RealityCases.interact_with_resident(ServiceRoundDirector.RESIDENT_ID)
	round.dialogue.choose(0)
	root.player.world_modified.emit(
			root.get_node(ServiceRoundDirector.RADIATOR_ID).global_position,
			ServiceRoundDirector.RADIATOR_ID)
	var board := root.find_child(ServiceRoundDirector.BOARD_ID,
			true, false) as OtisProp
	var boiler := root.get_node(ServiceRoundDirector.BOILER_ID) as BoilerProp
	var radiator := root.get_node(ServiceRoundDirector.RADIATOR_ID) as RadiatorProp
	board.apply_maintenance_result({
		"quality": "good", "note": "contacts squared",
		"mechanism_patch": {"stuck_flag": false, "contact_alignment": 0.63}})
	var keys_before: Array = RealityState.data.keys()
	keys_before.sort()
	var children_before := encroachment.get_child_count()
	boiler.apply_maintenance_result({
		"quality": "good", "note": "column proved",
		"mechanism_patch": {"water_level": 0.62, "column_proved": true}})

	var answer := encroachment.service_response_census()
	var keys_after: Array = RealityState.data.keys()
	keys_after.sort()
	var field: LivingField = encroachment.fields.get("F02")
	var field_census := field.census()
	_check(orders.job_stage(ServiceRoundDirector.JOB_ID) == "repairable"
			and int(answer.observations) == 3 and int(answer.answers) == 1,
			"the real apartment, lobby and basement route earns one answer")
	_check((answer.attention_at as Vector3).distance_to(
			boiler.global_position) < 0.01
			and encroachment.ecology.attending.distance_to(
					boiler.global_position) < 0.01,
			"the production boiler is the whole body's attention point")
	_check((answer.answer_at as Vector3).distance_to(
			radiator.global_position) < 0.01
			and int(field_census.vascular_responses) >= 1
			and int(answer.answer_cells) > 0,
			"the production F02 field holds the answer at Lena's radiator")
	_check(keys_after == keys_before
			and encroachment.get_child_count() == children_before,
			"the production answer adds neither a save owner nor a node owner")
	_check(root.find_child("DreamServiceDirector", true, false) == null
			and root.find_child("ServiceDreamEntity", true, false) == null,
			"no maintenance-specific Dream director or entity exists")

	radiator.apply_maintenance_result({
		"quality": "good", "note": "vent seated; supply returned fully open",
		"mechanism_patch": {"vent_grade": 2, "supply_position": 1.0}})
	_check(orders.job_stage(ServiceRoundDirector.JOB_ID) == "repaired"
			and encroachment.service_reply_packets == 1
			and int(encroachment.ecology.signal_census().by_function.get(
					"recognize", 0)) == 2,
			"the real repair returns one recognition through the shared bed")

	print("DREAM SERVICE ANSWER PRODUCTION TEST: %s" %
			("PASS" if failures == 0 else "FAIL (%d)" % failures))
	get_tree().quit(failures)


func _close_previous_job() -> void:
	const JOB := ServiceRoundDirector.PREVIOUS_JOB_ID
	orders.issue_job(JOB, "reported")
	orders.acknowledge_job(JOB)
	orders.diagnose_job(JOB)
	orders.mark_job_awaiting_part(JOB)
	orders.mark_job_repairable(JOB)
	orders.record_job_repair(JOB, {"quality": "good", "note": "proof gate"})
	orders.close_job(JOB)


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  [production answer ok] ", label)
	else:
		failures += 1
		printerr("  [PRODUCTION ANSWER FAIL] ", label)
