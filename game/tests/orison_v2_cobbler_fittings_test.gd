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
	check(not world.startup_failed and not world.passage_region.startup_failed,"composed world fits the original cobbler shop")
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
	check(passage.residency.state=="RESIDENT","normal prefetch exposes fitted cobbler geometry")
	if passage.residency.state!="RESIDENT":world.shutdown_for_tests();world.free();get_tree().quit(1);return
	await get_tree().physics_frame;await get_tree().physics_frame
	await validate_in_world(world)
	world.shutdown_for_tests();world.free();await _retired_audio();get_tree().quit(0 if failures.is_empty() else 1)

func validate_in_world(world: OrisonV2RuntimeRoot) -> Dictionary:
	var passage: OrisonV2PassageRegion=world.passage_region
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_cobbler_fittings.json"))
	check(FileAccess.get_sha256("res://assets/props/cobbler_fittings.glb")==fixture.asset_sha256,"installed mesh binds the native cobbler export")
	var parts:=0;var triangles:=0;var removed:=0;var supports:=0
	for record: Dictionary in fixture.runtime.cells:
		var cell: Node3D=passage.cell_nodes[record.id];var model: Node3D=cell.get_node("CobblerFittings")
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
			var name:=str(draw.get_meta("cobbler_part"));var expected: Dictionary=fixture.parts.filter(func(row):return row.name==name)[0]
			check(count==int(expected.triangles) and expected.cell==record.id,"each fitted partition binds exact native triangles and cell")
			_check_cap_mapping(draw.mesh,true)
			var mat:=draw.mesh.surface_get_material(0) as StandardMaterial3D
			check(mat!=null and not mat.uv1_triplanar and mat.albedo_texture!=null and mat.roughness_texture!=null and mat.normal_texture!=null,"three source shipping maps reach native metre charts")
			var source: StandardMaterial3D
			var runtime_part: Dictionary=record.parts.filter(func(row):return row.name==name)[0]
			for original_draw: MeshInstance3D in originals:
				if str(original_draw.name).trim_suffix("-col").ends_with("_"+str(runtime_part.key)):source=originals[original_draw].surface_get_material(0)
			if runtime_part.has("catalog_key"):
				var library:=MatLib.get_mat(str(runtime_part.catalog_key))
				check(library!=mat and library.uv1_triplanar and library.albedo_texture==mat.albedo_texture and library.roughness_texture==mat.roughness_texture and library.normal_texture==mat.normal_texture and mat.uv1_scale.is_equal_approx(library.uv1_scale),"native cloth, iron and brass use their registered catalogue finish without changing shared materials")
				check(mat.metallic==library.metallic and mat.roughness==library.roughness and mat.normal_scale==library.normal_scale,"catalogued finish retains its metallic, roughness and normal strength")
			else:
				check(source!=null and source!=mat and source.albedo_texture==mat.albedo_texture and source.roughness_texture==mat.roughness_texture and source.normal_texture==mat.normal_texture,"original brass, chrome, timber and other shipping materials retain their original shipping maps")
				check(source!=null and source.metallic==mat.metallic and source.roughness==mat.roughness and source.normal_scale==mat.normal_scale,"source finish retains its metallic, roughness and normal strength")
			if runtime_part.has("tint"):
				var tint: Array=runtime_part.tint
				check(mat.albedo_color.is_equal_approx(Color(tint[0],tint[1],tint[2],tint[3])),"dark shoe upper uses its bounded local tint")
			var bounds: AABB=draw.transform*draw.mesh.get_aabb();check(maxf(maxf(bounds.size.x,bounds.size.y),bounds.size.z)<5.,"individual furniture partitions retain bounded culling")
			var shape: CollisionShape3D=draw.find_children("*","CollisionShape3D",true,false)[0]
			check((shape.shape as ConcavePolygonShape3D).get_faces()==draw.mesh.get_faces() and shape.global_transform.is_equal_approx(draw.global_transform),"native furniture physical triangles and poses match visible triangles")
		for contact: Dictionary in fixture.contacts:
			var at:=_v(contact.point);var direction:=_v(contact.direction);var exclude: Array[RID]=[world.player.get_rid()]
			for body: CollisionObject3D in model.find_children("*","CollisionObject3D",true,false):
				var draw:=body.get_parent() as MeshInstance3D
				if draw!=null and str(draw.get_meta("cobbler_part")).begins_with(str(contact.assembly)+"__"):exclude.append(body.get_rid())
			var query:=PhysicsRayQueryParameters3D.create(cell.to_global(at+direction*.004),cell.to_global(at-direction*.004),1,exclude)
			var hit:=world.get_world_3d().direct_space_state.intersect_ray(query)
			check(not hit.is_empty() and cell.to_local(hit.position).distance_to(at)<.00003,"fitted support contact: "+str(contact.label)+" / "+str(contact.owner));supports+=1
	check(parts==fixture.parts.size() and triangles==int(fixture.triangles) and removed==fixture.original_records.size()*12 and supports==fixture.contacts.size(),"native counts bind all original boxes, fitted furniture and floor samples")
	_check_shoe_collars(world,fixture)
	await _cobbler_views(world,fixture)
	var directory:=OS.get_environment("SHOT_DIR")
	FileAccess.open(directory.path_join("fittings.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","checks":checks,"parts":parts,"triangles":triangles,"removed":removed,"supports":supports,"failures":failures},"\t"))
	print("COBBLER FITTINGS: checks=",checks," parts=",parts," triangles=",triangles," removed=",removed," supports=",supports," failures=",failures.size())
	return {"checks":checks,"parts":parts,"triangles":triangles,"removed":removed,"supports":supports,"failures":failures.duplicate()}

func _check_shoe_collars(world: OrisonV2RuntimeRoot, fixture: Dictionary) -> void:
	var cell: Node3D=world.passage_region.cell_nodes.shop_shoe_rebuilding
	var model: Node3D=cell.get_node("CobblerFittings")
	var all_bodies: Array[RID]=[world.player.get_rid()]
	for body: CollisionObject3D in world.find_children("*","CollisionObject3D",true,false):all_bodies.append(body.get_rid())
	var slots: Dictionary={};var count:=0
	for row: Dictionary in fixture.original_records:
		if not str(row.id).begins_with("storm_shop_shoe_rebuilding_shoe"):continue
		var number:=int(str(row.id).get_slice("shoe",2));var level:=number%5
		var slot:=int(slots.get(level,0));slots[level]=slot+1
		var cx:=6.34+slot*.76;var base:=.46+.36*level
		for side in [-1,1]:
			var suffix:="__"+str(number)+"_"+str(side)
			var draws:=model.find_children("*","MeshInstance3D",true,false).filter(func(draw):return str(draw.get_meta("cobbler_part","")).ends_with(suffix))
			check(draws.size()==1,"each hollow upper retains one independently culled physical partition")
			if draws.size()!=1:continue
			var shape: CollisionShape3D=draws[0].find_children("*","CollisionShape3D",true,false)[0]
			var exclude: Array[RID]=all_bodies.duplicate();exclude.erase(shape.get_parent().get_rid())
			var at:=Vector3(cx+side*.057,base+.20,50.05+.246*.31)
			var query:=PhysicsRayQueryParameters3D.create(cell.to_global(at+Vector3.UP*2.5),cell.to_global(at-Vector3.UP*.19),1,exclude)
			var hit:=world.get_world_3d().direct_space_state.intersect_ray(query)
			var valid:=not hit.is_empty()
			if valid:
				var local:=cell.to_local(hit.position)
				valid=local.y>base+.030 and local.y<base+.040 and hit.collider==shape.get_parent() and hit.normal.dot(cell.global_basis.y)>.95
			check(valid,"actual hollow collar for retained pair "+str(number)+" side "+str(side));count+=1
	check(count==22,"eleven original pair identities produce twenty-two physical open shoes")
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		if not str(draw.get_meta("cobbler_part","")).begins_with("storm_shop_shoe_rebuilding_rack0__"):continue
		var bounds: AABB=draw.transform*draw.mesh.get_aabb()
		check(bounds.position.x>=6.13-.00001,"shoe rack leaves the original service-door aperture clear")
	for at: Vector3 in [Vector3(6.43,.03,49.10),Vector3(5.70,.03,49.50)]:
		check(_city_clear_station(world,cell.to_global(at)),"actual 660 mm standing capsule fits the rear-door approach")

func _cobbler_views(world: OrisonV2RuntimeRoot, fixture: Dictionary) -> void:
	var cell: Node3D=world.passage_region.cell_nodes.shop_shoe_rebuilding
	var floor: Dictionary=fixture.assemblies[0].floor
	var r: Array=floor.rect
	var observations: Array=[]
	for view: Array in [["floor_dust",Vector3(8.3,.03,46.95),Vector3(7.15,.018,47.3)],["finisher",Vector3(7.6,0.03,46.8),Vector3(6.1,1.1,46.4)],["sewing",Vector3(7.2,0.03,48.05),Vector3(5.65,1.1,48)],["shoe_rack",Vector3(6.43,0.03,49.5),Vector3(7.4,1.25,50.05)],["last_rack",Vector3(7.9,0.03,47.8),Vector3(6.4,1,49.4)],["bench",Vector3(7.75,0.03,46.3),Vector3(7.1,1.02,45.1)],["counter",Vector3(8.85,0.03,47),Vector3(9.9,1.18,47.6)],["window_cabinet",Vector3(9.2,0.03,45.8),Vector3(10.5,0.74,46.7)],["rear_door",Vector3(5.7,0.03,49.5),Vector3(5.65,1.1,50.25)],["waiting_seat",Vector3(9.55,0.03,49.5),Vector3(9.2,0.5,50.1)]]:
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
		if capture_enabled:
			await _settled_optics();await shot(view[0])
		observations.append({"id":view[0],"requested_feet":[preferred.x,preferred.y,preferred.z],"feet":[selected.x,selected.y,selected.z],"target":[view[2].x,view[2].y,view[2].z],"image":str(view[0])+".png"})
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("views.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","views":observations,"scope":"Standing-capsule detail observations; continuous access and service behavior have separate walking tests."},"\t"))
