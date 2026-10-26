extends "res://tests/orison_v2_floor_surface_test.gd"
## Exhaustive loaded geometry discovery. Findings remain failures, never exemptions.
var mesh_rows: Dictionary = {}
var material_rows: Dictionary = {}
var texture_rows: Dictionary = {}
var draws: Array = []
var unhandled_geometry: Array = []
var shader_filter_cache := {}

func _run() -> void:
	var started := Time.get_ticks_msec()
	var directory := OS.get_environment("SHOT_DIR")
	if directory.is_empty() or DirAccess.make_dir_recursive_absolute(directory) != OK or DisplayServer.get_name() == "headless":
		push_error("Surface qualification requires writable SHOT_DIR and -Windowed")
		get_tree().quit(1)
		return
	var root := ProjectSettings.globalize_path("res://..").simplify_path()
	var binding_args: Array[String]=[root.path_join("tools/preflight_spatial_test_bindings.py"),"--root",root]
	for fixture: String in ["orison_bodega_frontage.json","orison_city_closure.json","orison_city_elevations.json","orison_city_ground_apron.json","orison_city_horizon.json","orison_front_pavement_construction.json","orison_front_pavement_review.json","orison_street_paving_details.json","passage_shop_leaves.json"]:
		binding_args.append_array(["--fixture","game/tests/fixtures/"+fixture])
	var binding_output: Array=[]
	if OS.execute("python",binding_args,binding_output)!=0:
		push_error("Native fixture source preflight failed before world composition: "+str(binding_output))
		get_tree().quit(1);return
	var before := _input_snapshot(root)
	if before.is_empty(): get_tree().quit(1); return
	var shared_uv_defaults: Array = []
	var finish_review := preload("res://tests/v2_control_finish_review.gd").new()
	finish_review.validate_material_contract(self)
	if not failures.is_empty():
		# An invalid material ABI cannot qualify a world. Fail before its costly build.
		get_tree().quit(1);return
	for key in ["metal","wood_dark","timber","cast_iron","paper"]:
		var stock := MatLib.get_mat(key) as StandardMaterial3D
		shared_uv_defaults.append({"stock":stock,"uv1":stock.uv1_triplanar,"uv2":stock.uv2_triplanar})
	var frontage_stock := MatLib.get_mat("oak_quartered",Color(.42,.30,.20),.8)
	shared_uv_defaults.append({"stock":frontage_stock,"uv1":frontage_stock.uv1_triplanar,"uv2":frontage_stock.uv2_triplanar})
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	# Seasonal renders deliberately visit four dates; gameplay clock proof is separate.
	CampaignTime.set_frozen_for_tests(true)
	CampaignClock.new().configure_date(1928,10,15,750)
	GameBoot.launch_mode = GameBoot.LaunchMode.CINEMATIC
	var world := _world_scene().instantiate() as OrisonV2RuntimeRoot
	if world == null:
		push_error("Surface world failed to instantiate")
		get_tree().quit(1)
		return
	add_child(world)
	await get_tree().physics_frame
	await get_tree().physics_frame
	if world.player == null or world.startup_failed:
		get_tree().quit(1)
		return
	world.player.set_physics_process(false)
	# The world builds synchronously; give passive parts actual physics ticks
	# before taking snapshots that are expected to remain supported on restore.
	for frame in 40:await get_tree().physics_frame
	# Validate the changed hand/stock family in this same production world
	# alongside the remaining surface programmes.
	var fire_review := preload("res://tests/v2_fire_service_review.gd").new()
	await fire_review.run(world,self)
	# Retain every fire failure, but collect the remaining world surfaces in
	# this same run. A failed fitting must not suppress the defect inventory.
	if OS.get_environment("ORISON_SURFACE_FIRE_ONLY")=="1":
		world.shutdown_for_tests();world.free()
		for frame in 4:await RenderingServer.frame_post_draw
		fire_review.after_teardown(self)
		print("V2 FIRE PREFLIGHT: ","PASS" if failures.is_empty() else "FAIL"," checks=",batch_checks," failures=",failures.size(),"; fire-only scope, not full surface acceptance")
		get_tree().quit(0 if failures.is_empty() else 1);return
	await preload("res://tests/v2_city_elevation_review.gd").new().run(world,self)
	var furnishing_review := preload("res://tests/v2_furnishing_clearance_review.gd").new()
	furnishing_review.set_meta("shared_world_validation",true);add_child(furnishing_review)
	await furnishing_review.validate_in_world(world)
	batch_checks+=furnishing_review.batch_checks
	for failure: String in furnishing_review.failures:failures.append(failure)
	furnishing_review.free()
	var front_review := preload("res://tests/v2_front_restoration_review.gd").new()
	add_child(front_review)
	await front_review.run(world,self)
	front_review.free()
	var pavement_review := preload("res://tests/orison_v2_front_pavement_test.gd").new()
	pavement_review.batch_mode=true;pavement_review.capture_enabled=true;add_child(pavement_review)
	var pavement_result: Dictionary=await pavement_review.validate_in_world(world)
	if not pavement_result.has_all(["checks","failures"]):
		check(false,"pavement validation aborted without a complete result")
		world.shutdown_for_tests();world.free();get_tree().quit(1);return
	batch_checks+=int(pavement_result.checks)
	for failure: String in pavement_result.failures:failures.append(failure)
	pavement_review.free()
	var street_pose:=world.player.global_transform;var street_camera:=world.player.camera.transform
	var paving_review := preload("res://tests/orison_v2_street_paving_details_test.gd").new()
	paving_review.batch_mode=true;paving_review.capture_enabled=true;add_child(paving_review)
	var paving_result: Dictionary=await paving_review.validate_in_world(world)
	if not paving_result.has_all(["checks","failures"]):
		check(false,"street validation aborted without a complete result")
		world.shutdown_for_tests();world.free();get_tree().quit(1);return
	batch_checks+=int(paving_result.checks)
	for failure: String in paving_result.failures:failures.append(failure)
	paving_review.free()
	world.player.global_transform=street_pose;world.player.camera.transform=street_camera;world.player.velocity=Vector3.ZERO
	var public_review := preload("res://tests/public_region_walk_probe.gd").new()
	public_review.externally_managed=true;add_child(public_review)
	await public_review.run(world,self)
	public_review.free()
	var construction_review := preload("res://tests/v2_construction_shed_review.gd").new()
	add_child(construction_review)
	await construction_review.run(world,self)
	construction_review.free()
	var street_review := preload("res://tests/v2_street_optics_probe.gd").new()
	street_review.externally_managed=true;add_child(street_review)
	await street_review.run(world,self)
	street_review.free()
	var glazing_review := preload("res://tests/v2_glazing_optical_probe.gd").new()
	glazing_review.externally_managed=true;add_child(glazing_review)
	await glazing_review.run(world,self)
	glazing_review.free()
	var arcade_review := preload("res://tests/v2_arcade_fabric_review.gd").new()
	add_child(arcade_review)
	await arcade_review.run(world,self)
	arcade_review.free()
	var bodega_frontage := preload("res://tests/orison_v2_bodega_frontage_test.gd").new()
	bodega_frontage.batch_mode=true;bodega_frontage.capture_enabled=false;add_child(bodega_frontage)
	var bodega_result: Dictionary=await bodega_frontage.validate_in_world(world)
	batch_checks+=int(bodega_result.checks)
	for failure: String in bodega_result.failures:failures.append(failure)
	bodega_frontage.free()
	var sign_review := preload("res://tests/orison_v2_signage_test.gd").new()
	sign_review.capture_enabled=false;add_child(sign_review)
	var sign_result: Dictionary=await sign_review.validate_in_world(world)
	batch_checks+=int(sign_result.checks)
	for failure: String in sign_result.failures:failures.append(failure)
	var bedding_review := preload("res://tests/orison_v2_bedding_test.gd").new()
	bedding_review.batch_mode=true;add_child(bedding_review)
	var bedding_result: Dictionary=await bedding_review.validate_in_world(world)
	batch_checks+=int(bedding_result.checks)
	for failure: String in bedding_result.failures:failures.append(failure)
	bedding_review.free()
	var fixed_review := preload("res://tests/orison_v2_fixed_lighting_test.gd").new()
	fixed_review.capture_enabled=false; add_child(fixed_review)
	var fixed_result: Dictionary=await fixed_review.validate_in_world(world)
	batch_checks+=int(fixed_result.checks)
	for failure: String in fixed_result.failures:failures.append(failure)
	var patrol := preload("res://tests/orison_v2_patrol_stations_test.gd").new()
	patrol.set_meta("shared_world_validation",true);add_child(patrol)
	await patrol.validate_in_world(world)
	batch_checks+=patrol.batch_checks
	for failure: String in patrol.failures:failures.append(failure)
	patrol.free()
	var entrance_review := preload("res://tests/orison_v2_front_facade_test.gd").new()
	entrance_review.set_meta("shared_world_validation",true)
	entrance_review.capture_prefix="entrance_";add_child(entrance_review)
	var entrance_result: Dictionary=await entrance_review.validate_in_world(world)
	batch_checks+=int(entrance_result.checks)
	for failure: String in entrance_result.failures:failures.append(failure)
	entrance_review.free()
	await preload("res://tests/v2_kitchen_sink_review.gd").new().run(world,self)
	await preload("res://tests/v2_bathroom_tile_review.gd").new().run(world,self)
	await preload("res://tests/v2_watch_stations_review.gd").new().run(world,self)
	await preload("res://tests/v2_window_treatments_review.gd").new().run(world,self)
	await preload("res://tests/v2_millwork_weather_review.gd").new().run(world,self)
	await preload("res://tests/v2_mail_bank_review.gd").new().run(world,self)
	var media_review := preload("res://tests/v2_active_media_review.gd").new()
	add_child(media_review)
	var media_result: Dictionary = await media_review.validate_in_world(world)
	batch_checks += int(media_result.checks)
	for failure: String in media_result.failures: failures.append(failure)
	# Reuse this production world for changed instrument geometry and its
	# retained service owners, then measure retirement after the same audit.
	var electrical_review := preload("res://tests/v2_electrical_service_review.gd").new()
	await electrical_review.run(world,self)
	var connections_review := preload("res://tests/v2_electrical_connections_review.gd").new()
	await connections_review.run(world,self)
	var domestic_review := preload("res://tests/orison_v2_domestic_objects_test.gd").new()
	domestic_review.capture_enabled=false;add_child(domestic_review)
	var domestic_result: Dictionary=await domestic_review.validate_in_world(world)
	batch_checks+=int(domestic_result.checks)
	for failure: String in domestic_result.failures:failures.append(failure)
	# Inspect all shared seating copies and capture the five native variants
	# inside this already-loaded production world rather than booting another.
	var seating_review := preload("res://tests/orison_v2_domestic_seating_test.gd").new()
	add_child(seating_review)
	var seating_result: Dictionary=await seating_review.validate_in_world(world)
	batch_checks+=int(seating_result.checks)
	for failure: String in seating_result.failures:failures.append(failure)
	var storage_review := preload("res://tests/orison_v2_domestic_storage_test.gd").new()
	storage_review.capture_enabled=false;add_child(storage_review)
	var storage_result: Dictionary=await storage_review.validate_in_world(world)
	batch_checks+=int(storage_result.checks)
	for failure: String in storage_result.failures:failures.append(failure)
	var instruments := preload("res://tests/orison_v2_service_instruments_test.gd").new()
	instruments.capture_enabled = false
	add_child(instruments)
	var instrument_result: Dictionary = await instruments.validate_in_world(world)
	batch_checks += int(instrument_result.checks)
	for failure: String in instrument_result.failures: failures.append(failure)
	world.player.global_position = world.adapter.root.to_global(Vector3(-4., .02, -5.))
	for frame in 600:
		if world.passage_region.residency.state == "RESIDENT": break
		await get_tree().process_frame
	# The owner retired playable cabinets. Inspect their exact source retirement
	# in this world; historical embedded-game qualifications remain historical.
	var retirement_review := preload("res://tests/v2_arcade_retirement_review.gd").new()
	retirement_review.batch_mode=true;add_child(retirement_review)
	var retirement_result: Dictionary=await retirement_review.validate_in_world(world)
	if not retirement_result.has_all(["checks","failures"]):
		check(false,"retirement validation aborted without a complete result")
		world.shutdown_for_tests();world.free();get_tree().quit(1);return
	batch_checks+=int(retirement_result.checks)
	for failure: String in retirement_result.failures:failures.append(failure)
	check(int(retirement_result.checks)>900,"surface review executes the complete current cabinet-retirement validator")
	retirement_review.free()
	await get_tree().process_frame; await get_tree().process_frame
	# The encounter is normally dormant. Qualify its actual loaded physical
	# anatomy in this composed world rather than silently omitting it.
	var gang_target := world.find_child(ServiceRoundDirector.RADIATOR_ID,true,false) as RadiatorProp
	check(gang_target != null,"tentacle surface fixture resolves installed radiator")
	var surface_gang := preload("res://scripts/dream/entity/maintenance_tentacle_gang.gd").new()
	world.add_child(surface_gang)
	var gang_at := gang_target.to_global(Vector3(0,-gang_target.installation_drop,-.5))
	check(surface_gang.start(gang_target,world.player,Transform3D(Basis.IDENTITY,gang_at),34,world.get_node("LampAtmosphere").field),"seven-limb physical surface scope starts")
	surface_gang.phase=surface_gang.Phase.INTERFERING
	surface_gang._process(0)
	surface_gang.set_process(false);surface_gang.set_physics_process(false)
	var gang_camera_pose := world.player.camera.global_transform
	world.player.camera.global_position=gang_target.to_global(Vector3(0,.35,-1.6))
	world.player.camera.look_at(gang_at+Vector3.UP*.35)
	world.player.camera.make_current()
	for frame in 3:await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join("tentacle_installed_surfaces.png"))
	surface_gang._make_haze()
	surface_gang._set_phase(surface_gang.Phase.COORDINATED_RETREAT)
	surface_gang._process(2.0)
	for frame in 3:await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join("tentacle_flowing_residue.png"))
	world.player.camera.global_transform=gang_camera_pose
	for node: Node in world.find_children("*", "GeometryInstance3D", true, false):
		if node is Label3D: continue # Separately authored lettering, RUL-008.
		if not node is MeshInstance3D and not node is MultiMeshInstance3D and not node is GPUParticles3D and not node is CPUParticles3D:
			unhandled_geometry.append({"path":str(world.get_path_to(node)),"type":node.get_class()})
			continue
		var mesh: Mesh
		var instances := 1
		if node is MeshInstance3D: mesh = node.mesh
		elif node is CPUParticles3D:
			mesh = node.mesh
			instances = node.amount
		elif node is GPUParticles3D:
			if node.draw_passes != 1:
				unhandled_geometry.append({"path":str(world.get_path_to(node)),"type":"unscanned particle draw passes"})
				continue
			mesh = node.draw_pass_1
			instances = node.amount
		elif node is MultiMeshInstance3D and node.multimesh != null:
			mesh = node.multimesh.mesh
			instances = node.multimesh.instance_count
		if mesh == null: continue
		var mesh_id := str(mesh.get_instance_id())
		if not mesh_rows.has(mesh_id): mesh_rows[mesh_id] = _mesh(mesh)
		var slots: Array = []
		for surface in mesh.get_surface_count():
			var material: Material = node.material_override
			if material == null and node is MeshInstance3D: material = node.get_active_material(surface)
			if material == null: material = mesh.surface_get_material(surface)
			var material_id := "none" if material == null else str(material.get_instance_id())
			if material != null and not material_rows.has(material_id): material_rows[material_id] = _material(material)
			slots.append(material_id)
		var owner: Node = node
		while owner != world and owner.get_script() == null: owner = owner.get_parent()
		draws.append({"path":str(world.get_path_to(node)), "owner":str(world.get_path_to(owner)), "owner_script":owner.get_script().resource_path if owner.get_script() != null else "", "visible":node.is_visible_in_tree(), "mesh":mesh_id, "materials":slots, "instances":instances, "surface_role":str(node.get_meta("surface_role", "physical")), "retired_surface":str(node.get_meta("retired_surface", "")), "geometry_transparency":node.transparency})
		if node.material_overlay != null:
			var overlay_key := str(node.material_overlay.get_instance_id())
			if not material_rows.has(overlay_key): material_rows[overlay_key] = _material(node.material_overlay)
			var overlay_draw: Dictionary = draws.back().duplicate()
			overlay_draw.path += "/material_overlay"
			overlay_draw.materials = []
			for index in mesh.get_surface_count(): overlay_draw.materials.append(overlay_key)
			draws.append(overlay_draw)
	if directory.is_empty() or DirAccess.make_dir_recursive_absolute(directory) != OK:
		push_error("Surface inventory requires a writable SHOT_DIR")
		world.shutdown_for_tests()
		world.free()
		get_tree().quit(1)
		return
	var report := {"schema":"orison.v2-surface-inventory.v1", "evidence_class":"INERT", "acceptance":"Inventory; acceptance requires passing runtime contract and reviewed renders.", "coverage":{"production_world":true,"space_count":world.layout.spaces.size(),"resident_cells":world.passage_region.cell_nodes.size()}, "passage_state":world.passage_region.residency.state, "draws":draws, "meshes":mesh_rows, "materials":material_rows, "textures":texture_rows,"unhandled_geometry":unhandled_geometry}
	var file := FileAccess.open(directory.path_join("surface-inventory.json"), FileAccess.WRITE)
	if file == null:
		push_error("Cannot write surface inventory")
		world.shutdown_for_tests()
		world.free()
		get_tree().quit(1)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	var audit_output: Array = []
	check(OS.execute("python",[root.path_join("tools/audit_v2_surfaces.py"),"--inventory",directory.path_join("surface-inventory.json"),"--out",directory.path_join("technical_findings.json")],audit_output)==0,"all loaded surfaces satisfy UV/PBR/mip/filter requirements")
	for line in audit_output: print(str(line).strip_edges())
	_validate_native_controls(world)
	print("SURFACE INVENTORY: draws=", draws.size(), " meshes=",mesh_rows.size()," materials=",material_rows.size()," textures=",texture_rows.size())
	surface_gang.cleanup();surface_gang.queue_free()
	# Reuse this composed world for representative appearance checks.
	for child in world.player.carried_device.get_children():
		if child is CanvasLayer: child.hide()
	for room_id in ["F02_A_MAIN", "F03_B_MAIN", "F04_C_MAIN"]:
		for record: Dictionary in world.layout.spaces:
			if str(record.id) != room_id: continue
			var r: Array = record.rect
			var y: float = world.adapter.root.level_y[record.level]
			world.player.global_position = world.adapter.root.to_global(Vector3((r[0]+r[2])*.5,y+.05,r[1]+.65))
			world.player.camera.make_current()
			world.player.face_world_point(world.adapter.root.to_global(Vector3((r[0]+r[2])*.5,y+1.0,(r[1]+r[3])*.5)))
			await shot(room_id)
	# Recheck the two measured clipping defects using clear physical stances.
	var room_survey:=preload("res://tests/v2_area_survey.gd").new()
	for identity: String in ["F03_B_BATH","F06_B_KITCHEN"]:
		for record: Dictionary in world.layout.spaces:
			if str(record.id)!=identity:continue
			var stance: Dictionary=room_survey._stance(world,world.adapter.root,record.rect,world.adapter.root.level_y[record.level])
			check(not stance.is_empty(),"glare review retains an actual capsule-clear stance: "+identity)
			if stance.is_empty():continue
			world.player.global_position=Vector3(stance.feet[0],stance.feet[1],stance.feet[2])
			world.player.global_rotation=Vector3(0,world.adapter.root.global_rotation.y,0);world.player.camera.rotation=Vector3(-.08,0,0)
			for frame in 90:await RenderingServer.frame_post_draw
			var reflection_owner: Node=world.get_node("V2RoomReflections")
			check(reflection_owner.probes.has(identity),"glare review uses the actual bounded room probe: "+identity)
			if reflection_owner.probes.has(identity):
				check(reflection_owner.probes[identity].ambient_mode==ReflectionProbe.AMBIENT_DISABLED,"room probe does not duplicate diffuse radiance: "+identity)
			await shot(identity+"_reflection_repair")
	room_survey.free()
	# A fixed review camera avoids controller, head-motion and lens framing.
	var review_camera := Camera3D.new()
	review_camera.fov = world.player.camera.fov
	review_camera.attributes = world.player.camera.attributes
	review_camera.cull_mask = world.player.camera.cull_mask
	world.add_child(review_camera)
	for station in [
		["B1_FUSE_PANEL",Vector3(.35,.7,1.25),Vector3(0,.6,.1),"fuse_panel"],
		["LobbyMailBank",Vector3(.35,1.,-1.5),Vector3(0,.9,-.1),"mail_bank"],
		["B1_WATCH_STATION",Vector3(.2,.25,.7),Vector3(0,.16,.09),"watch_station"],
		["F04_4A_BOOKSHELF_01",Vector3(.35,.85,1.6),Vector3(0,.8,.15),"bookcase"],
		["F02_B_RADIATOR_01",Vector3(.35,.65,-1.1),Vector3(0,.48,0),"radiator"],
		["B1_BOILER_01",Vector3(.6,1.45,-2.15),Vector3(0,1.,0),"boiler"],
		["F04_B_MONITOR_01",Vector3(.35,.8,-1.3),Vector3(0,.3,-.2),"signal_terminal"],
		["F02_2A_TOASTER_01",Vector3(.25,.35,-.65),Vector3(0,.1,0),"toaster_crumbs"],
		["LobbyServiceDumbwaiter",Vector3(.65,1.,1.7),Vector3(0,1.,0),"dumbwaiter"]]:
		var actor := world.find_child(str(station[0]),true,false) as Node3D
		check(actor != null,"capture station exists: "+str(station[0]))
		if actor == null: continue
		var saved_condition := ""
		if actor is RadiatorProp:
			saved_condition = actor.open_shift_condition
			actor.apply_open_shift_condition("porter_temporary_shutoff")
		if actor is ToasterProp:
			actor.get_parent().restore_open_state(true)
			actor.set_crumb_tray_open(true,0)
		world.player.global_position = actor.to_global(Vector3(station[1].x,0,station[1].z))
		world.player.face_world_point(actor.to_global(station[2]))
		review_camera.global_position = actor.to_global(station[1])
		review_camera.look_at(actor.to_global(station[2]),Vector3.UP)
		review_camera.make_current()
		await shot(str(station[3]))
		if actor is RadiatorProp: actor.apply_open_shift_condition(saved_condition)
	# Review the changed UV application at the existing roof plant in daylight.
	var atmosphere: Node=world.get_node("WakingAtmosphere")
	var manager: Node=atmosphere.weather_manager
	var weather_processing: bool=manager.is_processing()
	manager.set_process(false)
	var review_minute: float=world.campaign_clock.minute_of_day()
	check(review_minute>=750 and review_minute<780,"fixed noon calendar frames the seasonal visual review")
	check(not world.shop_simulation.failed,"review preserves the monotonic shop simulation clock")
	manager._publish(); atmosphere.director._apply(review_minute)
	await get_tree().create_timer(.5).timeout
	for station in [
		["FittedHouseTank",Vector3(4.,2.6,3.8),Vector3(0,2.6,0),"roof_tank_uv"],
		["ROOF_LIFT_DRIVE",Vector3(2.8,1.9,2.8),Vector3(0,1.,0),"roof_drive_uv"]]:
		var actor: Node3D = world.find_child(str(station[0]),true,false) as Node3D
		if str(station[0])=="ROOF_LIFT_DRIVE": actor=world.adapter.resolve(str(station[0])) as Node3D
		check(actor!=null,"roof UV capture station exists: "+str(station[0]))
		if actor==null:continue
		review_camera.global_position=actor.to_global(station[1])
		review_camera.look_at(actor.to_global(station[2]),Vector3.UP)
		review_camera.make_current()
		await shot(str(station[3]))
	manager.set_process(weather_processing)
	await finish_review.run(world,self)
	await preload("res://tests/radiator_joint_review.gd").new().run(world,self)
	var after := _input_snapshot(root)
	check(before.get("sha256","") == after.get("sha256","changed"),"rendering inputs stayed fixed during qualification")
	var owner_ref: WeakRef = weakref(world)
	world.shutdown_for_tests()
	world.free()
	fixed_review.free()
	for frame in 3: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(OS.get_environment("SHOT_DIR").path_join("signage"))
	var sign_retired: Dictionary=await sign_review.validate_after_teardown()
	batch_checks+=int(sign_retired.checks)-int(sign_result.checks)
	for failure: String in sign_retired.failures:
		if not failures.has(failure):failures.append(failure)
	sign_review.free()
	for row: Dictionary in shared_uv_defaults:
		check(row.stock.uv1_triplanar==row.uv1 and row.stock.uv2_triplanar==row.uv2,
			"shared catalogue projection defaults restore after V2 teardown")
	check(owner_ref.get_ref() == null,"production world retires after inspection")
	DirAccess.make_dir_recursive_absolute(OS.get_environment("SHOT_DIR").path_join("service_instruments"))
	var instrument_post: Dictionary = await instruments.validate_after_teardown()
	batch_checks += int(instrument_post.checks)-int(instrument_result.checks)
	for failure: String in instrument_post.failures:
		if not failure in failures: failures.append(failure)
	instruments.free()
	fire_review.after_teardown(self)
	electrical_review.after_teardown(self)
	connections_review.after_teardown(self)
	var domestic_retired: Dictionary=domestic_review.validate_after_teardown()
	for failure: String in domestic_retired.failures:
		if not failures.has(failure):failures.append(failure)
	domestic_review.free()
	var seating_retired: Dictionary=seating_review.validate_after_teardown()
	batch_checks+=int(seating_retired.checks)-int(seating_result.checks)
	for failure: String in seating_retired.failures:
		if not failures.has(failure):failures.append(failure)
	seating_review.free()
	var storage_retired: Dictionary=storage_review.validate_after_teardown()
	batch_checks+=int(storage_retired.checks)-int(storage_result.checks)
	for failure: String in storage_retired.failures:
		if not failures.has(failure): failures.append(failure)
	storage_review.free()
	var media_retired: Dictionary = media_review.validate_after_teardown()
	batch_checks += int(media_retired.checks)-int(media_result.checks)
	for failure: String in media_retired.failures:
		if not failures.has(failure): failures.append(failure)
	media_review.free()
	var head: Array=[]; var digest: Array=[]
	check(OS.execute("git",["-C",root,"rev-parse","HEAD"],head)==0,"record repository head")
	check(OS.execute("python",[root.path_join("tools/run_receipt.py"),"digest","--root",root],digest)==0,"record runtime input digest")
	var passed := failures.is_empty()
	var status := "PASS" if passed else "FAIL"
	var path: String = get_script().resource_path
	var contract := {"schema_version":2,"evidence_kind":"runtime_contract","selector":"v2","production_runtime":true,
		"scope":"all loaded V2 physical surface UV/PBR/mip/filter checks; representative renders; no gameplay completion claim",
		"execution":{"completed":true,"exit_code":0 if passed else 1,"timed_out":false,"elapsed_s":(Time.get_ticks_msec()-started)/1000.},
		"source":{"test_path":"game/"+path.trim_prefix("res://"),"test_sha256":FileAccess.get_sha256(path),"repository_head":str(head[0]).strip_edges() if not head.is_empty() else "","runtime_inputs_sha256":str(digest[0]).strip_edges() if not digest.is_empty() else ""},
		"surface_inputs_sha256":after.get("sha256",""),"inventory_sha256":FileAccess.get_sha256(directory.path_join("surface-inventory.json")),
		"contracts":{"production_composition":{"executed":true,"status":status},"surface_requirements":{"executed":true,"status":status},"save_reconstruction":{"executed":false,"status":"NOT_EXECUTED"},"teardown":{"executed":true,"status":status,"measurement_scope":"runtime_owned"}},
		"checks":batch_checks,"failures":failures}
	FileAccess.open(directory.path_join("runtime_contract.json"),FileAccess.WRITE).store_string(JSON.stringify(contract,"\t"))
	print("V2 SURFACE QUALIFICATION: ",status,"; ",batch_checks," checks; ",failures.size()," failures")
	# Let this coroutine's local resource references leave scope before the
	# renderer is retired; then drain deferred node/render commands explicitly.
	_finish_surface.call_deferred(0 if passed else 1)

func _finish_surface(code: int) -> void:
	for frame in 8: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_tree().quit(code)

func _input_snapshot(root: String) -> Dictionary:
	var output: Array = []
	if OS.execute("python",[root.path_join("tools/v2_surface_evidence.py"),"--snapshot"],output) != 0 or output.is_empty(): return {}
	var result: Variant = JSON.parse_string(str(output[0]))
	return result if result is Dictionary else {}

func _validate_native_controls(world: Node) -> void:
	var cases := 0
	var loose := 0
	var copies := 0
	for actor: Node in world.find_children("*","Node3D",true,false):
		if actor.get_script() == preload("res://scripts/building/orison_v2_bookshelf.gd"):
			cases += 1
			check(actor._sashes.size()==actor._case_record.doors.size(),"native case retains every source sash")
			for sash: Node3D in actor._sashes:
				check(sash.valid(sash.snapshot()),"native sash has a valid physical lift/pocket pose")
				check(not sash.shapes.is_empty() and sash.solid is AnimatableBody3D,"moving sash retains native collision stock")
				var glass := 0
				for identity: String in sash.record.parts:
					var material: String = str(actor.native_stock.data.parts[identity].material)
					if material != "glass_drawn_expressive": continue
					glass += 1
					var finish: StandardMaterial3D = actor.native_stock.materials[material]
					check(finish.refraction_enabled and finish.normal_enabled,"native sash uses mapped refractive glass")
				check(glass==1,"each native sash has its separate glass stock")
		if actor.get_script() == preload("res://scripts/building/v2_loose_library.gd"):
			loose += 1
			copies += actor._books.size()
			check(actor.valid_library(actor.library_snapshot()),"loose library retains a valid native physical snapshot")
		if actor is RadiatorProp:
			for tag: MeshInstance3D in actor._porter_tag.find_children("*","MeshInstance3D",true,false):
				var bounds := tag.mesh.get_aabb()
				check(is_equal_approx(bounds.size.x,.1056) and is_equal_approx(bounds.size.y,.1584),"native paper tag retains physical size")
	print("NATIVE LIBRARY DISCOVERY: cases=",cases," loose=",loose," copies=",copies)
	check(cases==10,"composed surface discovery covers all ten native resident cases: "+str(cases))
	check(loose==3 and copies==61,"composed surface discovery covers all three loose collections and 61 copies: "+str([loose,copies]))

func _mesh(mesh: Mesh) -> Dictionary:
	var surfaces: Array = []
	for index in mesh.get_surface_count():
		var a := mesh.surface_get_arrays(index)
		var vertices: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var uv: PackedVector2Array = PackedVector2Array() if a[Mesh.ARRAY_TEX_UV] == null else a[Mesh.ARRAY_TEX_UV]
		var indices: PackedInt32Array = PackedInt32Array() if a[Mesh.ARRAY_INDEX] == null else a[Mesh.ARRAY_INDEX]
		var missing := uv.size() != vertices.size()
		var invalid := 0
		var degenerate := 0
		var triangles := 0
		for point in uv:
			if not point.is_finite(): invalid += 1
		var primitive: int = (mesh as ArrayMesh).surface_get_primitive_type(index) if mesh is ArrayMesh else Mesh.PRIMITIVE_TRIANGLES
		if primitive == Mesh.PRIMITIVE_TRIANGLES and not missing:
			var count := indices.size() if not indices.is_empty() else vertices.size()
			for start in range(0, count - 2, 3):
				var i: int = indices[start] if not indices.is_empty() else start
				var j: int = indices[start+1] if not indices.is_empty() else start+1
				var k: int = indices[start+2] if not indices.is_empty() else start+2
				if (vertices[j]-vertices[i]).cross(vertices[k]-vertices[i]).length_squared() <= 1e-18: continue
				triangles += 1
				if absf((uv[j]-uv[i]).cross(uv[k]-uv[i])) <= 1e-12: degenerate += 1
		surfaces.append({"vertices":vertices.size(),"missing_uv":missing,"nonfinite_uv":invalid,"degenerate_uv_triangles":degenerate,"triangles":triangles})
	return {"source":mesh.resource_path,"type":mesh.get_class(),"surfaces":surfaces}

func _texture(texture: Texture2D) -> String:
	var key := texture.resource_path
	if key.is_empty(): key = "generated:"+str(texture.get_instance_id())
	if not texture_rows.has(key):
		# A live render target is an image of a screen, not a sampled PBR map.
		# Dummy headless rendering cannot read it; keep it in the inventory.
		var pixels: Image = null if texture is ViewportTexture else texture.get_image()
		texture_rows[key] = {"type":texture.get_class(),"width":texture.get_width(),"height":texture.get_height(),"mips":pixels != null and pixels.has_mipmaps(),"mip_levels":pixels.get_mipmap_count() if pixels != null else 0,"compressed":pixels.is_compressed() if pixels != null else false,"format":pixels.get_format() if pixels != null else -1}
	return key

func _material(material: Material) -> Dictionary:
	var maps := {}
	var row := {"type":material.get_class(),"source":material.resource_path,"name":material.resource_name,"maps":maps}
	if material is StandardMaterial3D:
		row.triplanar = material.uv1_triplanar
		row.filter = material.texture_filter
		row.metallic = material.metallic
		row.roughness = material.roughness
		row.transparency = material.transparency
		row.unshaded = material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED
		row.additive = material.blend_mode == BaseMaterial3D.BLEND_MODE_ADD
		row.billboard = material.billboard_mode == BaseMaterial3D.BILLBOARD_ENABLED
		row.emissive = material.emission_enabled
		row.stock_recipe = str(material.get_meta("v2_surface_stock", ""))
		row.normal_enabled = material.normal_enabled
		row.color = [material.albedo_color.r,material.albedo_color.g,material.albedo_color.b,material.albedo_color.a]
		for property in material.get_property_list():
			var value: Variant = material.get(property.name)
			if value is Texture2D: maps[property.name] = _texture(value)
	elif material is ShaderMaterial and material.shader != null:
		row.shader = material.shader.resource_path
		row.shader_unshaded = material.shader.code.contains("unshaded")
		row.mesh_uv_selector = material.shader.code.contains("orison_surface.gdshaderinc")
		row.mip_filters = _shader_filters(material.shader)
		for uniform in material.shader.get_shader_uniform_list():
			var value: Variant = material.get_shader_parameter(uniform.name)
			if value is Texture2D: maps[uniform.name] = _texture(value)
			elif uniform.name in ["has_normal_tex", "has_rough_tex", "has_albedo_tex", "uv_mode"]: row[uniform.name] = value
	if material.next_pass != null: row.next_pass = _material(material.next_pass)
	return row

func _expanded_shader_source(code: String, visited: Dictionary) -> String:
	var include := RegEx.new()
	include.compile('#include\\s+"(res://[^"]+)"')
	var expanded := code
	for match in include.search_all(code):
		var path := match.get_string(1)
		if visited.has(path): continue
		visited[path] = true
		expanded += "\n" + _expanded_shader_source(FileAccess.get_file_as_string(path), visited)
	return expanded

func _shader_filters(shader: Shader) -> Dictionary:
	var identity := shader.get_instance_id()
	if shader_filter_cache.has(identity): return shader_filter_cache[identity]
	var code := _expanded_shader_source(shader.code, {})
	var sampler := RegEx.new()
	sampler.compile("uniform\\s+sampler2D\\s+(\\w+)\\s*([^;]*);")
	var filters := {}
	for match in sampler.search_all(code): filters[match.get_string(1)] = match.get_string(2).contains("mipmap")
	shader_filter_cache[identity] = filters
	return filters
