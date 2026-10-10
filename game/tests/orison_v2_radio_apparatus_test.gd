extends "res://tests/orison_v2_city_sweep.gd"
## Actual retained shop boundaries, fitted supports, imported charts and standing detail views.
func _run() -> void:
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928,11,10,20*60);GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var world:=_world_scene().instantiate() as OrisonV2RuntimeRoot;add_child(world)
	await get_tree().physics_frame;await get_tree().physics_frame
	check(not world.startup_failed and not world.passage_region.startup_failed,"source-owned original instruments fit Radio Service")
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
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_radio_apparatus.json"))
	var installed: bool=passage.cell_nodes.has("shop_radio_service") and passage.cell_nodes.shop_radio_service.has_node("RadioApparatus")
	check(installed,"actual retained radio cell and native fittings exist before their contracts")
	if not installed:world.shutdown_for_tests();world.free();get_tree().quit(1);return
	check(FileAccess.get_sha256("res://assets/props/radio_apparatus.glb")==fixture.asset_sha256,"installed mesh binds the native radio instrument export")
	var parts:=0;var triangles:=0;var removed:=0;var supports:=0
	for record: Dictionary in fixture.runtime.cells:
		var cell: Node3D=passage.cell_nodes[record.id];var model: Node3D=cell.get_node("RadioApparatus")
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
			var name:=str(draw.get_meta("radio_apparatus_part"));var expected: Dictionary=fixture.parts.filter(func(row):return row.name==name)[0]
			check(count==int(expected.triangles) and expected.cell==record.id,"each fitted partition binds exact native triangles and cell")
			_check_cap_mapping(draw.mesh,true)
			var mat:=draw.mesh.surface_get_material(0) as StandardMaterial3D
			check(mat!=null and not mat.uv1_triplanar and mat.albedo_texture!=null and mat.roughness_texture!=null and mat.normal_texture!=null,"declared original and local catalogue maps reach native metre charts")
			var source: StandardMaterial3D
			var runtime_part: Dictionary=record.parts.filter(func(row):return row.name==name)[0]
			for original_draw: MeshInstance3D in originals:
				if str(original_draw.name).trim_suffix("-col").ends_with("_"+str(runtime_part.key)):source=originals[original_draw].surface_get_material(0)
			if runtime_part.has("catalog_key"):
				var library:=MatLib.get_mat(str(runtime_part.catalog_key))
				check(library!=mat and library.uv1_triplanar and library.albedo_texture==mat.albedo_texture and library.roughness_texture==mat.roughness_texture and library.normal_texture==mat.normal_texture and mat.uv1_scale.is_equal_approx(library.uv1_scale),"local registered finishes use their catalogue owner without changing shared materials")
				check(mat.metallic==library.metallic and mat.roughness==library.roughness and mat.normal_scale==library.normal_scale,"catalogued finish retains its metallic, roughness and normal strength")
			else:
				check(source!=null and source!=mat and source.albedo_texture==mat.albedo_texture and source.roughness_texture==mat.roughness_texture and source.normal_texture==mat.normal_texture,"declared original and local catalogue retain their shipping maps")
				check(source!=null and source.metallic==mat.metallic and source.roughness==mat.roughness and source.normal_scale==mat.normal_scale,"source finish retains its metallic, roughness and normal strength")
			if runtime_part.has("tint"):
				var tint: Array=runtime_part.tint
				check(mat.albedo_color.is_equal_approx(Color(tint[0],tint[1],tint[2],tint[3])),"declared local finish binding retains its declared tint")
			var bounds: AABB=draw.transform*draw.mesh.get_aabb();check(maxf(maxf(bounds.size.x,bounds.size.y),bounds.size.z)<5.,"individual furniture partitions retain bounded culling")
			var shape: CollisionShape3D=draw.find_children("*","CollisionShape3D",true,false)[0]
			check((shape.shape as ConcavePolygonShape3D).get_faces()==draw.mesh.get_faces() and shape.global_transform.is_equal_approx(draw.global_transform),"native furniture physical triangles and poses match visible triangles")
		for contact: Dictionary in fixture.contacts:
			var at:=_v(contact.point);var direction:=_v(contact.direction);var exclude: Array[RID]=[world.player.get_rid()]
			for body: CollisionObject3D in model.find_children("*","CollisionObject3D",true,false):
				var draw:=body.get_parent() as MeshInstance3D
				if draw!=null and str(draw.get_meta("radio_apparatus_part")).begins_with(str(contact.assembly)+"__"):exclude.append(body.get_rid())
			var query:=PhysicsRayQueryParameters3D.create(cell.to_global(at+direction*.004),cell.to_global(at-direction*.004),1,exclude)
			var hit:=world.get_world_3d().direct_space_state.intersect_ray(query)
			check(not hit.is_empty() and cell.to_local(hit.position).distance_to(at)<.00003,"fitted support contact: "+str(contact.label)+" / "+str(contact.owner));supports+=1
	check(parts==fixture.parts.size() and triangles==int(fixture.triangles) and removed==fixture.original_records.size()*12 and supports==fixture.contacts.size(),"native counts bind all original boxes, fitted instruments and actual bench samples")
	_check_apparatus_details(world,fixture)
	await _retail_detail_views(world,fixture)
	var directory:=OS.get_environment("SHOT_DIR")
	FileAccess.open(directory.path_join("fittings.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","checks":checks,"parts":parts,"triangles":triangles,"removed":removed,"supports":supports,"failures":failures},"\t"))
	print("RADIO APPARATUS: checks=",checks," parts=",parts," triangles=",triangles," removed=",removed," supports=",supports," failures=",failures.size())
	world.shutdown_for_tests();world.free();await _retired_audio();get_tree().quit(0 if failures.is_empty() else 1)

func _isolated_ray(world: OrisonV2RuntimeRoot, model: Node3D, part: String, start: Vector3, finish: Vector3) -> Dictionary:
	var targets:=model.find_children("*","MeshInstance3D",true,false).filter(func(draw):return str(draw.get_meta("radio_apparatus_part",""))==part)
	check(targets.size()==1,"actual installed fitting partition: "+part)
	if targets.size()!=1:return {}
	var target: CollisionObject3D=targets[0].find_children("*","CollisionShape3D",true,false)[0].get_parent()
	var exclude: Array[RID]=[]
	for body: CollisionObject3D in world.find_children("*","CollisionObject3D",true,false):
		if body!=target:exclude.append(body.get_rid())
	return world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(start,finish,1,exclude))

func _check_apparatus_details(world: OrisonV2RuntimeRoot, fixture: Dictionary) -> void:
	var cell: Node3D=world.passage_region.cell_nodes.shop_radio_service;var model: Node3D=cell.get_node("RadioApparatus")
	check(fixture.original_records.size()==8 and fixture.assemblies.size()==3 and fixture.closed_stocks.size()==135,"only eight original records become three connected instrument assemblies")
	check(model.find_children("*","Light3D",true,false).is_empty(),"passive fitted instruments add no signal or illumination")
	var originals: Dictionary={}
	for row: Dictionary in fixture.original_records:originals[str(row.id)]=row
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		check(draw.transform.basis.is_equal_approx(Basis.IDENTITY) and draw.material_override==null,"native instrument partition retains unit-scale metre geometry")
		var mat:=draw.mesh.surface_get_material(0) as StandardMaterial3D
		check(mat!=null and not mat.emission_enabled,"fitted instrument material remains passive")
	for contact: Dictionary in fixture.contacts:
		var point:=_v(contact.point);var body: Dictionary=originals[str(contact.assembly)]
		var key: String="scope_case" if str(body.id).ends_with("_scope") else "case_bakelite"
		var underside:=_isolated_ray(world,model,str(contact.assembly)+"__"+key,cell.to_global(point-Vector3(0,.20,0)),cell.to_global(point+Vector3(0,.15,0)))
		check(not underside.is_empty() and cell.to_local(underside.position).distance_to(point)<.00003,"actual imported instrument bottom seats at original bench datum: "+str(contact.assembly))
	var chassis: Dictionary=originals.storm_shop_radio_service_chassis
	var r: Array=chassis.rect;var centre_x: float=(float(r[0])+float(r[2]))*.5;var crown: float=float(chassis.z0)+float(chassis.h)
	for key in ["case_bakelite","chassis_metal"]:
		var cavity:=_isolated_ray(world,model,str(chassis.id)+"__"+str(key),cell.to_global(Vector3(centre_x,1.22,55.55)),cell.to_global(Vector3(centre_x,1.22,56.29)))
		check(cavity.is_empty(),"actual imported open rear exposes the set cavity above its internal stock")
	var panel:=_isolated_ray(world,model,str(chassis.id)+"__case_bakelite",cell.to_global(Vector3(centre_x,1.22,55.55)),cell.to_global(Vector3(centre_x,1.22,57.0)))
	check(not panel.is_empty() and absf(cell.to_local(panel.position).z-(-float(r[1])-.041))<.00003,"open rear retains the original set's supported front panel")
	var valve_count:=0
	for row: Dictionary in fixture.original_records:
		if not str(row.id).contains("bench_valve"):continue
		var q: Array=row.rect;var x: float=(float(q[0])+float(q[2]))*.5;var z: float=-(float(q[1])+float(q[3]))*.5
		# Long isolated origins avoid the backend's short-segment determinant
		# cutoff on small cap triangles; the expected surface datum stays exact.
		var top:=_isolated_ray(world,model,str(chassis.id)+"__valve_opal",cell.to_global(Vector3(x,6.70,z)),cell.to_global(Vector3(x,-3.30,z)))
		check(not top.is_empty() and absf(cell.to_local(top.position).y-(float(row.z0)+float(row.h)))<.00003,"actual valve crown keeps its original source height: "+str(row.id))
		var bottom:=_isolated_ray(world,model,str(chassis.id)+"__valve_opal",cell.to_global(Vector3(x,-3.60,z)),cell.to_global(Vector3(x,6.40,z)))
		var socket_top:=_isolated_ray(world,model,str(chassis.id)+"__control_bakelite",cell.to_global(Vector3(x,1.50,z)),cell.to_global(Vector3(x,1.30,z)))
		var socket_bottom:=_isolated_ray(world,model,str(chassis.id)+"__control_bakelite",cell.to_global(Vector3(x,1.25,z)),cell.to_global(Vector3(x,1.40,z)))
		var deck:=_isolated_ray(world,model,str(chassis.id)+"__chassis_metal",cell.to_global(Vector3(x,1.80,z)),cell.to_global(Vector3(x,1.20,z)))
		var seated:=not bottom.is_empty() and not socket_top.is_empty() and not socket_bottom.is_empty() and not deck.is_empty()
		if seated:seated=cell.to_local(bottom.position).y<=cell.to_local(socket_top.position).y+.00003 and cell.to_local(socket_bottom.position).y<=cell.to_local(deck.position).y+.00003 and absf(cell.to_local(deck.position).y-crown)<.00003
		check(seated,"actual socket bridges the old ten-millimetre gap and bears its valve: "+str(row.id));valve_count+=1
	check(valve_count==5,"all five original valve stations retain geometric bearings")
	_check_retained_scope_face(cell)

func _check_retained_scope_face(cell: Node3D) -> void:
	var packed:=ResourceLoader.load("res://assets/building/floor_01_cells/shop_radio_service.gltf","PackedScene",ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene
	check(packed!=null,"actual unchanged original radio cell remains available for display comparison")
	if packed==null:return
	var reference:=packed.instantiate() as Node3D
	var candidates:=reference.find_children("*","MeshInstance3D",true,false).filter(func(draw):return str(draw.name).trim_suffix("-col").ends_with("_screen"))
	var retained:=cell.find_children("*","MeshInstance3D",true,false).filter(func(draw):return str(draw.name).trim_suffix("-col").ends_with("_screen"))
	check(candidates.size()==retained.size() and not candidates.is_empty(),"all original literal display draws retain their owners")
	for original: MeshInstance3D in candidates:
		var matching:=retained.filter(func(draw):return draw.name==original.name)
		check(matching.size()==1,"original display draw keeps its exact source name")
		if matching.size()!=1:continue
		var actual: MeshInstance3D=matching[0]
		check(actual.transform.is_equal_approx(original.transform) and actual.mesh.get_surface_count()==original.mesh.get_surface_count(),"original display pose and material slots remain")
		for surface in original.mesh.get_surface_count():
			var before:=original.mesh.surface_get_arrays(surface);var after:=actual.mesh.surface_get_arrays(surface)
			for attribute in Mesh.ARRAY_MAX:check(before[attribute]==after[attribute],"retained original display vertex/index attribute: "+str(attribute))
			var source:=original.mesh.surface_get_material(surface) as StandardMaterial3D;var material:=actual.mesh.surface_get_material(surface) as StandardMaterial3D
			check(source!=null and material!=null and source.albedo_texture==null and material.albedo_texture==null and source.albedo_color.is_equal_approx(material.albedo_color) and source.roughness==material.roughness and source.metallic==material.metallic,"original blank display retains its literal material without new maps")
	reference.free()

func _retail_detail_views(world: OrisonV2RuntimeRoot, _fixture: Dictionary) -> void:
	var cell: Node3D=world.passage_region.cell_nodes.shop_radio_service;var observations: Array=[]
	for view: Dictionary in RADIO_APPARATUS_VIEWS:
		var feet:=_v(view.feet);var target:=_v(view.target)
		check(_city_clear_station(world,cell.to_global(feet)),"same retained floor/capsule radio instrument observation: "+str(view.id))
		world.player.global_position=cell.to_global(feet);world.player.velocity=Vector3.ZERO
		world.player.face_world_point(cell.to_global(target));world.player.set_lamp_enabled(true)
		await _settled_optics();await shot(view.id)
		observations.append(view.duplicate(true))
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("views.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","views":observations,"scope":"Same retained standing floor/capsule samples before and after instrument fitting. No continuous route, sightline, alignment procedure, instrument operation or engineering capacity."},"\t"))

const RADIO_APPARATUS_VIEWS: Array=[{"id":"radio_room","image":"radio_room.png","feet":[19.4,0.03,57.85],"target":[20.25,0.8,56.14]},{"id":"alignment_bench","image":"alignment_bench.png","feet":[19.45,0.03,57.5],"target":[20.3,0.65,56.13]},{"id":"original_instruments","image":"original_instruments.png","feet":[19.45,0.03,57.5],"target":[20.1,1.22,56.12]},{"id":"side_leaf","image":"side_leaf.png","feet":[19.4,0.03,56.95],"target":[19.03,1.0,56.15]},{"id":"side_bearings","image":"side_bearings.png","feet":[19.4,0.03,56.95],"target":[19.03,0.45,56.15]},{"id":"back_edge","image":"back_edge.png","feet":[19.45,0.03,57.5],"target":[21.2,1.01,55.83]},{"id":"valve_rank","image":"valve_rank.png","feet":[19.45,0.03,57.5],"target":[20.745,1.5,56.13]},{"id":"scope_controls","image":"scope_controls.png","feet":[19.4,0.03,56.95],"target":[19.7,1.22,56.445]},{"id":"generator_dial","image":"generator_dial.png","feet":[19.4,0.03,56.95],"target":[19.04,1.25,56.38]}]
