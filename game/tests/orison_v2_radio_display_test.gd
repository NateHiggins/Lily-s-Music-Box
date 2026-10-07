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
	check(not world.startup_failed and not world.passage_region.startup_failed,"source-owned counter and passive horn/cone display fits Radio Service")
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
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_radio_display.json"))
	var installed: bool=passage.cell_nodes.has("shop_radio_service") and passage.cell_nodes.shop_radio_service.has_node("RadioDisplay")
	check(installed,"actual retained radio cell and native fittings exist before their contracts")
	if not installed:return {"checks":checks,"failures":failures.duplicate()}
	check(FileAccess.get_sha256("res://assets/props/radio_display.glb")==fixture.asset_sha256,"installed mesh binds the native counter and passive display export")
	var parts:=0;var triangles:=0;var removed:=0;var supports:=0
	for record: Dictionary in fixture.runtime.cells:
		var cell: Node3D=passage.cell_nodes[record.id];var model: Node3D=cell.get_node("RadioDisplay")
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
			var name:=str(draw.get_meta("radio_display_part"));var expected: Dictionary=fixture.parts.filter(func(row):return row.name==name)[0]
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
				if draw!=null and str(draw.get_meta("radio_display_part")).begins_with(str(contact.assembly)+"__"):exclude.append(body.get_rid())
			var query:=PhysicsRayQueryParameters3D.create(cell.to_global(at+direction*.004),cell.to_global(at-direction*.004),1,exclude)
			var hit:=world.get_world_3d().direct_space_state.intersect_ray(query)
			check(not hit.is_empty() and cell.to_local(hit.position).distance_to(at)<.00003,"fitted support contact: "+str(contact.label)+" / "+str(contact.owner));supports+=1
	check(parts==fixture.parts.size() and triangles==int(fixture.triangles) and removed==fixture.original_records.size()*12 and supports==fixture.contacts.size(),"native counts bind all original boxes, counter/display assembly and actual floor samples")
	_check_display_details(world,fixture)
	await _retail_detail_views(world,fixture)
	var directory:=OS.get_environment("SHOT_DIR")
	FileAccess.open(directory.path_join("fittings.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","checks":checks,"parts":parts,"triangles":triangles,"removed":removed,"supports":supports,"failures":failures},"\t"))
	print("RADIO DISPLAY: checks=",checks," parts=",parts," triangles=",triangles," removed=",removed," supports=",supports," failures=",failures.size())
	return {"checks":checks,"parts":parts,"triangles":triangles,"removed":removed,"supports":supports,"failures":failures.duplicate()}

func _isolated_ray(world: OrisonV2RuntimeRoot, model: Node3D, part: String, start: Vector3, finish: Vector3) -> Dictionary:
	var targets:=model.find_children("*","MeshInstance3D",true,false).filter(func(draw):return str(draw.get_meta("radio_display_part",""))==part)
	check(targets.size()==1,"actual installed fitting partition: "+part)
	if targets.size()!=1:return {}
	var target: CollisionObject3D=targets[0].find_children("*","CollisionShape3D",true,false)[0].get_parent()
	var exclude: Array[RID]=[]
	for body: CollisionObject3D in world.find_children("*","CollisionObject3D",true,false):
		if body!=target:exclude.append(body.get_rid())
	return world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(start,finish,1,exclude))

func _check_display_details(world: OrisonV2RuntimeRoot, fixture: Dictionary) -> void:
	var cell: Node3D=world.passage_region.cell_nodes.shop_radio_service;var model: Node3D=cell.get_node("RadioDisplay")
	var identity: String="storm_shop_radio_service_counter"
	check(fixture.original_records.size()==6 and fixture.assemblies.size()==3 and fixture.closed_stocks.size()==29,"six immutable records become a counter and two independently supported window speakers")
	check(model.find_children("*","Light3D",true,false).is_empty(),"passive display adds no signal or illumination")
	var original: Dictionary={}
	for row: Dictionary in fixture.original_records:original[str(row.id)]=row
	var top_row: Dictionary=original.storm_shop_radio_service_counter_top;var q: Array=top_row.rect
	var worktop: float=float(top_row.z0)+float(top_row.h)
	var rear_owner: Dictionary=fixture.fitted_datums.rear_wainscot
	var rear: float=maxf(float(q[1]),float(rear_owner.rect[3])+.002)
	var window: Dictionary=fixture.fitted_datums.window_plinth;var w: Array=window.rect;var seat: float=float(window.z0)+float(window.h)
	var front: float=float(w[0])+.06;var horn_y: float=float(w[1])+.25;var cone_y: float=float(w[3])-.31
	var horn_row: Dictionary=original.storm_shop_radio_service_horn_mouth;var cone_row: Dictionary=original.storm_shop_radio_service_cone_speaker
	var horn_height: float=float(horn_row.z0)+float(horn_row.h)-.24;var cone_height: float=float(cone_row.z0)+float(cone_row.h)-.29
	check(absf(float(fixture.fitted_datums.countertop_rear_y)-rear)<1e-12 and absf(float(fixture.fitted_datums.countertop_top)-worktop)<1e-12,"counter fit derives from immutable countertop and retained wainscot")
	check(absf(rear-float(q[1])-.032)<1e-12 and absf(rear-float(rear_owner.rect[3])-.002)<1e-12,"declared 32mm rear trim retains 2mm wainscot clearance")
	check(_v(fixture.fitted_datums.horn_centre).distance_to(Vector3(front,horn_y,horn_height))<.00003 and _v(fixture.fitted_datums.cone_centre).distance_to(Vector3(front,cone_y,cone_height))<.00003,"speaker fits derive from actual window plinth and original source maxima")
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		var mat:=draw.mesh.surface_get_material(0) as StandardMaterial3D
		check(draw.transform.basis.is_equal_approx(Basis.IDENTITY) and draw.material_override==null and mat!=null and not mat.emission_enabled,"native counter/window partitions retain unit-scale passive finish")
	for contact: Dictionary in fixture.contacts:
		var point:=_v(contact.point);var key: String="wood_dark" if str(contact.assembly)==identity else "cast_iron"
		var underside:=_isolated_ray(world,model,str(contact.assembly)+"__"+key,cell.to_global(point-Vector3(0,.02,0)),cell.to_global(point+Vector3(0,.02,0)))
		check(not underside.is_empty() and cell.to_local(underside.position).distance_to(point)<.00003,"native underside seats on actual retained floor/window plinth: "+str(contact.label))
	var top_draw: MeshInstance3D=model.find_children("*","MeshInstance3D",true,false).filter(func(draw):return str(draw.get_meta("radio_display_part",""))==identity+"__countertop")[0]
	var bounds: AABB=top_draw.transform*top_draw.mesh.get_aabb()
	check(absf(bounds.end.y-worktop)<.00003 and absf(bounds.end.z+rear)<.00003 and absf(bounds.position.z+float(q[3]))<.00003,"actual imported counter preserves height/front and fitted rear clearance")
	var book: Dictionary=original.storm_shop_radio_service_ledger;var book_x: float=(float(book.rect[0])+float(book.rect[2]))*.5
	var at:=Vector3(book_x,worktop,-float(q[3])+.19)
	var lower:=_isolated_ray(world,model,identity+"__wood_dark",cell.to_global(at-Vector3(0,.02,0)),cell.to_global(at+Vector3(0,.02,0)))
	var upper:=_isolated_ray(world,model,identity+"__countertop",cell.to_global(at+Vector3(0,.02,0)),cell.to_global(at-Vector3(0,.02,0)))
	check(not lower.is_empty() and not upper.is_empty() and cell.to_local(lower.position).distance_to(at)<.00003 and cell.to_local(upper.position).distance_to(at)<.00003,"actual ledger pad bears directly on imported worktop")
	var book_top:=_isolated_ray(world,model,identity+"__paper",cell.to_global(Vector3(book_x,2.,at.z)),cell.to_global(Vector3(book_x,1.,at.z)))
	check(not book_top.is_empty() and absf(cell.to_local(book_top.position).y-(float(book.z0)+float(book.h)))<.00003,"seated ledger retains original 1.18m maximum")
	var horn_key: String=str(horn_row.id)+"__brass_dull";var cone_key: String=str(cone_row.id)
	var horn_axis:=_isolated_ray(world,model,horn_key,cell.to_global(Vector3(front-.15,horn_height,-horn_y)),cell.to_global(Vector3(front+.08,horn_height,-horn_y)))
	check(horn_axis.is_empty(),"actual finite window horn retains an open front mouth")
	var horn_shell:=_isolated_ray(world,model,horn_key,cell.to_global(Vector3(front-.15,horn_height,-horn_y+.18)),cell.to_global(Vector3(front+.27,horn_height,-horn_y+.18)))
	check(not horn_shell.is_empty(),"actual window horn has finite physical shell around its opening")
	var crown:=_isolated_ray(world,model,horn_key,cell.to_global(Vector3(front+.004,2.,-horn_y)),cell.to_global(Vector3(front+.004,.44,-horn_y)))
	check(not crown.is_empty() and absf(cell.to_local(crown.position).y-(float(horn_row.z0)+float(horn_row.h)))<.00003,"window horn lip preserves its original 0.96m maximum")
	var cone_shell:=_isolated_ray(world,model,cone_key+"__fabric_warm",cell.to_global(Vector3(front-.15,cone_height,-cone_y+.15)),cell.to_global(Vector3(front+.20,cone_height,-cone_y+.15)))
	check(not cone_shell.is_empty(),"actual window cone has finite passive textile stock")
	var cone_axis:=_isolated_ray(world,model,cone_key+"__fabric_warm",cell.to_global(Vector3(front-.15,cone_height,-cone_y)),cell.to_global(Vector3(front+.20,cone_height,-cone_y)))
	check(cone_axis.is_empty(),"actual window cone retains its finite open centre")
	var cone_crown:=_isolated_ray(world,model,cone_key+"__cast_iron",cell.to_global(Vector3(front+.013,2.,-cone_y)),cell.to_global(Vector3(front+.013,.44,-cone_y)))
	check(not cone_crown.is_empty() and absf(cell.to_local(cone_crown.position).y-(float(cone_row.z0)+float(cone_row.h)))<.00003,"window speaker frame preserves its original 1.04m maximum")

func _retail_detail_views(world: OrisonV2RuntimeRoot, _fixture: Dictionary) -> void:
	var cell: Node3D=world.passage_region.cell_nodes.shop_radio_service;var observations: Array=[]
	var capture_door: DoorProp=world.passage_region.doors["SITE_SHOP_DOOR_RADIO_SERVICE"]
	capture_door.npc_set_open(false);await get_tree().create_timer(.8).timeout
	check(not capture_door.open and absf(capture_door._body.rotation.y)<.000001,"diagnostic leaf reaches existing closed owner pose")
	for view: Dictionary in RADIO_WINDOW_VIEWS:
		var feet:=_v(view.feet);var target:=_v(view.target)
		check(_city_clear_station(world,cell.to_global(feet)),"retained window/counter standing floor and capsule sample: "+str(view.id))
		world.player.global_position=cell.to_global(feet);world.player.velocity=Vector3.ZERO
		world.player.face_world_point(cell.to_global(target));world.player.set_lamp_enabled(bool(view.lamp))
		if capture_enabled:
			await _settled_optics();await shot(view.id)
		observations.append(view.duplicate(true))
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("views.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","views":observations,"capture_leaf_pose":{"id":"SITE_SHOP_DOOR_RADIO_SERVICE","open":capture_door.open,"angle_radians":capture_door._body.rotation.y,"method":"existing npc_set_open closed diagnostic pose; no ordinary-input route claim"},"scope":"Matched floor/capsule observations of window speaker placement and fitted counter. Original glazing/backboard and physical collision remain. Exterior lamp off avoids direct torch reflection. No continuous route, sightline, signal, operation or engineering capacity."}))

const RADIO_WINDOW_VIEWS: Array=[{"id":"passive_window_stock","image":"passive_window_stock.png","feet":[15.6,0.03,57.95],"target":[17.24,0.74,57.95],"lamp":false},{"id":"window_horn_mouth","image":"window_horn_mouth.png","feet":[15.6,0.03,58.25],"target":[17.24,0.72,58.27],"lamp":false},{"id":"window_cone_speaker","image":"window_cone_speaker.png","feet":[15.6,0.03,57.6],"target":[17.24,0.75,57.63],"lamp":false},{"id":"window_plinth_bearings","image":"window_plinth_bearings.png","feet":[15.6,0.03,57.95],"target":[17.35,0.44,57.95],"lamp":false},{"id":"counter_floor_posts","image":"counter_floor_posts.png","feet":[17.5,0.03,56.8],"target":[17.98,0.1,57.36],"lamp":true},{"id":"seated_counter_ledger","image":"seated_counter_ledger.png","feet":[17.5,0.03,56.8],"target":[18.1,1.16,57.35],"lamp":true}]
