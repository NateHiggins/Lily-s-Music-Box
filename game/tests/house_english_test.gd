extends Node

const HouseEnglishScript := preload("res://scripts/language/house_english.gd")
var failures := 0
var checks := 0


func _check(ok: bool, label: String) -> void:
	checks += 1
	print("  [%s] %s" % ["house english ok" if ok else "HOUSE ENGLISH FAIL", label])
	if not ok: failures += 1


func _ready() -> void:
	var fact := {"unit":"2B", "apparatus":"radiator", "evidence":"reported",
			"state":"contradictory"}
	var house: String = HouseEnglishScript.render_report(fact, "house")
	var plain: String = HouseEnglishScript.render_report(fact, "plain")
	_check(house == "2B tenant-says its heat-iron reads cross. Take the work-paper. Hand-prove before square.",
			"one semantic report renders the controlled opening-shift cant")
	_check(plain == "2B: reported by the occupant; radiator is wrong, obstructed, or contradictory.",
			"the identical fact renders an accessible plain-language surface")
	_check(HouseEnglishScript.term("energized") == "hot"
			and HouseEnglishScript.term("unindicated") == "blind",
			"core state words are stable rather than improvised synonyms")
	var before := JSON.stringify(RealityState.data)
	HouseEnglishScript.render_report(fact, "house")
	_check(JSON.stringify(RealityState.data) == before,
			"language presentation owns no persistent fact")
	var source := FileAccess.get_file_as_string("res://scripts/language/house_english.gd")
	_check(not source.contains("WorkOrders") and not source.contains("RealityCases")
			and not source.contains("commit("),
			"the renderer cannot issue, close, or record story state")
	print("[HOUSE ENGLISH] RESULT: %s (%d/%d)" % [
			"PASS" if failures == 0 else "FAIL", checks - failures, checks])
	get_tree().quit(failures)
