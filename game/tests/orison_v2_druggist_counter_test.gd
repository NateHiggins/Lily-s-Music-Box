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
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_druggist_counter.json"))
	var installed: bool=passage.cell_nodes.has("shop_otis_son") and passage.cell_nodes.shop_otis_son.has_node("DruggistCounter")
	check(installed,"actual retained druggist cell and drawer fitting exist before their contracts")
	if not installed:world.shutdown_for_tests();world.free();get_tree().quit(1);return
	check(FileAccess.get_sha256("res://assets/props/druggist_counter.glb")==fixture.asset_sha256,"installed mesh binds the native counter/ledger export")
	var parts:=0;var triangles:=0;var removed:=0;var supports:=0
	for record: Dictionary in fixture.runtime.cells:
		var cell: Node3D=passage.cell_nodes[record.id];var model: Node3D=cell.get_node("DruggistCounter")
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
			var name:=str(draw.get_meta("druggist_counter_part"));var expected: Dictionary=fixture.parts.filter(func(row):return row.name==name)[0]
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
				if draw!=null and str(draw.get_meta("druggist_counter_part")).begins_with(str(contact.assembly)+"__"):exclude.append(body.get_rid())
			var query:=PhysicsRayQueryParameters3D.create(cell.to_global(at+direction*.004),cell.to_global(at-direction*.004),1,exclude)
			var hit:=world.get_world_3d().direct_space_state.intersect_ray(query)
			check(not hit.is_empty() and cell.to_local(hit.position).distance_to(at)<.00003,"fitted support contact: "+str(contact.label)+" / "+str(contact.owner));supports+=1
	check(parts==fixture.parts.size() and triangles==int(fixture.triangles) and removed==fixture.original_records.size()*12 and supports==fixture.contacts.size(),"native counts bind all original boxes, fitted furniture and floor samples")
	_check_counter_details(world,fixture)
	await _retail_detail_views(world,fixture)
	var directory:=OS.get_environment("SHOT_DIR")
	FileAccess.open(directory.path_join("fittings.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","checks":checks,"parts":parts,"triangles":triangles,"removed":removed,"supports":supports,"failures":failures},"\t"))
	print("DRUGGIST COUNTER: checks=",checks," parts=",parts," triangles=",triangles," removed=",removed," supports=",supports," failures=",failures.size())
	world.shutdown_for_tests();world.free();await _retired_audio();get_tree().quit(0 if failures.is_empty() else 1)

func _isolated_ray(world: OrisonV2RuntimeRoot, model: Node3D, part: String, start: Vector3, finish: Vector3) -> Dictionary:
	var targets:=model.find_children("*","MeshInstance3D",true,false).filter(func(draw):return str(draw.get_meta("druggist_counter_part",""))==part)
	check(targets.size()==1,"actual installed cavity partition: "+part)
	if targets.size()!=1:return {}
	var target: CollisionObject3D=targets[0].find_children("*","CollisionShape3D",true,false)[0].get_parent()
	var exclude: Array[RID]=[]
	for body: CollisionObject3D in world.find_children("*","CollisionObject3D",true,false):
		if body!=target:exclude.append(body.get_rid())
	return world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(start,finish,1,exclude))

func _check_counter_details(world: OrisonV2RuntimeRoot, fixture: Dictionary) -> void:
	var cell: Node3D=world.passage_region.cell_nodes.shop_otis_son;var model: Node3D=cell.get_node("DruggistCounter")
	var prefix:="storm_shop_otis___son_"
	check(fixture.original_records.size()==2 and fixture.assemblies.size()==2 and fixture.closed_stocks.size()==21,"two original source-owned countertop objects have real closed stocks")
	var old: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_druggist_drawers.json"))
	var counter: Dictionary=old.original_records.filter(func(row):return str(row.id)==prefix+"counter")[0]
	var top: Dictionary=old.original_records.filter(func(row):return str(row.id)==prefix+"counter_top")[0]
	var front:=float(counter.rect[1])+.450;var seat:=float(top.z0)+float(top.h);var tr: Array=top.rect
	var bank: Node3D=cell.get_node("DruggistDrawers");var cabinet_front: float=INF;var upper_vertices:=0
	for draw: MeshInstance3D in bank.find_children("*","MeshInstance3D",true,false):
		for vertex: Vector3 in draw.mesh.get_faces():
			var p: Vector3=draw.transform*vertex
			if p.y>seat+.0001:cabinet_front=minf(cabinet_front,p.z);upper_vertices+=1
	check(upper_vertices>0 and cabinet_front>=-front-.039-.000003,"actual upper cabinet faces and pulls respect their declared forward envelope")
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		var a: AABB=draw.transform*draw.mesh.get_aabb();var end:=a.end
		check(a.position.x>=float(tr[0])-.000003 and end.x<=float(tr[2])+.000003 and a.position.z>=-float(tr[3])-.000003 and end.z<=cabinet_front-.018+.000003 and a.position.y>=seat-.000003,"actual object stays on the original serving top with at least 18mm upper-cabinet clearance")
	var phone: Dictionary=fixture.original_records.filter(func(row):return str(row.id)==prefix+"telephone")[0]
	var cx: float=(float(phone.rect[0])+float(phone.rect[2]))*.5;var cy:=front+.18;var rear:=cy-.060
	# Small fan/boolean faces need a long isolated segment. Short segments can
	# fall below Geometry3D/physics intersection epsilon despite valid faces.
	var hit:=_isolated_ray(world,model,prefix+"telephone__bakelite_black",cell.to_global(Vector3(cx,1.445,-(rear+.070))),cell.to_global(Vector3(cx,1.445,-(rear-3.))))
	print("COUNTER TRANSMITTER HIT: ",cell.to_local(hit.position) if not hit.is_empty() else "empty"," normal=",hit.get("normal"))
	check(not hit.is_empty() and absf(cell.to_local(hit.position).z+rear+.017)<.00003 and hit.normal.dot(-cell.global_basis.z)>.99,"actual transmitter mouth reaches its recessed inner back rather than a solid front plug")
	hit=_isolated_ray(world,model,prefix+"telephone__bakelite_black",cell.to_global(Vector3(cx-.060,1.25,-rear)),cell.to_global(Vector3(cx-.060,4.,-rear)))
	print("COUNTER RECEIVER HIT: ",cell.to_local(hit.position) if not hit.is_empty() else "empty"," normal=",hit.get("normal"))
	check(not hit.is_empty() and absf(cell.to_local(hit.position).y-1.329)<.00003 and hit.normal.dot(-cell.global_basis.y)>.99,"actual hanging receiver has an open lower mouth and recessed internal cap")
	for k in range(10):
		var angle: float=(k+.25)*TAU/10.;var at:=Vector3(cx+.046*cos(angle),seat+.0495,-(cy+.040+.046*sin(angle)))
		hit=_isolated_ray(world,model,prefix+"telephone__brass_dull",cell.to_global(at+Vector3(0,.30,0)),cell.to_global(at-Vector3(0,3.,0)))
		check(hit.is_empty(),"actual rotary finger bore clears the ring and stem collar: "+str(k))
	for k in range(4):
		var angle: float=(k+.75)*TAU/10.;var at:=Vector3(cx+.046*cos(angle),seat+.0495,-(cy+.040+.046*sin(angle)))
		hit=_isolated_ray(world,model,prefix+"telephone__brass_dull",cell.to_global(at+Vector3(0,.30,0)),cell.to_global(at-Vector3(0,3.,0)))
		print("COUNTER BRIDGE HIT: ",k," at=",cell.to_local(hit.position) if not hit.is_empty() else "empty")
		check(not hit.is_empty() and absf(cell.to_local(hit.position).y-seat-.053)<.00003,"actual rotary ring bridges remain solid between bores")

func _retail_detail_views(world: OrisonV2RuntimeRoot, fixture: Dictionary) -> void:
	var cell: Node3D=world.passage_region.cell_nodes.shop_otis_son
	var r: Array=fixture.assemblies[0].floor.rect;var observations: Array=[]
	for view: Array in [["telephone",Vector3(19.08,.03,47.05),Vector3(19.08,1.36,47.92)],["rotary_dial",Vector3(18.72,.03,47.05),Vector3(19.08,1.16,47.88)],["ledger",Vector3(19.78,.03,47.05),Vector3(19.78,1.14,47.93)],["counter_context",Vector3(21.8,.03,47.0),Vector3(19.55,1.36,48.0)],["shop_context",Vector3(17.30,.03,45.65),Vector3(20.4,1.56,48.1)]]:
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
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("views.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","views":observations,"scope":"Standing-capsule passive telephone/ledger observations. Medicine/poison custody, stock state, operating dispensing/fountain, continuous routes and independent services retain separate authority."},"\t"))
