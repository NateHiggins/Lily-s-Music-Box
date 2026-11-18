extends Node3D
## Nearby installed venue VISUAL intake only. Camera moves; no actor is moved.
const ENTRY := "res://data/orison_v2/harukiya_entry.json"
const EXPECTED_SHOTS := ["open_hours_upper_descent_closed_leaf","open_hours_lower_closed_leaf","open_hours_lower_half_leaf","open_hours_lower_full_leaf","open_hours_cyan_context","open_hours_magenta_context","closed_hours_magenta_context","closed_hours_cyan_context","closed_hours_upper_descent"]
const ENTRY_INPUTS := [
	"res://scripts/building/orison_v2_bar_entry.gd",
	"res://scripts/building/harukiya_entry_retirement.gd",
	"res://scripts/building/orison_v2_bar_entry_door.gd",
	"res://scripts/building/orison_v2_bar_entry_light.gd",
	"res://data/orison_v2/harukiya_entry_retirement.json",
	"res://assets/building/floor_01_cells/shop_bar.gltf",
	"res://assets/building/floor_01_cells/shop_bar.bin",
	"res://data/building_layout.json",
	"res://data/runtime_material_sets.json",
	"res://data/floor_01_cell_registry.json"
]
var bar: OrisonV2BarRegion
var door: DoorProp
var camera: Camera3D
var rig: LightRig
var directory := ""
var failures: Array[String] = []
var shots: Array[Dictionary] = []
var motion_frames: Array[Dictionary] = []
const LIGHTING_SHOTS := ["lighting_stage", "lighting_counter", "lighting_pool", "lighting_gallery", "lighting_room"]
var expected_shots: Array = EXPECTED_SHOTS.duplicate()
const MOTION_FRAMES_PER_PATH := 120
var prior_data: Dictionary
var prior_hash := ""
var prior_mode: int
var prior_mouse: int
var prior_frozen: bool
var preview_owned := false
var inputs: Dictionary = {}
var logger
var prior_initialized := false
var deadline := 0
var clock := CampaignClock.new()
func check(ok: bool, label: String) -> bool:
	if not ok: failures.append(label); push_error("ENTRY VISUAL: " + label)
	return ok
func _ready() -> void: run.call_deferred()
func hashes() -> Dictionary:
	var root := ProjectSettings.globalize_path("res://..").simplify_path()
	var runtime: Array = []; var physical: Array = []
	check(OS.execute("python",[root.path_join("tools/run_receipt.py"),"digest","--root",root],runtime)==0,"runtime digest")
	check(OS.execute("python",[root.path_join("tools/v2_physical_inputs.py"),"--root",root],physical)==0,"physical digest")
	var result := {"runtime":str(runtime[0]).strip_edges() if not runtime.is_empty() else "", "physical":str(physical[0]).strip_edges() if not physical.is_empty() else ""}
	for path: String in [get_script().resource_path,scene_file_path,ENTRY,"res://scripts/building/orison_v2_bar_region.gd","res://scripts/building/light_rig.gd","res://scripts/building/harukiya_state_director.gd","res://scripts/props/door_prop.gd","res://tests/guide_bell_error_capture.gd"] + ENTRY_INPUTS:
		check(FileAccess.file_exists(path),"input exists " + path); result[path]=FileAccess.get_sha256(path)
	var decoded: Variant=JSON.parse_string(FileAccess.get_file_as_string(ENTRY))
	if not check(decoded is Dictionary,"entry input parses as object"):return result
	var spec: Dictionary=decoded
	for key: String in ["asset","door_asset","fixture_asset"]:
		var path: String=str(spec.get(key,""));check(FileAccess.file_exists(path),"native input " + key);result[path]=FileAccess.get_sha256(path)
	return result
func wait_seconds(seconds: float) -> void:
	var until := Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<until and failures.is_empty():
		if deadline>0 and Time.get_ticks_msec()>deadline:check(false,"90-second post-startup visual deadline");return
		await get_tree().process_frame
func view(at: Vector3, target: Vector3, fov: float=70.0) -> void:
	camera.global_position=bar.to_global(GameBoot.b2g([at.x,at.y,at.z]))
	camera.look_at(bar.to_global(GameBoot.b2g([target.x,target.y,target.z])),Vector3.UP)
	camera.fov=fov;camera.make_current()
func fixture_state() -> Array:
	var result: Array=[]
	for id: String in ["F01_BAR_LT_ENTRY_CYAN","F01_BAR_LT_ENTRY_MAGENTA","F01_BAR_LT_STAIR"]:
		var light:=bar.actors.get_node_or_null(id) as LightFixtureProp
		if not check(light!=null and light.light!=null,"original light owner exists " + id):continue
		var row: Dictionary={"id":id,"owner_instance_id":light.get_instance_id(),"energy":light.light.light_energy,"visible":light.light.visible,"colour":light.light.light_color}
		var surfaces: Variant=light.get("_tube_surfaces") if id!="F01_BAR_LT_STAIR" else null
		if surfaces is Array:
			row.emission=[]
			for material: ShaderMaterial in surfaces:row.emission.append(material.get_shader_parameter("emission_energy"))
		result.append(row)
	return result
func capture(label: String, settle: bool=true) -> void:
	if settle:await wait_seconds(1.2)
	if not failures.is_empty():return
	await RenderingServer.frame_post_draw
	var angle: float=float(door.mechanism_snapshot().angle)
	if label.contains("half_leaf"):
		if not check(absf(angle/door.motion_target_angle(true))>=.35 and absf(angle/door.motion_target_angle(true))<=.75,"half-leaf frame observes real intermediate motion"):return
	var path:=directory.path_join(label+".png")
	var img:=get_viewport().get_texture().get_image()
	if not check(img!=null and img.save_png(path)==OK,"capture " + label):return
	shots.append({"name":label,"path":path,"sha256":FileAccess.get_sha256(path),"camera_world":camera.global_transform,"fov":camera.fov,"door_instance_id":door.get_instance_id(),"door_angle":angle,"door_fraction":absf(angle/door.motion_target_angle(true)),"hours_state":bar.hours._state,"fixtures":fixture_state(),"minute":clock.minute_of_day()})
func until_door(fraction: float, opening: bool) -> bool:
	var until:=Time.get_ticks_msec()+8000
	while Time.get_ticks_msec()<until and failures.is_empty():
		var at: float=absf(float(door.mechanism_snapshot().angle)/door.motion_target_angle(true))
		if (opening and at>=fraction) or (not opening and at<=fraction):return true
		await get_tree().physics_frame
	return check(false,"ordinary door reaches requested observed angle; no forced pose")
func hours(minute: int, expected: int) -> bool:
	if not check(clock.configure_date(1929,6,14,minute),"preview civil clock scenario"):return false
	# Let the ordinary director's seven-second cadence apply; no _apply override.
	await wait_seconds(8.2)
	return check(bar.hours.enabled and bar.hours._state==expected,"ordinary venue hours state")
func motion_path(label: String, start: Vector3, end: Vector3, target: Vector3) -> void:
	var folder := directory.path_join("motion_frames")
	if not check(DirAccess.make_dir_recursive_absolute(folder)==OK,"motion frame directory"):return
	for index in MOTION_FRAMES_PER_PATH:
		if not failures.is_empty():return
		if Time.get_ticks_msec()>deadline:check(false,"90-second post-startup visual deadline");return
		if label=="door_swing" and index in [0,60]:door.npc_set_open(index==60)
		var t: float=float(index)/float(MOTION_FRAMES_PER_PATH-1)
		view(start.lerp(end,t),target,82.0)
		await RenderingServer.frame_post_draw
		var owner: Node3D=bar.wall_occlusion
		if not check(is_instance_valid(owner) and owner.enabled and owner.errors.is_empty(),"guarded wall owner stays valid during "+label):return
		var frame := get_viewport().get_texture().get_image()
		if not check(frame!=null,"motion frame readback"):return
		frame.convert(Image.FORMAT_RGB8)
		var path := folder.path_join("frame_%04d.jpg"%motion_frames.size())
		if not check(frame.save_jpg(path,.9)==OK,"motion frame saved"):return
		motion_frames.append({"path":path,"sha256":FileAccess.get_sha256(path),"segment":label,"index":index,"camera":camera.global_transform,"fov":camera.fov,"observed_monotonic_ms":Time.get_ticks_msec(),"door_angle":door.mechanism_snapshot().angle,"wall_occlusion_enabled":owner.enabled})

func occlusion_motion() -> void:
	await motion_path("threshold_in",Vector3(5.6,-34.425,-1.73),Vector3(3.45,-34.425,-1.73),Vector3(2.2,-34.425,-1.5))
	await motion_path("threshold_out",Vector3(3.45,-34.425,-1.73),Vector3(5.6,-34.425,-1.73),Vector3(5.86,-34.425,-1.7))
	await motion_path("gallery_edge",Vector3(-4.65,-34.425,1.41083),Vector3(.2,-34.425,1.41083),Vector3(0,-32,1.45))
	await motion_path("door_swing",Vector3(5.6,-34.425,-1.73),Vector3(5.6,-34.425,-1.73),Vector3(4.15,-34.425,-1.73))
	if not failures.is_empty():return
	check(await until_door(.99,true),"door returns fully open after ordinary swing commands")

func run() -> void:
	directory=OS.get_environment("SHOT_DIR")
	if not check(not directory.is_empty() and DirAccess.make_dir_recursive_absolute(directory)==OK,"explicit SHOT_DIR"):get_tree().quit(2);return
	prior_data=RealityState.data;prior_hash=JSON.stringify(prior_data).sha256_text();prior_mode=GameBoot.launch_mode;prior_mouse=Input.mouse_mode;prior_frozen=CampaignTime._frozen_for_tests
	prior_initialized=true
	logger=preload("res://tests/guide_bell_error_capture.gd").new();OS.add_logger(logger)
	inputs=hashes()
	if not failures.is_empty():await finish();return
	preview_owned=RealityState.begin_preview_campaign(self)
	if not check(preview_owned,"exclusive nonpersistent preview grant"):await finish();return
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC;CampaignTime.set_frozen_for_tests(true)
	if not check(clock.configure_date(1929,6,14,1260),"preview Friday21:00"):await finish();return
	var environment:=WorldEnvironment.new();environment.name="WorldEnvironment";environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color(.035,.04,.05)
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color(.7,.72,.76);environment.environment.ambient_light_energy=.18
	add_child(environment);get_viewport().use_taa=true
	camera=Camera3D.new();camera.name="ReviewCamera";add_child(camera);camera.make_current()
	bar=OrisonV2BarRegion.new();bar.name="ProductionHarukiya";add_child(bar)
	if not check(not bar.startup_failed and bar.destination!=null and bar.hours!=null,"actual bar pipeline starts"):await finish();return
	door=bar.doors.get("F01_BAR_RED_DOOR") as DoorProp
	if not check(door!=null and door.leaf_state!="locked","actual red door available unlocked in authored preview"):await finish();return
	if not check(DisplayServer.get_name()!="headless","windowed hidden renderer required"):await finish();return
	rig=LightRig.new();rig.name="LightRig";add_child(rig)
	deadline=Time.get_ticks_msec()+90000
	view(Vector3(4.8,-28.0,1.65),Vector3(4.8,-31.7,-.65),78)
	if not await hours(1260,HarukiyaStateDirector.BarState.OPEN):await finish();return
	door.npc_set_open(false)
	if not await until_door(.01,false):await finish();return
	await capture("open_hours_upper_descent_closed_leaf")
	view(Vector3(5.60,-34.425,-1.73),Vector3(4.15,-34.425,-1.73),82)
	await capture("open_hours_lower_closed_leaf")
	# Authored mechanical command only. No direct leaf pose or actor teleport.
	door.npc_set_open(true)
	if not await until_door(.45,true):await finish();return
	await capture("open_hours_lower_half_leaf",false)
	if not await until_door(.99,true):await finish();return
	await capture("open_hours_lower_full_leaf")
	if OS.get_environment("ENTRY_OCCLUSION_MOTION")=="1":await occlusion_motion()
	if OS.get_environment("BAR_LIGHTING_REVIEW")=="1":
		expected_shots.append_array(LIGHTING_SHOTS)
		var views := [
			[Vector3(-2.0,-33.8,-1.28),Vector3(-1.8,-36.7,-1.4)],
			[Vector3(-4.7,-32.1,-1.28),Vector3(-1.8,-29.6,-1.4)],
			[Vector3(-10.1,-32.8,-1.28),Vector3(-8.4,-31.25,-1.9)],
			[Vector3(-3.9,-35.4,1.40),Vector3(-.1,-33.8,1.1)],
			[Vector3(2.4,-33.3,-1.28),Vector3(-4.3,-34.8,-1.4)]]
		for index in views.size():
			view(views[index][0],views[index][1],78)
			await capture(LIGHTING_SHOTS[index])
	view(Vector3(4.8,-30.0,.85),Vector3(5.86,-29.1,2.0),72)
	await capture("open_hours_cyan_context")
	view(Vector3(4.8,-32.3,-.45),Vector3(5.86,-33.0,-.15),72)
	await capture("open_hours_magenta_context")
	if not await hours(720,HarukiyaStateDirector.BarState.CLOSED):await finish();return
	await capture("closed_hours_magenta_context")
	view(Vector3(4.8,-30.0,.85),Vector3(5.86,-29.1,2.0),72)
	await capture("closed_hours_cyan_context")
	view(Vector3(4.8,-28.0,1.65),Vector3(4.8,-31.7,-.65),78)
	await capture("closed_hours_upper_descent")
	await finish()
func finish() -> void:
	if OS.get_environment("ENTRY_OCCLUSION_MOTION")=="1":check(motion_frames.size()==MOTION_FRAMES_PER_PATH*4,"all four continuous camera segments captured")
	# Every caller after SHOT_DIR validation has recorded original state/logger.
	if not prior_initialized or logger==null:
		push_error("ENTRY VISUAL: cleanup called before original state initialized");get_tree().quit(2);return
	var observed := {}
	for shot: Dictionary in shots:
		var label: String=str(shot.name)
		check(label in expected_shots and not observed.has(label),"planned distinct capture " + label)
		observed[label]=true
		check(FileAccess.file_exists(str(shot.path)) and FileAccess.get_sha256(str(shot.path))==str(shot.sha256),"capture retained unchanged " + label)
	check(shots.size()==expected_shots.size() and observed.size()==expected_shots.size(),"exactly all planned captures")
	for label: String in expected_shots:check(observed.has(label),"required capture " + label)
	if rig!=null:rig.free();rig=null
	if bar!=null:bar.shutdown();bar.free();bar=null
	await get_tree().process_frame
	if preview_owned:
		check(RealityState.end_preview_campaign(self) and is_same(RealityState.data,prior_data),"original campaign restored");preview_owned=false
	check(JSON.stringify(prior_data).sha256_text()==prior_hash,"original campaign content unchanged")
	CampaignTime.set_frozen_for_tests(prior_frozen);GameBoot.launch_mode=prior_mode
	check(Input.mouse_mode==prior_mouse,"harness never changes mouse mode")
	check(inputs==hashes(),"capture source inputs unchanged")
	var engine_errors: Array=[]
	for message: String in logger.errors:
		if not message.contains("ENTRY VISUAL:"):engine_errors.append(message)
	OS.remove_logger(logger)
	var receipt: Dictionary={"schema_version":1,"evidence_kind":"visual_capture","status":"CAPTURED" if failures.is_empty() and engine_errors.is_empty() else "FAIL","gameplay_certification":false,"source_inputs":inputs,"shots":shots,"motion_frames":motion_frames,"motion_scope":"Four120frame detached-camera segments, actual ordinary door motion. No actor/controller movement, collision/squeeze or full-crowd qualification; frame-indexed camera animation is not a real-time performance benchmark.","failures":failures,"engine_errors":engine_errors,"scope":"Nearby actual installed bar, retained stock, real native leaf/fixtures, surfaces, LightRig and hours. Detached review camera only; no player/NPC spawn/replacement or walking proof. Neutral nearby environment from destination fixture; no exterior city sky/weather. Door uses ordinary mechanical command; half shot records actual observed fraction, never a forced pose."}
	var file:=FileAccess.open(directory.path_join("visual_capture.json"),FileAccess.WRITE)
	if file==null:get_tree().quit(2);return
	file.store_string(JSON.stringify(receipt,"\t"));file.close()
	get_tree().quit(0 if failures.is_empty() and engine_errors.is_empty() else 1)
