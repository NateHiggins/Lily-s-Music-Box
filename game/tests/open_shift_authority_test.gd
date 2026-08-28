extends Node
## Focused authority proofs for the corrected Open Shift: knowledge is
## earned, actors act, custody is singular, time is simulation-owned,
## and neither scene lifetime nor save/load can pause, repeat or
## accelerate a consequence.

const Ecosystem := preload("res://scripts/game/open_shift_radiator_ecosystem.gd")

var failures := 0
var minute := 100.0


func _ready() -> void:
	RealityState.persistence_enabled = false
	_knowledge_absent_before_observation()
	_two_observers_two_beliefs()
	_unreachable_porter_does_not_act()
	_delayed_offscreen_is_deterministic()
	_packing_has_one_custodian()
	_save_load_mid_transit_preserves_authority()
	await _room_lifetime_cannot_warp_consequences()
	print("OPEN SHIFT AUTHORITY TEST: %s" %
			("PASS" if failures == 0 else "FAIL"))
	get_tree().quit(failures)


func _compose(access := Callable()) -> Ecosystem:
	RealityState.reset_campaign_for_tests()
	minute = 100.0
	var radiator := RadiatorProp.new()
	radiator.prop_type = "radiator"
	add_child(radiator)
	var ecosystem := Ecosystem.new()
	add_child(ecosystem)
	ecosystem.setup(null, radiator, null, func(): return minute,
			null, null, access)
	ecosystem.situation.offer(ServiceRoundDirector.RESIDENT_ID)
	return ecosystem


func _knowledge_absent_before_observation() -> void:
	var ecosystem := _compose()
	_check(ecosystem.ledger.beliefs("omar_bell").is_empty() and
			ecosystem.ledger.beliefs(
					ServiceRoundDirector.RESIDENT_ID).is_empty(),
			"nobody knows anything before an observable event")
	minute = 106.0
	ecosystem.advance_autonomy()
	_check(not ecosystem.ledger.beliefs("omar_bell").is_empty(),
			"knowledge appears only after the hearable event")


func _two_observers_two_beliefs() -> void:
	var ecosystem := _compose()
	for step: float in [6.0, 13.0, 16.0, 21.0, 23.0]:
		minute = 100.0 + step
		ecosystem.advance_autonomy()
	var omar := ecosystem.ledger.beliefs("omar_bell")
	var lena := ecosystem.ledger.beliefs(
			ServiceRoundDirector.RESIDENT_ID)
	var omar_learned: Array = omar.map(func(b): return b.learned)
	var lena_learned: Array = lena.map(func(b): return b.learned)
	_check("heard_riser_hammer_worsening" in omar_learned and
			"porter_shut_heat_off" not in omar_learned,
			"the riser neighbor knows only what the riser carried")
	_check("porter_shut_heat_off" in lena_learned,
			"the resident knows what the tag in her flat shows")
	_check(omar[0].channel == "heating_riser" and
			lena.back().channel == "in_home_sight",
			"different evidence routes leave different provenance")


func _unreachable_porter_does_not_act() -> void:
	var ecosystem := _compose(func(): return false)
	for step: float in [6.0, 13.0, 16.0, 21.0, 25.0]:
		minute = 100.0 + step
		ecosystem.advance_autonomy()
	var porter := ecosystem.porter.state()
	var state := ecosystem.situation.state()
	_check(str(porter.blocked_reason) == "cannot_reach_2b" and
			float(porter.acted_at) < 0.0,
			"a porter who cannot reach 2B is turned away")
	_check(ecosystem.radiator.open_shift_condition != \
			"porter_temporary_shutoff" and
			str(state.resolution_kind).is_empty(),
			"the intervention does not silently occur")
	_check(str(state.residue.get("compensation", "")) ==
			"attempted_but_no_access",
			"the failed attempt is honest continuing state")


func _delayed_offscreen_is_deterministic() -> void:
	var outcomes: Array = []
	for run in 2:
		var ecosystem := _compose()
		for step: float in [6.0, 14.0, 40.0]:
			minute = 100.0 + step
			ecosystem.advance_autonomy()
		outcomes.append(ecosystem.porter.state())
	_check(outcomes[0] == outcomes[1],
			"an identical delayed timeline reconstructs identically")
	_check(float(outcomes[0].arrived_at) ==
			float(outcomes[0].departed_at) + PorterActor.TRAVEL_MINUTES
			and float(outcomes[0].acted_at) ==
			float(outcomes[0].arrived_at) +
			PorterActor.INSPECTION_MINUTES,
			"off-screen phases land at their scheduled minutes")


func _packing_has_one_custodian() -> void:
	var ecosystem := _compose()
	var inventory := MaintenanceInventory.new()
	inventory.setup()
	add_child(inventory)
	var radiator := ecosystem.radiator
	radiator.bind_inventory(inventory)
	_check(radiator.packing_location() == "radiator",
			"packing starts at the mechanism")
	_surface(radiator, "open_service").interact(null)
	_surface(radiator, "inspect_union").interact(null)
	_check(radiator.packing_location() == "player" and
			inventory.has_item(RadiatorProp.PACKING_ITEM),
			"pickup transfers custody through the inventory")
	_check(not inventory.grant(RadiatorProp.PACKING_ITEM, "elsewhere"),
			"a second grant of the same packing is refused")
	radiator.apply_maintenance_result({
		"mechanism_patch": {"vent_grade": 2, "supply_position": 1.0}})
	_check(radiator.packing_location() == "consumed" and
			inventory.is_consumed(RadiatorProp.PACKING_ITEM),
			"repair consumes the carried packing exactly once")
	_check(not radiator._repair_prerequisites_satisfied() or
			radiator.open_shift_condition == "repaired",
			"absent packing prevents any further repair")


func _save_load_mid_transit_preserves_authority() -> void:
	var ecosystem := _compose()
	for step: float in [6.0, 13.0, 16.0]:
		minute = 100.0 + step
		ecosystem.advance_autonomy()
	var mid := ecosystem.porter.state()
	_check(float(mid.departed_at) >= 0.0 and float(mid.acted_at) < 0.0,
			"the porter is genuinely mid-transit")
	var payload := JSON.stringify(RealityState.data)
	RealityState.reset_campaign_for_tests()
	var parsed: Dictionary = JSON.parse_string(payload)
	RealityState.data.merge(parsed, true)
	var rebuilt := RadiatorProp.new()
	rebuilt.prop_type = "radiator"
	add_child(rebuilt)
	var second := Ecosystem.new()
	add_child(second)
	second.setup(null, rebuilt, null, func(): return minute)
	_check(second.porter.state().departed_at == mid.departed_at,
			"save/load preserves the actor's own timeline")
	minute = 125.0
	second.advance_autonomy()
	_check(rebuilt.open_shift_condition == "porter_temporary_shutoff"
			and float(second.porter.state().acted_at) ==
			float(mid.departed_at) + PorterActor.TRAVEL_MINUTES +
			PorterActor.INSPECTION_MINUTES,
			"the reloaded porter finishes the same errand once")


func _room_lifetime_cannot_warp_consequences() -> void:
	var ecosystem := _compose()
	for step: float in [6.0, 13.0, 16.0]:
		minute = 100.0 + step
		ecosystem.advance_autonomy()
	# The 2B room unloads: the mechanism node dies, the world does not.
	ecosystem.radiator.queue_free()
	ecosystem.radiator = null
	ecosystem.porter.rebind_mechanism(null)
	await get_tree().process_frame
	minute = 125.0
	ecosystem.advance_autonomy()
	var porter := ecosystem.porter.state()
	_check(float(porter.acted_at) >= 0.0,
			"unloading the room does not pause the porter's errand")
	# The room reloads: the durable outcome lands exactly once.
	var reloaded := RadiatorProp.new()
	reloaded.prop_type = "radiator"
	add_child(reloaded)
	ecosystem.radiator = reloaded
	ecosystem.porter.rebind_mechanism(reloaded)
	_check(reloaded.open_shift_condition == "porter_temporary_shutoff",
			"reloading the room applies the durable outcome")
	var acted := float(porter.acted_at)
	minute = 140.0
	ecosystem.advance_autonomy()
	_check(float(ecosystem.porter.state().acted_at) == acted,
			"reloading cannot repeat or accelerate the consequence")


func _surface(root: Node, action_id: String) -> Node:
	for child in root.find_children("*", "Area3D", true, false):
		if str(child.get("action_id")) == action_id:
			return child
	failures += 1
	push_error("  FAIL  missing surface " + action_id)
	return null


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  PASS  " + label)
	else:
		failures += 1
		push_error("  FAIL  " + label)
