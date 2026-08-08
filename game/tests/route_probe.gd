extends Node
## Walk the route to each shop as a body would, and name whatever stops
## it.
##
## Rendering found the doorway and the crossing both clear, and the
## report is that the player is stopped before reaching either. Eyes
## have been wrong twice on this street tonight; a shape cast along the
## actual walking line cannot be.
##
## Sweeps a capsule the size of the player along each leg of the route
## and prints the first collider it touches, with its parent, so the
## offender can be named in gen_layout rather than guessed at.

const LEGS_BAR := [
	[Vector3(0.72, 0.9, 10.70), Vector3(2.90, 0.9, 13.60)],
	[Vector3(2.90, 0.9, 13.60), Vector3(3.50, 0.9, 15.10)],
	[Vector3(3.50, 0.9, 15.10), Vector3(4.10, 0.9, 19.30)],
	[Vector3(4.10, 0.9, 19.30), Vector3(4.60, 0.9, 23.60)],
	[Vector3(4.60, 0.9, 23.60), Vector3(4.875, 0.9, 26.40)],
	[Vector3(4.875, 0.9, 26.40), Vector3(4.875, 0.9, 28.05)],
]
## Straight in at the door from due south, which is the only approach
## that matters: if this is clear the shop is enterable and any earlier
## block was the diagonal lane clipping street furniture, not the door.
const LEGS_DOOR_IN := [
	[Vector3(18.67, 0.9, 13.60), Vector3(18.67, 0.9, 12.40)],
	[Vector3(18.67, 0.9, 12.40), Vector3(18.67, 0.9, 11.40)],
	[Vector3(18.67, 0.9, 11.40), Vector3(18.67, 0.9, 9.50)],
]
const LEGS_BODEGA := [
	[Vector3(0.72, 0.9, 10.70), Vector3(6.20, 0.9, 12.40)],
	[Vector3(6.20, 0.9, 12.40), Vector3(12.00, 0.9, 12.60)],
	[Vector3(12.00, 0.9, 12.60), Vector3(16.60, 0.9, 12.60)],
	[Vector3(16.60, 0.9, 12.60), Vector3(18.67, 0.9, 12.60)],
]


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var root: Node3D = load(
			"res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	await get_tree().create_timer(1.5).timeout
	await get_tree().physics_frame
	var space := root.get_viewport().find_world_3d().direct_space_state

	var shape := CapsuleShape3D.new()
	shape.radius = 0.33          # the player's own radius, from the layout
	shape.height = 1.524

	for name_and_legs in [["TO THE BAR", LEGS_BAR],
			["TO THE BODEGA", LEGS_BODEGA],
			["IN THE BODEGA DOOR", LEGS_DOOR_IN]]:
		print("--- %s ---" % name_and_legs[0])
		var blocked := false
		for leg in name_and_legs[1]:
			var from: Vector3 = leg[0]
			var to: Vector3 = leg[1]
			var params := PhysicsShapeQueryParameters3D.new()
			params.shape = shape
			params.transform = Transform3D(Basis(), from)
			params.motion = to - from
			params.collide_with_areas = false
			var res := space.cast_motion(params)
			var frac: float = res[0] if res.size() > 0 else 1.0
			if frac >= 0.999:
				print("  clear   %v -> %v" % [from, to])
				continue
			blocked = true
			var stop := from + (to - from) * frac
			print("  BLOCKED %v -> %v  at %.0f%% (%v)"
					% [from, to, frac * 100.0, stop])
			# Name it: rest the capsule where it stopped and see what
			# it is touching.
			params.transform = Transform3D(Basis(),
					from + (to - from) * maxf(0.0, frac - 0.001))
			params.motion = (to - from).normalized() * 0.6
			var hits := space.intersect_shape(
					_point_query(from + (to - from) * frac), 8)
			for h in hits:
				var c = h.collider
				var parent = c.get_parent() if c else null
				print("       touching %s (%s) parent=%s"
						% [str(c.name), c.get_class(),
						str(parent.name) if parent else "-"])
		if not blocked:
			print("  route is walkable end to end")
	get_tree().quit(0)


func _point_query(at: Vector3) -> PhysicsShapeQueryParameters3D:
	var s := SphereShape3D.new()
	s.radius = 0.55
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = s
	q.transform = Transform3D(Basis(), at)
	q.collide_with_areas = false
	return q
