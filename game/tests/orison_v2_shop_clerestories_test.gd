extends "res://tests/orison_v2_city_sweep.gd"
## Actual retained shop boundaries, fitted supports, imported charts and standing detail views.
var batch_mode := false
var capture_enabled := true
var encoded_contact_offsets: Array = []

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
	var passage: OrisonV2PassageRegion=world.passage_region
	check(not world.startup_failed and not passage.startup_failed,"composed world fits the original eleven borrowed-light assemblies")
	check(passage.residency.state=="RESIDENT","normal prefetch exposes fitted stock geometry")
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_shop_clerestories.json"))
	check(FileAccess.get_sha256("res://assets/props/shop_clerestories.glb")==fixture.asset_sha256,"installed mesh binds the native composed furnishing export")
	var owner_rows: Array=passage.source_layout.floors.filter(func(floor):return floor.id=="F01")[0].furniture
	var parts:=0;var triangles:=0;var removed:=0;var supports:=0
	for record: Dictionary in fixture.runtime.cells:
		var cell: Node3D=passage.cell_nodes[record.id];var model: Node3D=cell.get_node("ShopClerestories")
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
			var name:=str(draw.get_meta("shop_clerestories_part"));var expected: Dictionary=fixture.parts.filter(func(row):return row.name==name)[0]
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
			var bounds: AABB=draw.transform*draw.mesh.get_aabb();check(maxf(maxf(bounds.size.x,bounds.size.y),bounds.size.z)<8.,"individual furniture partitions retain bounded culling")
			var shape: CollisionShape3D=draw.find_children("*","CollisionShape3D",true,false)[0]
			check((shape.shape as ConcavePolygonShape3D).get_faces()==draw.mesh.get_faces() and shape.global_transform.is_equal_approx(draw.global_transform),"native furniture physical triangles and poses match visible triangles")
		for contact: Dictionary in fixture.contacts:
			if not record.parts.any(func(part):return str(part.name).begins_with(str(contact.assembly)+"__")):continue
			var at:=_v(contact.point);var direction:=_v(contact.direction);var exclude: Array[RID]=[world.player.get_rid()]
			for body: CollisionObject3D in model.find_children("*","CollisionObject3D",true,false):
				var draw:=body.get_parent() as MeshInstance3D
				if draw!=null and str(draw.get_meta("shop_clerestories_part")).begins_with(str(contact.assembly)+"__"):
					exclude.append(body.get_rid())
			# Keep the near start, but use a long segment to resolve small triangles.
			var query:=PhysicsRayQueryParameters3D.create(cell.to_global(at+direction*.004),cell.to_global(at-direction*2.),1,exclude)
			var hit:=world.get_world_3d().direct_space_state.intersect_ray(query)
			var tolerance:=.00003
			# Retained V1 draws quantize all three position axes. Their diagonal
			# gives a conservative one-step XYZ error bound; native owners keep 30um.
			if not contact.native_owner and not hit.is_empty():
				var source_draw: MeshInstance3D=hit.collider.get_parent()
				tolerance+=source_draw.mesh.get_aabb().size.length()/65535.
			var offset: float=cell.to_local(hit.position).distance_to(at) if not hit.is_empty() else INF
			check(not hit.is_empty() and offset<tolerance,"fitted support contact within declared source encoding: "+str(contact.label)+" / "+str(contact.owner));supports+=1
			if offset>.00003:encoded_contact_offsets.append({"owner":contact.owner,"label":contact.label,"offset_m":offset,"budget_m":tolerance,"native_owner":contact.native_owner})
			if contact.native_owner:
				check(not hit.is_empty() and hit.collider.get_parent().get_meta_list().any(func(key):return str(key).ends_with("_part") and str(hit.collider.get_parent().get_meta(key)).begins_with(str(contact.owner)+"__")),"actual native bearing reaches its declared fitted owner")
			else:
				var owner: Dictionary=owner_rows.filter(func(row):return row.id==contact.owner)[0]
				check(not hit.is_empty() and str(hit.collider.get_parent().name).trim_suffix("-col").ends_with("_"+str(owner.mat)),"actual bearing reaches its retained floor or wainscot material owner")
	check(parts==fixture.parts.size() and triangles==int(fixture.triangles) and removed==fixture.original_records.size()*12 and supports==fixture.contacts.size(),"native counts bind all original boxes, fitted furniture and wall/ceiling samples")
	_check_clerestory_details(world,fixture)
	await _clerestory_views(world,fixture)
	var directory:=OS.get_environment("SHOT_DIR")
	FileAccess.open(directory.path_join("clerestories.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","checks":checks,"parts":parts,"triangles":triangles,"removed":removed,"supports":supports,"encoded_contact_offsets":encoded_contact_offsets,"failures":failures},"\t"))
	print("SHOP CLERESTORIES: checks=",checks," parts=",parts," triangles=",triangles," removed=",removed," supports=",supports," failures=",failures.size())
	return {"checks":checks,"parts":parts,"triangles":triangles,"removed":removed,"supports":supports,"encoded_contact_offsets":encoded_contact_offsets,"failures":failures.duplicate()}

func _isolated_ray(world: OrisonV2RuntimeRoot, model: Node3D, part: String, start: Vector3, finish: Vector3) -> Dictionary:
	var targets:=model.find_children("*","MeshInstance3D",true,false).filter(func(draw):return str(draw.get_meta("shop_clerestories_part",""))==part)
	check(targets.size()==1,"actual installed cavity partition: "+part)
	if targets.size()!=1:return {}
	var target: CollisionObject3D=targets[0].find_children("*","CollisionShape3D",true,false)[0].get_parent()
	var exclude: Array[RID]=[]
	for body: CollisionObject3D in world.find_children("*","CollisionObject3D",true,false):
		if body!=target:exclude.append(body.get_rid())
	var query:=PhysicsRayQueryParameters3D.create(start,finish,1,exclude)
	query.hit_back_faces=false
	return world.get_world_3d().direct_space_state.intersect_ray(query)

func _check_clerestory_details(world: OrisonV2RuntimeRoot, fixture: Dictionary) -> void:
	check(fixture.original_records.size()==89 and fixture.assemblies.size()==11 and fixture.runtime.cells.size()==11,"exact trim, sheet and rebated-wall source count")
	var photo: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_photo_glazing.json"))
	check(FileAccess.get_sha256("res://assets/props/photo_glazing.glb")==photo.asset_sha256,"existing Photo glazing export remains bound to its accepted fixture")
	var optics: Dictionary=fixture.runtime.optics
	check(optics.role=="Glazing" and optics.room_class=="public" and optics.registered_owner=="res://scripts/building/orison_v2_architectural_materials.gd" and optics.shader=="res://shaders/lamp_glass_surface.gdshader" and float(optics.surface_roughness)==.06,"declared existing local optical owner")
	for assembly: Dictionary in fixture.assemblies:
		var cell: Node3D=world.passage_region.cell_nodes[assembly.cell];var model: Node3D=cell.get_node("ShopClerestories")
		check(model.find_children("*","Area3D",true,false).is_empty(),"fixed clerestory adds no interaction authority")
		var glass: Dictionary=assembly.glazing;var q: Array=glass.rect;var cx: float=(q[0]+q[2])*.5;var cy: float=(q[1]+q[3])*.5
		var source: Dictionary=fixture.original_records.filter(func(row):return row.id==assembly.id)[0]
		var pane_model: Node3D=model;var part:=str(assembly.id)+"__glassish";var meta:="shop_clerestories_part"
		if assembly.cell=="shop_photo_supplies":
			pane_model=cell.get_node("PhotoGlazing");part=str(glass.id)+"__glassish";meta="photo_glazing_part"
		var panes:=pane_model.find_children("*","MeshInstance3D",true,false).filter(func(draw):return str(draw.get_meta(meta,""))==part)
		check(panes.size()==1,"one physical sheet owner, preserving the accepted Photo pane")
		if panes.size()!=1:continue
		var pane: MeshInstance3D=panes[0];var box: AABB=pane.transform*pane.mesh.get_aabb()
		check(absf(box.size.x-.006)<.00003 and absf(box.get_center().x-cx)<.00003 and absf(box.position.y-float(glass.z0))<.00003 and absf(box.size.y-float(glass.h))<.00003 and absf(box.position.z+float(q[3]))<.00003 and absf(box.size.z-float(q[3])+float(q[1]))<.00003,"actual six-millimetre pane retains centre, width and vertical envelope")
		var optical:=pane.material_override as ShaderMaterial
		check(optical!=null and optical.shader.resource_path==str(optics.shader) and is_equal_approx(float(optical.get_shader_parameter("surface_roughness")),.06),"actual pane uses the existing clear dielectric shader")
		if assembly.cell!="shop_photo_supplies":check(optical==model.get_meta("optical_material") and pane.get_meta("glazing_source_surface")==pane.mesh.surface_get_material(0),"per-cell optical override retains its source surface")
		for level in [float(source.z0)+.025,float(glass.z0)+float(glass.h)+.025]:
			var at:=Vector3(cx,level,-cy)
			var cavity:=_isolated_ray(world,model,str(assembly.id)+"__plaster_stained",cell.to_global(at+Vector3.RIGHT*2.),cell.to_global(at-Vector3.RIGHT*2.))
			check(cavity.is_empty(),"wall pocket does not retain plaster inside the sill or head")
		# The retained Photo fixture's two original contact positions must still seat.
		for level in [float(glass.z0),float(glass.z0)+float(glass.h)]:
			var direction:=Vector3.UP if level<float(glass.z0)+.1 else Vector3.DOWN;var at:=Vector3(cx,level,-cy)
			var seat:=_isolated_ray(world,model,str(assembly.id)+"__trim",cell.to_global(at+direction*.08),cell.to_global(at-direction*.08))
			check(not seat.is_empty() and cell.to_local(seat.position).distance_to(at)<.00003,"native sill/head preserve original pane bearing planes")

func _clerestory_views(world: OrisonV2RuntimeRoot, fixture: Dictionary) -> void:
	var observations: Array=[]
	for assembly: Dictionary in fixture.assemblies:
		var cell: Node3D=world.passage_region.cell_nodes[assembly.cell]
		var source: Dictionary=fixture.original_records.filter(func(row):return row.id==assembly.id)[0]
		var r: Array=source.rect;var floor_r: Array=assembly.floor.rect
		var g: Array=assembly.glazing.rect
		var target:=Vector3((float(g[0])+float(g[2]))*.5,2.70,-(float(g[1])+float(g[3]))*.5)
		var direction:=1.0 if target.x<(float(floor_r[0])+float(floor_r[2]))*.5 else -1.0
		var preferred:=Vector3(target.x+direction*3.50,.03,target.z)
		var selected:=preferred;var distance:=INF
		if not _city_clear_station(world,cell.to_global(preferred)):
			for u in range(1,25):
				for v in range(1,25):
					var at:=Vector3(lerpf(floor_r[0],floor_r[2],u/25.),.03,-lerpf(floor_r[1],floor_r[3],v/25.))
					if at.distance_squared_to(preferred)<distance and _city_clear_station(world,cell.to_global(at)):selected=at;distance=at.distance_squared_to(preferred)
		check(_city_clear_station(world,cell.to_global(selected)),"floor-supported clerestory observation: "+str(assembly.id))
		world.player.global_position=cell.to_global(selected);world.player.velocity=Vector3.ZERO
		world.player.face_world_point(cell.to_global(target));world.player.set_lamp_enabled(true)
		if capture_enabled:
			await _settled_optics();await shot(str(assembly.cell)+"_"+str(assembly.kind))
		observations.append({"id":assembly.id,"feet":[selected.x,selected.y,selected.z],"target":[target.x,target.y,target.z]})
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("views.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","views":observations,"scope":"Original high-level glass and rebated frames; no new opening or route authority."},"\t"))
