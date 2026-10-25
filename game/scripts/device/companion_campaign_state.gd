extends RefCounted
## Additive campaign domain. No world observations, pending events or input leases
## survive loading. The ordinary campaign transaction validates these bytes.
const Memory = preload("res://scripts/device/companion_memory.gd")
const KEY := "companion"

static func fresh() -> Dictionary:
	return {"version":1, "memory":Memory.new().snapshot(), "draft":"", "visited":[]}

static func valid(value: Variant) -> bool:
	if value is not Dictionary or value.size() != 4: return false
	if typeof(value.get("version")) not in [TYPE_INT, TYPE_FLOAT] or value.version != 1: return false
	if value.get("memory") is not Dictionary or not Memory.new().restore(value.memory): return false
	if value.get("draft") is not String or value.draft.length() > 512: return false
	if value.get("visited") is not Array or value.visited.size() > 64: return false
	var unique := {}
	for room: Variant in value.visited:
		if room is not String or room.is_empty() or room.length() > 160 or unique.has(room): return false
		unique[room] = true
	return true
