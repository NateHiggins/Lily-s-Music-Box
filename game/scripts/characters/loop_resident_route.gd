extends "res://scripts/characters/orison_v2_resident_route.gd"
## During an authored visit, yield to real neighboring bodies before the
## existing route motor takes a step. Keep its geometry, doors and collision
## work in the parent; never move around a person by cutting a new corner.

func _route_step_allowed(next: Vector3) -> bool:
	if not is_instance_valid(world) or world.get("loop_performances") == null:
		return true
	# The independently owned bar route keeps its measured seat/aisle clearance.
	if destination == "harukiya_bar":
		return true
	for identity: String in identities:
		if identity.begins_with("bar_") and (int(identities[identity]) == current_id \
				or (not path.is_empty() and int(identities[identity]) == path[0])):
			return true
	return bool(world.loop_performances.allow_step(resident, next))
