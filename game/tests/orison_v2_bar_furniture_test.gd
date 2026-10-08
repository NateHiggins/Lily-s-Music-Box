extends "res://tests/orison_v2_domestic_native_test.gd"
## Passive bar construction, exact retirement and the retained Rainbow Round.
var retained: Array[WeakRef] = []
var contract_started := 0

func validate_in_world(world: OrisonV2RuntimeRoot) -> Dictionary:
	contract_started = Time.get_ticks_msec()
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_bar_furniture.json"))
	check(FileAccess.get_sha256(str(fixture.runtime.asset)) == fixture.asset_sha256,"native bar furniture export bound")
	check(not world.bar_region.startup_failed,"complete bar region initialized")
	var geometry := world.bar_region.get_node("RetainedBarGeometry") as Node3D
	var model := geometry.get_node_or_null("BarFurniture") as Node3D
	check(model != null,"complete piano, microphone, target and score assembly mounted")
	if model == null: return {"checks":checks,"failures":failures}
	retained.append(weakref(model))
	var actual := model.find_children("*","MeshInstance3D",true,false)
	check(actual.size() == fixture.runtime.parts.size(),"all native partitions mounted once")
	for part: Dictionary in fixture.runtime.parts:
		var draw := model.get_node("F01_retail_bar_native_"+str(part.name)) as MeshInstance3D
		check(draw.mesh is ArrayMesh and draw.mesh.get_faces().size()==int(part.triangles)*3,"native partition has exact exported geometry")
		_check_cap_mapping(draw.mesh,true)
		var material := draw.mesh.surface_get_material(0) as StandardMaterial3D
		var library := MatLib.get_mat(str(part.catalog_key))
		check(material != library and material.albedo_texture==library.albedo_texture and material.normal_texture==library.normal_texture,"local finishes retain registered source maps")
		check(not material.uv1_triplanar and material.uv1_scale.is_equal_approx(Vector3.ONE/float(part.tile)),"metre charts retained")
		check(is_equal_approx(material.normal_scale,float(part.normal)) and is_equal_approx(material.roughness,float(part.roughness)),"local relief and roughness retained")
		var layered := draw.get_surface_override_material(0) as ShaderMaterial
		check(layered != null and is_equal_approx(float(layered.get_shader_parameter("pigment_variation")),float(part.pigment)),"SurfacePass retains material state and calibrated pigment")
		check(draw.find_children("*","Area3D",true,false).is_empty(),"passive geometry creates no new interaction owner")
	var originals: Dictionary = model.get_meta("original_meshes")
	var removed: Dictionary = model.get_meta("removed_triangles")
	# Receiving cases share several legacy material draws. Their separately
	# bound retirement follows furniture in the production composition.
	var later_removed: Dictionary = {}
	if geometry.has_node("BarReceiving"):
		later_removed=geometry.get_node("BarReceiving").get_meta("removed_triangles")
	var total := 0
	for draw: MeshInstance3D in originals:
		var old: ArrayMesh = originals[draw]
		var amount: int = int(removed[str(draw.name)]); total += amount
		check(old.get_faces().size()-draw.mesh.get_faces().size()==(amount+int(later_removed.get(draw,0)))*3,"only furniture and separately bound subsequent receiving triangles retire")
		if draw.mesh.get_surface_count()==0: continue
		var remap: Array = draw.mesh.get_meta("bar_source_surface_indices")
		for surface in draw.mesh.get_surface_count():
			var before: Dictionary = (old.get("_surfaces") as Array)[int(remap[surface])]
			var after: Dictionary = (draw.mesh.get("_surfaces") as Array)[surface]
			for key in ["vertex_data","attribute_data","skin_data","vertex_count","format","aabb"]:
				check(before.get(key)==after.get(key),"retained imported vertex attributes remain byte exact: "+key)
	var ceiling: Dictionary = geometry.get_meta("bar_ceiling_finish")
	check(ceiling.finish_surface>=0 and ceiling.owner.mesh.surface_get_material(int(ceiling.finish_surface)).resource_name=="M_smoked_plaster","earlier ceiling finish owner survives score-surface retirement")
	check(total==1292,"exact source retirement includes the omitted left door's zero drawn faces")
	var excluded: Array[RID] = []
	for body: StaticBody3D in model.find_children("*","StaticBody3D",true,false): excluded.append(body.get_rid())
	for bearing: Dictionary in fixture.contacts:
		var at := world.bar_region.to_global(_v(bearing.point)); var normal: Vector3 = world.bar_region.global_basis*_v(bearing.normal)
		var query := PhysicsRayQueryParameters3D.create(at+normal*.004,at-normal*.004,1,excluded)
		var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
		check(not hit.is_empty() and hit.position.distance_to(at)<.0002 and hit.normal.dot(normal)>.99,"native stock bears on retained stage or wall: "+str(bearing.id))
	var piano_feet := world.bar_region.to_global(Vector3(-1.90,-2.55,36.25))
	check(_city_clear_station(world,piano_feet),"original stage front remains reachable beside keybed and pedals")
	world.first_shift_director.ritual_phase()
	var saved := var_to_bytes(RealityState.data)
	var darts := world.find_child("F01_BAR_DARTS",true,false) as DartsProp
	var station := world.bar_region.to_global(Vector3(-8.72,-2.77,33.36))
	check(_city_clear_station(world,station),"clear standing station beside original oche")
	world.player.global_position=station; world.player.face_world_point(darts.to_global(Vector3(0,.12,0)))
	await get_tree().physics_frame
	var from := world.player.camera.global_position
	var aim := darts.to_global(Vector3(0,.12,0))
	var query := PhysicsRayQueryParameters3D.create(from,from+from.direction_to(aim)*2.1,1,[world.player.get_rid()])
	query.collide_with_areas=true
	var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
	var owner: Node = hit.get("collider")
	while owner != null and owner != darts: owner=owner.get_parent()
	check(owner==darts,"pot remains the nearest interaction hit from the throwing station")
	world.player._try_interact()
	check(is_instance_valid(darts._panel) and world.player.call_locked,"actual player ray opens the original Rainbow Round")
	if is_instance_valid(darts._panel):
		var panel := darts._panel as DartsPanel; retained.append(weakref(panel)); panel.set_process(false)
		check(panel.trivia.colours==["red","orange","yellow","green","blue","indigo","violet"],"seven source sectors remain clockwise from red at top")
		for i in 7:
			var angle := i*TAU/7.+.007
			for radius in [60.,103.,132.,166.]:
				var result := panel.trivia.slice_at(sin(angle)*radius,cos(angle)*radius)
				check(result.colour==panel.trivia.colours[i] and result.ring==("treble" if radius==103. else "double" if radius==166. else "single"),"model's sector/ring datums match retained scoring")
				var at := world.bar_region.to_global(Vector3(-11.406,-1.07+cos(angle)*radius/1000.,33.-sin(angle)*radius/1000.))
				var normal := world.bar_region.global_basis.x
				# A metre-long probe avoids the engine segment/triangle epsilon
				# rejecting small scoring-band triangles on a 33 mm segment.
				var field_hit := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at+normal*.5,at-normal*.5,1))
				var field: Node = field_hit.get("collider")
				if field != null: field=field.get_parent()
				var expected := "DartsCabinet__sector_"+str(i)+("_single" if result.ring=="single" else "")
				check(field!=null and str(field.get_meta("bar_furniture_part",""))==expected,"actual painted field matches the retained scoring result")
		panel.aim=panel.trivia.aim_point(str(panel.trivia.card.a),132.)
		panel._steady=1.
		var click := InputEventMouseButton.new(); click.button_index=MOUSE_BUTTON_LEFT; click.pressed=false
		panel._unhandled_input(click)
		check(panel.step==DartsPanel.Step.THROWN and panel.trivia.thrown.has(0) and panel._landed.size()==1,"mouse release performs one original player throw")
		var result: Dictionary = panel.trivia.thrown.get(0,{})
		check(not result.is_empty() and int(panel.trivia.players[0].score)==int(result.points),"retained result updates its original score owner")
		panel._process(1.3)
		check(panel.step==DartsPanel.Step.REVEAL and panel.trivia.everyone_thrown(),"original opponent completes and reveals the round")
		var enter := InputEventKey.new(); enter.keycode=KEY_ENTER; enter.pressed=true
		var round_before := panel.trivia.round_no; panel._unhandled_input(enter)
		check(panel.trivia.round_no==round_before+1 and panel.trivia.thrown.is_empty(),"original Enter action deals the next round")
		var escape := InputEventKey.new(); escape.keycode=KEY_ESCAPE; escape.pressed=true; panel._unhandled_input(escape)
		await get_tree().process_frame
		check(darts._panel==null and not world.player.call_locked,"Escape closes the original panel and unlocks player")
	check(var_to_bytes(RealityState.data)==saved,"passive furniture and original darts round add no persistent fact")
	if capture_enabled:
		await _city_inspect(world,world.bar_region,Vector3(-.15,-2.77,34.8),Vector3(-1.55,-1.76,37.05),"stage_audience","bar","G09")
		await _city_inspect(world,world.bar_region,Vector3(-1.9,-2.55,36.25),Vector3(-1.9,-1.93,36.74),"piano_keys","bar","G09")
		await _city_inspect(world,world.bar_region,Vector3(-9.05,-2.77,33.0),Vector3(-11.4,-1.07,33.0),"darts_oche","bar","G11")
		await _city_inspect(world,world.bar_region,Vector3(-10.3,-2.77,31.5),Vector3(-11.42,-.98,32.1),"darts_score_oblique","bar","G11")
	return {"checks":checks,"failures":failures,"views":discovery.duplicate(true)}

func validate_after_teardown() -> Dictionary:
	for ref in retained: check(ref.get_ref()==null,"native furniture and original round panel retire with world")
	var root := ProjectSettings.globalize_path("res://..").simplify_path()
	var head: Array=[]; var digest: Array=[]
	check(OS.execute("git",["-C",root,"rev-parse","HEAD"],head)==0,"contract records repository head")
	check(OS.execute("python",[root.path_join("tools/run_receipt.py"),"digest","--root",root],digest)==0,"contract records runtime digest")
	var passed := failures.is_empty(); var status := "PASS" if passed else "FAIL"
	var path: String=get_script().resource_path
	var receipt := {"schema_version":2,"evidence_kind":"runtime_contract","selector":"v2","production_runtime":true,
		"scope":"Passive stage and target construction, exact source retirement, bearings and reach, original Rainbow Round ray/open/throw/opponent/reveal/next/close, saved-state stability and teardown. No playable piano, microphone capture, physical projectiles or save reconstruction is exercised.",
		"execution":{"completed":true,"exit_code":0 if passed else 1,"timed_out":false,"elapsed_s":(Time.get_ticks_msec()-contract_started)/1000.},
		"source":{"test_path":"game/"+path.trim_prefix("res://"),"test_sha256":FileAccess.get_sha256(path),"repository_head":str(head[0]).strip_edges() if not head.is_empty() else "","runtime_inputs_sha256":str(digest[0]).strip_edges() if not digest.is_empty() else ""},
		"contracts":{"production_composition":{"executed":true,"status":status},"premature_action_denial":{"executed":false,"status":"NOT_EXECUTED"},"save_reconstruction":{"executed":false,"status":"NOT_EXECUTED"},"teardown":{"executed":true,"status":status,"measurement_scope":"runtime_owned","retained_nodes":retained.filter(func(r):return r.get_ref()!=null).size()}},"checks":checks,"failures":failures}
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("bar_furniture/runtime_contract.json"),FileAccess.WRITE).store_string(JSON.stringify(receipt,"\t"))
	return {"checks":checks,"failures":failures}

func _v(a: Array) -> Vector3: return Vector3(a[0],a[1],a[2])
