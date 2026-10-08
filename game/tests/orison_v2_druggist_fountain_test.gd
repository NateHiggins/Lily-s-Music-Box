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
	check(not world.startup_failed and not world.passage_region.startup_failed,"original unused soda fountain fits the Otis & Son shop")
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
	var passage: OrisonV2PassageRegion = world.passage_region
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_druggist_fountain.json"))
	var installed: bool=passage.cell_nodes.has("shop_otis_son") and passage.cell_nodes.shop_otis_son.has_node("DruggistFountain")
	check(installed,"actual retained druggist cell and fountain fitting exist before their contracts")
	if not installed:return {"checks":checks,"failures":failures}
	check(FileAccess.get_sha256("res://assets/props/druggist_fountain.glb")==fixture.asset_sha256,"installed mesh binds the native unused-fountain export")
	var parts:=0;var triangles:=0;var removed:=0;var supports:=0
	for record: Dictionary in fixture.runtime.cells:
		var cell: Node3D=passage.cell_nodes[record.id];var model: Node3D=cell.get_node("DruggistFountain")
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
			var name:=str(draw.get_meta("druggist_fountain_part"));var expected: Dictionary=fixture.parts.filter(func(row):return row.name==name)[0]
			check(count==int(expected.triangles) and expected.cell==record.id,"each fitted partition binds exact native triangles and cell")
			_check_cap_mapping(draw.mesh,true)
			var mat:=draw.mesh.surface_get_material(0) as StandardMaterial3D
			check(mat!=null and not mat.uv1_triplanar and (mat.albedo_texture!=null or str(expected.key).begins_with("glassish")) and mat.roughness_texture!=null and mat.normal_texture!=null,"source optical maps reach native metre charts; drawn glass retains its literal color")
			var source: StandardMaterial3D
			var runtime_part: Dictionary=record.parts.filter(func(row):return row.name==name)[0]
			for original_draw: MeshInstance3D in originals:
				if str(original_draw.name).trim_suffix("-col").ends_with("_"+str(runtime_part.key)):source=originals[original_draw].surface_get_material(0)
			if runtime_part.has("catalog_key"):
				var library:=MatLib.get_mat(str(runtime_part.catalog_key))
				check(library!=mat and library.uv1_triplanar and library.albedo_texture==mat.albedo_texture and library.roughness_texture==mat.roughness_texture and library.normal_texture==mat.normal_texture and mat.uv1_scale.is_equal_approx(library.uv1_scale),"local registered finishes use their catalogue owner without changing shared materials")
				check(mat.metallic==library.metallic and mat.roughness==library.roughness and mat.normal_scale==library.normal_scale,"catalogued finish retains its metallic, roughness and normal strength")
			else:
				check(source!=null and source!=mat and source.albedo_texture==mat.albedo_texture and source.roughness_texture==mat.roughness_texture and source.normal_texture==mat.normal_texture,"original marble and chrome retain their original shipping maps")
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
				if draw!=null and str(draw.get_meta("druggist_fountain_part")).begins_with(str(contact.assembly)+"__"):exclude.append(body.get_rid())
			var query:=PhysicsRayQueryParameters3D.create(cell.to_global(at+direction*.004),cell.to_global(at-direction*.004),1,exclude)
			var hit:=world.get_world_3d().direct_space_state.intersect_ray(query)
			check(not hit.is_empty() and cell.to_local(hit.position).distance_to(at)<.00003,"fitted support contact: "+str(contact.label)+" / "+str(contact.owner));supports+=1
	check(parts==fixture.parts.size() and triangles==int(fixture.triangles) and removed==fixture.original_records.size()*12 and supports==fixture.contacts.size(),"native counts bind all original boxes, fitted furniture and floor samples")
	_check_fountain_details(world,fixture)
	await _retail_detail_views(world,fixture)
	var directory:=OS.get_environment("SHOT_DIR")
	FileAccess.open(directory.path_join("fittings.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","checks":checks,"parts":parts,"triangles":triangles,"removed":removed,"supports":supports,"failures":failures},"\t"))
	print("DRUGGIST FOUNTAIN: checks=",checks," parts=",parts," triangles=",triangles," removed=",removed," supports=",supports," failures=",failures.size())
	return {"checks":checks,"failures":failures,"parts":parts,"triangles":triangles,"supports":supports}

func _isolated_ray(world: OrisonV2RuntimeRoot, model: Node3D, part: String, start: Vector3, finish: Vector3) -> Dictionary:
	var targets:=model.find_children("*","MeshInstance3D",true,false).filter(func(draw):return str(draw.get_meta("druggist_fountain_part",""))==part)
	check(targets.size()==1,"actual installed cavity partition: "+part)
	if targets.size()!=1:return {}
	var target: CollisionObject3D=targets[0].find_children("*","CollisionShape3D",true,false)[0].get_parent()
	var exclude: Array[RID]=[]
	for body: CollisionObject3D in world.find_children("*","CollisionObject3D",true,false):
		if body!=target:exclude.append(body.get_rid())
	return world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(start,finish,1,exclude))

func _check_fountain_details(world: OrisonV2RuntimeRoot, fixture: Dictionary) -> void:
	var cell: Node3D=world.passage_region.cell_nodes.shop_otis_son;var model: Node3D=cell.get_node("DruggistFountain")
	var identity:="storm_shop_otis___son_fount"
	check(fixture.original_records.size()==5 and fixture.assemblies.size()==1,"five original unused-fountain source identities survive")
	var original: Dictionary={}
	for row: Dictionary in fixture.original_records:original[str(row.id)]=row
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		var part:=str(draw.get_meta("druggist_fountain_part"));var bounds:=draw.mesh.get_aabb()
		var low_y: float=float(draw.position.y)+float(bounds.position.y);var high_y: float=low_y+float(bounds.size.y)
		check(draw.transform.basis.is_equal_approx(Basis.IDENTITY),"native fountain fitting retains unit-scale metre geometry")
		check(draw.material_override==null,"original marble and chrome retain their own mapped finishes")
		if part.ends_with("__marble_case") or part.ends_with("__marble_top"):
			var row: Dictionary=original[identity if part.ends_with("__marble_case") else identity+"_top"];var r: Array=row.rect
			var low_x: float=float(draw.position.x)+float(bounds.position.x);var high_x: float=low_x+float(bounds.size.x)
			var low_z: float=float(draw.position.z)+float(bounds.position.z);var high_z: float=low_z+float(bounds.size.z)
			check(absf(low_x-float(r[0]))<.000003 and absf(high_x-float(r[2]))<.000003 and absf(low_z+float(r[3]))<.000003 and absf(high_z+float(r[1]))<.000003,"actual original case or counter retains its complete plan")
			check(absf(low_y-float(row.z0))<.000003 and absf(high_y-float(row.z0)-float(row.h))<.000003,"actual original case or counter retains its source base and top")
		if part.ends_with("__catch_trays"):check(absf(low_y-1.080)<.000003 and absf(high_y-1.105)<.000003,"three actual shallow trays sit on the unchanged worktop")
		for i in 3:
			if not part.ends_with("__tap"+str(i)):continue
			var row: Dictionary=original[identity+"_tap"+str(i)];var r: Array=row.rect;var c:=bounds.get_center()
			check(absf(float(draw.position.x)+float(c.x)-(float(r[0])+float(r[2]))*.5)<.000003 and absf(float(draw.position.z)+float(c.z)+(float(r[1])+float(r[3]))*.5)<.000003,"actual control retains its original source centre")
			check(absf(low_y-1.08)<.000003 and absf(high_y-1.52)<.000003,"actual tap foot and control retain their original base and maximum height")
	for i in 3:
		var row: Dictionary=original[identity+"_tap"+str(i)];var r: Array=row.rect;var cx: float=(float(r[0])+float(r[2]))*.5;var cz: float=-(float(r[1])+float(r[3]))*.5
		# Godot's segment-triangle parallel test scales with segment length.
		# A long isolated ray avoids rejecting millimetre rim/bore triangles;
		# the feature coordinates, expected hit heights and tolerances remain exact.
		var hit:=_isolated_ray(world,model,identity+"__nozzle"+str(i),cell.to_global(Vector3(cx+.160,-1.755,cz)),cell.to_global(Vector3(cx+.160,1.455,cz)))
		check(not hit.is_empty() and cell.to_local(hit.position).y>1.37 and cell.to_local(hit.position).y<1.455,"actual open nozzle mouth admits a ray to its upper curved bore")
		hit=_isolated_ray(world,model,identity+"__nozzle"+str(i),cell.to_global(Vector3(cx+.172,-1.755,cz)),cell.to_global(Vector3(cx+.172,1.290,cz)))
		check(not hit.is_empty() and absf(cell.to_local(hit.position).y-1.270)<.00003,"actual annular nozzle rim surrounds the twenty-millimetre bore")
		hit=_isolated_ray(world,model,identity+"__catch_trays",cell.to_global(Vector3(cx+.160,1.13,cz)),cell.to_global(Vector3(cx+.160,1.07,cz)))
		check(not hit.is_empty() and absf(cell.to_local(hit.position).y-1.085)<.00003,"actual open catch tray has its five-millimetre inner base")
		hit=_isolated_ray(world,model,identity+"__marble_top",cell.to_global(Vector3(cx,1.10,cz)),cell.to_global(Vector3(cx,1.02,cz)))
		check(not hit.is_empty() and absf(cell.to_local(hit.position).y-1.08)<.00003,"actual worktop seats each original control foot")
	var case: Dictionary=original[identity];var r: Array=case.rect
	for x in [float(r[0])+.018,float(r[2])-.018]:
		for z in [-float(r[1])-.08,-float(r[3])+.08]:
			var hit:=_isolated_ray(world,model,identity+"__marble_case",cell.to_global(Vector3(x,1.04,z)),cell.to_global(Vector3(x,1.01,z)))
			check(not hit.is_empty() and absf(cell.to_local(hit.position).y-1.03)<.00003,"actual cabinet end wall bears the original counter underside")

func _retail_detail_views(world: OrisonV2RuntimeRoot, fixture: Dictionary) -> void:
	if not capture_enabled:return
	var cell: Node3D=world.passage_region.cell_nodes.shop_otis_son;var r: Array=fixture.assemblies[0].floor.rect;var observations: Array=[]
	var views: Array=[["shop_context",Vector3(20.5,.03,47.10),Vector3(20.2,.80,44.95)],["front_marble",Vector3(20.2,.03,45.85),Vector3(20.2,.45,45.30)],["tap_worktop",Vector3(21.75,.03,44.9),Vector3(19.7,1.30,44.835)]]
	for i in 3:
		var row: Dictionary=fixture.original_records.filter(func(record):return str(record.id)=="storm_shop_otis___son_fount_tap"+str(i))[0];var br: Array=row.rect;var cz: float=-(float(br[1])+float(br[3]))*.5
		views.append(["nozzle"+str(i),Vector3(20.6,.03,45.70),Vector3(19.805,1.27,cz)])
	views.append(["tray_cavities",Vector3(20.6,.03,45.70),Vector3(19.805,1.088,44.835)])
	for view: Array in views:
		var preferred: Vector3=view[1];var selected:=preferred;var distance:=INF
		if not _city_clear_station(world,cell.to_global(preferred)):
			for u in range(1,25):
				for v in range(1,25):
					var at:=Vector3(lerpf(r[0],r[2],u/25.),.03,-lerpf(r[1],r[3],v/25.))
					if at.distance_squared_to(preferred)<distance and _city_clear_station(world,cell.to_global(at)):selected=at;distance=at.distance_squared_to(preferred)
		check(_city_clear_station(world,cell.to_global(selected)),"actual floor-supported fountain observation: "+str(view[0]))
		world.player.global_position=cell.to_global(selected);world.player.velocity=Vector3.ZERO
		world.player.face_world_point(cell.to_global(view[2]));world.player.set_lamp_enabled(true)
		await _settled_optics();await shot(view[0])
		observations.append({"id":view[0],"requested_feet":[preferred.x,preferred.y,preferred.z],"feet":[selected.x,selected.y,selected.z],"target":[view[2].x,view[2].y,view[2].z],"image":str(view[0])+".png"})
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("views.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","views":observations,"scope":"Standing-capsule unused-fountain observations. Actual open mouths and trays establish no dispensing, liquid, drainage, refrigeration, capacity, clinical service or continuous route."},"\t"))
