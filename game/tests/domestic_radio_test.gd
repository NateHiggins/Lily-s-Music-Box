extends Node

const RadioScript := preload("res://scripts/props/domestic_radio_prop.gd")
const CATALOG := "res://data/domestic_radios.json"

var failures := 0
var checks := 0


func _check(ok: bool, label: String) -> void:
	checks += 1
	print("  [%s] %s" % ["radio ok" if ok else "RADIO FAIL", label])
	if not ok:
		failures += 1


func _ready() -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	var profiles: Array = catalog.get("profiles", [])
	var sources: Dictionary = catalog.get("sources", {})
	var units := {}
	var families := {}
	var anchors := {}
	_check(int(catalog.get("year", 0)) == 1928, "the census declares the production year")
	_check(profiles.size() == 18, "one authored receiver for each of 18 occupied apartments")
	_check(sources.size() >= 6, "six primary-object or period-trade source records ground the range")
	for profile in profiles:
		var unit := str(profile.get("unit", ""))
		var family := str(profile.get("family", ""))
		var anchor := str(profile.get("anchor", ""))
		_check(unit != "" and not units.has(unit), "%s is a unique household" % unit)
		units[unit] = true
		families[family] = true
		anchors[anchor] = true
		_check(anchor != "" and float(profile.get("surface_y", 0.0)) > 0.3,
				"%s is tied to a named furniture surface" % unit)
	_check(families.size() >= 7, "the census carries at least seven receiver silhouettes")
	_check(units.has("4B"), "the player's apartment participates in the same broadcast world")
	_check(units.has("5B") and units.has("3B") and units.has("6C"),
			"collector and repair households receive a principal set without erasing extras")

	for profile in profiles:
		var radio: Node = RadioScript.new()
		radio.configure(profile)
		add_child(radio)
		await get_tree().process_frame
		var before: Dictionary = radio.public_state()
		_check(not bool(before.powered) and float(before.reach) <= 5.5,
				"%s boots silent with apartment-bounded reach" % radio.unit)
		_check(str(before.family) == str(profile.family)
				and str(radio.get_meta("radio_condition")) == str(profile.condition),
				"%s keeps its authored mechanism and wear" % radio.unit)
		radio.queue_free()
		await get_tree().process_frame

	var source := FileAccess.get_file_as_string("res://scripts/props/domestic_radio_prop.gd")
	_check(not source.contains("RealityState") and not source.contains("WorkOrders")
			and not source.contains("RealityCases"),
			"a receiver owns no save, job, or case lifecycle")
	_check(not source.contains("issue_job") and not source.contains("publish_case"),
			"listening cannot originate a report or investigation")
	print("[DOMESTIC RADIO] RESULT: %s (%d/%d)" % [
			"PASS" if failures == 0 else "FAIL", checks - failures, checks])
	get_tree().quit(failures)
