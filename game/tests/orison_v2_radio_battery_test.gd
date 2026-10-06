extends "res://tests/orison_v2_city_sweep.gd"
## Actual retained shop boundaries, fitted supports, imported charts and standing detail views.
func _run() -> void:
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928,11,10,20*60);GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var world:=_world_scene().instantiate() as OrisonV2RuntimeRoot;add_child(world)
	await get_tree().physics_frame;await get_tree().physics_frame
	check(not world.startup_failed and not world.passage_region.startup_failed,"source-owned charging display fits Radio Service")
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
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_radio_battery.json"))
	var installed: bool=passage.cell_nodes.has("shop_radio_service") and passage.cell_nodes.shop_radio_service.has_node("RadioBattery")
	check(installed,"actual retained radio cell and native fittings exist before their contracts")
	if not installed:world.shutdown_for_tests();world.free();get_tree().quit(1);return
	check(FileAccess.get_sha256("res://assets/props/radio_battery.glb")==fixture.asset_sha256,"installed mesh binds the native charging display export")
	var parts:=0;var triangles:=0;var removed:=0;var supports:=0
	for record: Dictionary in fixture.runtime.cells:
		var cell: Node3D=passage.cell_nodes[record.id];var model: Node3D=cell.get_node("RadioBattery")
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
			var name:=str(draw.get_meta("radio_battery_part"));var expected: Dictionary=fixture.parts.filter(func(row):return row.name==name)[0]
			check(count==int(expected.triangles) and expected.cell==record.id,"each fitted partition binds exact native triangles and cell")
			_check_cap_mapping(draw.mesh,true)
			var mat:=draw.mesh.surface_get_material(0) as StandardMaterial3D
			check(mat!=null and not mat.uv1_triplanar and mat.roughness_texture!=null and mat.normal_texture!=null,"declared original and local catalogue maps reach native metre charts")
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

			if runtime_part.has("plain_alpha"):
				check(bool(runtime_part.plain_alpha) and source!=null and source.albedo_texture==null and mat.albedo_texture==null and mat.albedo_color.is_equal_approx(source.albedo_color) and mat.cull_mode==source.cull_mode and mat.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA,"finite glass retains literal source alpha, colour and culling with its declared local alpha adaptation")
			else:check(mat.albedo_texture!=null,"opaque original and registered stock retains an albedo map")
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
				if draw!=null and str(draw.get_meta("radio_battery_part")).begins_with(str(contact.assembly)+"__"):exclude.append(body.get_rid())
			var query:=PhysicsRayQueryParameters3D.create(cell.to_global(at+direction*.004),cell.to_global(at-direction*.004),1,exclude)
			var hit:=world.get_world_3d().direct_space_state.intersect_ray(query)
			check(not hit.is_empty() and cell.to_local(hit.position).distance_to(at)<.00003,"fitted support contact: "+str(contact.label)+" / "+str(contact.owner));supports+=1
	check(parts==fixture.parts.size() and triangles==int(fixture.triangles) and removed==fixture.original_records.size()*12 and supports==fixture.contacts.size(),"native counts bind all original boxes, charging display and actual floor samples")
	_check_battery_details(world,fixture)
	await _retail_detail_views(world,fixture)
	var directory:=OS.get_environment("SHOT_DIR")
	FileAccess.open(directory.path_join("fittings.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","checks":checks,"parts":parts,"triangles":triangles,"removed":removed,"supports":supports,"failures":failures},"\t"))
	print("RADIO BATTERY: checks=",checks," parts=",parts," triangles=",triangles," removed=",removed," supports=",supports," failures=",failures.size())
	world.shutdown_for_tests();world.free();await _retired_audio();get_tree().quit(0 if failures.is_empty() else 1)

func _isolated_ray(world: OrisonV2RuntimeRoot, model: Node3D, part: String, start: Vector3, finish: Vector3) -> Dictionary:
	var targets:=model.find_children("*","MeshInstance3D",true,false).filter(func(draw):return str(draw.get_meta("radio_battery_part",""))==part)
	check(targets.size()==1,"actual installed fitting partition: "+part)
	if targets.size()!=1:return {}
	var target: CollisionObject3D=targets[0].find_children("*","CollisionShape3D",true,false)[0].get_parent()
	var exclude: Array[RID]=[]
	for body: CollisionObject3D in world.find_children("*","CollisionObject3D",true,false):
		if body!=target:exclude.append(body.get_rid())
	return world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(start,finish,1,exclude))

func _check_battery_details(world: OrisonV2RuntimeRoot, fixture: Dictionary) -> void:
	var cell: Node3D=world.passage_region.cell_nodes.shop_radio_service;var model: Node3D=cell.get_node("RadioBattery")
	check(fixture.original_records.size()==11 and fixture.fitted_records.size()==11 and fixture.assemblies.size()==1 and fixture.closed_stocks.size()==64,"eleven preserved source records become one fitted charging assembly")
	check(model.find_children("*","Light3D",true,false).is_empty(),"passive charging display adds no light or signal")
	var originals: Dictionary={};var fitted: Dictionary={}
	for row: Dictionary in fixture.original_records:originals[str(row.id)]=row
	for row: Dictionary in fixture.fitted_records:fitted[str(row.id)]=row
	var source_rows: Array=world.passage_region.source_layout.floors.filter(func(row):return row.id=="F01")[0].furniture
	var counter: Dictionary=source_rows.filter(func(row):return row.id=="storm_shop_radio_service_counter_top")[0]
	var bench: Dictionary=source_rows.filter(func(row):return row.id=="storm_shop_radio_service_bench_top")[0]
	var rack: String=fixture.assemblies[0].id;var dx: float=float(counter.rect[2])+.15-float(originals[rack].rect[0])
	var dy: float=float(bench.rect[1])-.72-float(originals[rack].rect[3])
	for identity: String in fitted:
		var original: Dictionary=originals[identity];var actual: Dictionary=fitted[identity];var expected: Dictionary=original.duplicate(true)
		expected.rect[0]+=dx;expected.rect[2]+=dx;expected.rect[1]+=dy;expected.rect[3]+=dy
		# Independent Godot parsing measured two 7.1e-15m coordinate
		# differences. Keep all non-placement fields exact and compare
		# derived doubles within 1e-12m; physical surfaces remain at 30um.
		var unchanged:=actual.duplicate(true);unchanged.erase("rect")
		var fields:=original.duplicate(true);fields.erase("rect");var coordinates_match:=true
		for component in 4:coordinates_match=coordinates_match and absf(float(actual.rect[component])-float(expected.rect[component]))<1e-12
		check(unchanged==fields and coordinates_match,"fitted placement derives from the authored counter and bench while retaining every non-placement field: "+identity)
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		var mat:=draw.mesh.surface_get_material(0) as StandardMaterial3D
		check(draw.transform.basis.is_equal_approx(Basis.IDENTITY) and draw.material_override==null and mat!=null and not mat.emission_enabled,"unit-scale partitions and passive materials retain their owners")
	for contact: Dictionary in fixture.contacts:
		var point:=_v(contact.point)
		var underside:=_isolated_ray(world,model,rack+"__timber",cell.to_global(point-Vector3(0,4,0)),cell.to_global(point+Vector3(0,6,0)))
		check(not underside.is_empty() and cell.to_local(underside.position).distance_to(point)<.00003,"each imported rack foot meets the unchanged retained floor")
	for index in 5:
		var jar: Dictionary=fitted["storm_shop_radio_service_wet_cell"+str(index)];var q: Array=jar.rect
		var x: float=(float(q[0])+float(q[2]))*.5;var z: float=-(float(q[1])+float(q[3]))*.5
		var base: float=jar.z0;var crown: float=base+float(jar.h)
		var glass:=_vertical_battery_ray(world,model,rack+"__glass_shell",Vector3(x,base,z),false)
		var pad:=_vertical_battery_ray(world,model,rack+"__timber",Vector3(x,base,z),true)
		var lip:=_vertical_battery_ray(world,model,rack+"__glass_shell",Vector3(x+.101,crown,z),true)
		var cap:=_vertical_battery_ray(world,model,rack+"__bakelite_black",Vector3(x,1.272,z),false)
		var collar:=_vertical_battery_ray(world,model,rack+"__bakelite_black",Vector3(x+.095,1.255,z),false)
		check(_battery_height(cell,glass,base) and _battery_height(cell,pad,base),"actual hollow glass bottom and fitted timber pad meet at original jar height: "+str(index))
		check(_battery_height(cell,lip,crown) and _battery_height(cell,cap,1.272) and _battery_height(cell,collar,1.255),"actual finite glass lip and inserted cap collar bridge the original cap gap: "+str(index))
		for terminal in 2:
			var xx: float=x+(-.05 if terminal==0 else .05)
			var top:=_vertical_battery_ray(world,model,rack+"__terminal_metal",Vector3(xx,1.33,z),true)
			check(_battery_height(cell,top,1.33),"passive terminal preserves original cap maximum: "+str(index)+"/"+str(terminal))
	for index in 4:
		var left: Dictionary=fitted["storm_shop_radio_service_wet_cell"+str(index)];var right: Dictionary=fitted["storm_shop_radio_service_wet_cell"+str(index+1)]
		var a:=Vector3((left.rect[0]+left.rect[2])*.5+.05,1.324,-(left.rect[1]+left.rect[3])*.5)
		var b:=Vector3((right.rect[0]+right.rect[2])*.5-.05,1.324,-(right.rect[1]+right.rect[3])*.5)
		for end in 2:
			# Query the first interior cross-section, not its finite end-face
			# boundary. Independent probes retain all eight original misses.
			# The whole wire radius at this sample fits inside its 7mm post.
			var endpoint:=a if end==0 else b;var sample:=endpoint.lerp(b if end==0 else a,.01)
			var wire:=_vertical_battery_ray(world,model,rack+"__series_wire",sample,false)
			var post_top:=_vertical_battery_ray(world,model,rack+"__terminal_metal",sample,true)
			var post_bottom:=_vertical_battery_ray(world,model,rack+"__terminal_metal",sample,false)
			var expected: float=1.324+.003*sin(PI/12.)*.12-.0022
			check(sample.distance_to(endpoint)+.0022<.007 and _battery_height(cell,wire,expected) and _battery_height(cell,post_top,1.33) and _battery_height(cell,post_bottom,1.284),"each copper link endpoint seats inside an actual passive terminal: "+str(index)+"/"+str(end))
	var timber: MeshInstance3D=model.find_children("*","MeshInstance3D",true,false).filter(func(draw):return str(draw.get_meta("radio_battery_part",""))==rack+"__timber")[0]
	var bounds: AABB=timber.transform*timber.mesh.get_aabb()
	check(absf(bounds.position.x-(float(counter.rect[2])+.15))<.00003 and bounds.end.x<19.,"fitted rack clears the retained cabinet and follows the authored counter datum")
	check(absf(bounds.position.z-(-float(bench.rect[1])+.72))<.00003,"rack front preserves the declared 720mm source-derived bench passage")

func _vertical_battery_ray(world: OrisonV2RuntimeRoot, model: Node3D, part: String, at: Vector3, downward: bool) -> Dictionary:
	var direction:=Vector3.DOWN if downward else Vector3.UP
	return _isolated_ray(world,model,part,model.get_parent().to_global(at-direction*5.),model.get_parent().to_global(at+direction*5.))

func _battery_height(cell: Node3D, hit: Dictionary, expected: float) -> bool:
	return not hit.is_empty() and absf(cell.to_local(hit.position).y-expected)<.00003

func _retail_detail_views(world: OrisonV2RuntimeRoot, _fixture: Dictionary) -> void:
	var cell: Node3D=world.passage_region.cell_nodes.shop_radio_service;var observations: Array=[]
	for view: Dictionary in RADIO_BATTERY_VIEWS:
		var feet:=_v(view.feet);var target:=_v(view.target)
		check(_city_clear_station(world,cell.to_global(feet)),"same retained floor/capsule radio charging display observation: "+str(view.id))
		world.player.global_position=cell.to_global(feet);world.player.velocity=Vector3.ZERO
		world.player.face_world_point(cell.to_global(target));world.player.set_lamp_enabled(true)
		await _settled_optics();await shot(view.id)
		observations.append(view.duplicate(true))
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("views.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","views":observations,"scope":"Same retained standing floor/capsule samples before and after charging display fitting. No continuous route, sightline, alignment procedure, instrument operation or engineering capacity."},"\t"))

const RADIO_BATTERY_VIEWS: Array=[{"id":"radio_battery_room","image":"radio_battery_room.png","feet":[19.45,0.03,57.8],"target":[18.77,1.02,57.800000000000004]},{"id":"five_charging_jars","image":"five_charging_jars.png","feet":[19.4,0.03,57.2],"target":[18.77,1.12,57.800000000000004]},{"id":"jar_and_cap_seat","image":"jar_and_cap_seat.png","feet":[19.4,0.03,57.5],"target":[18.77,1.24,58.190000000000005]},{"id":"passive_series_links","image":"passive_series_links.png","feet":[19.4,0.03,57.5],"target":[18.77,1.325,57.9]},{"id":"rack_floor_feet","image":"rack_floor_feet.png","feet":[19.4,0.03,57.8],"target":[18.77,0.1,57.800000000000004]},{"id":"retained_repair_cabinet","image":"retained_repair_cabinet.png","feet":[19.45,0.03,57.5],"target":[21.45,0.95,57.2]}]
