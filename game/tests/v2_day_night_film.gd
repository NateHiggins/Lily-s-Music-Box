extends "res://scripts/building/roof_weather_preview.gd"
## Offline optical film; INERT evidence, not a real-time benchmark or played route.
const FPS := 24
const SUBFRAMES := 2
const SIZE := Vector2i(1920, 1080)
const SOURCE_PATHS := [
	"res://tests/v2_day_night_film.gd", "res://tests/V2DayNightFilm.tscn",
	"res://scripts/building/roof_weather_preview.gd",
	"res://scripts/building/living_sky.gd",
	"res://scripts/building/queens_weather_extension.gd",
	"res://scripts/building/day_night_director.gd",
	"res://scripts/building/orison_v2_city_shells.gd",
	"res://scripts/building/orison_v2_city_horizon.gd",
	"res://scripts/building/orison_v2_city_far_districts.gd",
	"res://scripts/building/orison_v2_city_midground.gd",
	"res://scripts/building/orison_v2_street_lamps.gd",
	"res://shaders/queens_weather_sky.gdshader",
	"res://shaders/queens_weather_air.gdshader",
	"res://shaders/queens_weather_math.gdshaderinc",
	"res://shaders/sky_spectacle.gdshaderinc",
	"res://shaders/skywatch_planets.gdshaderinc",
	"res://shaders/skywatch_moon.gdshaderinc",
	"res://shaders/skywatch_stars.gdshaderinc",
	"res://shaders/skywatch_sun.gdshaderinc",
	"res://scripts/game/campaign_clock.gd",
	"res://scripts/game/campaign_weather.gd",
	"res://scripts/building/live_weather_service.gd",
	"res://data/weather/living_sky.json",
	"res://data/weather/campaign_weather.json",
]
var _film_dir := ""
var _failures: Array[String] = []
var _frame_rows: Array[Dictionary] = []
var _sources_before: Dictionary = {}
var _original_data: Dictionary
var _original_values := ""
var _original_settings: Dictionary
var _original_mode: GameBoot.LaunchMode
var _original_persistence := false
var _film_clock: Dictionary
var _encoder: Dictionary = {}
var _encoder_pid := -1
var _started_usec := 0
var _film_started_usec := 0
var _camera_original: Transform3D
var _start_minutes := 0.0
var _span_minutes := 1440.0
var _frame_count := 576
var _city: Node
var _far_city: Node
var _mid_city: Node

func _ready() -> void:
	_film_dir = OS.get_environment("SHOT_DIR")
	if _film_dir.is_empty() or DisplayServer.get_name() == "headless":
		push_error("SKY FILM requires a hidden native window and SHOT_DIR");get_tree().quit(2);return
	DirAccess.make_dir_recursive_absolute(_film_dir.path_join("native_samples"))
	_original_data = RealityState.data
	_original_values = JSON.stringify(_original_data, "", true, true)
	_original_settings = GameBoot.settings.duplicate(true)
	_original_mode = GameBoot.launch_mode
	_original_persistence = RealityState.persistence_enabled
	_sources_before = _source_hashes()
	_started_usec = Time.get_ticks_usec()
	var requested_frames := OS.get_environment("SKY_FILM_FRAMES")
	if not requested_frames.is_empty(): _frame_count = clampi(int(requested_frames), 2, 576)
	var requested_span := OS.get_environment("SKY_FILM_SPAN_MINUTES")
	if not requested_span.is_empty(): _span_minutes = clampf(float(requested_span), 1.0, 1440.0)
	# Existing accessibility preference, temporary in this isolated process.
	GameBoot.settings.reduce_flashing = true
	super._ready()

func _preview_ready() -> void:
	set_process(false);set_process_input(false);set_process_unhandled_input(false)
	_capture.call_deferred()

func _require(ok: bool, message: String) -> bool:
	if not ok:
		_failures.append(message)
		push_error("SKY FILM: " + message)
	return ok

func _capture() -> void:
	overlay.hide()
	set_exploration(false)
	# GameBoot can restore a saved window mode after command-line parsing.
	# Set the capture's native size here, after construction, without saving a setting.
	get_window().mode = Window.MODE_WINDOWED
	get_window().size = SIZE
	get_window().content_scale_size = Vector2i.ZERO
	for settle in 4: await RenderingServer.frame_post_draw
	_require(Vector2i(get_viewport().get_visible_rect().size) == SIZE, "actual viewport must be 1920x1080")
	_require(not RealityState.persistence_enabled, "preview must have disabled persistence")
	_require(manager.source == "campaign-calendar", "authored calendar weather required")
	_require(manager.clock == preview_clock and director._campaign_clock == preview_clock, "both optical owners use detached date")
	_require(world.campaign_clock != preview_clock, "gameplay clock must remain separate")
	_require(Engine.time_scale == 1.0, "unscaled engine time required")
	# Godot removes recognized engine flags from OS.get_cmdline_args(). Check
	# the actual clock step, not a command-line string that cannot be observed.
	_require(absf(get_process_delta_time()-1.0/48.0)<.000001, "actual process timestep requires --fixed-fps 48")
	for source in _sources_before:
		_require(_sources_before[source] != "MISSING" and not str(_sources_before[source]).is_empty(), "consumed source present: "+source)
	_film_clock = RealityState.data.campaign_clock.duplicate(true)
	# PreviewClock's calendar view is pure, but inherited day_info() also needs
	# a valid epoch seed. Seed only the detached copy from this isolated preview.
	preview_clock._state = _film_clock.duplicate(true)
	preview_clock._state.start_minute_of_day = 0
	preview_clock._state.elapsed_minutes = 0.0
	_city = world.get_node_or_null("CityShells")
	_far_city = world.get_node_or_null("FarDistricts")
	_mid_city = world.get_node_or_null("Midground")
	_require(_city != null and _far_city != null and _mid_city != null, "complete near/mid/far city required")
	if not _failures.is_empty(): await _finish();return
	# Borrow their existing read-only clock inputs; their own periodic refresh
	# must not overwrite the sampled window date between the two rendered frames.
	_city.set("_clock", preview_clock)
	_city.get_node("CityHorizon").set("_window_clock", preview_clock)
	_far_city.set("_clock", preview_clock)
	_mid_city.set("_clock", preview_clock)
	_camera_original = player.camera.transform
	player.camera.global_position += Vector3.UP * 4.0
	var eye := player.camera.global_position
	var base_forward := -player.camera.global_basis.z
	_start_minutes = float(CampaignClock._ordinal(1929,2,23)-CampaignClock._ordinal(1928,11,10))*1440.0+480.0
	_sample(0.0, eye, base_forward)
	var civil := preview_clock.day_info()
	_require(bool(civil.get("valid",false)) and int(civil.get("year",0)) == 1929
		and int(civil.get("month",0)) == 2 and int(civil.get("day_of_month",0)) == 23
		and is_equal_approx(float(civil.get("minute_of_day",-1.0)),480.0),
		"detached day_info agrees with 1929-02-23 08:00")
	if not _failures.is_empty(): await _finish();return
	# No startup or warmup image enters the encoder.
	for warmup in 60: await RenderingServer.frame_post_draw
	if not _start_encoder(): await _finish();return
	_film_started_usec = Time.get_ticks_usec()
	for index in _frame_count:
		var fraction := float(index)/float(_frame_count-1)
		_sample(fraction, eye, base_forward)
		for subframe in SUBFRAMES: await RenderingServer.frame_post_draw
		if not _require(absf(get_process_delta_time()-1.0/48.0)<.000001, "fixed timestep retained at frame %d" % index): break
		if not _require(OS.is_process_running(_encoder_pid), "encoder still running at frame %d" % index): break
		var picture := get_viewport().get_texture().get_image()
		if not _require(picture.get_size() == SIZE, "readback has the requested native dimensions"): break
		if index % maxi(1,int((_frame_count-1)/6)) == 0 or index == _frame_count-1:
			_require(picture.save_png(_film_dir.path_join("native_samples/frame_%04d.png" % index)) == OK, "native review sample saved")
		picture.convert(Image.FORMAT_RGB8)
		var bytes := picture.get_data()
		if not _require(bytes.size() == SIZE.x*SIZE.y*3, "packed RGB byte count"): break
		var channel: FileAccess = _encoder.stdio
		channel.store_buffer(bytes)
		if not _require(channel.get_error() == OK, "encoder pipe accepts complete frame"): break
		_frame_rows.append({
			"frame":index, "movie_seconds":float(index)/FPS, "date_local":preview_clock.local_datetime(),
			"date_utc":preview_clock.utc_datetime(), "day_info":preview_clock.day_info(), "calendar_minutes":preview_clock.calendar_minutes(),
			"engine_drawn_frames":Engine.get_frames_drawn(), "engine_process_frames":Engine.get_process_frames(),
			"engine_movie_delta_seconds":1.0/FPS, "subframes":SUBFRAMES,
			"engine_process_delta_seconds":get_process_delta_time(),
			"wall_elapsed_ms":(Time.get_ticks_usec()-_film_started_usec)/1000.0,
			"eye":_xyz(player.camera.global_position), "forward":_xyz(-player.camera.global_basis.z),
			"weather_source":manager.source, "weather_target":manager.target.duplicate(true),
			"atmosphere":manager.atmosphere_state.duplicate(true),
			"taa":get_viewport().use_taa
		})
		if index % 96 == 0: print("SKY FILM FRAME %d/%d" % [index,_frame_count-1])
	_require(_frame_rows.size() == _frame_count, "all requested movie frames captured")
	_require(RealityState.data.campaign_clock == _film_clock, "optical day leaves gameplay date unchanged")
	player.camera.transform = _camera_original
	await _finish()

func _sample(fraction: float, eye: Vector3, forward: Vector3) -> void:
	preview_clock.seek(_start_minutes+fraction*_span_minutes)
	var aim := forward.rotated(Vector3.UP, deg_to_rad(lerpf(-12.0,12.0,fraction)))
	player.camera.global_position = eye
	player.camera.look_at(eye+aim*100.0)
	refresh_weather()
	_city.call("project_window_clock", preview_clock)
	_far_city.call("project_clock", preview_clock)
	_mid_city.call("project_clock", preview_clock)
	# Their established diagnostic override feeds the same lamp-factor reader.
	for lamps in get_tree().get_nodes_in_group("v2_street_lamp_clocks"):
		lamps.set("clock_override", preview_clock.day_info())
		lamps.call("refresh")
	_mid_city.call("_follow_lamps")

func _start_encoder() -> bool:
	var python := OS.get_environment("SKY_FILM_PYTHON")
	var relay := OS.get_environment("SKY_FILM_ENCODER_RELAY")
	var ffmpeg := OS.get_environment("SKY_FILM_FFMPEG")
	if not _require(FileAccess.file_exists(python) and FileAccess.file_exists(relay) and FileAccess.file_exists(ffmpeg), "explicit Python/relay/ffmpeg paths exist"): return false
	var args := PackedStringArray([relay,"--ffmpeg",ffmpeg,"--out",_film_dir,
		"--width",str(SIZE.x),"--height",str(SIZE.y),"--fps",str(FPS),
		"--frames",str(_frame_count),"--deadline","1050","--drain","60"])
	_encoder = OS.execute_with_pipe(python,args,true)
	if not _require(_encoder.has("stdio") and _encoder.has("pid"), "encoder relay started with bounded watchdog"): return false
	_encoder_pid = int(_encoder.pid)
	return true

func _finish() -> void:
	if _encoder.has("stdio"):
		(_encoder.stdio as FileAccess).close() # EOF is essential, including an incomplete/failed film.
	if _encoder_pid > 0:
		var until := Time.get_ticks_msec()+75000
		while OS.is_process_running(_encoder_pid) and Time.get_ticks_msec() < until:
			await get_tree().process_frame
		if OS.is_process_running(_encoder_pid):
			_require(false,"encoder did not drain within 75 real seconds")
			OS.kill(_encoder_pid) # Owned relay has its independent parent/child watchdog too.
		else:
			_require(OS.get_process_exit_code(_encoder_pid) == 0,"encoder relay and ffmpeg completed successfully")
	if _encoder.has("stderr"): (_encoder.stderr as FileAccess).close()
	_encoder_pid = -1
	var after := _source_hashes()
	_require(after == _sources_before,"consumed source bytes unchanged during film")
	await retire_preview()
	GameBoot.settings = _original_settings.duplicate(true)
	_require(is_same(RealityState.data,_original_data) and JSON.stringify(RealityState.data,"",true,true) == _original_values, "original campaign reference and values restored")
	_require(RealityState.persistence_enabled == _original_persistence, "original persistence restored")
	_require(GameBoot.launch_mode == _original_mode and GameBoot.settings == _original_settings, "original launch mode and settings restored")
	var record := {
		"schema":1,"evidence_class":"INERT","status":"pass" if _failures.is_empty() else "fail",
		"scope":"Offline elevated optical day/night movie; no played route, real-time performance, full authority/save qualification, or artistic acceptance.",
		"expected_frames":_frame_count,"frames":_frame_rows.size(),"fps":FPS,"duration_seconds":float(_frame_count)/FPS,
		"dimensions":[SIZE.x,SIZE.y],"start_local":"1929-02-23 08:00","span_minutes":_span_minutes,
		"camera_offset_metres":[0,4,0],"pan_degrees":24,"residents_and_buildings_hidden":false,
		"inherited_preview_limits":"Resident agenda frozen; HUD and companion hidden by RoofWeatherPreview; physics/resident presence otherwise retained.",
		"clock_policy":"Detached calendar drives sky, astronomy and near/mid/far city windows/lamps. --fixed-fps48 and two renders/output make shader TIME and ordinary animation advance at movie24fps. Startup phase recorded, not reset.",
		"accessibility":"Existing reduce_flashing=true locally; restored after film. Silent MP4.",
		"startup_outputs":0,"warmup_frames":60,"runtime_wall_seconds":(Time.get_ticks_usec()-_started_usec)/1000000.0,
		"sources_before":_sources_before,"sources_after":after,"frame_clock":_frame_rows,"failures":_failures,
		"renderer":RenderingServer.get_current_rendering_method(),"driver":RenderingServer.get_current_rendering_driver_name(),"cmdline":OS.get_cmdline_args(),
		"engine":Engine.get_version_info(),"encoder_relay_sha256":FileAccess.get_sha256(OS.get_environment("SKY_FILM_ENCODER_RELAY"))
	}
	var record_file := FileAccess.open(_film_dir.path_join("capture.json"),FileAccess.WRITE)
	if record_file != null: record_file.store_string(JSON.stringify(record,"\t"))
	print("SKY FILM: ",record.status)
	get_tree().quit(0 if _failures.is_empty() else 1)

func _source_hashes() -> Dictionary:
	var result: Dictionary = {}
	for source in SOURCE_PATHS:
		result[source] = FileAccess.get_sha256(source) if FileAccess.file_exists(source) else "MISSING"
	return result

static func _xyz(vector: Vector3) -> Array: return [vector.x,vector.y,vector.z]

func _exit_tree() -> void:
	if _encoder.has("stdio"): (_encoder.stdio as FileAccess).close()
	# On normal exit _finish has already drained/reaped the child. On an
	# exceptional exit, EOF lets the independent relay perform bounded cleanup.
	if not _original_settings.is_empty(): GameBoot.settings = _original_settings.duplicate(true)
	super._exit_tree()
