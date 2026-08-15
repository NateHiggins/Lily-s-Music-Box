extends Node
## Production-scene proof for the no-screen service set and the universal E
## interaction contract introduced with it.

var _fails := 0
var root: Node3D


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
	if not ok:
		_fails += 1


func _action_has_physical_key(action: StringName, keycode: Key) -> bool:
	if not InputMap.has_action(action):
		return false
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and event.physical_keycode == keycode:
			return true
	return false


func _ready() -> void:
	OS.set_environment("DAYNIGHT", "0")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	await get_tree().create_timer(1.8).timeout

	var player: PlayerController = root.player
	var carrier: ServiceSetCarrier = root.service_set_carrier
	var device: ServiceSetProp = carrier.device if carrier else null
	var telegram: TelegramHud = player.telegram_hud
	_check("production owns one Vantry service-set carrier",
			carrier != null and player.carried_device == carrier)
	_check("production instantiates no PhoneCarrier or Phone3D",
			_count_old_phone(root) == 0)
	_check("the physical set owns no screen SubViewport",
			device != null and _count_subviewports(device) == 0)
	_check("the model contains a real control-scale assembly",
			device != null and _count_geometry(device) >= 70)
	_check("one shared non-modal telegram presenter belongs to the player",
			telegram != null and telegram.layer == 9 and not player.call_locked)
	_check("the core HUD uses the licensed service-wire type family",
			player._prompt.get_theme_font("font") == TelegramStyle.BOLD_FONT
			and root.objective_tracker._title.get_theme_font("font") \
			== TelegramStyle.BOLD_FONT)
	_check("the back owns NET and LAMP modified indicators",
			device != null and device._net_material != null
			and device._lamp_indicator_material != null)
	player.set_sleep_onset_progress(0.75)
	_check("sleep presentation reaches the real carried-lamp lag owner",
			is_equal_approx(carrier._sleep_onset, 0.75))
	player.set_sleep_onset_progress(0.0)

	_check("radio and work lamp boot in their physical ON states",
			device.radio_powered and player.lamp_is_enabled()
			and device._net_material.emission_enabled
			and device._lamp_indicator_material.emission_enabled)
	_check("L and R are the physical lamp and radio controls",
			_action_has_physical_key("lamp_toggle", KEY_L)
			and _action_has_physical_key("radio_toggle", KEY_R))
	player.set_lamp_enabled(false)
	await get_tree().process_frame
	_check("one public call extinguishes beam, plate and rear LAMP jewel",
			not player.flashlight.visible and not player._light_mask.visible
			and not device.lamp_enabled
			and not device._lamp_indicator_material.emission_enabled)
	player.set_lamp_enabled(true)
	Input.action_press("lamp_toggle")
	# This harness runs after the production player in tree order; explicitly
	# sample once so a frame waiter cannot release before its sibling polls.
	player._process(0.0)
	Input.action_release("lamp_toggle")
	_check("the mapped physical lamp action reaches the same owner",
			not player.lamp_is_enabled() and not device.lamp_enabled)
	player.set_lamp_enabled(true)
	carrier.set_radio_powered(false)
	await get_tree().create_timer(0.35).timeout
	_check("radio OFF collapses the aerial and extinguishes NET",
			not device.radio_powered and device._aerial.scale.y < 0.2
			and not device._net_material.emission_enabled)
	carrier.set_radio_powered(true)
	var print_before := device.printed_count
	_check("a powered set advances a physical field slip",
			carrier.print_telegram_card("Proof object")
			and device.printed_count == print_before + 1
			and device._receipt_root.visible)
	carrier.set_radio_powered(false)
	_check("radio OFF suppresses paper and never invents a screen fallback",
			not carrier.print_telegram_card("Must not print")
			and device.printed_count == print_before + 1)
	carrier.set_radio_powered(true)
	await get_tree().create_timer(0.35).timeout
	_check("radio ON extends the aerial and restores NET",
			device.radio_powered and device._aerial.scale.y > 0.95
			and device._net_material.emission_enabled)
	Input.action_press("radio_toggle")
	player._process(0.0)
	Input.action_release("radio_toggle")
	_check("the mapped radio action pushes the aerial home",
			not device.radio_powered)
	carrier.set_radio_powered(true)

	var orders: WorkOrders = root.work_orders
	_check("ORDER boots from the authoritative aggregate",
			device.order_open == orders.has_open_work()
			and device._order_material.emission_enabled == orders.has_open_work())
	_check("filing through WorkOrders keeps ORDER lit",
			orders.issue("service_set_test", "Service-set test", "Inspect")
			and device.order_open and device._order_material.emission_enabled)
	_check("closing one order recomputes rather than blindly clearing ORDER",
			orders.close("service_set_test")
			and device.order_open == orders.has_open_work()
			and device._order_material.emission_enabled == orders.has_open_work())

	var fridges := _fridges(root)
	_check("all eighteen cold boxes exist", fridges.size() == 18)
	_check("every cold box has a ray-reachable E area",
			fridges.all(func(fridge): return _has_area_shape(fridge)))
	var interactable_count := 0
	var missing_area: Array[String] = []
	interactable_count = _audit_functional_interactions(root, interactable_count,
			missing_area)
	_check("every functional prop that publishes E has a collision owner",
			interactable_count > 40 and missing_area.is_empty())
	if not missing_area.is_empty():
		print("    missing interaction areas: %s" % str(missing_area))

	var fridge := root.find_child("F04_B_FRIDGE_01", true, false) as FridgeProp
	if fridge:
		player.global_position = fridge.to_global(Vector3(0, 0, -1.20))
		player.velocity = Vector3.ZERO
		player.camera.look_at(fridge.to_global(Vector3(0, 0.72, -0.22)))
		await get_tree().physics_frame
		await get_tree().physics_frame
		player._try_interact()
		await get_tree().create_timer(0.65).timeout
		_check("a real production E ray opens the 4B icebox", fridge._open)
		_check("the same E produces one state-reading field copy",
				telegram.serial > 0
				and str(telegram.last_card.get("title", "")) == "FRIDGE"
				and device.printed_count > print_before + 1
				and not player.call_locked)
		player._try_interact()
		await get_tree().create_timer(0.65).timeout
		_check("the same production E ray closes it again", not fridge._open)
		_check("rapid replacement reuses the one presenter",
				telegram.serial >= 2 and telegram._paper.visible)
	else:
		_check("the authored 4B refrigerator is present", false)

	var bench := root.find_child("LobbyBenchZone", true, false) as LobbyBenchZone
	if bench:
		var before := player.global_position
		bench.interact(player)
		_check("sitting records a physical E owner",
				bench.seated and player.call_locked
				and player.seated_interaction == bench)
		player.use_primary_interaction()
		_check("E stands back up without needing to reacquire the seat ray",
				not bench.seated and not player.call_locked
				and player.seated_interaction == null
				and player.global_position.distance_to(before) < 0.02)
	else:
		_check("the lobby bench interaction exists", false)

	var desk: DeskZone = _first_desk(root)
	if desk:
		desk.interact(player)
		_check("the support chair uses the same seated E contract",
				desk.seated_player == player and player.call_locked)
		player.use_primary_interaction()
		_check("E leaves the support chair and closes its modal panel",
				desk.seated_player == null and not player.call_locked
				and player.seated_interaction == null)
	else:
		_check("the authored support desk exists", false)

	var inspection := InspectableZone.new()
	inspection.setup("Old programme card", ["THE INK HAS OUTLIVED THE HAND STOP"])
	var inspection_card := inspection.interact(player)
	_check("existing look-at copy routes through the telegram card contract",
			str(inspection_card.get("title", "")) == "Old programme card"
			and str(inspection_card.get("body", "")).ends_with("STOP")
			and inspection.get_child_count() == 1)
	inspection.free()

	print("[SERVICE SET] interactions=%d fridges=%d result=%s" % [
			interactable_count, fridges.size(), "PASS" if _fails == 0 else "FAIL"])
	get_tree().quit(_fails)


func _count_old_phone(node: Node) -> int:
	var count := 1 if node is PhoneCarrier or node is Phone3D else 0
	for child in node.get_children():
		count += _count_old_phone(child)
	return count


func _count_subviewports(node: Node) -> int:
	var count := 1 if node is SubViewport else 0
	for child in node.get_children():
		count += _count_subviewports(child)
	return count


func _count_geometry(node: Node) -> int:
	var count := 1 if node is GeometryInstance3D else 0
	for child in node.get_children():
		count += _count_geometry(child)
	return count


func _has_area_shape(node: Node) -> bool:
	if node is Area3D:
		for child in node.get_children():
			if child is CollisionShape3D and child.shape != null \
					and not child.disabled:
				return true
	for child in node.get_children():
		if _has_area_shape(child):
			return true
	return false


func _fridges(node: Node) -> Array[FridgeProp]:
	var out: Array[FridgeProp] = []
	if node is FridgeProp:
		out.append(node)
	for child in node.get_children():
		out.append_array(_fridges(child))
	return out


func _audit_functional_interactions(node: Node, count: int,
		missing: Array[String]) -> int:
	if node is FunctionalProp and node.has_method("interact") \
			and node.has_method("interact_prompt"):
		count += 1
		if not _has_area_shape(node):
			missing.append(str(node.name))
	for child in node.get_children():
		count = _audit_functional_interactions(child, count, missing)
	return count


func _first_desk(node: Node) -> DeskZone:
	if node is DeskZone:
		return node
	for child in node.get_children():
		var found := _first_desk(child)
		if found:
			return found
	return null
