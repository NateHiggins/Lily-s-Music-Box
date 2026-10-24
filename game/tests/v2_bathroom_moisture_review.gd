extends "res://tests/v2_bathroom_optics_profile.gd"
## Actual route first, then untimed optical/weather controls and captures.
var _moisture: Node
var _states: Array=[]
var _signal_checks:=0
var _signal_mismatches:=0
var _before_decay:=0.0

func _init() -> void:route_label="V2 BATHROOM MOISTURE REVIEW"

func _route() -> void:
	_moisture=world.bathroom_moisture
	if not _require(is_instance_valid(_moisture) and not _moisture._sources.is_empty(),"production moisture owner binds installed showers"):return
	for source: Dictionary in _moisture._sources:source.tap.flow_changed.connect(_observe_flow.bind(source))
	await super._route()
	if failures.is_empty():
		_require(_signal_checks>0 and _signal_mismatches==0,"actual valve signals update spray before returning from input")
		_verify_surfaces()
		await _visual_review()
		var taps: Array=[];var panes: Array=[]
		for source: Dictionary in _moisture._sources:taps.append(source.tap)
		for surface: Dictionary in _moisture._surfaces:panes.append(surface.pane)
		var mechanical_before: Dictionary=_tap.mechanism_snapshot()
		_moisture.shutdown()
		_require(_tap.mechanism_snapshot()==mechanical_before,"optical shutdown preserves the authoritative valve/curtain/save state")
		for tap: TapProp in taps:
			for connection: Dictionary in tap.flow_changed.get_connections():_require(connection.callable.get_object()!=_moisture,"optical shutdown disconnects each immediate-flow callback")
		for pane: MeshInstance3D in panes:_require(pane.material_overlay==null,"optical shutdown restores each original glass surface")
		_require(_moisture._sources.is_empty() and _moisture._rooms.is_empty() and _moisture._retiring.is_empty(),"optical shutdown releases world-owned caches and retirement work")
	var output:=OS.get_environment("SHOT_DIR")
	FileAccess.open(output.path_join("moisture.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Actual valve/input route; optical review and injected weather controls follow timed route. No runtime_contract or human acceptance.","signal_checks":_signal_checks,"signal_mismatches":_signal_mismatches,"states":_states,"failures":failures},"\t"))

func _observe_flow(source: Dictionary) -> void:
	if not is_instance_valid(source.spray):return
	_signal_checks+=1
	if source.spray.emitting!=(float(source.tap.get_flow_state().flow)>0.0001):_signal_mismatches+=1

func _source() -> Dictionary:
	for source: Dictionary in _moisture._sources:
		if source.tap==_tap:return source
	return {}

func _measure(label: String,look_at: Vector3,seconds: float=8.0) -> void:
	await super._measure(label,look_at,seconds)
	_phase=label+"_checks_excluded"
	var source: Dictionary=_source()
	var room: Dictionary=_moisture._rooms[source.room]
	var snapshot: Dictionary={"phase":label,"room":source.room,"humidity":room.humidity,"target":room.target,"emitting":source.spray.emitting,"steam_visible":room.steam.visible,"mirror_wet":_mirror_owner.mirror_surface().get_meta("v2_condensation",0.0)}
	_states.append(snapshot)
	if label in ["dry_shower","dry_mirror","cold_shower"]:_require(is_zero_approx(float(room.humidity)),"dry/cold input creates no steam: "+label)
	if label=="cold_shower":_require(source.spray.emitting and not room.steam.visible,"cold input produces spray without local steam")
	if label=="hot_developing":_require(float(room.humidity)>0.2 and room.steam.visible,"actual hot flow develops bounded local steam")
	if label=="hot_mirror":
		_before_decay=float(room.humidity)
		_require(float(snapshot.mirror_wet)>0.2,"same room moisture reaches the active mirror front")
	if label=="off_mirror_decay":
		_require(float(room.humidity)<_before_decay and float(room.humidity)>0.0,"shutoff dries gradually rather than erasing condensation")
		_require(not source.spray.emitting and RenderingServer.particles_is_inactive(source.spray.get_base()),"shut spray retires its GPU simulation")

func _verify_surfaces() -> void:
	var inspector:=preload("res://tests/orison_v2_surface_inventory.gd").new()
	var mesh: Dictionary=inspector._mesh(_moisture._drop_mesh)
	var draw_rows: Array=[];var mesh_rows: Dictionary={};var materials: Dictionary={}
	mesh_rows["spray"]=mesh;materials["spray"]=inspector._material(_moisture._water)
	draw_rows.append({"path":"spray","owner":"moisture","owner_script":_moisture.get_script().resource_path,"visible":true,"mesh":"spray","materials":["spray"],"instances":_moisture._sources[0].spray.amount,"surface_role":"physical"})
	for index in _moisture._surfaces.size():
		var surface: Dictionary=_moisture._surfaces[index];var key: String=str(index)
		mesh_rows[key]=inspector._mesh(surface.pane.mesh);materials[key]=inspector._material(surface.material)
		draw_rows.append({"path":str(surface.pane.get_path())+"/MoistureFilm","owner":"moisture","owner_script":_moisture.get_script().resource_path,"visible":true,"mesh":key,"materials":[key],"instances":1,"surface_role":"physical"})
		_require(surface.material.get_shader_parameter("normal_tex")==_moisture._water.normal_texture,"glass film shares registered water normal map: "+key)
	var output: String=OS.get_environment("SHOT_DIR").path_join("moisture_surfaces.json")
	FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify({"schema":"orison.v2-moisture-surfaces.diagnostic.v1","evidence_class":"INERT","scope":"New spray mesh and optical film materials on existing panes only; no whole-world qualification.","passage_state":world.passage_region.residency.state,"draws":draw_rows,"meshes":mesh_rows,"materials":materials,"textures":inspector.texture_rows,"unhandled_geometry":[]},"\t"))
	inspector.free()

func _shot(label: String,target: Vector3) -> void:
	_phase="visual_capture_excluded"
	var old_fov:=player.camera.fov
	player.camera.fov=75.0 if label.contains("spray") else 38.0;player.camera.look_at(target)
	for frame in 12:await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT_DIR").path_join(label+".png"))
	player.camera.fov=old_fov

func _visual_review() -> void:
	_phase="untimed_visual_controls_excluded"
	var source: Dictionary=_source();var room: Dictionary=_moisture._rooms[source.room]
	# Real drying, with original flow/heat authority untouched.
	var start:=Time.get_ticks_msec()
	var elapsed_sim:=0.0;var drying: Array=[];var next_sample:=0.0
	while float(room.humidity)>0.003 and Time.get_ticks_msec()-start<90000:
		await get_tree().process_frame
		elapsed_sim+=get_process_delta_time()
		if elapsed_sim>=next_sample:
			drying.append({"simulation_s":elapsed_sim,"wall_s":(Time.get_ticks_msec()-start)/1000.0,"humidity":room.humidity,"target":room.target,"flow":_tap.get_flow_state(),"processing":_moisture.is_processing()})
			next_sample+=5.0
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("drying.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","samples":drying,"simulation_s":elapsed_sim,"wall_s":(Time.get_ticks_msec()-start)/1000.0,"final_humidity":room.humidity},"\t"))
	if not _require(float(room.humidity)<=0.003,"local steam naturally decays after actual shutoff"):return
	var water_view: Vector3=_tap._stream.global_position+Vector3.DOWN*0.55
	await _shot("dry_mirror",_mirror_owner.mirror_center())
	if not await _drag_part(_tap,_tap._handles[1].global_position,PI*0.5,"visual_cold_on"):return
	await get_tree().create_timer(2.0).timeout
	await _shot("cold_spray_cone",water_view)
	if not await _drag_part(_tap,_tap._handles[1].global_position,0.0,"visual_cold_off"):return
	if not await _drag_part(_tap,_tap._handles[0].global_position,PI*0.5,"visual_hot_on"):return
	await get_tree().create_timer(12.0).timeout
	await _shot("hot_spray_steam",water_view)
	await get_tree().create_timer(10.0).timeout
	await _shot("fogged_mirror",_mirror_owner.mirror_center())
	await _verify_steam_cap(room,water_view)
	if not await _drag_part(_tap,_tap._handles[0].global_position,0.0,"visual_hot_off"):return
	await _rain_review()
	await _ordering_control()

func _rain_review() -> void:
	var weather: Node=world.get_node("WeatherFX")
	var manager: Node=world.get_node("WakingAtmosphere").weather_manager
	var manager_running:=manager.is_processing();manager.set_process(false)
	_require(_moisture.exposure_ready,"window exposure cache waits for completed physical geometry")
	var original: Dictionary=weather._live_conditions.duplicate(true)
	var wet: Dictionary=original.duplicate(true);wet.rain_intensity=1.0;wet.wet=true
	weather.set_live_conditions(wet)
	await get_tree().create_timer(10.0).timeout
	var nearest: Dictionary={};var distance:=INF;var exposed:=0;var sheltered:=0
	for surface: Dictionary in _moisture._surfaces:
		if surface.mirror:continue
		if surface.exposed:
			exposed+=1
			_require(float(surface.outside)>0.8,"injected rain wets exposed exterior glass face")
			var candidate: float=surface.pane.global_position.distance_squared_to(player.camera.global_position)
			if candidate<distance:nearest=surface;distance=candidate
		else:
			sheltered+=1;_require(is_zero_approx(float(surface.outside)),"sheltered glass exterior remains dry")
		if not _moisture._rooms.has(surface.room):_require(is_zero_approx(float(surface.inside)),"rain does not wet a dry room-side face")
	_require(exposed>0 and sheltered>0,"installed windows include exposed and sheltered rain controls")
	_states.append({"phase":"injected_rain_untimed","exposed":exposed,"sheltered":sheltered,"nearest":str(nearest.get("pane")),"nearest_distance_squared":distance})
	if not nearest.is_empty() and distance<144.0:
		# Render-only viewpoints, not player access or exterior traversal proof.
		var camera:=Camera3D.new();world.add_child(camera);camera.fov=55.0;camera.attributes=player.camera.attributes
		var pane: MeshInstance3D=nearest.pane
		var axis:=0 if nearest.material.get_shader_parameter("along_z") else 2
		var normal:=Vector3.ZERO;normal[axis]=float(nearest.material.get_shader_parameter("outside_sign"))
		normal=(pane.global_basis*normal).normalized()
		for side: float in [-1.0,1.0]:
			camera.global_position=pane.global_position+normal*side*0.85;camera.look_at(pane.global_position);camera.make_current()
			for frame in 12:await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT_DIR").path_join("rain_inside.png" if side<0.0 else "rain_outside.png"))
		camera.free();player.camera.make_current()
	weather.set_live_conditions(original);manager.set_process(manager_running)

func _ordering_control() -> void:
	_moisture.set_process(false)
	var rows: Array=[];var chosen: Dictionary={};var distance:=INF
	for surface: Dictionary in _moisture._surfaces:
		if surface.mirror:continue
		var pane: MeshInstance3D=surface.pane
		rows.append({"path":str(pane.get_path()),"visible":pane.visible,"visible_in_tree":pane.is_visible_in_tree(),"bounds":str(pane.mesh.get_aabb()),"basis":str(pane.global_basis),"overlay_active":pane.material_overlay==surface.material,"inside":surface.inside,"outside":surface.outside,"axis_z":surface.material.get_shader_parameter("along_z"),"sign":surface.material.get_shader_parameter("outside_sign"),"room":surface.room,"exposed":surface.exposed})
		var d:=pane.global_position.distance_squared_to(player.camera.global_position)
		if surface.exposed and d<distance:chosen=surface;distance=d
	var output:=OS.get_environment("SHOT_DIR")
	if not _require(not chosen.is_empty(),"actual exposed pane available for transparent-order control"):return
	var pane: MeshInstance3D=chosen.pane
	var normal:=Vector3.ZERO;normal[0 if chosen.material.get_shader_parameter("along_z") else 2]=float(chosen.material.get_shader_parameter("outside_sign"))
	normal=(pane.global_basis*normal).normalized()
	var camera:=Camera3D.new();world.add_child(camera);camera.fov=55.0;camera.attributes=player.camera.attributes
	camera.global_position=pane.global_position-normal*0.85;camera.look_at(pane.global_position);camera.make_current()
	var images: Array[Image]=[]
	for mode: String in ["water_priority","without_film","positive_window_mask"]:
		if mode=="without_film":pane.material_overlay=null
		if mode=="positive_window_mask":
			var debug:=ShaderMaterial.new();debug.shader=Shader.new()
			debug.shader.code="shader_type spatial; render_mode unshaded,cull_disabled,depth_draw_never; void fragment(){ ALBEDO=vec3(1.0,0.0,1.0); ALPHA=0.65; }"
			debug.render_priority=1;pane.material_overlay=debug
		for frame in 12:await RenderingServer.frame_post_draw
		var image:=get_viewport().get_texture().get_image();image.save_png(output.path_join(mode+".png"));images.append(image)
	var differences: Array=[]
	for compare in [0,2]:
		var change:=0.0;var samples:=0
		for y in range(int(images[1].get_height()*0.25),int(images[1].get_height()*0.85),4):
			for x in range(0,int(images[1].get_width()*0.5),4):
				var a:=images[compare].get_pixel(x,y);var b:=images[1].get_pixel(x,y)
				change+=absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b);samples+=3
		differences.append(change/samples)
	_require(float(differences[0])>0.003,"wet film makes a visible change against its removed control")
	_require(float(differences[1])>0.05,"positive mask proves the selected pane renders above refractive glass")
	pane.material_overlay=chosen.material;camera.free();player.camera.make_current();_moisture.set_process(true)
	FileAccess.open(output.path_join("rain_probe.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Untimed weather injection, render-only eye placement and temporary optical positive/removed controls. No traversal or runtime qualification.","states":_states,"surfaces":rows,"chosen":str(pane.get_path()),"rgb_mean_differences":differences,"failures":failures},"\t"))

func _verify_steam_cap(room: Dictionary,water_view: Vector3) -> void:
	var start:=Time.get_ticks_msec();var next_sample:=0;var samples: Array=[]
	while absf(float(room.humidity)-float(room.target))>.02 and Time.get_ticks_msec()-start<40000:
		await get_tree().process_frame
		if Time.get_ticks_msec()-start>=next_sample:
			samples.append({"wall_s":(Time.get_ticks_msec()-start)/1000.0,"humidity":room.humidity,"thermal_target":room.target,"flow":_tap.get_flow_state()})
			next_sample+=500
	_require(float(room.target)>.5 and absf(float(room.humidity)-float(room.target))<=.02 and float(room.humidity)<=1.0,"continued hot flow accumulates room steam up to its live thermal cap")
	await get_tree().create_timer(5.0).timeout
	_require(absf(float(room.humidity)-float(room.target))<=.02 and float(room.humidity)<=1.0,"continued hot flow holds room steam at its thermal cap without runaway density")
	samples.append({"wall_s":(Time.get_ticks_msec()-start)/1000.0,"humidity":room.humidity,"thermal_target":room.target,"flow":_tap.get_flow_state()})
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("steam_cap.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Actual hot input, temperature-dependent steady room moisture and global cap control","samples":samples,"failures":failures},"\t"))
	await _shot("capped_spray_room_steam",water_view)
