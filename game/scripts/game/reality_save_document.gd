extends RefCounted
## Pure save-shape and calendar inspection. Domain owners retain their validators.
## Worker use primes DoorKeyring sources on the main thread before dispatch.

static func validate(candidate: Dictionary, supported_version: int) -> Dictionary:
	var version: Variant = candidate.get("version", 0)
	if not _whole_number(version) or float(version) < 0.0:
		return {"ok": false, "code": "save_invalid_read_only", "detail": "Invalid save version."}
	if float(version) > supported_version:
		return {"ok": false, "code": "future_save_read_only", "version": int(version)}
	if candidate.has("lamp_optics") and not preload("res://scripts/lamp/lamp_optical_snapshot.gd").valid(candidate.lamp_optics):
		return _invalid_shape("lamp_optics")
	if candidate.has("companion") and not preload("res://scripts/device/companion_campaign_state.gd").valid(candidate.companion):
		return _invalid_shape("companion")
	if candidate.has("prologue") and not preload("res://scripts/game/prologue_state.gd").valid(candidate.prologue):
		return _invalid_shape("prologue")
	if candidate.has("caretaker_economy") and not preload("res://scripts/game/caretaker_economy.gd").valid(candidate.caretaker_economy):
		return _invalid_shape("caretaker_economy")
	if candidate.has("door_keys") and not preload("res://scripts/game/door_keyring.gd").valid(candidate.door_keys):
		return _invalid_shape("door_keys")
	if candidate.has("household_larders") and not preload("res://scripts/game/kitchen_larder.gd").valid(candidate.household_larders):
		return _invalid_shape("household_larders")
	if candidate.has("keys_book") and not preload("res://scripts/game/keys_sales.gd").valid(candidate.keys_book):
		return _invalid_shape("keys_book")
	if candidate.has("photo_bench") and not preload("res://scripts/game/photo_sales.gd").valid(candidate.photo_bench):
		return _invalid_shape("photo_bench")
	if candidate.has("pawn_book") and not preload("res://scripts/game/pawn_sales.gd").valid(candidate.pawn_book):
		return _invalid_shape("pawn_book")
	if candidate.has("luncheonette_served") and not preload("res://scripts/props/luncheonette_counter.gd").valid(candidate.luncheonette_served):
		return _invalid_shape("luncheonette_served")
	if candidate.has("mail_orders") and not preload("res://scripts/game/mail_orders.gd").valid(candidate.mail_orders):
		return _invalid_shape("mail_orders")
	if candidate.has("resident_gifts") and not preload("res://scripts/game/resident_gifts.gd").valid(candidate.resident_gifts):
		return _invalid_shape("resident_gifts")
	if candidate.has("item_use") and not preload("res://scripts/game/item_use.gd").valid(candidate.item_use):
		return _invalid_shape("item_use")
	if candidate.has("resident_errands") and not preload("res://scripts/game/resident_errands.gd").valid(candidate.resident_errands):
		return _invalid_shape("resident_errands")
	if candidate.has("carried_case") and not preload("res://scripts/game/carried_case.gd").valid(candidate.carried_case):
		return _invalid_shape("carried_case")
	if candidate.has("shop_stock") and not preload("res://scripts/game/shop_stock.gd").valid(candidate.shop_stock):
		return _invalid_shape("shop_stock")
	if candidate.has("inventories") and not preload("res://scripts/game/person_inventory.gd").valid(candidate.inventories):
		return _invalid_shape("inventories")
	if candidate.has("inventories") and candidate.has("door_keys") and int(candidate.door_keys.get("version", 0)) == 2 \
			and not preload("res://scripts/game/person_inventory.gd").consistent(candidate.inventories, candidate.door_keys):
		return _invalid_shape("inventories spare")
	for key in ["cases", "building_personality", "work_orders", "maintenance_jobs",
			"maintenance_items", "open_shift_situations", "shop_buckets", "exterior_semantics",
			"organism_incidents", "core_loop", "first_shift", "dream", "sleep_pressure", "waking_residues",
			"night_register", "npc_observations", "porter_actor",
			"resident_trust", "conversation_visits"]:
		if candidate.has(key) and candidate[key] is not Dictionary:
			return _invalid_shape(key)
	for key in ["portal_rules", "discovered_documents", "music_library", "heard_music_anecdotes",
			"knowledge_flags", "newspapers_collected"]:
		if candidate.has(key) and candidate[key] is not Array:
			return _invalid_shape(key)
	for key in ["current_case_id", "dream_seed", "last_waking_residue_id"]:
		if candidate.has(key) and candidate[key] is not String:
			return _invalid_shape(key)
	if candidate.has("intro_complete") and candidate.intro_complete is not bool:
		return _invalid_shape("intro_complete")
	for key in ["building_stability", "reality_coherence"]:
		if candidate.has(key) and not _finite_number(candidate[key]):
			return _invalid_shape(key)
	if candidate.has("dreams_had") and (not _whole_number(candidate.dreams_had) or float(candidate.dreams_had) < 0.0):
		return _invalid_shape("dreams_had")
	# These are maps of durable records, not arbitrary nested dictionaries.
	# Domain owners still validate IDs, vocabulary, quantities and chronology.
	for key in ["cases", "work_orders", "maintenance_jobs", "maintenance_items",
			"open_shift_situations", "shop_buckets", "exterior_semantics",
			"organism_incidents", "waking_residues"]:
		for record in candidate.get(key, {}).values():
			if record is not Dictionary:
				return _invalid_shape(key + " entry")
	for beliefs in candidate.get("npc_observations", {}).values():
		if not _array_of_records(beliefs):
			return _invalid_shape("npc_observations entry")
	var register: Dictionary = candidate.get("night_register", {})
	if register.has("lines") and not _array_of_records(register.lines):
		return _invalid_shape("night_register.lines")
	var checked := CampaignClock.validate_snapshot(candidate.get("campaign_clock", {}))
	return {"ok":true} if checked.ok else {"ok":false,"code":"campaign_clock_read_only","detail":str(checked.error)}


static func _finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))


static func _array_of_records(value: Variant) -> bool:
	if value is not Array:
		return false
	for record in value:
		if record is not Dictionary:
			return false
	return true


static func _whole_number(value: Variant) -> bool:
	return _finite_number(value) and float(value) == floor(float(value))


static func _invalid_shape(key: String) -> Dictionary:
	return {"ok": false, "code": "save_invalid_read_only", "detail": "Invalid saved field: " + key + "."}
