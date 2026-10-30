extends RefCounted
## Bounded, JSON-safe conversation memory. Facts must be supplied by witnesses.
## A campaign year of correspondence, about two exchanges a day, fits without
## dropping its beginning; each record stays clipped to 512/2048 characters.
const LIMIT := 1024
var history: Array[Dictionary] = []
var counts: Dictionary = {}
var seen: Dictionary = {}
var pending_ids: Array[String] = []
var last_object := ""
var branch := ""
var trust := 0

func record(input: String, intent: String, line_id: String, output: String) -> void:
	increment(intent)
	history.append({"input":input.left(512), "intent":intent, "line_id":line_id, "output":output.left(2048)})
	while history.size() > LIMIT: history.pop_front()

func increment(key: String) -> int:
	var previous := int(counts.get(key, 0))
	if not counts.has(key) and counts.size() >= 64: return previous
	counts[key] = mini(999, previous + 1)
	return int(counts[key])

func snapshot() -> Dictionary:
	return {"version":1, "history":history.duplicate(true), "counts":counts.duplicate(true),
		"seen":seen.duplicate(true), "last_object":last_object, "branch":branch, "trust":trust}

func restore(value: Dictionary) -> bool:
	# Reject malformed or unbounded state atomically; never partly adopt it.
	if value.get("version") != 1: return false
	if value.size() != 7: return false
	if value.get("history") is not Array or value.history.size() > LIMIT: return false
	if value.get("counts") is not Dictionary or value.counts.size() > 64: return false
	if value.get("seen") is not Dictionary or value.seen.size() > 128: return false
	if value.get("last_object") is not String or value.last_object.length() > 160: return false
	if value.get("branch") is not String or value.branch.length() > 80: return false
	if value.get("trust") is not int and value.get("trust") is not float: return false
	if not is_finite(float(value.trust)) or value.trust != int(value.trust) or abs(value.trust) > 100: return false
	for record_value: Variant in value.history:
		if record_value is not Dictionary: return false
		if record_value.size() != 4: return false
		for key: String in ["input", "intent", "line_id", "output"]:
			var limit := 512 if key == "input" else 2048 if key == "output" else 80
			if record_value.get(key) is not String or record_value[key].length() > limit: return false
	for key: Variant in value.counts:
		if key is not String or key.length() > 80: return false
		var count: Variant = value.counts[key]
		if (count is not int and count is not float) or not is_finite(float(count)): return false
		if count != int(count) or count < 0 or count > 999: return false
	for key: Variant in value.seen:
		if key is not String or key.length() > 160 or value.seen[key] is not bool: return false
	history.assign(value.history.duplicate(true))
	counts = {}
	for key: String in value.counts: counts[key] = int(value.counts[key])
	seen = value.seen.duplicate(true)
	last_object = value.last_object
	branch = value.branch
	trust = int(value.trust)
	pending_ids.clear() # Resolve again against the current world after reload.
	return true
