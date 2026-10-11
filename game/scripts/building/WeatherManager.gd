extends Node
## NYC observations are presentation input; CampaignClock owns date and sun.
signal conditions_changed(conditions: Dictionary)
const Service := preload("res://scripts/building/live_weather_service.gd")
const CloudNoise := preload("res://scripts/building/weather_noise.gd")
const TRANSITION_SECONDS := 300.0
const MEAN_F := [33.7,35.9,42.8,53.7,63.2,72.0,77.5,76.1,69.2,57.9,48.0,39.1]
const FIELDS := ["temperature_c","relative_humidity","cloud_total","cloud_low","cloud_mid","cloud_high","wind_speed_kmh","wind_gusts_kmh","precipitation_intensity","rain_intensity","snow_intensity"]
var provider: LiveWeatherService
var current: Dictionary = {}
var target: Dictionary = {}
var origin: Dictionary = {}
var elapsed := TRANSITION_SECONDS
var source := "seasonal-fallback"
var last_error := ""
var clock: CampaignClock
var director: DayNightDirector
var sky: ShaderMaterial
var effects: WeatherFX
var _publish_left := 0.0
var _day := ""
var _shape_age := 900.0
var _shape := 0
var _wind_offset := Vector3.ZERO
var _before_taa := false
var _owns_taa := false
var _frame := 0

func configure(owner_clock: CampaignClock, owner_director: DayNightDirector,
		material: ShaderMaterial, owner_effects: WeatherFX = null) -> void:
	clock=owner_clock; director=owner_director; sky=material; effects=owner_effects
	current=Service.presentation(seasonal_snapshot(clock.local_datetime()))
	target=current.duplicate(true); origin=current.duplicate(true)

func _ready() -> void:
	if clock == null or sky == null: set_process(false); return
	if RenderingServer.get_current_rendering_method() == "forward_plus":
		sky.set_shader_parameter("cloud_noise",CloudNoise.load_volume())
		sky.set_shader_parameter("cirrus_tex",load("res://assets/environment/weather/cirrus.png"))
		_before_taa=get_viewport().use_taa
		if bool(GameBoot.settings.get("weather_taa_enabled",true)):
			get_viewport().use_taa=true; _owns_taa=true
	provider=Service.new(); provider.name="LiveWeatherService"
	provider.weather_updated.connect(receive_snapshot)
	provider.weather_failed.connect(_fallback)
	add_child(provider)
	_publish()

func _exit_tree() -> void:
	if _owns_taa and is_instance_valid(get_viewport()): get_viewport().use_taa=_before_taa

static func seasonal_snapshot(date: Dictionary) -> Dictionary:
	var month := clampi(int(date.get("month",11)),1,12)
	var season := season_weights(month,int(date.get("day",date.get("day_of_month",15))))
	var cover := season.dot(Vector4(.75,.47,.38,.24))
	return {"source":"nyc-seasonal-idealized","observed_at":"campaign-season",
		"location":Service.QUEENS.duplicate(true),"weather_code":3 if cover>.7 else 2,
		"temperature_c":(MEAN_F[month-1]-32.0)*5.0/9.0,"relative_humidity":season.dot(Vector4(68,63,73,52)),
		"cloud_total":cover,"cloud_low":cover*season.dot(Vector4(1,.75,.75,.20)),
		"cloud_mid":cover*.45,"cloud_high":cover*season.dot(Vector4(.12,.20,.17,1.0)),
		"wind_speed_kmh":season.dot(Vector4(9,22,12,24)),"wind_direction_degrees":285.0,
		"wind_gusts_kmh":28.0,"precipitation_mm":0.0,"rain_mm":0.0,"showers_mm":0.0,"snowfall_cm":0.0}

static func season_weights(month: int, day: int = 15) -> Vector4:
	# Calendar art direction changes gradually over the shoulders of each season.
	var value := fposmod(float(month)-1.0+clampf(float(day-1)/31.0,0.0,1.0),12.0)/3.0
	var primary := int(floor(value))%4
	var next := (primary+1)%4
	var weight := smoothstep(.66,1.0,fposmod(value,1.0))
	var result := Vector4.ZERO
	result[primary]=1.0-weight; result[next]=weight
	return result

static func interpolate(a: Dictionary, b: Dictionary, progress: float) -> Dictionary:
	var weight := smoothstep(0.0,1.0,clampf(progress,0.0,1.0))
	var result: Dictionary = (a if weight<.5 else b).duplicate(true)
	for key: String in FIELDS: result[key]=lerpf(float(a.get(key,0)),float(b.get(key,0)),weight)
	result.wind_direction_degrees=fposmod(rad_to_deg(lerp_angle(deg_to_rad(float(a.get("wind_direction_degrees",0))),deg_to_rad(float(b.get("wind_direction_degrees",0))),weight)),360.0)
	return result

func receive_snapshot(snapshot: Dictionary) -> void:
	var presentation := Service.presentation(snapshot)
	if presentation.is_empty(): _fallback("empty weather observation"); return
	origin=current.duplicate(true); target=presentation; elapsed=0.0
	source=str(snapshot.get("source","unknown")); last_error=""

func _fallback(reason: String) -> void:
	receive_snapshot(seasonal_snapshot(clock.local_datetime()))
	last_error=reason

static func shape_for_day(identity: String, seed_value: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed=hash(identity+":"+str(seed_value))
	return rng.randi_range(1,3) if rng.randf()<.01 else 0

func _process(delta: float) -> void:
	elapsed=minf(TRANSITION_SECONDS,elapsed+delta)
	current=interpolate(origin,target,elapsed/TRANSITION_SECONDS)
	var date := clock.local_datetime()
	var identity := "%04d-%02d-%02d" % [date.get("year",1928),date.get("month",11),date.get("day",date.get("day_of_month",10))]
	if identity != _day:
		_day=identity
		if source.begins_with("nyc-seasonal") or source=="seasonal-fallback":
			receive_snapshot(seasonal_snapshot(date))
		var seed_value := int(OS.get_environment("WEATHER_SEED")) if OS.get_environment("WEATHER_SEED").is_valid_int() else 1928
		_shape=shape_for_day(identity,seed_value); _shape_age=0.0
		var forced := OS.get_environment("WEATHER_CLOUD_SHAPE")
		if forced in ["duck","whale","ship"]: _shape=["duck","whale","ship"].find(forced)+1
	_shape_age+=delta
	var bearing := deg_to_rad(float(current.get("wind_direction_degrees",0)))
	var wind_direction := Vector3(-sin(bearing),0,cos(bearing))
	# km, accumulated rather than TIME*speed: new observations cannot jump clouds.
	_wind_offset+=wind_direction*float(current.get("wind_speed_kmh",0))/3600.0*delta
	if RenderingServer.get_current_rendering_method()=="forward_plus":
		_frame=(_frame+1)%128
		sky.set_shader_parameter("temporal_phase",float(_frame) if get_viewport().use_taa else 0.0)
		sky.set_shader_parameter("wind_offset",_wind_offset)
		sky.set_shader_parameter("shape_kind",_shape)
		sky.set_shader_parameter("shape_opacity",smoothstep(0,90,_shape_age)*(1.0-smoothstep(720,900,_shape_age)))
		if effects!=null and effects.get("air_material")!=null:
			effects.air_material.set_shader_parameter("wind_offset",_wind_offset)
	_publish_left-=delta
	if _publish_left<=0.0: _publish_left=1.0; _publish()

func _publish() -> void:
	var date := clock.local_datetime()
	var weights := season_weights(int(date.get("month",11)),int(date.get("day",date.get("day_of_month",15))))
	current["season_weights"]=weights
	director.set_live_conditions(current)
	if effects != null: effects.set_live_conditions(current)
	if RenderingServer.get_current_rendering_method()=="forward_plus":
		sky.set_shader_parameter("season_weights",weights)
		sky.set_shader_parameter("humidity",float(current.get("relative_humidity",.5)))
		sky.set_shader_parameter("storm_strength",float(current.get("precipitation_intensity",0)))
	conditions_changed.emit(current.duplicate(true))

