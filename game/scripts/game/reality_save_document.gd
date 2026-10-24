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
	if candidate.has("caretaker_economy") and not preload("res://scripts/game/caretaker_economy.gd").valid(candidate.caretaker_economy):
		return _invalid_shape("caretaker_economy")
	if candidate.has("door_keys") and not preload("res://scripts/game/door_keyring.gd").valid(candidate.door_keys):
		return _invalid_shape("door_keys")
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

