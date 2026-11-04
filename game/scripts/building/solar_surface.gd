extends RefCounted
## Sunspot groups for the telescope Sun (skywatch_sun.gdshaderinc). The campaign
## year sits just past the maximum of solar cycle 16 (smoothed maximum in 1928), so
## the disc usually shows several groups. They are generated, not measured: each
## group is born on a hashed day, lives one to three weeks, and rides the Sun's
## rotation across the disc at its latitude's rate.

const MAX_SPOTS := 8
const GROUPS_PER_DAY := 0.45 # births; about seven groups alive at once
const EPOCH := 2425560.5 # Julian day of 1928-11-10, the campaign's first day

## Spots on the visible disc at a Julian day, as the shader's vec4 array:
## xy disc position, z umbra radius in disc units, w strength.
static func spots(julian_day: float) -> PackedVector4Array:
	var found: Array[Vector4] = []
	var today := int(floor(julian_day - EPOCH))
	for born in range(today - 24, today + 1):
		var births := 1 if _hash(born, 0) < GROUPS_PER_DAY else 0
		births += 1 if _hash(born, 1) < GROUPS_PER_DAY * 0.4 else 0
		for g in births:
			var spot := _group(born, g, julian_day)
			if spot.w > 0.0: found.append(spot)
	found.sort_custom(func(a: Vector4, b: Vector4) -> bool: return a.z * a.w > b.z * b.w)
	var result := PackedVector4Array()
	for i in MAX_SPOTS:
		result.append(found[i] if i < found.size() else Vector4.ZERO)
	return result

static func _group(born: int, index: int, julian_day: float) -> Vector4:
	var seed := born * 7 + index
	var life := 7.0 + 14.0 * _hash(seed, 2)
	var age := julian_day - (EPOCH + float(born) + _hash(seed, 3))
	if age < 0.0 or age > life: return Vector4.ZERO
	# Spots appear between 5 and 30 degrees of latitude, north or south.
	var latitude := deg_to_rad((5.0 + 25.0 * _hash(seed, 4)) * (1.0 if _hash(seed, 5) < 0.5 else -1.0))
	# Differential rotation (synodic, degrees per day) and a random birth longitude.
	var rate := 13.45 - 3.0 * pow(sin(latitude), 2.0) - 0.98
	var longitude := deg_to_rad(-90.0 + 180.0 * _hash(seed, 6) + rate * age)
	if absf(longitude) > PI * 0.5 - 0.02: return Vector4.ZERO # behind the limb
	var position := Vector2(cos(latitude) * sin(longitude), sin(latitude))
	# Grow for a few days, then decay.
	var growth := clampf(age / 3.0, 0.0, 1.0) * clampf((life - age) / 4.0, 0.0, 1.0)
	var radius := (0.006 + 0.022 * pow(_hash(seed, 7), 2.0)) * (0.4 + 0.6 * growth)
	return Vector4(position.x, position.y, radius, growth)

static func _hash(a: int, b: int) -> float:
	var h := (a * 374761393 + b * 668265263) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float(h % 100000) / 100000.0
