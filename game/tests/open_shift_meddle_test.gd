extends Node
## MEDDLE disposition: the player turns the wrong valve through the
## radiator's own public surface. The mechanism mutates itself, the
## acoustic fabric decides who heard the change, and interference is
## recorded as observation - never as authored knowledge.

const Ecosystem := preload("res://scripts/game/open_shift_radiator_ecosystem.gd")

var failures := 0
var minute := 500.0


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var radiator := RadiatorProp.new()
	radiator.prop_type = "radiator"
	add_child(radiator)
	var ecosystem := Ecosystem.new()
	add_child(ecosystem)
	ecosystem.setup(null, radiator, null, func(): return minute)
	ecosystem.situation.offer(ServiceRoundDirector.RESIDENT_ID)
	var surface := _find_surface(radiator, "turn_valve")
	_check(surface != null, "the supply valve is a public surface")
	surface.interact(null)
	var state := ecosystem.situation.state()
	var heat := radiator.get_heat_state()
	_check(radiator.open_shift_condition == "wrong_valve_partial" and
			bool(heat.get("supply_partial", false)),
			"the mechanism owns the wrong-valve outcome")
	_check("wrong_valve" in state.observed_interference,
			"interference is recorded as an observation")
	_check(state.residue.get("evidence", "") == "fresh_valve_marks",
			"meddling leaves physical evidence")
	_check(str(state.recoverable_next_state) ==
			"restore_supply_balance_then_diagnose",
			"the world stays recoverable, not failed")
	_check(ecosystem.ledger.has_learned("omar_bell",
			"heard_pipe_sound_change_after_valve_turn"),
			"the riser neighbor hears the change acoustically")
	_check(ecosystem.ledger.has_learned(
			ServiceRoundDirector.RESIDENT_ID,
			"heat_changed_but_fault_remains"),
			"the resident notices the heat change at home")
	_check(not state.has("npc_knowledge"),
			"no coordinator-authored knowledge exists")
	_check(RealityState.data.maintenance_jobs.is_empty(),
			"meddling invents no job")
	# Reconstruction under a fresh mechanism.
	var rebuilt := RadiatorProp.new()
	rebuilt.prop_type = "radiator"
	add_child(rebuilt)
	var second := Ecosystem.new()
	add_child(second)
	second.setup(null, rebuilt, null, func(): return minute)
	_check(rebuilt.open_shift_condition == "wrong_valve_partial",
			"interference residue reconstructs on the mechanism")
	print("OPEN SHIFT MEDDLE TEST: %s" %
			("PASS" if failures == 0 else "FAIL"))
	get_tree().quit(failures)


func _find_surface(root: Node, action_id: String) -> Node:
	for child in root.find_children("*", "Area3D", true, false):
		if str(child.get("action_id")) == action_id:
			return child
	return null


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  PASS  " + label)
	else:
		failures += 1
		push_error("  FAIL  " + label)
