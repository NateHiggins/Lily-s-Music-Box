extends RefCounted
## The eighteen witness clocks and the two honest clocks, in V2 (Lily,
## v1r_witness_tells_20261109 and v1r_small_props_20261109).
##
## V1 hung these by its own wall-art law on V1's rooms. V2 has its own rooms
## and its own pictures, so each clock's place is data
## (data/orison_v2/witness_clock_placements.json, in the blockout's own
## metres): the mantel clock and the travelling alarm stand on furniture, and
## every other clock hangs beside something the resident already has on that
## wall, or on a measured clear stretch where the flat has nothing hung.
##
## The profiles stay V1's (data/domestic_witness_clocks.json). Routing an
## intrusion to a clock is the director's business: `clocks` is the same
## case_id -> clock table DomesticWitnessSystem kept.
const PROFILES := "res://data/domestic_witness_clocks.json"
const PLACEMENTS := "res://data/orison_v2/witness_clock_placements.json"
const WitnessClock := preload("res://scripts/building/orison_v2_witness_clock.gd")
const HonestClock := preload("res://scripts/building/orison_v2_honest_clock.gd")
const Native := preload("res://scripts/building/orison_v2_native_witness_clocks.gd")
const HOLDER := "WitnessClocks"


## Returns {"clocks": {case_id: clock}, "honest": [lobby master, 4B octagon],
## "node": the holder under the blockout, "errors": [String]}.
static func mount(root: Node3D, blockout: Node3D, layout: Dictionary, adapter: Variant) -> Dictionary:
	var result := {"clocks": {}, "honest": [], "node": null, "errors": []}
	var errors: Array = result.errors
	var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string(PROFILES))
	var placed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PLACEMENTS))
	if not (catalog is Dictionary) or not (placed is Dictionary) or int(placed.get("schema_version", 0)) != 1:
		errors.append("witness clock profiles or placements missing")
		return result
	if root == null or blockout == null or blockout.get_node_or_null(HOLDER) != null:
		errors.append("witness clocks need a blockout and mount once")
		return result
	var native := Native.new()
	if not native.prepare():
		errors.append_array(native.errors)
		return result
	var spaces: Dictionary = {}
	for space: Dictionary in layout.get("spaces", []):
		spaces[str(space.id)] = true
	var holder := Node3D.new()
	holder.name = HOLDER
	blockout.add_child(holder)
	result.node = holder
	for spec: Dictionary in catalog.get("profiles", []):
		var case_id := str(spec.case_id)
		var place: Dictionary = placed.witness.get(case_id, {})
		if place.is_empty() or not _legal(place, spaces, adapter, errors, case_id):
			errors.append("no V2 place for witness clock " + case_id)
			continue
		var clock := WitnessClock.new()
		clock.native = native
		clock.configure(spec)
		clock.mounting = str(place.mounting)
		_pose(clock, place)
		holder.add_child(clock)
		result.clocks[case_id] = clock
	for place: Dictionary in placed.get("honest", []):
		if not _legal(place, spaces, adapter, errors, str(place.id)):
			continue
		var honest := HonestClock.new()
		honest.native = native
		honest.name = str(place.id)
		honest.prop_type = "wall_clock"
		honest.unit = str(place.unit)
		honest.clock_variant = str(place.variant)
		honest.graph_node_id = str(place.id)
		_pose(honest, place)
		holder.add_child(honest)
		result.honest.append(honest)
	print("[V2 WITNESS CLOCKS] %d witness clocks and %d honest clocks mounted" % [
			result.clocks.size(), result.honest.size()])
	return result


## A place is legal when its room is a V2 space and the thing it hangs beside
## or stands on is still in the building.
static func _legal(place: Dictionary, spaces: Dictionary, adapter: Variant, errors: Array, who: String) -> bool:
	if not spaces.has(str(place.get("space", ""))):
		errors.append("%s: unknown V2 space %s" % [who, place.get("space", "")])
		return false
	for key: String in ["beside", "support"]:
		var identity := str(place.get(key, ""))
		if not identity.is_empty() and (adapter == null or adapter.resolve(identity) == null):
			errors.append("%s: %s %s is not in the building" % [who, key, identity])
			return false
	return true


static func _pose(clock: Node3D, place: Dictionary) -> void:
	clock.position = Native.vec(place.position)
	clock.rotation.y = deg_to_rad(float(place.yaw_deg))
