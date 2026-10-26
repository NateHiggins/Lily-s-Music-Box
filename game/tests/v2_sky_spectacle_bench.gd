extends Node3D
## Optical review bench for the sky spectacle; no completion claim. It walks the
## year's schedule (data/weather/phenomena.json): for each phenomenon the campaign
## clock jumps to its first dated occurrence, the production WeatherManager picks
## it up and forces its weather, the V2 director lights the sky from the real
## ephemeris, and the lens is aimed by the bearing or the sun. One frame each,
## over the real V2 city horizon (St. Elmo's fire sits on its chimney caps).
##
##   SHOT_DIR=<abs> [SPECTACLE_ONLY=id,id] godot --path game res://tests/V2SkySpectacleBench.tscn

const Manager := preload("res://scripts/building/WeatherManager.gd")
const Phenomena := preload("res://scripts/building/sky_phenomena.gd")
const EYE := Vector3(0.0, 22.0, 0.0)
@export var queens_renderer := true
## id -> [aim, pitch degrees, fov, yaw offset]. aim: bearing | sun | sun_az | anti | anti_az | tip
const SHOTS := {
	"mammatus": ["bearing", 28.0, 80.0, 0.0], "shelf_cloud": ["bearing", 6.0, 85.0, 0.0],
	"wall_cloud": ["bearing", 7.0, 70.0, 0.0], "lenticular": ["bearing", 13.0, 60.0, 0.0],
	"morning_glory": ["bearing", 8.0, 85.0, 0.0], "virga": ["bearing", 12.0, 75.0, 0.0],
	"microburst": ["bearing", 7.0, 75.0, 0.0], "haboob": ["bearing", 6.0, 85.0, 0.0],
	"asperitas": ["bearing", 55.0, 90.0, 0.0], "kelvin_helmholtz": ["bearing", 15.0, 70.0, 0.0],
	"fallstreak_hole": ["bearing", 18.0, 75.0, 0.0], "striated_supercell": ["bearing", 10.0, 85.0, 0.0],
	"anvil_cumulonimbus": ["bearing", 14.0, 75.0, 0.0], "overshooting_top": ["bearing", 22.0, 50.0, 0.0],
	"pileus": ["bearing", 16.0, 60.0, 0.0], "pyrocumulonimbus": ["bearing", 15.0, 75.0, 0.0],
	"tornado": ["bearing", 6.0, 60.0, 0.0], "waterspout": ["bearing", 5.0, 55.0, 0.0],
	"nacreous": ["sun_az", 10.0, 80.0, 0.0], "noctilucent": ["sun_az", 12.0, 85.0, 0.0],
	"aurora": ["bearing", 18.0, 90.0, 0.0], "steve": ["bearing", 58.0, 95.0, 0.0],
	"spider_lightning": ["bearing", 35.0, 90.0, 0.0], "red_sprite": ["bearing", 8.0, 45.0, 0.0],
	"blue_jet": ["bearing", 6.0, 40.0, 0.0], "gigantic_jet": ["bearing", 10.0, 50.0, 0.0],
	"elves": ["bearing", 10.0, 60.0, 0.0], "st_elmos_fire": ["tip", 0.0, 9.0, 0.0],
	"volcanic_lightning": ["bearing", 15.0, 75.0, 0.0], "rainbow": ["anti_az", 20.0, 100.0, 0.0],
	"halo_22": ["sun", 0.0, 75.0, 0.0], "sun_dogs": ["sun", 0.0, 75.0, 0.0],
	"circumhorizontal_arc": ["sun_az", 26.0, 85.0, 0.0], "circumzenithal_arc": ["sun_az", 68.0, 85.0, 0.0],
	"light_pillars": ["sun_az", 6.0, 40.0, 0.0], "crepuscular_rays": ["sun_az", 12.0, 95.0, 0.0],
	"anticrepuscular_rays": ["anti_az", 10.0, 95.0, 0.0], "glory": ["anti", 0.0, 30.0, 0.0],
	"iridescence": ["sun", 0.0, 60.0, 0.0], "green_flash": ["sun", 0.0, 6.0, 0.0],
	"fata_morgana": ["bearing", 3.5, 28.0, 0.0],
}
var sky_material: ShaderMaterial
var manager: Node
var director: DayNightDirector
var clock: CampaignClock
var camera: Camera3D
var horizon: Node3D
var environment: Environment
var flashing := false


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	clock = CampaignClock.new()
	clock.configure_date(1928, 11, 10, 720)
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.volumetric_fog_enabled = true
	environment.volumetric_fog_density = .0001
	environment.volumetric_fog_length = 24.0
	sky_material = ShaderMaterial.new()
	sky_material.shader = preload("res://shaders/queens_weather_sky.gdshader") if queens_renderer else preload("res://shaders/v2_seasonal_sky.gdshader")
	sky_material.set_shader_parameter("moon_surface", load("res://assets/environment/lroc_color_poles_1k.jpg"))
	environment.sky = Sky.new()
	environment.sky.sky_material = sky_material
	environment.sky.radiance_size = Sky.RADIANCE_SIZE_128
	environment.sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	var key := DirectionalLight3D.new()
	add_child(key)
	horizon = preload("res://scripts/building/orison_v2_city_horizon.gd").new()
	add_child(horizon)
	director = preload("res://scripts/building/v2_city_day_night_director.gd").new()
	add_child(director)
	director.setup(self, environment, key, sky_material)
	var observer := Node3D.new()
	add_child(observer)
	observer.global_position = EYE - Vector3(0, 1.6, 0)
	var effects := preload("res://scripts/building/v2_weather_fx.gd").new()
	effects.setup(observer, Callable(effects, "exposed"), Callable(effects, "covered"))
	add_child(effects)
	director.bind_weather(effects)
	manager = Manager.new()
	manager.configure(clock, director, sky_material, effects)
	add_child(manager)
	camera = Camera3D.new()
	add_child(camera)
	camera.make_current()
	camera.global_position = EYE
	get_viewport().use_taa = true
	await get_tree().process_frame
	if OS.get_environment("SKY_VORTEX_REVIEW")=="1":
		await _vortex_review()
		return
	if OS.get_environment("SKY_MOTION_REVIEW")=="1":
		await _motion_review()
		return
	if OS.get_environment("SKY_BRUSH_REVIEW")=="1":
		await _brush_review()
		return
	if OS.get_environment("SKY_CYCLONE_REVIEW")=="1":
		await _cyclone_review()
		return
	if OS.get_environment("SKY_LIBRARY_VIEWER")=="1":
		_library_viewer()
		return
	if OS.get_environment("SKY_LIBRARY_YEAR")=="1":
		await _library_year()
		return
	var only := OS.get_environment("SPECTACLE_ONLY").split(",", false)
	var saved := 0
	for slot in Phenomena.SLOTS:
		var id: String = manager.schedule.ids_by_slot[slot]
		if not only.is_empty() and id not in only: continue
		var entry: Dictionary = {}
		for candidate: Dictionary in manager.schedule.occurrences:
			if candidate.id == id: entry = candidate; break
		if id == "haboob":
			# The wall approaching, then the street inside it.
			await _shoot(id, entry, .1, "%02d_%s_approach" % [slot, id])
			saved += 1
		await _shoot(id, entry, .5, "%02d_%s" % [slot, id])
		saved += 1
	print("V2 SKY SPECTACLE BENCH: %d frames" % saved)
	get_tree().quit(0)


## Development-only calendar viewer and compact annual gallery. Uses the same
## production manager/shader and real city horizon, not the full occupied world.
func _library_date(day_index: int,hour: float) -> void:
	var start:=Time.get_unix_time_from_datetime_string("1928-11-10T00:00:00")
	var date:=Time.get_datetime_dict_from_unix_time(start+day_index*86400)
	clock.configure_date(int(date.year),int(date.month),int(date.day),int(hour*60))
	manager._calendar_check_left=0.0;manager._phenomena_left=0.0;manager._publish_left=0.0
	manager._process(1.0);manager._publish()
	if manager.extreme_weather!=null:manager.extreme_weather.publish(sky_material,camera.global_position)
	director._apply(clock.minute_of_day())
	camera.fov=85
	camera.look_at(EYE+Vector3(-1,.42,-.3))

func _library_viewer() -> void:
	manager.set_process(false)
	var panel:=VBoxContainer.new();panel.position=Vector2(18,18);panel.custom_minimum_size=Vector2(430,0)
	add_child(panel)
	var label:=Label.new();panel.add_child(label)
	var day:=HSlider.new();day.max_value=364;day.step=1;panel.add_child(day)
	var hour:=HSlider.new();hour.max_value=23.99;hour.step=.05;hour.value=12;panel.add_child(hour)
	var seed_label:=Label.new();seed_label.text="Layout seed (same calendar weather)";panel.add_child(seed_label)
	var seed_control:=SpinBox.new();seed_control.max_value=65520;seed_control.value=manager._seed_value();panel.add_child(seed_control)
	var update:=func(_value: float):
		OS.set_environment("WEATHER_SEED",str(int(seed_control.value)))
		_library_date(int(day.value),hour.value)
		label.text="%s | %s | %s\nDay / hour — development preview"%[clock.datetime_string(),manager.atmosphere_state.regime,manager.atmosphere_state.scenario_label]
	day.value_changed.connect(update);hour.value_changed.connect(update);seed_control.value_changed.connect(update)
	update.call(0.0)

## Real production weather publication at fractional campaign time, stationary
## camera and fixed jitter. Counts are uploaded states, not wall-time FPS.
func _motion_review() -> void:
	manager.set_process(false);director.set_process(false)
	var directory:=OS.get_environment("SHOT_DIR");DirAccess.make_dir_recursive_absolute(directory)
	var rows: Array[Dictionary]=[];var failures: Array[String]=[]
	var sources: Dictionary={}
	for path: String in ["res://shaders/queens_weather_sky.gdshader","res://shaders/queens_weather_math.gdshaderinc","res://shaders/queens_weather_air.gdshader"]:
		sources[path]=FileAccess.get_file_as_string(path).replace("\r\n","\n").sha256_text()
	for day_index: int in [0,210,300,362]:
		_library_date(day_index,12.0)
		var frames: Array=[];var previous:=Time.get_ticks_usec()
		for frame in 360:
			clock.advance_seconds(1.0/60.0)
			var before:=Time.get_ticks_usec();manager._process(1.0/60.0)
			var publication_ms:=(Time.get_ticks_usec()-before)/1000.0
			sky_material.set_shader_parameter("temporal_phase",0.0)
			await RenderingServer.frame_post_draw
			var now:=Time.get_ticks_usec()
			var motion: Vector4=sky_material.get_shader_parameter("living_motion_0")
			var wind: Vector3=sky_material.get_shader_parameter("wind_offset")
			var phase:=PackedFloat32Array([float(sky_material.get_shader_parameter("wx_phase"))])[0]
			var drift_value: Variant=sky_material.get_shader_parameter("wx_cloud_drift")
			var drift: Vector4=drift_value if drift_value is Vector4 else Vector4.ZERO
			var cycle_value: Variant=sky_material.get_shader_parameter("wx_cyclone_phase")
			var cycle:=PackedFloat32Array([float(cycle_value) if cycle_value is float else 0.0])[0]
			frames.append([clock.absolute_minutes(),(now-previous)/1000.0,publication_ms,motion.x,motion.y,motion.z,wind.x,wind.z,phase,drift.x,drift.y,cycle])
			previous=now
			if frame in [0,359]:
				var name:="motion_day_%03d_%03d.png"%[day_index,frame]
				if get_viewport().get_texture().get_image().save_png(directory.path_join(name))!=OK:failures.append("capture "+name)
		rows.append({"date":clock.datetime_string(),"day":day_index,"samples":frames})
	for path: String in sources:
		if FileAccess.get_file_as_string(path).replace("\r\n","\n").sha256_text()!=sources[path]:failures.append("source changed during motion review: "+path)
	FileAccess.open(directory.path_join("motion_review.json"),FileAccess.WRITE).store_string(JSON.stringify({
		"evidence_class":"INERT","scope":"stationary production weather bench, 360 fractional-clock frames at each of four dates; uploaded-state cadence, not occupied-world or input qualification",
		"columns":["absolute_minutes","wall_ms","publication_ms","low_motion_x","low_motion_y","low_evolution","wind_x","wind_z","phase_float32","storm_noise_x","storm_noise_z","cyclone_phase_float32"],"dates":rows,"failures":failures,"shader_sources":sources,"test_sha256":FileAccess.get_sha256(get_script().resource_path)},"\t"))
	print("CLOUD MOTION REVIEW: %d dates, %d failures"%[rows.size(),failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

## Matched production funnel/root views and a no-funnel control. No input capture.
func _vortex_review() -> void:
	manager.set_process(false);director.set_process(false)
	var entry: Dictionary={}
	for candidate: Dictionary in manager.schedule.occurrences:
		if candidate.id=="tornado":entry=candidate;break
	var directory:=OS.get_environment("SHOT_DIR");DirAccess.make_dir_recursive_absolute(directory)
	var sources: Dictionary={};var failures: Array[String]=[];var rows: Array[Dictionary]=[]
	for path: String in ["res://shaders/queens_weather_sky.gdshader","res://shaders/queens_weather_math.gdshaderinc"]:
		sources[path]=FileAccess.get_file_as_string(path).replace("\r\n","\n").sha256_text()
	if entry.is_empty():push_error("missing scheduled tornado");get_tree().quit(1);return
	await _shoot("tornado",entry,.5,"vortex_setup")
	var original_pose:=camera.global_transform
	var center: Vector2=sky_material.get_shader_parameter("wx_vortex_center")
	var root:=Vector3(center.x*1000.0,1100.0,center.y*1000.0)
	var intensity:=float(sky_material.get_shader_parameter("vortex_intensity"))
	if intensity<.9:failures.append("scheduled funnel not fully active")
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
	var variants: Dictionary={"production":sky_material.shader}
	var baseline:=OS.get_environment("SKY_VORTEX_BASELINE")
	if not baseline.is_empty():
		var baseline_code:=FileAccess.get_file_as_string(baseline)
		if baseline_code.is_empty():push_error("missing original geometry shader");get_tree().quit(1);return
		sources[baseline]=baseline_code.replace("\r\n","\n").sha256_text()
		var original:=Shader.new();original.code=baseline_code
		variants={"baseline":original,"production":sky_material.shader}
	var parameters: Dictionary={}
	for uniform: Dictionary in sky_material.shader.get_shader_uniform_list():
		var value: Variant=sky_material.get_shader_parameter(str(uniform.name))
		if value!=null:parameters[str(uniform.name)]=value
	for variant: String in variants:
		sky_material.shader=variants[variant]
		for key: String in parameters:sky_material.set_shader_parameter(key,parameters[key])
		for view: String in ["wide","root","side","control"]:
			camera.global_transform=original_pose;camera.fov=60.0
			if view!="wide":
				if view=="side":camera.global_position+=root.cross(Vector3.UP).normalized()*center.length()*200.0
				camera.look_at(root);camera.fov=24.0
			sky_material.set_shader_parameter("wx_camera_km",camera.global_position*.001)
			sky_material.set_shader_parameter("vortex_intensity",0.0 if view=="control" else intensity)
			sky_material.set_shader_parameter("temporal_phase",0.0)
			for frame in 48:await RenderingServer.frame_post_draw
			var times: Array=[]
			for frame in 64:
				await RenderingServer.frame_post_draw
				times.append([RenderingServer.viewport_get_measured_render_time_cpu(get_viewport().get_viewport_rid()),RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid())])
			var name:="vortex_%s_%s.png"%[variant,view]
			if get_viewport().get_texture().get_image().save_png(directory.path_join(name))!=OK:failures.append("capture "+name)
			rows.append({"variant":variant,"view":view,"file":name,"camera":str(camera.global_transform),"fov":camera.fov,"render_cpu_gpu_ms":times})
	for path: String in sources:
		if FileAccess.get_file_as_string(path).replace("\r\n","\n").sha256_text()!=sources[path]:failures.append("source changed: "+path)
	FileAccess.open(directory.path_join("vortex_review.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"scheduled tornado optical and isolated viewport cost review, four fixed views; not occupied gameplay, input or final art acceptance","samples":rows,"failures":failures,"date":clock.datetime_string(),"shader_sources":sources,"test_sha256":FileAccess.get_sha256(get_script().resource_path)},"\t"))
	print("VORTEX REVIEW: %d views, %d failures"%[rows.size(),failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

## Date-owned composition with diagnostic stratum masks. No player or mouse
## capture is instantiated here; this is optical review, not gameplay proof.
func _brush_review() -> void:
	manager.set_process(false);director.set_process(false)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
	var directory:=OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(directory)
	var rows: Array[Dictionary]=[];var failures: Array[String]=[]
	var sources: Dictionary={}
	for path: String in ["res://shaders/queens_weather_sky.gdshader","res://shaders/queens_weather_math.gdshaderinc"]:
		sources[path]=FileAccess.get_file_as_string(path).replace("\r\n","\n").sha256_text()
	for day_index: int in [0,120,210,300]:
		_library_date(day_index,_daylight_hours(day_index)[2])
		sky_material.set_shader_parameter("temporal_phase",0.0)
		var layers: Array[Vector4]=[]
		for band in 3:layers.append(sky_material.get_shader_parameter("living_layer_%d"%band))
		for mask: String in ["all","low_mid","high"]:
			DisplayServer.window_set_title("Cloud brush review: day %d/365 · %s"%[day_index+1,mask])
			for band in 3:
				var layer: Vector4=layers[band]
				if (mask=="high" and band<2) or (mask=="low_mid" and band==2):layer.x=0.0
				sky_material.set_shader_parameter("living_layer_%d"%band,layer)
			for frame in 48:await RenderingServer.frame_post_draw
			var times: Array=[]
			for frame in 64:
				await RenderingServer.frame_post_draw
				times.append([RenderingServer.viewport_get_measured_render_time_cpu(get_viewport().get_viewport_rid()),RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid())])
			var name:="brush_day_%03d_%s.png"%[day_index,mask]
			if get_viewport().get_texture().get_image().save_png(directory.path_join(name))!=OK:failures.append("capture "+name)
			rows.append({"date":clock.datetime_string(),"mask":mask,"state":manager.atmosphere_state.duplicate(true),"file":name,"render_cpu_gpu_ms":times})
	for path: String in sources:
		if FileAccess.get_file_as_string(path).replace("\r\n","\n").sha256_text()!=sources[path]:failures.append("source changed during review: "+path)
	FileAccess.open(directory.path_join("brush_review.json"),FileAccess.WRITE).store_string(JSON.stringify({
		"evidence_class":"INERT","scope":"calendar-owned city-horizon optical bench, diagnostic layer masks and 64 settled render samples per view; no occupied-world performance or input qualification",
		"samples":rows,"failures":failures,"shader_sources":sources,"test_sha256":FileAccess.get_sha256(get_script().resource_path)},"\t"))
	print("CLOUD BRUSH REVIEW: %d views, %d failures"%[rows.size(),failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

## Isolate the production warp from all other storm shading. The control uses
## the same shader/parameters, with only the coordinate warp replaced by identity.
## This is an optical diagnostic, not a substitute for an occupied-world route.
func _cyclone_review() -> void:
	manager.set_process(false);director.set_process(false)
	_library_date(362,12.0) # November 7, 1929: an actual authored coastal storm.
	manager.extreme_weather.publish(sky_material,camera.global_position)
	sky_material.set_shader_parameter("temporal_phase",0.0)
	var directory:=OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(directory)
	var code: String=sky_material.shader.code
	var math_code:=FileAccess.get_file_as_string("res://shaders/queens_weather_math.gdshaderinc")
	var control_math:=math_code.replace("float angle=weight*","float angle=0.0*weight*")
	var control_code:=code.replace('#include "res://shaders/queens_weather_math.gdshaderinc"',control_math)
	var failures: Array[String]=[]
	if control_math==math_code or control_code==code:failures.append("could not isolate cyclone coordinate warp")
	var control:=sky_material.duplicate() as ShaderMaterial
	var control_shader:=Shader.new();control_shader.code=control_code;control.shader=control_shader
	for uniform: Dictionary in sky_material.shader.get_shader_uniform_list():
		control.set_shader_parameter(str(uniform.name),sky_material.get_shader_parameter(str(uniform.name)))
	var cyclone:=float(sky_material.get_shader_parameter("wx_cyclone"))
	var wind: Vector3=sky_material.get_shader_parameter("wind_offset")
	if cyclone<=.1 or wind.length()<1000.0:failures.append("fixture must have authored cyclone and accumulated year-scale wind")
	var views: Array[Dictionary]=[]
	for pitch: float in [.24,.75]:
		camera.look_at(EYE+Vector3(-1,pitch,-.3))
		var images: Array[Image]=[]
		for material: ShaderMaterial in [control,sky_material]:
			environment.sky.sky_material=material
			for frame in 80:await RenderingServer.frame_post_draw
			var capture:=get_viewport().get_texture().get_image()
			var name:="cyclone_%s_%s.png"%[str(pitch),"production" if material==sky_material else "identity"]
			if capture.save_png(directory.path_join(name))!=OK:failures.append("capture "+name)
			images.append(capture)
		var error_sum:=0.0;var changed:=0;var count:=0
		for y in range(0,images[0].get_height()*2/3,4):
			for x in range(0,images[0].get_width(),4):
				var a:=images[0].get_pixel(x,y);var b:=images[1].get_pixel(x,y)
				var difference:=maxf(absf(a.r-b.r),maxf(absf(a.g-b.g),absf(a.b-b.b)))
				error_sum+=difference;count+=1
				if difference>.01:changed+=1
		views.append({"pitch":pitch,"mean_max_channel_difference":error_sum/count,"fraction_changed_over_01":float(changed)/count})
	FileAccess.open(directory.path_join("cyclone_review.json"),FileAccess.WRITE).store_string(JSON.stringify({
		"evidence_class":"INERT","scope":"production cloud density versus identity coordinate-warp control, same authored storm and year-scale transport; no gameplay performance or runtime qualification",
		"date":clock.datetime_string(),"cyclone":cyclone,"wind_km":[wind.x,wind.y,wind.z],"views":views,"failures":failures,
		"shader_sha256":FileAccess.get_sha256("res://shaders/queens_weather_sky.gdshader")},"\t"))
	print("CYCLONE OPTICAL REVIEW: %d views, %d failures"%[views.size(),failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

func _library_year() -> void:
	manager.set_process(false)
	var directory:=OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(directory)
	# One row per day, six columns in solar order. Small review thumbnails keep
	# the full-year survey bounded; the interactive roof remains full resolution.
	var atlas:=Image.create(960,1440,false,Image.FORMAT_RGB8)
	var rows: Array[Dictionary]=[];var failures: Array[String]=[]
	var diversity: Dictionary={"genera":{},"arrangements":{},"regimes":{},"coverage_bins":{},"light_and_genus":{},"signatures":{}}
	var replay_states: Dictionary={}
	var labels: Array[String]=["dawn","morning","solar_noon","afternoon","dusk","night"]
	for day_index in 365:
		var hours:=_daylight_hours(day_index)
		var samples: Array[Dictionary]=[]
		if day_index%16==0:atlas.fill(Color(.025,.025,.025))
		for slot in hours.size():
			_library_date(day_index,hours[slot])
			sky_material.set_shader_parameter("temporal_phase",0.0)
			for frame in 24:await RenderingServer.frame_post_draw
			var image:=get_viewport().get_texture().get_image()
			image.resize(160,90,Image.INTERPOLATE_LANCZOS)
			atlas.blit_rect(image,Rect2i(0,0,160,90),Vector2i(slot*160,(day_index%16)*90))
			var state: Dictionary=manager.atmosphere_state.duplicate(true)
			var sun: Vector3=sky_material.get_shader_parameter("sun_direction")
			var features:=_composition_features(image)
			samples.append({"period":labels[slot],"date":clock.datetime_string(),"sun_elevation_degrees":rad_to_deg(asin(sun.y)),"state":state,"source":manager.source,"appearance":features})
			if manager.source!="campaign-calendar" or state.is_empty():failures.append("missing calendar atmosphere day %d %s"%[day_index,labels[slot]])
			if slot in [1,2,3] and sun.y<=0:failures.append("daylight sample below horizon day %d %s"%[day_index,labels[slot]])
			if slot==5 and sun.y>=0:failures.append("night sample above horizon day %d"%day_index)
			_tally(diversity.regimes,str(state.get("regime","")))
			_tally(diversity.coverage_bins,str(clampi(int(float(state.get("combined_coverage",0))*5),0,4)))
			_tally(diversity.signatures,str(features.signature))
			for layer: Dictionary in state.get("layers",[]):
				if float(layer.coverage)<=.03:continue
				_tally(diversity.genera,str(layer.genus));_tally(diversity.arrangements,str(layer.arrangement))
				_tally(diversity.light_and_genus,labels[slot]+":"+str(layer.genus))
			if day_index%30==0 and slot==2:replay_states[day_index]=state
		rows.append({"day":day_index,"hours":hours,"samples":samples})
		if day_index%16==15 or day_index==364:
			var path:=directory.path_join("year_%02d.png"%(day_index/16))
			if atlas.save_png(path)!=OK:failures.append("capture "+path)
			print("LIVING SKY GALLERY day %d/365"%(day_index+1))
	# Return in reverse order. Geometry state must not depend on traversal order,
	# scene uptime, the preceding day's weather, or how many frames were rendered.
	var replay_days: Array=replay_states.keys();replay_days.reverse()
	for day_index: int in replay_days:
		_library_date(day_index,_daylight_hours(day_index)[2])
		if manager.atmosphere_state!=replay_states[day_index]:failures.append("reverse-date field reconstruction day %d"%day_index)
	FileAccess.open(directory.path_join("annual_gallery.json"),FileAccess.WRITE).store_string(JSON.stringify({
		"evidence_class":"INERT","scope":"365 days, six solar-relative periods each, production sky over city-horizon bench; appearance signatures describe fixed upper-frame luminance, not a cloud segmentation or measured cloud-cover mask. No occupied-world save/rebuild, performance or human acceptance.",
		"seed":manager._seed_value(),"periods":labels,"samples":365*labels.size(),"reverse_date_replays":replay_days.size(),"calendar_sha256":FileAccess.get_sha256("res://data/weather/campaign_weather.json"),"diversity":diversity,"days":rows,"failures":failures},"\t"))
	print("LIVING SKY ANNUAL REVIEW: %d samples, %d reverse-date replays, %d failures"%[365*labels.size(),replay_days.size(),failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

func _daylight_hours(day_index: int) -> PackedFloat64Array:
	var civil:=Time.get_unix_time_from_datetime_string("1928-11-10T00:00:00")+day_index*86400
	var rise:=0.0;var setting:=24.0;var peak:=-1.0;var noon:=12.0;var previous:=-1.0
	for quarter in 97:
		var hour:=float(quarter)*.25
		var utc:=Time.get_datetime_dict_from_unix_time(civil+int(hour*3600)+300*60)
		var elevation:=CelestialEphemeris.sun_direction(utc,40.75,-73.92).y
		if quarter>0 and previous<=0 and elevation>0:rise=hour-.25+.25*(-previous)/(elevation-previous)
		if quarter>0 and previous>0 and elevation<=0:setting=hour-.25+.25*previous/(previous-elevation)
		if elevation>peak:peak=elevation;noon=hour
		previous=elevation
	var span:=setting-rise
	return PackedFloat64Array([maxf(0,rise-.25),rise+span*.18,noon,rise+span*.82,minf(23.99,setting+.25),23.0])

func _tally(table: Dictionary,key: String) -> void: table[key]=int(table.get(key,0))+1

func _composition_features(image: Image) -> Dictionary:
	var signature:=PackedByteArray();var mean:=Vector3.ZERO;var luminance:=0.0;var square:=0.0
	# Fixed upper two thirds, sampled sparsely. This is a reproducible image
	# descriptor; repeated overcast signatures are observations, never failures.
	for row in 8:
		for column in 16:
			var color:=image.get_pixel(column*10+5,row*7+3)
			var value:=color.get_luminance()
			mean+=Vector3(color.r,color.g,color.b);luminance+=value;square+=value*value
			signature.append(clampi(int(value*31),0,31))
	return {"mean_rgb":[mean.x/128,mean.y/128,mean.z/128],"luminance_stddev":sqrt(maxf(0,square/128-pow(luminance/128,2))),"signature":signature.hex_encode().sha256_text()}


func _shoot(id: String, entry: Dictionary, fraction: float, label: String) -> void:
	var minute := float(entry.start) + (float(entry.end) - float(entry.start)) * fraction
	var date := CampaignClock._date_from_ordinal(int(floor(minute / 1440.0)))
	clock.configure_date(int(date.year), int(date.month), int(date.day_of_month), int(fposmod(minute, 1440.0)))
	# The schedule decides; then settle the weather transition and the sky at once.
	manager._calendar_check_left=0.0;manager._phenomena_left=0.0;manager._publish_left=0.0
	manager._process(.016)
	manager.origin = manager.target.duplicate(true)
	manager.elapsed = Manager.TRANSITION_SECONDS
	manager._phenomena_left = 0.0
	manager._process(.016)
	manager._publish()
	director._apply(clock.minute_of_day())
	var row: Dictionary = manager.schedule.phenomena[id]
	flashing = bool(row.get("flash", false))
	_aim(id, entry)
	for frame in 40:
		if flashing: manager.trigger_flash()
		sky_material.set_shader_parameter("temporal_phase", float(frame))
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var active: Array = manager.active_phenomena.map(func(e): return e.id)
	print("  %s at %s %s, sun %.1f deg, active %s, levels %s, dust %.2f" % [label, entry.date,
			"%02d:%02d" % [int(fposmod(minute, 1440.0)) / 60, int(fposmod(minute, 60.0))],
			Phenomena.sun_elevation(minute), active,
			manager.active_phenomena.map(func(e): return snappedf(e.level, .01)),
			float(manager.current.get("dust", 0.0))])
	if id == "st_elmos_fire":
		var corona := horizon.find_child("StElmoCorona", true, false) as MultiMeshInstance3D
		print("  corona: visible %s, tips %d, first %s, aim %s, level %s" % [corona.visible,
				corona.multimesh.instance_count, corona.multimesh.get_instance_transform(0).origin,
				_nearest_corona_tip(), (corona.material_override as ShaderMaterial).get_shader_parameter("corona")])
	var directory := OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(directory)
	get_viewport().get_texture().get_image().save_png(directory.path_join(label + ".png"))
	var uniforms: Dictionary={}
	for item: Dictionary in sky_material.shader.get_shader_uniform_list():
		var value: Variant=sky_material.get_shader_parameter(str(item.name))
		if value is Resource:continue
		uniforms[str(item.name)]=value
	FileAccess.open(directory.path_join(label+".json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","date":clock.datetime_string(),"atmosphere":manager.atmosphere_state,"conditions":manager.current,"uniforms":uniforms},"\t"))


func _aim(id: String, entry: Dictionary) -> void:
	var shot: Array = SHOTS[id]
	camera.fov = float(shot[2])
	var sun: Vector3 = (sky_material.get_shader_parameter("sun_direction") as Vector3).normalized()
	var target: Vector3
	match str(shot[0]):
		"sun": target = sun
		"anti": target = -sun
		"sun_az", "anti_az":
			var flat := Vector3(sun.x, 0, sun.z).normalized() * (1.0 if str(shot[0]) == "sun_az" else -1.0)
			target = flat * cos(deg_to_rad(float(shot[1]))) + Vector3.UP * sin(deg_to_rad(float(shot[1])))
		"tip":
			target = _nearest_corona_tip() - EYE
		_:
			var bearing := float(entry.bearing) + deg_to_rad(float(shot[3]))
			var flat := Vector3(sin(bearing), 0, -cos(bearing))
			target = flat * cos(deg_to_rad(float(shot[1]))) + Vector3.UP * sin(deg_to_rad(float(shot[1])))
	camera.look_at(EYE + target.normalized() * 100.0, Vector3.UP if absf(target.normalized().y) < .98 else Vector3.FORWARD)


func _nearest_corona_tip() -> Vector3:
	var corona := horizon.find_child("StElmoCorona", true, false) as MultiMeshInstance3D
	var best := Vector3(0, 30, -200)
	var best_distance := INF
	for index in corona.multimesh.instance_count:
		var tip := corona.global_transform * corona.multimesh.get_instance_transform(index).origin
		var distance := tip.distance_to(EYE)
		if distance < best_distance and tip.y > EYE.y - 4.0:
			best = tip
			best_distance = distance
	return best
