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
## In at the door from due south, then INTO THE AISLE, which is what a
## body actually does. The old third leg carried straight north at the
## door's centre line and ended in the east wall shelving — but that
## shelving is meant to be there, and no shop has a clear straight run
## from its door to its back wall along one x. The aisle between the
## gondolas (x 17.95) and that shelving (x 18.97) is the route, so the
## probe walks it.
const LEGS_DOOR_IN := [
	[Vector3(18.67, 0.9, 13.60), Vector3(18.67, 0.9, 12.40)],
	[Vector3(18.67, 0.9, 12.40), Vector3(18.67, 0.9, 11.40)],
	[Vector3(18.67, 0.9, 11.40), Vector3(18.46, 0.9, 10.40)],
	[Vector3(18.46, 0.9, 10.40), Vector3(18.46, 0.9, 8.00)],
]
## From the foot of the stair, west through the red door into the room.
## The opening is pierced in the x 4.00..4.30 wall between z 33.95 and
## 34.90; the leaf is CLOSED by default, so a block here names either
## the leaf (hinge still wrong) or the wall (the lane is off the hole).
const LEGS_BAR_ROOM := [
	[Vector3(4.875, -1.9, 34.42), Vector3(4.40, -1.9, 34.42)],
	[Vector3(4.40, -1.9, 34.42), Vector3(3.80, -1.9, 34.42)],
	[Vector3(3.80, -1.9, 34.42), Vector3(2.60, -1.9, 34.60)],
]
const LEGS_BODEGA := [
	[Vector3(0.72, 0.9, 10.70), Vector3(6.20, 0.9, 12.40)],
	[Vector3(6.20, 0.9, 12.40), Vector3(12.00, 0.9, 12.60)],
	[Vector3(12.00, 0.9, 12.60), Vector3(16.60, 0.9, 12.60)],
	[Vector3(16.60, 0.9, 12.60), Vector3(18.67, 0.9, 12.60)],
]
## M0.5 check 1. Four shops - laundry, cobbler, hardware, photo - have
## bays outside the lateral stage boundary (STAGE_W -20.10 / STAGE_E
## +20.60 in Blender x, which is Godot x unchanged). The brief claims
## they are unreachable. That claim came off boundary DIMENSIONS, and
## the boundary bodies are only 7.55 m deep in Blender y, centred at
## y -13.45, so they cover the north walk and part of the carriageway
## and may not close the SOUTH pavement at all.
##
## Blender y -> Godot z is negated by b2g, so the south pavement (walk
## y -23.744..-28.316) lies at Godot z 23.744..28.316. These sweeps run
## along its middle, outward past both boundaries.
const SOUTH_WALK_Z := 26.03
const LEGS_SOUTH_W := [
	[Vector3(-18.00, 0.9, SOUTH_WALK_Z), Vector3(-19.50, 0.9, SOUTH_WALK_Z)],
	[Vector3(-19.50, 0.9, SOUTH_WALK_Z), Vector3(-20.60, 0.9, SOUTH_WALK_Z)],
	[Vector3(-20.60, 0.9, SOUTH_WALK_Z), Vector3(-22.00, 0.9, SOUTH_WALK_Z)],
	[Vector3(-22.00, 0.9, SOUTH_WALK_Z), Vector3(-24.00, 0.9, SOUTH_WALK_Z)],
	[Vector3(-24.00, 0.9, SOUTH_WALK_Z), Vector3(-27.00, 0.9, SOUTH_WALK_Z)],
	[Vector3(-27.00, 0.9, SOUTH_WALK_Z), Vector3(-30.00, 0.9, SOUTH_WALK_Z)],
]
const LEGS_SOUTH_E := [
	[Vector3(18.00, 0.9, SOUTH_WALK_Z), Vector3(20.00, 0.9, SOUTH_WALK_Z)],
	[Vector3(20.00, 0.9, SOUTH_WALK_Z), Vector3(21.20, 0.9, SOUTH_WALK_Z)],
	[Vector3(21.20, 0.9, SOUTH_WALK_Z), Vector3(23.00, 0.9, SOUTH_WALK_Z)],
	[Vector3(23.00, 0.9, SOUTH_WALK_Z), Vector3(25.00, 0.9, SOUTH_WALK_Z)],
	[Vector3(25.00, 0.9, SOUTH_WALK_Z), Vector3(27.00, 0.9, SOUTH_WALK_Z)],
	[Vector3(27.00, 0.9, SOUTH_WALK_Z), Vector3(29.50, 0.9, SOUTH_WALK_Z)],
]
## Reaching the pavement is not reaching the shop. Walk each outlying
## bay's centre line from mid-pavement up to its shopfront face
## (Blender y -28.316 -> Godot z 28.316), stopping 0.4 m short of the
## glass so a clear result means "a body can stand at that door".
const LEGS_LAUNDRY_DOOR := [
	[Vector3(-29.60, 0.9, SOUTH_WALK_Z), Vector3(-29.60, 0.9, 27.90)],
]
const LEGS_COBBLER_DOOR := [
	[Vector3(-24.00, 0.9, SOUTH_WALK_Z), Vector3(-24.00, 0.9, 27.90)],
]
const LEGS_HARDWARE_DOOR := [
	[Vector3(23.70, 0.9, SOUTH_WALK_Z), Vector3(23.70, 0.9, 27.90)],
]
const LEGS_PHOTO_DOOR := [
	[Vector3(29.00, 0.9, SOUTH_WALK_Z), Vector3(29.00, 0.9, 27.90)],
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
			["INTO THE BAR ROOM", LEGS_BAR_ROOM],
			["TO THE BODEGA", LEGS_BODEGA],
			["IN THE BODEGA DOOR", LEGS_DOOR_IN],
			["SOUTH WALK, WEST PAST STAGE_W", LEGS_SOUTH_W],
			["SOUTH WALK, EAST PAST STAGE_E", LEGS_SOUTH_E],
			["TO MODEL LAUNDRY DOOR", LEGS_LAUNDRY_DOOR],
			["TO SHOE REBUILDING DOOR", LEGS_COBBLER_DOOR],
			["TO HARDWARE PAINT DOOR", LEGS_HARDWARE_DOOR],
			["TO PHOTO SUPPLIES DOOR", LEGS_PHOTO_DOOR]]:
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
			# A leg that BEGINS inside something reads as perfectly clear:
			# cast_motion has no free space to measure and hands back 1.0.
			# That is how a bin lying across the bodega door passed this
			# probe for two sessions — the leg started in it. Check the
			# start pose before trusting any sweep.
			var stuck := space.intersect_shape(params, 4)
			if stuck.size() > 0:
				blocked = true
				print("  STUCK AT START %v (sweep result is meaningless)"
						% from)
				for h in stuck:
					var sc = h.collider
					var sp = sc.get_parent() if sc else null
					print("       inside %s parent=%s"
							% [str(sc.name), str(sp.name) if sp else "-"])
				continue
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
