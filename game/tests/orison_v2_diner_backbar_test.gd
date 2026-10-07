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
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_diner_backbar.json"))
	check(FileAccess.get_sha256("res://assets/props/diner_backbar.glb")==fixture.asset_sha256,"installed mesh binds the native rear serving bench and literal narrow shelf export")
	var parts:=0;var triangles:=0;var removed:=0;var supports:=0
	for record: Dictionary in fixture.runtime.cells:
		var cell: Node3D=passage.cell_nodes[record.id];var model: Node3D=cell.get_node("DinerBackbar")
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
			var name:=str(draw.get_meta("diner_backbar_part"));var expected: Dictionary=fixture.parts.filter(func(row):return row.name==name)[0]
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
				if draw!=null and str(draw.get_meta("diner_backbar_part")).begins_with(str(contact.assembly)+"__"):exclude.append(body.get_rid())
			var query:=PhysicsRayQueryParameters3D.create(cell.to_global(at+direction*.004),cell.to_global(at-direction*.004),1,exclude)
			var hit:=world.get_world_3d().direct_space_state.intersect_ray(query)
			check(not hit.is_empty() and cell.to_local(hit.position).distance_to(at)<.00003,"fitted support contact: "+str(contact.label)+" / "+str(contact.owner));supports+=1
	check(parts==fixture.parts.size() and triangles==int(fixture.triangles) and removed==fixture.original_records.size()*12 and supports==fixture.contacts.size(),"native counts bind all original boxes, fitted furniture and floor samples")
	_check_backbar_details(world,fixture)
	await _retail_detail_views(world,fixture)
	var directory:=OS.get_environment("SHOT_DIR")
	FileAccess.open(directory.path_join("fittings.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","checks":checks,"parts":parts,"triangles":triangles,"removed":removed,"supports":supports,"failures":failures},"\t"))
	print("DINER BACKBAR: checks=",checks," parts=",parts," triangles=",triangles," removed=",removed," supports=",supports," failures=",failures.size())
	world.shutdown_for_tests();world.free();await _retired_audio();get_tree().quit(0 if failures.is_empty() else 1)

func _isolated_ray(world: OrisonV2RuntimeRoot, model: Node3D, part: String, start: Vector3, finish: Vector3) -> Dictionary:
	var targets:=model.find_children("*","MeshInstance3D",true,false).filter(func(draw):return str(draw.get_meta("diner_backbar_part",""))==part)
	check(targets.size()==1,"actual installed cavity partition: "+part)
	if targets.size()!=1:return {}
	var target: CollisionObject3D=targets[0].find_children("*","CollisionShape3D",true,false)[0].get_parent()
	var exclude: Array[RID]=[]
	for body: CollisionObject3D in world.find_children("*","CollisionObject3D",true,false):
		if body!=target:exclude.append(body.get_rid())
	return world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(start,finish,1,exclude))

func _check_backbar_details(world: OrisonV2RuntimeRoot, fixture: Dictionary) -> void:
	var cell: Node3D=world.passage_region.cell_nodes.shop_luncheonette;var model: Node3D=cell.get_node("DinerBackbar")
	var prefix:="storm_shop_luncheonette_"
	check(fixture.original_records.size()==5 and fixture.assemblies.size()==2,"original backbar/top and three original rear shelf owners")
	var probe:=model.get_node_or_null("DinerFinishReflection") as ReflectionProbe
	check(probe!=null and probe.update_mode==ReflectionProbe.UPDATE_ONCE and probe.max_distance==8.0 and probe.box_projection and probe.interior,"one bounded cell-owned room capture supplies original fully metallic chrome")
	var hit:=_isolated_ray(world,model,prefix+"backbar__countertop",cell.to_global(Vector3(22.85,1.20,41.30)),cell.to_global(Vector3(22.85,.90,41.30)))
	check(not hit.is_empty() and absf(cell.to_local(hit.position).y-1.02)<.00003 and hit.normal.dot(cell.global_basis.y)>.99,"actual back-bar serving sheet retains the source 1.02m upper datum")
	for at: Vector3 in [Vector3(22.81,1.02,43.45),Vector3(22.81,1.02,42.83),Vector3(22.79,1.02,40.20)]:
		hit=_isolated_ray(world,model,prefix+"backbar__countertop",cell.to_global(at+Vector3(0,.005,0)),cell.to_global(at-Vector3(0,.005,0)))
		check(not hit.is_empty() and cell.to_local(hit.position).distance_to(at)<.00003,"actual native serving top supports an unchanged urn or pie-case seat")
		var exclude: Array[RID]=[world.player.get_rid()]
		for body: CollisionObject3D in model.find_children("*","CollisionObject3D",true,false):exclude.append(body.get_rid())
		var base_query:=PhysicsRayQueryParameters3D.create(cell.to_global(at-Vector3(0,.005,0)),cell.to_global(at+Vector3(0,.005,0)),1,exclude)
		hit=world.get_world_3d().direct_space_state.intersect_ray(base_query)
		check(not hit.is_empty() and cell.to_local(hit.position).distance_to(at)<.00003,"original urn or pie-case physical base remains on the source 1.02m seat")
	hit=_isolated_ray(world,model,prefix+"backbar__chrome",cell.to_global(Vector3(22.30,.45,41.10)),cell.to_global(Vector3(22.62,.45,41.10)))
	check(not hit.is_empty() and absf(cell.to_local(hit.position).x-22.562)<.00003 and hit.normal.dot(-cell.global_basis.x)>.99,"actual rear cabinet has the declared thin front panel")
	hit=_isolated_ray(world,model,prefix+"backbar__chrome",cell.to_global(Vector3(22.64,.45,41.10)),cell.to_global(Vector3(22.30,.45,41.10)))
	check(not hit.is_empty() and absf(cell.to_local(hit.position).x-22.565)<.00003 and hit.normal.dot(cell.global_basis.x)>.99,"actual front panel has a three millimetre inner face")
	var query:=PhysicsRayQueryParameters3D.create(cell.to_global(Vector3(22.70,.45,41.10)),cell.to_global(Vector3(22.96,.45,41.10)),1,[world.player.get_rid()])
	check(world.get_world_3d().direct_space_state.intersect_ray(query).is_empty(),"actual rear bench carcass is hollow without retained solid chrome infill")
	for i in range(3):
		var y:=1.36+float(i)*.40
		hit=_isolated_ray(world,model,prefix+"bbshelf0__timber",cell.to_global(Vector3(23.36,y+.08,41.10)),cell.to_global(Vector3(23.36,y-.08,41.10)))
		check(not hit.is_empty() and absf(cell.to_local(hit.position).y-y)<.00003,"actual literal shelf retains source upper datum: "+str(i))
	var shelves: Array=model.find_children("*","MeshInstance3D",true,false).filter(func(draw):return str(draw.get_meta("diner_backbar_part",""))==prefix+"bbshelf0__timber")
	check(shelves.size()==1,"single joined shelf assembly owns the three source runs and supports")
	if shelves.size()==1:
		var bounds: AABB=shelves[0].transform*shelves[0].mesh.get_aabb()
		check(absf(bounds.position.x-23.33)<.00003 and absf(bounds.size.x-.05)<.00003,"actual source shelf depth stays five centimetres")
	for name in ["ShopSeating","DinerReceiving","DinerCounter","DinerTill"]:
		if name == "DinerReceiving" and not world.passage_region.cabinets_enabled:
			check(not cell.has_node(name),"temporarily removed Diner cabinets remain absent")
			continue
		check(cell.has_node(name),"accepted adjacent native fitting retained: "+name)

func _retail_detail_views(world: OrisonV2RuntimeRoot, fixture: Dictionary) -> void:
	var cell: Node3D=world.passage_region.cell_nodes.shop_luncheonette
	var r: Array=fixture.assemblies[0].floor.rect;var observations: Array=[]
	for view: Array in [["rear_bench_front",Vector3(22.10,.03,40.10),Vector3(22.56,.50,40.10)],["rear_floor_posts",Vector3(22.10,.03,40.10),Vector3(22.58,.04,39.63)],["rear_serving_top",Vector3(22.10,.03,40.10),Vector3(22.85,1.02,40.10)],["rear_shelf_runs",Vector3(21.10,.03,41.10),Vector3(23.35,1.61,41.78)],["rear_end",Vector3(20.15,.03,43.47),Vector3(22.80,1.00,43.50)],["shop_context",Vector3(19.80,.03,40.30),Vector3(22.85,1.35,41.78)]]:
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
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("views.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","views":observations,"scope":"Standing-capsule passive Diner rear serving bench and literal narrow shelf observations; shelf loads/capacity, food/drink service, utilities, continuous routes and human acceptance remain separate."},"\t"))
