extends "res://tests/orison_v2_roof_membrane_test.gd"
## Actual laundry boundaries, floor bearings, materials and paired views.
func _run() -> void:
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928,11,10,20*60);GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var world:=_world_scene().instantiate() as OrisonV2RuntimeRoot;add_child(world)
	await get_tree().physics_frame;await get_tree().physics_frame
	check(not world.startup_failed and not world.passage_region.startup_failed,"composed world fits the original shop laundry")
	if world.startup_failed or world.passage_region.startup_failed:world.shutdown_for_tests();world.free();get_tree().quit(1);return
	world.player.set_physics_process(false);world.service_set_carrier.set_capture_hidden(true)
	for layer: CanvasLayer in world.find_children("*","CanvasLayer",true,false):layer.hide()
	var passage: OrisonV2PassageRegion=world.passage_region
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_laundry_apparatus.json"))
	check(FileAccess.get_sha256("res://assets/props/laundry_apparatus.glb")==fixture.asset_sha256,"installed mesh binds the native laundry export")
	var parts:=0;var triangles:=0;var removed:=0;var supports:=0
	for record: Dictionary in fixture.runtime.cells:
		var cell: Node3D=passage.cell_nodes[record.id];var model: Node3D=cell.get_node("LaundryApparatus")
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
			var name:=str(draw.get_meta("laundry_apparatus_part"));var expected: Dictionary=fixture.parts.filter(func(row):return row.name==name)[0]
			check(count==int(expected.triangles) and expected.cell==record.id,"each fitted partition binds exact native triangles and cell")
			_check_cap_mapping(draw.mesh,true)
			var mat:=draw.mesh.surface_get_material(0) as StandardMaterial3D
			check(mat!=null and not mat.uv1_triplanar and mat.albedo_texture!=null and mat.roughness_texture!=null and mat.normal_texture!=null,"three source shipping maps reach native metre charts")
			var source: StandardMaterial3D
			for original_draw: MeshInstance3D in originals:
				if str(original_draw.name).trim_suffix("-col").ends_with("_"+str(expected.key)):source=originals[original_draw].surface_get_material(0)
			if expected.key in ["linen","cast_iron"]:
				var library:=MatLib.get_mat("linen" if expected.key=="linen" else "iron_blackened")
				check(library!=mat and library.uv1_triplanar and library.albedo_texture==mat.albedo_texture and library.roughness_texture==mat.roughness_texture and library.normal_texture==mat.normal_texture and mat.uv1_scale.is_equal_approx(library.uv1_scale),"new rope and bare iron use their registered catalogue finish without changing shared materials")
				check(mat.metallic==library.metallic and mat.roughness==library.roughness and mat.normal_scale==library.normal_scale,"catalogued finish retains its metallic, roughness and normal strength")
			else:
				check(source!=null and source!=mat and source.albedo_texture==mat.albedo_texture and source.roughness_texture==mat.roughness_texture and source.normal_texture==mat.normal_texture,"zinc, timber, rubber and metal retain their original shipping maps")
				check(source!=null and source.metallic==mat.metallic and source.roughness==mat.roughness and source.normal_scale==mat.normal_scale,"source finish retains its metallic, roughness and normal strength")
			var bounds: AABB=draw.transform*draw.mesh.get_aabb();check(maxf(maxf(bounds.size.x,bounds.size.y),bounds.size.z)<5.,"individual furniture partitions retain bounded culling")
			var shape: CollisionShape3D=draw.find_children("*","CollisionShape3D",true,false)[0]
			check((shape.shape as ConcavePolygonShape3D).get_faces()==draw.mesh.get_faces() and shape.global_transform.is_equal_approx(draw.global_transform),"native furniture physical triangles and poses match visible triangles")
		for contact: Dictionary in fixture.contacts:
			var at:=_v(contact.point);var direction:=_v(contact.direction);var exclude: Array[RID]=[world.player.get_rid()]
			for body: CollisionObject3D in model.find_children("*","CollisionObject3D",true,false):
				var draw:=body.get_parent() as MeshInstance3D
				if draw!=null and str(draw.get_meta("laundry_apparatus_part")).begins_with(str(contact.assembly)+"__"):exclude.append(body.get_rid())
			var query:=PhysicsRayQueryParameters3D.create(cell.to_global(at+direction*.004),cell.to_global(at-direction*.004),1,exclude)
			var hit:=world.get_world_3d().direct_space_state.intersect_ray(query)
			check(not hit.is_empty() and cell.to_local(hit.position).distance_to(at)<.00003,"fitted support contact: "+str(contact.label)+" / "+str(contact.owner));supports+=1
	check(parts==fixture.parts.size() and triangles==int(fixture.triangles) and removed==fixture.original_records.size()*12 and supports==fixture.contacts.size(),"native counts bind all original boxes, fitted furniture and floor samples")
	_check_open_basins(world,fixture)
	await _laundry_views(world,fixture)
	await _apparatus_detail_views(world,fixture)
	print("LAUNDRY APPARATUS: checks=",checks," parts=",parts," triangles=",triangles," removed=",removed," supports=",supports," failures=",failures.size())
	world.shutdown_for_tests();world.free();await _retired_audio();get_tree().quit(0 if failures.is_empty() else 1)

func _laundry_views(world: OrisonV2RuntimeRoot, fixture: Dictionary) -> void:
	var observations: Array=[]
	for record: Dictionary in fixture.runtime.cells:
		var cell: Node3D=world.passage_region.cell_nodes[record.id];var model: Node3D=cell.get_node("LaundryApparatus")
		var floor: Dictionary=world.passage_region.source_layout.floors.filter(func(row):return row.id=="F01")[0]
		var markers: Array=[]
		for source: Dictionary in floor.markers:
			if str(source.id).begins_with("SITE_SHOP_IN") and str(source.id).ends_with(str(record.id).trim_prefix("shop_").to_upper().replace("OTIS_SON","OTIS___SON")):markers.append(source)
		for source: Dictionary in markers:
			var target:=GameBoot.b2g(source.pos);target.y=.5
			var center:=Vector3.ZERO
			for item: Dictionary in fixture.assemblies:
				if item.cell!=record.id:continue
				var body: Dictionary=fixture.original_records.filter(func(row):return row.id==item.id)[0];center+=GameBoot.b2g([(body.rect[0]+body.rect[2])*.5,(body.rect[1]+body.rect[3])*.5,float(body.z0)+float(body.h)*.5])
			var total: int=fixture.assemblies.filter(func(row):return row.cell==record.id).size();center/=total
			var feet:=target;feet.y=.03
			world.player.global_position=cell.to_global(feet);world.player.face_world_point(cell.to_global(center));world.player.set_lamp_enabled(true)
			await _paired_laundry_view(model,str(source.id))
		var floors: Dictionary={}
		for item: Dictionary in fixture.assemblies:
			if item.cell==record.id:floors[str(item.floor.id)]=item.floor
		for identity: String in floors:
			var source: Dictionary=floors[identity];var r: Array=source.rect
			var height:=float(source.z0)+float(source.h);var center:=Vector3.ZERO;var count:=0
			for item: Dictionary in fixture.assemblies:
				if item.cell!=record.id or item.floor.id!=identity:continue
				var body: Dictionary=fixture.original_records.filter(func(row):return row.id==item.id)[0]
				center+=GameBoot.b2g([(body.rect[0]+body.rect[2])*.5,(body.rect[1]+body.rect[3])*.5,height+1.35]);count+=1
			center/=count
			var candidates: Array[Vector3]=[]
			for u in [.12,.3,.5,.7,.88]:
				for v in [.12,.3,.5,.7,.88]:
					var at:=GameBoot.b2g([lerpf(r[0],r[2],u),lerpf(r[1],r[3],v),height+.025])
					if _clear_laundry_station(world,cell.to_global(at)):candidates.append(at)
			check(candidates.size()>=2,"fitted furniture has clear floor-owned inspection stations: "+identity)
			if candidates.size()<2:continue
			var first: Vector3=candidates[0];var farthest:=first
			for at: Vector3 in candidates:
				if at.distance_squared_to(first)>farthest.distance_squared_to(first):farthest=at
			var index:=0
			for at: Vector3 in [first,farthest]:
				world.player.global_position=cell.to_global(at);world.player.face_world_point(cell.to_global(center));world.player.set_lamp_enabled(true)
				await _paired_laundry_view(model,identity+"_"+str(index));observations.append({"floor_owner":identity,"feet":str(at),"target":str(center)});index+=1
	var directory:=OS.get_environment("SHOT_DIR")
	if not directory.is_empty():
		var file:=FileAccess.open(directory.path_join("laundry-inspection.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify({"evidence_class":"INERT","stations":observations,"checks":checks,"failures":failures},"\t")+"\n");file.close()

func _paired_laundry_view(model: Node3D, identity: String) -> void:
	await _settled_optics();await shot(identity+"_fitted")
	var originals: Dictionary=model.get_meta("original_meshes");var fitted: Dictionary={}
	model.hide()
	for draw: MeshInstance3D in originals:fitted[draw]=draw.mesh;draw.mesh=originals[draw];draw.show()
	await _settled_optics();await shot(identity+"_original")
	for draw: MeshInstance3D in fitted:draw.mesh=fitted[draw];draw.visible=draw.mesh.get_surface_count()>0
	model.show()

func _clear_laundry_station(world: OrisonV2RuntimeRoot, at: Vector3) -> bool:
	var shape:=CapsuleShape3D.new();shape.radius=PlayerController.BODY_RADIUS;shape.height=PlayerController.STANDING_HEIGHT
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=shape;query.collision_mask=1
	query.transform=Transform3D(Basis.IDENTITY,at+Vector3.UP*PlayerController.STANDING_HEIGHT*.5);query.exclude=[world.player.get_rid()]
	return world.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

func _check_open_basins(world: OrisonV2RuntimeRoot, fixture: Dictionary) -> void:
	var cell: Node3D=world.passage_region.cell_nodes["shop_model_laundry"]
	for assembly: Dictionary in fixture.assemblies:
		if assembly.kind!="tub":continue
		var source: Dictionary=fixture.original_records.filter(func(row):return row.id==assembly.id)[0]
		var r: Array=source.rect;var center:=GameBoot.b2g([(r[0]+r[2])*.5,(r[1]+r[3])*.5,1.])
		# Sample inside faces. A ray on the cap's triangulation junction can
		# miss in Jolt despite the closed native and identical physical mesh.
		for offset: Vector3 in [Vector3(.03,0,.04),Vector3(-.06,0,.03)]:
			var interior_ray:=PhysicsRayQueryParameters3D.create(cell.to_global(center+offset),cell.to_global(center+offset-Vector3.UP*.8),1,[world.player.get_rid()])
			var bottom:=world.get_world_3d().direct_space_state.intersect_ray(interior_ray)
			check(not bottom.is_empty() and absf(cell.to_local(bottom.position).y-.373)<.00003 and str(bottom.collider.get_parent().get_meta("laundry_apparatus_part","")).begins_with(str(assembly.id)+"__zinc_liner"),"open basin interior sample hits its physical inner bottom")
		var at:=GameBoot.b2g([(r[0]+r[2])*.5,(r[1]+r[3])*.5,.65])
		var ray:=PhysicsRayQueryParameters3D.create(cell.to_global(at),cell.to_global(at+Vector3.RIGHT*.5),1,[world.player.get_rid()]);var hit:=world.get_world_3d().direct_space_state.intersect_ray(ray)
		check(not hit.is_empty() and absf(cell.to_local(hit.position).y-.65)<.00003 and cell.to_local(hit.position).x>at.x+.24 and cell.to_local(hit.position).x<at.x+.34,"hollow basin retains its sloping physical inner wall")

func _apparatus_detail_views(world: OrisonV2RuntimeRoot, fixture: Dictionary) -> void:
	var cell: Node3D=world.passage_region.cell_nodes["shop_model_laundry"];var model: Node3D=cell.get_node("LaundryApparatus")
	for assembly: Dictionary in fixture.assemblies:
		if assembly.kind=="iron":continue
		var row: Dictionary=fixture.original_records.filter(func(source):return source.id==assembly.id)[0];var r: Array=row.rect
		var heights: Dictionary={"tub":.65,"mangle":1.04,"heater":.72,"airer":2.60}
		var center:=GameBoot.b2g([(r[0]+r[2])*.5,(r[1]+r[3])*.5,float(heights[assembly.kind])])
		var feet:=Vector3.ZERO;var clear:=false
		for distance: float in [1.,1.4,1.8,2.2,2.6]:
			for angle: int in range(0,360,15):
				if clear:continue
				var radians:=deg_to_rad(float(angle));var candidate:=Vector3(center.x+cos(radians)*distance,.035,center.z+sin(radians)*distance)
				var floor_rect: Array=assembly.floor.rect
				if candidate.x<floor_rect[0]+PlayerController.BODY_RADIUS or candidate.x>floor_rect[2]-PlayerController.BODY_RADIUS or candidate.z< -floor_rect[3]+PlayerController.BODY_RADIUS or candidate.z> -floor_rect[1]-PlayerController.BODY_RADIUS:continue
				if not _clear_laundry_station(world,cell.to_global(candidate)):continue
				var sight:=PhysicsRayQueryParameters3D.create(cell.to_global(candidate+Vector3.UP*1.41),cell.to_global(center),1,[world.player.get_rid()])
				var hit:=world.get_world_3d().direct_space_state.intersect_ray(sight)
				if hit.is_empty():continue
				var draw: MeshInstance3D=hit.collider.get_parent() as MeshInstance3D
				if draw==null or not str(draw.get_meta("laundry_apparatus_part","")).begins_with(str(assembly.id)+"__"):continue
				feet=candidate;clear=true
		check(clear,"standing player has a clear sightline to the fitted "+str(assembly.kind))
		if not clear:continue
		world.player.global_position=cell.to_global(feet);world.player.face_world_point(cell.to_global(center));world.player.set_lamp_enabled(true)
		await _paired_laundry_view(model,str(assembly.id)+"_detail")
