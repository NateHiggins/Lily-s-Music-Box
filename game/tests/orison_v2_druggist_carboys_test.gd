extends "res://tests/orison_v2_city_sweep.gd"
## Actual retained shop boundaries, fitted supports, imported charts and standing detail views.
func _run() -> void:
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928,11,10,20*60);GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var world:=_world_scene().instantiate() as OrisonV2RuntimeRoot;add_child(world)
	await get_tree().physics_frame;await get_tree().physics_frame
	check(not world.startup_failed and not world.passage_region.startup_failed,"four original display carboys fit the Otis & Son shop")
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
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_druggist_carboys.json"))
	var installed: bool=passage.cell_nodes.has("shop_otis_son") and passage.cell_nodes.shop_otis_son.has_node("DruggistCarboys")
	check(installed,"actual retained druggist cell and drawer fitting exist before their contracts")
	if not installed:world.shutdown_for_tests();world.free();get_tree().quit(1);return
	check(FileAccess.get_sha256("res://assets/props/druggist_carboys.glb")==fixture.asset_sha256,"installed mesh binds the native display-carboy export")
	var parts:=0;var triangles:=0;var removed:=0;var supports:=0
	for record: Dictionary in fixture.runtime.cells:
		var cell: Node3D=passage.cell_nodes[record.id];var model: Node3D=cell.get_node("DruggistCarboys")
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
			if draw.has_meta(&"lamp_optical_receiver"):continue
			parts+=1;var count:=draw.mesh.get_faces().size()/3;triangles+=count
			var name:=str(draw.get_meta("druggist_carboys_part"));var expected: Dictionary=fixture.parts.filter(func(row):return row.name==name)[0]
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
				if draw!=null and str(draw.get_meta("druggist_carboys_part")).begins_with(str(contact.assembly)+"__"):exclude.append(body.get_rid())
			var query:=PhysicsRayQueryParameters3D.create(cell.to_global(at+direction*.004),cell.to_global(at-direction*.004),1,exclude)
			var hit:=world.get_world_3d().direct_space_state.intersect_ray(query)
			check(not hit.is_empty() and cell.to_local(hit.position).distance_to(at)<.00003,"fitted support contact: "+str(contact.label)+" / "+str(contact.owner));supports+=1
	check(parts==fixture.parts.size() and triangles==int(fixture.triangles) and removed==fixture.original_records.size()*12 and supports==fixture.contacts.size(),"native counts bind all original boxes, fitted furniture and floor samples")
	_check_carboy_details(world,fixture)
	await _retail_detail_views(world,fixture)
	var directory:=OS.get_environment("SHOT_DIR")
	FileAccess.open(directory.path_join("fittings.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","checks":checks,"parts":parts,"triangles":triangles,"removed":removed,"supports":supports,"failures":failures},"\t"))
	print("DRUGGIST CARBOYS: checks=",checks," parts=",parts," triangles=",triangles," removed=",removed," supports=",supports," failures=",failures.size())
	world.shutdown_for_tests();world.free();await _retired_audio();get_tree().quit(0 if failures.is_empty() else 1)

func _isolated_ray(world: OrisonV2RuntimeRoot, model: Node3D, part: String, start: Vector3, finish: Vector3) -> Dictionary:
	var targets:=model.find_children("*","MeshInstance3D",true,false).filter(func(draw):return str(draw.get_meta("druggist_carboys_part",""))==part)
	check(targets.size()==1,"actual installed cavity partition: "+part)
	if targets.size()!=1:return {}
	var target: CollisionObject3D=targets[0].find_children("*","CollisionShape3D",true,false)[0].get_parent()
	var exclude: Array[RID]=[]
	for body: CollisionObject3D in world.find_children("*","CollisionObject3D",true,false):
		if body!=target:exclude.append(body.get_rid())
	return world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(start,finish,1,exclude))

func _check_carboy_details(world: OrisonV2RuntimeRoot, fixture: Dictionary) -> void:
	var cell: Node3D=world.passage_region.cell_nodes.shop_otis_son;var model: Node3D=cell.get_node("DruggistCarboys")
	var prefix:="storm_shop_otis___son_"
	check(fixture.original_records.size()==14 and fixture.assemblies.size()==6,"twelve original hero identities and both original window-display furniture identities survive")
	var original: Dictionary={}
	for floor: Dictionary in world.passage_region.source_layout.floors:
		if str(floor.id)!="F01":continue
		for row: Dictionary in floor.furniture:original[str(row.id)]=row
	var shells:=0;var stoppers:=0;var fills:=0;var pedestals:=0;var optics:=0
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		if draw.has_meta(&"lamp_optical_receiver"):continue
		var part:=str(draw.get_meta("druggist_carboys_part"));var bounds:=draw.mesh.get_aabb()
		check(draw.transform.basis.is_equal_approx(Basis.IDENTITY),"native carboy partition retains unit-scale metre geometry")
		var low_y: float=float(draw.position.y)+float(bounds.position.y);var high_y: float=low_y+float(bounds.size.y)
		if part.begins_with(prefix+"window_"):
			var low_x: float=float(draw.position.x)+float(bounds.position.x);var high_x: float=low_x+float(bounds.size.x)
			if part.ends_with("window_back__plywood"):
				check(absf(low_x-17.655)<.000003 and absf(high_x-17.695)<.000003 and absf(low_y-.625)<.000003 and absf(high_y-1.57)<.000003,"actual furniture backing clears the original bottle envelope and pedestal seats")
			elif part.ends_with("window_back__wood_dark"):
				check(absf(low_x-17.67)<.000003 and absf(high_x-17.70)<.000003 and absf(low_y-.01)<.000003 and absf(high_y-1.57)<.000003,"actual end stiles support the backing from its original floor")
			else:
				check(absf(low_x-17.18)<.000003 and absf(high_x-17.54)<.000003 and absf(low_y-.01)<.000003 and absf(high_y-.44)<.000003,"open plinth frame retains its original plan and top while reaching the floor")
			continue
		check(low_y>=.01-.000003 and high_y<=1.56+.000003,"actual display fitting retains its floor and original maximum stopper height")
		if part.ends_with("__glassish_shell"):
			optics+=1;var glass:=draw.material_override as ShaderMaterial
			check(glass!=null and glass.shader.resource_path=="res://shaders/lamp_glass_surface.gdshader" and is_equal_approx(float(glass.get_shader_parameter("surface_roughness")),.06),"clear shell uses the unchanged existing optical owner")
			check(draw.get_meta("glazing_source_surface")==draw.mesh.surface_get_material(0),"original mapped glass remains beneath its bounded optical override")
			check(draw.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"clear shell does not cast an opaque engine shadow onto its display fill")
			var haze:=draw.get_node("LampGlassHaze") as MeshInstance3D
			check(haze!=null and haze.has_meta(&"lamp_optical_receiver") and haze.mesh==draw.mesh and haze.transform.is_equal_approx(Transform3D.IDENTITY),"existing lamp haze shares the actual glass surface and pose")
			check(haze.layers==preload("res://scripts/lamp/lamp_optical_receivers.gd").LAYER and haze.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and haze.find_children("*","CollisionShape3D",true,false).is_empty(),"optical receiver has only its reserved light layer and adds no physical geometry")
			var haze_material:=haze.material_override as ShaderMaterial
			check(haze_material.shader.resource_path=="res://shaders/lamp_optical_glass_haze.gdshader" and is_equal_approx(float(haze_material.get_shader_parameter("thickness_m")),.012),"unchanged haze owner retains actual shell-wall thickness")
		if part.ends_with("__glassish_shell"):
			shells+=1;var identity:=part.trim_suffix("__glassish_shell")
			check(original.has(identity),"complete display body identity resolves its retained source")
			if not original.has(identity):continue
			var row: Dictionary=original[identity];var r: Array=row.rect;var centre:=bounds.get_center()
			var cx: float=float(draw.position.x)+float(centre.x);var cz: float=float(draw.position.z)+float(centre.z)
			check(absf(cx-(float(r[0])+float(r[2]))*.5)<.000003 and absf(cz+(float(r[1])+float(r[3]))*.5)<.000003,"actual hollow carboy retains its original display centre")
			check(absf(low_y-.62)<.000003 and absf(high_y-1.34)<.000003 and absf(bounds.size.x-.34)<.000003,"actual shell retains original base, body height and display diameter")

		if part.ends_with("__glassish_stopper"):
			stoppers+=1;check(absf(low_y-1.32)<.000003 and absf(high_y-1.56)<.000003,"separate actual opal stopper inserts twenty millimetres while keeping its original maximum height")
			var stopper:=draw.mesh.surface_get_material(0) as StandardMaterial3D
			check(draw.material_override==null and stopper.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED and stopper.albedo_texture==MatLib.get_mat("milk_glass").albedo_texture,"opaque opal stopper retains its declared existing catalogue owner")
		if "__fill" in part:
			fills+=1;check(absf(low_y-.636)<.000003 and absf(high_y-1.066)<.000003 and bounds.size.x<.316,"bounded static display fill fits inside the hollow glass base and wall")
		if part.ends_with("__wood_dark"):pedestals+=1;check(absf(low_y-.01)<.000003 and absf(high_y-.62)<.000003,"fabricated pedestal bridges actual floor and retained body seat")
	check(shells==4 and stoppers==4 and fills==4 and pedestals==4,"four actual shell, stopper, display-fill and pedestal partitions are present")
	check(optics==4,"all four clear shells have their bounded optical owner")
	for i in 4:
		var identity:=prefix+"carboy"+str(i);var row: Dictionary=original[identity];var r: Array=row.rect
		var cx: float=(float(r[0])+float(r[2]))*.5;var cz: float=-(float(r[1])+float(r[3]))*.5
		var hit:=_isolated_ray(world,model,identity+"__glassish_shell",cell.to_global(Vector3(cx,1.57,cz)),cell.to_global(Vector3(cx,.60,cz)))
		check(not hit.is_empty() and absf(cell.to_local(hit.position).y-.636)<.00003,"isolated open carboy neck reaches the actual sixteen-millimetre glass inner base")
		hit=_isolated_ray(world,model,identity+"__glassish_stopper",cell.to_global(Vector3(cx,1.60,cz)),cell.to_global(Vector3(cx,1.30,cz)))
		check(not hit.is_empty() and absf(cell.to_local(hit.position).y-1.56)<.00003,"actual separate stopper has the retained top face")
		hit=_isolated_ray(world,model,identity+"__fill"+str(i),cell.to_global(Vector3(cx,1.20,cz)),cell.to_global(Vector3(cx,.62,cz)))
		check(not hit.is_empty() and absf(cell.to_local(hit.position).y-1.066)<.00003,"actual bounded display volume has its static top face inside the shell")
		hit=_isolated_ray(world,model,identity+"__wood_dark",cell.to_global(Vector3(cx,.64,cz)),cell.to_global(Vector3(cx,.54,cz)))
		check(not hit.is_empty() and absf(cell.to_local(hit.position).y-.62)<.00003,"actual pedestal top meets the unchanged vessel base")

func _retail_detail_views(world: OrisonV2RuntimeRoot, fixture: Dictionary) -> void:
	var cell: Node3D=world.passage_region.cell_nodes.shop_otis_son
	var r: Array=fixture.assemblies[0].floor.rect;var observations: Array=[]
	var views: Array=[["display_bay",Vector3(16.25,.03,47.25),Vector3(17.47,1.10,47.40)],["pedestal_feet",Vector3(16.35,.03,47.75),Vector3(17.47,.27,47.67)],["shop_context",Vector3(20.10,.03,47.20),Vector3(17.67,1.0,47.40)]]
	for i in 4:
		var row: Dictionary=fixture.original_records.filter(func(record):return str(record.id)=="storm_shop_otis___son_carboy"+str(i))[0];var br: Array=row.rect;var cz: float=-(float(br[1])+float(br[3]))*.5
		views.append(["carboy"+str(i),Vector3(16.35,.03,cz),Vector3(17.47,1.12,cz)])
	for view: Array in views:
		var preferred: Vector3=view[1];var selected:=preferred;var distance:=INF
		var search: Array=r if view[0]=="shop_context" else [15.5,-48.6,16.65,-44.5]
		if not _city_clear_station(world,cell.to_global(preferred)):
			for u in range(1,25):
				for v in range(1,25):
					var at:=Vector3(lerpf(search[0],search[2],u/25.),.03,-lerpf(search[1],search[3],v/25.))
					if at.distance_squared_to(preferred)<distance and _city_clear_station(world,cell.to_global(at)):
						selected=at;distance=at.distance_squared_to(preferred)
		check(_city_clear_station(world,cell.to_global(selected)),"actual floor-supported display-carboy observation: "+str(view[0]))
		world.player.global_position=cell.to_global(selected);world.player.velocity=Vector3.ZERO
		world.player.face_world_point(cell.to_global(view[2]));world.player.set_lamp_enabled(true)
		await _settled_optics()
		if view[0]=="display_bay" and RenderingServer.get_rendering_device()!=null:
			var atmosphere:=world.get_node("LampAtmosphere")
			var model: Node3D=cell.get_node("DruggistCarboys")
			for receiver: MeshInstance3D in model.find_children("LampGlassHaze","MeshInstance3D",true,false):
				var receiver_material:=receiver.material_override as ShaderMaterial
				check(receiver.visible and atmosphere.receivers.receivers.has(receiver.get_instance_id()) and receiver_material.get_shader_parameter("lamp_optical_bound")==true,"existing optical owner binds each live shell receiver")
		await shot(view[0])
		observations.append({"id":view[0],"lamp_enabled":true,"requested_feet":[preferred.x,preferred.y,preferred.z],"feet":[selected.x,selected.y,selected.z],"target":[view[2].x,view[2].y,view[2].z],"image":str(view[0])+".png"})
		if view[0]=="display_bay":
			world.player.set_lamp_enabled(false);await _settled_optics();await shot("display_bay_shop_light")
			observations.append({"id":"display_bay_shop_light","lamp_enabled":false,"requested_feet":[preferred.x,preferred.y,preferred.z],"feet":[selected.x,selected.y,selected.z],"target":[view[2].x,view[2].y,view[2].z],"image":"display_bay_shop_light.png"})
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("views.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","views":observations,"scope":"Standing-capsule display-carboy observations. Opaque bounded display-fill volumes have no liquid simulation, chemistry or medical owner. Fountain, custody, continuous routes and independent services retain separate authority."},"\t"))
