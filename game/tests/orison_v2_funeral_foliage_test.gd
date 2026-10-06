extends "res://tests/orison_v2_city_sweep.gd"
## Actual retained shop boundaries, fitted supports, imported charts and standing detail views.
func _run() -> void:
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928,11,10,20*60);GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var world:=_world_scene().instantiate() as OrisonV2RuntimeRoot;add_child(world)
	await get_tree().physics_frame;await get_tree().physics_frame
	check(not world.startup_failed and not world.passage_region.startup_failed,"two source-owned potted palms and two laid wreaths fit the funeral parlour")
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
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_funeral_foliage.json"))
	var installed: bool=passage.cell_nodes.has("shop_funeral_parlour") and passage.cell_nodes.shop_funeral_parlour.has_node("FuneralFoliage")
	check(installed,"actual retained funeral cell and native fittings exist before their contracts")
	if not installed:world.shutdown_for_tests();world.free();get_tree().quit(1);return
	check(FileAccess.get_sha256("res://assets/props/funeral_foliage.glb")==fixture.asset_sha256,"installed mesh binds the native foliage export")
	var parts:=0;var triangles:=0;var removed:=0;var supports:=0
	for record: Dictionary in fixture.runtime.cells:
		var cell: Node3D=passage.cell_nodes[record.id];var model: Node3D=cell.get_node("FuneralFoliage")
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
			var name:=str(draw.get_meta("funeral_foliage_part"));var expected: Dictionary=fixture.parts.filter(func(row):return row.name==name)[0]
			check(count==int(expected.triangles) and expected.cell==record.id,"each fitted partition binds exact native triangles and cell")
			_check_cap_mapping(draw.mesh,true)
			var mat:=draw.mesh.surface_get_material(0) as StandardMaterial3D
			check(mat!=null and not mat.uv1_triplanar and mat.albedo_texture!=null and mat.roughness_texture!=null and mat.normal_texture!=null,"catalogued foliage, timber, brass and soil maps reach native metre charts")
			var source: StandardMaterial3D
			var runtime_part: Dictionary=record.parts.filter(func(row):return row.name==name)[0]
			for original_draw: MeshInstance3D in originals:
				if str(original_draw.name).trim_suffix("-col").ends_with("_"+str(runtime_part.key)):source=originals[original_draw].surface_get_material(0)
			if runtime_part.has("catalog_key"):
				var library:=MatLib.get_mat(str(runtime_part.catalog_key))
				check(library!=mat and library.uv1_triplanar and library.albedo_texture==mat.albedo_texture and library.roughness_texture==mat.roughness_texture and library.normal_texture==mat.normal_texture and mat.uv1_scale.is_equal_approx(library.uv1_scale),"local registered finishes use their catalogue owner without changing shared materials")
				check(mat.metallic==library.metallic and mat.roughness==library.roughness and mat.normal_scale==library.normal_scale,"catalogued finish retains its metallic, roughness and normal strength")
			else:
				check(source!=null and source!=mat and source.albedo_texture==mat.albedo_texture and source.roughness_texture==mat.roughness_texture and source.normal_texture==mat.normal_texture,"catalogued foliage, timber, brass and soil retain their shipping maps")
				check(source!=null and source.metallic==mat.metallic and source.roughness==mat.roughness and source.normal_scale==mat.normal_scale,"source finish retains its metallic, roughness and normal strength")
			if runtime_part.has("tint"):
				var tint: Array=runtime_part.tint
				check(mat.albedo_color.is_equal_approx(Color(tint[0],tint[1],tint[2],tint[3])),"local green leaf binding retains its declared tint")
			var bounds: AABB=draw.transform*draw.mesh.get_aabb();check(maxf(maxf(bounds.size.x,bounds.size.y),bounds.size.z)<5.,"individual furniture partitions retain bounded culling")
			var shape: CollisionShape3D=draw.find_children("*","CollisionShape3D",true,false)[0]
			check((shape.shape as ConcavePolygonShape3D).get_faces()==draw.mesh.get_faces() and shape.global_transform.is_equal_approx(draw.global_transform),"native furniture physical triangles and poses match visible triangles")
		for contact: Dictionary in fixture.contacts:
			var at:=_v(contact.point);var direction:=_v(contact.direction);var exclude: Array[RID]=[world.player.get_rid()]
			for body: CollisionObject3D in model.find_children("*","CollisionObject3D",true,false):
				var draw:=body.get_parent() as MeshInstance3D
				if draw!=null and str(draw.get_meta("funeral_foliage_part")).begins_with(str(contact.assembly)+"__"):exclude.append(body.get_rid())
			var query:=PhysicsRayQueryParameters3D.create(cell.to_global(at+direction*.004),cell.to_global(at-direction*.004),1,exclude)
			var hit:=world.get_world_3d().direct_space_state.intersect_ray(query)
			check(not hit.is_empty() and cell.to_local(hit.position).distance_to(at)<.00003,"fitted support contact: "+str(contact.label)+" / "+str(contact.owner));supports+=1
	check(parts==fixture.parts.size() and triangles==int(fixture.triangles) and removed==fixture.original_records.size()*12 and supports==fixture.contacts.size(),"native counts bind all original boxes, fitted foliage and floor samples")
	_check_foliage_details(world,fixture)
	await _retail_detail_views(world,fixture)
	var directory:=OS.get_environment("SHOT_DIR")
	FileAccess.open(directory.path_join("fittings.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","checks":checks,"parts":parts,"triangles":triangles,"removed":removed,"supports":supports,"failures":failures},"\t"))
	print("FUNERAL FOLIAGE: checks=",checks," parts=",parts," triangles=",triangles," removed=",removed," supports=",supports," failures=",failures.size())
	world.shutdown_for_tests();world.free();await _retired_audio();get_tree().quit(0 if failures.is_empty() else 1)

func _isolated_ray(world: OrisonV2RuntimeRoot, model: Node3D, part: String, start: Vector3, finish: Vector3) -> Dictionary:
	var targets:=model.find_children("*","MeshInstance3D",true,false).filter(func(draw):return str(draw.get_meta("funeral_foliage_part",""))==part)
	check(targets.size()==1,"actual installed fitting partition: "+part)
	if targets.size()!=1:return {}
	var target: CollisionObject3D=targets[0].find_children("*","CollisionShape3D",true,false)[0].get_parent()
	var exclude: Array[RID]=[]
	for body: CollisionObject3D in world.find_children("*","CollisionObject3D",true,false):
		if body!=target:exclude.append(body.get_rid())
	return world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(start,finish,1,exclude))

func _check_foliage_details(world: OrisonV2RuntimeRoot, fixture: Dictionary) -> void:
	var cell: Node3D=world.passage_region.cell_nodes.shop_funeral_parlour;var model: Node3D=cell.get_node("FuneralFoliage")
	check(fixture.original_records.size()==8 and fixture.assemblies.size()==4 and fixture.closed_stocks.size()==742,"only eight source records become two supported wreaths and two potted palms")
	for assembly: Dictionary in fixture.assemblies:
		var identity:=str(assembly.id)
		var row: Dictionary=fixture.original_records.filter(func(item):return str(item.id)==identity)[0]
		var foliage_id:=identity.replace("_palm_pot","_palm").replace("_stand","_wreath")
		var foliage_row: Dictionary=fixture.original_records.filter(func(item):return str(item.id)==foliage_id)[0]
		var rect: Array=row.rect;var envelope: Array=foliage_row.rect
		var cx: float=(float(rect[0])+float(rect[2]))*.5;var z: float=-(float(rect[1])+float(rect[3]))*.5
		var foliage: MeshInstance3D=model.find_children("*","MeshInstance3D",true,false).filter(func(draw):return str(draw.get_meta("funeral_foliage_part",""))==identity+"__foliage")[0]
		check(foliage.transform.basis.is_equal_approx(Basis.IDENTITY) and foliage.material_override==null,"actual foliage retains unit-scale metre geometry and its mapped material")
		var within:=true
		for vertex: Vector3 in foliage.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			# Add float32 mesh offsets as doubles before testing original metres.
			var x: float=float(foliage.position.x)+float(vertex.x);var y: float=float(foliage.position.y)+float(vertex.y);var depth: float=float(foliage.position.z)+float(vertex.z)
			within=within and x>=float(envelope[0])-.000003 and x<=float(envelope[2])+.000003 and depth>=-float(envelope[3])-.000003 and depth<=-float(envelope[1])+.000003 and y<=float(foliage_row.z0)+float(foliage_row.h)+.000003
		check(within,"actual imported leaves stay inside their original plans and maximum heights")
		if str(assembly.kind)=="laid_wreath":
			var top:=_isolated_ray(world,model,identity+"__stand_frame",cell.to_global(Vector3(cx,1.4,z)),cell.to_global(Vector3(cx,.70,z)))
			check(not top.is_empty() and absf(cell.to_local(top.position).y-.91)<.00003,"actual wreath stand retains its original support height")
			for suffix in ["foliage","wreath_twig"]:
				var hole:=_isolated_ray(world,model,identity+"__"+suffix,cell.to_global(Vector3(cx,1.4,z)),cell.to_global(Vector3(cx,.70,z)))
				check(hole.is_empty(),"actual laid wreath retains an open centre above its stand")
		else:
			var rx: float=(float(rect[2])-float(rect[0]))*.5
			var rim:=_isolated_ray(world,model,identity+"__pot_brass",cell.to_global(Vector3(cx+rx*.97,1.2,z)),cell.to_global(Vector3(cx+rx*.97,.3,z)))
			check(not rim.is_empty() and absf(cell.to_local(rim.position).y-.57)<.00003,"actual open brass rim retains the original pot top")
			var cavity:=_isolated_ray(world,model,identity+"__pot_brass",cell.to_global(Vector3(cx+.02,1.2,z)),cell.to_global(Vector3(cx+.02,.04,z)))
			check(not cavity.is_empty() and absf(cell.to_local(cavity.position).y-.075)<.00003,"actual pot centre is open down to its closed bottom")
			var soil:=_isolated_ray(world,model,identity+"__soil",cell.to_global(Vector3(cx+.02,1.2,z)),cell.to_global(Vector3(cx+.02,.45,z)))
			check(not soil.is_empty() and absf(cell.to_local(soil.position).y-.555)<.00003,"actual display soil sits below the pot rim")
			var underside:=_isolated_ray(world,model,identity+"__pot_brass",cell.to_global(Vector3(cx+rx*.64,-.2,z)),cell.to_global(Vector3(cx+rx*.64,.12,z)))
			check(not underside.is_empty() and absf(cell.to_local(underside.position).y-.01)<.00003,"actual foot ring sits on the retained floor top")
	check(not fixture.runtime.cells[0].replace.any(func(row):return str(row.id)=="storm_shop_funeral_parlour_boh_door"),"retained decorative rear door is outside the eight replacement owners")

func _retail_detail_views(world: OrisonV2RuntimeRoot, _fixture: Dictionary) -> void:
	var cell: Node3D=world.passage_region.cell_nodes.shop_funeral_parlour;var observations: Array=[]
	for view: Dictionary in FOLIAGE_BASELINE_VIEWS:
		var feet:=_v(view.feet);var target:=_v(view.target)
		check(_city_clear_station(world,cell.to_global(feet)),"same original floor-supported foliage observation: "+str(view.id))
		world.player.global_position=cell.to_global(feet);world.player.velocity=Vector3.ZERO
		world.player.face_world_point(cell.to_global(target));world.player.set_lamp_enabled(true)
		await _settled_optics();await shot(view.id)
		observations.append(view.duplicate(true))
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("views.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","views":observations,"scope":"Same original standing-capsule observations before and after fitted palms and wreaths. No continuous route, sightline, ritual, occupancy, chapel access, moving curtain or load capacity is established."},"\t"))

const FOLIAGE_BASELINE_VIEWS: Array=[{"id":"foliage_room","image":"foliage_room.png","feet":[9.31999969482422,0.0299999993294477,61.7879981994629],"target":[4.825,1.0,61.7]},{"id":"west_palm","image":"west_palm.png","feet":[5.67999982833862,0.0299999993294477,60.0279998779297],"target":[4.825,1.1,59.95]},{"id":"west_pot","image":"west_pot.png","feet":[5.67999982833862,0.0299999993294477,60.0279998779297],"target":[4.825,0.52,59.95]},{"id":"west_fronds","image":"west_fronds.png","feet":[5.67999982833862,0.0299999993294477,60.0279998779297],"target":[4.825,1.52,59.95]},{"id":"east_palm","image":"east_palm.png","feet":[5.67999982833862,0.0299999993294477,63.3720016479492],"target":[4.825,1.1,63.45]},{"id":"east_pot","image":"east_pot.png","feet":[5.67999982833862,0.0299999993294477,63.3720016479492],"target":[4.825,0.52,63.45]},{"id":"east_fronds","image":"east_fronds.png","feet":[5.67999982833862,0.0299999993294477,63.3720016479492],"target":[4.825,1.52,63.45]},{"id":"west_wreath","image":"west_wreath.png","feet":[9.31999969482422,0.0299999993294477,61.7879981994629],"target":[9.725,0.98,59.975]},{"id":"east_wreath","image":"east_wreath.png","feet":[9.31999969482422,0.0299999993294477,61.7879981994629],"target":[8.89,0.98,63.64]},{"id":"wreath_gallery","image":"wreath_gallery.png","feet":[10.0,0.0299999993294477,62.7999992370605],"target":[8.89,0.6,63.64]},{"id":"curtain_opening","image":"curtain_opening.png","feet":[5.67999982833862,0.0299999993294477,60.0279998779297],"target":[4.215,1.45,60.8]}]
