extends Node3D
## Nearby localization only. This is not production attendance/gameplay proof.
var bar: OrisonV2BarRegion
var runtime: OrisonV2RuntimeRoot
func _ready() -> void: _run.call_deferred()
func _run() -> void:
	var out:=OS.get_environment("SHOT_DIR")
	if out.is_empty() or FileAccess.file_exists(out.path_join("probe.json")):get_tree().quit(2);return
	DirAccess.make_dir_recursive_absolute(out)
	var prior: Dictionary=RealityState.data
	var prior_mouse:=Input.mouse_mode
	var frozen:=CampaignTime._frozen_for_tests
	if not RealityState.begin_preview_campaign(self):get_tree().quit(2);return
	CampaignTime.set_frozen_for_tests(true)
	var clock:=CampaignClock.new()
	clock.configure_date(1929,6,14,1200)
	bar=OrisonV2BarRegion.new();add_child(bar)
	var timetable:=ScheduleDirector.new();add_child(timetable);timetable.setup(null,bar.source_layout)
	runtime=OrisonV2RuntimeRoot.new();runtime.campaign_clock=clock;runtime.resident_presence=timetable
	var panel:=CaseDialoguePanel.new();add_child(panel)
	var talk:=ResidentConversations.new();add_child(talk);talk.setup(panel)
	var counter:=preload("res://scripts/props/harukiya_counter_glass.gd").new()
	var configured:=counter.configure(runtime,bar,talk)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var report: Dictionary={"evidence_kind":"native_localization_diagnostic","qualified_gameplay":false,"configured":configured,"bar_transform":bar.global_transform,"draws":[],"rays":[],"whereabouts":runtime.resident_whereabouts("adela_voss")}
	if configured:
		var actor: Node3D=counter.cast.performers.adela_voss
		var column: Dictionary=actor.standing_occupancy()
		report.actor={"position":actor.global_position,"visible":actor.is_visible_in_tree(),"column":column}
		var base: Vector3=column.get("base",actor.global_position)
		for extent: float in [.08,1.0]:
			var query:=PhysicsRayQueryParameters3D.create(base+Vector3.UP*extent,base-Vector3.UP*extent,1)
			var hit:=get_world_3d().direct_space_state.intersect_ray(query)
			report.rays.append({"extent":extent,"hit":not hit.is_empty(),"point":hit.get("position"),"normal":hit.get("normal"),"owner":str(hit.collider.get_path()) if not hit.is_empty() else "","areas":query.collide_with_areas})
		for draw: MeshInstance3D in bar.destination.find_children("*","MeshInstance3D",true,false):
			if not str(draw.name).contains("Destination_Stage_"):continue
			var row: Dictionary={"name":draw.name,"transform":draw.global_transform,"bounds":draw.global_transform*draw.get_aabb(),"colliders":[]}
			for shape: CollisionShape3D in draw.find_children("*","CollisionShape3D",true,false):
				var owner:=shape.get_parent() as CollisionObject3D
				row.colliders.append({"path":shape.get_path(),"transform":shape.global_transform,"disabled":shape.disabled,"layer":owner.collision_layer if owner!=null else -1,"bounds":shape.global_transform*shape.shape.get_debug_mesh().get_aabb()})
			report.draws.append(row)
		var camera:=Camera3D.new();add_child(camera);camera.make_current()
		camera.global_position=actor.global_position+Vector3(1.8,.6,1.8)
		camera.look_at(actor.global_position+Vector3.UP*.3)
		var lamp:=OmniLight3D.new();add_child(lamp);lamp.global_position=actor.global_position+Vector3(1,2,1);lamp.light_energy=2.;lamp.omni_range=5.
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("native_feet.png"))
	bar.shutdown();bar.free()
	runtime.free()
	RealityState.end_preview_campaign(self)
	CampaignTime.set_frozen_for_tests(frozen)
	Input.mouse_mode=prior_mouse
	report.preview_identity_restored=is_same(RealityState.data,prior)
	var file:=FileAccess.open(out.path_join("probe.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.flush()
	print("ADELA NATIVE LOCALIZATION COMPLETE")
	get_tree().quit(0)
