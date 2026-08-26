extends Node

const Ephemeris := preload("res://scripts/building/celestial_ephemeris.gd")

var fails := 0
func _check(ok: bool, label: String) -> void:
	print("  [%s] %s" % ["ephemeris ok" if ok else "EPHEMERIS FAIL", label])
	if not ok: fails += 1

func _ready() -> void:
	var j2000 := {"year": 2000, "month": 1, "day": 1, "hour": 12}
	_check(absf(Ephemeris.julian_day(j2000) - 2451545.0) < 0.000001,
			"the UTC calendar reproduces J2000")
	_check(absf(Ephemeris.greenwich_sidereal_degrees(2451545.0)
			- 280.46061837) < 0.000001, "J2000 matches the USNO sidereal angle")
	var equinox := {"year": 2026, "month": 3, "day": 20, "hour": 12}
	_check(Ephemeris.altitude_degrees(
			Ephemeris.sun_direction(equinox, 0.0, 0.0)) > 87.0,
			"the equinox noon sun is near the equatorial zenith")
	_check(absf(Ephemeris.moon_direction(
			equinox, 40.75, -73.92).length() - 1.0) < 0.00001,
			"the lunar solution is normalized")
	var star_a: Vector3 = Ephemeris.star_direction(101.287, -16.716,
			equinox, 40.75, -73.92)
	var next_sidereal := {"year": 2026, "month": 3, "day": 21,
			"hour": 11, "minute": 56}
	var star_b: Vector3 = Ephemeris.star_direction(101.287, -16.716,
			next_sidereal, 40.75, -73.92)
	_check(star_a.dot(star_b) > 0.9999,
			"a catalog star closes after approximately one sidereal day")
	_check(Ephemeris.sun_direction(equinox, 40.75, -73.92).dot(
			Ephemeris.sun_direction(equinox, -33.86, 151.21)) < 0.0,
			"one instant resolves differently for Queens and Sydney")
	print("[CELESTIAL EPHEMERIS] RESULT: %s (%d failures)" % [
			"PASS" if fails == 0 else "FAIL", fails])
	get_tree().quit(fails)
