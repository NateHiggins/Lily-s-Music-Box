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


static func render_line(fact: Dictionary, mode := "house") -> String:
	## One physical record, two surfaces. The mode may explain house words but
	## cannot add or delete an endpoint, operator hand, trunk, or line state.
	var endpoint := str(fact.get("endpoint", "THE HOUSE")).to_upper()
	var phase := str(fact.get("state", "IDLE")).to_upper()
	var trunk := str(fact.get("trunk", "")).replace("_", " ")
	if mode == "plain":
		match phase:
			"ASKING": return "%s telephone circuit is requesting an answer." % endpoint
			"ANSWERED": return "Operator A answered %s; destination is not connected." % endpoint
			"CARRYING": return "Operator B carries %s through %s." % [endpoint, trunk]
			"UNANSWERED": return "%s rang but was not taken." % endpoint
			_: return "%s telephone circuit is idle." % endpoint
	match phase:
		"ASKING": return "%s line asking. A answer." % endpoint
		"ANSWERED": return "A has %s. Take order." % endpoint
		"CARRYING": return "A answered. B carries %s on %s." % [endpoint, trunk]
		"UNANSWERED": return "%s unanswered. Line rests." % endpoint
		_: return "%s line rests." % endpoint


static func render_fortune_answer(fact: Dictionary, mode := "house") -> String:
	## A pure account of the visible mechanism. Question text and causality are
	## intentionally absent: the record can prove path, current and head axis.
	var answer := str(fact.get("answer", "")).to_upper()
	var powered := bool(fact.get("powered", false))
	var motion := "nodded" if answer == "YES" else (
			"shook" if answer == "NO" else "did not answer")
	if mode == "plain":
		if not powered:
			return "No current reached the selector magnets; the head did not answer."
		return "%s %s; %s; the head %s." % [
				term("coin_selected", mode), answer,
				term("hand_requested", mode), motion]
	if not powered:
		return "Line blind. Coin waits. Hand asks; head rests."
	return "%s %s. %s. Head %s." % [
			term("coin_selected", mode), answer,
			term("hand_requested", mode), motion]


static func _load() -> void:
	if not _terms.is_empty(): return
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	_terms = parsed.get("terms", {})
