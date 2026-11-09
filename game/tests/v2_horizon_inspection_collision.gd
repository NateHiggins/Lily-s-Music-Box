extends RefCounted
## The game builds collision only for city horizon parts the player can reach,
## inside the walk boundary's wall (owner ruling 2026-11-09; collision for the
## rest cost ~10 s of every world startup). Reviews that measure unreachable
## parts with rays - roof contacts, sight lines, bounds - install this
## inspection-only copy of the same collision from each part's source mesh.

const FACES := preload("res://scripts/building/orison_v2_native_faces.gd")


## True when the runtime built collision on exactly the reachable parts.
static func reach_split_holds(horizon: Node3D) -> bool:
	if horizon.get("reach_frame") == null:
		return false
	for draw: MeshInstance3D in horizon.find_children("*", "MeshInstance3D", true, false):
		if not draw.has_meta("v2_city_horizon_faces_mesh") or draw.has_meta("v2_inspection_collision"):
			continue
		var reachable: bool = float(horizon.call("reach_distance", draw)) <= float(horizon.get("reach_radius_m"))
		if reachable != (draw.get_node_or_null("HorizonCollision") != null):
			return false
	return true


## Adds a HorizonCollision body, exactly as the runtime builds one, to every
## static part that has none; returns how many it added. Idempotent.
static func install(horizon: Node3D) -> int:
	var added := 0
	for draw: MeshInstance3D in horizon.find_children("*", "MeshInstance3D", true, false):
		if not draw.has_meta("v2_city_horizon_faces_mesh") or draw.get_node_or_null("HorizonCollision") != null:
			continue
		var body := StaticBody3D.new()
		body.name = "HorizonCollision"
		draw.add_child(body)
		var shape := CollisionShape3D.new()
		var native := ConcavePolygonShape3D.new()
		native.set_faces(FACES.read(draw.get_meta("v2_city_horizon_faces_mesh")))
		shape.shape = native
		body.add_child(shape)
		draw.set_meta("v2_inspection_collision", true)
		added += 1
	return added
