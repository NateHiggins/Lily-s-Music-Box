extends "res://tests/orison_v2_roof_membrane_test.gd"
## Actual laundry boundaries, floor bearings, materials and paired views.
var batch_mode := false
var capture_enabled := true

func _ready() -> void:
	if not batch_mode: call_deferred("_run")

func _run() -> void:
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928,11,10,20*60);GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var world:=_world_scene().instantiate() as OrisonV2RuntimeRoot;add_child(world)
	await get_tree().physics_frame;await get_tree().physics_frame
	if world.startup_failed or world.passage_region.startup_failed:check(false,"world startup failed");world.shutdown_for_tests();world.free();get_tree().quit(1);return
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
	if passage.residency.state!="RESIDENT":check(false,"normal prefetch failed");world.shutdown_for_tests();world.free();get_tree().quit(1);return
	await get_tree().physics_frame;await get_tree().physics_frame
	await validate_in_world(world)
	world.shutdown_for_tests();world.free();await _retired_audio();get_tree().quit(0 if failures.is_empty() else 1)

func validate_in_world(world: OrisonV2RuntimeRoot) -> Dictionary:
	check(not world.startup_failed and not world.passage_region.startup_failed,"composed world fits the original shop laundry")
	var passage: OrisonV2PassageRegion=world.passage_region
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_laundry_fittings.json"))
	check(FileAccess.get_sha256("res://assets/props/laundry_fittings.glb")==fixture.asset_sha256,"installed mesh binds the native laundry export")
	var parts:=0;var triangles:=0;var removed:=0;var supports:=0
	for record: Dictionary in fixture.runtime.cells:
		var cell: Node3D=passage.cell_nodes[record.id];var model: Node3D=cell.get_node("LaundryFittings")
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
			var name:=str(draw.get_meta("laundry_part"));var expected: Dictionary=fixture.parts.filter(func(row):return row.name==name)[0]
			check(count==int(expected.triangles) and expected.cell==record.id,"each fitted partition binds exact native triangles and cell")
			_check_cap_mapping(draw.mesh,true)
			var mat:=draw.mesh.surface_get_material(0) as StandardMaterial3D
			check(mat!=null and not mat.uv1_triplanar and mat.albedo_texture!=null and mat.roughness_texture!=null and mat.normal_texture!=null,"three source shipping maps reach native metre charts")
			var source: StandardMaterial3D
			for original_draw: MeshInstance3D in originals:
				if str(original_draw.name).ends_with("_"+str(expected.key)):source=originals[original_draw].surface_get_material(0)
			# Dossier slice 75: any catalogue-bound key (linen, the aged parcel paper) is held to its library set.
			var runtime_part: Dictionary=record.parts.filter(func(row):return row.name==name)[0]
			if runtime_part.has("catalog_key"):
				var library:=MatLib.get_mat(str(runtime_part.catalog_key))
				check(library!=mat and library.uv1_triplanar and library.albedo_texture==mat.albedo_texture and library.roughness_texture==mat.roughness_texture and library.normal_texture==mat.normal_texture and mat.uv1_scale.is_equal_approx(library.uv1_scale),"new pressed cloth uses the existing locked catalogue linen without changing its shared material")
			else:
				check(source!=null and source!=mat and source.albedo_texture==mat.albedo_texture and source.roughness_texture==mat.roughness_texture and source.normal_texture==mat.normal_texture,"paper, timber and chrome retain their original shipping maps")
			var bounds: AABB=draw.transform*draw.mesh.get_aabb();check(maxf(maxf(bounds.size.x,bounds.size.y),bounds.size.z)<5.,"individual furniture partitions retain bounded culling")
			var shape: CollisionShape3D=draw.find_children("*","CollisionShape3D",true,false)[0]
			check((shape.shape as ConcavePolygonShape3D).get_faces()==draw.mesh.get_faces() and shape.global_transform.is_equal_approx(draw.global_transform),"native furniture physical triangles and poses match visible triangles")
		for contact: Dictionary in fixture.contacts:
			var at:=_v(contact.point);var direction:=_v(contact.direction);var exclude: Array[RID]=[world.player.get_rid()]
			for body: CollisionObject3D in model.find_children("*","CollisionObject3D",true,false):
				var draw:=body.get_parent() as MeshInstance3D
				if draw!=null and str(draw.get_meta("laundry_part")).begins_with(str(contact.assembly)+"__"):exclude.append(body.get_rid())
			var query:=PhysicsRayQueryParameters3D.create(cell.to_global(at+direction*.004),cell.to_global(at-direction*.004),1,exclude)
			var hit:=world.get_world_3d().direct_space_state.intersect_ray(query)
			check(not hit.is_empty() and cell.to_local(hit.position).distance_to(at)<.00003,"fitted support contact: "+str(contact.label)+" / "+str(contact.owner));supports+=1
	check(parts==fixture.parts.size() and triangles==int(fixture.triangles) and removed==fixture.original_records.size()*12 and supports==fixture.contacts.size(),"native counts bind all original boxes, fitted furniture and floor samples")
	await _ironing_receiver_views(world,fixture)
	await _laundry_views(world,fixture)
	await _shirt_detail_views(world,fixture)
	print("LAUNDRY FITTINGS: checks=",checks," parts=",parts," triangles=",triangles," removed=",removed," supports=",supports," failures=",failures.size())
	return {"checks":checks,"parts":parts,"triangles":triangles,"removed":removed,"supports":supports,"failures":failures.duplicate()}

func _ironing_receiver_views(world: OrisonV2RuntimeRoot, fixture: Dictionary) -> void:
	var fit: Dictionary=fixture.fitted_receiver_clearance
	var cell: Node3D=world.passage_region.cell_nodes.shop_model_laundry
	var model: Node3D=cell.get_node("LaundryFittings")
	var source: Dictionary=fit.source_record
	var source_floor: Dictionary=world.passage_region.source_layout.floors.filter(func(row):return str(row.id)=="F01")[0]
	var original: Dictionary=source_floor.furniture.filter(func(row):return str(row.id)==str(source.id))[0]
	var prop:=world.passage_region._actors.get_node_or_null("Arcade_"+str(source.id)) as ArcadeCabinetProp
	check(original==source,"furniture fit retains the complete original optional cabinet record")
	if world.passage_region.cabinets_enabled:
		check(prop!=null,"explicitly restored cabinet has its original actor")
		if prop==null:return
		check(prop.variant==int(source.variant) and prop.position.is_equal_approx(GameBoot.b2g([source.at[0],source.at[1],float(source_floor.z)+float(source.get("z0",0.))]))
			and is_equal_approx(prop.rotation.y,deg_to_rad(float(source.yaw))+PI),"ironing fit preserves cabinet variant, pose and programme owner")
	else:
		check(prop==null,"temporarily removed cabinet has no play actor")
	var hull:=cell.get_node_or_null(str(fit.hull_name)) as StaticBody3D
	check(hull!=null,"exact original receiving hull remains in its source cell")
	if hull==null:return
	var shape:=hull.get_child(0) as CollisionShape3D
	var faces: PackedVector3Array=(shape.shape as ConcavePolygonShape3D).get_faces()
	check(faces.size()==36 and shape.disabled and hull.collision_layer==0 and hull.collision_mask==0,"complete original twelve-triangle receiving hull stays intact after exact native chassis retirement")
	if world.passage_region.cabinets_enabled:
		check(cell.has_node("LaundryReceiving") and cell.get_node("LaundryReceiving").get_meta("original_hull")==hull,"native receiving physical stock owns the retired source hull")
	else:
		check(not cell.has_node("LaundryReceiving"),"removed laundry cabinet has no native replacement")
	var low:=Vector3(INF,INF,INF);var high:=Vector3(-INF,-INF,-INF)
	for vertex in faces:
		var point:=cell.to_local(shape.to_global(vertex));low=low.min(point);high=high.max(point)
	var a:=GameBoot.b2g(fit.hull_low_b);var b:=GameBoot.b2g(fit.hull_high_b)
	check(low.distance_to(a.min(b))<.00003 and high.distance_to(a.max(b))<.00003,"actual retained receiving hull binds immutable assembler bounds")
	var measured: Array=[]
	for spec: Dictionary in [{"id":"storm_shop_model_laundry_iron_table","limit":fit.table_right_x},{"id":"storm_shop_model_laundry_iron_pad","limit":fit.pad_right_x}]:
		var right: float=-INF;var left: float=INF;var found:=0
		for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
			if not str(draw.get_meta("laundry_part","")).begins_with(str(spec.id)+"__"):continue
			found+=1
			for surface in draw.mesh.get_surface_count():
				var vertices: PackedVector3Array=draw.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
				for vertex in vertices:
					var x: float=cell.to_local(draw.to_global(vertex)).x;right=maxf(right,x);left=minf(left,x)
		check(found==1 and absf(right-float(spec.limit))<.00003 and low.x-right>=float(fit.clearance_m)-.00003,
			"actual fitted furniture clears the complete retained receiver hull: "+str(spec.id))
		if str(spec.id).ends_with("_table"):
			check(absf(right-left-float(fit.fitted_table_length_m))<.00003 and float(fit.fitted_table_length_m)<float(fit.source_table_length_m),"supported ironing table shortens only its obstructing end")
		measured.append({"assembly":spec.id,"right_x":right,"hull_left_x":low.x,"gap_m":low.x-right})
	check(absf(float(fit.pad_right_x)-float(fit.table_right_x)-float(fit.pad_overhang_m))<.000001,"padded top retains its original overhang beyond the timber support")
	for spec: Dictionary in [{"id":"laundry_receiver_front","feet":[7.6,.03,42.8],"target":[7.6,1.29,43.87]},
		{"id":"laundry_receiver_table_supports","feet":[6.75,.03,42.9],"target":[6.85,.50,44.12]}]:
		var feet:=cell.to_global(_v(spec.feet))
		check(_clear_laundry_station(world,feet),"standing capsule has a clear ironing/receiver observation: "+str(spec.id))
		world.player.global_position=feet;world.player.velocity=Vector3.ZERO
		world.player.face_world_point(cell.to_global(_v(spec.target)));world.player.set_lamp_enabled(true)
		if capture_enabled:await _settled_optics();await shot(str(spec.id))
	var directory:=OS.get_environment("SHOT_DIR")
	FileAccess.open(directory.path_join("receiving_clearance.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","measured":measured,"original_hull_triangles":12,"scope":"Actual imported table and pad are separated from the intact original receiver envelope, whose exact hull stays disabled under the current cabinet policy. Standing floor/capsule observations do not establish continuous shop entry, cabinet operation, services or human acceptance."},"\t"))

func _laundry_views(world: OrisonV2RuntimeRoot, fixture: Dictionary) -> void:
	var observations: Array=[]
	for record: Dictionary in fixture.runtime.cells:
		var cell: Node3D=world.passage_region.cell_nodes[record.id];var model: Node3D=cell.get_node("LaundryFittings")
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
	if not capture_enabled:return
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

func _shirt_detail_views(world: OrisonV2RuntimeRoot, fixture: Dictionary) -> void:
	var shirts: Array=fixture.original_records.filter(func(row):return str(row.id).contains("_shirt"))
	var cell: Node3D=world.passage_region.cell_nodes["shop_model_laundry"];var model: Node3D=cell.get_node("LaundryFittings")
	for index: int in [0,shirts.size()-1]:
		var row: Dictionary=shirts[index];var r: Array=row.rect
		var center:=GameBoot.b2g([(r[0]+r[2])*.5,(r[1]+r[3])*.5,float(row.z0)+float(row.h)*.5])
		var feet:=Vector3.ZERO;var clear:=false
		for dx: float in [.75,-.75,1.05,-1.05]:
			for dz: float in [0.,.3,-.3,.6,-.6]:
				if clear:continue
				var candidate:=Vector3(center.x+dx,.035,center.z+dz)
				if not _clear_laundry_station(world,cell.to_global(candidate)):continue
				var sight:=PhysicsRayQueryParameters3D.create(cell.to_global(candidate+Vector3.UP*1.41),cell.to_global(center),1,[world.player.get_rid()])
				var hit:=world.get_world_3d().direct_space_state.intersect_ray(sight)
				if hit.is_empty():continue
				var draw: MeshInstance3D=hit.collider.get_parent() as MeshInstance3D
				if draw==null or not str(draw.get_meta("laundry_part","")).begins_with(str(row.id)+"__"):continue
				feet=candidate;clear=true
		check(clear,"normal player capsule has a clear shirt-detail station")
		if not clear:continue
		world.player.global_position=cell.to_global(feet);world.player.face_world_point(cell.to_global(center));world.player.set_lamp_enabled(true)
		await _paired_laundry_view(model,str(row.id)+"_detail")
