extends "res://tests/orison_v2_city_sweep.gd"
## Actual retained shop boundaries, fitted supports, imported charts and standing detail views.
func _run() -> void:
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928,11,10,20*60);GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var world:=_world_scene().instantiate() as OrisonV2RuntimeRoot;add_child(world)
	await get_tree().physics_frame;await get_tree().physics_frame
	check(not world.startup_failed and not world.passage_region.startup_failed,"source-owned stored valve rack fits Radio Service")
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
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_radio_stock.json"))
	var installed: bool=passage.cell_nodes.has("shop_radio_service") and passage.cell_nodes.shop_radio_service.has_node("RadioStock")
	check(installed,"actual retained radio cell and native fittings exist before their contracts")
	if not installed:world.shutdown_for_tests();world.free();get_tree().quit(1);return
	check(FileAccess.get_sha256("res://assets/props/radio_stock.glb")==fixture.asset_sha256,"installed mesh binds the native radio stock export")
	var parts:=0;var triangles:=0;var removed:=0;var supports:=0
	for record: Dictionary in fixture.runtime.cells:
		var cell: Node3D=passage.cell_nodes[record.id];var model: Node3D=cell.get_node("RadioStock")
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
			var name:=str(draw.get_meta("radio_stock_part"));var expected: Dictionary=fixture.parts.filter(func(row):return row.name==name)[0]
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
				if draw!=null and str(draw.get_meta("radio_stock_part")).begins_with(str(contact.assembly)+"__"):exclude.append(body.get_rid())
			var query:=PhysicsRayQueryParameters3D.create(cell.to_global(at+direction*.004),cell.to_global(at-direction*.004),1,exclude)
			var hit:=world.get_world_3d().direct_space_state.intersect_ray(query)
			check(not hit.is_empty() and cell.to_local(hit.position).distance_to(at)<.00003,"fitted support contact: "+str(contact.label)+" / "+str(contact.owner));supports+=1
	check(parts==fixture.parts.size() and triangles==int(fixture.triangles) and removed==fixture.original_records.size()*12 and supports==fixture.contacts.size(),"native counts bind all original boxes, stored valves and actual floor samples")
	_check_stock_details(world,fixture)
	await _retail_detail_views(world,fixture)
	var directory:=OS.get_environment("SHOT_DIR")
	FileAccess.open(directory.path_join("fittings.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","checks":checks,"parts":parts,"triangles":triangles,"removed":removed,"supports":supports,"failures":failures},"\t"))
	print("RADIO STOCK: checks=",checks," parts=",parts," triangles=",triangles," removed=",removed," supports=",supports," failures=",failures.size())
	world.shutdown_for_tests();world.free();await _retired_audio();get_tree().quit(0 if failures.is_empty() else 1)

func _isolated_ray(world: OrisonV2RuntimeRoot, model: Node3D, part: String, start: Vector3, finish: Vector3) -> Dictionary:
	var targets:=model.find_children("*","MeshInstance3D",true,false).filter(func(draw):return str(draw.get_meta("radio_stock_part",""))==part)
	check(targets.size()==1,"actual installed fitting partition: "+part)
	if targets.size()!=1:return {}
	var target: CollisionObject3D=targets[0].find_children("*","CollisionShape3D",true,false)[0].get_parent()
	var exclude: Array[RID]=[]
	for body: CollisionObject3D in world.find_children("*","CollisionObject3D",true,false):
		if body!=target:exclude.append(body.get_rid())
	return world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(start,finish,1,exclude))

func _check_stock_details(world: OrisonV2RuntimeRoot, fixture: Dictionary) -> void:
	var cell: Node3D=world.passage_region.cell_nodes.shop_radio_service;var model: Node3D=cell.get_node("RadioStock")
	check(fixture.original_records.size()==18 and fixture.assemblies.size()==1 and fixture.closed_stocks.size()==56,"four source shelves and fourteen source valves become one joined rack")
	check(model.find_children("*","Light3D",true,false).is_empty(),"stored valve rack adds no signal or illumination")
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		check(draw.transform.basis.is_equal_approx(Basis.IDENTITY) and draw.material_override==null,"rack partition retains unit-scale metre geometry")
		var mat:=draw.mesh.surface_get_material(0) as StandardMaterial3D
		check(mat!=null and not mat.emission_enabled,"stored-valve materials remain passive")
	var rack: String=fixture.assemblies[0].id
	for contact: Dictionary in fixture.contacts:
		var point:=_v(contact.point)
		var underside:=_isolated_ray(world,model,rack+"__timber",cell.to_global(point-Vector3(0,4,0)),cell.to_global(point+Vector3(0,6,0)))
		check(not underside.is_empty() and cell.to_local(underside.position).distance_to(point)<.00003,"actual rack foot seats on unchanged retained floor: "+str(contact.label))
	var originals: Dictionary={}
	for row: Dictionary in fixture.original_records:originals[str(row.id)]=row
	var valves:=0
	for index in 14:
		var row: Dictionary=originals["storm_shop_radio_service_valve"+str(index)];var q: Array=row.rect
		var x: float=(float(q[0])+float(q[2]))*.5;var z: float=-(float(q[1])+float(q[3]))*.5;var base: float=row.z0;var crown: float=base+float(row.h)
		# Long queries retain exact surface expectations on small cap triangles.
		var suffix: String="__valve"+str(index)
		var base_top:=_isolated_ray(world,model,rack+"__valve_base"+suffix,cell.to_global(Vector3(x,6.5,z)),cell.to_global(Vector3(x,-3.5,z)))
		var base_bottom:=_isolated_ray(world,model,rack+"__valve_base"+suffix,cell.to_global(Vector3(x,-3.5,z)),cell.to_global(Vector3(x,6.5,z)))
		var board:=_isolated_ray(world,model,rack+"__timber",cell.to_global(Vector3(x,base+.15,z)),cell.to_global(Vector3(x,base-.05,z)))
		# Separate native valve partitions isolate aligned rows while long
		# queries retain exact cap expectations on these small triangles.
		var top:=_isolated_ray(world,model,rack+"__milk_glass"+suffix,cell.to_global(Vector3(x,6.5,z)),cell.to_global(Vector3(x,-3.5,z)))
		var bottom:=_isolated_ray(world,model,rack+"__milk_glass"+suffix,cell.to_global(Vector3(x,-3.5,z)),cell.to_global(Vector3(x,6.5,z)))
		check(not top.is_empty() and absf(cell.to_local(top.position).y-crown)<.00003,"each stored opal valve retains its original maximum: "+str(row.id))
		var seated:=not bottom.is_empty() and not base_top.is_empty() and not base_bottom.is_empty() and not board.is_empty()
		if seated:seated=absf(cell.to_local(bottom.position).y-(base+.023))<.00003 and absf(cell.to_local(base_top.position).y-(base+.027))<.00003 and absf(cell.to_local(base_bottom.position).y-base)<.00003 and absf(cell.to_local(board.position).y-base)<.00003
		check(seated,"actual Bakelite foot, opal joint and unchanged shelf seat every valve: "+str(row.id));valves+=1
	check(valves==14,"all fourteen source valve stations retain geometric bearings")
	var timber: MeshInstance3D=model.find_children("*","MeshInstance3D",true,false).filter(func(draw):return str(draw.get_meta("radio_stock_part",""))==rack+"__timber")[0]
	var extent: AABB=timber.transform*timber.mesh.get_aabb()
	check(absf(extent.position.x-19.547)<.00003 and absf(extent.end.x-21.6)<.00003,"declared shelf extension covers the original leftmost valve footprint")
	check(extent.end.z<58.650-.0019,"rack rear remains two millimetres clear of original wainscot")
	for index in 4:
		var shelf: Dictionary=originals["storm_shop_radio_service_valve_sh"+str(index)];var crown: float=float(shelf.z0)+float(shelf.h)
		var hit:=_isolated_ray(world,model,rack+"__timber",cell.to_global(Vector3(20.05,crown+.12,58.43)),cell.to_global(Vector3(20.05,crown-.12,58.43)))
		check(not hit.is_empty() and absf(cell.to_local(hit.position).y-crown)<.00003,"each original shelf top retains its source height: "+str(index))

func _retail_detail_views(world: OrisonV2RuntimeRoot, _fixture: Dictionary) -> void:
	var cell: Node3D=world.passage_region.cell_nodes.shop_radio_service;var observations: Array=[]
	for view: Dictionary in RADIO_STOCK_VIEWS:
		var feet:=_v(view.feet);var target:=_v(view.target)
		check(_city_clear_station(world,cell.to_global(feet)),"same retained floor/capsule radio stock observation: "+str(view.id))
		world.player.global_position=cell.to_global(feet);world.player.velocity=Vector3.ZERO
		world.player.face_world_point(cell.to_global(target));world.player.set_lamp_enabled(true)
		await _settled_optics();await shot(view.id)
		observations.append(view.duplicate(true))
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("views.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","views":observations,"scope":"Same retained standing floor/capsule samples before and after stored-valve rack fitting. No continuous route, sightline, alignment procedure, instrument operation or engineering capacity."},"\t"))

const RADIO_STOCK_VIEWS: Array=[{"id":"radio_stock_room","image":"radio_stock_room.png","feet":[19.3,0.03,57.7],"target":[20.58,1.15,58.5]},{"id":"rack_front","image":"rack_front.png","feet":[20.35,0.03,58.0],"target":[20.58,1.1,58.5]},{"id":"left_valve_bearing","image":"left_valve_bearing.png","feet":[19.25,0.03,58.0],"target":[19.6,0.96,58.53]},{"id":"upper_valve_rank","image":"upper_valve_rank.png","feet":[19.4,0.03,57.9],"target":[20.58,1.8,58.53]},{"id":"rack_floor_feet","image":"rack_floor_feet.png","feet":[19.4,0.03,57.9],"target":[20.58,0.08,58.5]},{"id":"empty_shelves","image":"empty_shelves.png","feet":[20.35,0.03,58.0],"target":[20.58,1.5,58.5]}]
