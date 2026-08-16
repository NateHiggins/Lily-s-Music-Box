class_name DreamPursuer
extends CharacterBody3D
## N6: the Tenant as one invisible navigation body wearing the just-integrated
## subject's shadows-only silhouette.
##
## The pursuit numbers and rules are N3's measured contract, unchanged
## (art/renders/dream_light_n3): lamp-on with a clear physics line refreshes
## the target continuously at the lit speed; darkness decays to a coarse
## last-known point sampled from footsteps, at the dark speed; a stop is one
## final audible plant so darkness delays capture but can never make the run
## endless. What N6 adds is the real maze: movement follows the assembled
## chain's door waypoints, so the body never teleports and never crosses
## closed collision, and acquisition rays are blocked by real module walls.
##
## No mesh, face, attack animation or true form exists here. The silhouette
## is the resident's own hero model forced to SHADOW_CASTING_SETTING_SHADOWS_ONLY;
## it can fall on a wall, and it can never be looked at.

signal captured

const BODY_RADIUS := 0.28
const BODY_HEIGHT := 1.70
const RAY_HEIGHT := 1.05
const ARRIVE_M := 0.05
const HERO_MODEL_DIR := "res://assets/characters"

var plan: Dictionary = {}
var profile: Dictionary = {}
var player: Node3D
var silhouette_source := ""

var elapsed_s := 0.0
var acquisition_time_s := -1.0
var capture_time_s := -1.0
var acquired := false
var is_captured := false
var last_known_position := Vector3.ZERO

var _lit_speed_mps := 6.35
var _dark_speed_mps := 3.35
var _hearing_period_s := 0.72
var _capture_radius_m := 0.75
var _hearing_due_s := 0.0
var _last_target_position := Vector3.ZERO
var _target_was_moving := false


func setup(maze_plan: Dictionary, pursuit_profile: Dictionary,
		target_player: Node3D, seed_hex: String) -> void:
	plan = maze_plan
	profile = pursuit_profile
	player = target_player
	name = "TenantNavigationBody"
	collision_layer = 2
	collision_mask = 1
	var body_shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = BODY_RADIUS
	capsule.height = BODY_HEIGHT
	body_shape.shape = capsule
	body_shape.position.y = BODY_HEIGHT * 0.5
	add_child(body_shape)
	_seed_run(seed_hex)
	_borrow_silhouette(str(profile.get("silhouette_resident", "")))
	var spawn: Array = plan.get("spawn_pursuer", [0.0, 0.0])
	position = Vector3(spawn[0], 0.0, spawn[1])
	if player != null:
		last_known_position = _flat(player.global_position)
		_last_target_position = last_known_position


## The exact campaign seed arrives as sixteen hex digits. Consume the two
## 32-bit halves (N4's contract) and fold them into one in-range RNG seed;
## same campaign, same pursuit jitter, forever.
func _seed_run(seed_hex: String) -> void:
	var halves := DreamMazeBuilder.seed_halves(seed_hex)
	var rng := RandomNumberGenerator.new()
	rng.seed = (halves[0] << 21) ^ halves[1] ^ 0x51E77
	_lit_speed_mps = float(profile.get("lit_speed_mps", 6.35)) \
			+ rng.randf_range(-1.0, 1.0) \
			* float(profile.get("lit_speed_jitter_mps", 0.12))
	_dark_speed_mps = float(profile.get("dark_speed_mps", 3.35)) \
			+ rng.randf_range(-1.0, 1.0) \
			* float(profile.get("dark_speed_jitter_mps", 0.08))
	_hearing_period_s = float(profile.get("hearing_period_s", 0.72)) \
			+ rng.randf_range(-1.0, 1.0) \
			* float(profile.get("hearing_period_jitter_s", 0.08))
	_capture_radius_m = float(profile.get("capture_radius_m", 0.75))
	_hearing_due_s = _hearing_period_s


## Borrow the subject's own hero model as a shadows-only proxy. Every
## geometry instance is forced out of the beauty pass; any light or autoplay
## the source scene carries is removed. If the model is missing the contract
## survives on a proportioned capsule, loudly.
func _borrow_silhouette(resident_slug: String) -> void:
	var proxy: Node3D = null
	if not resident_slug.is_empty():
		var path := "%s/%s/%s.gltf" % [HERO_MODEL_DIR, resident_slug,
				resident_slug]
		var packed := load(path) as PackedScene
		if packed != null:
			proxy = packed.instantiate()
			silhouette_source = resident_slug
	if proxy == null:
		push_warning("dream silhouette model missing for '%s'; capsule proxy"
				% resident_slug)
		var stand_in := MeshInstance3D.new()
		var capsule := CapsuleMesh.new()
		capsule.radius = BODY_RADIUS
		capsule.height = BODY_HEIGHT
		stand_in.mesh = capsule
		stand_in.position.y = BODY_HEIGHT * 0.5
		proxy = stand_in
		silhouette_source = "capsule_fallback"
	proxy.name = "BorrowedSilhouette"
	_force_shadows_only(proxy)
	add_child(proxy)


func _force_shadows_only(node: Node) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = \
				GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	if node is Light3D:
		node.queue_free()
		return
	if node is AnimationPlayer:
		(node as AnimationPlayer).stop()
	for child in node.get_children():
		_force_shadows_only(child)


## One deterministic pursuit step. DreamMazeRoot drives this from its physics
## loop in production; tests drive it directly at a fixed rate.
func advance_fixed(delta: float) -> void:
	if is_captured or player == null:
		return
	elapsed_s += delta
	var target := _flat(player.global_position)
	var target_moving := target.distance_to(_last_target_position) > 0.00001
	if _target_was_moving and not target_moving:
		# The final shoe plant is audible (N3's corrected rule): a stop is a
		# real place the body can finish reaching, never a hiding state.
		last_known_position = target
	_last_target_position = target
	_target_was_moving = target_moving

	var clear_light := lamp_finds_target()
	if clear_light:
		if not acquired:
			acquisition_time_s = elapsed_s
		acquired = true
		last_known_position = target
	else:
		_hearing_due_s -= delta
		if _hearing_due_s <= 0.0:
			if target_moving:
				last_known_position = target
			_hearing_due_s += _hearing_period_s

	var speed := _lit_speed_mps if clear_light and acquired \
			else _dark_speed_mps
	_advance_along_route(speed * delta)
	if _flat(position).distance_to(target) <= _capture_radius_m:
		is_captured = true
		capture_time_s = elapsed_s
		captured.emit()


## N3's acquisition gate against the real light owner: the player's actual
## service lamp must be on AND an unobstructed physics line must exist.
## Module walls are real layer-1 collision, so acquisition can never cross
## opaque architecture.
func lamp_finds_target() -> bool:
	if player == null or not player.has_method("lamp_is_enabled") \
			or not player.call("lamp_is_enabled"):
		return false
	return has_clear_line_to_target()


func has_clear_line_to_target() -> bool:
	var from := global_position + Vector3.UP * RAY_HEIGHT
	var to: Vector3 = player.global_position + Vector3.UP * RAY_HEIGHT
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	var exclude: Array[RID] = [get_rid()]
	if player is CollisionObject3D:
		exclude.append((player as CollisionObject3D).get_rid())
	query.exclude = exclude
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## Test hook mirroring N3: one acquisition scan without movement.
func scan_light_once() -> bool:
	if lamp_finds_target():
		acquired = true
		acquisition_time_s = elapsed_s
		last_known_position = _flat(player.global_position)
	return acquired


## Reset for a paired measurement run without changing seeded parameters.
func reset_run(at: Vector3) -> void:
	elapsed_s = 0.0
	acquisition_time_s = -1.0
	capture_time_s = -1.0
	acquired = false
	is_captured = false
	_hearing_due_s = _hearing_period_s
	position = at
	if player != null:
		last_known_position = _flat(player.global_position)
		_last_target_position = last_known_position
		_target_was_moving = false


func run_parameters() -> Dictionary:
	return {
		"lit_speed_mps": _lit_speed_mps,
		"dark_speed_mps": _dark_speed_mps,
		"hearing_period_s": _hearing_period_s,
		"capture_radius_m": _capture_radius_m,
	}


## Move a distance budget along the chain toward the last-known point:
## straight to it inside the same module, otherwise through the connecting
## door centers in order. Segments stay inside convex module rects, so the
## body follows the validated graph and cannot cut a wall corner.
func _advance_along_route(budget: float) -> void:
	var here := _flat(position)
	var goal := _flat(last_known_position)
	var my_module := DreamMazeBuilder.nav_module_at(plan, here.x, here.z)
	var goal_module := DreamMazeBuilder.nav_module_at(plan, goal.x, goal.z)
	var waypoints: Array = []
	if my_module != "" and goal_module != "" and my_module != goal_module:
		waypoints = DreamMazeBuilder.chain_route(plan, my_module, goal_module)
	waypoints.append(goal)
	# The route is recomputed every step, so waypoints already passed must be
	# pruned or the body walks back to them forever at a doorway.
	while waypoints.size() >= 2:
		var w0 := _flat(waypoints[0])
		var w1 := _flat(waypoints[1])
		if here.distance_to(w1) <= w0.distance_to(w1) + 0.01:
			waypoints.pop_front()
		else:
			break
	for waypoint in waypoints:
		if budget <= 0.0:
			break
		var flat_goal := _flat(waypoint)
		var leg := flat_goal - _flat(position)
		var length := leg.length()
		if length <= ARRIVE_M:
			continue
		var step := minf(budget, length)
		position += leg.normalized() * step
		budget -= step


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
