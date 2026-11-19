extends "res://scripts/characters/orison_v2_resident_route.gd"
## During an authored visit, yield to real neighboring bodies before the
## existing route motor takes a step. Keep its geometry, doors and collision
## work in the parent; never move around a person by cutting a new corner.

var _bar_identities: Dictionary[int, String] = {}


func _point(identity: String, point: Vector3) -> int:
	var id := super._point(identity, point)
	if identity.begins_with("bar_"):
		_bar_identities[id] = identity
	return id


func _is_bar_point(id: int) -> bool:
	var identity: String = _bar_identities.get(id, "")
	# A rebuilt graph can reuse an old numeric point ID.
	return not identity.is_empty() and identities.get(identity, -1) == id


func _route_step_allowed(next: Vector3) -> bool:
	if not is_instance_valid(world) or world.get("loop_performances") == null:
		return true
	# The independently owned bar route keeps its measured seat/aisle clearance.
	if destination == "harukiya_bar" or _is_bar_point(current_id) \
			or (not path.is_empty() and _is_bar_point(path[0])):
		return true
	return bool(world.loop_performances.allow_step(resident, next))
