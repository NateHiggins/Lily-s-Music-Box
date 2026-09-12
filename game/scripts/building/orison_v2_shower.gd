extends RefCounted
## Supply the collision and physical valve targets absent from V2's baked hull.
const Valve := preload("res://scripts/building/orison_v2_water_valve.gd")

class Receptor extends StaticBody3D:
	# Stop the player's ancestor lookup at this collision-only surface.
	# Clicking the pan must not fall through to TapProp's generic water cycle.
	func interact_prompt() -> String:
		return ""
	func interact(_player: Node) -> void:
		pass

func mount(tap: TapProp) -> bool:
	if tap == null or tap.fixture != "shower" or tap._handles.size() != 2:
		return false
	# Match TapProp._open_rect_basin(0.12, 0.72, 0.72, 0.12): four lips,
	# four bowl walls, its floor, and the low rear splash. No curtain-sized box.
	var pieces: Array[Array] = [
		[Vector3(.755, .025, .035), Vector3(0, .12, -.36)],
		[Vector3(.755, .025, .035), Vector3(0, .12, .36)],
		[Vector3(.035, .025, .72), Vector3(-.36, .12, 0)],
		[Vector3(.035, .025, .72), Vector3(.36, .12, 0)],
		[Vector3(.028, .12, .67), Vector3(-.334, .06, 0)],
		[Vector3(.028, .12, .67), Vector3(.334, .06, 0)],
		[Vector3(.67, .12, .028), Vector3(0, .06, -.334)],
		[Vector3(.67, .12, .028), Vector3(0, .06, .334)],
		[Vector3(.65, .018, .65), Vector3(0, .01, 0)],
		[Vector3(.74, .18, .035), Vector3(0, .20, .355)],
	]
	var body := Receptor.new()
	body.name = "FixtureBody"
	for piece in pieces:
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = piece[0]
		collision.shape = shape
		collision.position = piece[1]
		body.add_child(collision)
	tap.add_child(body)
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
