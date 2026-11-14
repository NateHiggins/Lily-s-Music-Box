extends RefCounted
## PRIVATE pilot only. Owns avoidance RIDs, never actors or route targets.
## Caller snapshots every actual public body BEFORE ordinary route motors.
## No navmesh, physics substitute, movement callback, or progress guarantee.
var map: RID
var agents: Dictionary = {}
var errors: Array[String] = []

func open() -> void:
	if map.is_valid():
		return
	map = NavigationServer3D.map_create()
	NavigationServer3D.map_set_up(map, Vector3.UP)
	NavigationServer3D.map_set_active(map, true)

## Complete snapshot rows: id, feet, preferred, steer, player.
## For unsteered bodies preferred MUST be observed actual velocity (zero if parked).
## steer is only for the approved public motor seam, never shop local transactions.
func submit(rows: Array[Dictionary]) -> bool:
	if not map.is_valid():
		errors.append("Map not opened")
		return false
	var seen: Dictionary = {}
	for row in rows:
		var key: int = int(row["id"])
		var feet: Vector3 = row["feet"]
		var wanted: Vector3 = row["preferred"]
		if seen.has(key) or not feet.is_finite() or not wanted.is_finite():
			errors.append("Invalid or duplicate body snapshot")
			return false
		seen[key] = true
		if not agents.has(key):
			var rid := NavigationServer3D.agent_create()
			agents[key] = {"rid": rid, "velocity": Vector3.ZERO, "frame": -1}
			NavigationServer3D.agent_set_map(rid, map)
			NavigationServer3D.agent_set_use_3d_avoidance(rid, false)
			NavigationServer3D.agent_set_avoidance_layers(rid, 1)
			NavigationServer3D.agent_set_neighbor_distance(rid, 4.0)
			NavigationServer3D.agent_set_time_horizon_agents(rid, 1.5)
			NavigationServer3D.agent_set_time_horizon_obstacles(rid, 1.0)
			NavigationServer3D.agent_set_height(rid, 1.4)
			NavigationServer3D.agent_set_avoidance_callback(rid, _computed.bind(key))
			NavigationServer3D.agent_set_avoidance_enabled(rid, true)
		var rid: RID = agents[key]["rid"]
		var steer: bool = bool(row["steer"])
		wanted.y = 0.0
		# Soft planning envelopes match existing .60/.65 courtesy, not body changes.
		NavigationServer3D.agent_set_radius(rid, 0.35 if bool(row["player"]) else 0.30)
		NavigationServer3D.agent_set_max_neighbors(rid, rows.size())
		NavigationServer3D.agent_set_avoidance_mask(rid, 1 if steer else 0)
		NavigationServer3D.agent_set_avoidance_priority(rid, 0.5 if steer else 1.0)
		NavigationServer3D.agent_set_max_speed(rid, 1.05 if steer else wanted.length())
		NavigationServer3D.agent_set_position(rid, feet)
		NavigationServer3D.agent_set_velocity(rid, wanted.limit_length(1.05) if steer else wanted)
	for key in agents.keys():
		if not seen.has(key):
			_remove(key)
	return true

## Consume once, before next submit. Empty means HOLD, never use preferred fallback.
## Caller rejects changed target/eligibility and native/floor/peer/bounds failure.
func take(key: int) -> Dictionary:
	if not agents.has(key):
		return {}
	var entry: Dictionary = agents[key]
	var age: int = Engine.get_physics_frames() - int(entry["frame"])
	if age < 0 or age > 1 or int(entry["frame"]) < 0:
		return {}
	entry["frame"] = -1
	return {"velocity": Vector3(entry["velocity"]).limit_length(1.05), "age": age}

func _computed(velocity: Vector3, key: int) -> void:
	if agents.has(key) and velocity.is_finite():
		agents[key]["velocity"] = velocity
		agents[key]["frame"] = Engine.get_physics_frames()

func _remove(key: int) -> void:
	var rid: RID = agents[key]["rid"]
	NavigationServer3D.agent_set_avoidance_callback(rid, Callable())
	NavigationServer3D.agent_set_map(rid, RID())
	NavigationServer3D.free_rid(rid)
	agents.erase(key)

## Mandatory on owner retirement AND preview cleanup; SceneTree pause is insufficient.
func close() -> void:
	for key in agents.keys():
		_remove(key)
	if map.is_valid():
		NavigationServer3D.map_set_active(map, false)
		NavigationServer3D.free_rid(map)
		map = RID()
