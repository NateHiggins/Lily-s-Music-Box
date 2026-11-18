extends Node
## The domestic witnesses in V2 (Lily, v1r_witness_tells_20261109: "Import
## them together with the director").
##
## V1's DomesticWitnessSystem did two things. It built one clock per resident
## and a stand-in household object per case, and it routed every intrusion of
## the sanity director to that resident's own witness, plus exactly one of the
## player's own things in 4B. The routing is imported whole. The objects are
## V2's: a tell is attached to the household object V2 already gave the flat
## where one matches (`possessed_objects.json`). Objects with no V2
## counterpart, and the eighteen clocks, arrive as Blender assets and join
## through `bind_clocks` and `add_witness`.

signal intrusion_routed(case_id: String, tier: int, answered: Array)

const DATA := "res://data/orison_v2/possessed_objects.json"
const Tell := preload("res://scripts/building/orison_v2_possessed_tell.gd")

var clocks: Dictionary = {}       # case id -> witness clock
var anomalies: Dictionary = {}    # case id -> the object that answers for it
var home_relays: Array = []       # 4B's own things: one answers each intrusion
var tells: Dictionary = {}        # tell id -> tell
var unmatched: Array[String] = [] # rows whose V2 object could not be found
var player: Node3D
var vantry_points: Node
var errors: Array[String] = []


## Attaches every tell whose V2 object stands. Returns how many were attached.
func mount(adapter: Variant, vantry_network: Node = null) -> int:
	name = "DomesticWitnesses"
	vantry_points = vantry_network
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if parsed is not Dictionary or parsed.get("schema_version") != 1 or parsed.get("tells") is not Array:
		errors.append("possessed object table malformed")
		return 0
	for spec: Dictionary in parsed.tells:
		var object := adapter.resolve(str(spec.get("node", ""))) as Node3D
		if object == null:
			unmatched.append(str(spec.get("id", "")))
			continue
		# The table's fields are read here, where the table is owned.
		var moves: Dictionary = spec.get("motion", {})
		var motion: Dictionary = {"per_tier": bool(moves.get("per_tier", false))}
		if moves.has("turn_y"):
			motion.turn_y = float(moves.turn_y)
		if moves.has("knob_z"):
			motion.knob_z = float(moves.knob_z)
		if bool(moves.get("flip", false)):
			motion.flip = true
		if bool(moves.get("seize", false)):
			motion.seize = true
		var tell := Tell.new()
		tell.configure({"id": str(spec.get("id", "")), "unit": str(spec.get("unit", "")),
			"kind": str(spec.get("kind", "")), "tell": str(spec.get("tell", "")),
			"cases": spec.get("cases", []), "relay_all": bool(spec.get("relay_all", false)),
			"motion": motion}, object)
		add_child(tell)
		add_witness(tell)
	# Teresa's witness is not a second ceiling object. Her real bedroom point
	# owns the mechanical aperture that closes before she stops speaking.
	if vantry_points != null and vantry_points.get("points") is Dictionary \
			and (vantry_points.points as Dictionary).has("F01_D_BED_VANTRY_POINT"):
		anomalies["teresa_call_bells"] = vantry_points
	print("[WITNESS] %d household tells on V2's own objects, %d clocks, %d of 4B's things relay (unmatched: %s)" % [
			tells.size(), clocks.size(), home_relays.size(), unmatched])
	return tells.size()


## A witness with `prop_id`, `case_ids`, `relay_all` and `stage_haunt(case_id,
## tier, player)`: a tell on a V2 object, or a possessed object of its own.
func add_witness(witness: Node) -> void:
	tells[str(witness.prop_id)] = witness
	for case_id: Variant in witness.case_ids:
		anomalies[str(case_id)] = witness
	if bool(witness.relay_all):
		home_relays.append(witness)


## The eighteen witness clocks, by case, when their batch is mounted.
func bind_clocks(by_case: Dictionary) -> void:
	for case_id: Variant in by_case:
		clocks[str(case_id)] = by_case[case_id]


func bind_director(director: SanityDirector, body: Node3D) -> void:
	player = body
	if not director.intruded.is_connected(_on_intruded):
		director.intruded.connect(_on_intruded)


func _on_intruded(case_id: String, tier: int) -> void:
	var answered: Array = []
	var clock: Variant = clocks.get(case_id)
	if clock != null and is_instance_valid(clock) and clock.stage_haunt(tier, player):
		answered.append(clock)
	var anomaly: Variant = anomalies.get(case_id)
	if anomaly != null and is_instance_valid(anomaly) and anomaly.stage_haunt(case_id, tier, player):
		answered.append(anomaly)
	var relay := _home_relay(case_id, tier)
	if relay != null and relay.stage_haunt(case_id, tier, player):
		answered.append(relay)
	intrusion_routed.emit(case_id, tier, answered)


## Tests and the debug panel: the same routing without waiting for the director.
func force(case_id: String, tier := 2) -> bool:
	var did := false
	var clock: Variant = clocks.get(case_id)
	if clock != null and is_instance_valid(clock):
		did = clock.stage_haunt(tier, player) or did
	var anomaly: Variant = anomalies.get(case_id)
	if anomaly != null and is_instance_valid(anomaly):
		did = anomaly.stage_haunt(case_id, tier, player) or did
	var relay := _home_relay(case_id, tier)
	if relay != null:
		did = relay.stage_haunt(case_id, tier, player) or did
	return did


## Apartment 4B is the receiver, not the source. Exactly one familiar object
## answers each building intrusion, chosen deterministically, so the room
## feels implicated without every appliance performing on cue.
func _home_relay(case_id: String, tier: int) -> Node:
	var live: Array = home_relays.filter(func(relay: Variant) -> bool: return is_instance_valid(relay))
	if live.is_empty():
		return null
	return live[absi((case_id + str(tier)).hash()) % live.size()]


func restore_all() -> void:
	for tell: Variant in tells.values():
		if is_instance_valid(tell) and tell.has_method("restore"):
			tell.restore()
