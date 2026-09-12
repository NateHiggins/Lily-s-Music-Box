extends RefCounted
## Supply the collision and physical valve targets absent from V2's baked hull.
const Controls := preload("res://scripts/building/orison_v2_water_controls.gd")

func mount(tap: TapProp) -> bool:
	var controls := Controls.new()
	if not controls.can_mount(tap) or tap.fixture != "shower" \
			or tap.get_node_or_null("FixtureBody") != null:
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
	var body := Controls.FixtureBody.new()
	body.name = "FixtureBody"
	for piece in pieces:
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = piece[0]
		collision.shape = shape
		collision.position = piece[1]
		body.add_child(collision)
	tap.add_child(body)
	return controls.mount(tap)
