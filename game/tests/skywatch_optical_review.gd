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
