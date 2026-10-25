extends Node
## NYC observations are presentation input; CampaignClock owns date and sun.
signal conditions_changed(conditions: Dictionary)
const Service := preload("res://scripts/building/live_weather_service.gd")
const CloudNoise := preload("res://scripts/building/weather_noise.gd")
const Calendar := preload("res://scripts/game/campaign_weather.gd")
const Phenomena := preload("res://scripts/building/sky_phenomena.gd")
const TLE_SLOTS := [23, 24, 25, 26]
const CRAWLER_SLOT := 22
const PLUME_LIGHTNING_SLOT := 28
const ST_ELMO_SLOT := 27
const MICROBURST_SLOT := 6
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
var extreme_weather: RefCounted
var _extreme_events: Dictionary={}
var _calendar_events: Dictionary={}
var _calendar_minute := ""
var _calendar_check_left := 0.0
## Spectacle: the dated year (data/weather/phenomena.json) plus seeded rolls.
var schedule := Phenomena.new()
var active_phenomena: Array[Dictionary] = []
var forced_phenomena: Dictionary = {}   # id -> {level, bearing}; benches and debug
var _phenomena_left := 0.0
var _spectacle_levels := PackedFloat32Array()
var _spectacle_bearings := PackedFloat32Array()
var _spectacle_time := 0.0
var _tle_frames := 0
var _tle_slot := -1
var _crawler := 0.0
var _crawler_wait := 4.0
var _plume_flash := 0.0
var _plume_wait := 3.0
var _corona := -1.0
var _flash_rng := RandomNumberGenerator.new()

func configure(owner_clock: CampaignClock, owner_director: DayNightDirector,
		material: ShaderMaterial, owner_effects: WeatherFX = null) -> void:
	clock=owner_clock; director=owner_director; sky=material; effects=owner_effects
	var authored := Calendar.snapshot(clock.local_datetime())
	current=Service.presentation(authored if not authored.is_empty() else seasonal_snapshot(clock.local_datetime()))
	source="campaign-calendar" if not authored.is_empty() else "seasonal-fallback"
	_calendar_events=Calendar.events(authored)
	target=current.duplicate(true); origin=current.duplicate(true)
	if RenderingServer.get_current_rendering_method()=="forward_plus" and OS.get_environment("WEATHER_SKY_BASELINE")!="1":
		extreme_weather=preload("res://scripts/building/queens_weather_extension.gd").new()
		director.set("extreme_weather",extreme_weather)
		if effects!=null:effects.set("extreme_weather",extreme_weather)
	_spectacle_levels.resize(Phenomena.SLOTS); _spectacle_bearings.resize(Phenomena.SLOTS)
	if not schedule.load_schedule(Phenomena.PATH, Callable(self,"_seasonal_for_date")):
		for problem in schedule.errors: push_error("sky phenomena: "+problem)
	_flash_rng.seed=hash("spectacle-flash:"+str(_seed_value()))
	if effects!=null and effects.has_signal("ground_strike"):
		effects.ground_strike.connect(_on_ground_strike)
	var forced_id := OS.get_environment("WEATHER_PHENOMENON")
	if schedule.phenomena.has(forced_id): force_phenomenon(forced_id,1.0)

func _ready() -> void:
	if clock == null or sky == null: set_process(false); return
	add_to_group("weather_manager")
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
	if extreme_weather!=null:RenderingServer.global_shader_parameter_set("wetness",0.0)
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
		"wind_gusts_kmh":28.0,"pressure_hpa":1024.0,"precipitation_mm":0.0,"rain_mm":0.0,"showers_mm":0.0,"snowfall_cm":0.0}

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
	var authored := Calendar.snapshot(clock.local_datetime())
	receive_snapshot(authored if not authored.is_empty() else seasonal_snapshot(clock.local_datetime()))
	_calendar_events=Calendar.events(authored)
	_calendar_minute=""
	last_error=reason

func _seasonal_for_date(date: String) -> Dictionary:
	var parts := date.split("-")
	return Service.presentation(seasonal_snapshot({"month":int(parts[1]),"day":int(parts[2])}))

func _seed_value() -> int:
	return int(OS.get_environment("WEATHER_SEED")) if OS.get_environment("WEATHER_SEED").is_valid_int() else 1928

static func shape_for_day(identity: String, seed_value: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed=hash(identity+":"+str(seed_value))
	return rng.randi_range(1,3) if rng.randf()<.01 else 0

func _process(delta: float) -> void:
	elapsed=minf(TRANSITION_SECONDS,elapsed+delta)
	current=interpolate(origin,target,elapsed/TRANSITION_SECONDS)
	var date := clock.local_datetime()
	_calendar_check_left-=delta
	if _calendar_check_left<=0.0:
		_calendar_check_left=1.0
		if source=="campaign-calendar" or source.begins_with("nyc-seasonal") or source=="seasonal-fallback":
			var minute_key:="%s:%s:%s"%[Calendar.date_key(date),date.get("hour",0),date.get("minute",0)]
			if minute_key!=_calendar_minute:
				_calendar_minute=minute_key
				var authored:=Calendar.snapshot(date)
				current=Service.presentation(authored if not authored.is_empty() else seasonal_snapshot(date))
				target=current.duplicate(true);origin=current.duplicate(true);elapsed=TRANSITION_SECONDS
				source="campaign-calendar" if not authored.is_empty() else "seasonal-fallback"
				_calendar_events=Calendar.events(authored)
	var identity := "%04d-%02d-%02d" % [date.get("year",1928),date.get("month",11),date.get("day",date.get("day_of_month",10))]
	if identity != _day:
		_day=identity
		if source.begins_with("nyc-seasonal") or source=="seasonal-fallback":
			receive_snapshot(seasonal_snapshot(date))
		_shape=shape_for_day(identity,_seed_value()); _shape_age=0.0
		var forced := OS.get_environment("WEATHER_CLOUD_SHAPE")
		if forced in ["duck","whale","ship"]: _shape=["duck","whale","ship"].find(forced)+1
	_shape_age+=delta
	_update_phenomena(delta)
	var bearing := deg_to_rad(float(current.get("wind_direction_degrees",0)))
	var wind_direction := Vector3(-sin(bearing),0,cos(bearing))
	# km, accumulated rather than TIME*speed: new observations cannot jump clouds.
	_wind_offset+=wind_direction*float(current.get("wind_speed_kmh",0))/3600.0*delta
	var animate:=true
	if extreme_weather!=null:
		animate=extreme_weather.advance(delta)
		if animate and effects!=null and is_instance_valid(effects._player):
			var camera:=get_viewport().get_camera_3d()
			extreme_weather.publish(sky,camera.global_position if camera!=null else effects._player.global_position,effects.get("air_material"))
	if RenderingServer.get_current_rendering_method()=="forward_plus" and animate:
		_frame=(_frame+1)%128
		sky.set_shader_parameter("temporal_phase",float(_frame) if get_viewport().use_taa else 0.0)
		sky.set_shader_parameter("wind_offset",_wind_offset)
		sky.set_shader_parameter("shape_kind",_shape)
		sky.set_shader_parameter("shape_opacity",smoothstep(0,90,_shape_age)*(1.0-smoothstep(720,900,_shape_age)))
		if effects!=null and effects.get("air_material")!=null:
			effects.air_material.set_shader_parameter("wind_offset",_wind_offset)
	_push_spectacle()
	_publish_left-=delta
	if _publish_left<=0.0: _publish_left=1.0; _publish()

func _publish() -> void:
	var date := clock.local_datetime()
	var weights := season_weights(int(date.get("month",11)),int(date.get("day",date.get("day_of_month",15))))
	current["season_weights"]=weights
	if extreme_weather!=null:
		var identity:="%04d-%02d-%02d"%[date.get("year",1928),date.get("month",11),date.get("day",date.get("day_of_month",10))]
		var seed_value:=int(OS.get_environment("WEATHER_SEED")) if OS.get_environment("WEATHER_SEED").is_valid_int() else 1928
		var events:=_calendar_events.duplicate(true) if source=="campaign-calendar" else {}
		events.merge(_extreme_events,true)
		extreme_weather.receive_conditions(current,identity,seed_value,events)
	director.set_live_conditions(current)
	if effects != null: effects.set_live_conditions(current)
	if RenderingServer.get_current_rendering_method()=="forward_plus":
		sky.set_shader_parameter("season_weights",weights)
		sky.set_shader_parameter("humidity",float(current.get("relative_humidity",.5)))
		sky.set_shader_parameter("storm_strength",float(current.get("precipitation_intensity",0)))
	conditions_changed.emit(current.duplicate(true))

func set_extreme_event(event: Dictionary) -> bool:
	# Authored coastal-storm/alert adapter. The existing weather owner remains
	# authoritative; arbitrary descriptions never become tornado forecasts.
	for key: Variant in event:
		if key not in ["hail","tornado","cyclone","severe_storm_threat"]:return false
		if typeof(event[key]) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(event[key])) or float(event[key])<0.0 or float(event[key])>1.0:return false
	_extreme_events=event.duplicate(true)
	return true


## --- spectacle ------------------------------------------------------------------

## Show a phenomenon regardless of the calendar (benches, debug). level 0 clears.
func force_phenomenon(id: String, level: float, bearing_degrees := -1.0) -> void:
	if level <= 0.0: forced_phenomena.erase(id); _phenomena_left = 0.0; return
	var bearing := deg_to_rad(bearing_degrees) if bearing_degrees >= 0.0 else -1.0
	if bearing < 0.0:
		for entry: Dictionary in schedule.occurrences:
			if entry.id == id: bearing = float(entry.bearing); break
	forced_phenomena[id] = {"level": level, "bearing": maxf(bearing, 0.0)}
	_phenomena_left = 0.0

func seasonal_mode() -> bool:
	return source=="campaign-calendar" or source.begins_with("nyc-seasonal") or source=="seasonal-fallback"

func _update_phenomena(delta: float) -> void:
	_spectacle_time+=delta
	_phenomena_left-=delta
	if _phenomena_left<=0.0:
		_phenomena_left=.25
		active_phenomena=_resolve_active()
	# Forced flags never outlive their event: start each frame from the target.
	current["dust"]=0.0
	for key: String in ["thunderstorm","wet","snowing","foggy","weather_code"]:
		if target.has(key): current[key]=target[key]
	# Scheduled weather owns the presentation while an event shows. Live
	# observations are never overwritten, only filtered (see _resolve_active).
	if seasonal_mode() or not forced_phenomena.is_empty():
		for entry: Dictionary in active_phenomena: _force_weather(entry)
	var listed: Array = []
	for entry: Dictionary in active_phenomena:
		listed.append({"id":entry.id,"label":entry.label,"family":entry.family,
			"level":entry.level,"bearing_degrees":rad_to_deg(entry.bearing)})
	current["phenomena"]=listed
	_update_flashes(delta)

func _resolve_active() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	if schedule.phenomena.is_empty(): return found
	var minute := clock.absolute_minutes()
	var date := clock.local_datetime()
	if is_finite(minute) and not date.is_empty():
		var rolled: Array = []
		if seasonal_mode():
			rolled=schedule.rolls_for(int(floor(minute/1440.0)),_seed_value(),
				Service.presentation(seasonal_snapshot(date)),Callable(self,"_ear_allows"))
		for entry: Dictionary in schedule.active_at(minute,rolled):
			# Live weather is the player's own sky: show only what it allows.
			if not seasonal_mode() and not Phenomena.unmet_requirements(schedule.phenomena[entry.id],current).is_empty():
				continue
			found.append(entry)
	for id: String in forced_phenomena:
		var row: Dictionary = schedule.phenomena[id]
		for index in range(found.size()-1,-1,-1):
			if found[index].id==id: found.remove_at(index)
		found.append({"id":id,"slot":int(row.slot),"family":str(row.family),"flash":bool(row.get("flash",false)),
			"level":float(forced_phenomena[id].level),"bearing":float(forced_phenomena[id].bearing),
			"weather":Phenomena.forcing(row,{}),"label":str(row.label)})
	return found

## A rolled day must agree with the weather the papers printed, when they are on the rack.
func _ear_allows(row: Dictionary, date: String) -> bool:
	var catalog := get_tree().get_first_node_in_group("newspaper_catalog") if is_inside_tree() else null
	if catalog == null or not catalog.has_issue(date): return true
	return Phenomena.ear_allows(row,str(catalog.issue("record",date).get("ear",""))+" "+str(catalog.issue("speaker",date).get("ear","")))

func _force_weather(entry: Dictionary) -> void:
	var weight := clampf(float(entry.level),0.0,1.0)
	var weather: Dictionary = entry.weather
	for key: String in weather:
		var value: Variant = weather[key]
		if value is bool:
			if weight>.35: current[key]=value
		elif key=="weather_code":
			if weight>.35: current[key]=int(value)
		elif key=="wind_direction_degrees":
			current[key]=fposmod(rad_to_deg(lerp_angle(deg_to_rad(float(current.get(key,0))),deg_to_rad(float(value)),weight)),360.0)
		else:
			current[key]=lerpf(float(current.get(key,0.0)),float(value),weight)

func _on_ground_strike(strength: float) -> void:
	# Transient luminous events ride the big ground strokes, one to three frames.
	var candidates: Array = []
	for entry: Dictionary in active_phenomena:
		if int(entry.slot) in TLE_SLOTS: candidates.append(int(entry.slot))
		if int(entry.slot)==CRAWLER_SLOT: _crawler=maxf(_crawler,strength)
	if not candidates.is_empty() and strength>.5:
		_tle_slot=candidates[_flash_rng.randi_range(0,candidates.size()-1)]
		_tle_frames=_flash_rng.randi_range(1,3)

## Benches: fire every flash phenomenon now, as a big ground stroke would.
func trigger_flash(frames := 3) -> void:
	_on_ground_strike(1.0)
	_tle_frames=frames
	_crawler=1.0
	_plume_flash=1.0

func _update_flashes(delta: float) -> void:
	var crawling := false; var plume := false
	for entry: Dictionary in active_phenomena:
		crawling=crawling or int(entry.slot)==CRAWLER_SLOT
		plume=plume or int(entry.slot)==PLUME_LIGHTNING_SLOT
	# Anvil crawlers also run on their own between ground strokes.
	if crawling:
		_crawler_wait-=delta
		if _crawler_wait<=0.0: _crawler_wait=_flash_rng.randf_range(3.0,9.0); _crawler=1.0
	if plume:
		_plume_wait-=delta
		if _plume_wait<=0.0: _plume_wait=_flash_rng.randf_range(2.0,6.0); _plume_flash=1.0
	_crawler*=exp(-delta/.35)
	_plume_flash*=exp(-delta/.18)

func _flash_for(slot: int) -> float:
	if slot==CRAWLER_SLOT: return _crawler
	if slot==PLUME_LIGHTNING_SLOT: return _plume_flash
	if slot in TLE_SLOTS: return 1.0 if slot==_tle_slot and _tle_frames>0 else 0.0
	return 1.0

func _push_spectacle() -> void:
	_spectacle_levels.fill(0.0)
	var corona := 0.0; var burst := 0.0
	for entry: Dictionary in active_phenomena:
		var slot := int(entry.slot)
		var level := float(entry.level)*(_flash_for(slot) if bool(entry.flash) else 1.0)
		_spectacle_levels[slot]=maxf(_spectacle_levels[slot],level)
		_spectacle_bearings[slot]=float(entry.bearing)
		if slot==ST_ELMO_SLOT: corona=float(entry.level)
		if slot==MICROBURST_SLOT: burst=float(entry.level)
	if _tle_frames>0: _tle_frames-=1
	if RenderingServer.get_current_rendering_method()=="forward_plus":
		sky.set_shader_parameter("spectacle",_spectacle_levels)
		sky.set_shader_parameter("spectacle_bearing",_spectacle_bearings)
		sky.set_shader_parameter("spectacle_time",_spectacle_time)
	if absf(corona-_corona)>.01 and is_inside_tree():
		_corona=corona
		get_tree().call_group("st_elmo_corona","set_corona",corona)
	if effects!=null and effects.has_method("set_burst"): effects.set_burst(burst)
