extends "res://tests/orison_v2_city_sweep.gd"
## Actual retained shop boundaries, fitted supports, imported charts and standing detail views.
func _run() -> void:
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928,11,10,20*60);GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var world:=_world_scene().instantiate() as OrisonV2RuntimeRoot;add_child(world)
	await get_tree().physics_frame;await get_tree().physics_frame
	check(not world.startup_failed and not world.passage_region.startup_failed,"composed world fits the original Diner")
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
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_diner_apparatus.json"))
	check(FileAccess.get_sha256("res://assets/props/diner_apparatus.glb")==fixture.asset_sha256,"installed mesh binds the native griddle, soda pumps and supported mixer export")
	var parts:=0;var triangles:=0;var removed:=0;var supports:=0
	for record: Dictionary in fixture.runtime.cells:
		var cell: Node3D=passage.cell_nodes[record.id];var model: Node3D=cell.get_node("DinerApparatus")
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
			var name:=str(draw.get_meta("diner_apparatus_part"));var expected: Dictionary=fixture.parts.filter(func(row):return row.name==name)[0]
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
				if draw!=null and str(draw.get_meta("diner_apparatus_part")).begins_with(str(contact.assembly)+"__"):
					if str(contact.owner)=="storm_shop_luncheonette_soda_fount" and str(draw.get_meta("diner_apparatus_part"))=="storm_shop_luncheonette_soda_fount__marble_lobby":continue
					exclude.append(body.get_rid())
			var query:=PhysicsRayQueryParameters3D.create(cell.to_global(at+direction*.004),cell.to_global(at-direction*.004),1,exclude)
			var hit:=world.get_world_3d().direct_space_state.intersect_ray(query)
			check(not hit.is_empty() and cell.to_local(hit.position).distance_to(at)<.00003,"fitted support contact: "+str(contact.label)+" / "+str(contact.owner));supports+=1
			if str(contact.owner)=="storm_shop_luncheonette_soda_fount":
				check(not hit.is_empty() and str(hit.collider.get_parent().get_meta("diner_apparatus_part",""))=="storm_shop_luncheonette_soda_fount__marble_lobby","pump flange bears on actual fitted marble owner")
	check(parts==fixture.parts.size() and triangles==int(fixture.triangles) and removed==fixture.original_records.size()*12 and supports==fixture.contacts.size(),"native counts bind all original boxes, fitted furniture and floor samples")
	_check_apparatus_details(world,fixture)
	await _retail_detail_views(world,fixture)
	var directory:=OS.get_environment("SHOT_DIR")
	FileAccess.open(directory.path_join("fittings.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","checks":checks,"parts":parts,"triangles":triangles,"removed":removed,"supports":supports,"failures":failures},"\t"))
	print("DINER APPARATUS: checks=",checks," parts=",parts," triangles=",triangles," removed=",removed," supports=",supports," failures=",failures.size())
	world.shutdown_for_tests();world.free();await _retired_audio();get_tree().quit(0 if failures.is_empty() else 1)

func _isolated_ray(world: OrisonV2RuntimeRoot, model: Node3D, part: String, start: Vector3, finish: Vector3) -> Dictionary:
	var targets:=model.find_children("*","MeshInstance3D",true,false).filter(func(draw):return str(draw.get_meta("diner_apparatus_part",""))==part)
	check(targets.size()==1,"actual installed cavity partition: "+part)
	if targets.size()!=1:return {}
	var target: CollisionObject3D=targets[0].find_children("*","CollisionShape3D",true,false)[0].get_parent()
	var exclude: Array[RID]=[]
	for body: CollisionObject3D in world.find_children("*","CollisionObject3D",true,false):
		if body!=target:exclude.append(body.get_rid())
	return world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(start,finish,1,exclude))

func _check_apparatus_details(world: OrisonV2RuntimeRoot, fixture: Dictionary) -> void:
	var cell: Node3D=world.passage_region.cell_nodes.shop_luncheonette;var model: Node3D=cell.get_node("DinerApparatus")
	var prefix:="storm_shop_luncheonette_"
	check(fixture.original_records.size()==10 and fixture.assemblies.size()==3,"original griddle/top, fountain/five pumps and mixer/base source groups")
	var hit:=_isolated_ray(world,model,prefix+"griddle__metal",cell.to_global(Vector3(21.86,.78,43.35)),cell.to_global(Vector3(21.93,.78,43.35)))
	check(not hit.is_empty() and absf(cell.to_local(hit.position).x-21.900)<.00003,"actual griddle outer sheet retains source west plane")
	hit=_isolated_ray(world,model,prefix+"griddle__metal",cell.to_global(Vector3(21.94,.78,43.35)),cell.to_global(Vector3(21.88,.78,43.35)))
	check(not hit.is_empty() and absf(cell.to_local(hit.position).x-21.903)<.00003,"actual griddle has a three millimetre inner sheet")
	var query:=PhysicsRayQueryParameters3D.create(cell.to_global(Vector3(22.0,.78,43.35)),cell.to_global(Vector3(22.3,.78,43.35)),1,[world.player.get_rid()])
	check(world.get_world_3d().direct_space_state.intersect_ray(query).is_empty(),"actual griddle carcass is empty without invented heating or fuel")
	hit=_isolated_ray(world,model,prefix+"griddle__cast_iron",cell.to_global(Vector3(22.17,1.020,43.35)),cell.to_global(Vector3(22.17,.995,43.35)))
	check(not hit.is_empty() and absf(cell.to_local(hit.position).y-1.006)<.00003,"actual worked iron bed keeps its measured upper face")
	query=PhysicsRayQueryParameters3D.create(cell.to_global(Vector3(21.894,1.0,43.35)),cell.to_global(Vector3(21.894,.980,43.35)),1,[world.player.get_rid()])
	check(world.get_world_3d().direct_space_state.intersect_ray(query).is_empty(),"actual front gutter stays open and empty")
	hit=_isolated_ray(world,model,prefix+"soda_fount__marble_lobby",cell.to_global(Vector3(21.87,.65,41.8)),cell.to_global(Vector3(21.93,.65,41.8)))
	check(not hit.is_empty() and absf(cell.to_local(hit.position).x-21.902)<.00003,"actual stone pedestal outer side has its declared inset")
	hit=_isolated_ray(world,model,prefix+"soda_fount__marble_lobby",cell.to_global(Vector3(21.96,.65,41.8)),cell.to_global(Vector3(21.90,.65,41.8)))
	check(not hit.is_empty() and absf(cell.to_local(hit.position).x-21.920)<.00003,"actual stone side keeps eighteen millimetres of wall")
	query=PhysicsRayQueryParameters3D.create(cell.to_global(Vector3(21.98,.65,41.8)),cell.to_global(Vector3(22.34,.65,41.8)),1,[world.player.get_rid()])
	check(world.get_world_3d().direct_space_state.intersect_ray(query).is_empty(),"actual stone pedestal has an empty chamber")
	var pump_draw: MeshInstance3D=model.find_children("*","MeshInstance3D",true,false).filter(func(d):return str(d.get_meta("diner_apparatus_part",""))==prefix+"soda_fount__nickel_plated")[0]
	var pump_faces:=pump_draw.mesh.get_faces()
	var high_count:=0;var max_height:=-100.;var up:=0;var down:=0
	for j in range(0,pump_faces.size(),3):
		var a:=cell.to_local(pump_draw.to_global(pump_faces[j]));var b:=cell.to_local(pump_draw.to_global(pump_faces[j+1]));var c:=cell.to_local(pump_draw.to_global(pump_faces[j+2]))
		max_height=maxf(max_height,maxf(a.y,maxf(b.y,c.y)))
		if minf(a.y,minf(b.y,c.y))>1.419:
			high_count+=1;var nn:=(b-a).cross(c-a).normalized()
			if nn.y>0:up+=1
			else:down+=1
	print("PUMP MESH maximum=",max_height," high_triangles=",high_count," winding_up=",up," winding_down=",down," aabb=",pump_draw.transform*pump_draw.mesh.get_aabb())
	for i in range(5):
		var z:=42.24-float(i)*.24
		hit=_isolated_ray(world,model,prefix+"soda_fount__nickel_plated",cell.to_global(Vector3(22.20,1.20,z)),cell.to_global(Vector3(22.24,1.20,z)))
		check(not hit.is_empty() and absf(cell.to_local(hit.position).x-22.221)<.00003,"actual independent pump outer wall follows its source pose")
		hit=_isolated_ray(world,model,prefix+"soda_fount__nickel_plated",cell.to_global(Vector3(22.24,1.20,z)),cell.to_global(Vector3(22.20,1.20,z)))
		check(not hit.is_empty() and absf(cell.to_local(hit.position).x-22.224)<.00003,"actual independent pump has a three millimetre hollow wall")
		query=PhysicsRayQueryParameters3D.create(cell.to_global(Vector3(22.24,1.20,z)),cell.to_global(Vector3(22.29,1.20,z)),1,[world.player.get_rid()])
		check(world.get_world_3d().direct_space_state.intersect_ray(query).is_empty(),"actual pump chamber is empty without syrup contents")
		query=PhysicsRayQueryParameters3D.create(cell.to_global(Vector3(22.076,1.220,z)),cell.to_global(Vector3(22.076,1.236,z)),1,[world.player.get_rid()])
		check(world.get_world_3d().direct_space_state.intersect_ray(query).is_empty(),"actual passive pump nozzle retains an open bore")
		hit=_isolated_ray(world,model,prefix+"soda_fount__nickel_plated",cell.to_global(Vector3(22.265,1.45,z)),cell.to_global(Vector3(22.265,1.405,z)))
		print("PUMP HEIGHT centre=",hit if hit.is_empty() else cell.to_local(hit.position))
		hit=_isolated_ray(world,model,prefix+"soda_fount__nickel_plated",cell.to_global(Vector3(22.270,1.45,z+.007)),cell.to_global(Vector3(22.270,1.30,z+.007)))
		print("PUMP HEIGHT interior=",hit if hit.is_empty() else cell.to_local(hit.position))
		check(not hit.is_empty() and absf(cell.to_local(hit.position).y-1.42)<.00003,"actual blank plunger retains the original 1.42m maximum")
	hit=_isolated_ray(world,model,prefix+"mixer_base__nickel_plated",cell.to_global(Vector3(22.27,1.89,40.8)),cell.to_global(Vector3(22.27,1.84,40.8)))
	check(not hit.is_empty() and absf(cell.to_local(hit.position).y-1.86)<.00003,"actual mixer lid keeps original 1.86m maximum")
	hit=_isolated_ray(world,model,prefix+"mixer_base__nickel_plated",cell.to_global(Vector3(22.27,1.82,40.8)),cell.to_global(Vector3(22.27,1.78,40.8)))
	check(not hit.is_empty() and absf(cell.to_local(hit.position).y-1.794)<.00003,"actual motor shell has a four millimetre closed inner floor")
	query=PhysicsRayQueryParameters3D.create(cell.to_global(Vector3(22.24,1.83,40.8)),cell.to_global(Vector3(22.30,1.83,40.8)),1,[world.player.get_rid()])
	check(world.get_world_3d().direct_space_state.intersect_ray(query).is_empty(),"actual compact motor chamber is empty without invented internals")
	hit=_isolated_ray(world,model,prefix+"mixer_base__enamel",cell.to_global(Vector3(22.27,1.34,40.8)),cell.to_global(Vector3(22.27,1.31,40.8)))
	check(not hit.is_empty() and absf(cell.to_local(hit.position).y-1.32)<.00003,"actual supported mixer base keeps original 1.32m upper datum")
	for name in ["ShopSeating","DinerReceiving","DinerCounter","DinerTill","DinerBackbar","DinerUrns"]:
		check(cell.has_node(name),"accepted adjacent native fitting retained: "+name)

func _retail_detail_views(world: OrisonV2RuntimeRoot, fixture: Dictionary) -> void:
	var cell: Node3D=world.passage_region.cell_nodes.shop_luncheonette
	var r: Array=fixture.assemblies[0].floor.rect;var observations: Array=[]
	for view: Array in [["griddle_front",Vector3(20.15,.03,43.47),Vector3(22.17,.83,43.35)],["griddle_bed",Vector3(20.15,.03,43.47),Vector3(22.17,1.006,43.35)],["griddle_feet",Vector3(20.15,.03,43.47),Vector3(22.17,.24,43.35)],["five_pumps",Vector3(20.15,.03,42.0),Vector3(22.24,1.25,41.75)],["pump_nozzles",Vector3(20.15,.03,42.0),Vector3(22.09,1.245,41.75)],["fountain_plinth",Vector3(20.15,.03,42.0),Vector3(22.17,.20,41.8)],["mixer_head",Vector3(22.10,.03,40.10),Vector3(22.27,1.70,40.8)],["mixer_stand",Vector3(22.10,.03,40.10),Vector3(22.27,.68,40.8)],["shop_context",Vector3(19.80,.03,40.30),Vector3(22.25,1.35,41.78)]]:
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
		await _settled_optics();await shot(view[0])
		observations.append({"id":view[0],"requested_feet":[preferred.x,preferred.y,preferred.z],"feet":[selected.x,selected.y,selected.z],"target":[view[2].x,view[2].y,view[2].z],"image":str(view[0])+".png"})
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("views.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","views":observations,"scope":"Standing-capsule passive griddle, fountain/pumps and floor-supported mixer observations; contents, food/drink service, heat, power, utilities, capacity, continuous routes and human acceptance remain separate."},"\t"))
