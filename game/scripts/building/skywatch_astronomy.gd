extends RefCounted
## Pure presentation geometry. CampaignClock and the existing director own time
## and lighting. No wall clock, random stream, save state or gameplay actions.
const Ephemeris := preload("res://scripts/building/celestial_ephemeris.gd")
const PLANETS := ["mercury", "venus", "mars", "jupiter", "saturn"]

static func configure_starfield(material: ShaderMaterial) -> void:
	material.set_meta("analytical_stars",true)
	material.set_shader_parameter("star_headers",load("res://assets/environment/stars/bsc5_headers.res"))
	material.set_shader_parameter("star_points",load("res://assets/environment/stars/bsc5_points.res"))
	material.set_shader_parameter("star_properties",load("res://assets/environment/stars/bsc5_properties.res"))
	material.set_shader_parameter("skywatch_stars_enabled",true)

static func precise_utc(clock: CampaignClock) -> Dictionary:
	var utc := clock.utc_datetime()
	utc.second=float(utc.get("second",0))+fposmod(clock.absolute_minutes()*60.,1.)
	return utc

static func publish_star_frame(material: ShaderMaterial,camera: Camera3D,clock: CampaignClock,observer := Vector2(40.75,-73.92)) -> void:
	if material==null or camera==null or clock==null or not bool(material.get_meta("analytical_stars",false)):return
	# Campaign fractions preserve deterministic forward/backward/reload sampling.
	material.set_shader_parameter("star_animation_seconds",fposmod(clock.absolute_minutes()*60.,4096.))
	# The retained lighting cadence is eight seconds. At 0.1 degrees that
	# would jump hundreds of pixels: publish presentation geometry separately.
	var jd := Ephemeris.julian_day(precise_utc(clock))
	material.set_shader_parameter("equatorial_axis_x",horizon(Vector3.RIGHT,jd,observer.x,observer.y))
	material.set_shader_parameter("equatorial_axis_y",horizon(Vector3.UP,jd,observer.x,observer.y))
	material.set_shader_parameter("equatorial_axis_z",horizon(Vector3.BACK,jd,observer.x,observer.y))
	var projection := camera.get_camera_projection()
	var field := 2.*atan(1./absf(projection.y.y))
	if not is_equal_approx(float(material.get_meta("stellar_camera_field",0.)),field):
		material.set_meta("stellar_camera_field",field)
		material.set_shader_parameter("camera_fov",field)
# JPL SSD Table 1, fitted 1800–2050; each row is a,e,I,L,perihelion,node,
# followed by their rates per Julian century. Angles are degrees, lengths AU.
# https://ssd.jpl.nasa.gov/planets/approx_pos.html
const ELEMENTS := {
 "earth": [1.00000261,.01671123,-.00001531,100.46457166,102.93768193,0., .00000562,-.00004392,-.01294668,35999.37244981,.32327364,0.],
 "mercury": [.38709927,.20563593,7.00497902,252.25032350,77.45779628,48.33076593, .00000037,.00001906,-.00594749,149472.67411175,.16047689,-.12534081],
 "venus": [.72333566,.00677672,3.39467605,181.97909950,131.60246718,76.67984255, .00000390,-.00004107,-.00078890,58517.81538729,.00268329,-.27769418],
 "mars": [1.52371034,.09339410,1.84969142,-4.55343205,-23.94362959,49.55953891, .00001847,.00007882,-.00813131,19140.30268499,.44441088,-.29257343],
 "jupiter": [5.20288700,.04838624,1.30439695,34.39644051,14.72847983,100.47390909, -.00011607,-.00013253,-.00183714,3034.74612775,.21252668,.20469106],
 "saturn": [9.53667594,.05386179,2.48599187,49.95424423,92.59887831,113.66242448, -.00125060,-.00050991,.00193609,1222.49362201,-.41897216,-.28867794],
}

static func heliocentric(body: String, jd: float) -> Vector3:
	if not ELEMENTS.has(body): return Vector3.ZERO
	var row: Array = ELEMENTS[body]
	var t := (jd - Ephemeris.J2000) / 36525.0
	var a := float(row[0]) + float(row[6]) * t
	var e := float(row[1]) + float(row[7]) * t
	var inc := deg_to_rad(float(row[2]) + float(row[8]) * t)
	var peri := deg_to_rad(float(row[4]) + float(row[10]) * t)
	var node := deg_to_rad(float(row[5]) + float(row[11]) * t)
	var mean := deg_to_rad(wrapf(float(row[3]) + float(row[9]) * t - rad_to_deg(peri), -180., 180.))
	var eccentric := mean + e * sin(mean)
	for iteration in range(8):
		eccentric -= (eccentric - e * sin(eccentric) - mean) / (1. - e * cos(eccentric))
	var x := a * (cos(eccentric) - e)
	var y := a * sqrt(1. - e * e) * sin(eccentric)
	var w := peri - node
	return Vector3((cos(w)*cos(node)-sin(w)*sin(node)*cos(inc))*x + (-sin(w)*cos(node)-cos(w)*sin(node)*cos(inc))*y,
		(cos(w)*sin(node)+sin(w)*cos(node)*cos(inc))*x + (-sin(w)*sin(node)+cos(w)*cos(node)*cos(inc))*y,
		sin(w)*sin(inc)*x + cos(w)*sin(inc)*y)

static func equatorial_j2000(body: String, jd: float) -> Vector3:
	# Retard the planet by light travel time. Earth stays at observation time.
	var earth := heliocentric("earth", jd)
	var planet := retarded_heliocentric(body,jd,earth)
	return ecliptic_to_equatorial(planet-earth)

static func retarded_heliocentric(body: String,jd: float,earth: Vector3) -> Vector3:
	var planet := heliocentric(body, jd)
	return heliocentric(body,jd-planet.distance_to(earth)*.0057755183)

static func ecliptic_to_equatorial(geo: Vector3) -> Vector3:
	var eps := deg_to_rad(23.43928)
	return Vector3(geo.x, geo.y*cos(eps)-geo.z*sin(eps), geo.y*sin(eps)+geo.z*cos(eps))

static func precess_to_date(equatorial: Vector3, jd: float) -> Vector3:
	# IAU 1976 J2000 -> mean equator/equinox of date, matching mean sidereal time.
	# Vector3 here is conventional equatorial XYZ, not Godot horizon coordinates.
	var t := (jd-Ephemeris.J2000)/36525.
	var zeta := deg_to_rad((2306.2181*t+.30188*t*t+.017998*t*t*t)/3600.)
	var z := deg_to_rad((2306.2181*t+1.09468*t*t+.018203*t*t*t)/3600.)
	var theta := deg_to_rad((2004.3109*t-.42665*t*t-.041833*t*t*t)/3600.)
	var n := equatorial.normalized()
	var ra := atan2(n.y,n.x)
	var dec := asin(clampf(n.z,-1.,1.))
	var a := cos(dec)*sin(ra+zeta)
	var b := cos(theta)*cos(dec)*cos(ra+zeta)-sin(theta)*sin(dec)
	var c := sin(theta)*cos(dec)*cos(ra+zeta)+cos(theta)*sin(dec)
	var out_ra := atan2(a,b)+z
	return Vector3(cos(out_ra)*sqrt(maxf(0.,1.-c*c)),sin(out_ra)*sqrt(maxf(0.,1.-c*c)),c)

static func horizon(equatorial_j2000_vector: Vector3, jd: float, latitude: float, longitude: float) -> Vector3:
	var n := precess_to_date(equatorial_j2000_vector,jd)
	return Ephemeris.equatorial_direction(rad_to_deg(atan2(n.y,n.x)),rad_to_deg(asin(clampf(n.z,-1.,1.))),jd,latitude,longitude)

static func planet_states(utc: Dictionary, latitude: float, longitude: float) -> Array[Dictionary]:
	var jd := Ephemeris.julian_day(utc)
	var earth := heliocentric("earth",jd)
	var result: Array[Dictionary] = []
	for body: String in PLANETS:
		var planet := retarded_heliocentric(body,jd,earth)
		var geo := planet-earth
		var phase_cos := clampf((-planet).normalized().dot((-geo).normalized()),-1.,1.)
		var elongation := acos(clampf(geo.normalized().dot((-earth).normalized()),-1.,1.))
		result.append({"body":body,"direction":horizon(equatorial_j2000(body,jd),jd,latitude,longitude),
			"sun_direction":horizon(ecliptic_to_equatorial(-planet),jd,latitude,longitude),
			"distance_au":geo.length(),"illumination":(1.+phase_cos)*.5,"elongation":elongation})
	return result

static func leonid_radiant(utc: Dictionary, latitude: float, longitude: float) -> Vector3:
	# Nominal J2000 shower radiant; precession prevents a one-degree epoch error.
	# This is not a measured individual meteor orbit or a claimed 1928 hourly rate.
	var ra := deg_to_rad(152.)
	var dec := deg_to_rad(22.)
	return horizon(Vector3(cos(dec)*cos(ra),cos(dec)*sin(ra),sin(dec)),Ephemeris.julian_day(utc),latitude,longitude)

static func lunar_eclipse(utc: Dictionary,latitude: float,longitude: float) -> Dictionary:
	# NASA/GSFC Espenak contact times are UT, not the catalogue's rounded TD.
	# Linear tangent-plane track fitted to P1/P4, greatest separation and radii.
	# This preserves measured contacts; it is not a new high-precision ephemeris.
	var date := "%04d-%02d-%02d" % [utc.year,utc.month,utc.day]
	var row: Array=[]
	if date=="1928-11-27": row=[6.*3600.+27.*60.,11.*3600.+35.*60.+45.,9.*3600.+60.+22.6,.4049,.2791667,.7670,1.3075,.3952,-.20]
	if date=="1929-05-23": row=[10.*3600.+20.*60.+29.,14.*3600.+54.*60.+10.,12.*3600.+37.*60.+20.7,.9657,.2470556,.6550,1.1814,-1.0650,.24]
	var none := {"shadow":Vector4.ZERO,"light_transmission":1.,"visible":false}
	if row.is_empty():return none
	var seconds := float(utc.get("hour",0))*3600.+float(utc.get("minute",0))*60.+float(utc.get("second",0))
	if seconds<float(row[0]) or seconds>float(row[1]):return none
	var half_duration := (float(row[1])-float(row[0]))*.5
	var impact := float(row[3]);var radius := float(row[4])
	var speed := sqrt(pow(float(row[6])+radius,2.)-impact*impact)/half_duration
	var track := Vector2(-cos(float(row[8])),sin(float(row[8])))
	var perpendicular := Vector2(-track.y,track.x)*signf(float(row[7]))
	var separation := track*((seconds-float(row[2]))*speed)+perpendicular*impact
	var moon := Ephemeris.moon_direction(utc,latitude,longitude)
	var pole := Ephemeris.equatorial_direction(0.,90.,Ephemeris.julian_day(utc),latitude,longitude)
	var north := (pole-moon*pole.dot(moon)).normalized()
	var east := north.cross(moon).normalized()
	var reference := Vector3.RIGHT if absf(moon.y)>.96 else Vector3.UP
	var right := reference.cross(moon).normalized();var up := moon.cross(right).normalized()
	var offset := -(east*separation.x+north*separation.y)/radius
	var shadow := Vector4(offset.dot(right),offset.dot(up),float(row[5])/radius,float(row[6])/radius)
	var umbra := 1.-smoothstep(float(row[5])-radius,float(row[5])+radius,separation.length())
	var visible := moon.y>0.
	return {"shadow":shadow,"light_transmission":lerpf(1.,.035,umbra) if visible else 1.,"visible":visible}
