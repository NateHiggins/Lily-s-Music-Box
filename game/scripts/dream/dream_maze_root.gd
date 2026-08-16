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
	if autonomous and pursuer != null and not pursuer.is_captured:
		pursuer.advance_fixed(delta)


## Capture is a dream outcome, not a failure state. The committed transaction
## owner decides everything that follows; this world only reports it.
func _on_captured() -> void:
	var shell := get_tree().get_first_node_in_group("campaign_shell")
	if shell is CampaignShell and (shell as CampaignShell).is_ancestor_of(self):
		(shell as CampaignShell).dream_director.end_dream("capture")
	else:
		push_warning("capture with no campaign shell; outcome not committed")


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
