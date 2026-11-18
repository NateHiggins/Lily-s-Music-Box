extends RefCounted
## Optional standing-column reader. Existing actors without the accessor keep
## each caller's original clearance policy. Malformed measured data must block
## the operation, rather than silently borrowing smaller legacy dimensions.

static func read(actor: Node3D) -> Dictionary:
	if not is_instance_valid(actor) or not actor.has_method("standing_occupancy"):
		return {}
	var value: Variant = actor.call("standing_occupancy")
	if not value is Dictionary or value.is_empty():
		return {"invalid": true}
	var base: Variant = value.get("base")
	var radius: Variant = value.get("radius")
	var height: Variant = value.get("height")
	if not base is Vector3 or not base.is_finite():
		return {"invalid": true}
	if not (radius is float or radius is int) or not (height is float or height is int):
		return {"invalid": true}
	if not is_finite(float(radius)) or not is_finite(float(height)) \
			or float(radius) <= 0.0 or float(height) <= 0.0:
		return {"invalid": true}
	return {"base": base, "radius": float(radius), "height": float(height)}
