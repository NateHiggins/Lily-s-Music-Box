class_name OpenShiftRadiatorEcosystem
extends Node
## Noncompliance consequences around the existing 2B service round.
## WorkOrders, RadiatorProp, inventory, residents and cases retain authority.

signal autonomous_event(kind: String, facts: Dictionary)

const SITUATION_ID := "lena_radiator_round_2b"
const NOTICE_MINUTES := 5.0
const COMPENSATE_MINUTES := 12.0
const SHUTOFF_MINUTES := 20.0

var situation: OpenShiftSituation
var work_orders: WorkOrders
var radiator: RadiatorProp
var service_round: ServiceRoundDirector
var _minute_provider: Callable
var _last_bucket := -1
var _simulation_accumulator := 0.0


func setup(orders: WorkOrders, mechanism: RadiatorProp,
		round: ServiceRoundDirector, minute_provider: Callable) -> void:
	work_orders = orders
	radiator = mechanism
	service_round = round
	_minute_provider = minute_provider
	situation = OpenShiftSituation.new()
	situation.name = "Radiator2BSituation"
	add_child(situation)
	situation.setup(SITUATION_ID, minute_provider)
	if service_round and not service_round.route_beat.is_connected(_on_route_beat):
		service_round.route_beat.connect(_on_route_beat)
	_reconstruct_physical_state()


func _process(delta: float) -> void:
	if work_orders == null or situation == null:
		return
	if work_orders.job_stage(ServiceRoundDirector.PREVIOUS_JOB_ID) == "closed":
		situation.offer(ServiceRoundDirector.RESIDENT_ID, 0.2, 0.25)
	# Production progression follows engine simulation time, accumulated into a
	# durable situation fact. An injected house clock remains available to tests
	# and authored jumps, but host wall-clock passage can never mutate the world.
	if not _minute_provider.is_valid() and float(situation.state().offered_at) >= 0.0:
		_simulation_accumulator += delta / 60.0
		if _simulation_accumulator >= 0.05:
			situation.advance_simulation_minutes(_simulation_accumulator)
			_simulation_accumulator = 0.0
	advance_autonomy()


func advance_autonomy() -> void:
	var record := situation.state()
	if float(record.offered_at) < 0.0 or not str(record.resolution_kind).is_empty():
		return
	var elapsed := situation.elapsed_since("offered_at") \
			if _minute_provider.is_valid() \
			else float(record.elapsed_simulation_minutes)
	var bucket := 3 if elapsed >= SHUTOFF_MINUTES else (2 if elapsed >= COMPENSATE_MINUTES else (1 if elapsed >= NOTICE_MINUTES else 0))
	if bucket == _last_bucket:
		return
	_last_bucket = bucket
	if bucket >= 1 and float(record.noticed_at) < 0.0:
		situation.notice("neighbor_heard_riser_hammer")
		situation.set_pressure(0.45, 0.55, 0.3)
		if radiator:
			radiator.apply_open_shift_condition("worsening_hammer")
		autonomous_event.emit("neighbor_noticed", {"observer": "2c_neighbor"})
	if bucket >= 2 and float(situation.state().compensation_started_at) < 0.0:
		situation.begin_compensation("porter")
		autonomous_event.emit("porter_dispatched", {"channel": "riser_complaint"})
	if bucket >= 3 and str(situation.state().resolution_kind).is_empty():
		if radiator:
			radiator.apply_open_shift_condition("porter_temporary_shutoff")
		var residue: Dictionary = situation.state().residue.duplicate(true)
		residue.merge({
			"heat": "off_in_2b", "fault": "unrepaired",
			"evidence": "porter_tag_on_valve",
			"relationship": "resident_expected_help_but_porter_arrived",
		}, true)
		situation.record_fact("npc_knowledge", {
			"2c_neighbor": "heard_hammer", "porter": "found_unresolved_fault",
			ServiceRoundDirector.RESIDENT_ID: "porter_shut_heat_off",
		})
		situation.record_fact("relationship_consequence",
				"resident_expected_help_but_porter_arrived")
		situation.record_fact("recoverable_next_state",
				"reopen_supply_then_diagnose_original_fault")
		situation.resolve("porter_temporary_shutoff", residue)
		autonomous_event.emit("porter_temporary_shutoff", situation.state().residue)


func abandon_after(boundary: String) -> bool:
	if boundary not in ["inspected", "named_part", "took_part", "returned",
			"opened_uncommitted"]:
		return false
	situation.accept("help_implied")
	situation.record_fact("abandonment_boundary", boundary)
	var residue: Dictionary = situation.state().residue.duplicate(true)
	match boundary:
		"inspected":
			situation.attend("inspected_then_left")
			residue.evidence = "inspection_marks"
		"named_part":
			situation.attend("named_packing_then_left")
			residue.evidence = "resident_heard_part_named"
		"took_part":
			situation.attend("left_with_packing")
			situation.record_fact("part_custody", "player_has_radiator_packing")
			residue.evidence = "packing_absent_from_store"
		"returned":
			situation.attend("returned_without_repair")
			residue.evidence = "resident_saw_return"
		"opened_uncommitted":
			situation.attend("opened_mechanism_without_commit")
			if radiator:
				radiator.apply_open_shift_condition("opened_uncommitted")
			residue.evidence = "open_union_and_tool_marks"
	situation.record_fact("npc_knowledge", {
		ServiceRoundDirector.RESIDENT_ID: "help_started_at_%s" % boundary,
	})
	situation.record_fact("relationship_consequence",
			"resident_believes_help_was_started")
	situation.record_fact("recoverable_next_state",
			"return_to_finish_or_explain")
	var record := _record_mutable()
	record.residue = residue
	RealityState.commit()
	return true


func meddle_wrong_valve(observer := "2c_neighbor") -> bool:
	if radiator == null or not radiator.apply_open_shift_condition(
			"wrong_valve_partial"):
		return false
	situation.notice("changed_pipe_sound")
	situation.observe_interference("wrong_valve", observer)
	situation.set_pressure(0.55, 0.62, 0.5)
	situation.record_fact("npc_knowledge", {
		observer: "heard_new_hammer_after_valve_turn",
		ServiceRoundDirector.RESIDENT_ID: "heat_changed_but_fault_remains",
	})
	situation.record_fact("relationship_consequence",
			"visible_interference_requires_explanation")
	situation.record_fact("recoverable_next_state",
			"restore_supply_balance_then_diagnose")
	var record := _record_mutable()
	record.residue = {
		"heat": "uneven", "fault": "worsened_by_wrong_valve",
		"sound": "new_riser_hammer", "evidence": "fresh_valve_marks",
	}
	RealityState.commit()
	autonomous_event.emit("wrong_valve_interference", record.residue)
	return true


func _record_mutable() -> Dictionary:
	return RealityState.data.open_shift_situations[OpenShiftRadiatorEcosystem.SITUATION_ID]


func _on_route_beat(beat: String) -> void:
	match beat:
		"call":
			situation.notice("service_set_call")
			situation.accept("heard_request")
		"resident": situation.accept("resident_expects_help")
		"radiator_evidence": situation.attend("inspected_radiator")
		"lobby_comparison": situation.attend("compared_porter_board")
		"basement_comparison": situation.attend("compared_boiler")
		"diagnosis": situation.attend("named_no_part_fault")
		"repair": situation.attend("committed_repair")
		"resident_return":
			situation.resolve("player_repair", {
				"heat": "restoring", "fault": "repaired",
				"relationship": "resident_saw_visible_patch",
			})


func _reconstruct_physical_state() -> void:
	if radiator == null:
		return
	var record := situation.state()
	var kind := str(record.resolution_kind)
	if kind == "porter_temporary_shutoff":
		radiator.apply_open_shift_condition("porter_temporary_shutoff")
	elif "wrong_valve" in record.observed_interference:
		radiator.apply_open_shift_condition("wrong_valve_partial")
	elif "vent_removed" in record.observed_interference:
		radiator.apply_open_shift_condition("vent_removed")
	elif float(record.noticed_at) >= 0.0:
		radiator.apply_open_shift_condition("worsening_hammer")
