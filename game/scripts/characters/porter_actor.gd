class_name PorterActor
extends Node
## The building porter as a persistent actor. Elapsed time can make him
## ELIGIBLE to act; it never stands in for the action. He forms an
## intention, finishes his board round, travels from the F01 watch
## station, needs real access to 2B, inspects with his own senses, and
## performs the shutoff through the mechanism's own API - or is turned
## away and the intervention honestly does not occur. Every step is a
## durable fact under RealityState.data.porter_actor, so save/load and
## scene unload reconstruct the same timeline deterministically.

signal porter_event(kind: String, facts: Dictionary)

const NPC_ID := "building_porter"
const SOURCE := "F01_WATCH"
## He finishes the board round he is on before departing.
const DISPATCH_DELAY_MINUTES := 2.0
## Watch station -> public core -> F02 west hall -> 2B, off screen.
const TRAVEL_MINUTES := 4.0
## Looking, listening and tagging before touching the valve.
const INSPECTION_MINUTES := 1.0

var radiator: Node
var ledger: NpcObservationLedger
## Answers whether the porter can physically reach and enter 2B right
## now (door reachable, not barred). Invalid means reachable.
var access_provider: Callable


func setup(mechanism: Node, observation_ledger: NpcObservationLedger,
		access := Callable()) -> void:
	radiator = mechanism
	ledger = observation_ledger
	access_provider = access
	_store()


func state() -> Dictionary:
	return _store().duplicate(true)


## The coordinator schedules: the porter becomes eligible with a reason.
func consider(reason: String, now: float) -> bool:
	var record := _store()
	if not str(record.intent).is_empty() or record.cancelled:
		return false
	record.intent = reason
	record.eligible_at = now
	RealityState.commit()
	porter_event.emit("porter_considering", {"reason": reason})
	return true


## The player (or anything else) resolved the fault first: the porter's
## errand evaporates before he acts.
func cancel(reason: String) -> void:
	var record := _store()
	if record.cancelled or record.acted_at >= 0.0:
		return
	record.cancelled = true
	record.cancel_reason = reason
	RealityState.commit()
	porter_event.emit("porter_stood_down", {"reason": reason})


## Deterministic catch-up: phase derives purely from durable timestamps
## and `now`, so unloading, reloading, saving or frame rate cannot pause,
## repeat or accelerate him.
func advance_to(now: float) -> void:
	var record := _store()
	if record.cancelled or record.acted_at >= 0.0 or \
			str(record.intent).is_empty():
		_reconcile_physical()
		return
	if record.departed_at < 0.0 and \
			now >= float(record.eligible_at) + DISPATCH_DELAY_MINUTES:
		record.departed_at = float(record.eligible_at) + \
				DISPATCH_DELAY_MINUTES
		RealityState.commit()
		porter_event.emit("porter_departed", {"from": SOURCE})
	if record.departed_at < 0.0:
		return
	var arrival_due := float(record.departed_at) + TRAVEL_MINUTES
	if record.arrived_at < 0.0 and now >= arrival_due:
		if not _can_access():
			if str(record.blocked_reason).is_empty():
				record.blocked_reason = "cannot_reach_2b"
				RealityState.commit()
				ledger.record_direct_observation(NPC_ID,
						"could_not_reach_reported_fault",
						"attempted_visit", "F02_WEST_HALL",
						{"reason": "no_access_to_2b"})
				porter_event.emit("porter_turned_away",
						{"reason": "no_access_to_2b"})
			return
		var was_blocked := not str(record.blocked_reason).is_empty()
		record.blocked_reason = ""
		# A porter who was turned away arrives only when access is
		# actually restored, not retroactively on the old schedule.
		record.arrived_at = now if was_blocked else arrival_due
		RealityState.commit()
		ledger.record_direct_observation(NPC_ID,
				"found_unresolved_fault", "direct_inspection", "2B",
				_mechanism_evidence())
		porter_event.emit("porter_arrived", {"at": "2B"})
	if record.arrived_at >= 0.0 and record.acted_at < 0.0 and \
			now >= float(record.arrived_at) + INSPECTION_MINUTES:
		record.acted_at = float(record.arrived_at) + INSPECTION_MINUTES
		record.applied_condition = "porter_temporary_shutoff"
		RealityState.commit()
		if radiator != null:
			radiator.apply_open_shift_condition("porter_temporary_shutoff")
		ledger.witness_visible_state("2B", "porter_shut_heat_off",
				{"evidence": "porter_tag_on_valve"})
		porter_event.emit("porter_shutoff_applied", {
			"heat": "off_in_2b", "fault": "unrepaired",
			"evidence": "porter_tag_on_valve",
		})


## After save/load or a room rebuild the mechanism reapplies the durable
## outcome; the porter never re-performs the action.
func rebind_mechanism(mechanism: Node) -> void:
	radiator = mechanism
	_reconcile_physical()


func _reconcile_physical() -> void:
	var record := _store()
	if radiator == null or record.acted_at < 0.0:
		return
	var applied := str(record.applied_condition)
	if not applied.is_empty() and \
			str(radiator.get("open_shift_condition")) != applied:
		radiator.apply_open_shift_condition(applied)


func _can_access() -> bool:
	if access_provider.is_valid():
		return bool(access_provider.call())
	return true


func _mechanism_evidence() -> Dictionary:
	if radiator != null and radiator.has_method("get_heat_state"):
		var heat: Dictionary = radiator.get_heat_state()
		return {"condition": str(heat.get("open_shift_condition", ""))}
	return {"condition": "unobserved_mechanism"}


func _store() -> Dictionary:
	if not RealityState.data.has("porter_actor"):
		RealityState.data.porter_actor = {
			"intent": "", "eligible_at": -1.0, "departed_at": -1.0,
			"arrived_at": -1.0, "acted_at": -1.0,
			"applied_condition": "", "blocked_reason": "",
			"cancelled": false, "cancel_reason": "",
			"source": SOURCE, "target": "F02_B_RADIATOR_01",
		}
	return RealityState.data.porter_actor
