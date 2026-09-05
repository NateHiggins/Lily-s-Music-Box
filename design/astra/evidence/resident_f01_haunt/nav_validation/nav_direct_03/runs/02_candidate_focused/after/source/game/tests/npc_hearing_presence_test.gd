extends Node
## Sound at a flat reaches a resident only while that resident is there.
## This exercises the observation owner; it does not simulate an audible mix.

class AcousticFixture extends RefCounted:
	func audibility(_origin: String) -> Array:
		return [{"room": "2B", "strength": 1.0},
			{"room": "3B", "strength": 0.4},
			{"room": "4D", "strength": 0.1}]

var present := {"lena": false, "omar": true, "distant": true}
var minute := 900.25
var passed := 0
var failed := 0


func _ready() -> void:
	var old_persistence := RealityState.persistence_enabled
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var acoustic := AcousticFixture.new()
	var ledger := NpcObservationLedger.new()
	add_child(ledger)
	ledger.setup([
		{"npc": "lena", "unit": "2B"}, {"npc": "omar", "unit": "3B"},
		{"npc": "distant", "unit": "4D"}],
		func(): return minute, acoustic,
		func(npc): return bool(present.get(npc, false)), "campaign_absolute_minutes")
	var evidence := {"source_unit": "2B", "source": "F02_B_RADIATOR_01"}
	var heard := ledger.witness_audible_event("F02_B_RADIATOR_01", "missed_hammer", evidence)
	_check(heard == ["omar"], "only the present riser neighbor hears the event")
	_check(not ledger.has_learned("lena", "heard_missed_hammer"),
		"the absent source-flat resident earns no hearing belief")
	_check(ledger.beliefs("distant").is_empty(), "presence does not bypass acoustic threshold")
	present.lena = true
	minute += 5.0
	_check(not ledger.has_learned("lena", "heard_missed_hammer"),
		"returning home does not replay a missed sound")
	heard = ledger.witness_audible_event("F02_B_RADIATOR_01", "new_hammer", evidence)
	_check(heard == ["lena", "omar"], "a later sound reaches both now-present residents")
	var local := _belief(ledger, "lena", "heard_new_hammer")
	var riser := _belief(ledger, "omar", "heard_new_hammer")
	_check(local.get("channel") == "in_home_hearing" and local.get("where") == "2B",
		"the source-flat belief retains its local evidence route")
	_check(riser.get("channel") == "heating_riser" and riser.get("where") == "3B",
		"the neighbor belief retains its propagated evidence route")
	_check(local.get("clock_basis") == "campaign_absolute_minutes"
		and absf(float(local.get("at_minutes", -1)) - minute) < 0.000001,
		"the earned belief uses the supplied simulation clock")
	evidence.source = "changed_after_event"
	_check(local.get("evidence", {}).get("source") == "F02_B_RADIATOR_01",
		"recorded evidence is an owned copy")
	_check(ledger.witness_audible_event("F02_B_RADIATOR_01", "new_hammer", evidence).is_empty(),
		"the same learned event remains deduplicated")
	present.omar = false
	heard = ledger.witness_audible_event("F02_B_RADIATOR_01", "third_hammer", evidence)
	_check(heard == ["lena"] and not ledger.has_learned("omar", "heard_third_hammer"),
		"an absent riser neighbor cannot hear through their empty flat")
	_check(ledger.record_direct_observation("omar", "read_corridor_notice", "document",
		"F03_CORRIDOR", {"source": "owned_notice"}),
		"an actor's explicit direct observation remains independent of home presence")
	ledger.free()
	RealityState.reset_campaign_for_tests()
	ledger = NpcObservationLedger.new()
	add_child(ledger)
	ledger.setup([{"npc": "lena", "unit": "2B"}], func(): return minute,
		null, func(_npc): return false)
	_check(ledger.witness_audible_event("2B", "fallback_sound", {"source_unit": "2B"}).is_empty(),
		"the source-unit-only fallback also respects absence")
	ledger.free()
	RealityState.reset_campaign_for_tests()
	RealityState.persistence_enabled = old_persistence
	print("NPC HEARING PRESENCE: %s %d/%d" % ["PASS" if failed == 0 else "FAIL", passed, passed + failed])
	get_tree().quit(failed)


func _belief(ledger: NpcObservationLedger, npc: String, learned: String) -> Dictionary:
	for belief: Dictionary in ledger.beliefs(npc):
		if belief.get("learned") == learned:
			return belief
	return {}


func _check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
	print("[HEARING] %s %s" % ["PASS" if ok else "FAIL", label])
