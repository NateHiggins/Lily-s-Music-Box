extends Node
## Owner-requested aesthetic/resolution diagnostics, never acceptance evidence.
var world: OrisonV2RuntimeRoot
var camera: Camera3D
var rows: Array=[]
var shots: Array=[]
var directory: String
func _ready() -> void:_run.call_deferred()
func review_wall_floor() -> bool:
	var failures: Array[String]=[]
	var counts: Dictionary={"limewash_plaster":0,"arcade_terrazzo":0}
	var textures: Dictionary={}
	for draw: MeshInstance3D in world.adapter.root.find_children("*","MeshInstance3D",true,false):
		if draw.mesh==null:continue
		for surface in draw.mesh.get_surface_count():
			var finish:=draw.get_active_material(surface) as ShaderMaterial
			if finish==null:continue
			var albedo: Texture2D=finish.get_shader_parameter("albedo_tex")
			if albedo==null:continue
			var key: String=""
			for candidate: String in counts:
				if albedo.resource_path.get_file()=="T_ai_materials_"+candidate+"_albedo.png":key=candidate;break
			if key.is_empty():continue
			counts[key]+=1
			var tile: float=float(MatLib.SETS[key][3])
			var scale: Vector2=finish.get_shader_parameter("mesh_uv_scale")
			if int(finish.get_shader_parameter("uv_mode"))!=0 or not scale.is_equal_approx(Vector2.ONE/tile):failures.append(str(draw.get_path())+": authored metre UV scale "+str(scale))
			if not bool(finish.get_shader_parameter("has_normal_tex")) or not is_equal_approx(float(finish.get_shader_parameter("normal_scale")),1.):failures.append(str(draw.get_path())+": physical normal response")
			for parameter: String in ["albedo_tex","normal_tex","rough_tex"]:
				var texture: Texture2D=finish.get_shader_parameter(parameter)
				if texture==null:failures.append(str(draw.get_path())+": missing "+parameter);continue
				if textures.has(texture.resource_path):continue
				var image:=texture.get_image()
				var complete: bool=image!=null and image.has_mipmaps() and image.get_mipmap_count()==int(floor(log(maxi(image.get_width(),image.get_height()))/log(2.)))
				textures[texture.resource_path]={"complete_loaded_mips":complete}
				if not complete:failures.append(texture.resource_path+": incomplete loaded mips")
	if int(counts.limewash_plaster)==0 or int(counts.arcade_terrazzo)==0:failures.append("Missing installed wall/floor finish family")
	var lobby:=world.adapter.root.get_node("F01_LOBBY/Floor") as MeshInstance3D
	var lobby_finish:=lobby.get_active_material(0) as ShaderMaterial
	if lobby_finish==null or (lobby_finish.get_shader_parameter("albedo_tex") as Texture2D).resource_path.get_file()!="T_ai_materials_arcade_terrazzo_albedo.png":failures.append("Lobby fine aggregate not installed")
	var result: Dictionary={"evidence_class":"INERT","scope":"Installed wall/floor maps, UV sampling and mip diagnostic; no gameplay, spatial or human acceptance", "surfaces":counts,"textures":textures,"failures":failures}
	FileAccess.open(directory.path_join("wall_floor_diagnostic.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("WALL FLOOR DIAGNOSTIC: ",JSON.stringify(result))
	return failures.is_empty()
func review_painted_trim() -> bool:
	# Optional diagnostic in the already-built production world: one render
	# launch covers the finish family and its actual loaded texture resources.
	var failures: Array[String]=[]
	var batches:=0;var windows:=0;var splices:=0;var textures: Dictionary={}
	for draw: GeometryInstance3D in world.find_children("*","GeometryInstance3D",true,false):
		var finish: Material
		if draw is MultiMeshInstance3D and draw.name=="HistoricMillwork":
			batches+=1;finish=draw.material_override
			if str(draw.get_meta("material_key",""))!="door_paint":failures.append(str(draw.get_path())+": coating identity")
		elif draw is MeshInstance3D and draw.name=="FittedWindowJoinery":
			windows+=1;finish=draw.get_active_material(0)
		elif draw is MeshInstance3D and draw.has_meta("native_front_trim_fit"):
			splices+=1;finish=draw.get_active_material(0)
		else:continue
		var maps: Array[Texture2D]=[]
		if finish is ShaderMaterial:
			maps=[finish.get_shader_parameter("albedo_tex"),finish.get_shader_parameter("rough_tex"),finish.get_shader_parameter("normal_tex")]
			if draw is MultiMeshInstance3D and not is_equal_approx(float(finish.get_shader_parameter("meters_per_tile")),.3):failures.append(str(draw.get_path())+": physical coating tile")
		elif finish is StandardMaterial3D:
			maps=[finish.albedo_texture,finish.roughness_texture,finish.normal_texture]
			if not finish.normal_enabled or finish.uv1_triplanar or not finish.uv1_scale.is_equal_approx(Vector3.ONE/.3):failures.append(str(draw.get_path())+": native coating UV/normal policy")
		else:failures.append(str(draw.get_path())+": missing coating material")
		for texture: Texture2D in maps:
			if texture==null:failures.append(str(draw.get_path())+": missing PBR map");continue
			if not texture.resource_path.get_file().begins_with("T_ai_materials_door_paint_"):failures.append(str(draw.get_path())+": exposed substrate map")
			if textures.has(texture.resource_path):continue
			var image:=texture.get_image()
			var complete: bool=image!=null and image.has_mipmaps() and image.get_mipmap_count()==int(floor(log(maxi(image.get_width(),image.get_height()))/log(2.)))
			textures[texture.resource_path]={"complete_loaded_mips":complete}
			if not complete:failures.append(texture.resource_path+": incomplete loaded mip chain")
	if batches==0 or windows==0 or splices==0:failures.append("Missing installed trim family")
	var result: Dictionary={"evidence_class":"INERT","scope":"Installed coating diagnostic, not gameplay or human acceptance", "batches":batches,"windows":windows,"splices":splices,"textures":textures,"failures":failures}
	FileAccess.open(directory.path_join("painted_trim_diagnostic.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("PAINTED TRIM DIAGNOSTIC: ",JSON.stringify(result))
	return failures.is_empty()
func size_text(value: Vector2i) -> Array:return [value.x,value.y]
func window_info() -> Dictionary:
	return {"mode":DisplayServer.window_get_mode(),"window_pixels":size_text(DisplayServer.window_get_size()),"screen_pixels":size_text(DisplayServer.screen_get_size()),"render_pixels":size_text(get_viewport().get_texture().get_size()),"scale_3d":get_viewport().scaling_3d_scale}
func resolution(value: Vector2i,fullscreen: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	if not fullscreen:DisplayServer.window_set_size(Vector2i(1920,1080))
	get_tree().root.content_scale_size=value
	get_tree().root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	get_viewport().scaling_3d_scale=1.
	await get_tree().process_frame;await get_tree().process_frame
func profile(label: String) -> void:
	for i in range(8):await RenderingServer.frame_post_draw
	var timings: Array[float]=[]
	for i in range(24):
		var start: int=Time.get_ticks_usec();await RenderingServer.frame_post_draw
		timings.append((Time.get_ticks_usec()-start)/1000.)
	timings.sort()
	var row: Dictionary=window_info()
	row.merge({"label":label,"frames":timings.size(),"median_frame_ms":timings[12],"p95_frame_ms":timings[22],"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"video_memory_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)})
	rows.append(row);print("4K PROFILE: ",JSON.stringify(row))
func aim(eye: Vector3,at: Vector3,fov: float=55.) -> void:
	camera.global_position=world.adapter.root.to_global(eye);camera.look_at(world.adapter.root.to_global(at));camera.fov=fov
func capture(label: String) -> bool:
	for i in range(12):await RenderingServer.frame_post_draw
	var start: int=Time.get_ticks_usec()
	var frame: Image=get_viewport().get_texture().get_image()
	var row: Dictionary=window_info();row["label"]=label;row["file"]=label+".png"
	row["image_pixels"]=size_text(frame.get_size())
	row["camera_world"]=str(camera.global_transform);row["fov"]=camera.fov
	if frame.get_size()!=Vector2i(3840,2160):push_error("Expected actual4K pixels, got "+str(frame.get_size()));return false
	var error: Error=frame.save_png(directory.path_join(label+".png"))
	row["readback_png_ms"]=(Time.get_ticks_usec()-start)/1000.
	shots.append(row);print("4K SHOT: ",JSON.stringify(row))
	return error==OK
func _run() -> void:
	directory=OS.get_environment("SHOT_DIR")
	if directory.is_empty() or DisplayServer.get_name()=="headless":get_tree().quit(1);return
	DirAccess.make_dir_recursive_absolute(directory)
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	CampaignTime.set_frozen_for_tests(true);CampaignClock.new().configure_date(1928,11,10,930)
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
	await resolution(Vector2i(1920,1080),false)
	var start: int=Time.get_ticks_msec()
	world=preload("res://scenes/building/orison_v2_runtime.tscn").instantiate();add_child(world)
	await get_tree().physics_frame;await get_tree().physics_frame
	if world.startup_failed or world.player==null:push_error("4K world startup failed");get_tree().quit(1);return
	if OS.get_environment("V2_FINISH_REVIEW")=="1" and not review_painted_trim():get_tree().quit(1);return
	if OS.get_environment("V2_WALL_FLOOR_REVIEW")=="1" and not review_wall_floor():get_tree().quit(1);return
	var build_ms: int=Time.get_ticks_msec()-start
	print("4K WORLD READY ms=",build_ms)
	world.player.set_physics_process(false);world.player.set_lamp_enabled(false);world.player.carried_device.set_capture_hidden(true)
	for layer: CanvasLayer in world.find_children("*","CanvasLayer",true,false):layer.hide()
	camera=Camera3D.new();camera.far=600.;world.add_child(camera);camera.make_current()
	Input.mouse_mode=Input.MOUSE_MODE_HIDDEN
	var atmosphere: Node=world.get_node("WakingAtmosphere")
	atmosphere.weather_manager._publish();atmosphere.director._apply(930.)
	aim(Vector3(0,1.65,-18),Vector3(0,2.9,-12.35),57.)
	await profile("1080p_windowed_same_entrance")
	await resolution(Vector2i(2560,1440),false);await profile("1440p_windowed_same_entrance")
	await resolution(Vector2i(3840,2160),false);await profile("4k_windowed_same_entrance")
	var ok: bool=await capture("01_orison_entrance_4k_windowed")
	await resolution(Vector2i(3840,2160),true);await profile("4k_borderless_fullscreen_same_entrance")
	aim(Vector3(-4.3,1.6,-8.25),Vector3(2.8,1.7,-5.15),68.)
	await profile("4k_fullscreen_lobby");ok=await capture("02_lobby_4k_fullscreen") and ok
	var tap: TapProp
	for node: Node in world.find_children("*","Node3D",true,false):
		if node is TapProp and node.fixture=="kitchen_sink" and node.unit=="2A":tap=node;break
	if tap==null:
		for node: Node in world.find_children("*","Node3D",true,false):
			if node is TapProp and node.fixture=="kitchen_sink":tap=node;break
	if tap==null:push_error("No installed kitchen for aesthetic view");get_tree().quit(1);return
	camera.global_position=tap.to_global(Vector3(.6,1.5,-1.4));camera.look_at(tap.to_global(Vector3(.12,.88,0)));camera.fov=55.
	await profile("4k_fullscreen_kitchen");ok=await capture("03_kitchen_4k_fullscreen") and ok
	var tank: Node3D=world.find_child("FittedHouseTank",true,false)
	if tank==null:push_error("No installed roof tank for aesthetic view");get_tree().quit(1);return
	camera.global_position=tank.to_global(Vector3(5.,3.6,6.));camera.look_at(tank.to_global(Vector3(0,2.4,0)));camera.fov=58.
	await profile("4k_fullscreen_roof");ok=await capture("04_rooftop_city_4k_fullscreen") and ok
	var file:=FileAccess.open(directory.path_join("resolution_diagnostic.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"evidence_class":"INERT","scope":"Posed aesthetic WIP only; no spatial/runtime/human acceptance.","date":"1928-11-10 15:30 frozen","world_build_ms":build_ms,"profiles":rows,"shots":shots,"notes":"Wall frame times include CPU and GPU synchronization; not GPU-only timings. Fullscreen does not imply a native4K monitor; actual window/screen/render/image pixels recorded separately. Existing production lighting/materials retained; player lamp/HUD hidden for aesthetic capture."},"\t"));file.close()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	print("V2 4K WIP CAPTURE: ","PASS" if ok and shots.size()==4 else "FAIL"," shots=",shots.size())
	get_tree().quit(0 if ok and shots.size()==4 else 1)
