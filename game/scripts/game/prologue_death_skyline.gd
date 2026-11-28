extends Node
## Five seconds of the skyline at the moment Adela dies (Lily 2026-11-28). A
## bounded presentation clip inside the waking shot: the sky, weather and city
## windows are projected for her `lives_until` minute through a detached,
## read-only clock, exactly as the temporal sky does, and everything is
## restored before `finished`. It never writes campaign, weather or save state,
## and it never moves, poses or schedules Adela.
signal finished(completed: bool)
const DURATION := 5.0
const TemporalSky := preload("res://scripts/game/prologue_temporal_sky.gd")
const Living := preload("res://scripts/building/living_sky.gd")
const Calendar := preload("res://scripts/game/campaign_weather.gd")
const Weather := preload("res://scripts/building/WeatherManager.gd")
const Astronomy := preload("res://scripts/building/skywatch_astronomy.gd")
const SCHEDULES := "res://data/resident_schedules.json"

var active := false
var age := 0.0
var failure := ""
var moment_utc := 0.0
var camera: Camera3D
var view_clock := TemporalSky.RenderClock.new()
var _world: Node3D
var _director: Node
var _manager: Node
var _old_camera: Camera3D
var _old_clock: CampaignClock
var _old_conditions := {}
var _old_extreme
var _old_mode := Node.PROCESS_MODE_INHERIT
var _old_parameters := {}
var _view_extreme
var _city: Node
var _far: Node
var _mid: Node
var _eye := Vector3.ZERO
var _veil: ColorRect
var _quiet := false
var _published := false
var _base_exposure := 1.0
const BRIGHTNESS := 2.1


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)


## Adela's last minute, from the resident schedule that ends her year.
static func death_utc() -> float:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SCHEDULES))
	# 1929 is before the Unix epoch, so the moment is negative; NAN means "not found".
	if data is not Dictionary:return NAN
	# She is staff: resident_schedules.json keys her record as staff/adela_voss.
	var found := _find_lives_until(data, "adela_voss")
	if found.is_empty():return NAN
	var midnight := float(Time.get_unix_time_from_datetime_string(str(found.date) + "T00:00:00"))
	# The year's clock keeps New York standard time (UTC-5), like the temporal sky.
	return midnight + 18000.0 + float(found.minute) * 60.0


static func _find_lives_until(value: Variant, resident: String) -> Dictionary:
	if value is Dictionary:
		var row := value as Dictionary
		if row.get("lives_until") is Dictionary and resident in [str(row.get("id", "")), str(row.get("resident_id", "")), str(row.get("resident", ""))]:
			return row.lives_until
		# A record keyed by the resident's id (staff/adela_voss).
		if row.get(resident) is Dictionary and (row[resident] as Dictionary).get("lives_until") is Dictionary:
			return row[resident].lives_until
		for child: Variant in row.values():
			var hit := _find_lives_until(child, resident)
			if not hit.is_empty():return hit
	elif value is Array:
		for child: Variant in value:
			var hit := _find_lives_until(child, resident)
			if not hit.is_empty():return hit
	return {}


func start(owner_world: Node3D) -> bool:
	if active or not is_instance_valid(owner_world):return _refuse("active or missing world")
	_world = owner_world
	_director = _world.get("day_night_director")
	var atmosphere := _world.get_node_or_null("WakingAtmosphere")
	if _director == null or atmosphere == null:return _refuse("missing day/night director or waking atmosphere")
	_manager = atmosphere.weather_manager
	if _manager == null or _manager.extreme_weather == null:return _refuse("missing weather owner")
	moment_utc = death_utc()
	if is_nan(moment_utc) or not view_clock.seek_utc(moment_utc):return _refuse("Adela's lives_until moment is not a valid year date")
	_old_camera = get_viewport().get_camera_3d()
	if _old_camera == null:return _refuse("no current camera")
	_old_clock = _director._campaign_clock
	_old_conditions = _director._live_conditions.duplicate(true)
	_old_extreme = _director.extreme_weather
	_view_extreme = preload("res://scripts/building/queens_weather_extension.gd").new()
	for uniform: Dictionary in _manager.sky.shader.get_shader_uniform_list():
		_old_parameters[str(uniform.name)] = _manager.sky.get_shader_parameter(uniform.name)
	_city = _world.get_node_or_null("CityShells")
	_far = _world.find_child("FarDistricts", true, false)
	_mid = _world.find_child("Midground", true, false)
	# The surveyed northwest roof station the temporal sky uses, at eye height.
	_eye = _world.adapter.root.to_global(Vector3(-11., 19.2702503 + 1.60, 6.))
	_old_mode = _world.process_mode
	_world.process_mode = Node.PROCESS_MODE_DISABLED
	_director._campaign_clock = view_clock
	_director.extreme_weather = _view_extreme
	camera = Camera3D.new();camera.name = "AdelaSkylineCamera";add_child(camera)
	# Dusk under the storm is near black at the game's own exposure; this shot
	# alone is lifted so the skyline reads (the world's environment is untouched).
	# The player camera has no environment of its own; the world's (from its
	# WorldEnvironment) is the one in use, so copy whichever applies.
	var source: Environment = _old_camera.environment if _old_camera.environment != null else _old_camera.get_world_3d().environment
	if source != null:
		camera.environment = source.duplicate()
		# Post-tonemap adjustment: auto exposure cannot adapt it back down.
		camera.environment.glow_enabled = true
		camera.environment.adjustment_enabled = true
		camera.environment.adjustment_brightness = BRIGHTNESS
		camera.environment.adjustment_contrast = 1.18
		camera.environment.adjustment_saturation = 1.1
	# The game's cameras expose through CameraAttributes, which override the
	# environment's value: lift this shot's own copy.
	_base_exposure = 1.0
	if _old_camera.attributes != null:
		camera.attributes = _old_camera.attributes.duplicate()
		_base_exposure = camera.attributes.exposure_multiplier * 2.6
		camera.attributes.exposure_multiplier = _base_exposure
	camera.cull_mask = _old_camera.cull_mask
	camera.near = _old_camera.near;camera.far = _old_camera.far;camera.keep_aspect = _old_camera.keep_aspect
	_quiet = bool(GameBoot.settings.get("reduce_flashing", false))
	var layer := CanvasLayer.new();layer.layer = 81;add_child(layer)
	_veil = ColorRect.new();layer.add_child(_veil);_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	active = true;age = 0.0;_published = false
	seek(0.0);camera.make_current();set_process(true)
	return true


func seek(seconds: float) -> void:
	if not active or not is_finite(seconds):return
	age = clampf(seconds, 0.0, DURATION)
	# Super-dramatic: low over the parapet, the lens slowly pushing in and
	# climbing toward the storm over Manhattan while the minute holds.
	var t := smoothstep(0.0, DURATION, age)
	var bearing := deg_to_rad(lerpf(318., 326., t))
	var toward := Vector3(sin(bearing), lerpf(.02, .16, t), -cos(bearing)).normalized()
	camera.global_transform = Transform3D(Basis.looking_at(toward, Vector3.UP), _eye + Vector3.DOWN * .35 + toward * lerpf(0., .6, t))
	camera.fov = lerpf(64., 46., t)
	# A white flash in and out (a slow fade under reduced flashing).
	var edge := .18 if not _quiet else .7
	var cover := 1.0 - smoothstep(0.0, edge, age) + smoothstep(DURATION - edge, DURATION, age)
	# One lightning strike over the city mid-shot (a slow swell when reduced).
	var strike := exp(-pow((age - 2.55) / .07, 2)) * .85 + exp(-pow((age - 2.8) / .05, 2)) * .5
	if _quiet:strike = .12 * sin(PI * smoothstep(1.5, 4.0, age))
	# The strike lights the storm and city from within, not a white sheet over them.
	_veil.color = Color(1, 1, 1, clampf(cover, 0, 1)) if not _quiet else Color(0, 0, 0, clampf(cover, 0, 1))
	if camera.environment != null:
		camera.environment.adjustment_brightness = BRIGHTNESS * (1.0 + strike * 1.4)
	if not _published:
		_published = true
		_publish()
	if age >= DURATION:_finish(true)


func _process(delta: float) -> void:
	if not active:return
	if not camera.is_current():_finish(false);return
	seek(age + maxf(delta, 0.0))


## The temporal sky's detached publication, for one fixed minute.
func _publish() -> void:
	var date := view_clock.local_datetime()
	var authored := Calendar.snapshot(date)
	var weather_sample: Dictionary = authored if not authored.is_empty() else Weather.seasonal_snapshot(date)
	var scheduled: Array[Dictionary] = _manager.schedule.active_at(view_clock.calendar_minutes())
	if not scheduled.is_empty():weather_sample = weather_sample.duplicate()
	var levels := PackedFloat32Array();levels.resize(Weather.Phenomena.SLOTS)
	var bearings := PackedFloat32Array();bearings.resize(Weather.Phenomena.SLOTS)
	for entry: Dictionary in scheduled:
		if entry.flash:continue
		levels[int(entry.slot)] = float(entry.level)
		bearings[int(entry.slot)] = float(entry.bearing)
		if float(entry.level) >= .8:weather_sample.merge(entry.weather, true)
	var conditions := Weather.Service.presentation(weather_sample)
	_manager.sky.set_shader_parameter("spectacle", levels)
	_manager.sky.set_shader_parameter("spectacle_bearing", bearings)
	_manager.sky.set_shader_parameter("spectacle_time", moment_utc - TemporalSky.State.LOOP_START_UTC)
	conditions.season_weights = Weather.season_weights(int(date.month), int(date.day))
	Living.publish(_manager.sky, Living.sample(date, conditions, _manager._seed_value()))
	var transport := Calendar.cloud_transport_at(moment_utc - 18000)
	_view_extreme.receive_conditions(conditions, Calendar.date_key(date), _manager._seed_value())
	_view_extreme.project_sky(moment_utc - 18000, transport)
	var parameters: Dictionary = _view_extreme.sky_parameters(camera.global_position)
	for parameter: String in parameters:_manager.sky.set_shader_parameter(parameter, parameters[parameter])
	var weather = _director._weather;var exterior = _director._exterior
	_director._weather = null;_director._exterior = null;_director._live_conditions = conditions
	_director._apply(view_clock.minute_of_day())
	_director._weather = weather;_director._exterior = exterior
	Astronomy.publish_star_frame(_manager.sky, camera, view_clock)
	_manager.sky.set_shader_parameter("season_weights", conditions.season_weights)
	_manager.sky.set_shader_parameter("humidity", float(conditions.relative_humidity))
	_manager.sky.set_shader_parameter("storm_strength", float(conditions.precipitation_intensity))
	if is_instance_valid(_city):_city.project_window_clock(view_clock)
	if is_instance_valid(_far):_far.project_clock(view_clock)
	if is_instance_valid(_mid):_mid.project_clock(view_clock)


func cancel() -> void:
	if active:_finish(false)


func _finish(completed: bool) -> void:
	if not active:return
	active = false;set_process(false)
	if is_instance_valid(_director):
		_director._campaign_clock = _old_clock;_director._live_conditions = _old_conditions;_director.extreme_weather = _old_extreme
		_director._apply(_old_clock.minute_of_day())
	if is_instance_valid(_old_clock):
		if is_instance_valid(_city):_city.project_window_clock(_old_clock)
		if is_instance_valid(_far):_far.project_clock(_old_clock)
		if is_instance_valid(_mid):_mid.project_clock(_old_clock)
	if is_instance_valid(_manager):
		for parameter: String in _old_parameters:_manager.sky.set_shader_parameter(parameter, _old_parameters[parameter])
	_old_parameters.clear();_view_extreme = null
	if is_instance_valid(camera):
		if camera.is_current() and is_instance_valid(_old_camera) and _old_camera.is_inside_tree():_old_camera.make_current()
		camera.queue_free()
	if is_instance_valid(_veil):_veil.get_parent().queue_free()
	if is_instance_valid(_world) and _world.process_mode == Node.PROCESS_MODE_DISABLED:_world.process_mode = _old_mode
	finished.emit(completed)


func _exit_tree() -> void:
	if active:_finish(false)


func _refuse(reason: String) -> bool:
	failure = reason
	push_warning("Adela skyline refused: " + reason)
	return false
