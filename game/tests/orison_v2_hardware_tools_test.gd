extends "res://tests/orison_v2_city_sweep.gd"
## Actual retained shop boundaries, fitted supports, imported charts and standing detail views.
func _run() -> void:
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928,11,10,20*60);GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var world:=_world_scene().instantiate() as OrisonV2RuntimeRoot;add_child(world)
	await get_tree().physics_frame;await get_tree().physics_frame
	check(not world.startup_failed and not world.passage_region.startup_failed,"composed world fits the original hardware shop")
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
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_hardware_tools.json"))
	check(FileAccess.get_sha256("res://assets/props/hardware_tools.glb")==fixture.asset_sha256,"installed mesh binds the native hardware-stock export")
	var parts:=0;var triangles:=0;var removed:=0;var supports:=0
	for record: Dictionary in fixture.runtime.cells:
		var cell: Node3D=passage.cell_nodes[record.id];var model: Node3D=cell.get_node("HardwareTools")
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
			var name:=str(draw.get_meta("hardware_tools_part"));var expected: Dictionary=fixture.parts.filter(func(row):return row.name==name)[0]
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
					check(not runtime_part.has("plain_alpha") and mat.transparency==source.transparency,"drawn sheet glazing retains the exact original transparency owner")
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
				if draw!=null and str(draw.get_meta("hardware_tools_part")).begins_with(str(contact.assembly)+"__"):exclude.append(body.get_rid())
			var query:=PhysicsRayQueryParameters3D.create(cell.to_global(at+direction*.004),cell.to_global(at-direction*.004),1,exclude)
			var hit:=world.get_world_3d().direct_space_state.intersect_ray(query)
			check(not hit.is_empty() and cell.to_local(hit.position).distance_to(at)<.00003,"fitted support contact: "+str(contact.label)+" / "+str(contact.owner));supports+=1
	check(parts==fixture.parts.size() and triangles==int(fixture.triangles) and removed==fixture.original_records.size()*12 and supports==fixture.contacts.size(),"native counts bind all original boxes, fitted furniture and floor samples")
	_check_tool_details(world,fixture)
	await _retail_detail_views(world,fixture)
	var directory:=OS.get_environment("SHOT_DIR")
	FileAccess.open(directory.path_join("fittings.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","checks":checks,"parts":parts,"triangles":triangles,"removed":removed,"supports":supports,"failures":failures},"\t"))
	print("HARDWARE TOOLS: checks=",checks," parts=",parts," triangles=",triangles," removed=",removed," supports=",supports," failures=",failures.size())
	world.shutdown_for_tests();world.free();await _retired_audio();get_tree().quit(0 if failures.is_empty() else 1)

func _isolated_ray(world: OrisonV2RuntimeRoot, model: Node3D, part: String, start: Vector3, finish: Vector3) -> Dictionary:
	var targets:=model.find_children("*","MeshInstance3D",true,false).filter(func(draw):return str(draw.get_meta("hardware_tools_part",""))==part)
	check(targets.size()==1,"actual installed cavity partition: "+part)
	if targets.size()!=1:return {}
	var target: CollisionObject3D=targets[0].find_children("*","CollisionShape3D",true,false)[0].get_parent()
	var exclude: Array[RID]=[]
	for body: CollisionObject3D in world.find_children("*","CollisionObject3D",true,false):
		if body!=target:exclude.append(body.get_rid())
	return world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(start,finish,1,exclude))

func _check_tool_details(world: OrisonV2RuntimeRoot, fixture: Dictionary) -> void:
	var cell: Node3D=world.passage_region.cell_nodes.shop_hardware_paint;var model: Node3D=cell.get_node("HardwareTools")
	var prefix:="storm_shop_hardware_paint_"
	var silhouettes: Array=fixture.original_records.filter(func(r):return str(r.id).begins_with(prefix+"tool_shadow"))
	var tools: Array=fixture.original_records.filter(func(r):return str(r.id) in [prefix+"tool0",prefix+"tool1",prefix+"tool2",prefix+"tool3",prefix+"tool4",prefix+"tool6",prefix+"tool7"])
	check(silhouettes.size()==8 and tools.size()==7 and not fixture.original_records.any(func(r):return str(r.id)==prefix+"tool5"),"eight original silhouettes retain seven tools and the deliberately missing index five")
	var empty:=Vector3(6.42,1.80,58.70)
	for key: String in ["metal","timber","brass_dull"]:
		check(_isolated_ray(world,model,prefix+"tool_board__"+key,cell.to_global(empty-Vector3(0,0,.5)),cell.to_global(empty+Vector3(0,0,.5))).is_empty(),"actual missing-tool slot contains no tool or false handle: "+key)
	var hit:=_isolated_ray(world,model,prefix+"tool_board__soot__vacant",cell.to_global(empty-Vector3(0,0,.5)),cell.to_global(empty+Vector3(0,0,.5)))
	check(not hit.is_empty() and absf(cell.to_local(hit.position).z-58.7205)<.00003,"actual empty slot retains its exposed unlettered silhouette")
	for sample: Array in [[0,0.,.14,"timber"],[1,0.,.10,"timber"],[2,0.,.14,"metal"],[3,.032,.10,"metal"],[4,-.006,.20,"metal"],[6,0.,.14,"metal"],[7,0.,.26,"metal"]]:
		var row: Dictionary=tools.filter(func(r):return str(r.id)==prefix+"tool"+str(sample[0]))[0]
		var r: Array=row.rect;var at:=Vector3((r[0]+r[2])*.5+float(sample[1]),1.58+float(sample[2]),58.70)
		# Tool and shadow source centres differ by five millimetres. Fabricated
		# tools deliberately share the source silhouette centre.
		at.x+=.005
		hit=_isolated_ray(world,model,prefix+"tool_board__"+str(sample[3]),cell.to_global(at-Vector3(0,0,.5)),cell.to_global(at+Vector3(0,0,.5)))
		check(not hit.is_empty() and hit.normal.dot(-cell.global_basis.z)>.9,"actual shaped tool occupies its original nonempty silhouette: "+str(sample[0]))
	var between:=Vector3(8.22,1.12,58.40)
	check(_isolated_ray(world,model,prefix+"ladder_r0__timber",cell.to_global(between-Vector3(0,0,.5)),cell.to_global(between+Vector3(0,0,.5))).is_empty(),"actual space between the ladder's rails and rungs remains open")
	check(fixture.original_records.filter(func(r):return str(r.id).begins_with(prefix+"ladder_rung")).size()==9,"all nine original rung identities survive fabrication")
	for index in range(5):
		var at:=Vector3(5.75,.70,54.8925+index*.10)
		hit=_isolated_ray(world,model,prefix+"glass_rack__glassish",cell.to_global(at-Vector3(0,0,.035)),cell.to_global(at+Vector3(0,0,.035)))
		check(not hit.is_empty() and absf(cell.to_local(hit.position).z-(54.88+index*.10))<.00003,"actual drawn sheet retains its distinct original front plane: "+str(index))

func _retail_detail_views(world: OrisonV2RuntimeRoot, fixture: Dictionary) -> void:
	var cell: Node3D=world.passage_region.cell_nodes.shop_hardware_paint
	var r: Array=fixture.assemblies[0].floor.rect;var observations: Array=[]
	for view: Array in [["glass_stand",Vector3(6.85,.03,55.23),Vector3(5.75,.70,55.1)],["glass_cutter",Vector3(6.85,.03,55.23),Vector3(6.37,.95,55.14)],["tool_board",Vector3(6.0,.03,56.6),Vector3(6.1,2.1,58.735)],["empty_tool_slot",Vector3(6.1,.03,57.75),Vector3(6.42,1.80,58.718)],["ladder",Vector3(8.8,.03,55.6),Vector3(8.22,1.60,58.5)],["east_stock",Vector3(7.2,.03,57.8),Vector3(7.1,1.26,59.0)],["shop_context",Vector3(9.0,.03,55.3),Vector3(6.8,1.2,57.1)]]:
		var preferred: Vector3=view[1];var selected:=preferred;var distance:=INF
		if not _city_clear_station(world,cell.to_global(preferred)):
			for u in range(1,25):
				for v in range(1,25):
					var at:=Vector3(lerpf(r[0],r[2],u/25.),.03,-lerpf(r[1],r[3],v/25.))
					if at.distance_squared_to(preferred)<distance and _city_clear_station(world,cell.to_global(at)):
						selected=at;distance=at.distance_squared_to(preferred)
		check(_city_clear_station(world,cell.to_global(selected)),"actual floor-supported capsule station: "+str(view[0]))
		world.player.global_position=cell.to_global(selected);world.player.velocity=Vector3.ZERO
		world.player.face_world_point(cell.to_global(view[2]));world.player.set_lamp_enabled(true)
		await _settled_optics();await shot(view[0])
		observations.append({"id":view[0],"requested_feet":[preferred.x,preferred.y,preferred.z],"feet":[selected.x,selected.y,selected.z],"target":[view[2].x,view[2].y,view[2].z],"image":str(view[0])+".png"})
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("views.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","views":observations,"scope":"Standing-capsule final hardware detail observations; original purchasing, operational tools, plot-device ladder behavior, continuous access and service capacity retain their separate authority."},"\t"))
