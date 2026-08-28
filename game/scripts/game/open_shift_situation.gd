class_name OpenShiftSituation
extends Node
## Durable observation/co-ordination facts for one domain-owned situation.
## This node never repairs a mechanism, advances a job/case, or requests a dream.

signal fact_changed(situation_id: String, fact: String, state: Dictionary)

var situation_id := ""
var _minute_provider: Callable


func setup(id: String, minute_provider: Callable) -> void:
	situation_id = id
	_minute_provider = minute_provider
	_store()


func state() -> Dictionary:
	return _store().duplicate(true)


func offer(owner: String, urgency := 0.15, severity := 0.2) -> bool:
	return _stamp_once("offered_at", {
		"social_owner": owner,
		"urgency": clampf(urgency, 0.0, 1.0),
		"physical_severity": clampf(severity, 0.0, 1.0),
	})


func notice(channel: String) -> bool:
	return _stamp_once("noticed_at", {"noticed_through": channel})


func accept(commitment := "promised") -> bool:
	return _stamp_once("accepted_at", {"player_commitment": commitment})


func attend(action: String) -> void:
	var record := _store()
	record.last_attended_at = _minute_now()
	_append_unique(record.attempted_actions, action)
	_commit("attempted_actions")


func observe_interference(action: String, observer := "") -> void:
	var record := _store()
	_append_unique(record.observed_interference, action)
	if not observer.is_empty():
		record.last_observer = observer
	_commit("observed_interference")


func set_pressure(urgency: float, severity: float, social: float) -> void:
	var record := _store()
	record.urgency = clampf(urgency, 0.0, 1.0)
	record.physical_severity = clampf(severity, 0.0, 1.0)
	record.social_pressure = clampf(social, 0.0, 1.0)
	_commit("pressure")


func begin_compensation(actor: String) -> bool:
	return _stamp_once("compensation_started_at", {"compensator": actor})


## NPC knowledge, relationships and item custody are deliberately NOT
## recordable here: beliefs belong to NpcObservationLedger (earned through
## evidence routes), custody belongs to MaintenanceInventory. This store
## keeps observation/coordination facts about the situation itself.
func record_fact(fact: String, value: Variant) -> bool:
	if fact not in ["abandonment_boundary",
			"recoverable_next_state", "elapsed_simulation_minutes"]:
		return false
	var record := _store()
	record[fact] = value.duplicate(true) if value is Dictionary or value is Array \
			else value
	_commit(fact)
	return true


## Domain owners report concrete physical outcomes into the residue through
## this API; nothing reaches into the raw record from outside.
func merge_residue(facts: Dictionary) -> void:
	if facts.is_empty():
		return
	var record := _store()
	var residue: Dictionary = record.residue
	residue.merge(facts.duplicate(true), true)
	_commit("residue")


func advance_simulation_minutes(amount: float) -> void:
	if amount <= 0.0:
		return
	var record := _store()
	record.elapsed_simulation_minutes = maxf(0.0,
			float(record.elapsed_simulation_minutes) + amount)
	_commit("elapsed_simulation_minutes")


func resolve(kind: String, residue_facts: Dictionary) -> bool:
	var record := _store()
	if not str(record.resolution_kind).is_empty():
		return false
	record.resolution_kind = kind
	record.residue = residue_facts.duplicate(true)
	record.closed_at = _minute_now()
	_commit("resolution_kind")
	return true


func elapsed_since(fact: String) -> float:
	var at := float(_store().get(fact, -1.0))
	if at < 0.0:
		return 0.0
	return fposmod(_minute_now() - at, 1440.0)


func _stamp_once(fact: String, extra: Dictionary) -> bool:
	var record := _store()
	if float(record.get(fact, -1.0)) >= 0.0:
		return false
	record[fact] = _minute_now()
	for key in extra:
		record[key] = extra[key]
	_commit(fact)
	return true


func _minute_now() -> float:
	if _minute_provider.is_valid():
		return fposmod(float(_minute_provider.call()), 1440.0)
	# Without an injected clock, the situation's own durable simulation
	# minutes are the clock, so timestamps stay meaningful in production
	# and reconstruct deterministically after save/load.
	return fposmod(180.0 + float(_store().elapsed_simulation_minutes),
			1440.0)


func _store() -> Dictionary:
	if not RealityState.data.has("open_shift_situations"):
		RealityState.data.open_shift_situations = {}
	var all: Dictionary = RealityState.data.open_shift_situations
	if not all.has(situation_id):
		all[situation_id] = {
			"offered_at": -1.0, "noticed_at": -1.0,
			"accepted_at": -1.0, "last_attended_at": -1.0,
			"urgency": 0.0, "physical_severity": 0.0,
			"social_pressure": 0.0, "social_owner": "",
			"player_commitment": "none", "attempted_actions": [],
			"observed_interference": [], "compensator": "",
			"compensation_started_at": -1.0, "resolution_kind": "",
			"residue": {}, "closed_at": -1.0,
			"elapsed_simulation_minutes": 0.0,
			"abandonment_boundary": "",
			"recoverable_next_state": "inspect_and_repair",
		}
	return all[situation_id]


func _append_unique(values: Array, value: String) -> void:
	if not value.is_empty() and value not in values:
		values.append(value)


func _commit(fact: String) -> void:
	RealityState.commit()
	fact_changed.emit(situation_id, fact, state())
