class_name HouseEnglish
extends RefCounted
## Deterministic presentation of semantic facts. It owns no story state.

const PATH := "res://data/house_english_lexicon.json"
static var _terms: Dictionary = {}


static func term(key: String, mode := "house") -> String:
	_load()
	var record: Dictionary = _terms.get(key, {})
	return str(record.get(mode, key.replace("_", " ")))


static func render_report(fact: Dictionary, mode := "house") -> String:
	var unit := str(fact.get("unit", "THE HOUSE")).to_upper()
	var apparatus := term(str(fact.get("apparatus", "apparatus")), mode)
	var evidence := term(str(fact.get("evidence", "reported")), mode)
	var state := term(str(fact.get("state", "contradictory")), mode)
	if mode == "plain":
		return "%s: %s; %s is %s." % [unit, evidence, apparatus, state]
	return "%s %s its %s reads %s. Take the %s. Hand-prove before square." % [
			unit, evidence, apparatus, state, term("work_order", mode)]


static func _load() -> void:
	if not _terms.is_empty(): return
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	_terms = parsed.get("terms", {})
