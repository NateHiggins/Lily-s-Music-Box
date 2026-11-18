extends RefCounted
## Test-only support witness. Arrival remains the original motor's authority.
const CONTACT_TOLERANCE := .003

static func inspect(bar: OrisonV2BarRegion, player: PlayerController, goal: Vector3,
		feet_override: Vector3 = Vector3.INF) -> Dictionary:
	var result := {"kind": "flat", "supported": false, "feet": feet_override, "contacts": [], "goal_id": ""}
	if not is_instance_valid(bar) or not is_instance_valid(player) or not player.is_inside_tree(): return result
	var feet: Vector3 = player.global_position if feet_override == Vector3.INF else feet_override
	result.feet = feet
	if not feet.is_finite() or not goal.is_finite(): return result
	var destination: Node3D = bar.destination
	if not is_instance_valid(destination): return result
	var navigation := destination.get_node_or_null("Navigation")
	if navigation == null: return result
	for marker: Node in navigation.get_children():
		if marker is Marker3D and str(marker.name).begins_with("balcony_tread_") \
				and marker.global_position.distance_to(goal) <= .001:
			result.kind = "stair"; result.goal_id = str(marker.name); break
	var space := player.get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(feet + Vector3.UP * .04,
		feet - Vector3.UP * (.24 if result.kind == "stair" else .08), 1)
	ray.exclude = [player.get_rid()]
	var hit := space.intersect_ray(ray)
	result.support_ray = {"hit": not hit.is_empty(), "at": hit.get("position"), "normal": hit.get("normal"),
		"owner": str(hit.collider.get_path()) if not hit.is_empty() else ""}
	var original_strict: bool = not hit.is_empty() and absf(hit.position.y - feet.y) < .035 and absf(feet.y - goal.y) < .05
	result.original_strict = original_strict
	# Keep every original strict positive, including flat top/bottom treads.
	# The additional contact witness is needed only for rejected stair edges.
	if result.kind == "flat" or original_strict:
		result.supported = original_strict
		return result
	var architecture := destination.get_node_or_null("Architecture")
	if architecture == null: return result
	var owners: Array[Node] = []
	for suffix: String in ["floor", "oak"]:
		var name := "F01_retail_bar_destination_Destination_Stair_" + suffix
		var body := architecture.get_node_or_null(name + "/" + name + "_col")
		if body != null: owners.append(body)
	if owners.size() != 2: return result
	var minimum_normal := cos(player.floor_max_angle)
	var ray_supported: bool = not hit.is_empty() and hit.collider in owners and hit.normal.dot(Vector3.UP) >= minimum_normal
	result.on_floor = player.is_on_floor()
	result.real_floor_normal = player.get_floor_normal()
	result.exact_stair_ray = ray_supported
	var capsule: CapsuleShape3D = player._capsule
	var shape: CollisionShape3D = player._shape
	result.capsule_binding = {"capsule_exists":capsule != null,"shape_exists":shape != null,
		"same_resource":shape != null and shape.shape == capsule,
		"basis_y":shape.global_basis.y if shape != null else Vector3.ZERO,
		"basis_scale":shape.global_basis.get_scale() if shape != null else Vector3.ZERO,
		"orthonormal":shape != null and shape.global_basis.is_equal_approx(shape.global_basis.orthonormalized())}
	if capsule == null or shape == null or shape.shape != capsule or not shape.global_transform.is_finite() or shape.global_basis.determinant() <= 0.0: return result
	var rigid: Basis = shape.global_basis.orthonormalized()
	# Bound numerical scale/shear drift within the SAME3mm contact budget.
	# ||(B-R)p|| <= ||B-R||_F * max_local_radius; no body is changed.
	var delta_squared: float = (shape.global_basis.x-rigid.x).length_squared() + (shape.global_basis.y-rigid.y).length_squared() + (shape.global_basis.z-rigid.z).length_squared()
	var transform_error_bound: float = sqrt(delta_squared) * maxf(capsule.height*.5,capsule.radius)
	result.shape_transform_error_bound_m = transform_error_bound
	if not rigid.y.is_equal_approx(Vector3.UP) or transform_error_bound > CONTACT_TOLERANCE: return result
	var center := shape.global_position + feet - player.global_position
	var half_axis := maxf(0.0, capsule.height * .5 - capsule.radius)
	result.capsule = {"center": center, "radius": capsule.radius, "height": capsule.height, "contact_tolerance_m": CONTACT_TOLERANCE}
	var actual_contact := false
	for index in player.get_slide_collision_count():
		var contact := player.get_slide_collision(index)
		var point := contact.get_position()
		var axis: Vector3 = center + rigid.y * clampf((point-center).dot(rigid.y),-half_axis,half_axis)
		var surface_error := absf(point.distance_to(axis) - capsule.radius)
		var owner: Object = contact.get_collider()
		var allowed: bool = owner in owners
		var normal := contact.get_normal()
		var qualified: bool = allowed and normal.dot(Vector3.UP) >= minimum_normal and surface_error + transform_error_bound <= CONTACT_TOLERANCE
		result.contacts.append({"owner": str(owner.get_path()) if owner is Node else str(owner), "point": point,
			"normal": normal, "exact_stair_owner": allowed, "surface_error_m": surface_error, "surface_error_with_transform_bound_m":surface_error+transform_error_bound, "qualified": qualified})
		actual_contact = actual_contact or qualified
	result.supported = player.is_on_floor() and player.get_floor_normal().dot(Vector3.UP) >= minimum_normal and ray_supported and actual_contact
	return result
