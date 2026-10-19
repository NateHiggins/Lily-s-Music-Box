extends Node
## Owner-requested aesthetic/resolution diagnostics, never acceptance evidence.
var world: OrisonV2RuntimeRoot
var camera: Camera3D
var rows: Array=[]
var shots: Array=[]
var directory: String
func _ready() -> void:_run.call_deferred()
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
