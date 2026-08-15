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

	var washer := WasherProp.new()
	washer.name = "TestWasher"
	add_child(washer)
	var lid_area := washer.get_node("LidReach") as PropControlArea
	var release_area := washer.get_node("ReleaseReach") as PropControlArea
	var wringer_area := washer.get_node("FeedReach") as PropControlArea
	var fill_area := washer.get_node("CocksReach") as PropControlArea
	var drain_area := washer.get_node("DrainReach") as PropControlArea
	var lid_card: Dictionary = lid_area.interact(hand)
	release_area.interact(hand)
	wringer_area.interact(hand)
	var drain_card: Dictionary = drain_area.interact(hand)
	var fill_card: Dictionary = fill_area.interact(hand)
	_check("washer controls remain separate ray owners",
			lid_area.interact_prompt().contains("Close washer lid")
			and release_area.interact_prompt().contains("safety release")
			and wringer_area.interact_prompt().contains("Stop wringer rolls")
			and fill_area.interact_prompt().contains("Close washer fill cocks")
			and drain_area.interact_prompt().contains("Open washer drain"))
	_check("washer controls change only their physical mechanism",
			washer._lid_tween.is_running()
			and washer._roller_gap == 0.040
			and washer._wringer_running
			and not washer._drain_open and washer._water.visible
			and lid_card.get("card_id", "") == "washer"
			and str(drain_card.get("condition", "")).contains("DRAIN OPEN")
			and str(fill_card.get("condition", "")).contains("DRAIN CLOSED"))

	var airer := LaundryAirerProp.new()
	airer.name = "TestAirer"
	add_child(airer)
	var rope_area := airer.get_node("AirerReach") as PropControlArea
	var rinse_area := airer.get_node("RinseReach") as PropControlArea
	var airer_card: Dictionary = rope_area.interact(hand)
	var rinse_card: Dictionary = rinse_area.interact(hand)
	_check("airer cleat lowers the rack while rinse stand only answers",
			rope_area.interact_prompt().contains("Raise ceiling airer")
			and rinse_area.interact_prompt().contains("Inspect rinse stand")
			and airer.is_airer_lowered() and airer._rack_tween.is_running()
			and airer_card.get("card_id", "") == "laundry_airer"
			and rinse_card.get("card_id", "") == "laundry_airer"
			and str(airer_card.get("condition", "")).contains("LOW HEADROOM"))

	var lamp := LampProp.new()
	lamp.name = "TestTaskLamp"
	lamp.variant = "office_green"
	add_child(lamp)
	var lamp_card: Dictionary = lamp.interact(hand)
	lamp.set_budget(1.0, false, true)
	_check("local lamp key survives the central lighting budget",
			lamp.get_node_or_null("PrimaryInteraction") is Area3D
			and lamp.interact_prompt().contains("Turn task lamp on")
			and not lamp.is_locally_enabled() and not lamp.light.visible
			and lamp.state == FunctionalProp.PState.OFF
			and lamp._switch_click.playing and lamp._switch_tween.is_running()
			and lamp_card.get("card_id", "") == "lamp"
			and str(lamp_card.get("condition", "")).contains("CONTROL OFF"))

	var receiver := MonitorProp.new()
	receiver.name = "TestCaseReceiver"
	receiver.graph_node_id = "F02_A_MONITOR_01"
	add_child(receiver)
	var receiver_card: Dictionary = receiver.interact(hand)
	_check("line receiver tunes locally without erasing case signal",
			receiver.get_node_or_null("PrimaryInteraction") is Area3D
			and receiver.interact_prompt().contains("Widen receiver tuning")
			and receiver.state == FunctionalProp.PState.OPERATING
			and receiver._narrow_tuning
			and receiver._tuning_click.playing
			and receiver._tuning_tween.is_running()
			and receiver_card.get("card_id", "") == "television"
			and str(receiver_card.get("condition", "")).contains("POWER LINE LIVE")
			and str(receiver_card.get("condition", "")).contains("TUNING NARROW"))

	await get_tree().create_timer(0.03).timeout
	await get_tree().process_frame
	await get_tree().process_frame
	print("    motion latch=%.4f chain=%.4f lock=%.4f lid=%.4f airer=%.4f" % [
			case_door._knob.rotation.z, cart._night_chain.rotation.z,
			cart._night_lock.rotation.z, washer._lid.rotation.x,
			airer._rack.position.y])
	_check("case latch and cart chain visibly moved",
			absf(case_door._knob.rotation.z) > 0.001
			and (absf(cart._night_chain.rotation.z) > 0.001
					or absf(cart._night_lock.rotation.z) > 0.001)
			and absf(washer._lid.rotation.x) > 0.001
			and airer._rack.position.y < 1.98)

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
