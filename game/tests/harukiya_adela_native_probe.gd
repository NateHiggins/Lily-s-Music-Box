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
		report.stage_search=_clear_stage_columns(column)
		var heads: Array=actor.get("model").find_children("Skin_head","MeshInstance3D",true,false)
		var paint: StandardMaterial3D=heads[0].material_overlay as StandardMaterial3D if heads.size()==1 else null
		var makeup: Dictionary={"normal_enabled":paint!=null and paint.normal_enabled,"maps":{},"filter":paint.texture_filter if paint!=null else -1}
		var complete:=paint!=null and paint.normal_enabled and paint.texture_filter==BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		for key: String in ["albedo_texture","normal_texture","roughness_texture","metallic_texture"]:
			var texture: Texture2D=paint.get(key) as Texture2D if paint!=null else null
			var image: Image=texture.get_image() if texture!=null else null
			var loaded:=image!=null and image.has_mipmaps()
			makeup.maps[key]={"path":texture.resource_path if texture!=null else "","loaded_mips":loaded}
			complete=complete and loaded
		makeup.complete=complete
		report.makeup=makeup
		var base: Vector3=column.get("base",actor.global_position)
		var upper:=CylinderShape3D.new();upper.radius=float(column.radius)
		var bottom: float=bar.to_global(Vector3(0,float(bar.destination.spec.architecture.stage.floor_z),0)).y+.002
		upper.height=base.y+float(column.height)-bottom
		var upper_query:=PhysicsShapeQueryParameters3D.new();upper_query.shape=upper;upper_query.margin=0.;upper_query.collision_mask=1
		upper_query.transform.origin=Vector3(base.x,bottom+upper.height*.5,base.z)
		var upper_hits:=get_world_3d().direct_space_state.intersect_shape(upper_query,64)
		report.actual_upper={"hits":upper_hits.map(func(h):return str(h.collider.get_path())),"excluded_colliders":0,"radius":upper.radius,"height":upper.height,"bottom":bottom,"original_top":base.y+float(column.height)}
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
		camera.global_position=bar.destination.get_node("Navigation/stage_front").global_position+Vector3(0,1.4,-1.2)
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
	var qualified:=bool(report.get("makeup",{}).get("complete",false)) and report.get("actual_upper",{}).get("hits",[null]).is_empty()
	if report.get("rays",[]).size()>0:
		var contact: Dictionary=report.rays[0]
		qualified=qualified and bool(contact.hit) and str(contact.owner).contains("Destination_Stage_floor") and absf(contact.point.y-report.actor.column.base.y)<=.002
	else:qualified=false
	report.nearby_material_and_column_preflight=qualified
	report.preflight_is_gameplay_qualification=false
	var file:=FileAccess.open(out.path_join("probe.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.flush()
	print("ADELA NATIVE LOCALIZATION COMPLETE")
	get_tree().quit(0 if qualified or OS.get_environment("ADELA_NATIVE_REQUIRE_QUALIFIED")!="1" else 1)

func _clear_stage_columns(column: Dictionary) -> Dictionary:
	var spec: Dictionary=bar.destination.get("spec")
	var stage: Dictionary=spec.architecture.stage
	var rect: Array=stage.rect
	var radius: float=column.radius
	var height: float=column.height
	var space:=get_world_3d().direct_space_state
	var rows: Array=[]
	var tested:=0
	var supported:=0
	var desired:=bar.to_global(GameBoot.b2g(spec.standing_positions.filter(func(r):return str(r.id)=="vocal_performer")[0].at))
	var x:=float(rect[0])+radius
	while x<=float(rect[2])-radius+.000001:
		var z: float=-float(rect[3])+radius
		while z<=-float(rect[1])-radius+.000001:
			tested+=1
			var base:=bar.to_global(Vector3(x,float(stage.floor_z),z))
			var ray:=PhysicsRayQueryParameters3D.create(base+Vector3.UP*.08,base-Vector3.UP*.08,1)
			var hit:=space.intersect_ray(ray)
			if not hit.is_empty() and str(hit.collider.get_path()).contains("Destination_Stage_floor") and absf(hit.position.y-base.y)<=.002:
				supported+=1
				var shape:=CylinderShape3D.new();shape.radius=radius;shape.height=height-.002
				var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.margin=0.;query.collision_mask=1
				query.transform.origin=base+Vector3.UP*(.002+shape.height*.5)
				var hits:=space.intersect_shape(query,64)
				if hits.is_empty():rows.append({"source_at":[x,-z,float(stage.floor_z)],"world_base":base,"distance_to_vocal":Vector2(base.x-desired.x,base.z-desired.z).length(),"support":str(hit.collider.get_path()),"support_y":hit.position.y,"upper_hits":0,"excluded_colliders":0})
			z+=.1
		x+=.1
	rows.sort_custom(func(a,b):return float(a.distance_to_vocal)<float(b.distance_to_vocal))
	return {"scope":"localization only; all native collisions retained, full measured radius/height, floor+2mm upper slab","tested":tested,"floor_supported":supported,"clear":rows.size(),"nearest":rows.slice(0,12)}
