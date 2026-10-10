extends "res://tests/orison_v2_city_sweep.gd"
## Actual retained shop boundaries, fitted supports, imported charts and standing detail views.
func _run() -> void:
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928,11,10,20*60);GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var world:=_world_scene().instantiate() as OrisonV2RuntimeRoot;add_child(world)
	await get_tree().physics_frame;await get_tree().physics_frame
	check(not world.startup_failed and not world.passage_region.startup_failed,"original lectern and empty bier fit the funeral parlour")
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
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_funeral_fittings.json"))
	var installed: bool=passage.cell_nodes.has("shop_funeral_parlour") and passage.cell_nodes.shop_funeral_parlour.has_node("FuneralFittings")
	check(installed,"actual retained funeral cell and native fittings exist before their contracts")
	if not installed:world.shutdown_for_tests();world.free();get_tree().quit(1);return
	check(FileAccess.get_sha256("res://assets/props/funeral_fittings.glb")==fixture.asset_sha256,"installed mesh binds the native funeral-fitting export")
	var parts:=0;var triangles:=0;var removed:=0;var supports:=0
	for record: Dictionary in fixture.runtime.cells:
		var cell: Node3D=passage.cell_nodes[record.id];var model: Node3D=cell.get_node("FuneralFittings")
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
			var name:=str(draw.get_meta("funeral_part"));var expected: Dictionary=fixture.parts.filter(func(row):return row.name==name)[0]
			check(count==int(expected.triangles) and expected.cell==record.id,"each fitted partition binds exact native triangles and cell")
			_check_cap_mapping(draw.mesh,true)
			var mat:=draw.mesh.surface_get_material(0) as StandardMaterial3D
			check(mat!=null and not mat.uv1_triplanar and mat.albedo_texture!=null and mat.roughness_texture!=null and mat.normal_texture!=null,"original timber and paper maps reach native metre charts")
			var source: StandardMaterial3D
			var runtime_part: Dictionary=record.parts.filter(func(row):return row.name==name)[0]
			for original_draw: MeshInstance3D in originals:
				if str(original_draw.name).trim_suffix("-col").ends_with("_"+str(runtime_part.key)):source=originals[original_draw].surface_get_material(0)
			if runtime_part.has("catalog_key"):
				var library:=MatLib.get_mat(str(runtime_part.catalog_key))
				check(library!=mat and library.uv1_triplanar and library.albedo_texture==mat.albedo_texture and library.roughness_texture==mat.roughness_texture and library.normal_texture==mat.normal_texture and mat.uv1_scale.is_equal_approx(library.uv1_scale),"local registered finishes use their catalogue owner without changing shared materials")
				check(mat.metallic==library.metallic and mat.roughness==library.roughness and mat.normal_scale==library.normal_scale,"catalogued finish retains its metallic, roughness and normal strength")
			else:
				check(source!=null and source!=mat and source.albedo_texture==mat.albedo_texture and source.roughness_texture==mat.roughness_texture and source.normal_texture==mat.normal_texture,"original timber and paper retain their shipping maps")
				check(source!=null and source.metallic==mat.metallic and source.roughness==mat.roughness and source.normal_scale==mat.normal_scale,"source finish retains its metallic, roughness and normal strength")
			if runtime_part.has("tint"):
				var tint: Array=runtime_part.tint
				check(mat.albedo_color.is_equal_approx(Color(tint[0],tint[1],tint[2],tint[3])),"local brown card binding retains its declared tint")
			var bounds: AABB=draw.transform*draw.mesh.get_aabb();check(maxf(maxf(bounds.size.x,bounds.size.y),bounds.size.z)<5.,"individual furniture partitions retain bounded culling")
			var shape: CollisionShape3D=draw.find_children("*","CollisionShape3D",true,false)[0]
			check((shape.shape as ConcavePolygonShape3D).get_faces()==draw.mesh.get_faces() and shape.global_transform.is_equal_approx(draw.global_transform),"native furniture physical triangles and poses match visible triangles")
		for contact: Dictionary in fixture.contacts:
			var at:=_v(contact.point);var direction:=_v(contact.direction);var exclude: Array[RID]=[world.player.get_rid()]
			for body: CollisionObject3D in model.find_children("*","CollisionObject3D",true,false):
				var draw:=body.get_parent() as MeshInstance3D
				if draw!=null and str(draw.get_meta("funeral_part")).begins_with(str(contact.assembly)+"__"):exclude.append(body.get_rid())
			var query:=PhysicsRayQueryParameters3D.create(cell.to_global(at+direction*.004),cell.to_global(at-direction*.004),1,exclude)
			var hit:=world.get_world_3d().direct_space_state.intersect_ray(query)
			check(not hit.is_empty() and cell.to_local(hit.position).distance_to(at)<.00003,"fitted support contact: "+str(contact.label)+" / "+str(contact.owner));supports+=1
	check(parts==fixture.parts.size() and triangles==int(fixture.triangles) and removed==fixture.original_records.size()*12 and supports==fixture.contacts.size(),"native counts bind all original boxes, fitted furniture and floor samples")
	_check_funeral_details(world,fixture)
	await _retail_detail_views(world,fixture)
	var directory:=OS.get_environment("SHOT_DIR")
	FileAccess.open(directory.path_join("fittings.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","checks":checks,"parts":parts,"triangles":triangles,"removed":removed,"supports":supports,"failures":failures},"\t"))
	print("FUNERAL FITTINGS: checks=",checks," parts=",parts," triangles=",triangles," removed=",removed," supports=",supports," failures=",failures.size())
	world.shutdown_for_tests();world.free();await _retired_audio();get_tree().quit(0 if failures.is_empty() else 1)

func _isolated_ray(world: OrisonV2RuntimeRoot, model: Node3D, part: String, start: Vector3, finish: Vector3) -> Dictionary:
	var targets:=model.find_children("*","MeshInstance3D",true,false).filter(func(draw):return str(draw.get_meta("funeral_part",""))==part)
	check(targets.size()==1,"actual installed fitting partition: "+part)
	if targets.size()!=1:return {}
	var target: CollisionObject3D=targets[0].find_children("*","CollisionShape3D",true,false)[0].get_parent()
	var exclude: Array[RID]=[]
	for body: CollisionObject3D in world.find_children("*","CollisionObject3D",true,false):
		if body!=target:exclude.append(body.get_rid())
	return world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(start,finish,1,exclude))

func _check_funeral_details(world: OrisonV2RuntimeRoot, fixture: Dictionary) -> void:
	var cell: Node3D=world.passage_region.cell_nodes.shop_funeral_parlour;var model: Node3D=cell.get_node("FuneralFittings")
	check(fixture.original_records.size()==6 and fixture.assemblies.size()==2,"six original source identities become only the lectern and empty bier")
	var original: Dictionary={}
	for row: Dictionary in fixture.original_records:original[str(row.id)]=row
	var lectern:="storm_shop_funeral_parlour_lectern";var bier:="storm_shop_funeral_parlour_bier"
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		var part:=str(draw.get_meta("funeral_part"));var bounds:=draw.mesh.get_aabb()
		var low_y: float=float(draw.position.y)+float(bounds.position.y);var high_y: float=low_y+float(bounds.size.y)
		check(draw.transform.basis.is_equal_approx(Basis.IDENTITY),"native funeral fitting retains unit-scale metre geometry")
		check(draw.material_override==null,"native fitting uses its own mapped material")
		if part.ends_with("__lectern_top") or part.ends_with("__bier_deck") or part.ends_with("__book_cover"):
			var identity: String=lectern+"_top" if part.ends_with("__lectern_top") else bier if part.ends_with("__bier_deck") else "storm_shop_funeral_parlour_book"
			var row: Dictionary=original[identity];var r: Array=row.rect
			var low_x: float=float(draw.position.x)+float(bounds.position.x);var high_x: float=low_x+float(bounds.size.x)
			var low_z: float=float(draw.position.z)+float(bounds.position.z);var high_z: float=low_z+float(bounds.size.z)
			if part.ends_with("__book_cover"):
				# Dossier slice 64: the register lies open across the desk, its binding seated on the original book base.
				var mid: float=(float(r[1])+float(r[3]))*.5
				check(absf(low_x-float(r[0]))<.000003 and absf(high_x-float(r[2]))<.000003 and absf(low_z+mid+.28)<.000003 and absf(high_z+mid-.28)<.000003,"actual open register spans the desk at the book's original depth")
				check(absf(low_y-float(row.z0))<.000003 and high_y<float(row.z0)+.0055,"actual open register's binding lies on the original book base")
			else:
				check(absf(low_x-float(r[0]))<.000003 and absf(high_x-float(r[2]))<.000003 and absf(low_z+float(r[3]))<.000003 and absf(high_z+float(r[1]))<.000003,"actual desk, book or empty deck retains its original plan")
				check(absf(low_y-float(row.z0))<.000003 and absf(high_y-float(row.z0)-float(row.h))<.000003,"actual desk, book or empty deck retains its original base and top")
		if part.ends_with("__lectern_body") or part.ends_with("__bier_frame"):check(absf(low_y-.01)<.000003,"actual native floor base reaches the original shop floor")
		if part.begins_with(bier+"__"):check(high_y<=.790003,"nothing is installed above the deliberately empty bier deck")
	for contact: Dictionary in fixture.contacts:
		var at:=_v(contact.point);var suffix:="__lectern_body" if str(contact.assembly)==lectern else "__bier_frame"
		var hit:=_isolated_ray(world,model,str(contact.assembly)+suffix,cell.to_global(at-Vector3(0,.10,0)),cell.to_global(at+Vector3(0,.02,0)))
		check(not hit.is_empty() and absf(cell.to_local(hit.position).y-.01)<.00003,"actual imported support underside meets its floor sample")
	var hit:=_isolated_ray(world,model,lectern+"__lectern_top",cell.to_global(Vector3(5.,1.25,61.7)),cell.to_global(Vector3(5.,1.15,61.7)))
	check(not hit.is_empty() and absf(cell.to_local(hit.position).y-1.22)<.00003,"actual original desk surface seats the closed book")
	hit=_isolated_ray(world,model,lectern+"__book_cover",cell.to_global(Vector3(5.035,1.30,61.7)),cell.to_global(Vector3(5.035,1.20,61.7)))
	check(not hit.is_empty() and absf(cell.to_local(hit.position).y-1.225)<.00003,"actual open register's binding lies flat under its gutter")
	for i in 5:
		var x:=5.28+.72*(float(i)+.5)/5.
		hit=_isolated_ray(world,model,bier+"__bier_deck",cell.to_global(Vector3(x,.9,61.7)),cell.to_global(Vector3(x,.65,61.7)))
		check(not hit.is_empty() and absf(cell.to_local(hit.position).y-.79)<.00003,"each actual empty deck plank retains the source top")
	for i in range(1,5):
		var x:=5.28+.72*float(i)/5.
		hit=_isolated_ray(world,model,bier+"__bier_deck",cell.to_global(Vector3(x,.9,61.7)),cell.to_global(Vector3(x,.65,61.7)))
		check(hit.is_empty(),"actual narrow plank seam remains open through the deck")
	for z in [60.74,62.66]:
		hit=_isolated_ray(world,model,bier+"__bier_frame",cell.to_global(Vector3(5.64,.75,z)),cell.to_global(Vector3(5.64,.60,z)))
		check(not hit.is_empty() and absf(cell.to_local(hit.position).y-.692)<.00003,"actual trestle bearing cleat bridges the original crown-to-deck gap")

func _retail_detail_views(world: OrisonV2RuntimeRoot, _fixture: Dictionary) -> void:
	var cell: Node3D=world.passage_region.cell_nodes.shop_funeral_parlour;var observations: Array=[]
	var views: Array=FUNERAL_BASELINE_VIEWS
	for view: Dictionary in views:
		var feet:=_v(view.feet);var target:=_v(view.target)
		check(_city_clear_station(world,cell.to_global(feet)),"same original floor-supported funeral observation: "+str(view.id))
		world.player.global_position=cell.to_global(feet);world.player.velocity=Vector3.ZERO
		world.player.face_world_point(cell.to_global(target));world.player.set_lamp_enabled(true)
		await _settled_optics();await shot(view.id)
		observations.append(view.duplicate(true))
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("views.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","views":observations,"scope":"Same original standing-capsule funeral observations. No route, sightline, ritual, occupancy, chapel access or load capacity is established."},"\t"))

const FUNERAL_BASELINE_VIEWS: Array=[{"feet":[9.31999969482422,0.0299999993294477,61.7879981994629],"id":"room_overview","image":"room_overview.png","requested_feet":[8.19999980926514,0.0299999993294477,61.7000007629395],"target":[5.65000009536743,0.699999988079071,61.7000007629395]},{"feet":[5.67999982833862,0.0299999993294477,63.3720016479492],"id":"empty_bier","image":"empty_bier.png","requested_feet":[6.69999980926514,0.0299999993294477,61.7000007629395],"target":[5.6399998664856,0.680000007152557,61.7000007629395]},{"feet":[5.67999982833862,0.0299999993294477,60.0279998779297],"id":"trestle0","image":"trestle0.png","requested_feet":[6.30000019073486,0.0299999993294477,60.0],"target":[5.6399998664856,0.449999988079071,60.7400016784668]},{"feet":[5.67999982833862,0.0299999993294477,63.3720016479492],"id":"trestle1","image":"trestle1.png","requested_feet":[6.30000019073486,0.0299999993294477,63.4000015258789],"target":[5.6399998664856,0.449999988079071,62.6599998474121]},{"feet":[5.67999982833862,0.0299999993294477,60.0279998779297],"id":"lectern","image":"lectern.png","requested_feet":[6.19999980926514,0.0299999993294477,60.6500015258789],"target":[5.0,1.10000002384186,61.7000007629395]},{"feet":[5.67999982833862,0.0299999993294477,60.0279998779297],"id":"book","image":"book.png","requested_feet":[6.09999990463257,0.0299999993294477,60.4000015258789],"target":[5.03499984741211,1.24500000476837,61.7000007629395]},{"feet":[5.67999982833862,0.0299999993294477,60.0279998779297],"id":"lectern_base","image":"lectern_base.png","requested_feet":[6.19999980926514,0.0299999993294477,60.6500015258789],"target":[5.0,0.100000001490116,61.7000007629395]},{"feet":[10.0,0.0299999993294477,62.7999992370605],"id":"gallery_direction","image":"gallery_direction.png","requested_feet":[10.0,0.0299999993294477,62.7999992370605],"target":[6.0,0.800000011920929,61.7000007629395]}]
