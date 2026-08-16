class_name DreamMazeRoot
extends Node3D
## N6: the production dream world. From the committed transaction context it
## deterministically assembles the campaign slot's module chain (N2 catalog),
## spawns the dream body of the player with the real service lamp, and runs
## the Tenant as one invisible navigation body wearing the subject's
## shadows-only silhouette (N3 contract). Capture reaches DreamDirector's
## existing outcome seam; no failure state exists here.
##
## N4's boundary contract is unchanged: identity and revision arrive through
## configure_dream before this node enters the tree, and every (re)build
## starts at D00. A chase frame is never reconstructed.

const START_MODULE_ID := "D00_4B_THRESHOLD"
const PROFILES_PATH := "res://data/dream_profiles.json"

## Tests drive pursuit steps manually when false.
var autonomous := true

## N7. The slot's authored ceiling, read from the catalog, and the clock
## against it. A passage that cannot end is not a passage.
var run_cap_s := 0.0
var run_elapsed_s := 0.0
## One outcome per dream, and it closes the door behind itself. Without
## this, a hazard firing in the same frame as capture would call
## end_dream twice and the second call would be into a director whose
## phase has already moved on.
var _outcome_committed := false

var dream_context: Dictionary = {}
var start_marker: Marker3D
var plan: Dictionary = {}
var player: PlayerController
var pursuer: DreamPursuer
var maze_built := false


func configure_dream(context: Dictionary) -> void:
	dream_context = context.duplicate(true)


func _ready() -> void:
	add_to_group("dream_world")
	start_marker = Marker3D.new()
	start_marker.name = START_MODULE_ID
	add_child(start_marker)
	_build_world()


func start_module_id() -> String:
	return START_MODULE_ID


func _build_world() -> void:
	var profile := _load_profile(str(dream_context.get("profile_id", "")))
	if profile.is_empty():
		push_warning("dream profile missing; boundary payload only")
		return
	var seed_hex := str(dream_context.get("seed_hex", ""))
	var slot := int(profile.get("campaign_slot", 1))
	var catalog := DreamMazeBuilder.load_catalog()
	plan = DreamMazeBuilder.assemble(catalog, seed_hex, slot)
	if not (plan.get("defects", ["unbuilt"]) as Array).is_empty():
		push_error("dream maze assembly defects: %s" % str(plan.defects))
		return
	var constants: Dictionary = catalog.get("constants", {})
	var clear_ceiling := float(constants.get("clear_ceiling_m", 3.015))
	# THE RUN CEILING IS AUTHORED AND HAS NEVER BEEN READ. The catalog
	# carries campaign_run_ceilings_s [28, 38, 50, 62, 76, 90] and no
	# GDScript has ever consumed it, so every dream so far could run
	# forever. Slot 1 is Mina's 28 seconds.
	var ceilings: Array = constants.get("campaign_run_ceilings_s", [])
	run_cap_s = float(ceilings[slot - 1]) if slot >= 1 			and slot <= ceilings.size() else 0.0
	DreamMazeBuilder.build_geometry(self, plan, clear_ceiling)
	maze_built = true

	var spawn: Array = plan.spawn_player
	start_marker.position = Vector3(spawn[0], 0.0, spawn[1])
	# The dream body: the same controller, the same service lamp, already
	# lit at the threshold. The waking body was freed with its world; no
	# transform crosses the boundary.
	player = PlayerController.new()
	player.position = start_marker.position
	add_child(player)
	player.set_lamp_enabled(true)

	pursuer = DreamPursuer.new()
	add_child(pursuer)
	pursuer.setup(plan, profile.get("pursuit", {}), player, seed_hex)
	pursuer.captured.connect(_on_captured)


func _physics_process(delta: float) -> void:
	if not autonomous or _outcome_committed:
		return
	if pursuer != null and not pursuer.is_captured:
		pursuer.advance_fixed(delta)
	if run_cap_s <= 0.0:
		return
	run_elapsed_s += delta
	if run_elapsed_s >= run_cap_s:
		_cap_fold()


## THE CAP CLOSES THE RUN BY TOPOLOGY, NOT BY CHEATING. When the slot's
## ceiling expires the Tenant is re-placed onto the chain waypoint AHEAD
## of the player, so the shorter converging route finishes the passage --
## the brief's own words: "the topology closes the distance; rubber-
## banding does not". It does NOT teleport the Tenant behind the camera,
## invent geometry, or touch the seeded pursuit numbers: reset_run zeroes
## the clock and preserves run_parameters() exactly.
##
## This is deliberately NOT the D09 terminal fold, which belongs to the
## final campaign slot and to a ring Mina's chain does not reach.
func _cap_fold() -> void:
	if pursuer == null or player == null or _outcome_committed:
		return
	var here := DreamMazeBuilder.nav_module_at(
			plan, player.position.x, player.position.z)
	var route: Array = DreamMazeBuilder.chain_route(
			plan, here, "D05_SERVICE_RISER") if here != "" else []
	if route.is_empty():
		# Already in the terminal module: close from its own far end
		# rather than from nowhere.
		var far: Array = plan.spawn_pursuer
		pursuer.reset_run(Vector3(far[0], 0.0, far[1]))
		return
	pursuer.reset_run(_flat(route[0]))


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


## Every ending goes through one door. Capture, fall and contact are all
## dream outcomes and none of them is a failure state; the committed
## transaction owner decides what follows and this world only reports it.
func _commit_outcome(outcome: String) -> bool:
	if _outcome_committed:
		return false
	var shell := get_tree().get_first_node_in_group("campaign_shell")
	if shell is CampaignShell and (shell as CampaignShell).is_ancestor_of(self):
		if (shell as CampaignShell).dream_director.end_dream(outcome):
			_outcome_committed = true
			# Nothing may step into the frame between the durable commit
			# and CampaignShell's deferred free of this world.
			autonomous = false
			return true
		return false
	push_warning("%s with no campaign shell; outcome not committed" % outcome)
	return false


func _on_captured() -> void:
	_commit_outcome("capture")


func _load_profile(profile_id: String) -> Dictionary:
	if profile_id.is_empty():
		return {}
	var parsed: Variant = JSON.parse_string(
			FileAccess.get_file_as_string(PROFILES_PATH))
	if parsed is not Dictionary:
		return {}
	var profiles: Dictionary = (parsed as Dictionary).get("profiles", {})
	var profile: Variant = profiles.get(profile_id, {})
	return profile if profile is Dictionary else {}
