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
	for frame in range(30): await bench.get_tree().process_frame
	var frames: Array[float]=[]
	var last := Time.get_ticks_usec()
	for frame in range(120):
		await bench.get_tree().process_frame
		var now := Time.get_ticks_usec()
		frames.append(float(now-last)/1000.);last=now
	var ordered := frames.duplicate();ordered.sort()
	return {"vertical_field_degrees":field,"relief":relief,"raw_frame_ms":frames,"p50":ordered[60],"p95":ordered[114],"p99":ordered[118],"max":ordered[-1],"scope":"clear optical bench, not occupied-world route or isolated GPU attribution"}

func capture(bench: Node3D,path: String) -> void:
	for frame in range(20): await bench.get_tree().process_frame
	await RenderingServer.frame_post_draw
	bench.get_viewport().get_texture().get_image().save_png(path)
