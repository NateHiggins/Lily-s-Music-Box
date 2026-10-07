extends "res://tests/orison_v2_city_sweep.gd"
## Actual retained shop boundaries, fitted supports, imported charts and standing detail views.
func _run() -> void:
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928,11,10,20*60);GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var world:=_world_scene().instantiate() as OrisonV2RuntimeRoot;add_child(world)
	await get_tree().physics_frame;await get_tree().physics_frame
	check(not world.startup_failed and not world.passage_region.startup_failed,"composed world fits the original Pawnbroker")
	if world.startup_failed or world.passage_region.startup_failed:world.shutdown_for_tests();world.free();get_tree().quit(1);return
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
	check(passage.residency.state=="RESIDENT","normal prefetch exposes fitted stock geometry")
	if passage.residency.state!="RESIDENT":world.shutdown_for_tests();world.free();get_tree().quit(1);return
	await get_tree().physics_frame;await get_tree().physics_frame
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_pawn_display.json"))
	check(FileAccess.get_sha256("res://assets/props/pawn_display.glb")==fixture.asset_sha256,"installed mesh binds the native cases and supported window export")
	var parts:=0;var triangles:=0;var removed:=0;var supports:=0
	for record: Dictionary in fixture.runtime.cells:
		var cell: Node3D=passage.cell_nodes[record.id];var model: Node3D=cell.get_node("PawnDisplay")
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
			var name:=str(draw.get_meta("pawn_display_part"));var expected: Dictionary=fixture.parts.filter(func(row):return row.name==name)[0]
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
				if draw!=null and str(draw.get_meta("pawn_display_part")).begins_with(str(contact.assembly)+"__"):
					exclude.append(body.get_rid())
			var query:=PhysicsRayQueryParameters3D.create(cell.to_global(at+direction*.004),cell.to_global(at-direction*.004),1,exclude)
			var hit:=world.get_world_3d().direct_space_state.intersect_ray(query)
			check(not hit.is_empty() and cell.to_local(hit.position).distance_to(at)<.00003,"fitted support contact: "+str(contact.label)+" / "+str(contact.owner));supports+=1
			check(str(contact.owner)=="storm_shop_pawnbroker_floor" and not hit.is_empty() and str(hit.collider.get_parent().name).trim_suffix("-col").ends_with("_floor_oak"),"actual feet reach the retained oak floor")
	check(parts==fixture.parts.size() and triangles==int(fixture.triangles) and removed==fixture.original_records.size()*12 and supports==fixture.contacts.size(),"native counts bind all original boxes, fitted furniture and wall/ceiling samples")
	_check_display_details(world,fixture)
	await _retail_detail_views(world,fixture)
	var directory:=OS.get_environment("SHOT_DIR")
	FileAccess.open(directory.path_join("fittings.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","checks":checks,"parts":parts,"triangles":triangles,"removed":removed,"supports":supports,"failures":failures},"\t"))
	print("PAWN DISPLAY: checks=",checks," parts=",parts," triangles=",triangles," removed=",removed," supports=",supports," failures=",failures.size())
	world.shutdown_for_tests();world.free();await _retired_audio();get_tree().quit(0 if failures.is_empty() else 1)

func _isolated_ray(world: OrisonV2RuntimeRoot, model: Node3D, part: String, start: Vector3, finish: Vector3) -> Dictionary:
	var targets:=model.find_children("*","MeshInstance3D",true,false).filter(func(draw):return str(draw.get_meta("pawn_display_part",""))==part)
	check(targets.size()==1,"actual installed cavity partition: "+part)
	if targets.size()!=1:return {}
	var target: CollisionObject3D=targets[0].find_children("*","CollisionShape3D",true,false)[0].get_parent()
	var exclude: Array[RID]=[]
	for body: CollisionObject3D in world.find_children("*","CollisionObject3D",true,false):
		if body!=target:exclude.append(body.get_rid())
	return world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(start,finish,1,exclude))

func _check_display_details(world: OrisonV2RuntimeRoot, fixture: Dictionary) -> void:
	var cell: Node3D=world.passage_region.cell_nodes.shop_pawnbroker;var model: Node3D=cell.get_node("PawnDisplay")
	check(fixture.original_records.size()==8 and fixture.assemblies.size()==3,"two original three-box cases and two-box window stand")
	var glass: ShaderMaterial=model.get_meta("optical_material")
	check(glass.shader.resource_path=="res://shaders/lamp_glass_surface.gdshader" and is_equal_approx(float(glass.get_shader_parameter("surface_roughness")),.06),"local glazing uses the existing clear dielectric owner")
	var optical_count:=0
	for draw: MeshInstance3D in cell.find_children("*","MeshInstance3D",true,false):
		if not draw.has_meta("pawn_display_optical_owner"):continue
		optical_count+=1
		check(draw.material_override==glass and draw.mesh.surface_get_material(0)==draw.get_meta("pawn_display_source_material"),"optical override retains original material resource and mapped surface")
	check(optical_count==4,"two case panes, paired lenses and remaining original fixed glazing share only this shop's optical instance")
	var retained: Dictionary=model.get_meta("retained_glazing");var glazing: MeshInstance3D=retained.draw
	check(glazing.mesh==retained.mesh and glazing.transform==retained.pose and glazing.mesh.get_faces()==retained.faces,"remaining original fixed glazing mesh and pose are unchanged")
	var shape: CollisionShape3D=glazing.find_children("*","CollisionShape3D",true,false)[0]
	check(not shape.disabled and shape.shape.get_faces()==retained.faces,"remaining original fixed glazing collision remains exact")
	for side: String in ["w","e"]:
		var name:="storm_shop_pawnbroker_case_"+side
		var cy:=55.165 if side=="w" else 51.435
		# Broad rays verify real physical faces and the empty display chamber.
		var top:=_isolated_ray(world,model,name+"__glassish",cell.to_global(Vector3(20.3,1.8,cy)),cell.to_global(Vector3(20.3,1.0,cy)))
		var underside:=_isolated_ray(world,model,name+"__glassish",cell.to_global(Vector3(20.3,1.0,cy)),cell.to_global(Vector3(20.3,1.8,cy)))
		check(not top.is_empty() and absf(cell.to_local(top.position).y-1.445)<.00003,"5mm top pane upper face at declared rebate: "+side)
		check(not underside.is_empty() and absf(cell.to_local(underside.position).y-1.440)<.00003,"5mm top pane underside leaves the chamber hollow: "+side)
		var yfront:=54.898 if side=="w" else 51.702
		var first:=_isolated_ray(world,model,name+"__glassish",cell.to_global(Vector3(20.3,1.2,yfront-.5)),cell.to_global(Vector3(20.3,1.2,yfront+.5)))
		var second:=_isolated_ray(world,model,name+"__glassish",cell.to_global(Vector3(20.3,1.2,yfront+.20)),cell.to_global(Vector3(20.3,1.2,yfront-.20)))
		check(not first.is_empty() and not second.is_empty() and absf(first.position.distance_to(second.position)-.004)<.00003,"actual side pane is 4mm rather than a solid glass box: "+side)
		var chamber:=_isolated_ray(world,model,name+"__wood_dark",cell.to_global(Vector3(20.3,1.2,cy-.10)),cell.to_global(Vector3(20.3,1.2,cy+.10)))
		check(chamber.is_empty(),"display cavity remains clear of timber: "+side)
	var east_max:=-INF
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		if str(draw.get_meta("pawn_display_part")).begins_with("storm_shop_pawnbroker_case_e__"):
			east_max=maxf(east_max,(draw.transform*draw.mesh.get_aabb()).end.x)
	check(absf(east_max-21.68)<.00003 and 21.72-east_max>.0399,"east-case end clears the unchanged safe by 40mm")
	var stand:="storm_shop_pawnbroker_window_plinth"
	var deck:=_isolated_ray(world,model,stand+"__wood_dark",cell.to_global(Vector3(17.22,.95,53.6)),cell.to_global(Vector3(17.22,.3,53.6)))
	check(not deck.is_empty() and absf(cell.to_local(deck.position).y-.64)<.00003,"window stock deck is raised above the original sill")
	var clock: Node3D=cell.get_node("PawnClocks")
	check(clock.get_meta("removed_triangles").size()==15,"all fifteen passive wall clocks retain their own fitting")
	check(not cell.has_node("PawnReceiving") if not world.passage_region.cabinets_enabled else cell.has_node("PawnReceiving"),"temporary cabinet policy remains consistent")

func _retail_detail_views(world: OrisonV2RuntimeRoot, fixture: Dictionary) -> void:
	var cell: Node3D=world.passage_region.cell_nodes.shop_pawnbroker
	var observations: Array=[]
	for view: Array in [["west_case",Vector3(20.,.03,53.5),Vector3(20.6,1.,55.16),60.],["east_case",Vector3(20.,.03,53.5),Vector3(20.6,1.,51.43),60.],["east_safe_clearance",Vector3(20.9,.03,52.6),Vector3(21.66,.75,51.5),40.],["window_street",Vector3(15.8,.03,54.02),Vector3(17.36,.84,54.02),65.],["window_watch",Vector3(15.95,.03,54.02),Vector3(17.34,.79,54.02),20.],["window_optics",Vector3(15.95,.03,53.10),Vector3(17.35,.76,53.15),20.],["shop_context",Vector3(18.4,.03,53.2),Vector3(20.8,1.5,53.3),75.]]:
		var preferred: Vector3=view[1];var selected:=preferred;var distance:=INF
		if not _city_clear_station(world,cell.to_global(preferred)):
			for u in range(-5,6):
				for v in range(-5,6):
					var at:=preferred+Vector3(u*.12,0.,v*.12)
					if at.distance_squared_to(preferred)<distance and _city_clear_station(world,cell.to_global(at)):
						selected=at;distance=at.distance_squared_to(preferred)
		check(_city_clear_station(world,cell.to_global(selected)),"actual floor-supported display observation: "+str(view[0]))
		world.player.global_position=cell.to_global(selected);world.player.velocity=Vector3.ZERO
		world.player.face_world_point(cell.to_global(view[2]));world.player.set_lamp_enabled(true)
		world.player.camera.fov=float(view[3])
		await _settled_optics();await shot(view[0])
		observations.append({"id":view[0],"requested_feet":[preferred.x,preferred.y,preferred.z],"feet":[selected.x,selected.y,selected.z],"target":[view[2].x,view[2].y,view[2].z],"image":str(view[0])+".png","field_of_view_deg":world.player.camera.fov})
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("views.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","views":observations,"scope":"Standing-capsule case and window-stock observations; no inventory, time, optical gameplay, continuous route or human acceptance."},"\t"))
