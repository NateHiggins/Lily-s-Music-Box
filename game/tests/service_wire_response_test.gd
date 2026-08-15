extends Node
## Focused I4 refusal/response proof. These were the four known ways a real
## ray target could consume E without a physical or textual answer.

var _fails := 0


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
	if not ok:
		_fails += 1


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	_check("researched service-wire book parses", PropServiceWire.is_valid())
	_check("missing owner state invalidates rather than invents copy",
			PropServiceWire.card("toaster", {}).is_empty())
	_check("case routing template can never present as generic copy",
			PropServiceWire.card("case_object", {
				"owner_title": "TEST", "owner_period_fact": "TEST STOP",
				"owner_condition": "TEST"}).is_empty())

	var hand := Node3D.new()
	hand.name = "TestHand"
	add_child(hand)

	var case_door := CaseDoorProp.new()
	case_door.name = "TestCaseDoor"
	add_child(case_door)
	case_door.reveal()
	var door_card: Dictionary = case_door.interact(hand)
	_check("revealed case door offers a physical latch attempt",
			case_door.interact_prompt().contains("Try")
			and case_door._rattle.playing
			and case_door._rattle_tween.is_running()
			and door_card.get("card_id", "") == "service_door"
			and str(door_card.get("condition", "")).contains("NO WORK ORDER"))

	var cart := PassagePushcart.new()
	cart.setup("test", "empty")
	add_child(cart)
	cart.set_after_hours_locked(true)
	var before := cart.linear_velocity
	var cart_card: Dictionary = cart.interact(hand)
	_check("chained cart rattles and names the restraint",
			cart.interact_prompt().contains("Rattle")
			and cart._chain_rattle.playing
			and cart._chain_tween.is_running()
			and cart_card.get("card_id", "") == "pushcart"
			and str(cart_card.get("condition", "")).contains("PADLOCKED")
			and cart.linear_velocity == before and cart.freeze)

	var toaster := ToasterProp.new()
	toaster.unit = "TEST"
	add_child(toaster)
	var start_card: Dictionary = toaster.interact(hand)
	var stage_after_start := toaster.state
	var busy_card: Dictionary = toaster.interact(hand)
	_check("toaster starts normally and reports its new state",
			stage_after_start == FunctionalProp.PState.STARTING
			and start_card.get("card_id", "") == "toaster")
	_check("busy toaster keeps a prompt and answers the second hand",
			toaster.interact_prompt().contains("latched")
			and toaster._click.playing
			and busy_card.get("card_id", "") == "toaster"
			and toaster.state == stage_after_start)

	var shop_service := MaintenanceShopService.new()
	shop_service.setup(null, null)
	add_child(shop_service)
	var counter := MaintenanceShopCounter.new()
	counter.setup(shop_service, "hardware_paint")
	add_child(counter)
	var counter_card: Dictionary = counter.interact(hand)
	_check("jobless counter inspects instead of swallowing E",
			counter.interact_prompt() == "[E]  Inspect hardware counter"
			and counter._counter_tap.playing
			and counter_card.get("card_id", "") == "hardware_counter"
			and str(counter_card.get("condition", "")).contains(
					"NO OPEN ORDER"))

	await get_tree().create_timer(0.03).timeout
	await get_tree().process_frame
	await get_tree().process_frame
	print("    motion latch=%.4f chain=%.4f lock=%.4f" % [
			case_door._knob.rotation.z, cart._night_chain.rotation.z,
			cart._night_lock.rotation.z])
	_check("case latch and cart chain visibly moved",
			absf(case_door._knob.rotation.z) > 0.001
			and (absf(cart._night_chain.rotation.z) > 0.001
					or absf(cart._night_lock.rotation.z) > 0.001))

	print("[SERVICE WIRE RESPONSE] RESULT: %s (%d failures)" % [
			"PASS" if _fails == 0 else "FAIL", _fails])
	for child in get_children():
		child.queue_free()
	PropServiceWire.clear_cache_for_tests()
	PropAudio.clear_cache()
	MatLib._cache.clear()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(_fails)
