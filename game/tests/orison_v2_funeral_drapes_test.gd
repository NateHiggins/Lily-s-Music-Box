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
	check(not world.startup_failed and not world.passage_region.startup_failed,"two source-owned fixed curtain runs fit the funeral parlour")
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
	await validate_in_world(world)
	world.shutdown_for_tests();world.free();await _retired_audio();get_tree().quit(0 if failures.is_empty() else 1)

func validate_in_world(world: OrisonV2RuntimeRoot) -> Dictionary:
	var passage: OrisonV2PassageRegion = world.passage_region
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_funeral_drapes.json"))
	var installed: bool=passage.cell_nodes.has("shop_funeral_parlour") and passage.cell_nodes.shop_funeral_parlour.has_node("FuneralDrapes")
	check(installed,"actual retained funeral cell and native fittings exist before their contracts")
	if not installed:return {"checks":checks,"failures":failures}
	check(FileAccess.get_sha256("res://assets/props/funeral_drapes.glb")==fixture.asset_sha256,"installed mesh binds the native fixed-curtain export")
	var parts:=0;var triangles:=0;var removed:=0;var supports:=0
	for record: Dictionary in fixture.runtime.cells:
		var cell: Node3D=passage.cell_nodes[record.id];var model: Node3D=cell.get_node("FuneralDrapes")
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
			var name:=str(draw.get_meta("funeral_drape_part"));var expected: Dictionary=fixture.parts.filter(func(row):return row.name==name)[0]
			check(count==int(expected.triangles) and expected.cell==record.id,"each fitted partition binds exact native triangles and cell")
			_check_cap_mapping(draw.mesh,true)
			var mat:=draw.mesh.surface_get_material(0) as StandardMaterial3D
			check(mat!=null and not mat.uv1_triplanar and mat.albedo_texture!=null and mat.roughness_texture!=null and mat.normal_texture!=null,"catalogued cloth and iron maps reach native metre charts")
			var source: StandardMaterial3D
			var runtime_part: Dictionary=record.parts.filter(func(row):return row.name==name)[0]
			for original_draw: MeshInstance3D in originals:
				if str(original_draw.name).trim_suffix("-col").ends_with("_"+str(runtime_part.key)):source=originals[original_draw].surface_get_material(0)
			if runtime_part.has("catalog_key"):
				var library:=MatLib.get_mat(str(runtime_part.catalog_key))
				check(library!=mat and library.uv1_triplanar and library.albedo_texture==mat.albedo_texture and library.roughness_texture==mat.roughness_texture and library.normal_texture==mat.normal_texture and mat.uv1_scale.is_equal_approx(library.uv1_scale),"local registered finishes use their catalogue owner without changing shared materials")
				check(mat.metallic==library.metallic and mat.roughness==library.roughness and mat.normal_scale==library.normal_scale,"catalogued finish retains its metallic, roughness and normal strength")
			else:
				check(source!=null and source!=mat and source.albedo_texture==mat.albedo_texture and source.roughness_texture==mat.roughness_texture and source.normal_texture==mat.normal_texture,"catalogued cloth and iron retain their shipping maps")
				check(source!=null and source.metallic==mat.metallic and source.roughness==mat.roughness and source.normal_scale==mat.normal_scale,"source finish retains its metallic, roughness and normal strength")
			if runtime_part.has("tint"):
				var tint: Array=runtime_part.tint
				check(mat.albedo_color.is_equal_approx(Color(tint[0],tint[1],tint[2],tint[3])),"local oxblood cloth binding retains its declared tint")
			var bounds: AABB=draw.transform*draw.mesh.get_aabb();check(maxf(maxf(bounds.size.x,bounds.size.y),bounds.size.z)<5.,"individual furniture partitions retain bounded culling")
			var shape: CollisionShape3D=draw.find_children("*","CollisionShape3D",true,false)[0]
			check((shape.shape as ConcavePolygonShape3D).get_faces()==draw.mesh.get_faces() and shape.global_transform.is_equal_approx(draw.global_transform),"native furniture physical triangles and poses match visible triangles")
		for contact: Dictionary in fixture.contacts:
			var at:=_v(contact.point);var direction:=_v(contact.direction);var exclude: Array[RID]=[world.player.get_rid()]
			for body: CollisionObject3D in model.find_children("*","CollisionObject3D",true,false):
				var draw:=body.get_parent() as MeshInstance3D
				if draw!=null and str(draw.get_meta("funeral_drape_part")).begins_with(str(contact.assembly)+"__"):exclude.append(body.get_rid())
			var query:=PhysicsRayQueryParameters3D.create(cell.to_global(at+direction*.004),cell.to_global(at-direction*.004),1,exclude)
			var hit:=world.get_world_3d().direct_space_state.intersect_ray(query)
			check(not hit.is_empty() and cell.to_local(hit.position).distance_to(at)<.00003,"fitted support contact: "+str(contact.label)+" / "+str(contact.owner));supports+=1
	check(parts==fixture.parts.size() and triangles==int(fixture.triangles) and removed==fixture.original_records.size()*12 and supports==fixture.contacts.size(),"native counts bind all original boxes, fitted curtains and ceiling samples")
	_check_curtain_details(world,fixture)
	await _retail_detail_views(world,fixture)
	var directory:=OS.get_environment("SHOT_DIR")
	FileAccess.open(directory.path_join("fittings.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","checks":checks,"parts":parts,"triangles":triangles,"removed":removed,"supports":supports,"failures":failures},"\t"))
	print("FUNERAL DRAPES: checks=",checks," parts=",parts," triangles=",triangles," removed=",removed," supports=",supports," failures=",failures.size())
	return {"checks":checks,"failures":failures,"parts":parts,"triangles":triangles,"supports":supports}

func _isolated_ray(world: OrisonV2RuntimeRoot, model: Node3D, part: String, start: Vector3, finish: Vector3) -> Dictionary:
	var targets:=model.find_children("*","MeshInstance3D",true,false).filter(func(draw):return str(draw.get_meta("funeral_drape_part",""))==part)
	check(targets.size()==1,"actual installed fitting partition: "+part)
	if targets.size()!=1:return {}
	var target: CollisionObject3D=targets[0].find_children("*","CollisionShape3D",true,false)[0].get_parent()
	var exclude: Array[RID]=[]
	for body: CollisionObject3D in world.find_children("*","CollisionObject3D",true,false):
		if body!=target:exclude.append(body.get_rid())
	return world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(start,finish,1,exclude))

func _check_curtain_details(world: OrisonV2RuntimeRoot, fixture: Dictionary) -> void:
	var cell: Node3D=world.passage_region.cell_nodes.shop_funeral_parlour;var model: Node3D=cell.get_node("FuneralDrapes")
	check(fixture.original_records.size()==10 and fixture.assemblies.size()==2 and fixture.closed_stocks.size()==94,"only ten original strips become two fixed supported cloth runs")
	for assembly: Dictionary in fixture.assemblies:
		var identity:=str(assembly.id);var envelope: Array=assembly.envelope
		var cloth: MeshInstance3D=model.find_children("*","MeshInstance3D",true,false).filter(func(draw):return str(draw.get_meta("funeral_drape_part",""))==identity+"__curtain_cloth")[0]
		var bounds:=cloth.mesh.get_aabb()
		var low_x: float=float(cloth.position.x)+float(bounds.position.x);var high_x: float=low_x+float(bounds.size.x)
		var low_y: float=float(cloth.position.y)+float(bounds.position.y);var high_y: float=low_y+float(bounds.size.y)
		var low_z: float=float(cloth.position.z)+float(bounds.position.z);var high_z: float=low_z+float(bounds.size.z)
		check(cloth.transform.basis.is_equal_approx(Basis.IDENTITY) and cloth.material_override==null,"cloth retains unit-scale native metre geometry and its own mapped material")
		check(low_x>=float(envelope[0])-.000003 and high_x<=float(envelope[1])+.000003,"actual folded cloth remains within its original depth envelope")
		check(absf(low_z+float(envelope[3]))<.000003 and absf(high_z+float(envelope[2]))<.000003,"actual cloth retains original run endpoints")
		check(absf(low_y-float(envelope[4]))<.000003 and absf(high_y-2.9225)<.000003,"actual hem retains its original base and support tabs have their declared top")
		# Intersect actual front and rear sheet triangles at standing body height.
		for fraction in [.12,.37,.62,.87]:
			var z: float=-float(envelope[2])+(float(envelope[2])-float(envelope[3]))*fraction
			var front:=_isolated_ray(world,model,identity+"__curtain_cloth",cell.to_global(Vector3(4.8,1.3,z)),cell.to_global(Vector3(4.,1.3,z)))
			var rear:=_isolated_ray(world,model,identity+"__curtain_cloth",cell.to_global(Vector3(3.7,1.3,z)),cell.to_global(Vector3(4.4,1.3,z)))
			check(not front.is_empty() and not rear.is_empty(),"actual imported pleated sheet has both physical sides")
			if not front.is_empty() and not rear.is_empty():
				var separation: float=front.position.distance_to(rear.position)
				check(separation>=.0018 and separation<.0042,"actual thin pleated sheet has finite two-millimetre normal stock")
		for point: Array in assembly.ceiling_points:
			var at:=_v(point)
			# From inside the retained ceiling, ignore every collider except this iron partition.
			var top:=_isolated_ray(world,model,identity+"__curtain_iron",cell.to_global(at+Vector3(.025,.02,.025)),cell.to_global(at+Vector3(.025,-.03,.025)))
			check(not top.is_empty() and absf(cell.to_local(top.position).y-at.y)<.00003,"actual ceiling plate top seats against the retained ceiling underside")
			var rail:=_isolated_ray(world,model,identity+"__curtain_iron",cell.to_global(Vector3(4.8,2.930,at.z)),cell.to_global(Vector3(4.,2.930,at.z)))
			check(not rail.is_empty() and absf(cell.to_local(rail.position).x-4.223)<.00003,"actual suspension rod enters the imported rail")
	var opening_low: float=60.14571428571429;var opening_high: float=61.41428571428571
	check(absf(opening_high-opening_low-1.26857142857142)<.0000001,"original intervening rear opening retains its width")
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		var vertices: PackedVector3Array=draw.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for vertex: Vector3 in vertices:
			var z: float=float(draw.position.z)+float(vertex.z)
			if z>opening_low+.000003 and z<opening_high-.000003:
				check(false,"no curtain or support crosses the retained rear opening");break
	for suffix in ["curtain_cloth","curtain_iron"]:
		for identity in ["storm_shop_funeral_parlour_drape0","storm_shop_funeral_parlour_drape6"]:
			for y in [.1,1.3,2.9,3.1]:
				var hit:=_isolated_ray(world,model,identity+"__"+suffix,cell.to_global(Vector3(5.,y,(opening_low+opening_high)*.5)),cell.to_global(Vector3(3.7,y,(opening_low+opening_high)*.5)))
				check(hit.is_empty(),"actual curtain collisions leave sampled opening heights clear")

func _retail_detail_views(world: OrisonV2RuntimeRoot, _fixture: Dictionary) -> void:
	if not capture_enabled:return
	var cell: Node3D=world.passage_region.cell_nodes.shop_funeral_parlour;var observations: Array=[]
	for view: Dictionary in CURTAIN_BASELINE_VIEWS:
		var feet:=_v(view.feet);var target:=_v(view.target)
		check(_city_clear_station(world,cell.to_global(feet)),"same original floor-supported curtain observation: "+str(view.id))
		world.player.global_position=cell.to_global(feet);world.player.velocity=Vector3.ZERO
		world.player.face_world_point(cell.to_global(target));world.player.set_lamp_enabled(true)
		await _settled_optics();await shot(view.id)
		observations.append(view.duplicate(true))
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("views.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","views":observations,"scope":"Same original standing-capsule observations before and after fitted curtains. No continuous route, sightline, ritual, occupancy, chapel access, moving curtain or load capacity is established."},"\t"))

const CURTAIN_BASELINE_VIEWS: Array=[{"id":"curtain_room","image":"curtain_room.png","feet":[9.31999969482422,0.0299999993294477,61.7879981994629],"target":[4.215,1.65,61.6]},{"id":"short_run","image":"short_run.png","feet":[5.67999982833862,0.0299999993294477,60.0279998779297],"target":[4.215,1.45,59.93]},{"id":"short_header","image":"short_header.png","feet":[5.67999982833862,0.0299999993294477,60.0279998779297],"target":[4.215,2.95,59.93]},{"id":"long_run","image":"long_run.png","feet":[5.67999982833862,0.0299999993294477,63.3720016479492],"target":[4.215,1.45,62.5]},{"id":"long_hem","image":"long_hem.png","feet":[5.67999982833862,0.0299999993294477,63.3720016479492],"target":[4.215,0.1,63.0]},{"id":"long_header","image":"long_header.png","feet":[5.67999982833862,0.0299999993294477,63.3720016479492],"target":[4.215,2.98,63.0]},{"id":"rear_opening","image":"rear_opening.png","feet":[5.67999982833862,0.0299999993294477,60.0279998779297],"target":[4.215,1.45,60.8]},{"id":"short_ceiling","image":"short_ceiling.png","feet":[5.67999982833862,0.0299999993294477,60.0279998779297],"target":[4.215,3.295,60.07571428571429]},{"id":"gallery_direction","image":"gallery_direction.png","feet":[10.0,0.0299999993294477,62.7999992370605],"target":[4.215,1.45,61.7]}]
