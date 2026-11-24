extends RefCounted
## Reads how a resident feels about the line they are saying, from what the
## game already holds (Lily, ruling npc_face_mood_source_20261124):
##
##   the subject at hand   the words and punctuation of the line itself
##   trust                 how far this resident trusts the player now
##   temperament           the resident's traits in resident_motives.json
##   the last exchange     whether the player's last choice won or lost
##                         trust, made an inference or offered evidence
##
## Rules and weights only, from mood_reading.json; nothing is generated and
## the same inputs always give the same reading. The result is a feeling the
## face shows (exaggerated, as she asked) and, when it is strong, a stage
## gesture the body may play. Who speaks and what is said stay with the
## dialogue; this only decides how it looks.

const DATA := "res://data/characters/mood_reading.json"
const MOTIVES := "res://data/resident_motives.json"

var _data: Dictionary = {}
var _traits: Dictionary = {}
var _patterns: Dictionary = {}


func load_data() -> bool:
	var document: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if document is not Dictionary or int(document.get("schema_version", 0)) != 1:
		return false
	_data = document
	var motives: Variant = JSON.parse_string(FileAccess.get_file_as_string(MOTIVES))
	if motives is Dictionary and motives.get("residents") is Dictionary:
		for slug: String in motives.residents:
			_traits[slug] = (motives.residents[slug] as Dictionary).get("traits", {})
	# Whole words and phrases, so "ha" is not found inside "that".
	for feeling: String in _data.subject_cues:
		var compiled: Array = []
		for cue: String in _data.subject_cues[feeling]:
			var text := cue.to_lower()
			var first := text.unicode_at(0)
			var last := text.unicode_at(text.length() - 1)
			if _is_word(first) and _is_word(last):
				var expression := RegEx.new()
				expression.compile("\\b" + _escape(text) + "\\b")
				compiled.append(expression)
			else:
				compiled.append(text)
		_patterns[feeling] = compiled
	return true


static func _is_word(code: int) -> bool:
	return (code >= 97 and code <= 122) or (code >= 48 and code <= 57)


static func _escape(text: String) -> String:
	var out := ""
	for character in text:
		out += ("\\" + character) if ".?*+()[]{}|^$\\".contains(character) else character
	return out


## Seconds a resident waits between stage gestures.
func emote_gap() -> float:
	return float((_data.get("emote", {}) as Dictionary).get("least_seconds_between", 5.0))


func traits_of(resident_id: String) -> Dictionary:
	return _traits.get(resident_id, {})


## exchange: {"trust_delta": int, "inferred": bool, "evidence": bool} for the
## player's choice that led to this line; empty for an opening line.
func read(resident_id: String, line: String, trust: int, exchange: Dictionary = {}) -> Dictionary:
	if _data.is_empty():
		return {"expression": "neutral", "intensity": 0.0, "emote": "", "score": 0.0}
	var scores: Dictionary = {}
	var text := " " + line.to_lower() + " "
	var weight := float(_data.cue_weight)
	for feeling: String in _patterns:
		for cue: Variant in _patterns[feeling]:
			var hits := 0
			if cue is RegEx:
				hits = (cue as RegEx).search_all(text).size()
			else:
				hits = text.count(str(cue))
			if hits > 0:
				_bump(scores, feeling, weight * minf(float(hits), 2.0))
	for mark: String in _data.punctuation:
		if text.contains(mark):
			_apply(scores, _data.punctuation[mark], 1.0)
	var trusting: Dictionary = _data.trust
	if trust >= int(trusting.warm_at):
		_apply(scores, trusting.warm, 1.0)
	elif trust < int(trusting.cold_below):
		_apply(scores, trusting.cold, 1.0)
	# Temperament leans the reading the way this person leans.
	var traits: Dictionary = traits_of(resident_id)
	for leaning: String in _data.traits:
		if traits.has(leaning):
			# A trait at 0.5 leans neither way; at 1 it leans fully, at 0 the other way.
			_apply(scores, _data.traits[leaning], (float(traits[leaning]) - 0.5) * 2.0)
	var choice: Dictionary = _data.choice
	var delta := int(exchange.get("trust_delta", 0))
	if delta > 0:
		_apply(scores, choice.trust_gained, 1.0)
	elif delta < 0:
		_apply(scores, choice.trust_lost, 1.0)
	if bool(exchange.get("inferred", false)):
		_apply(scores, choice.inferred, 1.0)
	if bool(exchange.get("evidence", false)):
		_apply(scores, choice.evidence, 1.0)
	# The strongest feeling wins; ties go to the earlier name, so it is stable.
	var best := ""
	var top := 0.0
	var names: Array = scores.keys()
	names.sort()
	for feeling: String in names:
		if float(scores[feeling]) > top:
			top = float(scores[feeling])
			best = feeling
	if best.is_empty() or top < float(_data.settle_threshold):
		return {"expression": str(_data.rest_expression), "intensity": float(_data.rest_intensity) * float(_data.exaggeration),
				"emote": "", "score": top}
	var intensity := minf((0.55 + 0.35 * top) * float(_data.exaggeration), float(_data.most_intensity))
	var emote := ""
	var emoting: Dictionary = _data.emote
	if top >= float(emoting.threshold):
		var clips: Array = (emoting.clips as Dictionary).get(best, [])
		if not clips.is_empty():
			# The same line picks the same gesture every time.
			emote = str(clips[absi(hash(resident_id + "|" + line)) % clips.size()])
	return {"expression": best, "intensity": intensity, "emote": emote, "score": top}


static func _bump(scores: Dictionary, feeling: String, amount: float) -> void:
	scores[feeling] = float(scores.get(feeling, 0.0)) + amount


static func _apply(scores: Dictionary, table: Dictionary, scale: float) -> void:
	for feeling: String in table:
		_bump(scores, feeling, float(table[feeling]) * scale)
