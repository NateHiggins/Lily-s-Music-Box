extends RefCounted
## Additive campaign domain. Heard words keep their source. Live witnesses,
## pending events and input leases expire on load. The ordinary campaign transaction validates these bytes.
const Memory = preload("res://scripts/device/companion_memory.gd")
const Lexicon = preload("res://scripts/device/companion_lexicon.gd")
const KEY := "companion"

static func fresh() -> Dictionary:
	return {"version":2, "memory":Memory.new().snapshot(), "draft":"", "visited":[], "heard":{}}

static func valid(value: Variant) -> bool:
	if value is not Dictionary or typeof(value.get("version")) not in [TYPE_INT, TYPE_FLOAT]: return false
	if value.version == 1:
		if value.size() != 4: return false
	elif value.version == 2:
		if value.size() != 5 or not Lexicon.valid(value.get("heard")): return false
	else: return false
	if value.get("memory") is not Dictionary or not Memory.new().restore(value.memory): return false
	if value.get("draft") is not String or value.draft.length() > 512: return false
	if value.get("visited") is not Array or value.visited.size() > 64: return false
	var unique := {}
	for room: Variant in value.visited:
		if room is not String or room.is_empty() or room.length() > 160 or unique.has(room): return false
		unique[room] = true
	return true
