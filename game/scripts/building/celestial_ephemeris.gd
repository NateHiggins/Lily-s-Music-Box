class_name CelestialEphemeris
extends RefCounted
## Offline observer-aware geometry. UTC and coordinates are explicit inputs;
## location privacy remains entirely with LiveWeatherService.

const J2000 := 2451545.0

static func julian_day(utc: Dictionary) -> float:
	var year := int(utc.year)
	var month := int(utc.month)
	var day := float(utc.day) + (float(utc.get("hour", 0))
			+ float(utc.get("minute", 0)) / 60.0
			+ float(utc.get("second", 0)) / 3600.0) / 24.0
	if month <= 2:
		year -= 1
		month += 12
	var century := floori(float(year) / 100.0)
	var correction := 2 - century + floori(float(century) / 4.0)
	return floor(365.25 * float(year + 4716)) \
			+ floor(30.6001 * float(month + 1)) + day + correction - 1524.5

static func greenwich_sidereal_degrees(jd: float) -> float:
	# USNO Circular 179. UTC is a sufficient UT1 stand-in for rendering.
	var centuries := (jd - J2000) / 36525.0
	return fposmod(280.46061837 + 360.98564736629 * (jd - J2000)
			+ 0.000387933 * centuries * centuries
			- centuries * centuries * centuries / 38710000.0, 360.0)

static func sun_direction(utc: Dictionary, latitude: float,
		longitude: float) -> Vector3:
	var jd := julian_day(utc)
	var days := jd - J2000
	var anomaly := deg_to_rad(fposmod(357.529 + 0.98560028 * days, 360.0))
	var mean_longitude := fposmod(280.459 + 0.98564736 * days, 360.0)
	var ecliptic_longitude := deg_to_rad(fposmod(mean_longitude
			+ 1.915 * sin(anomaly) + 0.020 * sin(2.0 * anomaly), 360.0))
	var obliquity := deg_to_rad(23.439 - 0.00000036 * days)
	var ra := atan2(cos(obliquity) * sin(ecliptic_longitude),
			cos(ecliptic_longitude))
	var dec := asin(sin(obliquity) * sin(ecliptic_longitude))
	return equatorial_direction(rad_to_deg(ra), rad_to_deg(dec), jd,
			latitude, longitude)

static func moon_direction(utc: Dictionary, latitude: float,
		longitude: float) -> Vector3:
	# Compact geocentric lunar elements: visual ephemeris, not navigation.
	var jd := julian_day(utc)
	var days := jd - 2451543.5
	var node := deg_to_rad(fposmod(125.1228 - 0.0529538083 * days, 360.0))
	var inclination := deg_to_rad(5.1454)
	var periapsis := deg_to_rad(fposmod(318.0634 + 0.1643573223 * days, 360.0))
	var eccentricity := 0.0549
	var anomaly := deg_to_rad(fposmod(115.3654 + 13.0649929509 * days, 360.0))
	var eccentric_anomaly := anomaly + eccentricity * sin(anomaly) \
			* (1.0 + eccentricity * cos(anomaly))
	var xv := cos(eccentric_anomaly) - eccentricity
	var yv := sqrt(1.0 - eccentricity * eccentricity) * sin(eccentric_anomaly)
	var true_anomaly := atan2(yv, xv)
	var radius := sqrt(xv * xv + yv * yv)
	var orbital := true_anomaly + periapsis
	var ecliptic := Vector3(
			radius * (cos(node) * cos(orbital) - sin(node) * sin(orbital) * cos(inclination)),
			radius * sin(orbital) * sin(inclination),
			radius * (sin(node) * cos(orbital) + cos(node) * sin(orbital) * cos(inclination)))
	var obliquity := deg_to_rad(23.4393 - 3.563e-7 * days)
	var equatorial := Vector3(ecliptic.x,
			ecliptic.y * cos(obliquity) + ecliptic.z * sin(obliquity),
			-ecliptic.y * sin(obliquity) + ecliptic.z * cos(obliquity))
	var ra := rad_to_deg(atan2(equatorial.z, equatorial.x))
	var dec := rad_to_deg(atan2(equatorial.y,
			sqrt(equatorial.x * equatorial.x + equatorial.z * equatorial.z)))
	return equatorial_direction(ra, dec, jd, latitude, longitude)

static func moon_illuminated_fraction(utc: Dictionary, latitude: float,
		longitude: float) -> float:
	# JPL defines lunar illumination through the Sun-target-observer phase
	# geometry. At Earth scale the apparent Sun/Moon elongation supplies the
	# rendering fraction: conjunction is new (0), opposition is full (1).
	var sun := sun_direction(utc, latitude, longitude)
	var moon := moon_direction(utc, latitude, longitude)
	return clampf((1.0 - sun.dot(moon)) * 0.5, 0.0, 1.0)

static func star_direction(ra_degrees: float, dec_degrees: float,
		utc: Dictionary, latitude: float, longitude: float) -> Vector3:
	return equatorial_direction(ra_degrees, dec_degrees, julian_day(utc),
			latitude, longitude)

static func equatorial_axes(utc: Dictionary, latitude: float,
		longitude: float) -> PackedVector3Array:
	# World-space directions of J2000 equatorial +X (RA 0), +Y (RA 90)
	# and +Z (north celestial pole). Dotting a horizon direction against
	# these axes recovers its inertial equatorial vector for all-sky maps.
	var jd := julian_day(utc)
	return PackedVector3Array([
		equatorial_direction(0.0, 0.0, jd, latitude, longitude),
		equatorial_direction(90.0, 0.0, jd, latitude, longitude),
		equatorial_direction(0.0, 90.0, jd, latitude, longitude),
	])

static func equatorial_direction(ra_degrees: float, dec_degrees: float,
		jd: float, latitude: float, longitude: float) -> Vector3:
	var hour_angle := deg_to_rad(fposmod(greenwich_sidereal_degrees(jd)
			+ longitude - ra_degrees + 180.0, 360.0) - 180.0)
	var lat := deg_to_rad(latitude)
	var dec := deg_to_rad(dec_degrees)
	var east := -cos(dec) * sin(hour_angle)
	var north := sin(dec) * cos(lat) - cos(dec) * cos(hour_angle) * sin(lat)
	var up := sin(dec) * sin(lat) + cos(dec) * cos(hour_angle) * cos(lat)
	return Vector3(east, up, -north).normalized()

static func altitude_degrees(direction: Vector3) -> float:
	return rad_to_deg(asin(clampf(direction.normalized().y, -1.0, 1.0)))
