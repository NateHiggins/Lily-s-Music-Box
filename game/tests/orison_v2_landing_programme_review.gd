extends Node
## INERT loaded ownership, stance and rendered review; not played route proof.
var world: OrisonV2RuntimeRoot
var checks:=0
var failures: Array[String]=[]
var observations: Array[Dictionary]=[]
var out: String

func _ready() -> void:
	_run.call_deferred()

func check(value: bool,label: String) -> void:
	checks+=1
	if not value:failures.append(label);push_error(label)
	print("LANDING REVIEW ",label," = ",value)

func clear_stance(local_feet: Vector3) -> bool:
	var query:=PhysicsShapeQueryParameters3D.new()
	query.shape=world.player._capsule
	query.transform=Transform3D(world.adapter.root.global_basis,world.adapter.root.to_global(local_feet+Vector3.UP*(world.player._capsule.height*.5+.025)))
	query.collision_mask=1;query.exclude=[world.player.get_rid()]
	return world.get_world_3d().direct_space_state.intersect_shape(query,8).is_empty()

func capture(label: String,feet: Vector3,target: Vector3,inspection_lamp: bool=false) -> void:
	check(clear_stance(feet),"ordinary standing capsule clears rendered station: "+label)
	world.player.global_position=world.adapter.root.to_global(feet+Vector3.UP*.025)
	world.player.velocity=Vector3.ZERO;world.player.face_world_point(target)
	world.player.set_lamp_enabled(inspection_lamp)
	for frame in 20:await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(out.path_join(label+".png"))==OK,"save actual programme render: "+label)

func _run() -> void:
	out=OS.get_environment("SHOT_DIR")
	if out.is_empty() or DisplayServer.get_name()=="headless":get_tree().quit(1);return
	DirAccess.make_dir_recursive_absolute(out)
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	CampaignTime.set_frozen_for_tests(true);CampaignClock.new().configure_date(1928,10,15,20*60)
	OS.set_environment("ORISON_BUILDING_ROOT","v2");GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	world=preload("res://scenes/building/orison_v2_runtime.tscn").instantiate() as OrisonV2RuntimeRoot
	add_child(world);await get_tree().physics_frame;await get_tree().physics_frame
	check(not world.startup_failed,"complete production world accepts six actual landing owners")
	if not world.startup_failed:
		world.player.set_physics_process(false);world.player.camera.make_current()
		world.player.set_lamp_enabled(false);world.player.carried_device.set_capture_hidden(true)
		var bindings: Dictionary=world.public_landings.snapshot()
		check(bindings.size()==6,"six loaded programme bindings")
		var wayfinding: Node=world.adapter.root.get_node("Wayfinding")
		check(wayfinding.finish_report.size()==16,"all public and service plaques clear actual installed finishes")
		for plaque: Node3D in wayfinding.plaques:
			for seat: Node3D in plaque.get_node("Hardware").find_children("WallSeat_*","Node3D",true,false):
				var normal:=plaque.global_basis.z
				var hit:=world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(seat.global_position+normal*.02,seat.global_position-normal*.02,1,[world.player.get_rid()]))
				check(not hit.is_empty() and seat.global_position.distance_to(hit.position)<.005,"relocated spacer retains real plaster bearing: "+str(plaque.name))
		for space: Dictionary in world.layout.spaces:
			if not space.has("landing_core"):continue
			var row: Dictionary=bindings[str(space.id)];var floor:=str(space.level)
			var y:=float(world.adapter.root.level_y[floor])
			check(row.units.size()==(2 if floor=="F01" else 4),"unit decisions come from actual fitted leaves: "+floor)
			check(row.supports.size()==space.floor_platforms.size() and row.landmarks.size()==space.programme_anchors.size(),"complete physical support and landmark ownership: "+floor)
			var sign:=row.sign.get_ref() as Node3D
			var units:=sign.get_node("Apartments") as Label3D
			check(units.text=="  /  ".join(row.units),"visible numbers match actual apartment identities: "+floor)
			check(world.room_at_world(world.adapter.root.to_global(Vector3(3.4,y,2.75)))==str(space.id),"runtime room query uses the landing floor: "+floor)
			check(world.room_at_world(world.adapter.root.to_global(Vector3(0,y,-1.5)))==str(space.landing_core),"runtime shaft point retains core authority: "+floor)
			var plaque_feet: Vector3=world.adapter.root.to_local(sign.global_position+sign.global_basis.z*1.35)
			plaque_feet.y=y
			await capture(floor+"_floor_decision",plaque_feet,sign.global_position,true)
			var north:=Vector3(-.5 if floor=="F01" else -1.7,y,.9)
			await capture(floor+"_north_landing",north,world.adapter.root.to_global(Vector3(4.7,y+1.35,2.75)))
			observations.append({"id":str(space.id),"units":row.units,"supports":space.floor_platforms,"plaque_stance_clear":clear_stance(plaque_feet),"north_stance_clear":clear_stance(north)})
	var root_ref: WeakRef=weakref(world)
	var programme_ref: WeakRef=weakref(world.public_landings) if world.public_landings!=null else null
	world.shutdown_for_tests();world.free();await get_tree().process_frame
	check(root_ref.get_ref()==null,"review world retires")
	check(programme_ref==null or programme_ref.get_ref()==null,"landing owner service retires")
	FileAccess.open(out.path_join("landing_review.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Loaded owners, exact floor queries and capsule-checked renders only. Posed capture stations are not played circulation or runtime acceptance.","checks":checks,"failures":failures,"observations":observations},"\t"))
	print("V2 LANDING PROGRAMME REVIEW ","PASS" if failures.is_empty() else "FAIL"," checks=",checks," failures=",failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
