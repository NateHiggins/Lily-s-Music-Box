extends "res://tests/orison_v2_city_sweep.gd"
## Actual retained shop boundaries, fitted supports, imported charts and standing detail views.
func _run() -> void:
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928,11,10,20*60);GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var world:=_world_scene().instantiate() as OrisonV2RuntimeRoot;add_child(world)
	await get_tree().physics_frame;await get_tree().physics_frame
	check(not world.startup_failed and not world.passage_region.startup_failed,"composed world fits the original hardware shop")
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
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_hardware_stock.json"))
	check(FileAccess.get_sha256("res://assets/props/hardware_stock.glb")==fixture.asset_sha256,"installed mesh binds the native hardware-stock export")
	var parts:=0;var triangles:=0;var removed:=0;var supports:=0
	for record: Dictionary in fixture.runtime.cells:
		var cell: Node3D=passage.cell_nodes[record.id];var model: Node3D=cell.get_node("HardwareStock")
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
			var name:=str(draw.get_meta("hardware_stock_part"));var expected: Dictionary=fixture.parts.filter(func(row):return row.name==name)[0]
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
					check(bool(runtime_part.get("plain_alpha",false)) and mat.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA and source.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS,"closed stock containers use local plain-alpha blending while source windows retain their depth-prepass material")
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
				if draw!=null and str(draw.get_meta("hardware_stock_part")).begins_with(str(contact.assembly)+"__"):exclude.append(body.get_rid())
			var query:=PhysicsRayQueryParameters3D.create(cell.to_global(at+direction*.004),cell.to_global(at-direction*.004),1,exclude)
			var hit:=world.get_world_3d().direct_space_state.intersect_ray(query)
			check(not hit.is_empty() and cell.to_local(hit.position).distance_to(at)<.00003,"fitted support contact: "+str(contact.label)+" / "+str(contact.owner));supports+=1
	check(parts==fixture.parts.size() and triangles==int(fixture.triangles) and removed==fixture.original_records.size()*12 and supports==fixture.contacts.size(),"native counts bind all original boxes, fitted furniture and floor samples")
	_check_stock_bores(world,fixture)
	await _retail_detail_views(world,fixture)
	await _check_counter_input(world)
	var directory:=OS.get_environment("SHOT_DIR")
	FileAccess.open(directory.path_join("fittings.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","checks":checks,"parts":parts,"triangles":triangles,"removed":removed,"supports":supports,"failures":failures},"\t"))
	print("HARDWARE STOCK: checks=",checks," parts=",parts," triangles=",triangles," removed=",removed," supports=",supports," failures=",failures.size())
	world.shutdown_for_tests();world.free();await _retired_audio();get_tree().quit(0 if failures.is_empty() else 1)

func _isolated_ray(world: OrisonV2RuntimeRoot, model: Node3D, part: String, start: Vector3, finish: Vector3) -> Dictionary:
	var targets:=model.find_children("*","MeshInstance3D",true,false).filter(func(draw):return str(draw.get_meta("hardware_stock_part",""))==part)
	check(targets.size()==1,"actual installed cavity partition: "+part)
	if targets.size()!=1:return {}
	var target: CollisionObject3D=targets[0].find_children("*","CollisionShape3D",true,false)[0].get_parent()
	var exclude: Array[RID]=[]
	for body: CollisionObject3D in world.find_children("*","CollisionObject3D",true,false):
		if body!=target:exclude.append(body.get_rid())
	return world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(start,finish,1,exclude))

func _check_stock_bores(world: OrisonV2RuntimeRoot, fixture: Dictionary) -> void:
	var cell: Node3D=world.passage_region.cell_nodes.shop_hardware_paint;var model: Node3D=cell.get_node("HardwareStock")
	var samples:=0
	for a: Dictionary in fixture.assemblies:
		if a.kind!="brass_stock":continue
		var row: Dictionary=fixture.original_records.filter(func(r):return r.id==a.id)[0];var r: Array=row.rect
		var center:=Vector3((r[0]+r[2])*.5+.20,float(row.z0),-(r[1]+r[3])*.5)
		for dx: float in [-.072,.072]:
			for dz: float in [-.077,.077]:
				var at:=center+Vector3(dx,.012,dz);var brass:=str(a.id)+"__brass_dull";var wood:=str(a.id)+"__timber"
				check(_isolated_ray(world,model,brass,cell.to_global(at+Vector3.UP*.17),cell.to_global(at-Vector3.UP*.01)).is_empty(),"actual pipe-coupling bore is open through both ends")
				var hit:=_isolated_ray(world,model,wood,cell.to_global(at+Vector3.UP*.16),cell.to_global(at-Vector3.UP*.01))
				check(not hit.is_empty() and cell.to_local(hit.position).distance_to(at)<.00003 and hit.normal.dot(cell.global_basis.y)>.99,"coupling bore reaches the actual supporting tray floor")
				# A one-metre segment resolves these small annular triangles; hit
				# position and normal retain the same strict acceptance tolerances.
				var lip:=at+Vector3(.03*cos(.2),.13,.03*sin(.2));hit=_isolated_ray(world,model,brass,cell.to_global(lip+Vector3.UP*.5),cell.to_global(lip-Vector3.UP*.5))
				check(not hit.is_empty() and cell.to_local(hit.position).distance_to(lip)<.00003 and hit.normal.dot(cell.global_basis.y)>.99,"actual flanged coupling rim carries its upper annular face")
				samples+=1
	check(samples==48,"all forty-eight original brass-stock couplings have actual open bores and tray seats")

func _retail_detail_views(world: OrisonV2RuntimeRoot, fixture: Dictionary) -> void:
	var cell: Node3D=world.passage_region.cell_nodes.shop_hardware_paint
	var r: Array=fixture.assemblies[0].floor.rect;var observations: Array=[]
	for view: Array in [["west_rack",Vector3(8.7,.03,56.6),Vector3(7.2,1.25,54.35)],["brass_stock",Vector3(8.35,.03,55.05),Vector3(8.12,1.28,54.385)],["east_rack",Vector3(7.2,.03,57.8),Vector3(7.1,1.26,59.0)],["service_counter",Vector3(8.65,.03,56.4),Vector3(9.88,.75,56.35)],["ledger",Vector3(9.08,.03,56.98),Vector3(9.88,1.16,56.70)],["window_stand",Vector3(9.75,.03,58.05),Vector3(10.63,.55,56.8)]]:
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
		await _settled_optics();await shot(view[0])
		observations.append({"id":view[0],"requested_feet":[preferred.x,preferred.y,preferred.z],"feet":[selected.x,selected.y,selected.z],"target":[view[2].x,view[2].y,view[2].z],"image":str(view[0])+".png"})
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("views.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","views":observations,"scope":"Standing-capsule stock/counter observations; original purchasing, remaining tool/glass racks, plot-device ladder and continuous access retain their separate authority."},"\t"))


func _check_counter_input(world: OrisonV2RuntimeRoot) -> void:
	# Provision the existing job through its public lifecycle; this is a bounded
	# acquisition-input regression, not proof of the complete diagnosis route.
	var job:=ChirpHunt.JOB_ID;var item:="carbon_transmitter_capsule";var shop:="hardware_paint"
	var before:=world.shop_service.stock_record(item)
	world.work_orders.issue_job(job,"reported");world.work_orders.acknowledge_job(job)
	world.work_orders.diagnose_job(job);world.work_orders.mark_job_awaiting_part(job)
	check(world.work_orders.job_stage(job)=="awaiting_part" and world.shop_service.pending_item(shop)==item,"original job lifecycle authorizes the existing capsule purchase")
	var counter:=world.shop_service.counter(shop);check(is_instance_valid(counter),"original service owns the fitted counter's interaction area")
	if not is_instance_valid(counter):return
	var cell: Node3D=world.passage_region.cell_nodes.shop_hardware_paint
	var feet:=cell.to_global(Vector3(8.65,.03,56.4))
	check(_city_clear_station(world,feet),"actual counter-input station is clear and floor-supported")
	world.player.global_position=feet;world.player.velocity=Vector3.ZERO
	world.player.face_world_point(counter.global_position)
	world.player.set_mouse_released(false)
	await get_tree().physics_frame;await get_tree().physics_frame
	var query:=PhysicsRayQueryParameters3D.create(world.player.camera.global_position,world.player.camera.global_position-world.player.camera.global_basis.z*2.1,1,[world.player.get_rid()]);query.collide_with_areas=true
	var hit:=world.get_world_3d().direct_space_state.intersect_ray(query)
	check(not hit.is_empty() and hit.collider==counter,"ordinary 2.1 metre interaction ray reaches the original area above the fitted top")
	world.player._update_prompt();check(world.player._prompt.text.contains("Buy: Carbon transmitter capsule"),"original buy prompt reaches the actual player")
	AudioPolicy.clear_diagnostics()
	var event:=InputEventKey.new();event.keycode=KEY_E;event.physical_keycode=KEY_E;event.pressed=true;Input.parse_input_event(event)
	await get_tree().process_frame
	await get_tree().process_frame
	event=InputEventKey.new();event.keycode=KEY_E;event.physical_keycode=KEY_E;Input.parse_input_event(event)
	await get_tree().process_frame
	var acquired:=world.maintenance_inventory.has_item(item)
	check(acquired and world.work_orders.job_stage(job)=="repairable","ordinary E input acquires the existing capsule through its original service")
	check(acquired and world.shop_service.stock_record(item)==before and not world.shop_service.acquire(item,shop),"purchase retains source inventory and refuses a duplicate grant")
	var issued:=AudioPolicy.event_history().filter(func(r):return r.cue_id==&"interaction.counter_issue" and r.source_id==&"counter:hardware_paint")
	check(issued.size()==1,"actual acquisition presents one original counter-issue answer")
