extends "res://tests/orison_v2_city_sweep.gd"
var batch_mode := true
var capture_enabled := true
var actor_id := 0
func _ready() -> void: pass

func validate_in_world(world: OrisonV2RuntimeRoot) -> Dictionary:
	var terminal := world.adapter.resolve("F04_B_MONITOR_01") as SignalTerminalProp
	check(terminal != null and terminal.get("native_ready") == true,"original signal actor owns native fixed instrument")
	if terminal == null: return {"checks":checks,"failures":failures.duplicate()}
	actor_id = terminal.get_instance_id()
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_signal_terminal.json"))
	check(FileAccess.get_sha256("res://assets/props/signal_terminal.glb") == fixture.asset_sha256,"terminal native asset binding")
	var fixed := terminal.get_node("FixedInstrument")
	check(fixed.get_child_count()+terminal.get_node("ValveBank").get_child_count() == fixture.parts.size(),"one native mesh per fixed or dynamic material")
	for part: Dictionary in fixture.runtime.assemblies[0].parts:
		var parent: Node = terminal.get_node("ValveBank") if part.key == "glassish" else fixed
		var draw := parent.get_node_or_null(str(part.name)) as MeshInstance3D
		check(draw != null and draw.owner == null,"native terminal part retains actor ownership")
		if draw == null: continue
		var expected: Dictionary = fixture.parts.filter(func(p): return p.name == part.name)[0]
		check(draw.mesh.get_faces().size()/3 == int(expected.triangles),"exact terminal construction stock")
		_check_cap_mapping(draw.mesh,true)
		var material := draw.mesh.surface_get_material(0) as StandardMaterial3D
		if part.key == "glassish":
			check(material == terminal._valve_mat and draw.material_override == terminal._valve_mat,"original dynamic valve material owns native envelopes")
			continue
		var library := MatLib.get_mat(str(part.catalog_key))
		check(material != library and material.albedo_texture == library.albedo_texture and not material.uv1_triplanar and material.uv1_scale.is_equal_approx(Vector3.ONE/float(part.tile)),"instance-local terminal catalogue maps")
		if part.has("finish"): check(is_equal_approx(material.normal_scale,float(part.finish.normal_scale)) and is_equal_approx(material.roughness,float(part.finish.roughness)),"terminal native/runtime finish agrees")
	var scope := terminal.get_node("SignalScope") as MeshInstance3D
	var annunciator := terminal.get_node("LineAnnunciator") as MeshInstance3D
	check(scope.material_override == terminal._scope_mat and terminal._screen_mats.has(terminal._scope_mat),"original scope material remains connected")
	check(annunciator.material_override == terminal._line_mat and terminal.has_node("ValveBank") and terminal.has_node("ScopePool"),"original annunciator, valve bank and practical remain")
	check(terminal._meter_needles.size() == 2,"two original moving meter pivots")
	for pivot: Node3D in terminal._meter_needles:
		for needle: MeshInstance3D in pivot.find_children("*","MeshInstance3D",false,false): check(needle.position.is_equal_approx(Vector3(0,.032,0)),"existing needle sits on its dial pivot")
	var old_stage: String = terminal._stage
	for stage: String in ["incoming","isolate","capture","route","idle"]:
		terminal.set_console_stage(stage)
		await get_tree().create_timer(.25).timeout
		check(terminal._stage == stage and terminal._scope_mat.emission_energy_multiplier > 0,"original stage drives scope: " + stage)
		if stage == "incoming": check(terminal._line_mat.emission_energy_multiplier > 1,"original incoming annunciator still responds")
		if stage == "route": check(is_equal_approx(terminal._meter_needles[0].rotation.x,.62) and is_equal_approx(terminal._meter_needles[1].rotation.x,.42),"original meter tween reaches route targets")
	terminal.set_console_stage(old_stage)
	await get_tree().create_timer(.25).timeout
	var desk := world.adapter.resolve("4B_terminal_desk") as StaticBody3D
	var own_bodies: Array[RID] = []
	for body: CollisionObject3D in terminal.find_children("*","CollisionObject3D",true,false): own_bodies.append(body.get_rid())
	for contact: Dictionary in fixture.contacts:
		var p: Array = contact.point
		var at := terminal.to_global(Vector3(p[0],p[1],p[2]))
		var query := PhysicsRayQueryParameters3D.create(at+Vector3.UP*.004,at-Vector3.UP*.004,1,own_bodies)
		var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
		check(not hit.is_empty() and hit.collider == desk and hit.position.distance_to(at)<.00004,"terminal base seats on native desktop")
	if capture_enabled:
		var feet: Vector3 = world.adapter.root.to_global(Vector3(-9.9,9.62,.7))
		check(_city_clear_station(world,feet),"terminal standing capture remains clear")
		await _city_capture(world,feet,terminal.to_global(Vector3(0,.19,0)),"vantry_context","native Vantry fixed instrument","F04_B_MONITOR_01")
	return {"checks":checks,"failures":failures.duplicate()}

func validate_after_teardown() -> Dictionary:
	check(actor_id != 0 and not is_instance_id_valid(actor_id),"original terminal actor retires with native fixed stock")
	return {"checks":checks,"failures":failures.duplicate()}
