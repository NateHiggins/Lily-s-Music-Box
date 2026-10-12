extends RefCounted
## Match the hollow casting so basin contents and wall valves remain reachable.
const Controls := preload("res://scripts/building/orison_v2_water_controls.gd")

func mount(tap: TapProp) -> bool:
	var controls := Controls.new()
	if not controls.can_mount(tap) or tap.fixture not in ["bath_sink", "kitchen_sink"]:
		return false
	var primary := tap.get_node_or_null("PrimaryInteraction") as Area3D
	var has_handle_targets := tap._handles.size()==2 and tap._handles.all(func(handle): return handle.get_node_or_null("ManipulationTarget")!=null)
	if (primary == null and not has_handle_targets) or tap.get_node_or_null("FixtureBody") != null:
		return false
	if not controls.mount(tap): return false
	# FunctionalProp's broad Area would intercept rays before these controls,
	# then reach TapProp.interact_area(), which only implements curtains.
	if primary != null:
		tap.remove_child(primary)
		primary.free()
	var body := Controls.FixtureBody.new()
	body.name = "FixtureBody"
	# A solid bounding box filled the open bowl and hid the drain plug from
	# the player's ray. Use the same fixed casting that supports the plug.
	tap.add_child(body)
	for draw: MeshInstance3D in tap.get_node("StaticFixture").find_children("*","MeshInstance3D",true,false):
		if draw.mesh == null: continue
		var collision := CollisionShape3D.new()
		collision.shape = draw.mesh.create_trimesh_shape()
		body.add_child(collision)
		collision.global_transform = draw.global_transform
	return body.get_child_count()>0
