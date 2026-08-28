extends Node
## ABANDON disposition: the boundary is DERIVED from attested world state
## - the mechanism's condition, the inventory's custody, the recorded
## attention - after real neglect minutes. Nothing ever declares an
## abandonment outcome directly, and the resident's belief comes only
## from what is visible in her own flat.

const Ecosystem := preload("res://scripts/game/open_shift_radiator_ecosystem.gd")

var failures := 0
var minute := 0.0


func _ready() -> void:
	RealityState.persistence_enabled = false
	for expectation: Array in [
		["inspected", ["listen"], "inspection_marks"],
		["opened_uncommitted", ["open_service"],
			"open_union_and_tool_marks"],
		["took_part", ["open_service", "inspect_union"],
			"packing_absent_from_store"],
	]:
		_exercise_boundary(str(expectation[0]), expectation[1],
				str(expectation[2]))
	_exercise_dialogue_boundary("named_part", "named_no_part_fault",
			"resident_heard_part_named")
	_exercise_dialogue_boundary("returned", "returned_without_repair",
			"resident_saw_return")
	print("OPEN SHIFT ABANDON TEST: %s" %
			("PASS" if failures == 0 else "FAIL"))
	get_tree().quit(failures)


func _compose() -> Ecosystem:
	RealityState.reset_campaign_for_tests()
	minute = 400.0
	var inventory := MaintenanceInventory.new()
	inventory.setup()
	add_child(inventory)
	var radiator := RadiatorProp.new()
	radiator.prop_type = "radiator"
	add_child(radiator)
	radiator.bind_inventory(inventory)
	var ecosystem := Ecosystem.new()
	add_child(ecosystem)
	ecosystem.setup(null, radiator, null, func(): return minute)
	ecosystem.situation.offer(ServiceRoundDirector.RESIDENT_ID)
	ecosystem.situation.accept("help_implied")
	return ecosystem


func _exercise_boundary(boundary: String, surfaces: Array,
		evidence: String) -> void:
	var ecosystem := _compose()
	for action in surfaces:
		var surface := _find_surface(ecosystem.radiator, str(action))
		if surface == null:
			failures += 1
			push_error("  FAIL  missing surface " + str(action))
			return
		surface.interact(null)
	_finish_boundary(ecosystem, boundary, evidence)


func _exercise_dialogue_boundary(boundary: String, attend: String,
		evidence: String) -> void:
	var ecosystem := _compose()
	# Dialogue-derived attention beats are attested through the service
	# round in production (see open_shift_work_test); the situation's
	# observation API records the same attested beat here.
	ecosystem.situation.attend(attend)
	_finish_boundary(ecosystem, boundary, evidence)


func _finish_boundary(ecosystem: Ecosystem, boundary: String,
		evidence: String) -> void:
	minute += Ecosystem.ABANDON_MINUTES + 1.0
	ecosystem.advance_autonomy()
	var state := ecosystem.situation.state()
	_check(str(state.abandonment_boundary) == boundary,
			"%s boundary derives from attested state" % boundary)
	_check(str(state.residue.get("evidence", "")) == evidence,
			"%s leaves its own physical evidence" % boundary)
	_check(str(state.resolution_kind).is_empty(),
			"%s stays unresolved and recoverable" % boundary)
	_check(str(state.recoverable_next_state) ==
			"return_to_finish_or_explain",
			"%s names an honest next state" % boundary)
	_check(ecosystem.ledger.has_learned(
			ServiceRoundDirector.RESIDENT_ID,
			"help_started_then_stopped"),
			"%s: the resident learns only from visible residue" % boundary)
	if boundary == "took_part":
		_check(ecosystem.radiator.packing_location() == "player",
				"took_part custody lives in the inventory authority")
	_check(not state.has("part_custody") and
			not state.has("npc_knowledge"),
			"%s: no shadow custody or authored beliefs" % boundary)


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
