class_name OpenShiftRadiatorEcosystem
extends Node
## Coordinates the 2B radiator situation without counterfeiting a single
## consequence. WorkOrders, RadiatorProp, MaintenanceInventory, the
## PorterActor and the NpcObservationLedger retain authority; this node
## schedules, observes attested world events, and records situation facts.
## It never writes NPC knowledge, never performs an actor's action, and
## never touches custody.

signal autonomous_event(kind: String, facts: Dictionary)

const SITUATION_ID := "lena_radiator_round_2b"
## Minutes of neglect before the porter becomes ELIGIBLE to be sent -
## eligibility only; the porter himself travels, inspects and acts.
const COMPENSATE_MINUTES := 12.0
## Minutes since the last attended action before an accepted-but-left
## situation is recorded as abandoned at its furthest attested boundary.
const ABANDON_MINUTES := 6.0
const RADIATOR_NODE := "F02_B_RADIATOR_01"

var situation: OpenShiftSituation
var ledger: NpcObservationLedger
var porter: PorterActor
var work_orders: WorkOrders
var radiator: RadiatorProp
var service_round: ServiceRoundDirector
var _minute_provider: Callable
var _simulation_accumulator := 0.0


func setup(orders: WorkOrders, mechanism: RadiatorProp,
		round: ServiceRoundDirector, minute_provider: Callable,
		observation_ledger: NpcObservationLedger = null,
		porter_actor: PorterActor = null,
		porter_access := Callable()) -> void:
	work_orders = orders
	radiator = mechanism
	service_round = round
	_minute_provider = minute_provider
	situation = OpenShiftSituation.new()
	situation.name = "Radiator2BSituation"
	add_child(situation)
	situation.setup(SITUATION_ID, minute_provider)
	ledger = observation_ledger
	if ledger == null:
		ledger = NpcObservationLedger.new()
		ledger.name = "ObservationLedger"
		add_child(ledger)
		ledger.setup([
			{"npc": ServiceRoundDirector.RESIDENT_ID, "unit": "2B"},
			{"npc": "omar_bell", "unit": "3B"},
		], minute_provider, _acoustic_authority())
	porter = porter_actor
	if porter == null:
		porter = PorterActor.new()
		porter.name = "BuildingPorter"
		add_child(porter)
		porter.setup(radiator, ledger, porter_access)
	if not porter.porter_event.is_connected(_on_porter_event):
		porter.porter_event.connect(_on_porter_event)
	if service_round and not service_round.route_beat.is_connected(
			_on_route_beat):
		service_round.route_beat.connect(_on_route_beat)
	if radiator and not radiator.physical_action.is_connected(
			_on_physical_action):
		radiator.physical_action.connect(_on_physical_action)
	_reconstruct_physical_state()


func now_minutes() -> float:
	if _minute_provider.is_valid():
		return fposmod(float(_minute_provider.call()), 1440.0)
	return fposmod(180.0 +
			float(situation.state().elapsed_simulation_minutes), 1440.0)


## This node lives at the waking root, not in any room: simulation time
## accrues while the waking world runs, regardless of which rooms are
## loaded or where the player stands. All consequences derive from the
## durable minute facts below, so save/load and rebuilds catch up
## deterministically instead of replaying or pausing.
func _process(delta: float) -> void:
	if work_orders == null or situation == null:
		return
	if work_orders.job_stage(ServiceRoundDirector.PREVIOUS_JOB_ID) \
			== "closed":
		situation.offer(ServiceRoundDirector.RESIDENT_ID, 0.2, 0.25)
	if not _minute_provider.is_valid() and \
			float(situation.state().offered_at) >= 0.0:
		_simulation_accumulator += delta / 60.0
		if _simulation_accumulator >= 0.05:
			situation.advance_simulation_minutes(_simulation_accumulator)
			_simulation_accumulator = 0.0
	advance_autonomy()


## Scheduling and observation only. The mechanism degrades itself, the
## acoustic fabric decides who hears it, and the porter performs his own
## errand. Nothing here applies a consequence.
func advance_autonomy() -> void:
	var record := situation.state()
	if float(record.offered_at) < 0.0:
		return
	var now := now_minutes()
	if str(record.resolution_kind).is_empty():
		var elapsed := _elapsed_since_offer(record)
		if radiator and radiator.apply_neglect(elapsed):
			situation.set_pressure(0.45, 0.55, 0.3)
			var heard := ledger.witness_audible_event(RADIATOR_NODE,
					"riser_hammer_worsening",
					{"source_unit": "2B", "source": RADIATOR_NODE})
			if not heard.is_empty():
				situation.notice("neighbor_heard_riser_hammer")
			autonomous_event.emit("hammer_worsened", {"heard": heard})
		if elapsed >= COMPENSATE_MINUTES:
			porter.consider("riser_complaint", now)
		_evaluate_abandonment(record, elapsed)
	porter.advance_to(now)


func _elapsed_since_offer(record: Dictionary) -> float:
	if _minute_provider.is_valid():
		return situation.elapsed_since("offered_at")
	return float(record.elapsed_simulation_minutes)


## The abandonment boundary is DERIVED from attested world state - the
## mechanism's condition, the inventory's custody, the attended actions -
## never asserted. What the resident believes about it comes only from
## what she could see in her own flat.
func _evaluate_abandonment(record: Dictionary, elapsed: float) -> void:
	if float(record.accepted_at) < 0.0 or \
			float(record.last_attended_at) < 0.0:
		return
	if not str(record.abandonment_boundary).is_empty():
		return
	var attended_after_offer := fposmod(
			float(record.last_attended_at) - float(record.offered_at),
			1440.0)
	var since_attend := elapsed - attended_after_offer
	if since_attend < ABANDON_MINUTES:
		return
	var boundary := _derive_boundary(record)
	if boundary.is_empty():
		return
	situation.record_fact("abandonment_boundary", boundary)
	situation.record_fact("recoverable_next_state",
			"return_to_finish_or_explain")
	situation.merge_residue(_boundary_residue(boundary))
	ledger.witness_visible_state("2B", "help_started_then_stopped",
			{"boundary": boundary,
			 "evidence": str(_boundary_residue(boundary).get(
					"evidence", ""))})
	autonomous_event.emit("abandonment_recorded",
			{"boundary": boundary})


func _derive_boundary(record: Dictionary) -> String:
	if radiator and radiator.packing_location() == "player":
		return "took_part"
	if radiator and radiator.open_shift_condition == "opened_uncommitted":
		return "opened_uncommitted"
	var attempts: Array = record.attempted_actions
	if "returned_without_repair" in attempts:
		return "returned"
	if "named_no_part_fault" in attempts:
		return "named_part"
	if "inspected_radiator" in attempts or "opened_mechanism" in attempts:
		return "inspected"
	return ""


func _boundary_residue(boundary: String) -> Dictionary:
	match boundary:
		"opened_uncommitted":
			return {"evidence": "open_union_and_tool_marks"}
		"took_part":
			return {"evidence": "packing_absent_from_store"}
		"returned":
			return {"evidence": "resident_saw_return"}
		"named_part":
			return {"evidence": "resident_heard_part_named"}
		"inspected":
			return {"evidence": "inspection_marks"}
	return {}


## Physical interactions attested by the mechanism itself. The situation
## records attention/interference; the ledger decides who observed.
func _on_physical_action(action_id: String, result: Dictionary) -> void:
	match action_id:
		"listen", "feel_temperature", "inspect_vent":
			situation.attend("inspected_radiator")
		"inspect_union":
			situation.attend("inspected_radiator")
			if str(result.get("observation", "")) == \
					"packing_removed_from_union":
				situation.attend("removed_packing")
				situation.merge_residue(
						{"evidence": "packing_absent_from_store"})
		"open_service":
			situation.attend("opened_mechanism")
			ledger.witness_visible_state("2B",
					"mechanism_opened_for_service",
					{"evidence": "open_union_and_tool_marks"})
		"turn_valve":
			# result.condition carries the pre-action state; the prop's
			# current condition is the attested outcome.
			if radiator.open_shift_condition == "wrong_valve_partial":
				situation.notice("changed_pipe_sound")
				situation.observe_interference("wrong_valve")
				situation.set_pressure(0.55, 0.62, 0.5)
				situation.merge_residue({
					"heat": "uneven",
					"fault": "worsened_by_wrong_valve",
					"sound": "new_riser_hammer",
					"evidence": "fresh_valve_marks",
				})
				ledger.witness_audible_event(RADIATOR_NODE,
						"pipe_sound_change_after_valve_turn",
						{"source_unit": "2B",
						 "source": RADIATOR_NODE})
				ledger.witness_visible_state("2B",
						"heat_changed_but_fault_remains",
						{"evidence": "fresh_valve_marks"})
				situation.record_fact("recoverable_next_state",
						"restore_supply_balance_then_diagnose")
				autonomous_event.emit("wrong_valve_interference",
						{"evidence": "fresh_valve_marks"})


func _on_porter_event(kind: String, facts: Dictionary) -> void:
	match kind:
		"porter_departed":
			situation.begin_compensation("porter")
			autonomous_event.emit("porter_dispatched",
					{"channel": "riser_complaint"})
		"porter_turned_away":
			situation.merge_residue({
				"compensation": "attempted_but_no_access",
			})
			autonomous_event.emit("porter_turned_away", facts)
		"porter_shutoff_applied":
			# The porter (actor) performed and reported the concrete
			# outcome; the situation records that report.
			situation.record_fact("recoverable_next_state",
					"reopen_supply_then_diagnose_original_fault")
			situation.resolve("porter_temporary_shutoff", {
				"heat": "off_in_2b", "fault": "unrepaired",
				"evidence": "porter_tag_on_valve",
			})
			autonomous_event.emit("porter_temporary_shutoff",
					situation.state().residue)


func _on_route_beat(beat: String) -> void:
	match beat:
		"call":
			situation.notice("service_set_call")
			situation.accept("heard_request")
		"resident":
			if str(situation.state().resolution_kind).is_empty() and \
					float(situation.state().last_attended_at) >= 0.0 \
					and work_orders != null and work_orders.job_stage(
					ServiceRoundDirector.JOB_ID) != "repaired":
				situation.attend("returned_without_repair")
			situation.accept("resident_expects_help")
		"radiator_evidence": situation.attend("inspected_radiator")
		"lobby_comparison": situation.attend("compared_porter_board")
		"basement_comparison": situation.attend("compared_boiler")
		"diagnosis": situation.attend("named_no_part_fault")
		"repair":
			situation.attend("committed_repair")
			porter.cancel("player_repaired_first")
		"resident_return":
			# ServiceRound/WorkOrders attest the repair happened; the
			# situation records that reported concrete result.
			situation.resolve("player_repair", {
				"heat": "restoring", "fault": "repaired",
				"evidence": "resident_saw_visible_patch",
			})


func _acoustic_authority() -> Object:
	var tree := get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null("AcousticGraphData")


func _reconstruct_physical_state() -> void:
	if radiator == null:
		return
	porter.rebind_mechanism(radiator)
	var record := situation.state()
	var kind := str(record.resolution_kind)
	if kind == "porter_temporary_shutoff":
		radiator.apply_open_shift_condition("porter_temporary_shutoff")
	elif "wrong_valve" in record.observed_interference:
		radiator.apply_open_shift_condition("wrong_valve_partial")
	elif "vent_removed" in record.observed_interference:
		radiator.apply_open_shift_condition("vent_removed")
	elif str(record.abandonment_boundary) == "opened_uncommitted":
		radiator.apply_open_shift_condition("opened_uncommitted")
	elif float(record.noticed_at) >= 0.0 and kind.is_empty():
		radiator.apply_open_shift_condition("worsening_hammer")
