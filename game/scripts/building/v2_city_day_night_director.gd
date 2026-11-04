extends "res://scripts/building/day_night_director.gd"
## V2's real neighbouring blocks extend past the retained V1 storm backdrop.
## The existing director remains the sole atmosphere and celestial authority.
const SkywatchAstronomy := preload("res://scripts/building/skywatch_astronomy.gd")
const StarGod := preload("res://scripts/building/star_god.gd")
const Weather := preload("res://scripts/building/WeatherManager.gd")
const StarGodLens := preload("res://scripts/building/star_god_lens.gd")
const CAMPAIGN_MIDNIGHT_UTC := "1928-11-10T05:00:00" # local midnight, EST
var _lens: CompositorEffect
var _star_god_live := false
var _astronomy_second := -INF
var _astronomy_observer := Vector2(INF,INF)
var _eclipse_transmission := 1.0
var _stellar_axes := PackedVector3Array()
var _skyward: Node3D
var _mirage: CompositorEffect

func setup(root: Node3D,env: Environment,sky_key: DirectionalLight3D,sky_mat: ShaderMaterial) -> void:
	super.setup(root,env,sky_key,sky_mat)
	if _sky!=null and _sky.shader!=null and _sky.shader.resource_path=="res://shaders/queens_weather_sky.gdshader" and OS.get_environment("WEATHER_SKY_BASELINE")!="1":
		_skyward=preload("res://scripts/building/skyward_traffic.gd").new()
		_skyward.name="SkywardTraffic";add_child(_skyward)
		_skyward.configure(root.global_transform)
		_mirage=preload("res://scripts/building/skywatch_mirage.gd").new()
		_lens=StarGodLens.new()

func set_mirage_spectacle(level: float,bearing: float,seconds: float) -> void:
	if _mirage!=null:_mirage.publish(level,bearing,seconds)

func _exit_tree() -> void:
	if _mirage!=null:_mirage.dispose();_mirage=null
	if _lens!=null:_lens.dispose();_lens=null

func _process(delta: float) -> void:
	super._process(delta)
	if _skyward!=null and _campaign_clock!=null:_skyward.update(_campaign_clock,_live_conditions)
	if _mirage!=null:_mirage.bind_camera(get_viewport().get_camera_3d())
	if _lens!=null:_lens.bind_camera(get_viewport().get_camera_3d())
	# The eclipse and the Star God move in seconds; relight every frame while they last.
	if _star_god_live and _sky!=null and _campaign_clock!=null:_apply(_minute_now())
	if _sky==null or _campaign_clock==null or not is_finite(_astronomy_observer.x):return
	if OS.get_environment("DAYNIGHT")=="0" or not OS.get_environment("DAYNIGHT_FORCE").is_empty():return
	var camera := get_viewport().get_camera_3d()
	SkywatchAstronomy.publish_star_frame(_sky,camera,_campaign_clock,_astronomy_observer)
	if camera==null or not bool(_sky.get_meta("analytical_stars",false)):return
	# Only telescope fields need sub-second orbital motion. Do not republish
	# ambient lighting, fog, weather, neighbours or residency here.
	if float(_sky.get_meta("stellar_camera_field",PI))<deg_to_rad(2.):
		var utc := SkywatchAstronomy.precise_utc(_campaign_clock)
		var sun := SkywatchAstronomy.Ephemeris.sun_direction(utc,_astronomy_observer.x,_astronomy_observer.y)
		var moon := SkywatchAstronomy.Ephemeris.moon_direction(utc,_astronomy_observer.x,_astronomy_observer.y)
		_publish_astronomy({"observer":_astronomy_observer})
		# Refraction as in the director, or the eyepiece Sun jumps by its lift.
		sun=SolarOptics.apparent_direction(sun)
		_sky.set_shader_parameter("sun_direction",sun)
		_sky.set_shader_parameter("celestial_direction",sun if sun.y>-.035 else moon)
		_sky.set_shader_parameter("moon_illumination",clampf((1.-sun.dot(moon))*.5,0.,1.))
		_sky.set_shader_parameter("moon_phase_enabled",sun.y<=-.035)

func _state_texture(state: String) -> Texture2D:
	if state!="night" or _sky==null or _sky.shader.resource_path!="res://shaders/queens_weather_sky.gdshader":
		return super._state_texture(state)
	# Keep the existing pair/residency owner, without loading a photograph whose
	# stars must no longer be sampled. Explicit baseline/Compatibility keep V1.
	var key: String=SKY_PATHS[state]
	if not _panoramas.has(key):
		var image := Image.create_empty(2,2,false,Image.FORMAT_RGB8)
		image.fill(Color(.001,.002,.004));image.generate_mipmaps()
		_panoramas[key]=ImageTexture.create_from_image(image)
	return _panoramas[key]

func _publish_ice_optics() -> void:
	if _sky==null or _sky.shader==null or _sky.shader.resource_path!="res://shaders/queens_weather_sky.gdshader":return
	_sky.set_shader_parameter("skywatch_extended_optics",true)
	var high := float(_live_conditions.get("cloud_high",0.0))
	var rain := float(_live_conditions.get("precipitation_intensity",0.0))
	var cold := 1.0-smoothstep(-4.0,2.0,float(_live_conditions.get("temperature_c",10.0)))
	var thin_ice := smoothstep(.18,.65,high)*(1.0-smoothstep(.88,1.0,high))*(1.0-smoothstep(.05,.4,rain))
	var frost := cold*smoothstep(.86,.98,float(_live_conditions.get("relative_humidity",.5)))
	_sky.set_shader_parameter("skywatch_ice_complex",Vector3(thin_ice*.35,thin_ice*cold*.24,frost*.45))
	for owner: Node in get_tree().get_nodes_in_group("v2_street_lamp_clocks"):
		owner.set_ice_level(frost)

func _publish_astronomy(profile: Dictionary) -> void:
	if _sky == null:
		return
	if _sky.shader == null or _sky.shader.resource_path != "res://shaders/queens_weather_sky.gdshader":
		return
	if _campaign_clock == null or not profile.has("observer"):
		var empty := PackedVector4Array();empty.resize(5)
		_sky.set_shader_parameter("skywatch_planets",empty)
		_sky.set_shader_parameter("moon_eclipse_shadow",Vector4.ZERO)
		_astronomy_second=-INF
		return
	var utc := SkywatchAstronomy.precise_utc(_campaign_clock)
	var second := SkywatchAstronomy.Ephemeris.julian_day(utc)*86400.
	var observer: Vector2 = profile.observer
	if second == _astronomy_second and observer==_astronomy_observer:
		profile["equatorial_axes"]=_stellar_axes
		if bool(profile.get("moon_phase_enabled",false)): profile.key_e *= _eclipse_transmission
		return
	_astronomy_second = second
	_astronomy_observer = observer
	var jd := SkywatchAstronomy.Ephemeris.julian_day(utc)
	_stellar_axes=PackedVector3Array([
		SkywatchAstronomy.horizon(Vector3.RIGHT,jd,observer.x,observer.y),
		SkywatchAstronomy.horizon(Vector3.UP,jd,observer.x,observer.y),
		SkywatchAstronomy.horizon(Vector3.BACK,jd,observer.x,observer.y)])
	profile["equatorial_axes"]=_stellar_axes
	_sky.set_shader_parameter("star_epoch_years",(jd-2425612.5)/365.25)
	_sky.set_shader_parameter("star_turbulence",clampf(float(_live_conditions.get("wind_speed_kmh",8.))/60.+.15,0.,1.))
	var eclipse := SkywatchAstronomy.lunar_eclipse(utc,observer.x,observer.y)
	_eclipse_transmission = float(eclipse.light_transmission)
	_sky.set_shader_parameter("moon_eclipse_shadow",eclipse.shadow)
	if bool(profile.get("moon_phase_enabled",false)):
		profile.key_e *= _eclipse_transmission
	var states := SkywatchAstronomy.planet_states(utc,observer.x,observer.y)
	var packed := PackedVector4Array()
	var solar := PackedVector3Array()
	var gains := [0.65,3.4,0.95,1.25,0.8]
	for i in range(states.size()):
		var state: Dictionary = states[i]
		var direction: Vector3 = state.direction
		# Solar proximity extinguishes the inner planets through twilight/smog.
		var contrast := smoothstep(deg_to_rad(6.),deg_to_rad(20.),float(state.elongation))
		packed.append(Vector4(direction.x,direction.y,direction.z,float(gains[i])*contrast))
		solar.append(state.sun_direction)
	_sky.set_shader_parameter("skywatch_planets",packed)
	_sky.set_shader_parameter("skywatch_planet_suns",solar)
	_sky.set_shader_parameter("skywatch_seconds",fposmod(second,3600.))

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
	_publish_ice_optics()
	_publish_astronomy(profile)
	_publish_star_god(profile)
	var distances := city_visibility(_live_conditions)
	profile.fog_begin = distances.x
	profile.fog_end = distances.y
	# Depth density is an opacity ceiling, not an extinction rate. Keep the
	# distant ground seam fully extinguished; weather controls physical range.
	profile.fog_d = 1.0
	_env.volumetric_fog_enabled=bool(_env.get_meta("outdoor_weather_active",false)) or bool(_env.get_meta("carried_lamp_volume_active",false))
	if extreme_weather!=null:
		var span:=_span_at(_last_minute)
		var fallback:=_source_direction(span.a.elevation,span.a.azimuth).slerp(_source_direction(span.b.elevation,span.b.azimuth),float(span.t)).normalized()
		if _last_minute<=360.0 or _last_minute>=1110.0:fallback=-fallback
		var sun: Vector3=profile.get("sun_direction",fallback)
		var light: Dictionary=extreme_weather.lighting(profile.key,profile.key_e,profile.ambient,profile.ambient_e,sun)
		profile.key=light.sun_color;profile.key_e=light.sun_energy
		profile.ambient=light.ambient_color;profile.ambient_e=light.ambient_energy
		_env.adjustment_enabled=true;_env.adjustment_saturation=float(light.saturation)
		var whiteout:=smoothstep(.60,1.0,float(extreme_weather.weights.z))
		var storm:=maxf(float(extreme_weather.cyclone),float(extreme_weather.threat)*.65)
		var fog: Color=profile.fog
		profile.fog=fog.lerp(Color(.17,.20,.24),storm*.70).lerp(Color(.78,.83,.88),whiteout)
		profile.fog_begin=lerpf(float(profile.fog_begin),2.0,whiteout)
		profile.fog_end=lerpf(float(profile.fog_end),24.0,whiteout)
	# The Corona ash wall closes the street in sepia, the coal smog's own colour.
	var dust := clampf(float(_live_conditions.get("dust", 0.0)), 0.0, 1.0)
	if dust > 0.0:
		profile.fog = (profile.fog as Color).lerp(Color(.46, .33, .19), dust * .85)
		profile.fog_begin = lerpf(profile.fog_begin, 4.0, dust)
		profile.fog_end = lerpf(profile.fog_end, 45.0, dust)
		profile.key_e *= 1.0 - dust * .7


## Minutes since local midnight on the campaign's first day, to the second.
func _campaign_minute() -> float:
	var utc := SkywatchAstronomy.precise_utc(_campaign_clock)
	var unix := Time.get_unix_time_from_datetime_dict(utc) + fposmod(float(utc.get("second", 0.0)), 1.0)
	return (unix - Time.get_unix_time_from_datetime_string(CAMPAIGN_MIDNIGHT_UTC)) / 60.0

## The Moon by day all year, and on 1 November 1929 the eclipse and the Star God
## (star_god.gd). Dims the light by the share of the Sun still showing.
func _publish_star_god(profile: Dictionary) -> void:
	if _sky == null or _sky.shader == null or _sky.shader.resource_path != "res://shaders/queens_weather_sky.gdshader":
		return
	if _campaign_clock == null or not profile.has("sun_direction") or not profile.has("moon_direction"):
		_star_god_live = false
		_sky.set_shader_parameter("moon_by_day", 0.0)
		_sky.set_shader_parameter("eclipse_active", 0.0)
		return
	var sun: Vector3 = profile.sun_direction
	var moon: Vector3 = profile.moon_direction
	var minute := _campaign_minute()
	var moon_radius := 0.2666 * Weather.moon_scale(minute * 60.0)
	var event := StarGod.state(minute, moon_radius)
	_star_god_live = bool(event.active) or float(event.afterglow) > 0.0 and float(event.afterglow) < 1.0
	# The disc frame the sky shader uses for the Sun: x across, y up.
	var across := Vector3.UP.cross(sun)
	across = Vector3.RIGHT if across.length() < 0.0001 else across.normalized()
	var upward := sun.cross(across).normalized()
	var sun_radius := deg_to_rad(StarGod.SUN_RADIUS_DEG)
	if bool(event.active):
		var offset: Vector2 = event.offset
		var angle := offset.length() * sun_radius
		var toward := (across * offset.x + upward * offset.y).normalized() if offset.length() > 0.0 else across
		moon = (sun * cos(angle) + toward * sin(angle)).normalized()
		var shown := float(event.visible)
		profile.key_e *= shown
		profile.ambient_e *= lerpf(0.04, 1.0, sqrt(shown))
		profile["star_strength"] = maxf(float(profile.get("star_strength", 0.0)), float(event.totality) * 0.55)
		profile["sky_exposure_scale"] = lerpf(0.06, 1.0, sqrt(shown))
	_sky.set_shader_parameter("moon_direction", moon)
	_sky.set_shader_parameter("moon_by_day", 1.0 if sun.y > -0.035 and moon.y > -0.05 else 0.0)
	_sky.set_shader_parameter("eclipse_active", 1.0 if bool(event.active) else 0.0)
	_sky.set_shader_parameter("eclipse_offset", event.offset)
	_sky.set_shader_parameter("eclipse_moon_radius", float(event.moon_radius))
	_sky.set_shader_parameter("eclipse_corona", float(event.corona))
	_sky.set_shader_parameter("eclipse_beads", float(event.beads))
	_sky.set_shader_parameter("star_god_ripple", float(event.ripple))
	_sky.set_shader_parameter("star_god_rift", float(event.rift))
	_sky.set_shader_parameter("star_god_afterglow", float(event.afterglow))
	_sky.set_shader_parameter("sun_eye", float(event.eye))
	if float(event.eye) > 0.0:
		_sky.set_shader_parameter("sun_spots", _eye_spots(float(event.eye)))
	# The figure grows out of the Sun on the side away from the Moon, then climbs.
	var away := -(across * float((event.offset as Vector2).x) + upward * float((event.offset as Vector2).y))
	away = away.normalized() if away.length() > 0.0 else upward
	var size := deg_to_rad(1.5 + 9.0 * float(event.entity))
	var centre := (sun + away * sin(size * 0.9)).normalized()
	var high := Vector3(sun.x, 0.0, sun.z).normalized() * cos(deg_to_rad(42.0)) + Vector3.UP * sin(deg_to_rad(42.0))
	centre = centre.slerp(high, float(event.ascent)).normalized()
	_sky.set_shader_parameter("star_god_entity", float(event.entity))
	_sky.set_shader_parameter("star_god_line", float(event.line))
	_sky.set_shader_parameter("star_god_centre", centre)
	_sky.set_shader_parameter("star_god_size", size)
	if _lens != null:
		var einstein := deg_to_rad(2.2) * float(event.ascent) * (1.0 - float(event.line))
		_lens.publish_lens(einstein, centre, float(event.shock) * 2.6)

## Phase A: the day's spots drift together into an eye: a pupil and the lids.
func _eye_spots(amount: float) -> PackedVector4Array:
	var eye := PackedVector4Array([Vector4(0.0, 0.0, 0.11, 1.0)])
	for i in 7:
		var a := TAU * float(i) / 7.0
		eye.append(Vector4(0.55 * cos(a), 0.24 * sin(a), 0.035, 1.0))
	var today := SolarSurface.spots(SkywatchAstronomy.Ephemeris.julian_day(SkywatchAstronomy.precise_utc(_campaign_clock)))
	var mixed := PackedVector4Array()
	for i in 8:
		var from: Vector4 = today[i] if i < today.size() else Vector4(eye[i].x, eye[i].y, 0.0, 0.0)
		mixed.append(from.lerp(eye[i], clampf(amount, 0.0, 1.0)))
	return mixed
