extends "res://tests/orison_v2_fixed_lighting_test.gd"
## INERT installed native family and powered room review; not hand qualification.
func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var world:=load("res://scenes/building/orison_v2_runtime.tscn").instantiate() as OrisonV2RuntimeRoot
	add_child(world)
	if world.startup_failed:get_tree().quit(1);return
	world.player.set_physics_process(false)
	world.service_set_carrier.set_capture_hidden(true);world.player.set_lamp_enabled(false)
	for frame in 20:await get_tree().physics_frame
	var result: Dictionary=await validate_in_world(world)
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("review.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","review":result},"\t"))
	print("BATH SCONCE REVIEW: ","PASS" if failures.is_empty() else "FAIL")
	get_tree().quit(0 if failures.is_empty() else 1)

func _city_capture(world: OrisonV2RuntimeRoot,at: Vector3,target: Vector3,label: String,bucket: String,owner: String) -> void:
	world.player.global_position=at;world.player.velocity=Vector3.ZERO
	world.player.face_world_point(target);world.player.set_lamp_enabled(false)
	await _settled_optics();await shot(label)
	discovery.append({"id":label,"bucket":bucket,"owner":owner,"status":"captured_pending_visual_review","feet":[at.x,at.y,at.z],"image":label+".png","carried_lamp":false})
