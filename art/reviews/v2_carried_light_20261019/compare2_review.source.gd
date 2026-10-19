extends Node
## Matched composed V2 frames. Diagnostic, not interaction or route acceptance.
const Runtime=preload("res://scenes/building/orison_v2_runtime.tscn")
const OFFSETS=[
	{"id":"eye","origin":Vector3(.018,-.018,-.035)},
	{"id":"shoulder","origin":Vector3(.16,-.12,-.06)},
	{"id":"hand","origin":Vector3(.22,-.22,-.10)},
	{"id":"wide","origin":Vector3(.30,-.18,-.08)},
	{"id":"left","origin":Vector3(-.20,-.16,-.08)}]
var rows: Array[Dictionary]=[]
var failures: Array[String]=[]
var out: String
func _ready() -> void:call_deferred("_run")
func check(ok: bool,label: String) -> void:
	print("LAMP OFFSET: ",label," = ",ok)
	if not ok:failures.append(label)
func _run() -> void:
	print("LAMP OFFSET REVIEW: starting composed comparison")
	out=OS.get_environment("SHOT_DIR")
	if out.is_empty() or DisplayServer.get_name()=="headless":get_tree().quit(2);return
	DirAccess.make_dir_recursive_absolute(out)
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	CampaignTime.set_frozen_for_tests(true);GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var world: OrisonV2RuntimeRoot=Runtime.instantiate();add_child(world)
	if world.startup_failed:check(false,"production V2 starts");get_tree().quit(1);return
	# Freeze this diagnostic composition, including the known WIP passive
	# nozzle sweep defect. No passive-mechanism or gameplay proof is claimed.
	world.process_mode=Node.PROCESS_MODE_DISABLED
	var player: PlayerController=world.player
	var air: Node3D=world.get_node("LampAtmosphere")
	check(air.field!=null,"production voxel field exists")
	if air.field==null:get_tree().quit(1);return
	player.set_beam_mask_enabled(false);player.set_lamp_enabled(true)
	air.driver.state.configure(0x28A11CE,true);air.driver.state.advance(2.)
	air.driver.apply_output()
	for layer: CanvasLayer in world.find_children("*","CanvasLayer",true,false):layer.hide()
	var native: RefCounted=world.adapter.root.get_meta("v2_native_fire_service")
	var actor: Node3D=native.stations.values()[0].get_ref()
	var views=[
		{"id":"cabinet_close","eye":actor.to_global(Vector3(-.04,.19,.68)),"at":actor.to_global(Vector3(-.04,.13,.09))},
		{"id":"cabinet_oblique","eye":actor.to_global(Vector3(.35,.20,.78)),"at":actor.to_global(Vector3(0,.13,.09))},
		{"id":"home","eye":world.adapter.root.to_global(Vector3(-11.4,1.65,-5.8)),"at":world.adapter.root.to_global(Vector3(-14.7,1.,-6.))}]
	var profiles: bool=OS.get_environment("LAMP_REVIEW_MODE") in ["profiles","all"]
	var options: Array=OFFSETS
	if profiles:
		options=[]
		if OS.get_environment("LAMP_REVIEW_MODE")=="all":
			for row: Dictionary in OFFSETS:
				var item: Dictionary=row.duplicate();item.energy=4.2;item.cone=1.45;options.append(item)
		options.append_array([{"id":"original","origin":Vector3(.018,-.018,-.035),"energy":4.2,"cone":1.45},
			{"id":"balanced","origin":Vector3(.16,-.12,-.06),"energy":2.4,"cone":1.0},
			{"id":"low","origin":Vector3(.16,-.12,-.06),"energy":1.8,"cone":.9},
			{"id":"moderate","origin":Vector3(.16,-.12,-.06),"energy":3.,"cone":1.1},
			{"id":"off","origin":Vector3(.16,-.12,-.06),"energy":0.,"cone":1.0}])
	for view: Dictionary in views:
		player.camera.global_position=view.eye;player.camera.look_at(view.at);player.camera.make_current()
		for option: Dictionary in options:
			var local: Vector3=option.origin
			var basis:=Basis.looking_at(Vector3(0,0,-1.2)-local)
			player.flashlight.global_transform=player.camera.global_transform*Transform3D(basis,local)
			if profiles:player.set_lamp_base_energy(option.energy);air.driver.cone_scale=option.cone
			air.driver.apply_output()
			for frame in range(10):
				air._update_volume(1./60.);air.scene_shadow._process(0.)
				await RenderingServer.frame_post_draw
			var image: Image=get_viewport().get_texture().get_image()
			var label: String=view.id+"_"+option.id
			check(image.save_png(out.path_join(label+".png"))==OK,label+" rendered")
			check(air.field.ready and air.field.failed.is_empty() and air.field.updates>0,"live voxel injection "+label)
			check(player.flashlight.light_projector==null and not player._light_mask.is_visible_in_tree(),"no patterned projection "+label)
			var ray:=PhysicsRayQueryParameters3D.create(player.camera.global_position,player.flashlight.global_position,1,[player.get_rid()])
			var blocked: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(ray)
			rows.append({"view":view.id,"offset":option.id,"origin":[local.x,local.y,local.z],"energy":player.flashlight.light_energy,"half_angle":player.flashlight.spot_angle,"origin_blocked":not blocked.is_empty(),"field_updates":air.field.updates,"field_pose_error":air.field.pose.origin.distance_to(player.flashlight.global_position)})
			print("LAMP OFFSET FRAME: ",label)
	FileAccess.open(out.path_join("measurements.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Frozen composed V2; matched lighting frames, live voxel injection, emitter segment rays. No movement/interaction acceptance; known WIP nozzle physics frozen.","rows":rows,"failures":failures},"\t"))
	world.shutdown_for_tests();world.free()
	print("LAMP OFFSET REVIEW: ","PASS" if failures.is_empty() else "FAIL"," failures=",failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
