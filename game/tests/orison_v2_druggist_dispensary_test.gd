extends "res://tests/orison_v2_city_sweep.gd"
## Actual retained shop boundaries, fitted supports, imported charts and standing detail views.
func _run() -> void:
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928,11,10,20*60);GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var world:=_world_scene().instantiate() as OrisonV2RuntimeRoot;add_child(world)
	await get_tree().physics_frame;await get_tree().physics_frame
	check(not world.startup_failed and not world.passage_region.startup_failed,"composed world fits the original Otis & Son shop")
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
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_druggist_dispensary.json"))
	var installed: bool=passage.cell_nodes.has("shop_otis_son") and passage.cell_nodes.shop_otis_son.has_node("DruggistDispensary")
	check(installed,"actual retained druggist cell and drawer fitting exist before their contracts")
	if not installed:world.shutdown_for_tests();world.free();get_tree().quit(1);return
	check(FileAccess.get_sha256("res://assets/props/druggist_dispensary.glb")==fixture.asset_sha256,"installed mesh binds the native composed dispensary export")
	var parts:=0;var triangles:=0;var removed:=0;var supports:=0
	for record: Dictionary in fixture.runtime.cells:
		var cell: Node3D=passage.cell_nodes[record.id];var model: Node3D=cell.get_node("DruggistDispensary")
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
			var name:=str(draw.get_meta("druggist_dispensary_part"));var expected: Dictionary=fixture.parts.filter(func(row):return row.name==name)[0]
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
				if draw!=null and str(draw.get_meta("druggist_dispensary_part")).begins_with(str(contact.assembly)+"__"):exclude.append(body.get_rid())
			var query:=PhysicsRayQueryParameters3D.create(cell.to_global(at+direction*.004),cell.to_global(at-direction*.004),1,exclude)
			var hit:=world.get_world_3d().direct_space_state.intersect_ray(query)
			check(not hit.is_empty() and cell.to_local(hit.position).distance_to(at)<.00003,"fitted support contact: "+str(contact.label)+" / "+str(contact.owner));supports+=1
	check(parts==fixture.parts.size() and triangles==int(fixture.triangles) and removed==fixture.original_records.size()*12 and supports==fixture.contacts.size(),"native counts bind all original boxes, fitted furniture and floor samples")
	_check_dispensary_details(world,fixture)
	await _retail_detail_views(world,fixture)
	var directory:=OS.get_environment("SHOT_DIR")
	FileAccess.open(directory.path_join("fittings.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","checks":checks,"parts":parts,"triangles":triangles,"removed":removed,"supports":supports,"failures":failures},"\t"))
	print("DRUGGIST DISPENSARY: checks=",checks," parts=",parts," triangles=",triangles," removed=",removed," supports=",supports," failures=",failures.size())
	world.shutdown_for_tests();world.free();await _retired_audio();get_tree().quit(0 if failures.is_empty() else 1)

func _isolated_ray(world: OrisonV2RuntimeRoot, model: Node3D, part: String, start: Vector3, finish: Vector3) -> Dictionary:
	var targets:=model.find_children("*","MeshInstance3D",true,false).filter(func(draw):return str(draw.get_meta("druggist_dispensary_part",""))==part)
	check(targets.size()==1,"actual installed cavity partition: "+part)
	if targets.size()!=1:return {}
	var target: CollisionObject3D=targets[0].find_children("*","CollisionShape3D",true,false)[0].get_parent()
	var exclude: Array[RID]=[]
	for body: CollisionObject3D in world.find_children("*","CollisionObject3D",true,false):
		if body!=target:exclude.append(body.get_rid())
	return world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(start,finish,1,exclude))

func _check_dispensary_details(world: OrisonV2RuntimeRoot, fixture: Dictionary) -> void:
	var cell: Node3D=world.passage_region.cell_nodes.shop_otis_son;var model: Node3D=cell.get_node("DruggistDispensary")
	var prefix:="storm_shop_otis___son_"
	check(fixture.original_records.size()==28 and fixture.assemblies.size()==26,"all original bench, balance and three seven-round ranks keep their source identities")
	var original: Dictionary={}
	for floor: Dictionary in world.passage_region.source_layout.floors:
		if str(floor.id)!="F01":continue
		for row: Dictionary in floor.furniture:original[str(row.id)]=row
	var case_row: Dictionary=original[prefix+"balance_case"];var cr: Array=case_row.rect;var case_top:=1.70
	var cupboard: Dictionary=original[prefix+"poison_cupboard"];var pr: Array=cupboard.rect
	var boards:=0;var rounds:=0;var panes:=0
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		var part:=str(draw.get_meta("druggist_dispensary_part"));var a: AABB=draw.transform*draw.mesh.get_aabb()
		check(a.position.x>=22.38-.000003 and a.end.x<=23.75+.000003 and a.position.z>=44.76-.000003 and a.end.z<=47.74+.000003 and a.position.y>=.01-.000003 and a.end.y<3.3,"actual composed furniture fits retained floor and ceiling")
		if part==prefix+"disp__countertop":
			for raw: Vector3 in draw.mesh.get_faces():
				var p: Vector3=draw.transform*raw
				check(not (p.x<float(pr[2])+.010-.000003 and p.z<=-float(pr[1])+.010-.000003),"actual notched top vertices keep 10mm from retained cupboard")
			check(absf(a.end.y-1.16)<.000003,"original 1.16m work-top datum retained")
		if "round_shelf" in part and part.ends_with("__timber"):
			boards+=1
			for raw: Vector3 in draw.mesh.get_faces():
				var p: Vector3=draw.transform*raw
				if p.x<=float(cr[2])+.000003 and p.z>=-float(cr[3]) and p.z<=-float(cr[1]):check(p.y>=case_top+.035-.000003,"actual stock boards clear the enclosed balance by 35mm")
		if "_round" in part and not "shelf" in part and part.ends_with("__glassish"):
			rounds+=1;check(a.position.y>=1.775-.000003 and a.end.y<=3.075+.000003,"all actual round bodies are seated above the balance instead of inside its bench")
			check(draw.material_override==null,"round bodies retain their source glass optical owner")
		if part in [prefix+"disp__glassish",prefix+"balance_case__glassish"]:
			panes+=1
			var glass:=draw.material_override as ShaderMaterial
			check(glass!=null and glass.shader.resource_path=="res://shaders/lamp_glass_surface.gdshader" and is_equal_approx(float(glass.get_shader_parameter("surface_roughness")),.06),"thin fixed panes use the actual existing clear-glass owner")
	check(boards==3 and rounds==21 and panes==2,"actual imported stock and fixed glazing partitions are complete")
	var case_part:=prefix+"balance_case__wood_dark"
	var hit:=_isolated_ray(world,model,case_part,cell.to_global(Vector3(23.35,1.10,46.17)),cell.to_global(Vector3(23.35,1.25,46.17)))
	check(not hit.is_empty() and absf(cell.to_local(hit.position).y-1.16)<.00003,"case has an actual seated lower face")
	var round_part:=prefix+"round0_0__glassish"
	hit=_isolated_ray(world,model,round_part,cell.to_global(Vector3(23.57,2.12,46.465)),cell.to_global(Vector3(23.57,1.70,46.465)))
	check(not hit.is_empty() and absf(cell.to_local(hit.position).y-1.793)<.00003,"actual round neck opens into an 18mm inner glass base beneath its separate stopper")
	var top_part:=prefix+"disp__countertop"
	hit=_isolated_ray(world,model,top_part,cell.to_global(Vector3(23.10,1.30,45.0)),cell.to_global(Vector3(23.10,1.0,45.0)))
	check(hit.is_empty(),"actual top face has a cupboard notch rather than an overlapping face")
	hit=_isolated_ray(world,model,top_part,cell.to_global(Vector3(23.35,1.30,46.875)),cell.to_global(Vector3(23.35,1.0,46.875)))
	check(not hit.is_empty() and absf(cell.to_local(hit.position).y-1.16)<.00003,"actual work top remains under the separate fitted mortar")

func _retail_detail_views(world: OrisonV2RuntimeRoot, fixture: Dictionary) -> void:
	var cell: Node3D=world.passage_region.cell_nodes.shop_otis_son
	var r: Array=fixture.assemblies[0].floor.rect;var observations: Array=[]
	for view: Array in [["dispensary",Vector3(21.8,.03,46.4),Vector3(23.45,1.65,46.1)],["balance",Vector3(22.25,.03,46.17),Vector3(23.35,1.44,46.17)],["round_ranks",Vector3(21.95,.03,45.55),Vector3(23.57,2.45,45.55)],["bench_notch",Vector3(21.85,.03,45.90),Vector3(23.2,1.12,45.10)],["mortar_context",Vector3(22.30,.03,47.15),Vector3(23.35,1.4,46.875)],["shop_context",Vector3(17.30,.03,45.65),Vector3(23.1,1.6,46.2)]]:
		var preferred: Vector3=view[1];var selected:=preferred;var distance:=INF
		if not _city_clear_station(world,cell.to_global(preferred)):
			for u in range(1,25):
				for v in range(1,25):
					var at:=Vector3(lerpf(r[0],r[2],u/25.),.03,-lerpf(r[1],r[3],v/25.))
					if at.distance_squared_to(preferred)<distance and _city_clear_station(world,cell.to_global(at)):
						selected=at;distance=at.distance_squared_to(preferred)
		check(_city_clear_station(world,cell.to_global(selected)),"actual floor-supported cabinet observation: "+str(view[0]))
		world.player.global_position=cell.to_global(selected);world.player.velocity=Vector3.ZERO
		world.player.face_world_point(cell.to_global(view[2]));world.player.set_lamp_enabled(true)
		await _settled_optics();await shot(view[0])
		observations.append({"id":view[0],"requested_feet":[preferred.x,preferred.y,preferred.z],"feet":[selected.x,selected.y,selected.z],"target":[view[2].x,view[2].y,view[2].z],"image":str(view[0])+".png"})
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("views.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","views":observations,"scope":"Standing-capsule composed dispensary observations. Medicine/poison custody, stock state, operating dispensing/fountain, continuous routes and independent services retain separate authority."},"\t"))
