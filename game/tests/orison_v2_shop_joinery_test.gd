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
	check(not world.startup_failed and not passage.startup_failed,"composed world fits the original eleven closed shop doors")
	check(passage.residency.state=="RESIDENT","normal prefetch exposes fitted stock geometry")
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_shop_joinery.json"))
	check(FileAccess.get_sha256("res://assets/props/shop_joinery.glb")==fixture.asset_sha256,"installed mesh binds the native composed furnishing export")
	var owner_rows: Array=passage.source_layout.floors.filter(func(floor):return floor.id=="F01")[0].furniture
	var parts:=0;var triangles:=0;var removed:=0;var supports:=0
	for record: Dictionary in fixture.runtime.cells:
		var cell: Node3D=passage.cell_nodes[record.id];var model: Node3D=cell.get_node("ShopJoinery")
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
			var name:=str(draw.get_meta("shop_joinery_part"));var expected: Dictionary=fixture.parts.filter(func(row):return row.name==name)[0]
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
			if not record.parts.any(func(part):return str(part.name).begins_with(str(contact.assembly)+"__")):continue
			var at:=_v(contact.point);var direction:=_v(contact.direction);var exclude: Array[RID]=[world.player.get_rid()]
			for body: CollisionObject3D in model.find_children("*","CollisionObject3D",true,false):
				var draw:=body.get_parent() as MeshInstance3D
				if draw!=null and str(draw.get_meta("shop_joinery_part")).begins_with(str(contact.assembly)+"__"):
					exclude.append(body.get_rid())
			var query:=PhysicsRayQueryParameters3D.create(cell.to_global(at+direction*.004),cell.to_global(at-direction*.004),1,exclude)
			var hit:=world.get_world_3d().direct_space_state.intersect_ray(query)
			check(not hit.is_empty() and cell.to_local(hit.position).distance_to(at)<.00003,"fitted support contact: "+str(contact.label)+" / "+str(contact.owner));supports+=1
			if contact.native_owner:
				check(not hit.is_empty() and str(hit.collider.get_parent().get_meta("shop_joinery_part","")).begins_with(str(contact.owner)+"__"),"actual native bearing reaches its declared fitted owner")
			else:
				var owner: Dictionary=owner_rows.filter(func(row):return row.id==contact.owner)[0]
				check(not hit.is_empty() and str(hit.collider.get_parent().name).trim_suffix("-col").ends_with("_"+str(owner.mat)),"actual bearing reaches its retained floor or wainscot material owner")
	check(parts==fixture.parts.size() and triangles==int(fixture.triangles) and removed==fixture.original_records.size()*12 and supports==fixture.contacts.size(),"native counts bind all original boxes, fitted furniture and wall/ceiling samples")
	_check_joinery_details(world,fixture)
	await _joinery_views(world,fixture)
	var directory:=OS.get_environment("SHOT_DIR")
	FileAccess.open(directory.path_join("joinery.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","checks":checks,"parts":parts,"triangles":triangles,"removed":removed,"supports":supports,"failures":failures},"\t"))
	print("SHOP JOINERY: checks=",checks," parts=",parts," triangles=",triangles," removed=",removed," supports=",supports," failures=",failures.size())
	return {"checks":checks,"parts":parts,"triangles":triangles,"removed":removed,"supports":supports,"failures":failures.duplicate()}

func _isolated_ray(world: OrisonV2RuntimeRoot, model: Node3D, part: String, start: Vector3, finish: Vector3) -> Dictionary:
	var targets:=model.find_children("*","MeshInstance3D",true,false).filter(func(draw):return str(draw.get_meta("shop_joinery_part",""))==part)
	check(targets.size()==1,"actual installed cavity partition: "+part)
	if targets.size()!=1:return {}
	var target: CollisionObject3D=targets[0].find_children("*","CollisionShape3D",true,false)[0].get_parent()
	var exclude: Array[RID]=[]
	for body: CollisionObject3D in world.find_children("*","CollisionObject3D",true,false):
		if body!=target:exclude.append(body.get_rid())
	var query:=PhysicsRayQueryParameters3D.create(start,finish,1,exclude)
	query.hit_back_faces=false
	return world.get_world_3d().direct_space_state.intersect_ray(query)

func _check_joinery_details(world: OrisonV2RuntimeRoot, fixture: Dictionary) -> void:
	check(fixture.original_records.size()==24 and fixture.assemblies.size()==12 and fixture.runtime.cells.size()==11,"eleven source doors/knobs and one empty funeral display retain their exact source count")
	for assembly: Dictionary in fixture.assemblies:
		var cell: Node3D=world.passage_region.cell_nodes[assembly.cell]
		var model: Node3D=cell.get_node("ShopJoinery")
		check(model.find_children("*","Area3D",true,false).is_empty(),"closed source representation adds no interaction areas")
		var source: Dictionary=fixture.original_records.filter(func(row):return row.id==assembly.id)[0]
		var r: Array=source.rect;var floor_r: Array=assembly.floor.rect
		if assembly.kind=="closed_door":
			var direction:=1.0 if (float(r[1])+float(r[3]))<(float(floor_r[1])+float(floor_r[3])) else -1.0
			var outward:=Vector3(0.,0.,-direction)
			var face:=float(floor_r[1])+.05 if direction>0 else float(floor_r[3])-.05
			var middle: float=(float(r[0])+float(r[2]))*.5
			var panel_x: float=(float(r[0])+.107+middle-.020)*.5
			var knob: Dictionary=fixture.original_records.filter(func(row):return row.id==str(assembly.id).trim_suffix("_door")+"_knob")[0]
			var knob_z: float=float(knob.z0)+float(knob.h)*.5+float(assembly.get("knob_height_offset_m",0.))
			var panel_height: float=(knob_z+.0325+float(source.z0)+float(source.h)-.11)*.5
			var panel_at:=Vector3(panel_x,panel_height,-face)
			var rail_at:=Vector3(panel_x,knob_z,-face)
			var panel:=_isolated_ray(world,model,str(assembly.id)+"__wood_dark",cell.to_global(panel_at+outward*.20),cell.to_global(panel_at-outward*.02))
			var rail:=_isolated_ray(world,model,str(assembly.id)+"__wood_dark",cell.to_global(rail_at+outward*.20),cell.to_global(rail_at-outward*.02))
			check(not panel.is_empty() and not rail.is_empty(),"actual closed panel and lock rail both have physical faces: "+str(assembly.cell))
			if not panel.is_empty() and not rail.is_empty():
				var inset: float=(cell.to_local(rail.position)-cell.to_local(panel.position)).dot(outward)
				check(absf(inset-.011)<.00003,"actual field is recessed eleven millimetres behind the rail")
			var knob_at:=Vector3((float(knob.rect[0])+float(knob.rect[2]))*.5,knob_z,-face)
			var brass: MeshInstance3D=model.find_children("*","MeshInstance3D",true,false).filter(func(draw):return str(draw.get_meta("shop_joinery_part",""))==str(assembly.id)+"__brass_dull")[0]
			var furthest:=-INF;var tip:=Vector3.ZERO
			for vertex: Vector3 in brass.mesh.get_faces():
				var point: Vector3=brass.transform*vertex;var depth: float=(point-knob_at).dot(outward)
				if depth>furthest:furthest=depth;tip=point
			check(absf(furthest-.102)<.00003 and absf(tip.x-knob_at.x)<.00003 and absf(tip.y-knob_at.y)<.00003,"physical turned tip retains source centre and declared projection: "+str(assembly.cell))
			# Sample a cap face away from the shared pole. A four-metre segment
			# resolves these tiny triangles; the earlier 20cm segment missed them.
			var probe:=knob_at+Vector3(.003,.002,0.)
			var expected_depth:=.102-sqrt(.003*.003+.002*.002)*(.002/.009)
			var hit:=_isolated_ray(world,model,str(assembly.id)+"__brass_dull",cell.to_global(probe+outward*2.),cell.to_global(probe-outward*2.))
			check(not hit.is_empty() and absf((cell.to_local(hit.position)-knob_at).dot(outward)-expected_depth)<.00003,"actual knob face near the tip has its lathed physical profile: "+str(assembly.cell))
		else:
			var centre:=Vector3((float(r[0])+float(r[2]))*.5,0.,-(float(r[1])+float(r[3]))*.5)
			var hit:=_isolated_ray(world,model,str(assembly.id)+"__wood_dark",cell.to_global(centre+Vector3.UP*.8),cell.to_global(centre+Vector3.UP*.15))
			check(not hit.is_empty() and absf(cell.to_local(hit.position).y-(float(source.z0)+float(source.h)))<.00003,"empty funeral window stand retains its original display datum")

func _joinery_views(world: OrisonV2RuntimeRoot, fixture: Dictionary) -> void:
	var observations: Array=[]
	for assembly: Dictionary in fixture.assemblies:
		var cell: Node3D=world.passage_region.cell_nodes[assembly.cell]
		var source: Dictionary=fixture.original_records.filter(func(row):return row.id==assembly.id)[0]
		var r: Array=source.rect;var floor_r: Array=assembly.floor.rect
		var target:=Vector3((float(r[0])+float(r[2]))*.5,1.12,-(float(r[1])+float(r[3]))*.5)
		var direction:=1.0 if (float(r[1])+float(r[3]))<(float(floor_r[1])+float(floor_r[3])) else -1.0
		var preferred:=Vector3(target.x,.03,target.z-direction*2.0)
		if assembly.kind=="window":preferred=Vector3(target.x+1.8,.03,target.z);target.y=.8
		else:
			preferred.x=clampf(preferred.x,float(floor_r[0])+.30,float(floor_r[2])-.30)
			preferred.z=clampf(preferred.z,-float(floor_r[3])+.30,-float(floor_r[1])-.30)
		var selected:=preferred;var distance:=INF
		if not _city_clear_station(world,cell.to_global(preferred)):
			for u in range(1,25):
				for v in range(1,25):
					var at:=Vector3(lerpf(floor_r[0],floor_r[2],u/25.),.03,-lerpf(floor_r[1],floor_r[3],v/25.))
					if at.distance_squared_to(preferred)<distance and _city_clear_station(world,cell.to_global(at)):selected=at;distance=at.distance_squared_to(preferred)
		check(_city_clear_station(world,cell.to_global(selected)),"floor-supported closed-joinery observation: "+str(assembly.id))
		world.player.global_position=cell.to_global(selected);world.player.velocity=Vector3.ZERO
		world.player.face_world_point(cell.to_global(target));world.player.set_lamp_enabled(true)
		if capture_enabled:
			await _settled_optics();await shot(str(assembly.cell)+"_"+str(assembly.kind))
		observations.append({"id":assembly.id,"feet":[selected.x,selected.y,selected.z],"target":[target.x,target.y,target.z]})
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("views.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","views":observations,"scope":"Passive closed shop backs and empty window stand; no new opening or route authority."},"\t"))

