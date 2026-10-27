extends RefCounted
## Diagnostic optical/numerical bench using the production sky and director.
## Not an installed telescope interaction or campaign save/load qualification.
const Astronomy := preload("res://scripts/building/skywatch_astronomy.gd")
const Ephemeris := preload("res://scripts/building/celestial_ephemeris.gd")
var failures: Array[String] = []
var samples: Array[Dictionary] = []
var timings: Array[Dictionary] = []
var optical_geometry: Array[Dictionary] = []

func check(ok: bool,label: String) -> void:
	print("SKYWATCH %s: %s" % ["PASS" if ok else "FAIL",label])
	if not ok: failures.append(label)

func run(bench: Node3D) -> void:
	if OS.get_environment("SKYWATCH_CLOUD_REVIEW")=="1":
		await cloud_review(bench)
		return
	if OS.get_environment("SKYWATCH_MIRAGE_REVIEW")=="1":
		await mirage_review(bench)
		return
	if OS.get_environment("SKYWATCH_TRAFFIC_REVIEW")=="1":
		await traffic_review(bench)
		return
	if OS.get_environment("SKYWATCH_ATMOSPHERE_REVIEW")=="1":
		await atmosphere_review(bench)
		return
	if OS.get_environment("SKYWATCH_CATALOGUE_BAKE")=="1":
		catalogue_review(bench)
		return
	if OS.get_environment("SKYWATCH_STAR_REVIEW")=="1":
		await star_review(bench)
		return
	var out := OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(out)
	var reference: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/skywatch_planet_reference.json"))
	var months := {"Nov":11,"Mar":3,"Jul":7}
	for row: Dictionary in reference.rows:
		var stamp: PackedStringArray = str(row.utc).split(" ")[0].split("-")
		var utc := {"year":int(stamp[0]),"month":months[stamp[1]],"day":int(stamp[2])}
		var jd := Ephemeris.julian_day(utc)
		var actual := Astronomy.equatorial_j2000(str(row.body),jd).normalized()
		var ra := deg_to_rad(float(row.ra));var dec := deg_to_rad(float(row.dec))
		var expected := Vector3(cos(dec)*cos(ra),cos(dec)*sin(ra),sin(dec))
		var error := rad_to_deg(atan2(actual.cross(expected).length(),actual.dot(expected)))
		samples.append({"body":row.body,"utc":row.utc,"error_degrees":error})
		check(error<(.4 if row.body in ["jupiter","saturn"] else .08),"JPL independent %s %s error %.5f deg" % [row.body,row.utc,error])
	# Point at the celestial pole: altitude must equal observer latitude.
	var jd := Ephemeris.julian_day({"year":1929,"month":1,"day":15})
	var pole := Ephemeris.equatorial_direction(0.,90.,jd,40.75,-73.92)
	check(absf(Ephemeris.altitude_degrees(pole)-40.75)<.001,"local pole altitude equals Queens latitude")
	var utc := {"year":1928,"month":11,"day":17,"hour":8}
	var radiant := Astronomy.leonid_radiant(utc,40.75,-73.92)
	check(absf(radiant.length()-1.)<.000001 and radiant.y>0.,"Leonid radiant rises for the pre-dawn watch")
	check(Astronomy.planet_states(utc,40.75,-73.92)==Astronomy.planet_states(utc,40.75,-73.92),"out-of-order reconstruction needs no RNG or accumulated orbit state")
	var total := Astronomy.lunar_eclipse({"year":1928,"month":11,"day":27,"hour":9,"minute":1,"second":23},40.75,-73.92)
	check(bool(total.visible) and float(total.light_transmission)<.04,"NASA November total eclipse is visible and immersed in umbra")
	var before := Astronomy.lunar_eclipse({"year":1928,"month":11,"day":27,"hour":6,"minute":26},40.75,-73.92)
	check(before.shadow==Vector4.ZERO,"no eclipse before NASA P1 contact")
	var may := Astronomy.lunar_eclipse({"year":1929,"month":5,"day":23,"hour":12,"minute":37,"second":21},40.75,-73.92)
	check(not bool(may.visible) and float(may.light_transmission)==1.,"remote penumbral maximum does not dim the Queens world")
	var penumbra: Vector4 = may.shadow
	check(Vector2(penumbra.x,penumbra.y).length()>penumbra.z+1.,"May penumbral Moon never touches the umbra")
	bench.manager.set_process(false)
	bench.director.set_process(false)
	Engine.max_fps=0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for child: Node in bench.get_children():
		if child is WeatherFX:
			child.process_mode=Node.PROCESS_MODE_DISABLED
			(child as Node3D).hide()
			for layer: CanvasLayer in child.find_children("*","CanvasLayer",true,false): layer.hide()
	for particle: GPUParticles3D in bench.find_children("*","GPUParticles3D",true,false):
		particle.emitting=false;particle.hide()
	bench.camera.near=.01
	bench.environment.fog_enabled=false
	bench.environment.volumetric_fog_enabled=false
	bench.sky_material.set_shader_parameter("moon_surface",load("res://assets/environment/moon_lroc_4k.jpg"))
	bench.sky_material.set_shader_parameter("moon_height",load("res://assets/environment/moon_lola_height.png"))
	bench.sky_material.set_shader_parameter("moon_relief_enabled",true)
	for path: String in ["res://assets/environment/moon_lroc_4k.jpg","res://assets/environment/moon_lola_height.png"]:
		var texture := load(path) as Texture2D
		check(texture.get_image().has_mipmaps(),"loaded optical map has mipmaps: "+path)
	# Actual UTC geometries, clear optical control. No weather/calendar changes.
	for day in [19,22,27]:
		var hour := 17 if day==19 else 20
		bench.clock.configure_date(1928,11,day,hour*60)
		utc=bench.clock.utc_datetime()
		bench.director._astronomy_second=-INF
		bench.director._apply(float(hour)*60.)
		bench.environment.fog_enabled=false
		bench.environment.volumetric_fog_enabled=false
		var moon := Ephemeris.moon_direction(utc,40.75,-73.92)
		print("LUNAR CAPTURE ",utc," altitude=",Ephemeris.altitude_degrees(moon))
		check(moon.y>.08,"Moon above local horizon for terrain capture %d" % day)
		bench.sky_material.set_shader_parameter("celestial_direction",moon)
		bench.sky_material.set_shader_parameter("sun_direction",Ephemeris.sun_direction(utc,40.75,-73.92))
		bench.sky_material.set_shader_parameter("moon_phase_enabled",true)
		bench.sky_material.set_shader_parameter("celestial_strength",1.4)
		bench.sky_material.set_shader_parameter("cloud_coverage",0.)
		bench.sky_material.set_shader_parameter("lower_cloud_strength",0.)
		bench.sky_material.set_shader_parameter("high_cloud_strength",0.)
		bench.sky_material.set_shader_parameter("living_enabled",true)
		for layer in range(3):
			bench.sky_material.set_shader_parameter("living_layer_%d" % layer,Vector4(0.,1.+float(layer),.5,0.))
		bench.sky_material.set_shader_parameter("shape_opacity",0.)
		var no_spectacle := PackedFloat32Array();no_spectacle.resize(41)
		bench.sky_material.set_shader_parameter("spectacle",no_spectacle)
		for key: String in ["wx_whiteout","wx_blood_rain","wx_hail","wx_cyclone","wx_formation_strength","vortex_intensity"]:
			bench.sky_material.set_shader_parameter(key,0.)
		bench.camera.look_at(bench.camera.global_position+moon,Vector3.UP)
		bench.camera.set_frustum(2.*bench.camera.near*tan(deg_to_rad(2.)*.5),Vector2.ZERO,bench.camera.near,2000.)
		await capture(bench,out+"/moon_%d_relief.png" % day)
		if day==19:
			bench.sky_material.set_shader_parameter("moon_relief_enabled",false)
			await capture(bench,out+"/moon_19_smooth_control.png")
			bench.sky_material.set_shader_parameter("moon_relief_enabled",true)
		if day==22:
			var right := Vector3.UP.cross(moon).normalized()
			var up := moon.cross(right).normalized()
			var lon := deg_to_rad(-20.08);var lat := deg_to_rad(9.62)
			var offset := Vector2(sin(lon)*cos(lat),sin(lat))*sin(deg_to_rad(.27*2.5))
			bench.camera.look_at(bench.camera.global_position+(moon*sqrt(1.-offset.length_squared())+right*offset.x+up*offset.y).normalized(),Vector3.UP)
			set_field(bench,.1)
			await capture(bench,out+"/copernicus_01deg_shadow.png")
			bench.sky_material.set_shader_parameter("moon_shadow_enabled",false)
			await capture(bench,out+"/copernicus_01deg_unshadowed_control.png")
			bench.sky_material.set_shader_parameter("moon_shadow_enabled",true)
			for field: float in [78.,.1]:
				set_field(bench,field)
				for enabled in [false,true]:
					bench.sky_material.set_shader_parameter("moon_relief_enabled",enabled)
					timings.append(await measure(bench,field,enabled))
			bench.sky_material.set_shader_parameter("moon_relief_enabled",true)
	# A dated, locally visible eclipse, not a forced red full-Moon decoration.
	bench.clock.configure_date(1928,11,27,4*60+1)
	bench.director._astronomy_second=-INF;bench.director._apply(241.)
	clear_optics(bench)
	utc=bench.clock.utc_datetime()
	var eclipse_moon := Ephemeris.moon_direction(utc,40.75,-73.92)
	bench.camera.look_at(bench.camera.global_position+eclipse_moon,Vector3.UP)
	bench.sky_material.set_shader_parameter("celestial_strength",1.4)
	set_field(bench,2.)
	await capture(bench,out+"/total_eclipse_19281127.png")
	bench.sky_material.set_shader_parameter("moon_eclipse_shadow",Vector4.ZERO)
	await capture(bench,out+"/total_eclipse_unshadowed_control.png")
	# Search real campaign instants for each planet's best available night view.
	for index in range(5):
		var best := -INF
		var chosen: Dictionary={}
		for date: Vector3i in [Vector3i(1928,11,10),Vector3i(1929,1,15),Vector3i(1929,5,15),Vector3i(1929,8,15)]:
			for hour in [1,2,3,4,5,18,19,20,21,22,23]:
				bench.clock.configure_date(date.x,date.y,date.z,hour*60)
				utc=bench.clock.utc_datetime()
				var sun := Ephemeris.sun_direction(utc,40.75,-73.92)
				var state: Dictionary = Astronomy.planet_states(utc,40.75,-73.92)[index]
				var direction: Vector3=state.direction
				if sun.y<-.04 and direction.y>best and float(state.elongation)>deg_to_rad(12.):
					best=direction.y;chosen={"date":date,"hour":hour,"utc":utc,"state":state,"sun":sun}
		check(not chosen.is_empty() and best>0.,"real night visibility found for "+Astronomy.PLANETS[index])
		if chosen.is_empty():continue
		var date: Vector3i=chosen.date
		bench.clock.configure_date(date.x,date.y,date.z,int(chosen.hour)*60)
		bench.director._astronomy_second=-INF;bench.director._apply(float(chosen.hour)*60.)
		clear_optics(bench)
		var direction: Vector3=chosen.state.direction
		var solar: Vector3=chosen.state.sun_direction
		check(absf((1.-direction.dot(solar))*.5-float(chosen.state.illumination))<.00001,"rendered phase uses planet-to-Sun geometry for "+Astronomy.PLANETS[index])
		bench.camera.look_at(bench.camera.global_position+direction,Vector3.UP)
		set_field(bench,1.)
		await capture(bench,out+"/planet_"+Astronomy.PLANETS[index]+".png")
		optical_geometry.append({"body":Astronomy.PLANETS[index],"utc":chosen.utc,"altitude_degrees":Ephemeris.altitude_degrees(direction),"solar_altitude_degrees":Ephemeris.altitude_degrees(chosen.sun),"elongation_degrees":rad_to_deg(float(chosen.state.elongation)),"illumination":chosen.state.illumination})
	var result := {"evidence_class":"INERT","scope":"Numerical and clear-sky optical diagnostics; no installed interaction or human acceptance", "failures":failures,"planet_comparisons":samples,"frame_times":timings,"optical_geometry":optical_geometry}
	var file := FileAccess.open(out+"/skywatch_review.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t")+"\n");file.close()
	print("SKYWATCH RESULT: %s" % ["PASS" if failures.is_empty() else "FAIL"])
	bench.get_tree().quit(0 if failures.is_empty() else 1)

func set_field(bench: Node3D,degrees: float) -> void:
	bench.camera.set_frustum(2.*bench.camera.near*tan(deg_to_rad(degrees)*.5),Vector2.ZERO,bench.camera.near,2000.)

func clear_optics(bench: Node3D) -> void:
	bench.environment.fog_enabled=false;bench.environment.volumetric_fog_enabled=false
	for key: String in ["cloud_coverage","lower_cloud_strength","high_cloud_strength","shape_opacity","wx_whiteout","wx_blood_rain","wx_hail","wx_cyclone","wx_formation_strength","vortex_intensity"]:
		bench.sky_material.set_shader_parameter(key,0.)
	bench.sky_material.set_shader_parameter("living_enabled",true)
	for layer in range(3):bench.sky_material.set_shader_parameter("living_layer_%d" % layer,Vector4(0.,1.+float(layer),.5,0.))
	var empty := PackedFloat32Array();empty.resize(41)
	bench.sky_material.set_shader_parameter("spectacle",empty)

func cloud_review(bench: Node3D) -> void:
	bench.manager.set_process(false);bench.director.set_process(false)
	var macro: Texture3D=bench.sky_material.get_shader_parameter("cloud_macro")
	var curl: Texture3D=bench.sky_material.get_shader_parameter("cloud_curl")
	check(macro!=null and curl!=null and macro.get_width()==128 and curl.get_width()==32 and macro.has_mipmaps() and curl.has_mipmaps(),"runtime cloud macro and curl textures are bound at their declared sizes with mipmaps")
	Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var output := OS.get_environment("SHOT_DIR");DirAccess.make_dir_recursive_absolute(output)
	var selected: Dictionary={}
	var calendar := preload("res://scripts/game/campaign_weather.gd")
	var library := preload("res://scripts/building/living_sky.gd")
	var start := Time.get_unix_time_from_datetime_string("1928-11-10T12:00:00")
	# Select actual dated regimes, without changing their authored weather.
	for day in range(365):
		for hour in [9,12,15,18]:
			var date := Time.get_datetime_dict_from_unix_time(start+day*86400+(hour-12)*3600)
			var conditions: Dictionary=bench.manager.Service.presentation(calendar.snapshot(date))
			var state := library.sample(date,conditions,1928)
			for layer: Dictionary in state.layers:
				if layer.genus in ["Cu","Sc","Ns","Cb","Ci"] and layer.coverage>(.05 if layer.genus=="Ci" else .2) and not selected.has(layer.genus):
					selected[layer.genus]={"day":day,"hour":hour}
		if selected.size()==5:break
	check(selected.size()==5,"cloud review finds five real dated genera without changing calendar weather")
	var rows: Array[Dictionary]=[]
	for kind: String in selected:
		bench._library_date(int(selected[kind].day),float(selected[kind].hour))
		bench.manager.origin=bench.manager.target.duplicate(true);bench.manager.elapsed=bench.manager.TRANSITION_SECONDS
		bench.manager._process(0.);bench.manager._publish()
		bench.director._apply(bench.clock.minute_of_day())
		for effect: Node in bench.get_children():
			if effect is WeatherFX:effect.process_mode=Node.PROCESS_MODE_DISABLED;(effect as Node3D).hide()
		bench.camera.look_at(bench.camera.global_position+Vector3(-1,.42,-.3));set_field(bench,85.)
		bench.sky_material.set_shader_parameter("temporal_phase",0.)
		var timing := await measure(bench,85.,false)
		await capture(bench,output.path_join(kind+"_noon.png"))
		rows.append({"genus":kind,"date":bench.clock.datetime_string(),"state":bench.manager.atmosphere_state.duplicate(true),"timing":timing})
		if kind=="Cu":
			var previous_fog: bool=bench.environment.volumetric_fog_enabled
			bench.environment.volumetric_fog_enabled=false
			var roll: Vector2=bench.sky_material.get_shader_parameter("living_flow_0")
			# Production morphology publications are throttled to 10 Hz. Force
			# this diagnostic publication while retaining a fractional clock.
			bench.clock.advance_seconds(.05);bench.manager._process(.05);bench.manager._publish()
			var advanced_roll: Vector2=bench.sky_material.get_shader_parameter("living_flow_0")
			check(absf(advanced_roll.x-roll.x-.05/1800.)<.000001,"curl roll publication follows fractional campaign time")
			bench.manager._process(0.)
			check(bench.sky_material.get_shader_parameter("living_flow_0")==advanced_roll,"paused clock holds the curl field")
			bench.get_viewport().use_taa=false
			bench.sky_material.set_shader_parameter("temporal_phase",0.)
			# Isolate ordinary density from the retained random animal SDF,
			# whose appearance envelope still follows instance uptime.
			bench.sky_material.set_shader_parameter("shape_kind",0)
			bench.sky_material.set_shader_parameter("shape_opacity",0.)
			await capture(bench,output.path_join("Cu_return_start.png"))
			var initial := bench.get_viewport().get_texture().get_image()
			var original_uniforms: Dictionary={}
			var original_camera: Transform3D=bench.camera.global_transform
			var original_projection: Projection=bench.camera.get_camera_projection()
			await capture(bench,output.path_join("Cu_paused_repeat.png"))
			var paused_image := bench.get_viewport().get_texture().get_image()
			var paused_signal := display_peak(initial,paused_image)
			var paused_error := cloud_image_error(initial,paused_image)
			bench.sky_material.set_shader_parameter("temporal_phase",113.)
			await capture(bench,output.path_join("Cu_legacy_phase_control.png"))
			check(cloud_image_error(initial,bench.get_viewport().get_texture().get_image())<=maxf(1./1020.,paused_error*1.5),"legacy jitter phase cannot introduce visible cloud grain at a fixed calendar time")
			bench.sky_material.set_shader_parameter("temporal_phase",0.)
			bench.sky_material.set_shader_parameter("shape_opacity",1.)
			await capture(bench,output.path_join("Cu_inactive_shape_timer.png"))
			check(cloud_image_error(initial,bench.get_viewport().get_texture().get_image())<=maxf(1./1020.,paused_error*1.5),"an inactive legacy shape timer cannot alter ordinary cloud marching")
			bench.sky_material.set_shader_parameter("shape_opacity",0.)
			for uniform: Dictionary in bench.sky_material.shader.get_shader_uniform_list():
				original_uniforms[uniform.name]=bench.sky_material.get_shader_parameter(uniform.name)
			bench.clock.advance_seconds(120.);bench.manager._process(120.)
			bench.sky_material.set_shader_parameter("temporal_phase",0.)
			bench.sky_material.set_shader_parameter("shape_kind",0)
			bench.sky_material.set_shader_parameter("shape_opacity",0.)
			await capture(bench,output.path_join("Cu_two_minutes.png"))
			var travelled := bench.get_viewport().get_texture().get_image()
			var travelled_error := cloud_image_error(initial,travelled)
			check(travelled_error>maxf(.005,paused_error*5.),"calendar transport changes cloud composition beyond measured paused render variation")
			bench._library_date(int(selected[kind].day),float(selected[kind].hour))
			bench.clock.advance_seconds(.05)
			bench.manager.origin=bench.manager.target.duplicate(true);bench.manager.elapsed=bench.manager.TRANSITION_SECONDS
			bench.manager._process(0.);bench.manager._publish()
			bench.get_viewport().use_taa=false;bench.sky_material.set_shader_parameter("temporal_phase",0.)
			bench.sky_material.set_shader_parameter("shape_kind",0)
			bench.sky_material.set_shader_parameter("shape_opacity",0.)
			var camera_restore := {"original":str(original_camera),"returned":str(bench.camera.global_transform),"original_projection":str(original_projection),"returned_projection":str(bench.camera.get_camera_projection())}
			bench.camera.global_transform=original_camera;set_field(bench,85.)
			bench.environment.volumetric_fog_enabled=false
			camera_restore["exact_camera"]=bench.camera.global_transform==original_camera
			camera_restore["exact_projection"]=bench.camera.get_camera_projection()==original_projection
			camera_restore["paused_peak"]=paused_signal
			camera_restore["paused_mean_error_160x90"]=paused_error
			camera_restore["travelled_mean_error_160x90"]=travelled_error
			FileAccess.open(output.path_join("return_camera.json"),FileAccess.WRITE).store_string(JSON.stringify(camera_restore,"\t"))
			await capture(bench,output.path_join("Cu_returned.png"))
			var changed_uniforms: Dictionary={}
			for name: String in original_uniforms:
				var value: Variant=bench.sky_material.get_shader_parameter(name)
				if original_uniforms[name]!=value:changed_uniforms[name]=[str(original_uniforms[name]),str(value)]
			FileAccess.open(output.path_join("return_uniform_changes.json"),FileAccess.WRITE).store_string(JSON.stringify(changed_uniforms,"\t"))
			var returned_error := cloud_image_error(initial,bench.get_viewport().get_texture().get_image())
			check(changed_uniforms.is_empty(),"returning to fractional time restores every published sky uniform")
			check(returned_error<=maxf(1./1020.,paused_error*1.5),"returned cloud composition agrees within measured paused render variation")
			camera_restore["returned_mean_error_160x90"]=returned_error
			FileAccess.open(output.path_join("return_camera.json"),FileAccess.WRITE).store_string(JSON.stringify(camera_restore,"\t"))
			bench.get_viewport().use_taa=true
			bench.environment.volumetric_fog_enabled=previous_fog
	FileAccess.open(output.path_join("cloud_review.json"),FileAccess.WRITE).store_string(JSON.stringify({
		"evidence_class":"INERT","scope":"five calendar-selected daytime genera over actual city-horizon bench; particle draws disabled; not occupied-world or annual artistic acceptance",
		"resolution":str(bench.get_viewport().get_visible_rect().size),"msaa":bench.get_viewport().msaa_3d,"taa":bench.get_viewport().use_taa,
		"rows":rows,"failures":failures},"\t"))
	print("SKYWATCH CLOUD RESULT: ","PASS" if failures.is_empty() else "FAIL")
	bench.get_tree().quit(0 if failures.is_empty() else 1)

func cloud_image_error(a: Image,b: Image) -> float:
	# Single-pixel maxima are dominated by renderer edge/jitter variation even
	# when paused. Compare large-scale composition against that measured floor.
	var left := a.duplicate() as Image;var right := b.duplicate() as Image
	left.resize(160,90,Image.INTERPOLATE_LANCZOS);right.resize(160,90,Image.INTERPOLATE_LANCZOS)
	var error := 0.
	for y in range(90):
		for x in range(160):
			var delta := left.get_pixel(x,y)-right.get_pixel(x,y)
			error+=absf(delta.r)+absf(delta.g)+absf(delta.b)
	return error/(160.*90.*3.)

func measure(bench: Node3D,field: float,relief: bool) -> Dictionary:
	Astronomy.publish_star_frame(bench.sky_material,bench.camera,bench.clock)
	for frame in range(30): await bench.get_tree().process_frame
	var frames: Array[float]=[]
	var last := Time.get_ticks_usec()
	for frame in range(120):
		await bench.get_tree().process_frame
		var now := Time.get_ticks_usec()
		frames.append(float(now-last)/1000.);last=now
	var ordered := frames.duplicate();ordered.sort()
	return {"vertical_field_degrees":field,"relief":relief,"raw_frame_ms":frames,"p50":ordered[60],"p95":ordered[114],"p99":ordered[118],"max":ordered[-1],"scope":"clear optical bench, not occupied-world route or isolated GPU attribution"}

func capture(bench: Node3D,path: String,phase_override := INF,settle_frames := 20) -> void:
	Astronomy.publish_star_frame(bench.sky_material,bench.camera,bench.clock)
	if is_finite(phase_override):bench.sky_material.set_shader_parameter("star_animation_seconds",phase_override)
	for frame in range(settle_frames): await bench.get_tree().process_frame
	await RenderingServer.frame_post_draw
	bench.get_viewport().get_texture().get_image().save_png(path)

func star_review(bench: Node3D) -> void:
	bench.manager.set_process(false);bench.director.set_process(false)
	Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	bench.clock.configure_date(1929,1,15,22*60)
	bench.director._astronomy_second=-INF;bench.director._apply(1320.)
	check(bench.director._panoramas[bench.director.SKY_PATHS.night].get_width()==2,"V2 no longer loads the photographic star panorama")
	clear_optics(bench)
	for effect: Node in bench.get_children():
		if effect is WeatherFX:
			effect.process_mode=Node.PROCESS_MODE_DISABLED;(effect as Node3D).hide()
	bench.camera.near=.01
	var baker := preload("res://scripts/building/skywatch_catalogue.gd")
	var data := FileAccess.get_file_as_bytes(ProjectSettings.globalize_path("res://../art/data/astronomy/bsc5_catalog.dat.gz"))
	var parsed := baker.parse_catalogue(data.decompress_dynamic(5000000,FileAccess.COMPRESSION_GZIP).get_string_from_ascii())
	var sirius: Dictionary={}
	for row: Dictionary in parsed.rows:
		if int(row.hr)==2491:sirius=row;break
	check(not sirius.is_empty(),"Sirius is identified by stable BSC HR number")
	var utc: Dictionary = bench.clock.utc_datetime()
	var jd := Ephemeris.julian_day(utc)
	var direction := Astronomy.horizon(baker.direction(sirius,jd),jd,40.75,-73.92)
	bench.camera.look_at(bench.camera.global_position+direction,Vector3.UP)
	var out := OS.get_environment("SHOT_DIR");DirAccess.make_dir_recursive_absolute(out)
	var frames: Array[Dictionary]=[]
	for field: float in [78.,1.,.1]:
		set_field(bench,field)
		await capture(bench,out+"/sirius_%.1f_degrees.png" % field)
		check(absf(float(bench.sky_material.get_shader_parameter("camera_fov"))-deg_to_rad(field))<.00001,"physical frustum field published %.1f degrees" % field)
		for mode in range(3):
			bench.sky_material.set_shader_parameter("skywatch_stars_enabled",mode>0)
			bench.sky_material.set_shader_parameter("skywatch_faint_stars",mode==2)
			var sample := await measure(bench,field,false)
			sample["star_mode"]=mode;frames.append(sample)
	bench.sky_material.set_shader_parameter("star_animation_seconds",0.)
	# A stationary clock hid the retained eight-second director cadence. Track
	# the rendered star as the real campaign clock advances within one second.
	set_field(bench,.1)
	var drift: Array[Dictionary]=[]
	for step in range(9):
		if step>0:bench.clock.advance_seconds(.05)
		var started := Time.get_ticks_usec()
		bench.director._process(.000001)
		var cpu_us := Time.get_ticks_usec()-started
		var axis: Vector3=bench.sky_material.get_shader_parameter("equatorial_axis_x")
		await capture(bench,out+"/stellar_drift_%02d.png" % step,0.)
		var centroid := image_centroid(bench.get_viewport().get_texture().get_image())
		drift.append({"elapsed_seconds":float(step)*.05,"centroid": [centroid.x,centroid.y],"axis":[axis.x,axis.y,axis.z],"director_cpu_us":cpu_us})
	var start_center := Vector2(drift[0].centroid[0],drift[0].centroid[1])
	var end_center := Vector2(drift[-1].centroid[0],drift[-1].centroid[1])
	var travel := end_center-start_center
	var continuous := travel.length()>5.
	var previous := start_center
	for step in range(1,drift.size()):
		var current := Vector2(drift[step].centroid[0],drift[step].centroid[1])
		continuous=continuous and (current-previous).dot(travel.normalized())>.2 and current.distance_to(previous)<travel.length()*.3
		previous=current
	check(continuous,"campaign sub-second rotation moves the rendered telescope star continuously before the lighting tick")
	check(Vector3(drift[0].axis[0],drift[0].axis[1],drift[0].axis[2]).distance_to(Vector3(drift[-1].axis[0],drift[-1].axis[1],drift[-1].axis[2]))>.00001,"V2 director publishes fractional-clock celestial axes")
	await capture(bench,out+"/sirius_reference.png")
	var baseline_phase := float(bench.sky_material.get_shader_parameter("star_animation_seconds"))
	await capture(bench,out+"/sirius_scintillation_control.png",baseline_phase+.073)
	# Let TAA settle after jumping from an unrelated phase to this endpoint;
	# otherwise its prior phase history contaminates the continuity comparison.
	await capture(bench,out+"/scintillation_wrap_before.png",4095.999,120)
	var wrap_before := bench.get_viewport().get_texture().get_image()
	await capture(bench,out+"/scintillation_wrap_after.png",.001,120)
	var wrap_after := bench.get_viewport().get_texture().get_image()
	var wrap_signal := image_signal(wrap_before,wrap_after)
	var flux_before := image_flux(wrap_before);var flux_after := image_flux(wrap_after)
	var wrap_flux_change := absf(flux_before-flux_after)/maxf(flux_before,flux_after)
	check(wrap_flux_change<.03,"bounded animation-clock wrap preserves integrated stellar light within three percent")
	# Compare the star contribution itself, so bright cloud lighting cannot be
	# mistaken for a star shining through its occluder.
	bench.sky_material.set_shader_parameter("skywatch_stars_enabled",true)
	await capture(bench,out+"/occlusion_clear_on.png")
	var clear_on := bench.get_viewport().get_texture().get_image()
	bench.sky_material.set_shader_parameter("skywatch_stars_enabled",false)
	await capture(bench,out+"/occlusion_clear_off.png")
	var clear_off := bench.get_viewport().get_texture().get_image()
	# Publish a complete production nimbostratus brush, not a coverage-only
	# hybrid retaining another genus's density/motion from the clear setup.
	var library := preload("res://scripts/building/living_sky.gd")
	var weather := {"cloud_total":1.,"cloud_low":0.,"cloud_mid":1.,"cloud_high":0.,"rain_intensity":.9,"snow_intensity":0.,"relative_humidity":.95,"temperature_c":2.,"wind_speed_kmh":20.,"pressure_hpa":990.}
	var ceiling := library.sample(bench.clock.local_datetime(),weather,1928,Vector2.ZERO)
	library.publish(bench.sky_material,ceiling)
	bench.sky_material.set_shader_parameter("skywatch_stars_enabled",true)
	await capture(bench,out+"/occlusion_cloud_on.png")
	var cloud_on := bench.get_viewport().get_texture().get_image()
	bench.sky_material.set_shader_parameter("skywatch_stars_enabled",false)
	await capture(bench,out+"/occlusion_cloud_off.png")
	var cloud_off := bench.get_viewport().get_texture().get_image()
	var clear_signal := image_signal(clear_on,clear_off)
	var cloud_signal := image_signal(cloud_on,cloud_off)
	check(clear_signal>.1 and cloud_signal<clear_signal*.1,"production cloud composite extinguishes at least 90 percent of the measured star signal")
	clear_optics(bench)
	var blocker := MeshInstance3D.new();var box := BoxMesh.new();box.size=Vector3(.2,.2,.2)
	blocker.mesh=box;bench.add_child(blocker);blocker.global_position=bench.camera.global_position+direction*3.
	var opaque := StandardMaterial3D.new();opaque.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;opaque.albedo_color=Color(.02,.02,.02)
	blocker.material_override=opaque
	bench.sky_material.set_shader_parameter("skywatch_stars_enabled",true)
	await capture(bench,out+"/occlusion_world_on.png")
	var world_on := bench.get_viewport().get_texture().get_image()
	bench.sky_material.set_shader_parameter("skywatch_stars_enabled",false)
	await capture(bench,out+"/occlusion_world_off.png")
	var world_off := bench.get_viewport().get_texture().get_image()
	var world_signal := image_signal(world_on,world_off)
	check(world_signal<.002,"a real opaque world mesh blocks the analytical starfield")
	blocker.queue_free();await bench.get_tree().process_frame
	var result := {"evidence_class":"INERT","scope":"native analytical-star optical/performance diagnostics; not telescope gameplay acceptance","failures":failures,"sirius_altitude_degrees":Ephemeris.altitude_degrees(direction),"frame_times":frames,"stellar_drift":drift,"clear_signal":clear_signal,"cloud_signal":cloud_signal,"world_signal":world_signal,"wrap_peak_signal":wrap_signal,"wrap_relative_flux_change":wrap_flux_change}
	var file := FileAccess.open(out+"/star_review.json",FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t")+"\n");file.close()
	print("SKYWATCH STAR RESULT: ","PASS" if failures.is_empty() else "FAIL")
	bench.get_tree().quit(0 if failures.is_empty() else 1)

func image_signal(a: Image,b: Image) -> float:
	var peak := 0.
	var center := a.get_size()/2
	for y in range(center.y-40,center.y+41):
		for x in range(center.x-40,center.x+41):
			var difference := a.get_pixel(x,y)-b.get_pixel(x,y)
			peak=maxf(peak,maxf(absf(difference.r),maxf(absf(difference.g),absf(difference.b))))
	return peak

func image_flux(a: Image) -> float:
	var center := a.get_size()/2
	var background := a.get_pixel(center.x-40,center.y-40).srgb_to_linear().get_luminance()
	var sum := 0.
	for y in range(center.y-40,center.y+41):
		for x in range(center.x-40,center.x+41):
			sum+=maxf(0.,a.get_pixel(x,y).srgb_to_linear().get_luminance()-background)
	return sum

func image_centroid(image: Image) -> Vector2:
	var center := image.get_size()/2
	var background := image.get_pixel(center.x-80,center.y-80).srgb_to_linear().get_luminance()
	var weighted := Vector2.ZERO
	var energy := 0.
	for y in range(center.y-80,center.y+81):
		for x in range(center.x-80,center.x+81):
			var value := maxf(0.,image.get_pixel(x,y).srgb_to_linear().get_luminance()-background)
			weighted+=Vector2(x,y)*value;energy+=value
	return weighted/maxf(energy,.000001)

func atmosphere_review(bench: Node3D) -> void:
	bench.manager.set_process(false);bench.director.set_process(false)
	Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var out := OS.get_environment("SHOT_DIR");DirAccess.make_dir_recursive_absolute(out)
	var records: Array[Dictionary]=[]
	for sample: Dictionary in [{"name":"solar_ice","year":1929,"month":1,"day":15,"minute":600,"anti":false},{"name":"lunar_ice","year":1928,"month":11,"day":27,"minute":90,"anti":false},{"name":"twilight_belt","year":1929,"month":3,"day":20,"minute":1080,"anti":true},{"name":"night_airglow","year":1929,"month":3,"day":10,"minute":1320,"anti":true}]:
		var minute: int=sample.minute
		if sample.name=="twilight_belt":
			var closest := INF
			for i in range(900,1260):
				bench.clock.configure_date(sample.year,sample.month,sample.day,i)
				var candidate := Ephemeris.sun_direction(bench.clock.utc_datetime(),40.75,-73.92)
				var gap := absf(Ephemeris.altitude_degrees(candidate)+3.)
				if gap<closest:closest=gap;minute=i
		bench.clock.configure_date(sample.year,sample.month,sample.day,minute)
		bench.director._live_conditions={"cloud_high":.6,"temperature_c":-8.,"precipitation_intensity":0.,"relative_humidity":.98}
		bench.director._astronomy_second=-INF;bench.director._apply(float(minute))
		clear_optics(bench)
		for effect: Node in bench.get_children():
			if effect is WeatherFX:effect.process_mode=Node.PROCESS_MODE_DISABLED;(effect as Node3D).hide()
		var sun := Ephemeris.sun_direction(bench.clock.utc_datetime(),40.75,-73.92)
		var moon := Ephemeris.moon_direction(bench.clock.utc_datetime(),40.75,-73.92)
		var source: Vector3=bench.sky_material.get_shader_parameter("celestial_direction")
		var aim := source
		if sample.anti:aim=Vector3(-sun.x,.15,-sun.z).normalized()
		bench.camera.look_at(bench.camera.global_position+aim,Vector3.UP);set_field(bench,100.)
		var ice: Vector3=bench.sky_material.get_shader_parameter("skywatch_ice_complex")
		check(ice.x>0.2 and ice.y>0.1 and ice.z>0.1,"existing weather owner derives cold ice optics: "+str(sample.name))
		bench.sky_material.set_shader_parameter("skywatch_extended_optics",false)
		bench.sky_material.set_shader_parameter("skywatch_ice_complex",Vector3.ZERO)
		await capture(bench,out+"/"+str(sample.name)+"_control.png")
		var control := bench.get_viewport().get_texture().get_image()
		bench.sky_material.set_shader_parameter("skywatch_extended_optics",true)
		bench.sky_material.set_shader_parameter("skywatch_ice_complex",ice if not sample.anti else Vector3.ZERO)
		await capture(bench,out+"/"+str(sample.name)+".png")
		var shown := bench.get_viewport().get_texture().get_image()
		var delta_sum := 0.;var peak := 0.
		for y in range(20,shown.get_height()-20,16):
			for x in range(20,shown.get_width()-20,16):
				var change := (shown.get_pixel(x,y)-control.get_pixel(x,y))
				var strength := absf(change.r)+absf(change.g)+absf(change.b)
				delta_sum+=strength;peak=maxf(peak,strength)
		check(peak>.005,"actual optical render differs from disabled control: "+str(sample.name))
		var row := {"id":sample.name,"local_minute":minute,"utc":bench.clock.utc_datetime(),"sun_altitude":Ephemeris.altitude_degrees(sun),"moon_altitude":Ephemeris.altitude_degrees(moon),"peak_displayed_rgb_change":peak,"sampled_displayed_rgb_change":delta_sum}
		if sample.name=="solar_ice":
			row["frames_enabled"]=await measure(bench,100.,false)
			bench.sky_material.set_shader_parameter("skywatch_extended_optics",false);bench.sky_material.set_shader_parameter("skywatch_ice_complex",Vector3.ZERO)
			row["frames_disabled"]=await measure(bench,100.,false)
		records.append(row)
	# The production lamp owner, with diagnostic source lights rather than a
	# fabricated sky bearing. Ordinary world depth must still hide the beam.
	var lamps := preload("res://scripts/building/orison_v2_street_lamps.gd")
	var owner := lamps.LampClock.new()
	owner.dusk=lamps.load_table().dusk;owner.dawn=lamps.load_table().dawn
	owner.clock_override={"month":1,"minute_of_day":1320.}
	var light := OmniLight3D.new();bench.add_child(light)
	light.position=bench.camera.position+Vector3(0,-5,-25)
	owner.lights.append(light);bench.add_child(owner);owner.set_process(false)
	bench.camera.look_at(light.global_position+Vector3.UP*10.,Vector3.UP);set_field(bench,70.)
	bench.director._live_conditions={"temperature_c":-8.,"relative_humidity":.98}
	bench.director._publish_ice_optics()
	check(owner.ice_level>.9 and owner.pillars.size()==1,"production freezing-fog publisher binds a pillar to the actual clocked globe")
	await capture(bench,out+"/urban_pillar.png")
	var pillar_on := bench.get_viewport().get_texture().get_image()
	owner.set_ice_level(0.)
	await capture(bench,out+"/urban_pillar_control.png")
	var pillar_off := bench.get_viewport().get_texture().get_image()
	var beam_region := Rect2i(pillar_on.get_width()/2-40,20,80,pillar_on.get_height()-40)
	check(display_peak(pillar_on,pillar_off,beam_region)>.02,"world-space lamp pillar produces measured optical signal")
	owner.set_ice_level(1.)
	owner.clock_override.minute_of_day=720.;owner.refresh()
	check(not light.visible and owner.lit==0.,"lamp clock extinguishes its pillar during the day")
	owner.clock_override.minute_of_day=1320.;owner.refresh()
	var blocker := MeshInstance3D.new();var block := BoxMesh.new();block.size=Vector3(15,40,1)
	blocker.mesh=block;bench.add_child(blocker)
	blocker.global_position=light.global_position+Vector3(0,10,10)
	var matte := StandardMaterial3D.new();matte.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;matte.albedo_color=Color(.02,.02,.02);blocker.material_override=matte
	await capture(bench,out+"/urban_pillar_blocked.png")
	var blocked_on := bench.get_viewport().get_texture().get_image()
	owner.set_ice_level(0.)
	await capture(bench,out+"/urban_pillar_blocked_control.png")
	# Restrict to the beam's fully covered central footprint. Unrelated
	# asynchronously scintillating stars outside the blocker are not its signal.
	var covered := Rect2i(blocked_on.get_width()/2-40,20,80,blocked_on.get_height()-40)
	check(display_peak(blocked_on,bench.get_viewport().get_texture().get_image(),covered)<.01,"real foreground world geometry blocks the urban optical beam")
	blocker.queue_free();owner.queue_free();light.queue_free();await bench.get_tree().process_frame
	var result := {"evidence_class":"INERT","scope":"clear optical component controls, not annual artistic acceptance or world qualification","failures":failures,"samples":records}
	FileAccess.open(out+"/atmosphere_review.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t")+"\n")
	print("SKYWATCH ATMOSPHERE RESULT: ","PASS" if failures.is_empty() else "FAIL")
	bench.get_tree().quit(0 if failures.is_empty() else 1)

func display_peak(a: Image,b: Image,region := Rect2i()) -> float:
	var peak := 0.
	if region.size==Vector2i.ZERO:region=Rect2i(20,20,a.get_width()-40,a.get_height()-40)
	for y in range(region.position.y,region.end.y,8):
		for x in range(region.position.x,region.end.x,8):
			var d := a.get_pixel(x,y)-b.get_pixel(x,y)
			peak=maxf(peak,absf(d.r)+absf(d.g)+absf(d.b))
	return peak

func mirage_review(bench: Node3D) -> void:
	var out := OS.get_environment("SHOT_DIR");DirAccess.make_dir_recursive_absolute(out)
	var occurrence: Dictionary={}
	for row: Dictionary in bench.manager.schedule.occurrences:
		if row.id=="fata_morgana":occurrence=row;break
	check(not occurrence.is_empty(),"authored annual calendar retains its dated mirage occurrence")
	await bench._shoot("fata_morgana",occurrence,.5,"scheduled_mirage")
	bench.manager.set_process(false);bench.director.set_process(false)
	for effect: Node in bench.get_children():
		if effect is WeatherFX:effect.process_mode=Node.PROCESS_MODE_DISABLED;(effect as Node3D).hide()
	var mirage: CompositorEffect=bench.director._mirage
	check(mirage.failed.is_empty() and mirage.passes>0 and mirage.enabled,"existing schedule drives the compiled native refraction compositor")
	var initial_phase: float=mirage.state.z
	bench.clock.advance_seconds(.05)
	bench.manager._update_phenomena(0.);bench.manager._push_spectacle()
	check(absf(fposmod(mirage.state.z-initial_phase,256.)-.05)<.001,"mirage follows fractional campaign time between whole seconds")
	var held_phase: float=mirage.state.z
	bench.manager._update_phenomena(0.);bench.manager._push_spectacle()
	check(mirage.state.z==held_phase,"paused campaign time holds optical shimmer exactly")
	clear_optics(bench)
	bench.get_viewport().use_taa=false
	# The retained bench's first neighbouring row is inside the protected 80 m
	# range. A translated diagnostic station puts those real buildings beyond
	# the cutoff; this does not claim that the installed roof sees a river.
	var riverward := Vector3(sin(float(occurrence.bearing)),0.,-cos(float(occurrence.bearing)))
	bench.camera.global_position-=riverward*120.
	# Retain its published calendar state, but clear moving cloud/particle noise
	# for paired spatial controls. The first capture preserves the real recipe.
	await capture(bench,out+"/geometry_refracted.png")
	var on := bench.get_viewport().get_texture().get_image()
	mirage.enabled=false;await capture(bench,out+"/geometry_control.png")
	var off := bench.get_viewport().get_texture().get_image()
	var optical_signal := display_peak(on,off)
	check(optical_signal>.02,"actual distant city image changes under the folded ray duct with TAA disabled")
	# Bright nearby stock is both a destination blocker and a forbidden sample.
	var block := MeshInstance3D.new();var mesh := BoxMesh.new();mesh.size=Vector3(.6,.8,.2);block.mesh=mesh
	var red := StandardMaterial3D.new();red.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;red.albedo_color=Color(1.,.02,.02);block.material_override=red
	bench.add_child(block);block.global_position=bench.camera.global_position-bench.camera.global_basis.z*4.
	var glass := MeshInstance3D.new();var pane := QuadMesh.new();pane.size=Vector2(.55,1.1);glass.mesh=pane
	var glazing := StandardMaterial3D.new();glazing.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	glazing.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;glazing.depth_draw_mode=BaseMaterial3D.DEPTH_DRAW_DISABLED;glazing.cull_mode=BaseMaterial3D.CULL_DISABLED
	var pattern := Image.create_empty(32,64,false,Image.FORMAT_RGBA8)
	for y in range(64):
		for x in range(32):pattern.set_pixel(x,y,Color(.1,.8,.1,.6) if (y/8)%2==0 else Color(.8,.1,.8,.6))
	glazing.albedo_texture=ImageTexture.create_from_image(pattern);glass.material_override=glazing
	bench.add_child(glass);glass.global_transform=bench.camera.global_transform
	glass.global_position=bench.camera.global_position-bench.camera.global_basis.z*4.+bench.camera.global_basis.x*.85
	var overlay := CanvasLayer.new();bench.add_child(overlay)
	var swatch := ColorRect.new();swatch.color=Color(.02,.8,.6);swatch.position=Vector2(40,40);swatch.size=Vector2(130,60);overlay.add_child(swatch)
	await capture(bench,out+"/near_control.png");var near_off := bench.get_viewport().get_texture().get_image()
	mirage.enabled=true;await capture(bench,out+"/near_refracted.png");var near_on := bench.get_viewport().get_texture().get_image()
	var center: Vector2i=near_on.get_size()/2
	check(display_peak(near_on,near_off,Rect2i(center-Vector2i(80,80),Vector2i(160,160)))<.01,"nearby opaque object remains unchanged by refraction")
	check(display_peak(near_on,near_off,Rect2i(45,45,120,50))<.01,"canvas interface remains outside the scene-refraction pass")
	var glass_center: Vector2i=bench.camera.unproject_position(glass.global_position)
	check(display_peak(near_on,near_off,Rect2i(glass_center-Vector2i(40,70),Vector2i(80,140)))<.01,"near transparent detail without depth writes remains unchanged")
	var dragged_red := 0
	for y in range(20,near_on.get_height()-20,3):
		for x in range(20,near_on.get_width()-20,3):
			var a := near_on.get_pixel(x,y);var b := near_off.get_pixel(x,y)
			if a.r>.7 and a.r>a.g*3. and a.r>a.b*3. and a.r-b.r>.1:dragged_red+=1
	check(dragged_red==0,"refracted source taps cannot pull nearby stock into the distant sky")
	block.queue_free();glass.queue_free();overlay.queue_free();await bench.get_tree().process_frame
	# Resize/rebind without changing the owner's fullscreen debug window.
	var probe := SubViewport.new();probe.size=Vector2i(1024,512);probe.world_3d=bench.get_world_3d()
	probe.msaa_3d=Viewport.MSAA_4X;probe.render_target_update_mode=SubViewport.UPDATE_ALWAYS;bench.add_child(probe)
	var probe_camera := Camera3D.new();probe_camera.fov=28.;probe.add_child(probe_camera)
	probe_camera.global_transform=bench.camera.global_transform;probe_camera.make_current()
	mirage.bind_camera(probe_camera)
	for frame in range(12):await bench.get_tree().process_frame
	await RenderingServer.frame_post_draw
	check(mirage.dimensions==probe.size and mirage.failed.is_empty(),"camera rebind resizes GPU snapshots for another multisampled viewport")
	probe.get_texture().get_image().save_png(out+"/secondary_viewport.png")
	mirage.bind_camera(bench.camera);probe.queue_free()
	for frame in range(8):await bench.get_tree().process_frame
	check(mirage.dimensions==Vector2i(bench.get_viewport().get_visible_rect().size),"returning to the native viewport rebuilds the correct snapshot extent")
	Engine.max_fps=0;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var frame_times := {"enabled":await measure(bench,28.,false)}
	mirage.enabled=false;frame_times["disabled"]=await measure(bench,28.,false);mirage.enabled=true
	# Camera-local composition preserves an unrelated pre-existing effect.
	mirage.bind_camera(null)
	var original := Compositor.new()
	var sentinel := preload("res://scripts/lamp/lamp_scene_shadow_effect.gd").new();sentinel.enabled=false
	original.compositor_effects=[sentinel];bench.camera.compositor=original
	mirage.bind_camera(bench.camera)
	check(bench.camera.compositor.compositor_effects.has(sentinel),"binding refraction preserves existing camera effects")
	mirage.bind_camera(null)
	check(bench.camera.compositor==original and original.compositor_effects==[sentinel],"unbinding restores the prior camera compositor")
	bench.camera.compositor=null;sentinel.dispose()
	mirage.bind_camera(bench.camera)
	var before: int=mirage.passes
	bench.director.set_mirage_spectacle(0.,float(occurrence.bearing),123.)
	for i in range(8):await bench.get_tree().process_frame
	check(mirage.passes==before and not mirage.enabled,"inactive weather executes no refraction dispatches")
	var result := {"evidence_class":"INERT","scope":"native camera-local mirage optical/depth/ownership diagnostics; not occupied-world or river-site artistic acceptance","failures":failures,"occurrence":occurrence.date,"peak_displayed_signal":optical_signal,"dragged_near_red_samples":dragged_red,"compute_failure":mirage.failed,"passes":mirage.passes,"last_projection_parameters":mirage.last_projection_parameters,"frame_times":frame_times,"cached_snapshot_bytes":mirage.dimensions.x*mirage.dimensions.y*16,"primary_msaa":bench.get_viewport().msaa_3d,"paired_taa":bench.get_viewport().use_taa}
	FileAccess.open(out+"/mirage_review.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t")+"\n")
	print("SKYWATCH MIRAGE RESULT: ","PASS" if failures.is_empty() else "FAIL")
	bench.get_tree().quit(0 if failures.is_empty() else 1)

func traffic_review(bench: Node3D) -> void:
	bench.manager.set_process(false);bench.director.set_process(false)
	for effect: Node in bench.get_children():
		if effect is WeatherFX:effect.process_mode=Node.PROCESS_MODE_DISABLED;(effect as Node3D).hide()
	var out := OS.get_environment("SHOT_DIR");DirAccess.make_dir_recursive_absolute(out)
	var traffic: Node3D=bench.director._skyward
	check(traffic!=null and traffic.propellers.size()==5,"production V2 director installs native liner and five driven propellers")
	var minute := -1
	for i in range(700,760):
		bench.clock.configure_date(1929,5,12,i)
		var state: Dictionary=traffic.sample(bench.clock.absolute_minutes(),{})
		if bool(state.active) and absf(float(state.phase)-.5)<.04:minute=i;break
	check(minute>=0,"calendar-derived midday overflight can be reconstructed without a random stream")
	bench.clock.configure_date(1929,5,12,minute)
	bench.director._live_conditions={"temperature_c":16.,"cloud_high":0.,"precipitation_intensity":0.,"wind_speed_kmh":12.}
	bench.director._astronomy_second=-INF;bench.director._apply(float(minute));clear_optics(bench)
	traffic.update(bench.clock,bench.director._live_conditions)
	var first: Dictionary=traffic.last_sample.duplicate(true)
	var stamp: float=bench.clock.absolute_minutes()
	var next: Dictionary=traffic.sample(stamp+.001,bench.director._live_conditions)
	check((first.pose as Transform3D).origin.distance_to((next.pose as Transform3D).origin)<.15,"fractional calendar movement is continuous instead of eight-second lighting jumps")
	bench.camera.look_at(traffic.hull.global_position,Vector3.UP);set_field(bench,100.)
	var projected := Rect2(bench.camera.unproject_position(traffic.hull.global_position),Vector2.ZERO)
	var bounds: AABB=traffic.hull.mesh.get_aabb()
	for corner in range(8):projected=projected.expand(bench.camera.unproject_position(traffic.hull.global_transform*bounds.get_endpoint(corner)))
	var craft_region := Rect2i(projected.grow(8.)).intersection(Rect2i(Vector2i.ZERO,bench.get_viewport().get_visible_rect().size))
	await capture(bench,out+"/liner_over_queens.png")
	var shown := bench.get_viewport().get_texture().get_image()
	traffic.hide();await capture(bench,out+"/liner_control.png")
	var hidden := bench.get_viewport().get_texture().get_image()
	check(display_peak(shown,hidden,craft_region)>.05,"native passenger liner is optically visible over the actual V2 city horizon")
	bench.clock.configure_date(1929,1,3,60);traffic.update(bench.clock,{})
	bench.clock.configure_date(1929,5,12,minute);traffic.update(bench.clock,bench.director._live_conditions)
	check(first==traffic.last_sample,"returning out of order restores exact route, phase, pose and propeller angle")
	var steady := traffic.global_transform
	traffic.update(bench.clock,bench.director._live_conditions)
	check(traffic.last_sample==first and steady==traffic.global_transform,"paused campaign time cannot advance the craft")
	traffic.update(bench.clock,{"wind_speed_kmh":65.})
	check(not traffic.visible and bool(traffic.last_sample.weather_hold),"real severe-weather conditions hold fictional passenger traffic")
	traffic.update(bench.clock,bench.director._live_conditions)
	# Cover the complete projected craft, then compare with it hidden. No depth
	# override is allowed to put aircraft in front of nearby walls or ceilings.
	var blocker := MeshInstance3D.new();var block := BoxMesh.new();block.size=Vector3(180,100,2.)
	blocker.mesh=block;bench.add_child(blocker)
	blocker.global_position=bench.camera.global_position.lerp(traffic.hull.global_position,.4)
	blocker.look_at(bench.camera.global_position,Vector3.UP)
	var matte := StandardMaterial3D.new();matte.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;matte.albedo_color=Color(.02,.02,.02);blocker.material_override=matte
	await capture(bench,out+"/liner_world_blocked.png");var covered := bench.get_viewport().get_texture().get_image()
	traffic.hide();await capture(bench,out+"/liner_world_blocked_control.png")
	check(display_peak(covered,bench.get_viewport().get_texture().get_image(),craft_region)<.01,"ordinary foreground geometry fully occludes aircraft")
	blocker.queue_free()
	var result := {"evidence_class":"INERT","scope":"native liner calendar, rendering and depth diagnostics; not occupied-world travel, shadow, surface or artistic qualification","failures":failures,"local_minute":minute,"stamp":stamp,"phase":first.get("phase"),"source_triangles":24860}
	FileAccess.open(out+"/traffic_review.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t")+"\n")
	print("SKYWATCH TRAFFIC RESULT: ","PASS" if failures.is_empty() else "FAIL")
	bench.get_tree().quit(0 if failures.is_empty() else 1)

func catalogue_review(bench: Node3D) -> void:
	var baker := preload("res://scripts/building/skywatch_catalogue.gd")
	var raw := FileAccess.get_file_as_bytes(ProjectSettings.globalize_path("res://../art/data/astronomy/bsc5_catalog.dat.gz"))
	var text := raw.decompress_dynamic(5000000,FileAccess.COMPRESSION_GZIP).get_string_from_ascii()
	var parsed := baker.parse_catalogue(text)
	var rows: Array[Dictionary]=parsed.rows
	check(rows.size()==9096 and int(parsed.non_stellar)==14,"BSC5 retains 9096 stars and skips 14 non-stellar records")
	check(parsed.malformed.is_empty(),"every fixed-width stellar record parses without corruption")
	var prefixed_colour := false
	for row: Dictionary in rows:
		if int(row.hr)==2632:prefixed_colour=is_equal_approx(float(row.bv),1.15)
	check(prefixed_colour,"missing photometry uses K colour after the historical giant prefix gK1")
	var full := baker.pack_radec_texture(rows).get_image()
	var half := baker.pack_radec_texture(rows,true).get_image()
	var max_full := 0.;var max_half := 0.
	for i in range(rows.size()):
		var a := full.get_pixel(i%baker.WIDTH,i/baker.WIDTH)
		var b := half.get_pixel(i%baker.WIDTH,i/baker.WIDTH)
		max_full=maxf(max_full,absf(float(rows[i].ra)-a.r))
		max_half=maxf(max_half,absf(float(rows[i].ra)-b.r))
	check(rad_to_deg(max_full)*3600.<.1,"RGBAF raw RA retains sub-arcsecond precision")
	check(rad_to_deg(max_half)*3600.>100.,"raw RGBAH RA cannot meet telescope precision; measured rather than assumed")
	var stock := baker.bake(rows)
	check(int(stock.count)==9096,"spatial bake preserves every stellar record")
	var headers: Image=stock.headers.get_image()
	var points: Image=stock.points.get_image()
	var cursor := 0;var consistent := true
	for y in range(headers.get_height()):
		for x in range(headers.get_width()):
			var header := headers.get_pixel(x,y)
			consistent=consistent and int(header.r)==cursor
			for offset in range(int(header.g)):
				var p := points.get_pixel(cursor%baker.WIDTH,cursor/baker.WIDTH)
				var cell := baker.cube_cell(Vector3(p.r,p.g,p.b))
				consistent=consistent and cell==Vector3i(x,y%baker.CELLS,y/baker.CELLS)
				cursor+=1
	check(consistent and cursor==9096,"bucket headers own contiguous complete non-overlapping star ranges")
	check(int(stock.max_bucket)<32,"shader traversal can be bounded below 32 records per direction bucket")
	var folder := "res://assets/environment/stars"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	for key: String in ["headers","points","properties"]:
		check(ResourceSaver.save(stock[key],folder+"/bsc5_"+key+".res")==OK,"save baked native data texture "+key)
	var result := {"evidence_class":"INERT","scope":"offline BSC5 parser/data-texture bake, not rendered starfield acceptance", "stars":rows.size(),"non_stellar":parsed.non_stellar,"missing_colour":parsed.missing_colour,"max_bucket":stock.max_bucket,"ra_full_max_error_arcsec":rad_to_deg(max_full)*3600.,"ra_half_max_error_arcsec":rad_to_deg(max_half)*3600.,"failures":failures}
	var out := OS.get_environment("SHOT_DIR");DirAccess.make_dir_recursive_absolute(out)
	var file := FileAccess.open(out+"/catalogue_bake.json",FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t")+"\n");file.close()
	print("SKYWATCH CATALOGUE RESULT: ","PASS" if failures.is_empty() else "FAIL", " ",JSON.stringify(result))
	bench.get_tree().quit(0 if failures.is_empty() else 1)
