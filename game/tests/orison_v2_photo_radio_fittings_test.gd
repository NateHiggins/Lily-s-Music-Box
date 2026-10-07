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
	check(not world.startup_failed and not passage.startup_failed,"composed world fits the closed Photo fittings and Radio stand")
	check(passage.residency.state=="RESIDENT","normal prefetch exposes fitted stock geometry")
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_photo_radio_fittings.json"))
	check(FileAccess.get_sha256("res://assets/props/photo_radio_fittings.glb")==fixture.asset_sha256,"installed mesh binds the native composed furnishing export")
	var owner_rows: Array=passage.source_layout.floors.filter(func(floor):return floor.id=="F01")[0].furniture
	var parts:=0;var triangles:=0;var removed:=0;var supports:=0
	for record: Dictionary in fixture.runtime.cells:
		var cell: Node3D=passage.cell_nodes[record.id];var model: Node3D=cell.get_node("PhotoRadioFittings")
		var native_draws: Array = model.find_children("*","MeshInstance3D",true,false)
		var runtime_parts: Array = record.parts.duplicate()
		if record.id == "shop_photo_supplies":
			var lamp = passage._actors.get_node("SITE_SHOP_DARKROOM_PHOTO_SUPPLIES")
			native_draws.append_array(lamp.native_parts.values())
			runtime_parts.append_array(fixture.runtime.actor_parts)
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
		for draw: MeshInstance3D in native_draws:
			parts+=1;var count:=draw.mesh.get_faces().size()/3;triangles+=count
			var name:=str(draw.get_meta("photo_radio_fittings_part"));var expected: Dictionary=fixture.parts.filter(func(row):return row.name==name)[0]
			check(count==int(expected.triangles) and expected.cell==record.id,"each fitted partition binds exact native triangles and cell")
			_check_cap_mapping(draw.mesh,true)
			var mat: StandardMaterial3D = draw.material_override as StandardMaterial3D if str(expected.key) == "milk_glass" else draw.mesh.surface_get_material(0) as StandardMaterial3D
			check(mat!=null and not mat.uv1_triplanar and (mat.albedo_texture!=null or str(expected.key)=="glassish") and mat.roughness_texture!=null and mat.normal_texture!=null,"source optical maps reach native metre charts; drawn glass retains its literal color")
			if mat == null: continue
			var source: StandardMaterial3D
			var runtime_part: Dictionary=runtime_parts.filter(func(row):return row.name==name)[0]
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
			if not runtime_parts.any(func(part):return str(part.name).begins_with(str(contact.assembly)+"__")):continue
			var at:=_v(contact.point);var direction:=_v(contact.direction);var exclude: Array[RID]=[world.player.get_rid()]
			for draw: MeshInstance3D in native_draws:
				if str(draw.get_meta("photo_radio_fittings_part")).begins_with(str(contact.assembly)+"__"):
					for body: CollisionObject3D in draw.find_children("*","CollisionObject3D",true,false): exclude.append(body.get_rid())
			var query:=PhysicsRayQueryParameters3D.create(cell.to_global(at+direction*.004),cell.to_global(at-direction*.004),1,exclude)
			var hit:=world.get_world_3d().direct_space_state.intersect_ray(query)
			check(not hit.is_empty() and cell.to_local(hit.position).distance_to(at)<.00003,"fitted support contact: "+str(contact.label)+" / "+str(contact.owner));supports+=1
			if contact.native_owner:
				check(not hit.is_empty() and str(hit.collider.get_parent().get_meta("shop_clerestories_part","")).begins_with(str(contact.owner)+"__"),"actual native bearing reaches its declared fitted owner")
			else:
				var owner: Dictionary=owner_rows.filter(func(row):return row.id==contact.owner)[0]
				check(not hit.is_empty() and str(hit.collider.get_parent().name).trim_suffix("-col").ends_with("_"+str(owner.mat)),"actual bearing reaches its retained floor or wainscot material owner")
	check(parts==fixture.parts.size() and triangles==int(fixture.triangles) and removed==fixture.original_records.size()*12 and supports==fixture.contacts.size(),"native counts bind all original boxes, fitted furniture and wall/ceiling samples")
	_check_photo_radio_details(world,fixture)
	await _photo_radio_views(world,fixture)
	var directory:=OS.get_environment("SHOT_DIR")
	FileAccess.open(directory.path_join("photo_radio.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","checks":checks,"parts":parts,"triangles":triangles,"removed":removed,"supports":supports,"failures":failures},"\t"))
	print("PHOTO RADIO FITTINGS: checks=",checks," parts=",parts," triangles=",triangles," removed=",removed," supports=",supports," failures=",failures.size())
	return {"checks":checks,"parts":parts,"triangles":triangles,"removed":removed,"supports":supports,"failures":failures.duplicate()}

func _check_photo_radio_details(world: OrisonV2RuntimeRoot, fixture: Dictionary) -> void:
	var passage := world.passage_region
	var lamp = passage._actors.get_node("SITE_SHOP_DARKROOM_PHOTO_SUPPLIES")
	check(lamp.get_script() == preload("res://scripts/props/photo_darkroom_light.gd"), "only existing V2 Photo fixture adopts native wall body")
	var marker: Dictionary = passage.source_layout.floors.filter(func(f): return f.id == "F01")[0].markers.filter(func(m): return m.id == str(lamp.name))[0]
	check(lamp.position.is_equal_approx(GameBoot.b2g(marker.pos)) and is_equal_approx(lamp.rotation.y, deg_to_rad(-float(marker.yaw_deg))), "source actor position and yaw unchanged")
	check(lamp.prop_type == marker.kind and lamp.energy_scale == float(marker.energy) and lamp.range_clamp == float(marker.range) and lamp.standby_scale == float(marker.standby), "electrical family, energy, range and standby remain authored")
	check(lamp.native_parts.size() == fixture.runtime.actor_parts.size() and lamp.find_children("*", "OmniLight3D", true, false).size() == 2, "one native lamp retains only its existing direct and bounce owners")
	var emitter := _v(fixture.runtime.emitter)
	check(passage.to_local(lamp.light.global_position).distance_to(emitter) < .00003, "actual visible lamp contains the controlled emitter")
	check(lamp.light.light_color.r > .9 and lamp.light.light_color.g < .03 and lamp._bulb_mat.albedo_color.g < .02, "red opal source retains red glass when unlit")
	var original := LightFixtureProp.new()
	original.prop_type = "cage_bulb"
	var body := Node3D.new()
	original.add_child(body)
	check(original._build_body(body).is_equal_approx(Vector3(0.,-.5,0.)), "V1 cage family retains original emitter and procedural body")
	check(body.find_children("*", "MeshInstance3D", true, false).size() > 2, "V1 rollback retains cage construction")
	original.free()
	var hours: PassageHoursDirector = passage.finish.hours_director
	var previous_scale: float = lamp._target_scale
	var previous_bounce: bool = lamp._bounce_on
	var previous_shadow: bool = lamp.light.shadow_enabled
	lamp.set_process(false)
	hours.apply_for_minute(750.)
	lamp.set_budget(1., true, true)
	for frame in 120: lamp._process(1./60.)
	check(lamp.powered and lamp._state_gain == 1. and lamp.light.light_energy > .1 and lamp._bulb_mat.emission_energy_multiplier > .5, "trading-hours owner lights native red diffuser")
	var lens: MeshInstance3D = lamp._swing_node.get_node("bulb_darkroom")
	check(lens.material_override == lamp._bulb_mat, "native lens binds original live emission envelope")
	var before: Transform3D = lens.global_transform
	lamp._surge = .8
	lamp._process(1./60.)
	check(lens.global_transform.is_equal_approx(before), "electrical surge cannot swing bolted wall geometry")
	lamp._surge = 0.
	hours.apply_for_minute(180.)
	lamp.set_budget(1., true, true)
	for frame in 120: lamp._process(1./60.)
	check(not lamp.powered and lamp._state_gain == 0. and lamp.light.light_energy < .0001 and lamp.bounce.light_energy == 0. and lamp._bulb_mat.emission_energy_multiplier < .0001 and not lamp._halo.visible, "actual after-hours policy extinguishes direct, bounce, halo and lens")
	hours.apply_for_minute(1200.)
	lamp.set_budget(previous_scale, previous_bounce, previous_shadow)
	lamp.set_process(true)
	check(fixture.original_records.size() == 4 and fixture.assemblies.size() == 3, "four source boxes retain three assembly identities")
	# Independent physical probes reach both unchanged Radio display bearing points.
	var cell: Node3D = passage.cell_nodes.shop_radio_service
	var display: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_radio_display.json"))
	for contact: Dictionary in display.contacts:
		if contact.owner != "storm_shop_radio_service_window_plinth": continue
		var at := _v(contact.point)
		var exclude: Array[RID] = []
		for body_node: CollisionObject3D in cell.get_node("RadioDisplay").find_children("*", "CollisionObject3D", true, false): exclude.append(body_node.get_rid())
		var hit := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(cell.to_global(at+Vector3.UP*.01),cell.to_global(at-Vector3.UP*.01),1,exclude))
		check(not hit.is_empty() and cell.to_local(hit.position).distance_to(at) < .00003 and str(hit.collider.get_parent().get_meta("photo_radio_fittings_part", "")).begins_with(str(contact.owner)+"__"), "accepted Radio display bears on exact native replacement deck")

func _photo_radio_views(world: OrisonV2RuntimeRoot, fixture: Dictionary) -> void:
	var views := [
		{"id":"photo_darkroom_lit", "cell":"shop_photo_supplies", "feet":[21.1,.03,60.8], "target":[22.86,1.3,59.725]},
		{"id":"photo_red_lamp", "cell":"shop_photo_supplies", "feet":[21.6,.03,59.9], "target":[22.80,2.27,59.725]},
		{"id":"radio_window_stand", "cell":"shop_radio_service", "feet":[15.6,.03,57.95], "target":[17.4,.55,57.95]},
		{"id":"radio_framed_back", "cell":"shop_radio_service", "feet":[18.75,.03,56.85], "target":[17.55,.95,57.92]}]
	var observations: Array = []
	for view: Dictionary in views:
		var cell: Node3D = world.passage_region.cell_nodes[view.cell]
		var selected := _v(view.feet)
		var target := _v(view.target)
		if not _city_clear_station(world,cell.to_global(selected)):
			var assembly: Dictionary = fixture.assemblies.filter(func(a):return a.cell == view.cell)[0]
			var rect: Array = assembly.floor.rect
			var distance := INF
			for u in range(1,25):
				for v in range(1,25):
					var at := Vector3(lerpf(rect[0],rect[2],u/25.),.03,-lerpf(rect[1],rect[3],v/25.))
					if at.distance_squared_to(_v(view.feet)) < distance and _city_clear_station(world,cell.to_global(at)):
						selected = at; distance = at.distance_squared_to(_v(view.feet))
		check(_city_clear_station(world,cell.to_global(selected)), "floor and capsule-supported observation: "+str(view.id))
		world.player.global_position = cell.to_global(selected)
		world.player.velocity = Vector3.ZERO
		world.player.face_world_point(cell.to_global(target))
		world.player.set_lamp_enabled(false)
		if capture_enabled:
			await _settled_optics(); await shot(str(view.id))
			if view.id == "photo_red_lamp":
				world.passage_region.finish.hours_director.apply_for_minute(180.)
				await _settled_optics(); await shot("photo_red_lamp_after_hours")
				world.passage_region.finish.hours_director.apply_for_minute(1200.)
		observations.append({"id":view.id, "feet":[selected.x,selected.y,selected.z], "target":view.target})
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("views.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","views":observations},"\t"))

