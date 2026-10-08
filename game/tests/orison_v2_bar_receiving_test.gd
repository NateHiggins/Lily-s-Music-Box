extends "res://tests/orison_v2_domestic_native_test.gd"
## Whole chassis, original keyboard programmes and actual bar reconstruction.
var retained: Array[WeakRef]=[]
var contract_started := 0
var reconstructed := false
var programmes: Array=[]
var saved: PackedByteArray
var reconstruction_loads := 0

func validate_in_world(world: OrisonV2RuntimeRoot) -> Dictionary:
	contract_started=Time.get_ticks_msec()
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_bar_receiving.json"))
	check(FileAccess.get_sha256(str(fixture.runtime.asset))==fixture.asset_sha256,"native receiving export bound")
	check(not world.bar_region.startup_failed,"complete bar initialized")
	var cell := world.bar_region.get_node("RetainedBarGeometry") as Node3D
	var model := cell.get_node_or_null("BarReceiving") as Node3D
	check(model!=null,"two complete native cases mounted")
	if model==null: return {"checks":checks,"failures":failures}
	retained.append(weakref(model))
	check(model.find_children("*","MeshInstance3D",true,false).size()==18,"eighteen native partitions mounted once")
	var excluded: Array[RID]=[]
	for part: Dictionary in fixture.runtime.parts:
		var draw := model.get_node("F01_retail_bar_native_receiver_"+str(part.name)) as MeshInstance3D
		check(draw.mesh.get_faces().size()==int(part.triangles)*3,"exact native triangle count")
		_check_cap_mapping(draw.mesh,true)
		var mat := draw.mesh.surface_get_material(0) as StandardMaterial3D
		var original := MatLib.get_mat(str(part.catalog_key))
		check(mat!=original and mat.albedo_texture==original.albedo_texture and mat.normal_texture==original.normal_texture,"local finish retains catalogue source maps")
		check(not mat.uv1_triplanar and mat.uv1_scale.is_equal_approx(Vector3.ONE/float(part.tile)),"metre charts retained")
		check(is_equal_approx(mat.normal_scale,float(part.normal)) and is_equal_approx(mat.roughness,float(part.roughness)),"local roughness and relief retained")
		var shader := draw.get_surface_override_material(0) as ShaderMaterial
		check(shader!=null and is_equal_approx(float(shader.get_shader_parameter("pigment_variation")),float(part.pigment)),"SurfacePass retains calibrated pigment and state")
		var shapes := draw.find_children("*","CollisionShape3D",true,false)
		check(shapes.size()==1 and shapes[0].shape.get_faces()==draw.mesh.get_faces(),"installed visible and collision triangles agree")
		check(draw.find_children("*","Area3D",true,false).is_empty(),"native case introduces no interaction owner")
	for body: StaticBody3D in model.find_children("*","StaticBody3D",true,false): excluded.append(body.get_rid())
	var count := 0
	var originals: Dictionary=model.get_meta("original_meshes")
	for draw: MeshInstance3D in originals:
		var old: ArrayMesh=originals[draw]; count+=(old.get_faces().size()-draw.mesh.get_faces().size())/3
		if draw.mesh.get_surface_count()==0: continue
		var remap: Array=draw.mesh.get_meta("bar_source_surface_indices")
		for surface in draw.mesh.get_surface_count():
			var before: Dictionary=(old.get("_surfaces") as Array)[int(remap[surface])]
			var after: Dictionary=(draw.mesh.get("_surfaces") as Array)[surface]
			for key in ["vertex_data","attribute_data","skin_data","vertex_count","format","aabb"]:
				check(before.get(key)==after.get(key),"unrelated packed source attributes remain exact: "+key)
	check(count==824,"only 824 original case triangles retire")
	var hulls: Dictionary=model.get_meta("original_hulls")
	check(hulls.size()==1,"one shared source hull retained")
	for shape: CollisionShape3D in hulls:
		var before: PackedVector3Array=hulls[shape].original.get_faces()
		var after: PackedVector3Array=shape.shape.get_faces()
		check(before.size()-after.size()==72,"only the two 12-triangle cabinet hulls retire")
		var keep := {}; var cursor := 0
		for i in range(0,before.size(),3): keep[[before[i],before[i+1],before[i+2]]]=true
		for i in range(0,after.size(),3):
			if keep.has([after[i],after[i+1],after[i+2]]): cursor+=1
		check(cursor*3==after.size(),"all retained shared collision faces remain exact")
	for contact: Dictionary in fixture.contacts:
		var at := cell.to_global(_v(contact.point))
		var hit := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3.UP*.03,at-Vector3.UP*.03,1,excluded))
		check(not hit.is_empty() and hit.position.distance_to(at)<.0002,"fitted foot bears on actual raised south deck")
	world.first_shift_director.ritual_phase()
	# Shutdown serializes the existing household defaults. Establish that normal
	# snapshot before comparing persistent facts across a complete reconstruction.
	world.household_state.capture_now()
	saved=var_to_bytes(RealityState.data)
	for i in range(2):
		var prop := world.bar_region.actors.get_node("Arcade_retail_bar_cab0"+str(i+1)) as ArcadeCabinetProp
		programmes.append(prop.cabinet.duplicate(true)); retained.append(weakref(prop))
		await _exercise(world,prop,i)
	check(var_to_bytes(RealityState.data)==saved,"ordinary receiver sessions preserve outer persistent facts")
	if capture_enabled:
		await _city_inspect(world,world.bar_region,Vector3(2.3,-2.59,34.9),Vector3(3.4,-1.65,35.8),"receivers_whole","bar","G12")
		await _city_inspect(world,world.bar_region,Vector3(2.3,-2.59,36.7),Vector3(3.3,-2.32,36.35),"receivers_feet","bar","G12")
	return {"checks":checks,"failures":failures,"views":discovery.duplicate(true)}

func _exercise(world: OrisonV2RuntimeRoot,prop: ArcadeCabinetProp,index: int,capture: bool=true) -> void:
	var station := world.bar_region.to_global(Vector3(2.3,-2.59,35.35+index*.95))
	check(_city_clear_station(world,station),"clear standing capsule on original receiver deck")
	world.player.global_position=station; world.player.velocity=Vector3.ZERO
	world.player.face_world_point(prop._screen.global_position); Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	await _settled_optics()
	var size := .38 if index==0 else .41; var height := 1.29 if index==0 else 1.345
	check((prop._screen.mesh as QuadMesh).size.is_equal_approx(Vector2(size,size)) and prop._screen.position.is_equal_approx(Vector3(0,height,-.386)),"original round live scope plane and size retained")
	var from := world.player.camera.global_position
	var ray := PhysicsRayQueryParameters3D.create(from,from-world.player.camera.global_basis.z*2.1,1,[world.player.get_rid()]); ray.collide_with_areas=true
	var hit := world.get_world_3d().direct_space_state.intersect_ray(ray); var node: Node=hit.get("collider"); var reached := false
	while node!=null: reached=reached or node==prop; node=node.get_parent()
	check(reached,"actual player ray reaches original receiver input owner")
	if not reached: return
	world.player._update_prompt(); check(world.player._prompt.text.contains(str(prop.cabinet.title)),"original programme heading/prompt remains")
	if capture_enabled and capture: await shot("receiver_"+str(index+1)+"_powered")
	await _key(KEY_E)
	check(prop._playing() and world.player.call_locked and prop.machine.state==ArcadeMachine.State.PLAYING,"ordinary E enters original programme")
	if not prop._playing(): return
	retained.append(weakref(prop._panel_ui)); retained.append(weakref(prop.machine._world)); retained.append(weakref(prop.machine.player))
	check(not prop.suspend_receiving(),"focused programme refuses inactive-board suspension")
	var event := InputEventKey.new(); event.keycode=KEY_W; event.physical_keycode=KEY_W; event.pressed=true; Input.parse_input_event(event)
	await get_tree().process_frame; await get_tree().process_frame
	check(prop.machine.player.control.move==Vector2(0,-1),"ordinary W reaches original programme movement input")
	for tick in 12: await get_tree().physics_frame
	event=InputEventKey.new(); event.keycode=KEY_W; event.physical_keycode=KEY_W; Input.parse_input_event(event)
	if capture_enabled and capture: await shot("receiver_"+str(index+1)+"_play")
	await _key(KEY_ESCAPE)
	check(not prop._playing() and not world.player.call_locked and prop.machine.state==ArcadeMachine.State.ATTRACT,"Escape closes original panel and releases player")
	var board: WeakRef = weakref(prop.machine._world)
	# Pause distance polling only during the explicit unload observation.
	prop.set_process(false)
	check(prop.suspend_receiving(),"closed receiver accepts inactive-board suspension")
	await get_tree().process_frame; await get_tree().process_frame
	check(board.get_ref()==null and not prop.machine.is_booted(),"inactive programme world unloads without orphan board")
	prop.set_process(true)

func _key(code: Key) -> void:
	var event := InputEventKey.new(); event.keycode=code; event.physical_keycode=code; event.pressed=true; Input.parse_input_event(event)
	await get_tree().process_frame; await get_tree().process_frame
	event=InputEventKey.new(); event.keycode=code; event.physical_keycode=code; Input.parse_input_event(event)
	await get_tree().process_frame; await get_tree().process_frame

func validate_after_teardown() -> Dictionary:
	# The bar is resident. Rebuild the whole production world so every normal
	# lighting/instrument adapter runs, rather than inventing a partial loader.
	var world := _world_scene().instantiate() as OrisonV2RuntimeRoot
	add_child(world); reconstruction_loads=1
	# Freeze before the first frame, just as the original world's sample was
	# frozen; otherwise two startup frames legitimately advance campaign time.
	for driver: CampaignClockDriver in get_tree().get_nodes_in_group("campaign_time_owner"): driver.set_frozen_for_tests(true)
	world.shop_simulation.set_process(false)
	await get_tree().physics_frame; await get_tree().physics_frame
	check(not world.startup_failed and not world.bar_region.startup_failed,"full world reconstructs fitted receivers through normal adapters")
	world.player.set_physics_process(false); world.service_set_carrier.set_capture_hidden(true)
	for driver: CampaignClockDriver in get_tree().get_nodes_in_group("campaign_time_owner"): driver.set_frozen_for_tests(true)
	world.shop_simulation.set_process(false)
	world.first_shift_director.ritual_phase()
	check(world.bar_region.actors.find_children("Arcade_retail_bar_cab*","Node3D",false,false).size()==2,"reconstruction has exactly two receiver actors")
	for i in range(2):
		var prop := world.bar_region.actors.get_node("Arcade_retail_bar_cab0"+str(i+1)) as ArcadeCabinetProp
		check(prop.cabinet==programmes[i],"reconstruction retains original programme identity/card")
		retained.append(weakref(prop)); await _exercise(world,prop,i,false)
	var original: Dictionary=bytes_to_var(saved)
	var differences := {}
	for key: String in original:
		if original[key]!=RealityState.data.get(key): differences[key]={"before":original[key],"after":RealityState.data.get(key)}
	for key: String in RealityState.data:
		if not original.has(key): differences[key]={"added":RealityState.data[key]}
	if not differences.is_empty():
		FileAccess.open(OS.get_environment("SHOT_DIR").path_join("bar_receiving/state_differences.json"),FileAccess.WRITE).store_string(JSON.stringify(differences,"\t"))
	check(RealityState.data==original,"full world reconstruction retains outer persistent facts")
	reconstructed=true
	world.shutdown_for_tests(); world.free(); await _retired_audio()
	for ref in retained: check(ref.get_ref()==null,"case, receiver, panel and programme owners retire")
	var root := ProjectSettings.globalize_path("res://..").simplify_path(); var head: Array=[]; var digest: Array=[]
	check(OS.execute("git",["-C",root,"rev-parse","HEAD"],head)==0,"contract records repository head")
	check(OS.execute("python",[root.path_join("tools/run_receipt.py"),"digest","--root",root],digest)==0,"contract records runtime digest")
	var passed := failures.is_empty(); var status := "PASS" if passed else "FAIL"; var path: String=get_script().resource_path
	var receipt := {"schema_version":2,"evidence_kind":"runtime_contract","selector":"v2","production_runtime":true,
		"scope":"Whole native receiving cases, exact static-source/hull retirement, floor bearings, original scope and ordinary E/W/Escape input, board unload, full production-world reconstruction with original programmes and outer-state stability, and final teardown. No disk-save reconstruction or changed residency policy.",
		"execution":{"completed":true,"exit_code":0 if passed else 1,"timed_out":false,"elapsed_s":(Time.get_ticks_msec()-contract_started)/1000.},
		"source":{"test_path":"game/"+path.trim_prefix("res://"),"test_sha256":FileAccess.get_sha256(path),"repository_head":str(head[0]).strip_edges() if not head.is_empty() else "","runtime_inputs_sha256":str(digest[0]).strip_edges() if not digest.is_empty() else ""},
		"contracts":{"production_composition":{"executed":true,"status":status},"premature_action_denial":{"executed":false,"status":"NOT_EXECUTED"},"save_reconstruction":{"executed":false,"status":"NOT_EXECUTED"},"world_reconstruction":{"executed":reconstructed,"status":status},"teardown":{"executed":true,"status":status,"measurement_scope":"runtime_owned","retained_nodes":retained.filter(func(r):return r.get_ref()!=null).size()}},"checks":checks,"failures":failures}
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("bar_receiving/runtime_contract.json"),FileAccess.WRITE).store_string(JSON.stringify(receipt,"\t"))
	return {"checks":checks,"failures":failures,"additional_world_loads":reconstruction_loads}

func _v(a: Array) -> Vector3: return Vector3(a[0],a[1],a[2])
