extends RefCounted
## Physical controls shared by V2 water fixtures; TapProp remains the owner.
const Valve := preload("res://scripts/building/orison_v2_water_valve.gd")

class FixtureBody extends StaticBody3D:
	# Stop ancestor lookup on collision-only porcelain. Only the authored
	# controls should change water; the fixture body advertises no action.
	func interact_prompt() -> String:
		return ""
	func interact(_player: Node) -> void:
		pass

func can_mount(tap: TapProp) -> bool:
	return tap != null and tap._handles.size() == 2 \
			and tap._handle_wall_mounted.size() == 2 \
			and tap._handle_wall_mounted[0] and tap._handle_wall_mounted[1] \
			and tap.get_node_or_null("HotValveControl") == null \
			and tap.get_node_or_null("ColdValveControl") == null

func mount(tap: TapProp) -> bool:
	if not can_mount(tap): return false
	for index in 2:
		var control := Valve.new()
		control.name = "HotValveControl" if index == 0 else "ColdValveControl"
		control.tap = tap
		control.hot = index == 0
		control.collision_layer = 1
		control.collision_mask = 0
		control.monitoring = false
		# Wall-mounted caps sit 60 mm in front of their shared handle pivots.
		control.position = tap._handles[index].position + Vector3(0, 0, -.06)
		var collision := CollisionShape3D.new()
		var shape := SphereShape3D.new()
		shape.radius = .07
		collision.shape = shape
		control.add_child(collision)
		tap.add_child(control)
	return true
