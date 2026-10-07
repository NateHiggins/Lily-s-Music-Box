extends "res://tests/orison_v2_city_sweep.gd"
## Actual retained shop boundaries, fitted supports, imported charts and standing detail views.
var batch_mode := false
var capture_enabled := true

func _ready() -> void:
	if not batch_mode: call_deferred("_run")

func _run() -> void:
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928,11,10,20*60);GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var world:=_world_scene().instantiate() as OrisonV2RuntimeRoot;add_child(world)
	await get_tree().physics_frame;await get_tree().physics_frame
	if world.startup_failed or world.passage_region.startup_failed:check(false,"world startup failed");world.shutdown_for_tests();world.free();get_tree().quit(1);return
	world.player.set_physics_process(false);world.service_set_carrier.set_capture_hidden(true)
	for layer: CanvasLayer in world.find_children("*","CanvasLayer",true,false):layer.hide()
	var passage: OrisonV2PassageRegion=world.passage_region
	for driver: CampaignClockDriver in get_tree().get_nodes_in_group("campaign_time_owner"):driver.set_frozen_for_tests(true)
	world.shop_simulation.set_process(false)
	var vestibule: Dictionary=world.layout.spaces.filter(func(row):return row.id=="F01_VESTIBULE")[0]
	var rect: Array=vestibule.rect
	world.player.global_position=world.adapter.root.to_global(Vector3((rect[0]+rect[2])*.5,0.,(rect[1]+rect[3])*.5))
	await get_tree().physics_frame;await get_tree().physics_frame
	for frame in 600:
		if passage.residency.state=="RESIDENT":break
		await get_tree().process_frame
	if passage.residency.state!="RESIDENT":check(false,"normal prefetch failed");world.shutdown_for_tests();world.free();get_tree().quit(1);return
	await get_tree().physics_frame;await get_tree().physics_frame
	await validate_in_world(world)
	world.shutdown_for_tests();world.free();await _retired_audio();get_tree().quit(0 if failures.is_empty() else 1)

func validate_in_world(world: OrisonV2RuntimeRoot) -> Dictionary:
	var passage: OrisonV2PassageRegion=world.passage_region
	check(not world.startup_failed and not passage.startup_failed,"composed world fits the original Pawnbroker")
	check(passage.residency.state=="RESIDENT","normal prefetch exposes fitted stock geometry")
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_pawn_clocks.json"))
	check(FileAccess.get_sha256("res://assets/props/pawn_clocks.glb")==fixture.asset_sha256,"installed mesh binds the native fifteen-clock export")
	var parts:=0;var triangles:=0;var removed:=0;var supports:=0
	for record: Dictionary in fixture.runtime.cells:
		var cell: Node3D=passage.cell_nodes[record.id];var model: Node3D=cell.get_node("PawnClocks")
		var originals: Dictionary=model.get_meta("original_meshes");var counts: Dictionary=model.get_meta("removed_triangles")
		for box: Dictionary in record.replace:
			check(counts[box.id]==int(box.expected_triangles),"exact original source boundary removed: "+str(box.id));removed+=int(counts[box.id])
		for draw: MeshInstance3D in originals:
			var original: Mesh=originals[draw];var retained:=draw.mesh
			check(retained.get_surface_count()==0 or original.get_surface_count()==retained.get_surface_count(),"remaining source material slots retained")
			for surface in retained.get_surface_count():
				var before:=original.surface_get_arrays(surface);var after:=retained.surface_get_arrays(surface)
				for attribute in Mesh.ARRAY_MAX:
					if attribute==Mesh.ARRAY_INDEX:continue
					check(before[attribute]==after[attribute],"other source vertex attribute remains identical: "+str(attribute))
				check(original.surface_get_material(surface)==retained.surface_get_material(surface),"original source material remains identical")
			var shape: CollisionShape3D=draw.find_children("*","CollisionShape3D",true,false)[0]
			check((shape.disabled and not draw.visible) if retained.get_surface_count()==0 else (shape.shape as ConcavePolygonShape3D).get_faces()==retained.get_faces(),"trimmed physical boundaries match visible boundaries")
		for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
			parts+=1;var count:=draw.mesh.get_faces().size()/3;triangles+=count
			var name:=str(draw.get_meta("pawn_clocks_part"));var expected: Dictionary=fixture.parts.filter(func(row):return row.name==name)[0]
			check(count==int(expected.triangles) and expected.cell==record.id,"each fitted partition binds exact native triangles and cell")
			_check_cap_mapping(draw.mesh,true)
			var mat:=draw.mesh.surface_get_material(0) as StandardMaterial3D
			check(mat!=null and not mat.uv1_triplanar and (mat.albedo_texture!=null or str(expected.key)=="glassish") and mat.roughness_texture!=null and mat.normal_texture!=null,"source optical maps reach native metre charts; drawn glass retains its literal color")
			var source: StandardMaterial3D
			var runtime_part: Dictionary=record.parts.filter(func(row):return row.name==name)[0]
			for original_draw: MeshInstance3D in originals:
				if str(original_draw.name).trim_suffix("-col").ends_with("_"+str(runtime_part.key)):source=originals[original_draw].surface_get_material(0)
			if runtime_part.has("catalog_key"):
				var library:=MatLib.get_mat(str(runtime_part.catalog_key))
				check(library!=mat and library.uv1_triplanar and library.albedo_texture==mat.albedo_texture and library.roughness_texture==mat.roughness_texture and library.normal_texture==mat.normal_texture and mat.uv1_scale.is_equal_approx(library.uv1_scale),"local registered finishes use their catalogue owner without changing shared materials")
				check(mat.metallic==library.metallic and mat.roughness==library.roughness and mat.normal_scale==library.normal_scale,"catalogued finish retains its metallic, roughness and normal strength")
			else:
				if str(runtime_part.key)=="glassish":source=model.get_meta("borrowed_glazing_owner").material
				check(source!=null and source!=mat and source.albedo_texture==mat.albedo_texture and source.roughness_texture==mat.roughness_texture and source.normal_texture==mat.normal_texture,"original timber, glass, bakelite and other shipping materials retain their original shipping maps")
				check(source!=null and source.metallic==mat.metallic and source.roughness==mat.roughness and source.normal_scale==mat.normal_scale,"source finish retains its metallic, roughness and normal strength")
				if str(runtime_part.key)=="glassish":
					check(source!=null and source.albedo_texture==null and mat.albedo_texture==null and source.albedo_color.is_equal_approx(mat.albedo_color) and source.cull_mode==mat.cull_mode,"drawn glass keeps exact original tint, alpha and culling")
					check(runtime_part.get("plain_alpha",false) and mat.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA,"bounded counter glazing uses its declared local alpha adaptation")
			if runtime_part.has("tint"):
				var tint: Array=runtime_part.tint
				check(mat.albedo_color.is_equal_approx(Color(tint[0],tint[1],tint[2],tint[3])),"local wrapper or wear finish uses its bounded tint")
			var bounds: AABB=draw.transform*draw.mesh.get_aabb();check(maxf(maxf(bounds.size.x,bounds.size.y),bounds.size.z)<5.,"individual furniture partitions retain bounded culling")
			var shape: CollisionShape3D=draw.find_children("*","CollisionShape3D",true,false)[0]
			check((shape.shape as ConcavePolygonShape3D).get_faces()==draw.mesh.get_faces() and shape.global_transform.is_equal_approx(draw.global_transform),"native furniture physical triangles and poses match visible triangles")
		for contact: Dictionary in fixture.contacts:
			var at:=_v(contact.point);var direction:=_v(contact.direction);var exclude: Array[RID]=[world.player.get_rid()]
			for body: CollisionObject3D in model.find_children("*","CollisionObject3D",true,false):
				var draw:=body.get_parent() as MeshInstance3D
				if draw!=null and str(draw.get_meta("pawn_clocks_part")).begins_with(str(contact.assembly)+"__"):
					exclude.append(body.get_rid())
			var query:=PhysicsRayQueryParameters3D.create(cell.to_global(at+direction*.004),cell.to_global(at-direction*.004),1,exclude)
			var hit:=world.get_world_3d().direct_space_state.intersect_ray(query)
			check(not hit.is_empty() and cell.to_local(hit.position).distance_to(at)<.00003,"fitted support contact: "+str(contact.label)+" / "+str(contact.owner));supports+=1
			check(str(contact.owner)=="site_passage_party_e_02" and not hit.is_empty() and str(hit.collider.get_parent().name).trim_suffix("-col").ends_with("_common_brick"),"rear bearing reaches actual unchanged brick party wall")
	check(parts==fixture.parts.size() and triangles==int(fixture.triangles) and removed==fixture.original_records.size()*12 and supports==fixture.contacts.size(),"native counts bind all original boxes, fitted furniture and wall/ceiling samples")
	_check_clock_details(world,fixture)
	await _retail_detail_views(world,fixture)
	var directory:=OS.get_environment("SHOT_DIR")
	FileAccess.open(directory.path_join("fittings.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","checks":checks,"parts":parts,"triangles":triangles,"removed":removed,"supports":supports,"failures":failures},"\t"))
	print("PAWN CLOCKS: checks=",checks," parts=",parts," triangles=",triangles," removed=",removed," supports=",supports," failures=",failures.size())
	return {"checks":checks,"parts":parts,"triangles":triangles,"removed":removed,"supports":supports,"failures":failures.duplicate()}

func _isolated_ray(world: OrisonV2RuntimeRoot, model: Node3D, part: String, start: Vector3, finish: Vector3) -> Dictionary:
	var targets:=model.find_children("*","MeshInstance3D",true,false).filter(func(draw):return str(draw.get_meta("pawn_clocks_part",""))==part)
	check(targets.size()==1,"actual installed cavity partition: "+part)
	if targets.size()!=1:return {}
	var target: CollisionObject3D=targets[0].find_children("*","CollisionShape3D",true,false)[0].get_parent()
	var exclude: Array[RID]=[]
	for body: CollisionObject3D in world.find_children("*","CollisionObject3D",true,false):
		if body!=target:exclude.append(body.get_rid())
	return world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(start,finish,1,exclude))

func _check_clock_details(world: OrisonV2RuntimeRoot, fixture: Dictionary) -> void:
	var cell: Node3D=world.passage_region.cell_nodes.shop_pawnbroker;var model: Node3D=cell.get_node("PawnClocks")
	var borrowed: Dictionary=model.get_meta("borrowed_glazing_owner");var glazing: MeshInstance3D=borrowed.draw
	check(glazing.mesh==borrowed.mesh and glazing.transform==borrowed.pose and glazing.mesh.surface_get_material(0)==borrowed.material,"borrowed shop glass keeps exact original mesh, pose and material")
	var glazing_shape: CollisionShape3D=glazing.find_children("*","CollisionShape3D",true,false)[0]
	check(glazing_shape.disabled==borrowed.disabled and glazing_shape.shape.get_faces()==borrowed.faces,"borrowed shop glass keeps exact original collision faces and state")
	check(fixture.original_records.size()==15 and fixture.assemblies.size()==15,"fifteen original clock records retain their individual owners")
	for row: Dictionary in fixture.original_records:
		var cx: float=(float(row.rect[0])+float(row.rect[2]))*.5;var cz: float=float(row.z0)+.46;var name:=str(row.id)
		var hit:=_isolated_ray(world,model,name+"__porcelain",cell.to_global(Vector3(cx,cz,51.24)),cell.to_global(Vector3(cx,cz,51.20)))
		check(not hit.is_empty() and absf(cell.to_local(hit.position).z-51.222)<.00003,"actual recessed pale dial front binds its declared translated seat: "+name)
		hit=_isolated_ray(world,model,name+"__glassish",cell.to_global(Vector3(cx+.045,cz,51.24)),cell.to_global(Vector3(cx+.045,cz,51.20)))
		check(not hit.is_empty() and absf(cell.to_local(hit.position).z-51.229)<.00003,"actual thin fixed pane sits inside the original front lip: "+name)
		hit=_isolated_ray(world,model,name+"__glassish",cell.to_global(Vector3(cx+.045,cz,51.20)),cell.to_global(Vector3(cx+.045,cz,51.24)))
		check(not hit.is_empty() and absf(cell.to_local(hit.position).z-51.2275)<.00003,"actual pane is 1.5 millimetres thick: "+name)
		check(float(row.z0)+.30>1.45,"translated original stock clears retained case tops")
	check(not cell.has_node("PawnReceiving") if not world.passage_region.cabinets_enabled else cell.has_node("PawnReceiving"),"temporary cabinet policy remains consistent")

func _retail_detail_views(world: OrisonV2RuntimeRoot, fixture: Dictionary) -> void:
	var cell: Node3D=world.passage_region.cell_nodes.shop_pawnbroker
	var r: Array=fixture.assemblies[0].floor.rect;var observations: Array=[]
	for view: Array in [["clock_wall",Vector3(19.7,.03,53.4),Vector3(19.92,2.16,51.21)],["wood_case",Vector3(21.32,.03,52.5),Vector3(21.32,1.64,51.21)],["brass_case",Vector3(20.62,.03,52.5),Vector3(20.62,1.64,51.21)],["upper_stock",Vector3(19.92,.03,52.4),Vector3(19.92,2.68,51.21)],["rear_bearing",Vector3(18.98,.03,52.00),Vector3(18.52,1.70,51.13)],["shop_context",Vector3(18.2,.03,53.3),Vector3(20.62,2.16,51.21)]]:
		var preferred: Vector3=view[1];var selected:=preferred;var distance:=INF
		if not _city_clear_station(world,cell.to_global(preferred)):
			for u in range(1,25):
				for v in range(1,25):
					var at:=Vector3(lerpf(r[0],r[2],u/25.),.03,-lerpf(r[1],r[3],v/25.))
					if at.distance_squared_to(preferred)<distance and _city_clear_station(world,cell.to_global(at)):
						selected=at;distance=at.distance_squared_to(preferred)
		check(_city_clear_station(world,cell.to_global(selected)),"actual floor-supported counter observation: "+str(view[0]))
		world.player.global_position=cell.to_global(selected);world.player.velocity=Vector3.ZERO
		world.player.face_world_point(cell.to_global(view[2]));world.player.set_lamp_enabled(true)
		world.player.camera.fov=20. if str(view[0]) in ["wood_case","brass_case","rear_bearing"] else 75.
		if capture_enabled:
			await _settled_optics();await shot(view[0])
		observations.append({"id":view[0],"requested_feet":[preferred.x,preferred.y,preferred.z],"feet":[selected.x,selected.y,selected.z],"target":[view[2].x,view[2].y,view[2].z],"image":str(view[0])+".png" if capture_enabled else null,"field_of_view_deg":world.player.camera.fov})
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("views.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","views":observations,"scope":"Standing-capsule passive clock wall observations; clock behavior, power/signal routes, utilities, capacity, continuous routes and human acceptance remain separate."},"\t"))
