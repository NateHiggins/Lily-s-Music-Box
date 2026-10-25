extends "res://scripts/building/day_night_director.gd"
## V2's real neighbouring blocks extend past the retained V1 storm backdrop.
## The existing director remains the sole atmosphere and celestial authority.

static func city_visibility(conditions: Dictionary) -> Vector2:
	var precipitation := clampf(float(conditions.get("precipitation_intensity", 0.0)), 0.0, 1.0)
	var humidity := clampf(float(conditions.get("relative_humidity", 0.70)), 0.0, 1.0)
	var obscuration := smoothstep(0.05, 0.80, precipitation)
	if int(conditions.get("weather_code", 0)) in [45, 48]:
		obscuration = 1.0
	# A dry cloud ceiling and high humidity alone cannot become ground fog.
	var haze := smoothstep(0.72, 1.0, humidity)
	var clear_air := Vector2(lerpf(70.0, 40.0, haze), lerpf(400.0, 300.0, haze))
	return clear_air.lerp(Vector2(13.0, 58.0), obscuration)


func _resolve_fog_profile(profile: Dictionary) -> void:
	var distances := city_visibility(_live_conditions)
	profile.fog_begin = distances.x
	profile.fog_end = distances.y
	# Depth density is an opacity ceiling, not an extinction rate. Keep the
	# distant ground seam fully extinguished; weather controls physical range.
	profile.fog_d = 1.0
	# The Corona ash wall closes the street in sepia, the coal smog's own colour.
	var dust := clampf(float(_live_conditions.get("dust", 0.0)), 0.0, 1.0)
	if dust > 0.0:
		profile.fog = (profile.fog as Color).lerp(Color(.46, .33, .19), dust * .85)
		profile.fog_begin = lerpf(profile.fog_begin, 4.0, dust)
		profile.fog_end = lerpf(profile.fog_end, 45.0, dust)
		profile.key_e *= 1.0 - dust * .7
