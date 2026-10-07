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
	check(not world.startup_failed and not world.passage_region.startup_failed,"original cupboard fits the Otis & Son shop")
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
	var passage: OrisonV2PassageRegion=world.passage_region
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_druggist_cupboard.json"))
	var installed: bool=passage.cell_nodes.has("shop_otis_son") and passage.cell_nodes.shop_otis_son.has_node("DruggistCupboard")
	check(installed,"actual retained druggist cell and drawer fitting exist before their contracts")
	if not installed:return {"checks":checks,"parts":0,"triangles":0,"removed":0,"supports":0,"failures":failures.duplicate()}
	check(FileAccess.get_sha256("res://assets/props/druggist_cupboard.glb")==fixture.asset_sha256,"installed mesh binds the native cupboard export")
	var parts:=0;var triangles:=0;var removed:=0;var supports:=0
	for record: Dictionary in fixture.runtime.cells:
		var cell: Node3D=passage.cell_nodes[record.id];var model: Node3D=cell.get_node("DruggistCupboard")
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
			var name:=str(draw.get_meta("druggist_cupboard_part"));var expected: Dictionary=fixture.parts.filter(func(row):return row.name==name)[0]
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
				if draw!=null and str(draw.get_meta("druggist_cupboard_part")).begins_with(str(contact.assembly)+"__"):exclude.append(body.get_rid())
			var query:=PhysicsRayQueryParameters3D.create(cell.to_global(at+direction*.004),cell.to_global(at-direction*.004),1,exclude)
			var hit:=world.get_world_3d().direct_space_state.intersect_ray(query)
			check(not hit.is_empty() and cell.to_local(hit.position).distance_to(at)<.00003,"fitted support contact: "+str(contact.label)+" / "+str(contact.owner));supports+=1
	check(parts==fixture.parts.size() and triangles==int(fixture.triangles) and removed==fixture.original_records.size()*12 and supports==fixture.contacts.size(),"native counts bind all original boxes, fitted furniture and floor samples")
	_check_cupboard_details(world,fixture)
	await _retail_detail_views(world,fixture)
	var directory:=OS.get_environment("SHOT_DIR")
	FileAccess.open(directory.path_join("fittings.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","checks":checks,"parts":parts,"triangles":triangles,"removed":removed,"supports":supports,"failures":failures},"\t"))
	print("DRUGGIST CUPBOARD: checks=",checks," parts=",parts," triangles=",triangles," removed=",removed," supports=",supports," failures=",failures.size())
	return {"checks":checks,"parts":parts,"triangles":triangles,"removed":removed,"supports":supports,"failures":failures.duplicate()}

func _isolated_ray(world: OrisonV2RuntimeRoot, model: Node3D, part: String, start: Vector3, finish: Vector3) -> Dictionary:
	var targets:=model.find_children("*","MeshInstance3D",true,false).filter(func(draw):return str(draw.get_meta("druggist_cupboard_part",""))==part)
	check(targets.size()==1,"actual installed cavity partition: "+part)
	if targets.size()!=1:return {}
	var target: CollisionObject3D=targets[0].find_children("*","CollisionShape3D",true,false)[0].get_parent()
	var exclude: Array[RID]=[]
	for body: CollisionObject3D in world.find_children("*","CollisionObject3D",true,false):
		if body!=target:exclude.append(body.get_rid())
	return world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(start,finish,1,exclude))

func _check_cupboard_details(world: OrisonV2RuntimeRoot, fixture: Dictionary) -> void:
	var cell: Node3D=world.passage_region.cell_nodes.shop_otis_son;var model: Node3D=cell.get_node("DruggistCupboard")
	var prefix:="storm_shop_otis___son_"
	check(fixture.original_records.size()==14 and fixture.assemblies.size()==7,"all original case, pane, six bottles and corresponding rib identities survive")
	var originals: Dictionary={}
	for floor: Dictionary in world.passage_region.source_layout.floors:
		if str(floor.id)!="F01":continue
		for row: Dictionary in floor.furniture:originals[str(row.id)]=row
	var cr: Dictionary=originals[prefix+"poison_cupboard"];var rect: Array=cr.rect
	var bottles:=0;var ribs:=0;var panes:=0
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		var part:=str(draw.get_meta("druggist_cupboard_part"));var a: AABB=draw.transform*draw.mesh.get_aabb()
		check(a.position.x>=float(rect[0])-.000003 and a.end.x<=float(rect[2])+.000003 and a.position.z>=-float(rect[3])-.000003 and a.end.z<=-float(rect[1])+.000003 and a.position.y>=.01-.000003 and a.end.y<=1.94+.000003,"actual case, inset pane and passive hardware remain inside the original case plan")
		if part==prefix+"poison_cupboard__glassish":
			panes+=1
			var local_bounds:=draw.mesh.get_aabb()
			var thickness: float=(draw.transform.basis*Vector3(0.,0.,local_bounds.size.z)).length()
			var centre_offset:=draw.transform.basis*local_bounds.get_center()
			var centre_z: float=float(draw.transform.origin.z)+float(centre_offset.z)
			print("CUPBOARD PANE MEASUREMENT: translated_aabb_width=",a.size.z," imported_local_width=",thickness," centre_z=",centre_z)
			check(absf(thickness-.006)<.000003 and absf(centre_z-45.202)<.000003,"actual six-millimetre pane moves 28mm inside its original projection")
			var glass:=draw.material_override as ShaderMaterial
			check(glass!=null and glass.shader.resource_path=="res://shaders/lamp_glass_surface.gdshader" and is_equal_approx(float(glass.get_shader_parameter("surface_roughness")),.06),"fixed pane retains the existing architectural glass optical owner")
		if part.ends_with("__glass_red") or part.ends_with("__glass_teal"):
			bottles+=1
			var identity:=part.trim_suffix("__glass_red").trim_suffix("__glass_teal")
			check(originals.has(identity),"actual bottle partition resolves its complete retained source identity")
			if not originals.has(identity):continue
			var row: Dictionary=originals[identity];var r: Array=row.rect
			check(absf(a.position.y-float(row.z0))<.000003 and absf(a.end.y-(float(row.z0)+.310))<.000003 and absf(a.size.x-.067)<.000003,"hollow bottle keeps its source seat and actual narrow round diameter")
			check(absf(a.get_center().x-(float(r[0])+float(r[2]))*.5)<.000003 and absf(a.get_center().z+(float(r[1])+float(r[3]))*.5)<.000003,"original bottle centres remain inside the case")
			check(draw.material_override==null and (draw.mesh.surface_get_material(0) as StandardMaterial3D).transparency==BaseMaterial3D.TRANSPARENCY_DISABLED,"bounded coloured bottle finish uses the registered opaque milk-glass maps")
		if part.ends_with("__ribs_red") or part.ends_with("__ribs_teal"):
			ribs+=1;check(a.size.x>.067 and a.size.x<.070 and a.size.z>.067 and a.size.z<.070,"physical tactile ribs rise outside the round body while retaining its source width")
	check(bottles==6 and ribs==6 and panes==1,"actual six hollow bodies, six rib partitions and one inset pane are complete")
	var case_part:=prefix+"poison_cupboard__wood_dark"
	for z in [.66,1.04]:
		var hit:=_isolated_ray(world,model,case_part,cell.to_global(Vector3(22.78,z+.005,45.02)),cell.to_global(Vector3(22.78,z-.050,45.02)))
		check(not hit.is_empty() and absf(cell.to_local(hit.position).y-z)<.00003,"actual internal shelf has the retained bottle seat")
	for i in 6:
		var identity:=prefix+"poison"+str(i);var row: Dictionary=originals[identity];var r: Array=row.rect;var cx: float=(float(r[0])+float(r[2]))*.5;var cz: float=-(float(r[1])+float(r[3]))*.5;var z: float=row.z0
		var body:=identity+("__glass_red" if i%2==0 else "__glass_teal")
		var hit:=_isolated_ray(world,model,body,cell.to_global(Vector3(cx,z+.360,cz)),cell.to_global(Vector3(cx,z-.020,cz)))
		check(not hit.is_empty() and absf(cell.to_local(hit.position).y-(z+.012))<.00003,"isolated actual bottle mouth reaches its twelve-millimetre internal base")
		hit=_isolated_ray(world,model,identity+"__wood_dark",cell.to_global(Vector3(cx,z+.360,cz)),cell.to_global(Vector3(cx,z+.280,cz)))
		check(not hit.is_empty() and absf(cell.to_local(hit.position).y-(z+.340))<.00003,"actual separate stopper retains the original total bottle height")
	var nearest:=INF;var samples:=0
	var dispensary: Node3D=cell.get_node("DruggistDispensary")
	for draw: MeshInstance3D in dispensary.find_children("*","MeshInstance3D",true,false):
		for raw: Vector3 in draw.mesh.get_faces():
			var p: Vector3=draw.transform*raw
			if p.y<.01-.000003 or p.y>1.94+.000003:continue
			var dx:=maxf(maxf(float(rect[0])-p.x,p.x-float(rect[2])),0.)
			var dz:=maxf(maxf(-float(rect[3])-p.z,p.z+float(rect[1])),0.)
			nearest=minf(nearest,Vector2(dx,dz).length());samples+=1
	check(samples>0 and nearest>=.010-.000003,"actual adjacent bench vertex samples keep at least ten millimetres from the case envelope including its pane and hardware")

func _retail_detail_views(world: OrisonV2RuntimeRoot, fixture: Dictionary) -> void:
	var cell: Node3D=world.passage_region.cell_nodes.shop_otis_son
	var r: Array=fixture.assemblies[0].floor.rect;var observations: Array=[]
	for view: Array in [["cupboard",Vector3(22.45,.03,46.00),Vector3(22.78,1.07,45.02)],["bottle_ribs",Vector3(22.75,.03,45.75),Vector3(22.76,1.10,45.02)],["cupboard_feet",Vector3(21.80,.03,45.85),Vector3(22.78,.25,45.02)],["bench_clearance",Vector3(21.85,.03,45.90),Vector3(23.15,1.15,45.22)],["dispensary_context",Vector3(21.80,.03,46.40),Vector3(23.10,1.60,46.10)],["shop_context",Vector3(17.30,.03,45.65),Vector3(23.00,1.30,45.70)]]:
		var preferred: Vector3=view[1];var selected:=preferred;var distance:=INF
		if not _city_clear_station(world,cell.to_global(preferred)):
			for u in range(1,25):
				for v in range(1,25):
					var at:=Vector3(lerpf(r[0],r[2],u/25.),.03,-lerpf(r[1],r[3],v/25.))
					if at.distance_squared_to(preferred)<distance and _city_clear_station(world,cell.to_global(at)):
						selected=at;distance=at.distance_squared_to(preferred)
		check(_city_clear_station(world,cell.to_global(selected)),"actual floor-supported cupboard observation: "+str(view[0]))
		world.player.global_position=cell.to_global(selected);world.player.velocity=Vector3.ZERO
		world.player.face_world_point(cell.to_global(view[2]));world.player.set_lamp_enabled(true)
		if capture_enabled:
			await _settled_optics();await shot(view[0])
		observations.append({"id":view[0],"requested_feet":[preferred.x,preferred.y,preferred.z],"feet":[selected.x,selected.y,selected.z],"target":[view[2].x,view[2].y,view[2].z],"image":str(view[0])+".png"})
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("views.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","views":observations,"scope":"Standing-capsule cupboard and dispensary observations. Closed leaf and passive lock plate have no new access/poison-custody or medical owner. Operating fountain, continuous routes and independent services retain separate authority."},"\t"))
