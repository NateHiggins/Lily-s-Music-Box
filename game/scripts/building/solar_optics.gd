extends RefCounted
## Naked-eye solar optics for 1928-29 Queens: what the air between the street and
## the Sun does to it. Refraction lifts and squashes the low disk; the air mass it
## shines through reddens and dims it; coal smoke from the heating season, summer
## haze and rain-washed spring air change how much. The director publishes the
## results to the sky shader and the sunlight. Ruled by Lily 2026-11-04
## (rulings.json sun_naked_eye).
##
## Formulas: Bennett (1982) refraction; Kasten & Young (1989) relative air mass;
## Rayleigh optical depth 0.0088 * lambda^-4.05 at sea level (lambda in um);
## Angstrom aerosol optical depth beta * lambda^-alpha.

## Effective wavelengths of the display's red, green and blue, in micrometres.
const LAMBDA := Vector3(0.612, 0.549, 0.465)
## Apparent solar radius, degrees.
const SOLAR_RADIUS := 0.2666

## Apparent lift of a body at geometric elevation e (degrees). Bennett's formula
## takes the apparent elevation; one fixed-point step is plenty at this precision.
static func refraction_deg(geometric_deg: float) -> float:
	if geometric_deg < -2.0: return 0.0
	var apparent := geometric_deg + _bennett(geometric_deg)
	return _bennett(apparent)

static func _bennett(apparent_deg: float) -> float:
	var h := maxf(apparent_deg, -1.9)
	return (1.0 / tan(deg_to_rad(h + 7.31 / (h + 4.4)))) / 60.0

## The geometric direction lifted by refraction, azimuth unchanged.
static func apparent_direction(geometric: Vector3) -> Vector3:
	var elevation := rad_to_deg(asin(clampf(geometric.y, -1.0, 1.0)))
	var lifted := deg_to_rad(elevation + refraction_deg(elevation))
	var flat := Vector3(geometric.x, 0.0, geometric.z)
	if flat.length_squared() < 0.000001: return geometric
	return flat.normalized() * cos(lifted) + Vector3.UP * sin(lifted)

## Relative optical air mass at apparent elevation e (degrees).
static func air_mass(apparent_deg: float) -> float:
	var e := maxf(apparent_deg, -0.5)
	return 1.0 / (sin(deg_to_rad(e)) + 0.50572 * pow(e + 6.07995, -1.6364))

## Vertical squash of the disk: the ratio of its apparent height to its width. The
## bottom limb is lifted more than the top, by the difference in refraction.
static func flattening(geometric_deg: float) -> float:
	var top := refraction_deg(geometric_deg + SOLAR_RADIUS)
	var bottom := refraction_deg(geometric_deg - SOLAR_RADIUS)
	return clampf(1.0 - (bottom - top) / (2.0 * SOLAR_RADIUS), 0.6, 1.0)

## The air of a given day: Angstrom beta (how much particulate) and alpha (how fine).
## Heating-season coal smoke is fine and dark and peaks at the morning and evening
## firing; summer haze is coarse and wet; spring rain washes the air; autumn is the
## clearest of the year. Humidity swells every particle a little.
static func aerosol(month: int, minute_of_day: float, relative_humidity: float) -> Dictionary:
	var heating := _heating_season(month)
	# Boilers fire before breakfast and at supper; the smoke lies low until mid-morning.
	var firing := maxf(_bump(minute_of_day, 7.0 * 60.0, 150.0), _bump(minute_of_day, 18.0 * 60.0, 180.0))
	var smoke := heating * (0.10 + 0.08 * firing)
	var summer := _season_bump(month, 7.5, 1.6)
	var spring := _season_bump(month, 4.5, 1.2)
	var autumn := _season_bump(month, 9.8, 1.0)
	var haze := summer * 0.17
	var swell := 1.0 + 0.9 * pow(clampf(relative_humidity, 0.0, 1.0), 3.0)
	var beta := (0.045 + smoke + haze) * swell * (1.0 - 0.35 * spring) * (1.0 - 0.45 * autumn)
	# Smoke is fine (alpha near 1.6) and reddens; haze is coarse (alpha near 0.7) and whitens.
	var alpha := (1.6 * smoke + 0.7 * haze + 1.3 * 0.045) / maxf(smoke + haze + 0.045, 0.001)
	# A glare halo grows with coarse, wet particles.
	var glare := clampf(haze * 3.2 * swell + smoke * 0.8, 0.0, 1.0)
	return {"beta": beta, "alpha": alpha, "glare": glare, "smoke": smoke, "haze": haze}

## Vertical optical depth per channel for that air.
static func optical_depth(air: Dictionary) -> Vector3:
	var tau := Vector3.ZERO
	for i in 3:
		var l: float = LAMBDA[i]
		tau[i] = 0.0088 * pow(l, -4.05) + float(air.beta) * pow(l, -float(air.alpha))
	return tau

## Direct-beam transmission per channel at an apparent elevation.
static func transmission(apparent_deg: float, tau: Vector3) -> Vector3:
	var m := air_mass(apparent_deg)
	return Vector3(exp(-tau.x * m), exp(-tau.y * m), exp(-tau.z * m))

## The sunlight a street in Queens receives directly: colour and a relative energy
## (1.0 for a high Sun through clean air).
static func direct_light(geometric_deg: float, air: Dictionary) -> Dictionary:
	var apparent := geometric_deg + refraction_deg(geometric_deg)
	var tau := optical_depth(air)
	var t := transmission(apparent, tau)
	var reference := transmission(90.0, optical_depth({"beta": 0.045, "alpha": 1.3}))
	var relative := Vector3(t.x / reference.x, t.y / reference.y, t.z / reference.z)
	var peak := maxf(relative.x, maxf(relative.y, relative.z))
	var colour := Color(relative.x / peak, relative.y / peak, relative.z / peak) if peak > 0.0 else Color.BLACK
	var energy := (relative.x * 0.2126 + relative.y * 0.7152 + relative.z * 0.0722) * clampf((apparent + 0.6) / 1.2, 0.0, 1.0)
	return {"colour": colour, "energy": energy, "apparent_deg": apparent, "tau": tau}

static func _heating_season(month: int) -> float:
	# October to April, deepest in January.
	return {1: 1.0, 2: 0.95, 3: 0.7, 4: 0.3, 5: 0.0, 6: 0.0, 7: 0.0, 8: 0.0, 9: 0.0, 10: 0.25, 11: 0.65, 12: 0.9}.get(month, 0.0)

static func _season_bump(month: int, centre: float, width: float) -> float:
	var d := absf(float(month) - centre)
	d = minf(d, 12.0 - d)
	return clampf(1.0 - d / width, 0.0, 1.0)

static func _bump(x: float, centre: float, width: float) -> float:
	return clampf(1.0 - absf(x - centre) / width, 0.0, 1.0)
