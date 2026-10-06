extends "res://tests/orison_v2_city_sweep.gd"
## Actual retained shop boundaries, fitted supports, imported charts and standing detail views.
func _run() -> void:
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928,11,10,20*60);GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var world:=_world_scene().instantiate() as OrisonV2RuntimeRoot;add_child(world)
	await get_tree().physics_frame;await get_tree().physics_frame
	check(not world.startup_failed and not world.passage_region.startup_failed,"composed world fits the original photography shop")
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
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_photo_process.json"))
	check(FileAccess.get_sha256("res://assets/props/photo_process.glb")==fixture.asset_sha256,"installed mesh binds the native process-equipment export")
	var parts:=0;var triangles:=0;var removed:=0;var supports:=0
	for record: Dictionary in fixture.runtime.cells:
		var cell: Node3D=passage.cell_nodes[record.id];var model: Node3D=cell.get_node("PhotoProcess")
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
			var name:=str(draw.get_meta("photo_process_part"));var expected: Dictionary=fixture.parts.filter(func(row):return row.name==name)[0]
			check(count==int(expected.triangles) and expected.cell==record.id,"each fitted partition binds exact native triangles and cell")
			_check_cap_mapping(draw.mesh,true)
			var mat:=draw.mesh.surface_get_material(0) as StandardMaterial3D
			check(mat!=null and not mat.uv1_triplanar and mat.albedo_texture!=null and mat.roughness_texture!=null and mat.normal_texture!=null,"registered process-equipment and timber maps reach native metre charts")
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
				if draw!=null and str(draw.get_meta("photo_process_part")).begins_with(str(contact.assembly)+"__"):
					if str(contact.owner).ends_with("_LowDeck") and str(draw.get_meta("photo_process_part")).ends_with("__wood"):continue
					exclude.append(body.get_rid())
			var query:=PhysicsRayQueryParameters3D.create(cell.to_global(at+direction*.004),cell.to_global(at-direction*.004),1,exclude)
			var hit:=world.get_world_3d().direct_space_state.intersect_ray(query)
			check(not hit.is_empty() and cell.to_local(hit.position).distance_to(at)<.00003,"fitted support contact: "+str(contact.label)+" / "+str(contact.owner));supports+=1
	check(parts==fixture.parts.size() and triangles==int(fixture.triangles) and removed==fixture.original_records.size()*12 and supports==fixture.contacts.size(),"native counts bind all original boxes, fitted furniture and floor samples")
	_check_process_details(world,fixture)
	await _receiving_clearance_views(world,fixture)
	await _retail_detail_views(world,fixture)
	var directory:=OS.get_environment("SHOT_DIR")
	FileAccess.open(directory.path_join("fittings.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","checks":checks,"parts":parts,"triangles":triangles,"removed":removed,"supports":supports,"failures":failures},"\t"))
	print("PHOTO PROCESS: checks=",checks," parts=",parts," triangles=",triangles," removed=",removed," supports=",supports," failures=",failures.size())
	world.shutdown_for_tests();world.free();await _retired_audio();get_tree().quit(0 if failures.is_empty() else 1)

func _isolated_ray(world: OrisonV2RuntimeRoot, model: Node3D, part: String, start: Vector3, finish: Vector3) -> Dictionary:
	var targets:=model.find_children("*","MeshInstance3D",true,false).filter(func(draw):return str(draw.get_meta("photo_process_part",""))==part)
	check(targets.size()==1,"actual installed cavity partition: "+part)
	if targets.size()!=1:return {}
	var target: CollisionObject3D=targets[0].find_children("*","CollisionShape3D",true,false)[0].get_parent()
	var exclude: Array[RID]=[]
	for body: CollisionObject3D in world.find_children("*","CollisionObject3D",true,false):
		if body!=target:exclude.append(body.get_rid())
	return world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(start,finish,1,exclude))

func _check_process_details(world: OrisonV2RuntimeRoot, fixture: Dictionary) -> void:
	var cell: Node3D=world.passage_region.cell_nodes.shop_photo_supplies;var model: Node3D=cell.get_node("PhotoProcess");var prefix:="storm_shop_photo_supplies_"
	for index in 4:
		var row: Dictionary=fixture.original_records.filter(func(r):return r.id==prefix+"dev_tray"+str(index))[0];var r: Array=row.rect;var at:=Vector3((float(r[0])+float(r[2]))*.5,float(row.z0)+.004,-(float(r[1])+float(r[3]))*.5)
		var hit:=_isolated_ray(world,model,prefix+"dev_tray"+str(index)+"__enamel_finish",cell.to_global(at+Vector3(0,.08,0)),cell.to_global(at-Vector3(0,.002,0)))
		check(not hit.is_empty() and absf(cell.to_local(hit.position).y-at.y)<.00003 and hit.normal.dot(cell.global_basis.y)>.99,"actual empty developing bowl reaches its recessed bottom: "+str(index))
		at.x=float(r[0])+.002;at.y=float(row.z0)+float(row.h)
		hit=_isolated_ray(world,model,prefix+"dev_tray"+str(index)+"__enamel_finish",cell.to_global(at+Vector3(0,.05,0)),cell.to_global(at-Vector3(0,.05,0)))
		check(not hit.is_empty() and absf(cell.to_local(hit.position).y-at.y)<.00003 and hit.normal.dot(cell.global_basis.y)>.99,"actual developing tray rim retains original top datum: "+str(index))
	for index in 3:
		var row: Dictionary=fixture.original_records.filter(func(r):return r.id==prefix+"tank"+str(index))[0];var r: Array=row.rect;var at:=Vector3((float(r[0])+float(r[2]))*.5,float(row.z0),-(float(r[1])+float(r[3]))*.5)
		var hit:=_isolated_ray(world,model,prefix+"tank"+str(index)+"__nickel_plated",cell.to_global(at-Vector3(0,.06,0)),cell.to_global(at+Vector3(0,.04,0)))
		check(not hit.is_empty() and absf(cell.to_local(hit.position).y-at.y)<.00003 and hit.normal.dot(-cell.global_basis.y)>.99,"actual developing tank bottom retains original lower datum: "+str(index))
		at.y=float(row.z0)+float(row.h)
		hit=_isolated_ray(world,model,prefix+"tank"+str(index)+"__nickel_plated",cell.to_global(at+Vector3(0,.06,0)),cell.to_global(at-Vector3(0,.04,0)))
		check(not hit.is_empty() and absf(cell.to_local(hit.position).y-at.y)<.00003 and hit.normal.dot(cell.global_basis.y)>.99,"closed developing tank lid retains original top envelope: "+str(index))
	var dryer: Dictionary=fixture.original_records.filter(func(r):return r.id==prefix+"print_dryer")[0];var dr: Array=dryer.rect.duplicate();dr[3]=fixture.fitted_receiver_clearance.dryer_north_y;var cy: float=-(float(dr[1])+float(dr[3]))*.5
	var hit:=_isolated_ray(world,model,prefix+"print_dryer__enamel_finish",cell.to_global(Vector3(float(dr[0])-.05,.41,cy)),cell.to_global(Vector3(float(dr[0])+.4,.41,cy)))
	check(hit.is_empty(),"actual print-dryer front shell has an open cavity")
	hit=_isolated_ray(world,model,prefix+"print_dryer__enamel_finish",cell.to_global(Vector3(float(dr[0])-.05,.41,cy)),cell.to_global(Vector3(float(dr[2])+.03,.41,cy)))
	check(not hit.is_empty() and absf(cell.to_local(hit.position).x-(float(dr[2])-.014))<.00003 and hit.normal.dot(-cell.global_basis.x)>.99,"actual print-dryer cavity ends at the recessed back sheet")
	hit=_isolated_ray(world,model,prefix+"print_dryer__nickel_plated",cell.to_global(Vector3(float(dr[0])-.05,.41,cy)),cell.to_global(Vector3(float(dr[2]),.41,cy)))
	check(not hit.is_empty() and absf(cell.to_local(hit.position).x-((float(dr[0])+float(dr[2]))*.5-.15))<.00003 and hit.normal.dot(-cell.global_basis.x)>.99,"actual passive dryer drum is seated on the joined axle")
	var slot: float=-float(dr[1])-.022-(float(dr[3])-float(dr[1])-.044)/22.
	hit=_isolated_ray(world,model,prefix+"print_dryer__iron",cell.to_global(Vector3(float(dr[0])-.03,float(dryer.z0)+.09,slot)),cell.to_global(Vector3(float(dr[0])+.05,float(dryer.z0)+.09,slot)))
	check(hit.is_empty(),"actual lower print-dryer vent has physical gaps between its slats")
	for index in 4:
		var row: Dictionary=fixture.original_records.filter(func(r):return r.id==prefix+"flash_tin"+str(index))[0];var r: Array=row.rect;var at:=Vector3((float(r[0])+float(r[2]))*.5,float(row.z0)+float(row.h),-(float(r[1])+float(r[3]))*.5)
		hit=_isolated_ray(world,model,prefix+"flash_tin0__tin",cell.to_global(at+Vector3(0,.06,0)),cell.to_global(at-Vector3(0,.02,0)))
		check(not hit.is_empty() and absf(cell.to_local(hit.position).y-at.y)<.00003 and hit.normal.dot(cell.global_basis.y)>.99,"actual closed flash tin retains original upper envelope: "+str(index))
	check(fixture.assemblies.size()==13 and fixture.original_records.size()==16,"exactly four trays, three tanks, one dryer, four folded tripods and four flash tins remain the source scope")

func _retail_detail_views(world: OrisonV2RuntimeRoot, fixture: Dictionary) -> void:
	var cell: Node3D=world.passage_region.cell_nodes.shop_photo_supplies;var r: Array=fixture.assemblies[0].floor.rect;var observations: Array=[]
	for view: Array in [["developing_trays",Vector3(20.05,.03,61.8),Vector3(21.35,.23,61.7)],["closed_tanks",Vector3(20.65,.03,60.65),Vector3(21.81,.45,60.65)],["print_dryer",Vector3(20.35,.03,60.1),Vector3(21.5,.48,60.)],["folded_tripods",Vector3(19.45,.03,59.55),Vector3(20.65,1.25,59.3)],["flash_tins",Vector3(21.30,.03,62.5),Vector3(22.45,.56,62.95)],["process_context",Vector3(19.5,.03,61.8),Vector3(21.8,.6,61.6)]]:
		var preferred: Vector3=view[1];var selected:=preferred;var distance:=INF
		if not _city_clear_station(world,cell.to_global(preferred)):
			for u in range(1,25):
				for v in range(1,25):
					var at:=Vector3(lerpf(r[0],r[2],u/25.),.03,-lerpf(r[1],r[3],v/25.))
					if at.distance_squared_to(preferred)<distance and _city_clear_station(world,cell.to_global(at)):
						selected=at;distance=at.distance_squared_to(preferred)
		check(_city_clear_station(world,cell.to_global(selected)),"actual floor-supported process-equipment observation: "+str(view[0]))
		world.player.global_position=cell.to_global(selected);world.player.velocity=Vector3.ZERO;world.player.face_world_point(cell.to_global(view[2]));world.player.set_lamp_enabled(true)
		await _settled_optics();await shot(view[0])
		observations.append({"id":view[0],"requested_feet":[preferred.x,preferred.y,preferred.z],"feet":[selected.x,selected.y,selected.z],"target":[view[2].x,view[2].y,view[2].z],"image":str(view[0])+".png"})
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("views.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","views":observations,"scope":"Standing-capsule passive process-equipment observations; chemicals, heat, photography operation, darkroom approach, continuous routes and services retain separate duties."},"\t"))

func _receiving_clearance_views(world: OrisonV2RuntimeRoot, fixture: Dictionary) -> void:
	var fit: Dictionary=fixture.fitted_receiver_clearance
	var cell: Node3D=world.passage_region.cell_nodes.shop_photo_supplies
	var model: Node3D=cell.get_node("PhotoProcess")
	var source: Dictionary=fit.source_record
	var floor: Dictionary=world.passage_region.source_layout.floors.filter(func(row):return str(row.id)=="F01")[0]
	var original: Dictionary=floor.furniture.filter(func(row):return str(row.id)==str(source.id))[0]
	var prop:=world.passage_region._actors.get_node_or_null("Arcade_"+str(source.id)) as ArcadeCabinetProp
	check(original==source and prop!=null,"dryer fit preserves complete immutable receiver record and actor")
	if prop==null:return
	check(prop.variant==int(source.variant) and prop.position.is_equal_approx(GameBoot.b2g([source.at[0],source.at[1],float(floor.z)+float(source.get("z0",0.))])) and is_equal_approx(prop.rotation.y,deg_to_rad(float(source.yaw))+PI),"dryer fit retains original receiver variant and pose")
	var original_dryer: Dictionary=floor.furniture.filter(func(row):return str(row.id)==str(fit.dryer_source_record.id))[0]
	check(original_dryer==fit.dryer_source_record,"dryer original rectangle and source record stay intact")
	var hull:=cell.get_node_or_null(str(fit.hull_name)) as StaticBody3D
	check(hull!=null,"exact original receiving hull remains in Photo Supplies")
	if hull==null:return
	var shape:=hull.get_child(0) as CollisionShape3D
	var faces: PackedVector3Array=(shape.shape as ConcavePolygonShape3D).get_faces()
	check(faces.size()==36 and shape.disabled and hull.collision_layer==0 and hull.collision_mask==0,"original twelve-triangle receiving hull retires disabled and complete")
	var receiving:=cell.get_node_or_null("PhotoReceiving") as Node3D
	check(receiving!=null and receiving.get_meta("original_hull")==hull,"native Photo chassis owns exactly the same original retired hull")
	var low:=Vector3(INF,INF,INF);var high:=Vector3(-INF,-INF,-INF)
	for vertex in faces:
		var point:=cell.to_local(shape.to_global(vertex));low=low.min(point);high=high.max(point)
	var a:=GameBoot.b2g(fit.hull_low_b);var b:=GameBoot.b2g(fit.hull_high_b)
	check(low.distance_to(a.min(b))<.00003 and high.distance_to(a.max(b))<.00003,"actual original receiver hull binds immutable assembler bounds")
	var north: float=INF;var south: float=-INF;var found:=0
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		if not str(draw.get_meta("photo_process_part","")).begins_with(str(fit.dryer_source_record.id)+"__"):continue
		found+=1
		for surface in draw.mesh.get_surface_count():
			var vertices: PackedVector3Array=draw.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for vertex in vertices:
				var z: float=cell.to_local(draw.to_global(vertex)).z;north=minf(north,z);south=maxf(south,z)
	check(found==3 and absf(north+float(fit.dryer_north_y))<.00003 and north-high.z>=float(fit.clearance_m)-.00003,"all actual dryer finishes stop clear of the complete receiver hull")
	check(absf(south-north-float(fit.fitted_dryer_length_m))<.00003 and float(fit.fitted_dryer_length_m)<float(fit.source_dryer_length_m),"dryer shortens only its obstructing north end")
	for spec: Dictionary in [{"id":"photo_receiver_dryer_scope","feet":[20.35,.03,60.1],"target":[21.45,1.20,59.736]},{"id":"photo_receiver_dryer_supports","feet":[20.35,.03,60.1],"target":[21.35,.08,59.98]}]:
		var feet:=cell.to_global(_v(spec.feet))
		check(_city_clear_station(world,feet),"floor-supported capsule observes actual dryer/receiver gap: "+str(spec.id))
		world.player.global_position=feet;world.player.velocity=Vector3.ZERO
		world.player.face_world_point(cell.to_global(_v(spec.target)));world.player.set_lamp_enabled(true)
		await _settled_optics();await shot(str(spec.id))
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("receiving_clearance.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","north_z":north,"hull_front_z":high.z,"gap_m":north-high.z,"fitted_length_m":south-north,"original_hull_triangles":12,"scope":"Actual passive dryer fit clears complete original receiver hull. Standing floor/capsule observations do not prove continuous entry, cabinet operation, services or human acceptance."},"\t"))
