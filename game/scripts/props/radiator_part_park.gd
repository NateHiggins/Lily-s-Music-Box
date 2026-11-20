extends RefCounted
## Where a loose radiator part rests when it is let go away from its seat (Lily, 20 Nov: no physics for radiator
## parts; their movements lock to preset places). The place is measured, not simulated: the nearest clear floor beside the
## radiator, level with the part's seat along the radiator's long axis and `step` metres toward its middle, on
## whichever side has floor (a wall on one side is found by the same ray), lying in its flattest orientation in the
## radiator's frame with its lowest point on the floor. With no floor found either side, it rests on the radiator top.

const ORIENTATIONS := [Vector3.ZERO, Vector3(PI * 0.5, 0, 0), Vector3(-PI * 0.5, 0, 0), Vector3(0, 0, PI * 0.5), Vector3(0, 0, -PI * 0.5)]


static func pose(radiator: Node3D, part: CollisionObject3D, draw: Node3D, seat_global: Vector3, _step: float) -> Transform3D:
	var box := AABB()
	var first := true
	var inverse := radiator.global_transform.affine_inverse()
	for node: Node in radiator.native_rig.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if not mesh.is_visible_in_tree() or part.is_ancestor_of(mesh):
			continue
		var local: AABB = (inverse * mesh.global_transform) * mesh.get_aabb()
		box = local if first else box.merge(local)
		first = false
	var seat := radiator.to_local(seat_global)
	var frame := radiator.global_basis.orthonormalized()
	var lying := Basis.IDENTITY
	var lowest := 0.0
	if draw != null and draw is VisualInstance3D:
		var shape: AABB = (draw as VisualInstance3D).get_aabb()
		var flattest := INF
		for euler: Vector3 in ORIENTATIONS:
			var turn := Basis.from_euler(euler)
			var low := INF
			var high := -INF
			for index in 8:
				var corner: Vector3 = turn * (draw.transform * shape.get_endpoint(index))
				low = minf(low, corner.y)
				high = maxf(high, corner.y)
			if high - low < flattest - 0.0001:
				flattest = high - low
				lying = turn
				lowest = low
	var basis := frame * lying
	var space := part.get_world_3d().direct_space_state
	# Candidate spots around the radiator's footprint, nearest the seat first: each axis, each side, three reaches.
	var spots: Array = []
	for axis: Vector3 in [Vector3.RIGHT, Vector3.BACK]:
		for side: float in [1.0, -1.0]:
			var edge := box.end.dot(axis) if side > 0.0 else box.position.dot(axis)
			for extra: float in [0.14, 0.24, 0.36]:
				var spot := seat - axis * seat.dot(axis) + axis * (edge + side * extra)
				spots.append(spot)
	spots.sort_custom(func(a: Vector3, b: Vector3) -> bool:
		return Vector2(a.x - seat.x, a.z - seat.z).length() < Vector2(b.x - seat.x, b.z - seat.z).length())
	for spot: Vector3 in spots:
		var top := radiator.to_global(Vector3(spot.x, box.end.y + 0.3, spot.z))
		var bottom := radiator.to_global(Vector3(spot.x, box.position.y - 0.3, spot.z))
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(top, bottom, 1, [part.get_rid()]))
		if hit.is_empty() or absf(radiator.to_local(hit.position).y - box.position.y) > 0.06:
			continue
		var placed := Transform3D(basis, hit.position - frame.y * (lowest - 0.0005))
		if _clear(part, placed, space):
			return placed
	# Nowhere clear on the floor: rest on the radiator top beside the seat.
	var middle := seat + Vector3(0, box.end.y - seat.y + 0.002, 0)
	return Transform3D(basis, radiator.to_global(middle) - frame.y * lowest)


static func _clear(part: CollisionObject3D, pose: Transform3D, space: PhysicsDirectSpaceState3D) -> bool:
	for node: Node in part.get_children():
		var shape := node as CollisionShape3D
		if shape == null or shape.shape == null or shape.disabled:
			continue
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape.shape
		query.transform = pose * shape.transform
		query.exclude = [part.get_rid()]
		query.collision_mask = 1
		query.margin = 0.0002
		if not space.intersect_shape(query, 1).is_empty():
			return false
	return true
