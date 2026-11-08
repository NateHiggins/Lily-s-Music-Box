extends "res://scripts/building/skywatch_mirage.gd"
## The Star God's lens and its exit ring (star_god.gd phase C), on the mirage's
## compositor machinery. Disabled whenever the strength is zero.

func _init() -> void:
	super._init("res://shaders/star_god_lens.compute")

## einstein: Einstein radius in radians; direction: the entity's centre (world);
## ring: the exit ring's angular radius in radians, 0 for none.
func publish_lens(einstein: float, direction: Vector3, ring: float) -> void:
	var azimuth := atan2(direction.x, -direction.z)
	var elevation := asin(clampf(direction.y, -1.0, 1.0))
	var strength := maxf(einstein, 0.0015 if ring > 0.0 else 0.0)
	lock.lock(); state = Vector4(strength, azimuth, elevation, ring); lock.unlock()
	enabled = strength > .001 and camera_ref != null and camera_ref.get_ref() != null
	capture.enabled = enabled
