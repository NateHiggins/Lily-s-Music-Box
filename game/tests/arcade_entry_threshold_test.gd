extends "res://tests/arcade_all_native_carrier_test.gd"

const Entry := preload("res://scripts/building/orison_v2_arcade_entry_threshold.gd")
const Shell := preload("res://scripts/building/orison_v2_arcade_plaza_shell.gd")
const Gateway := preload("res://assets/building/orison_v2/exterior/passage_gateway.gltf")
const Pavement := preload("res://assets/building/floor_01_cells/site_street_common.gltf")
const LINE := 28.316
const COURT := 28.645
const VANTRY := -9.795

func _inputs() -> Dictionary:
	var result := {}
	for path: String in [Entry.DATA, Shell.DATA, Gateway.resource_path, Pavement.resource_path,
		"res://tests/arcade_entry_threshold_test.gd", "res://tests/ArcadeEntryThresholdTest.tscn",
		"res://data/orison_v2/exterior/street_frame.json", "res://data/building_layout.json",
		"res://scripts/building/orison_v2_arcade_entry_threshold.gd", "res://scripts/building/orison_v2_arcade_plaza_shell.gd",
		"res://scripts/generated/material_sets.gd", "res://shaders/orison_surface.gdshader",
		"res://scripts/building/surface_pass.gd", "res://scripts/material_library.gd",
		"res://tests/orison_v2_roof_bulkhead_caps_test.gd"]:
		result[path] = FileAccess.get_file_as_string(path).replace("\r\n", "\n").sha256_text()
	for path: String in [Entry.ASSET, "res://assets/props/arcade_plaza_shells.glb",
		"res://assets/building/orison_v2/exterior/passage_gateway_subway.bin", "res://assets/building/floor_01_cells/site_street_common.bin"]:
		result[path] = FileAccess.get_sha256(path)
		if FileAccess.file_exists(path+".import"):
			result[path+".import"] = FileAccess.get_file_as_string(path+".import").replace("\r\n","\n").sha256_text()
	for file: String in MatLib.SETS["arcade_terrazzo"].slice(0,3):
		var path := MatLib.TEX+file
		result[path] = FileAccess.get_sha256(path)
		result[path+".import"] = FileAccess.get_file_as_string(path+".import").replace("\r\n","\n").sha256_text()
	return result

func _ray(x: float, z: float) -> Dictionary:
	var point := Vector3(x,0.,z+VANTRY)
	var query := PhysicsRayQueryParameters3D.create(point+Vector3.UP*.14,point-Vector3.UP*.08,1)
	return get_world_3d().direct_space_state.intersect_ray(query)

func _capture() -> void:
	var output := OS.get_environment("SHOT_DIR")
	if output.is_empty() or DisplayServer.get_name() == "headless":
		return
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-58,-17,0)
	add_child(light)
	var camera := Camera3D.new()
	add_child(camera)
	camera.look_at_from_position(Vector3(14.,1.65,LINE+VANTRY-.68), Vector3(14.,.05,COURT+VANTRY+.55))
	camera.make_current()
	for frame in 4: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(output.path_join("entry_threshold.png")) == OK,
		"loaded gateway threshold view")

func run() -> void:
	var started := Time.get_ticks_msec()
	var inputs := _inputs()
	OS.add_logger(logger)
	var root := Node3D.new()
	root.position.z = VANTRY
	add_child(root)
	var street := Pavement.instantiate() as Node3D
	# The street common source includes the same gateway draws. Use only the
	# original pavement batch here and publish the separate gateway exactly once.
	for node: Node in street.get_children():
		if not str(node.name).begins_with("F01_OWN_STREET_furniture_concrete"):
			node.free()
	root.add_child(street)
	root.add_child(Gateway.instantiate())
	var shell := Shell.new().prepare(JSON.parse_string(FileAccess.get_file_as_string(Shell.DATA)))
	var entry := Entry.prepare()
	if check(shell != null and entry != null,"actual native shell and threshold admit"):
		root.add_child(shell)
		await get_tree().physics_frame
		await get_tree().physics_frame
		check(_ray(14., (LINE+COURT)/2).is_empty(), "missing threshold exposes real gap")
		root.add_child(entry)
		await get_tree().physics_frame
		await get_tree().physics_frame
		for x: float in [12.75,14.,15.25]:
			var sidewalk := _ray(x,LINE-.005)
			check(not sidewalk.is_empty() and street.is_ancestor_of(sidewalk.collider) and absf(sidewalk.position.y-.01)<.00011,
				"retained pavement meets threshold at " + str(x))
			for step in 9:
				var t := (step+1)/10.
				var hit := _ray(x,lerpf(LINE,COURT,t))
				check(not hit.is_empty() and entry.is_ancestor_of(hit.collider) and absf(hit.position.y-(1.-t)*.01)<.00011,
					"walkable threshold gradient " + str(Vector2(x,t)))
			var court := _ray(x,COURT+.005)
			check(not court.is_empty() and shell.is_ancestor_of(court.collider) and absf(court.position.y)<.00011,
				"prepared court receives threshold at " + str(x))
		var draw := entry.get_node(Entry.DRAW) as MeshInstance3D
		var metrics := preload("res://tests/orison_v2_domestic_native_test.gd").new()
		metrics._check_cap_mapping(draw.mesh,true)
		check(metrics.failures.is_empty(),"loaded threshold UV/tangent metric")
		metrics.free()
		for channel: String in ["albedo_tex","rough_tex","normal_tex"]:
			var texture := (draw.material_override as ShaderMaterial).get_shader_parameter(channel) as Texture2D
			check(texture != null and texture.get_image().has_mipmaps(),"loaded threshold " + channel + " mip chain")
		await _capture()
	else:
		if shell != null: shell.free()
		if entry != null: entry.free()
	root.free()
	await get_tree().process_frame
	check(_inputs() == inputs,"entry inputs stayed frozen")
	check(logger.errors.is_empty(),"engine errors " + str(logger.errors))
	OS.remove_logger(logger)
	var output := OS.get_environment("SHOT_DIR")
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
		var result := {"schema_version":2,"evidence_kind":"runtime_contract","production_runtime":false,"selector":"v2",
			"scope":"Nearby real street pavement, gateway and prepared court floor continuity, source bindings and imported threshold surfaces.",
			"execution":{"completed":true,"exit_code":int(not failures.is_empty()),"timed_out":false,"elapsed_s":(Time.get_ticks_msec()-started)/1000.},
			"contracts":{"entry_threshold":{"executed":true,"status":"PASS" if failures.is_empty() else "FAIL"}},
			"source":{"test_path":"game/tests/arcade_entry_threshold_test.gd","inputs":inputs},
			"checks":checks,"failures":failures,"engine_errors":logger.errors}
		FileAccess.open(output.path_join("runtime_contract.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("ARCADE ENTRY THRESHOLD RESULT: %d checks / %d failures" % [checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
