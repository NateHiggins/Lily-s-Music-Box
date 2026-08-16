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

	var anomaly_file := FileAccess.open(
			"res://data/domestic_anomaly_props.json", FileAccess.READ)
	var anomaly_book: Variant = JSON.parse_string(
			anomaly_file.get_as_text() if anomaly_file else "")
	var anomaly_specs: Array = anomaly_book.get("props", []) \
			if anomaly_book is Dictionary else []
	var anomaly_kinds := {}
	var anomaly_complete := 0
	var anomaly_reactive := 0
	var anomaly_clue_leaks := 0
	var radio_sample: PossessedDomesticProp
	for entry in anomaly_specs:
		var spec: Dictionary = entry
		var anomaly := PossessedDomesticProp.new()
		anomaly.configure(spec)
		add_child(anomaly)
		anomaly_kinds[anomaly.kind] = true
		var card: Dictionary = anomaly.interact(hand)
		var source_ids: Variant = card.get("source_ids", [])
		if anomaly.get_node_or_null("PrimaryInteraction") is Area3D \
				and not str(card.get("title", "")).is_empty() \
				and not str(card.get("body", "")).is_empty() \
				and not str(card.get("condition", "")).is_empty() \
				and source_ids is Array and not source_ids.is_empty() \
				and card.get("card_id", "") == "case_object":
			anomaly_complete += 1
		if anomaly._inspect_sound.playing:
			anomaly_reactive += 1
		var printed := str(card)
		if printed.contains(anomaly.prop_id) or printed.contains(anomaly.tell):
			anomaly_clue_leaks += 1
		for case_id in anomaly.case_ids:
			if printed.contains(str(case_id)):
				anomaly_clue_leaks += 1
		if anomaly.kind == "table_radio":
			radio_sample = anomaly
	_check("all authored domestic anomalies have exact owner inspections",
			anomaly_specs.size() == 19 and anomaly_kinds.size() == 16
			and PossessedDomesticProp.INSPECTION_COPY.size() == 16
			and anomaly_complete == 19)
	_check("domestic anomaly inspections answer without disclosing clues",
			anomaly_reactive == 19 and anomaly_clue_leaks == 0)
	_check("movable anomaly acknowledges the hand before case authority",
			radio_sample != null and radio_sample._inspect_tween != null
			and radio_sample._inspect_tween.is_running())
	if radio_sample:
		var intrusion_started := radio_sample.stage_haunt(
				str(radio_sample.case_ids[0]), 4, hand)
		_check("case motion pre-empts the neutral handling response",
				intrusion_started and radio_sample._busy
				and not radio_sample._inspect_tween.is_running()
				and radio_sample._display.text == "YESTERDAY")
		if radio_sample._tween:
			radio_sample._tween.kill()
		radio_sample._restore()
		radio_sample._busy = true
		var altered_card := radio_sample.service_wire_card()
		_check("busy anomaly reports appearance without naming its cause",
				str(altered_card.get("condition", "")).contains(
						"VISIBLY ALTERED")
				and not str(altered_card).contains(radio_sample.tell)
				and not str(altered_card).contains(radio_sample.prop_id))
		radio_sample._busy = false

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

	# One owner per storefront, never one target per glyph.  Build the exact
	# generated set so a twelfth shop or a missing trade cannot enter silently.
	var sign_layout_file := FileAccess.open(
			"res://data/building_layout.json", FileAccess.READ)
	var sign_layout: Variant = JSON.parse_string(
			sign_layout_file.get_as_text() if sign_layout_file else "")
	var sign_specs: Array[Dictionary] = []
	if sign_layout is Dictionary:
		for floor_entry in (sign_layout as Dictionary).get("floors", []):
			for marker_entry in (floor_entry as Dictionary).get("markers", []):
				var marker: Dictionary = marker_entry
				if str(marker.get("kind", "")) == "shop_sign":
					sign_specs.append(marker)
	var sign_hours := PassageHoursDirector.new()
	add_child(sign_hours)
	sign_hours.apply_for_minute(180.0)
	sign_hours.set_process(false)
	var sign_names := {}
	var complete_signs := 0
	var reactive_signs := 0
	var ordinary_closed := 0
	var night_service := 0
	for spec in sign_specs:
		var sign := ShopSignProp.new()
		sign.sign_text = str(spec.get("text", "SHOP"))
		sign.shop_name = str(spec.get("shop_name", sign.sign_text))
		sign.trade = str(spec.get("trade", ""))
		sign.sub_text = str(spec.get("sub", ""))
		sign.blade_text = str(spec.get("blade_text", ""))
		sign.blade_dx = float(spec.get("blade_dx", 0.0))
		sign.half_width = float(spec.get("half_width", 2.4))
		sign.compact = bool(spec.get("compact", false))
		sign.bind_hours_director(sign_hours)
		add_child(sign)
		sign_names[sign.shop_name] = true
		var sign_card: Dictionary = sign.interact(hand)
		var sign_area := sign.get_node_or_null("ShopSignInspection") as Area3D
		var expected_shapes := 2 if not sign.blade_text.is_empty() else 1
		if sign_area != null \
				and sign_area.get_child_count() == expected_shapes \
				and sign_area.get_children().all(func(child):
					return child is CollisionShape3D) \
				and sign_card.get("card_id", "") == "shop_sign" \
				and sign_card.get("source_ids", []) == ["R028"] \
				and str(sign_card.get("condition", "")).contains(sign.shop_name):
			complete_signs += 1
		if sign._sign_tap.playing and sign._glint_tween.is_running():
			reactive_signs += 1
		var condition := str(sign_card.get("condition", ""))
		if sign.trade == "hardware" and condition.contains(
				"LIGHT LIT / HOURS NIGHT SERVICE"):
			night_service += 1
		elif sign.trade != "hardware" and condition.contains(
				"LIGHT DARK / HOURS CLOSED"):
			ordinary_closed += 1
	_check("all eleven shop signs own one complete sign-level inspection area",
			sign_specs.size() == 11 and sign_names.size() == 11
			and complete_signs == 11 and reactive_signs == 11)
	_check("shop signs present the hours owner's canonical night state",
			ordinary_closed == 10 and night_service == 1)

	# The three non-neon hero sign assemblies each get one owner-level target.
	# Their children remain visual details: no letter, lamp, screw or kanji stroke
	# can consume E independently.
	var bodega_sign := BodegaSignageProp.new()
	add_child(bodega_sign)
	var bodega_card: Dictionary = bodega_sign.interact(hand)
	var bodega_area := bodega_sign.get_node_or_null(
			"BodegaSignInspection") as Area3D
	_check("the complete bodega fascia owns one sourced inspection",
			bodega_area != null and bodega_area.get_child_count() == 1
			and bodega_sign._inspection_tap.playing
			and bodega_card.get("card_id", "") == "shop_sign"
			and bodega_card.get("source_ids", []) == ["R028"]
			and str(bodega_card.get("condition", "")).contains("HALF BAKED")
			and str(bodega_card.get("condition", "")).contains(
					"OPEN 24 HOURS"))
	bodega_sign._cabinet_dropped = true
	_check("the bodega card reports its real cabinet dropout",
			str(bodega_sign.service_wire_card().get(
					"condition", "")).contains("CABINET DROPOUT"))

	var bar_sign := HarukiyaSignageProp.new()
	add_child(bar_sign)
	var bar_area := bar_sign.get_node_or_null(
			"HarukiyaSignInspection") as Area3D
	var open_card: Dictionary = bar_sign.interact(hand)
	bar_sign.set_bar_state(1)
	var after_card := bar_sign.service_wire_card()
	bar_sign.set_bar_state(2)
	var closed_card := bar_sign.service_wire_card()
	_check("the complete Harukiya frontage owns one sourced inspection",
			bar_area != null and bar_area.get_child_count() == 1
			and bar_sign._inspection_tap.playing
			and open_card.get("card_id", "") == "shop_sign"
			and open_card.get("source_ids", []) == ["R028"]
			and str(open_card.get("condition", "")).contains("HARUKIYA"))
	_check("Harukiya copy follows its existing three-state hours owner",
			str(open_card.get("condition", "")).contains("HOURS OPEN")
			and str(after_card.get("condition", "")).contains(
					"HOURS AFTER HOURS")
			and str(after_card.get("condition", "")).contains(
					"LANTERN HANGING DARK")
			and str(closed_card.get("condition", "")).contains(
					"HOURS CLOSED")
			and str(closed_card.get("condition", "")).contains(
					"LANTERN TAKEN IN"))

	var entry_sign := BuildingEntrySign.new()
	add_child(entry_sign)
	var entry_card: Dictionary = entry_sign.interact(hand)
	var entry_area := entry_sign.get_node_or_null(
			"BuildingPlaqueInspection") as Area3D
	_check("the Orison identity plaque stays distinct from its door",
			entry_area != null and entry_area.get_child_count() == 1
			and entry_sign._inspection_tap.playing
			and entry_card.get("card_id", "") == "building_plaque"
			and entry_card.get("source_ids", []) == ["R028"]
			and str(entry_card.get("condition", "")).contains("THE ORISON")
			and str(entry_card.get("condition", "")).contains(
					"FOUR BRONZE SCREWS SEATED"))

	var marquee := EntranceMarqueeDress.new()
	add_child(marquee)
	var marquee_card: Dictionary = marquee.interact(hand)
	var marquee_area := marquee.get_node_or_null("MarqueeInspection") as Area3D
	_check("the complete entrance marquee owns one sourced look-point",
			marquee_area != null and marquee_area.get_child_count() == 1
			and marquee._inspection_tap.playing
			and marquee_card.get("card_id", "") == "marquee"
			and marquee_card.get("source_ids", []) == ["R028"]
			and str(marquee_card.get("condition", "")).contains(
					"PRISMATIC GLASS TRAY")
			and str(marquee_card.get("condition", "")).contains(
					"TIE RODS SEATED"))

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

	var cistern := BakedFurnitureInteraction.new()
	cistern.setup({"id": "TEST_wc", "asm": "toilet"})
	add_child(cistern)
	var flush_card: Dictionary = cistern.interact(hand)
	var flush_cycle := cistern._flush_tween
	var busy_flush_card: Dictionary = cistern.interact(hand)
	_check("baked water closet regains one physical cistern owner",
			cistern.interact_prompt().contains("refilling cistern handle")
			and cistern._refilling and cistern._water.playing
			and cistern._flush_tween == flush_cycle
			and cistern._flush_tween.is_running()
			and cistern._busy_tween.is_running()
			and flush_card.get("card_id", "") == "toilet"
			and busy_flush_card.get("card_id", "") == "toilet"
			and str(flush_card.get("title", "")) == "CISTERN WATER CLOSET"
			and str(flush_card.get("condition", "")).contains("REFILLING"))

	var radio := BakedFurnitureInteraction.new()
	radio.setup({"id": "TEST_radio", "asm": "radio"})
	add_child(radio)
	var radio_on_card: Dictionary = radio.interact(hand)
	var radio_off_card: Dictionary = radio.interact(hand)
	_check("baked valve radio owns a reversible physical switch",
			radio.interact_prompt().contains("Switch valve radio on")
			and not radio._powered and not radio._radio_bed.playing
			and radio._control_click.playing
			and radio._control_tween.is_running()
			and radio_on_card.get("card_id", "") == "radio"
			and str(radio_on_card.get("condition", "")).contains("POWER ON")
			and str(radio_on_card.get("condition", "")).contains("DISTANT SPEECH")
			and str(radio_off_card.get("condition", "")).contains("POWER OFF"))

	var wardrobe := BakedFurnitureInteraction.new()
	wardrobe.setup({"id": "2A_w0_wardrobe", "asm": "wardrobe", "W": 1.3,
			"case_wood": "oak_quartered"})
	add_child(wardrobe)
	var wardrobe_card: Dictionary = wardrobe.interact(hand)
	_check("split private wardrobe opens through its own hinged leaves",
			wardrobe.interact_prompt().contains("Close private wardrobe")
			and wardrobe._wardrobe_open
			and wardrobe._wardrobe_rattle.playing
			and wardrobe._wardrobe_tween.is_running()
			and wardrobe_card.get("card_id", "") == "wardrobe"
			and str(wardrobe_card.get("condition", "")).contains(
					"LEAF OPEN")
			and str(wardrobe_card.get("condition", "")).contains(
					"2A RESIDENT / PRIVATE"))

	var jukebox := BakedFurnitureInteraction.new()
	jukebox.setup({"id": "retail_bar_jukebox", "asm": "jukebox"})
	add_child(jukebox)
	var selector := jukebox.get_node("SelectorReach") as PropControlArea
	var coin_return := jukebox.get_node("CoinReturnReach") as PropControlArea
	var jukebox_play_card: Dictionary = selector.interact(hand)
	var first_stream := jukebox._jukebox_player.stream
	var jukebox_next_card: Dictionary = selector.interact(hand)
	var jukebox_return_card: Dictionary = coin_return.interact(hand)
	_check("baked jukebox selection plays from its own local pickup",
			selector.interact_prompt().contains("Press jukebox selection")
			and first_stream != null
			and jukebox._jukebox_player.stream != first_stream
			and jukebox._jukebox_selector_tween.is_running()
			and jukebox_play_card.get("card_id", "") == "jukebox"
			and str(jukebox_next_card.get("condition", "")).contains(
					"TURNING / LOCAL PICKUP"))
	_check("jukebox coin return stops the local record and answers physically",
			not jukebox._jukebox_player.playing
			and not jukebox._jukebox_sign_material.emission_enabled
			and jukebox._jukebox_coin_tween.is_running()
			and jukebox_return_card.get("card_id", "") == "jukebox"
			and str(jukebox_return_card.get("condition", "")).contains(
					"COIN RETURN RETURNED"))

	var layout_file := FileAccess.open(
			"res://data/building_layout.json", FileAccess.READ)
	var layout_data: Variant = JSON.parse_string(
			layout_file.get_as_text() if layout_file else "")
	var paper_specs: Array[Dictionary] = []
	var paper_ids := {}
	var loose_count := 0
	var board_count := 0
	if layout_data is Dictionary:
		for floor_entry in (layout_data as Dictionary).get("floors", []):
			var floor_spec: Dictionary = floor_entry
			for furniture_entry in floor_spec.get("furniture", []):
				var furniture_spec: Dictionary = furniture_entry
				var paper_kind := str(furniture_spec.get("asm", ""))
				if paper_kind != "papers" and paper_kind != "pinboard":
					continue
				paper_specs.append(furniture_spec.duplicate(true))
				paper_ids[str(furniture_spec.get("id", ""))] = true
				if paper_kind == "papers":
					loose_count += 1
				else:
					board_count += 1
	var copy_ids := {}
	for copy_id in BakedFurnitureInteraction.PAPER_OWNER_COPY:
		copy_ids[str(copy_id)] = true
	_check("paper attribution closes over every generated source record",
			loose_count == 14 and board_count == 8
			and paper_ids == copy_ids)
	var complete_papers := 0
	var exact_paper_collisions := 0
	for paper_spec in paper_specs:
		var paper_owner := BakedFurnitureInteraction.new()
		paper_owner.setup(paper_spec)
		add_child(paper_owner)
		var paper_card: Dictionary = paper_owner.service_wire_card()
		var collisions := paper_owner.get_children().filter(func(child):
			return child is CollisionShape3D)
		if collisions.size() == 1:
			exact_paper_collisions += 1
		if not str(paper_card.get("title", "")).is_empty() \
				and not str(paper_card.get("body", "")).is_empty() \
				and not str(paper_card.get("condition", "")).is_empty() \
				and paper_card.get("source_ids", []) == ["R052"] \
				and not str(paper_card).contains(paper_owner.record_id):
			complete_papers += 1
	_check("all 22 paper assemblies have one owner and clue-safe sourced copy",
			complete_papers == 22 and exact_paper_collisions == 22)

	var papers := BakedFurnitureInteraction.new()
	papers.setup({"id": "2A_papers", "asm": "papers", "n": 5})
	add_child(papers)
	var papers_card: Dictionary = papers.interact(hand)
	var pinboard := BakedFurnitureInteraction.new()
	pinboard.setup({"id": "2B_story_pattern_board", "asm": "pinboard",
			"W": 0.66, "H": 0.66, "cards": 0})
	add_child(pinboard)
	var pinboard_card: Dictionary = pinboard.interact(hand)
	_check("loose sheets lift and report count without printing their words",
			papers._paper_tap.playing and papers._paper_tween.is_running()
			and papers_card.get("card_id", "") == "papers"
			and str(papers_card.get("condition", "")).contains("5 SHEETS")
			and str(papers_card.get("condition", "")).contains("COPY WITHHELD")
			and not str(papers_card).contains("Mina")
			and not str(papers_card).contains("caption"))
	_check("empty pin board still answers through its one physical tack",
			pinboard._paper_tap.playing and pinboard._paper_tween.is_running()
			and pinboard_card.get("card_id", "") == "pinboard"
			and str(pinboard_card.get("condition", "")).contains("EMPTY")
			and str(pinboard_card.get("condition", "")).contains(
					"RESIDENT WORKING BOARD"))

	var witness := DomesticWitnessClock.new()
	witness.configure({"case_id": "TEST_SECRET_CASE", "unit": "9A",
			"resident": "TEST SECRET RESIDENT", "style": "schoolhouse",
			"accent": "8e2f38", "tell": "correction", "time": "04:17"})
	add_child(witness)
	var witness_card: Dictionary = witness.interact(hand)
	_check("case-driven clock answers through its own neutral inspection",
			witness.get_node_or_null("PrimaryInteraction") is Area3D
			and witness.interact_prompt().contains("Inspect familiar clock")
			and witness._inspect_tap.playing
			and witness._inspect_tween.is_running()
			and witness_card.get("card_id", "") == "winding_clock"
			and witness_card.get("source_ids", []) == ["R019"]
			and not str(witness_card).contains("TEST_SECRET_CASE")
			and not str(witness_card).contains("TEST SECRET RESIDENT"))

	var signal_witness := DomesticWitnessClock.new()
	signal_witness.configure({"case_id": "TEST_SIGNAL_CASE", "unit": "9B",
			"resident": "TEST SIGNAL RESIDENT", "style": "vantry_modular",
			"accent": "7656a8", "tell": "sample_skip", "time": "03:33"})
	add_child(signal_witness)
	var signal_card: Dictionary = signal_witness.interact(hand)
	_check("Vantry-synchronised witness keeps its signal provenance",
			str(signal_card.get("title", "")).contains("SIGNAL CLOCK")
			and signal_card.get("source_ids", []) == ["R034"]
			and str(signal_card.get("condition", "")).contains(
					"LINE SYNCHRONIZED")
			and not str(signal_card).contains("TEST_SIGNAL_CASE"))

	var master_clock := ClockProp.new()
	master_clock.unit = "LOBBY"
	master_clock.clock_variant = "vantry_master"
	add_child(master_clock)
	var master_card: Dictionary = master_clock.interact(hand)
	_check("sealed Vantry master resists through its actual setting cover",
			master_clock.interact_prompt().contains("Try sealed")
			and master_clock._service_touch.playing
			and master_clock._cover_tween.is_running()
			and master_card.get("card_id", "") == "winding_clock"
			and master_card.get("source_ids", []) == ["R051"]
			and str(master_card.get("condition", "")).contains(
					"SETTING COVER SEALED")
			and master_clock.displayed_offset_minutes() == 4.0)

	var directory := WayfindingSignagePass.new()
	add_child(directory)
	directory._build_materials()
	directory._build_front_directory()
	var directory_area := directory.find_child(
			"DirectoryDoorbellArea", true, false) as Area3D
	var directory_card: Dictionary = directory.interact_area(directory_area)
	var busy_directory_card: Dictionary = directory.interact_area(directory_area)
	_check("directory call button travels and answers on every press",
			directory_area != null and directory._bell_button != null
			and directory._bell.playing and directory._bell_tween.is_running()
			and directory_card.get("card_id", "") == "buzzer"
			and str(directory_card.get("condition", "")).contains("SOUNDED")
			and str(busy_directory_card.get("condition", "")).contains(
					"STILL RINGING"))

	var bulletin := LobbyBulletinBoard.new()
	add_child(bulletin)
	var bulletin_card: Dictionary = bulletin.interact(hand)
	_check("lobby notice owner answers with one pinned-sheet touch",
			bulletin.get_node_or_null("NoticeBoardInspection") is Area3D
			and bulletin._inspection_tap.playing
			and bulletin._inspection_tween.is_running()
			and bulletin_card.get("card_id", "") == "notice_board"
			and str(bulletin_card.get("condition", "")).contains(
					"SIX PINNED / TWO OVERFLOW"))

	var sales_board := LobbyOrisonAdBoard.new()
	add_child(sales_board)
	var sales_card: Dictionary = sales_board.interact(hand)
	_check("original sales broadside answers at its real frame",
			sales_board.get_node_or_null("SalesBoardInspection") is Area3D
			and sales_board._inspection_tap.playing
			and sales_board._inspection_tween.is_running()
			and sales_card.get("card_id", "") == "notice_board"
			and str(sales_card.get("condition", "")).contains(
					"ORIGINAL BROADSIDE"))

	var headquarters := MaintenanceHeadquarters.new()
	add_child(headquarters)
	var headquarters_card: Dictionary = headquarters.interact(hand)
	_check("case-wall authority answers without advancing a case",
			headquarters.get_node_or_null("CaseWallInspection") is Area3D
			and headquarters._inspection_tap.playing
			and headquarters._status_tween.is_running()
			and headquarters_card.get("card_id", "") == "service_board"
			and str(headquarters_card.get("condition", "")).contains(
					"REVIEW ONLY / NOT ADVANCED HERE")
			and headquarters.resolved_trophy_count() == 0)

	await get_tree().create_timer(0.03).timeout
	await get_tree().process_frame
	await get_tree().process_frame
	print("    motion latch=%.4f chain=%.4f lock=%.4f lid=%.4f airer=%.4f wardrobe=%.4f" % [
			case_door._knob.rotation.z, cart._night_chain.rotation.z,
			cart._night_lock.rotation.z, washer._lid.rotation.x,
			airer._rack.position.y, wardrobe._wardrobe_left_leaf.rotation.y])
	_check("case latch and cart chain visibly moved",
			absf(case_door._knob.rotation.z) > 0.001
			and (absf(cart._night_chain.rotation.z) > 0.001
					or absf(cart._night_lock.rotation.z) > 0.001)
			and absf(washer._lid.rotation.x) > 0.001
			and airer._rack.position.y < 1.98
			and absf(wardrobe._wardrobe_left_leaf.rotation.y) > 0.001)
	var closed_wardrobe_card: Dictionary = wardrobe.interact(hand)
	_check("private wardrobe closes through the same authoritative leaves",
			not wardrobe._wardrobe_open
			and wardrobe.interact_prompt().contains("Open private wardrobe")
			and str(closed_wardrobe_card.get("condition", "")).contains(
					"LEAF CLOSED"))

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
