extends Node
## A save written before a fitting left the world must not refuse the whole
## household (and with it the world). On 2026-11-08 the owner's save still held
## F01_INNER_DOOR_Leaf, unhung on 2026-10-26, and the V2 world never finished
## starting. Well-formed records for absent fittings are set aside; malformed
## records and kind mismatches still fail validation.

const HouseholdScript := preload("res://scripts/building/orison_v2_household_state.gd")


func _ready() -> void:
	var household = HouseholdScript.new()
	household._kinds = {"F01_LOBBY_LT": "light", "F04_B_HALL_DOOR_Leaf": "mechanism"}
	var failures: Array[String] = []
	var checks := 0

	var saved := {"schema_version": 1, "records": {
		"F01_LOBBY_LT": {"kind": "light", "value": true},
		"F01_INNER_DOOR_Leaf": {"kind": "mechanism", "value": {"angle": 0.4}},
	}}
	var kept: Dictionary = household._without_retired_fittings(saved)
	checks += 1
	if kept.records.has("F01_INNER_DOOR_Leaf") or not kept.records.has("F01_LOBBY_LT"):
		failures.append("a retired fitting's record is set aside and owned records stay")
	checks += 1
	if household.retired_identities != ["F01_INNER_DOOR_Leaf"]:
		failures.append("the set-aside identity is reported")
	checks += 1
	if not saved.records.has("F01_INNER_DOOR_Leaf"):
		failures.append("the save document itself is not edited in place")
	checks += 1
	if not household.validate(kept, household._kinds):
		failures.append("the remaining household validates: %s" % [household.errors])

	var untouched := {"schema_version": 1, "records": {"F01_LOBBY_LT": {"kind": "light", "value": false}}}
	checks += 1
	if not is_same(household._without_retired_fittings(untouched), untouched):
		failures.append("a save with nothing retired passes through unchanged")

	var malformed := {"schema_version": 1, "records": {
		"F01_LOBBY_LT": {"kind": "light", "value": true},
		"GONE_A": {"kind": "light"},
		"GONE_B": {"kind": "teleporter", "value": true},
	}}
	checks += 1
	if household.validate(household._without_retired_fittings(malformed), household._kinds):
		failures.append("malformed records and unknown kinds are still refused")

	var mismatch := {"schema_version": 1, "records": {"F01_LOBBY_LT": {"kind": "mechanism", "value": true}}}
	checks += 1
	if household.validate(household._without_retired_fittings(mismatch), household._kinds):
		failures.append("a kind mismatch on an owned fitting is still refused")

	household.free()
	for failure in failures: print("FAIL: " + failure)
	print("[V2 HOUSEHOLD RETIRED FITTING] RESULT: %s %d/%d" % [
			"PASS" if failures.is_empty() else "FAIL", checks - failures.size(), checks])
	get_tree().quit(0 if failures.is_empty() else 1)
