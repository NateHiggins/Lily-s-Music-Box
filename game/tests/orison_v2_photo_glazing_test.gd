extends "res://tests/orison_v2_city_sweep.gd"
## Actual retained shop boundaries, fitted supports, imported charts and standing detail views.
func _run() -> void:
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928,11,10,20*60);GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var world:=_world_scene().instantiate() as OrisonV2RuntimeRoot;add_child(world)
	await get_tree().physics_frame;await get_tree().physics_frame
	check(not world.startup_failed and not world.passage_region.startup_failed,"composed world fits the original photography shop")
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
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_photo_glazing.json"))
	check(passage.cell_nodes.shop_photo_supplies.has_node("PhotoGlazing"),"actual fixed-glass fitting is present before inspecting its contracts")
	if not passage.cell_nodes.shop_photo_supplies.has_node("PhotoGlazing"):world.shutdown_for_tests();world.free();get_tree().quit(1);return
	check(FileAccess.get_sha256("res://assets/props/photo_glazing.glb")==fixture.asset_sha256,"installed mesh binds the native counter/ledger export")
	var parts:=0;var triangles:=0;var removed:=0;var supports:=0
	for record: Dictionary in fixture.runtime.cells:
		var cell: Node3D=passage.cell_nodes[record.id];var model: Node3D=cell.get_node("PhotoGlazing")
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
			var name:=str(draw.get_meta("photo_glazing_part"));var expected: Dictionary=fixture.parts.filter(func(row):return row.name==name)[0]
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
				if draw!=null and str(draw.get_meta("photo_glazing_part")).begins_with(str(contact.assembly)+"__"):exclude.append(body.get_rid())
			var query:=PhysicsRayQueryParameters3D.create(cell.to_global(at+direction*.004),cell.to_global(at-direction*.004),1,exclude)
			var hit:=world.get_world_3d().direct_space_state.intersect_ray(query)
			check(not hit.is_empty() and cell.to_local(hit.position).distance_to(at)<.00003,"fitted support contact: "+str(contact.label)+" / "+str(contact.owner));supports+=1
	check(parts==fixture.parts.size() and triangles==int(fixture.triangles) and removed==fixture.original_records.size()*12 and supports==fixture.contacts.size(),"native counts bind all original boxes, fitted furniture and floor samples")
	var optical_ref:=_check_glazing_details(world,fixture)
	await _retail_detail_views(world,fixture)
	var directory:=OS.get_environment("SHOT_DIR")
	FileAccess.open(directory.path_join("fittings.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","checks":checks,"parts":parts,"triangles":triangles,"removed":removed,"supports":supports,"failures":failures},"\t"))
	print("PHOTO GLAZING: checks=",checks," parts=",parts," triangles=",triangles," removed=",removed," supports=",supports," failures=",failures.size())
	world.shutdown_for_tests();world.free();await _retired_audio()
	check(optical_ref.get_ref()==null,"local fixed/counter optical material releases with the actual world")
	FileAccess.open(directory.path_join("fittings.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","checks":checks,"parts":parts,"triangles":triangles,"removed":removed,"supports":supports,"failures":failures},"\t"))
	print("PHOTO GLAZING FINAL: checks=",checks," failures=",failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)

func _isolated_ray(world: OrisonV2RuntimeRoot, model: Node3D, part: String, start: Vector3, finish: Vector3) -> Dictionary:
	var targets:=model.find_children("*","MeshInstance3D",true,false).filter(func(draw):return str(draw.get_meta("photo_glazing_part",""))==part)
	check(targets.size()==1,"actual installed cavity partition: "+part)
	if targets.size()!=1:return {}
	var target: CollisionObject3D=targets[0].find_children("*","CollisionShape3D",true,false)[0].get_parent()
	var exclude: Array[RID]=[]
	for body: CollisionObject3D in world.find_children("*","CollisionObject3D",true,false):
		if body!=target:exclude.append(body.get_rid())
	return world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(start,finish,1,exclude))

func _check_glazing_details(world: OrisonV2RuntimeRoot, fixture: Dictionary) -> WeakRef:
	var cell: Node3D=world.passage_region.cell_nodes.shop_photo_supplies;var model: Node3D=cell.get_node("PhotoGlazing")
	check(fixture.original_records.size()==3 and fixture.assemblies.size()==3 and fixture.closed_stocks.size()==3,"exact three original fixed sheets retain single connected closed stock")
	for row: Dictionary in fixture.original_records:
		var identity:=str(row.id);var r: Array=row.rect;var t:=float(fixture.thickness_m[identity]);var expected:=.006 if identity.ends_with("borrowed_glass") else .008
		check(t==expected,"declared fixed-sheet thickness: "+identity)
		var at:=Vector3((float(r[0])+float(r[2]))*.5,float(row.z0)+float(row.h)*.5,-(float(r[1])+float(r[3]))*.5)
		for side: float in [-1.,1.]:
			var hit:=_isolated_ray(world,model,identity+"__glassish",cell.to_global(at+Vector3(side*.15,0,0)),cell.to_global(at-Vector3(side*.15,0,0)))
			check(not hit.is_empty() and absf(cell.to_local(hit.position).x-(at.x+side*t*.5))<.00003 and hit.normal.dot(cell.global_basis.x*side)>.99,"actual outward fixed-sheet face and physical thickness: "+identity+" / "+str(side))
		var target: MeshInstance3D=model.find_children("*","MeshInstance3D",true,false).filter(func(draw):return str(draw.get_meta("photo_glazing_part"))==identity+"__glassish")[0]
		var bounds: AABB=target.transform*target.mesh.get_aabb()
		check(absf(bounds.position.x-(at.x-t*.5))<.000003 and absf(bounds.size.x-t)<.000003 and absf(bounds.position.y-float(row.z0))<.000003 and absf(bounds.size.y-float(row.h))<.000003 and absf(bounds.position.z+float(r[3]))<.000003 and absf(bounds.size.z-(float(r[3])-float(r[1])))<.000003,"finished sheet preserves original plan/centre/height: "+identity)
	var factory:=preload("res://scripts/building/orison_v2_architectural_materials.gd").new()
	check(factory.key_for(str(fixture.runtime.optics.role),str(fixture.runtime.optics.room_class))=="glass","existing architectural catalogue role owns the proposed optics")
	var glass: ShaderMaterial=model.get_meta("optical_material")
	check(glass!=null and glass.shader.resource_path==str(fixture.runtime.optics.shader) and is_equal_approx(float(glass.get_shader_parameter("surface_roughness")),float(fixture.runtime.optics.surface_roughness)),"actual registered shader and roughness retain their declared owner")
	var other:=factory.material_for("Glazing","public")
	check(other!=glass and (other as ShaderMaterial).shader==glass.shader,"cell owns its own optical instance while sharing the unchanged shader")
	var draws:=_optical_draws(cell);check(draws.size()==4,"three fixed sheets and the existing four-pane counter partition receive optics")
	for draw: MeshInstance3D in draws:
		check(draw.material_override==glass and draw.get_active_material(0)==glass and draw.get_meta("glazing_optical_owner")==str(fixture.runtime.optics.registered_owner),"actual drawn optical material is the declared local owner: "+str(draw.name))
		check(draw.mesh.surface_get_material(0)==draw.get_meta("glazing_source_surface") and draw.mesh.surface_get_material(0) is StandardMaterial3D and draw.get_meta("glazing_original_override").material==null,"original mapped shipping surface remains beneath the local optical override")
	var counter_fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_photo_counter.json"))
	check(FileAccess.get_sha256("res://assets/props/photo_counter.glb")==counter_fixture.asset_sha256,"counter's original four-pane geometry retains its exact asset hash")
	return weakref(glass)

func _optical_draws(cell: Node3D) -> Array:
	var draws: Array=cell.get_node("PhotoGlazing").find_children("*","MeshInstance3D",true,false)
	draws.append_array(cell.get_node("PhotoCounter").find_children("*","MeshInstance3D",true,false).filter(func(draw):return str(draw.get_meta("photo_counter_part","")).ends_with("counter__glassish")))
	return draws

func _optical_snapshot(world: OrisonV2RuntimeRoot) -> Dictionary:
	var lights: Array=[]
	for light: Light3D in world.find_children("*","Light3D",true,false):
		lights.append({"path":str(world.get_path_to(light)),"visible":light.visible,"energy":light.light_energy,"color":[light.light_color.r,light.light_color.g,light.light_color.b,light.light_color.a],"transform":str(light.global_transform)})
	var lamp:=world.player.flashlight;var camera:=world.player.camera
	return {"lights":lights,"lamp_on":world.player.lamp_is_enabled(),"lamp_range":lamp.spot_range,"lamp_angle":lamp.spot_angle,"lamp_attenuation":lamp.spot_angle_attenuation,"camera_transform":str(camera.global_transform),"fov":camera.fov,"near":camera.near,"far":camera.far}

func _retail_detail_views(world: OrisonV2RuntimeRoot, fixture: Dictionary) -> void:
	var cell: Node3D=world.passage_region.cell_nodes.shop_photo_supplies
	var floor_row: Dictionary=fixture.assemblies[0].floor;var r: Array=floor_row.rect;var observations: Array=[]
	var draws:=_optical_draws(cell);var glass: Material=cell.get_node("PhotoGlazing").get_meta("optical_material")
	for view: Array in [["window_display",Vector3(15.55,.03,61.15),Vector3(17.45,.73,61.20)],["window_camera_detail",Vector3(16.10,.03,62.14),Vector3(17.40,.72,61.87)],["transom",Vector3(15.55,.03,62.6),Vector3(16.92,2.24,61.55)],["counter_front",Vector3(17.20,.03,62.8),Vector3(18.25,1.12,61.3)],["counter_back",Vector3(19.55,.03,61.3),Vector3(18.3,1.11,61.3)],["borrowed_light",Vector3(21.48,.03,62.7),Vector3(22.97,2.7,61.9)],["shop_context",Vector3(20.5,.03,62.7),Vector3(22.885,1.385,61.95)]]:
		var preferred: Vector3=view[1];var selected:=preferred;var distance:=INF
		if not _city_clear_station(world,cell.to_global(preferred)):
			for u in range(1,25):
				for v in range(1,25):
					var at:=Vector3(lerpf(r[0],r[2],u/25.),.03,-lerpf(r[1],r[3],v/25.))
					if at.distance_squared_to(preferred)<distance and _city_clear_station(world,cell.to_global(at)):
						selected=at;distance=at.distance_squared_to(preferred)
		check(_city_clear_station(world,cell.to_global(selected)),"actual floor-supported paired-glass observation: "+str(view[0]))
		world.player.global_position=cell.to_global(selected);world.player.velocity=Vector3.ZERO
		world.player.face_world_point(cell.to_global(view[2]));world.player.set_lamp_enabled(true)
		await _settled_optics()
		var previous_mode:=world.process_mode;world.process_mode=Node.PROCESS_MODE_DISABLED
		var before:=_optical_snapshot(world)
		for draw: MeshInstance3D in draws:draw.material_override=draw.get_meta("glazing_original_override").material as Material
		for draw: MeshInstance3D in draws:check(draw.get_active_material(0)==draw.get_meta("glazing_source_surface"),"paired reference draws the retained mapped surface")
		await _settled_optics();await shot(str(view[0])+"_mapped_reference")
		for draw: MeshInstance3D in draws:draw.material_override=glass
		await _settled_optics();await shot(str(view[0])+"_registered_clear")
		var after:=_optical_snapshot(world)
		check(before==after,"both glass captures use identical actual light outputs and camera parameters: "+str(view[0]))
		world.process_mode=previous_mode
		observations.append({"id":view[0],"requested_feet":[preferred.x,preferred.y,preferred.z],"feet":[selected.x,selected.y,selected.z],"target":[view[2].x,view[2].y,view[2].z],"mapped_reference":str(view[0])+"_mapped_reference.png","registered_clear":str(view[0])+"_registered_clear.png","optics_before":before,"optics_after":after})
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("views.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","views":observations,"scope":"Paired original mapped / existing registered clear finish on the same fitted panes, same actual camera and light output, frozen world update. GPU dust and sampling remain ordinary; no exact-pixel claim. Native geometry, darkroom light-tightness, operating photography, continuous routes and services retain separate duties."},"\t"))
