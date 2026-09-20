extends RefCounted
## Keep the sink solid below its rim while leaving the wall valves reachable.
const Controls := preload("res://scripts/building/orison_v2_water_controls.gd")

func mount(tap: TapProp) -> bool:
	var controls := Controls.new()
	if not controls.can_mount(tap) or tap.fixture not in ["bath_sink", "kitchen_sink"]:
		return false
	var primary := tap.get_node_or_null("PrimaryInteraction") as Area3D
	if primary == null or tap.get_node_or_null("FixtureBody") != null:
		return false
	var lower: AABB = tap._visual_bounds()
	var rim_top := .815
	var panel_size := Vector3(.61, .18, .045)
	var panel_position := Vector3(0, .87, .205)
	if tap.fixture == "kitchen_sink":
		# Match the shared roll-rim sink and its integral splash panel.
		var width := .50 if tap.compact_kitchen else .61
		var depth := .38 if tap.compact_kitchen else .46
		var top := .905 if tap.compact_kitchen else .90
		rim_top = top + .02
		panel_size = Vector3(width + .03, .16, .035)
		panel_position = Vector3(0, top + .075, depth * .5 - .004)
	if not lower.position.is_finite() or not lower.size.is_finite() \
			or lower.size.x <= 0 or lower.size.z <= 0 or lower.position.y >= rim_top:
		return false
	lower.size.y = rim_top - lower.position.y
	if not controls.mount(tap): return false
	# FunctionalProp's broad Area would intercept rays before these controls,
	# then reach TapProp.interact_area(), which only implements curtains.
	tap.remove_child(primary)
	primary.free()
	var body := Controls.FixtureBody.new()
	body.name = "FixtureBody"
	for bounds: AABB in [lower, AABB(panel_position - panel_size * .5, panel_size)]:
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = bounds.size
		collision.shape = shape
		collision.position = bounds.get_center()
		body.add_child(collision)
	tap.add_child(body)
	return true
