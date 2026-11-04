extends Node3D
## INERT offline rooftop showcase; detached optical time,never gameplay proof.
const Runtime=preload("res://scenes/building/orison_v2_runtime.tscn")
const Temporal=preload("res://scripts/game/prologue_temporal_sky.gd")
const Ephemeris=preload("res://scripts/building/celestial_ephemeris.gd")
const Optics=preload("res://scripts/building/v2_background_window_material.gd")
var failures:Array[String]=[]

func check(ok:bool,label:String)->bool:
	if not ok:failures.append(label);push_error(label)
	return ok

func _ready()->void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	run.call_deferred()

func run()->void:
	var output:=OS.get_environment("SHOT_DIR")
	if not check(not output.is_empty() and DisplayServer.get_name()!="headless","windowed output required"):get_tree().quit(2);return
	DirAccess.make_dir_recursive_absolute(output.path_join("frames"))
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	CampaignTime.set_frozen_for_tests(true)
	GameBoot.settings.weather_network_enabled=false
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var clock:=CampaignClock.new()
	check(clock.configure_date(1929,2,23,8*60),"authored winter showcase date")
	var start:=float(Time.get_unix_time_from_datetime_dict(clock.utc_datetime()))
	var midpoint:=Time.get_datetime_dict_from_unix_time(int(start+43200))
	var moon:Vector3=Ephemeris.moon_direction(midpoint,40.75,-73.92)
	var bearing:=Vector3(moon.x,0,moon.z).normalized()
	var world:=Runtime.instantiate() as OrisonV2RuntimeRoot
	add_child(world)
	while world.startup_ms<=0 and not world.startup_failed:await get_tree().process_frame
	if not check(not world.startup_failed,"complete installed city starts"):get_tree().quit(1);return
	world.player.set_physics_process(false);world.player.set_lamp_enabled(false)
	world.service_set_carrier.set_capture_hidden(true)
	for layer:CanvasLayer in world.find_children("*","CanvasLayer",true,false):layer.hide()
	world.process_mode=Node.PROCESS_MODE_DISABLED
	var saved_clock:Dictionary=RealityState.data.campaign_clock.duplicate(true)
	var camera:=Camera3D.new();add_child(camera)
	camera.cull_mask=world.player.camera.cull_mask;camera.fov=92.;camera.far=5000.
	camera.global_position=world.adapter.root.to_global(Vector3(-14,27,-9));camera.make_current()
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var projection:=Temporal.new();add_child(projection)
	projection.world=world;projection.camera=camera;projection.director=world.day_night_director
	projection.manager=world.get_node("WakingAtmosphere").weather_manager
	projection._view_extreme=preload("res://scripts/building/queens_weather_extension.gd").new()
	projection.director._campaign_clock=projection.view_clock
	projection.director.extreme_weather=projection._view_extreme
	var materials:Dictionary={}
	for draw:MeshInstance3D in world.get_node("CityShells").find_children("*","MeshInstance3D",true,false):
		var material:=draw.material_override as ShaderMaterial
		if material!=null and material.shader==Optics.InteriorShader:materials[material.get_instance_id()]=material
	check(materials.size()>0,"installed occupied-window materials found")
	var samples:Array=[]
	for index:int in 300:
		var fraction:=float(index)/299.
		projection.sampled_utc=start+fraction*86400.
		if not check(projection.view_clock.seek_utc(projection.sampled_utc),"detached date sample"):break
		var direction:Vector3=bearing.rotated(Vector3.UP,deg_to_rad(lerpf(-30.,30.,fraction)))
		direction.y=.10;camera.look_at(camera.global_position+direction*100.)
		projection._publish()
		for material:ShaderMaterial in materials.values():Optics.sync_clock(material,projection.view_clock)
		# Let presentation/TAA settle before the fixed-count frame readback.
		for settle:int in (60 if index==0 else 2):await RenderingServer.frame_post_draw
		var name:="frames/frame_%04d.png"%index
		check(get_viewport().get_texture().get_image().save_png(output.path_join(name))==OK,"save showcase frame")
		if index%30==0 or index==299:
			samples.append({"frame":index,"utc":projection.view_clock.utc_datetime(),"eye":str(camera.global_position),"direction":str(direction)})
			print("SKY CYCLE FRAME ",index,"/299")
	check(RealityState.data.campaign_clock==saved_clock,"optical day never advances gameplay clock")
	var record:Dictionary={"evidence_class":"INERT","scope":"Offline complete24hour authored sky/occupied-window projection;60degree rooftop pan;not real-time performance,played access or artistic acceptance","frames":300,"fps":30,"duration_seconds":10,"start_utc":start,"end_utc":start+86400,"date":"1929-02-23 08:00 to1929-02-24 08:00 local","viewport":str(get_viewport().get_visible_rect().size),"samples":samples,"failures":failures}
	FileAccess.open(output.path_join("capture.json"),FileAccess.WRITE).store_string(JSON.stringify(record,"\t"))
	projection.free();camera.free();world.shutdown_for_tests();world.free()
	for drain:int in 8:await get_tree().process_frame
	print("CITY SKY CYCLE CAPTURE: ","PASS" if failures.is_empty() else "FAIL")
	get_tree().quit(0 if failures.is_empty() else 1)
