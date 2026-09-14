class_name OrisonV2M11C2DoorCrossingSupport
extends RefCounted
## Provider-independent public-door crossing path for the M11C2 proof.
##
## The immutable seam record owns the aperture, right axis, and endpoints. The
## real DoorProp pivot identifies the hinge jamb. A bounded lateral offset away
## from that jamb lets the production capsule clear the real open leaf without
## a teleport, collision mutation, or shop-specific coordinate.

const Support := preload(
		"res://tests/orison_v2_m11c1_owner_first/m11c1_harness_support.gd")
const RETAINED_CLEARANCE_FRACTION := 0.85


static func derive(root: Node, spec: Dictionary) -> Dictionary:
	var opening: Dictionary = spec.get("opening_bounds", {}) as Dictionary
	var center := Support.vector3(opening.get("center", []))
	var right := Support.vector3(opening.get("right_axis", [])).normalized()
	var half_width := float(opening.get("half_width_m", 0.0))
	var minimum_side := float(opening.get("minimum_side_clearance_m", 0.0))
	var forward_raw: Array = spec.get("forward_waypoints", []) as Array
	var return_raw: Array = spec.get("return_waypoints", []) as Array
	var start_raw: Variant = spec.get("start")
	if not center.is_finite() or not right.is_finite() or right.is_zero_approx() \
			or half_width <= 0.0 or minimum_side < 0.0 \
			or forward_raw.size() != 1 or return_raw.size() != 1 \
			or start_raw is not Array:
		return {"ok": false, "reason": "door crossing record is incomplete"}
	var identity := str(spec.get("door_identity", ""))
	var interactables: Array[Node] = []
	for candidate: Node in root.find_children(identity, "", true, false):
		if candidate.has_method("interact") and candidate is Node3D:
			interactables.append(candidate)
	if interactables.size() != 1:
		return {"ok": false, "reason": "door owner does not resolve exactly once",
				"matching_interactable_count": interactables.size()}
	var door := interactables[0] as Node3D
	var hinge_projection := (door.global_position - center).dot(right)
	if absf(hinge_projection) < half_width * 0.5:
		return {"ok": false,
				"reason": "resolved DoorProp pivot is not on an aperture jamb"}
	var available := half_width - PlayerController.BODY_RADIUS - minimum_side
	if available <= 0.0:
		return {"ok": false,
				"reason": "opening has no bounded lateral capsule clearance"}
	var hinge_sign := signf(hinge_projection)
	var offset := available * RETAINED_CLEARANCE_FRACTION
	var lateral := right * (-hinge_sign * offset)
	var start := Support.vector3(start_raw)
	var inside := Support.vector3(forward_raw[0])
	var outside_return := Support.vector3(return_raw[0])
	if not start.is_finite() or not inside.is_finite() \
			or not outside_return.is_finite():
		return {"ok": false, "reason": "door crossing endpoints are invalid"}
	var forward: Array[Vector3] = [start + lateral, inside + lateral]
	var backward: Array[Vector3] = [outside_return + lateral, outside_return]
	return {
		"ok": true,
		"forward_waypoints": forward,
		"return_waypoints": backward,
		"receipt": {
			"applicable": true,
			"authority": "opening_bounds plus resolved production DoorProp pivot",
			"door_identity": identity,
			"source_traversal_id": str(spec.get("id", "")),
			"source_record_sha256": JSON.stringify(spec).sha256_text(),
			"hinge_jamb": "positive_right_axis" if hinge_sign > 0.0 \
					else "negative_right_axis",
			"capsule_radius_m": PlayerController.BODY_RADIUS,
			"half_width_m": half_width,
			"minimum_side_clearance_m": minimum_side,
			"lateral_offset_m": offset,
			"retained_clearance_fraction": RETAINED_CLEARANCE_FRACTION,
			"provider_identity_read": false,
			"shop_identity_branch": false,
			"coordinate_fields_omitted": true,
		},
	}
