extends Node

const TEST_PATH := "user://tests/reality_future_save_test.json"
var passed := 0
var failed := 0
var old_path := ""
var old_persistence := true


func _ready() -> void:
	old_path = RealityState.save_path
	old_persistence = RealityState.persistence_enabled
	RealityState.save_path = TEST_PATH
	RealityState.persistence_enabled = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://tests"))
	var future := '{"version":99,"intro_complete":true,"future_fact":"keep me"}'
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string(future)
	file = null

	RealityState.load_game()
	_check(RealityState.save_write_blocked, "future save blocks writes")
	_check(RealityState.incompatible_save_version == 99, "future version is named")
	var notice := RealityState.player_notice()
	_check(str(notice.get("code", "")) == "future_save_read_only",
			"future save publishes a player notice")
	_check(str(notice.get("title", "")) == "SAVE CREATED BY A NEWER VERSION"
			and str(notice.get("message", "")).contains("Progress will not be saved")
			and str(notice.get("message", "")).contains("start a new campaign"),
			"notice names consequence and both remedies plainly")
	await get_tree().process_frame
	_check(SaveStatusNotice.panel.visible
			and SaveStatusNotice.title_label.text == str(notice.title)
			and SaveStatusNotice.message_label.text == str(notice.message),
			"autoload presents the persistence owner's exact notice")
	SaveStatusNotice._dismiss()
	_check(not SaveStatusNotice.panel.visible and RealityState.save_write_blocked,
			"dismissal hides copy without releasing the safety latch")
	_check(not bool(RealityState.data.intro_complete), "future data is not merged")
	_check(not RealityState.data.has("future_fact"), "unknown future facts stay out of runtime")
	var before := FileAccess.get_file_as_string(TEST_PATH)
	RealityState.data.intro_complete = true
	RealityState.commit()
	_check(FileAccess.get_file_as_string(TEST_PATH) == before,
			"commit preserves future save byte for byte")

	RealityState.start_new_campaign()
	await get_tree().process_frame
	var replacement: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEST_PATH))
	_check(not RealityState.save_write_blocked, "explicit new campaign releases latch")
	_check(RealityState.player_notice().is_empty()
			and not SaveStatusNotice.panel.visible,
			"new campaign clears the obsolete notice")
	_check(replacement is Dictionary and int(replacement.get("version", 0)) ==
			RealityState.SAVE_VERSION, "explicit new campaign writes current version")

	_check_inventory_roster()
	_check_price_reception()

	RealityState.save_path = "user://tests"
	_check(not RealityState.save_game(), "unwritable save target refuses the write")
	var write_notice := RealityState.player_notice()
	_check(str(write_notice.get("code", "")) == "save_write_failed"
			and str(write_notice.get("message", "")).contains(
					"Progress since the last successful save may be lost"),
			"write failure publishes its player consequence")

	RealityState.save_path = old_path
	RealityState.persistence_enabled = old_persistence
	RealityState.reset_campaign_for_tests()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	print("[SAVE COMPAT] PASS %d/%d" % [passed, passed + failed] if failed == 0
			else "[SAVE COMPAT] FAIL %d/%d" % [failed, passed + failed])
	get_tree().quit(0 if failed == 0 else 1)


func _check_price_reception() -> void:
	var document := RealityState.data.duplicate(true)
	document.erase("price_reception")
	_check(RealityState._validate_document(document).ok, "saves from before the Price reception remain readable")
	document.price_reception = {"day": "1929-06-16", "visit": ""}
	_check(RealityState._validate_document(document).ok, "ordinary Sunday reception is valid")
	for bad: Variant in [false, {}, {"day": "1929-02-30", "visit": ""}, {"day": "1929-06-16", "visit": 7}]:
		document.price_reception = bad
		_check(not RealityState._validate_document(document).ok, "invalid Price reception is protected: %s" % str(bad))


func _check_inventory_roster() -> void:
	var fields := PersonInventory.book()
	_check(fields.get("version") == PersonInventory.ROSTER_VERSION, "new campaigns use the current inventory roster")
	var unit: String = DoorKeyring.residents()["lily"]
	var key_id := "key:" + unit
	var current := RealityState.data.duplicate(true)
	var legacy := current.duplicate(true)
	legacy.inventories["version"] = 1
	legacy.inventories.holders.erase("lily")
	legacy.inventories.erase(PersonInventory.OBJECTS_VERSION)
	legacy.inventories.holders.player["grocery:bread"] = {"kind": "grocery", "qty": 2.0}
	var legacy_bass := legacy.duplicate(true)
	legacy_bass.inventories[PersonInventory.OBJECTS_VERSION] = 1
	var bass: Dictionary = current.inventories.holders.lily[PersonInventory.BASS].duplicate()
	bass["location"] = "home"
	legacy_bass.inventories.holders["lily"] = {PersonInventory.BASS: bass}

	var prefix := TEST_PATH.get_basename() + "_roster_" + str(Time.get_ticks_usec())
	for fixture: Dictionary in [legacy, legacy_bass]:
		var path := prefix + ("_bass.json" if fixture.inventories.has(PersonInventory.OBJECTS_VERSION) else "_early.json")
		var bytes := _write_fixture(path, fixture)
		RealityState.save_path = path
		RealityState.load_game()
		var inventory: Dictionary = RealityState.data.get("inventories", {})
		_check(RealityState.can_continue() and inventory.get("version") == PersonInventory.ROSTER_VERSION,
				"legacy roster is upgraded before the campaign is published")
		var holder: Dictionary = inventory.get("holders", {}).get("lily", {})
		_check(holder.get(key_id) == {"kind": "key", "unit": unit, "cut": "original"},
				"only Lily gains her original key")
		var existing: Dictionary = inventory.get("holders", {}).duplicate()
		var expected: Dictionary = fixture.inventories.holders.duplicate()
		existing.erase("lily")
		expected.erase("lily")
		_check(existing == expected, "all other holdings survive")
		if fixture.inventories.has(PersonInventory.OBJECTS_VERSION):
			_check(holder.get(PersonInventory.BASS) == bass, "existing bass record and location survive")
		_check(FileAccess.get_file_as_string(path) == bytes, "loading leaves legacy bytes intact")
		_check(RealityState.save_game(), "the normal save transaction persists the upgraded roster")
		_check(FileAccess.get_file_as_string(path + ".bak") == bytes, "the transaction keeps the original bytes as backup")
		RealityState.load_game()
		_check(RealityState.can_continue(), "the upgraded roster reloads from disk")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".bak"))

	# Rewind can restore a detached older inventory after the top-level load.
	RealityState.data["inventories"] = legacy_bass.inventories.duplicate(true)
	_check(PersonInventory.has_key("lily", unit) and PersonInventory.object_location() == "home"
			and RealityState.data.inventories.version == PersonInventory.ROSTER_VERSION,
			"live inventory owner also upgrades a restored older snapshot")

	var invalid := current.duplicate(true)
	invalid.inventories.holders.lily.erase(key_id)
	var corrupt_legacy := legacy.duplicate(true)
	# Malform a required historical resident separately from the absent new key.
	var residents := DoorKeyring.residents()
	for resident: String in residents:
		if resident != "lily":
			corrupt_legacy.inventories.holders.erase(resident)
			break
	for fixture: Dictionary in [invalid, corrupt_legacy]:
		var path := prefix + "_invalid_" + str(fixture.inventories.version) + ".json"
		var bytes := _write_fixture(path, fixture)
		RealityState.save_path = path
		RealityState.load_game()
		_check(RealityState.save_write_blocked and not RealityState.save_game(),
				"unexpected missing original keys remain protected")
		_check(FileAccess.get_file_as_string(path) == bytes, "rejected inventories remain byte-identical")
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	RealityState.save_path = TEST_PATH
	RealityState.load_game()


func _write_fixture(path: String, document: Dictionary) -> String:
	var bytes := JSON.stringify(document, "\t", true, true)
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(bytes)
	file.close()
	return bytes


func _check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("  PASS ", label)
	else:
		failed += 1
		print("  FAIL ", label)
