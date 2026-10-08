extends "res://tests/orison_v2_domestic_native_test.gd"
## Optical QA and retained service-state checks in the batch's single world.
var retained: Array[WeakRef] = []
var contract_started := 0
var changed_slots := 0
var validation_completed := false

func validate_in_world(world: OrisonV2RuntimeRoot) -> Dictionary:
	contract_started = Time.get_ticks_msec()
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/orison_owner_service_finish.json"))
	check(FileAccess.get_sha256(str(fixture.profile_path)) == fixture.profile_sha256, "shared finish recipe bound")
	var owners: Array[Node] = []
	for actor: Node in world.find_children("*", "Node3D", true, false):
		if actor.has_meta("v2_owner_finish_group"): owners.append(actor)
	check(owners.size() > 40, "finish deployed across service and household fixture roster")
	var maps := {}
	var shader_slots := 0
	for actor: Node in owners:
		retained.append(weakref(actor))
		check(int(actor.get_meta("v2_owner_finish_slots")) > 0, "actual finish slots at " + str(actor.name))
		changed_slots += int(actor.get_meta("v2_owner_finish_slots"))
		for draw: Node in actor.find_children("*", "GeometryInstance3D", true, false):
			var materials: Array[Material] = []
			if draw is MeshInstance3D and draw.mesh != null:
				for i in draw.mesh.get_surface_count(): materials.append(draw.get_active_material(i))
			elif draw is MultiMeshInstance3D and draw.material_override != null: materials.append(draw.material_override)
			for material: Material in materials:
				if material == null or not material.has_meta("v2_owner_finish"): continue
				var textures: Array = []
				if material is StandardMaterial3D:
					check(not material.emission_enabled and material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED, "finish excludes stateful emission and water")
					textures = [material.albedo_texture,material.roughness_texture,material.normal_texture]
				elif material is ShaderMaterial:
					shader_slots += 1
					check(material.shader == SurfacePass.OPAQUE, "cloth/timber retain opaque surface shader")
					check(float(material.get_shader_parameter("pigment_variation")) > 0. and float(material.get_shader_parameter("pigment_variation")) < 1., "actual shader reduces pigment contrast without erasing grain")
					var relief: Variant = material.get_shader_parameter("height_relief_mm")
					check(relief == null or is_zero_approx(float(relief)), "furniture finish adds no displaced geometry; unset uses shader default zero")
					textures = [material.get_shader_parameter("albedo_tex"),material.get_shader_parameter("rough_tex"),material.get_shader_parameter("normal_tex")]
				for texture: Texture2D in textures:
					if texture != null: maps[texture.resource_path] = texture
	check(shader_slots > 80, "calibrated furniture and bedding shaders deployed")
	for path: String in maps:
		var pixels: Image = maps[path].get_image()
		check(pixels != null and pixels.has_mipmaps(), "real loaded mip chain: " + path.get_file())
	check(MatLib.get_mat("cast_iron").albedo_texture.resource_path.ends_with("T_ai_materials_cast_iron_albedo.png"), "V1 material cache remains original")
	var boiler := world.adapter.resolve("B1_BOILER_01") as BoilerProp
	var coal_material := boiler._firebed_mesh.material_override
	var fire_open := boiler._fire_open
	var ash_open := boiler._ash_open
	var boiler_state := boiler.maintenance_snapshot()
	for opened in [true,false]:
		boiler.set_fire_door_open(opened,0)
		boiler.set_ash_door_open(opened,0)
		check(boiler._fire_open == opened and boiler._ash_open == opened, "original boiler leaf states")
		check(is_equal_approx(boiler._fire_door.rotation.y, deg_to_rad(95. if opened else 0.)), "original fire hinge travel")
		check(boiler._fire_door.get_node("LeafCollision").get_parent() == boiler._fire_door, "fire collision follows original hinge")
	boiler.set_fire_door_open(fire_open,0)
	boiler.set_ash_door_open(ash_open,0)
	check(boiler._firebed_mesh.material_override == coal_material and boiler.maintenance_snapshot() == boiler_state, "boiler heat material and water service retained")
	for actor in owners:
		if actor is RadiatorProp:
			var before: Dictionary = actor.maintenance_snapshot()
			var mesh_id: int = actor._section_multimesh.multimesh.get_instance_id()
			actor.set_supply_position(0.,0.)
			check(is_zero_approx(actor.supply_position), "original radiator supply closes")
			actor.set_supply_position(float(before.supply_position),0.)
			check(actor.maintenance_snapshot()==before and actor._section_multimesh.multimesh.get_instance_id()==mesh_id, "radiator restores state and retains live section buffer")
		elif actor is WasherProp:
			var before: Dictionary = actor.get_service_state()
			var water: Material = actor._water.material_override
			var upper: Node3D = actor._roller_upper
			var operating: bool = actor.state == FunctionalProp.PState.OPERATING
			var warning: float = actor._release_warning
			actor.set_lid_open(true,0)
			actor.set_wringer_swing(75.,0)
			actor.trigger_safety_release()
			actor.set_agitating(true)
			check(actor._lid_open and is_equal_approx(actor._yoke.rotation.y,deg_to_rad(75.)) and is_equal_approx(upper.position.y,.04), "washer lid, wringer swing and release retain working parents")
			actor.set_lid_open(bool(before.lid_open),0)
			actor.set_wringer_swing(float(before.wringer_angle),0)
			actor.set_wringer_gap(float(before.roller_gap))
			actor.set_agitating(operating)
			actor._release_warning = warning
			check(actor.get_service_state()==before,"washer restores complete service state")
			check(actor._water.material_override == water and actor._roller_upper == upper, "washer liquid and roller owners retained")
		elif actor is TapProp:
			var before: Dictionary = actor.get_flow_state()
			var water: Material = actor._basin_water.material_override
			actor.set_hot(true); actor.set_cold(true); actor.set_stopper(true)
			check(actor.get_flow_state().hot and actor.get_flow_state().cold, "original hot and cold controls operate")
			actor.set_hot(bool(before.hot)); actor.set_cold(bool(before.cold)); actor.set_stopper(bool(before.stopper))
			check(actor._basin_water.material_override == water, "water resource identity survives finish and control changes")
			if actor.fixture == "shower":
				var opened: bool = actor.is_curtain_open()
				actor.set_curtain_open(not opened)
				check(actor._curtain_gathered.visible == (not opened), "retained gathered curtain follows control")
				actor.set_curtain_open(opened)
	if capture_enabled:
		for row in [["B1_BOILER_01",Vector3(.6,.03,-2.15),Vector3(0,1.,0),"boiler"],
				["F02_A_RADIATOR_01",Vector3(.15,.03,-1.45),Vector3(0,.46,0),"radiator"],
				["B1_WASHER_01",Vector3(.60,.03,-1.8),Vector3(0,.8,0),"washer"],
				["F04_4B_SHOWER_01",Vector3(0,.03,-1.25),Vector3(0,1.,0),"shower"]]:
			var actor := world.adapter.resolve(str(row[0])) as Node3D
			check(actor != null,"capture owner: " + str(row[0]))
			if actor != null:
				await _city_capture(world,actor.to_global(row[1]),actor.to_global(row[2]),str(row[3]),"production service finish",str(row[0]))
		var washer := world.adapter.resolve("B1_WASHER_01") as WasherProp
		var lid_open: bool = washer._lid_open
		washer.set_lid_open(true,0)
		await _city_capture(world,washer.to_global(Vector3(.55,.03,-1.65)),washer.to_global(Vector3(0,.7,0)),"washer_open","retained zinc tub",str(washer.name))
		washer.set_lid_open(lid_open,0)
	validation_completed = true
	return {"checks":checks,"failures":failures,"owners":owners.size(),"changed_slots":changed_slots,"shader_slots":shader_slots,"loaded_texture_maps":maps.size()}

func validate_after_teardown() -> Dictionary:
	check(validation_completed,"finish validation completed before runtime receipt")
	for ref in retained: check(ref.get_ref()==null,"service finish owner retires")
	var root := ProjectSettings.globalize_path("res://..").simplify_path()
	var head: Array=[]; var digest: Array=[]
	check(OS.execute("git",["-C",root,"rev-parse","HEAD"],head)==0,"record head")
	check(OS.execute("python",[root.path_join("tools/run_receipt.py"),"digest","--root",root],digest)==0,"record runtime digest")
	var passed := failures.is_empty(); var status := "PASS" if passed else "FAIL"
	var path: String=get_script().resource_path
	var receipt := {"schema_version":2,"evidence_kind":"runtime_contract","selector":"v2","production_runtime":true,
		"scope":"Scoped service and household finish overrides: loaded mip chains, deployed opaque pigment shaders, retained service mechanism controls, state restoration and owner retirement. Furniture fit, player approach routes and save reconstruction are not exercised by this module.",
		"execution":{"completed":true,"exit_code":0 if passed else 1,"timed_out":false,"elapsed_s":(Time.get_ticks_msec()-contract_started)/1000.},
		"source":{"test_path":"game/"+path.trim_prefix("res://"),"test_sha256":FileAccess.get_sha256(path),"repository_head":str(head[0]).strip_edges() if not head.is_empty() else "","runtime_inputs_sha256":str(digest[0]).strip_edges() if not digest.is_empty() else ""},
		"contracts":{"production_composition":{"executed":true,"status":status},"save_reconstruction":{"executed":false,"status":"NOT_EXECUTED"},"teardown":{"executed":true,"status":status,"measurement_scope":"runtime_owned","retained_nodes":retained.filter(func(r):return r.get_ref()!=null).size()}},"checks":checks,"failures":failures}
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("owner_service_finish/runtime_contract.json"),FileAccess.WRITE).store_string(JSON.stringify(receipt,"\t"))
	return {"checks":checks,"failures":failures}
