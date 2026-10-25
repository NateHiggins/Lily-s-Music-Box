extends Node3D
## Native/import/mechanism diagnostic. Does not qualify gameplay input/navigation.
var checks: Array[Dictionary] = []
var failures: Array[String] = []
var _finished := false

func check(ok: bool, name: String) -> void:
	checks.append({"name":name, "passed":ok})
	if not ok:
		failures.append(name)
		push_error(name)

func _ready() -> void:
	get_tree().create_timer(90.0).timeout.connect(_diagnostic_deadline)
	_run.call_deferred()

func _diagnostic_deadline() -> void:
	if _finished: return
	check(false, "mechanism diagnostic did not finish within ninety seconds")
	var out := OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(out)
	FileAccess.open(out.path_join("mechanism_diagnostic.json"), FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT", "scope":"Aborted mechanism diagnostic; partial observations are not qualification", "checks":checks, "failures":failures}, "\t"))
	print("COMPANION MECHANISM: aborted diagnostic; ", failures.size(), " failures")
	get_tree().quit(1)

func _run() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var out := OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(out)
	var rig: Node3D = preload("res://scripts/device/companion_mechanism.gd").new()
	add_child(rig)
	check(rig.build(), "native companion and original printer bind")
	if not failures.is_empty(): get_tree().quit(1); return
	rig.set_process(false)
	check(rig.keys.multimesh.instance_count == 40 and rig._key_names.size() == 43, "forty regular keys share one native MultiMesh with three native special sizes")
	var key_batches: Dictionary = {}
	for draw: GeometryInstance3D in rig._key_draws: key_batches[draw.get_instance_id()] = true
	check(key_batches.size() == 4, "all forty-three textured keys use four unscaled native geometry batches")
	check(rig._key_labels.size() == 43 and not rig.key_legends.visible, "physical key legends are present and hidden while closed")
	check(rig.keys.layers == 2, "keys share the original instrument visibility layer")
	var inspector: Node = preload("res://tests/orison_v2_surface_inventory.gd").new()
	var metrics: Node = preload("res://tests/orison_v2_roof_bulkhead_caps_test.gd").new()
	var meshes: Dictionary = {}
	var materials: Dictionary = {}
	var partitions := 0
	for draw: MeshInstance3D in rig.model.find_children("*", "MeshInstance3D", true, false):
		if bool(draw.get_meta("companion_instanced_key", false)): continue
		meshes[str(draw.name)] = inspector._mesh(draw.mesh)
		metrics._check_cap_mapping(draw.mesh, true)
		for surface in draw.mesh.get_surface_count():
			partitions += 1
			var material: Material = draw.get_active_material(surface)
			var row: Dictionary = inspector._material(material)
			materials[str(draw.name) + "/" + str(surface)] = row
			var required: Array = ["albedo_texture", "roughness_texture", "normal_texture"] if material is StandardMaterial3D else ["albedo_tex", "rough_tex", "normal_tex"]
			if material is ShaderMaterial:
				check(material.shader.resource_path == "res://scripts/device/writer_type_decal.gdshader", "retained hot-type shader ABI")
				required = ["steel_albedo", "steel_roughness", "steel_normal", "type_plate"]
			for map: String in required: check(row.maps.has(map), "loaded registered PBR map " + str(draw.name) + "/" + map)
			if material is StandardMaterial3D: check(material.normal_enabled and not material.uv1_triplanar, "native normals use authored UVs " + str(draw.name))
	check(partitions == 59, "all fifty-nine retained and formed-shell material primitives are present")
	var glass := rig.glazing.get_active_material(0) as StandardMaterial3D
	check(glass != null and glass.refraction_enabled and is_equal_approx(glass.refraction_scale, .004), "reading glass retains restrained authored refraction")
	for label: Label3D in [rig.device.teletype.ink, rig.device.teletype.heading, rig.device.teletype.footer]:
		check(label.alpha_cut == Label3D.ALPHA_CUT_DISCARD and not label.no_depth_test, "physical carbon glyphs enter the refracted opaque scene with depth testing")
	var film: Dictionary = inspector._material(rig.glazing_film)
	for map: String in ["albedo_tex", "rough_tex", "normal_tex"]:
		check(film.maps.has(map), "glass film uses loaded registered map " + map)
	rig.set_glass_moisture(.7, .8)
	check(is_equal_approx(float(rig.glazing_film.get_shader_parameter("inside_wet")), .7) and is_equal_approx(float(rig.glazing_film.get_shader_parameter("outside_wet")), .8), "glass exposes separate authoritative face moisture inputs")
	rig.set_glass_moisture(NAN, 0.0)
	check(is_equal_approx(float(rig.glazing_film.get_shader_parameter("outside_wet")), .8), "nonfinite glass input preserves the previous presentation")
	rig.set_glass_moisture(0.0, 0.0)
	await _fit_contacts(rig)
	for failure: String in metrics.failures: check(false, failure)
	for path: String in inspector.texture_rows:
		var texture: Dictionary = inspector.texture_rows[path]
		check(texture.mips and texture.mip_levels == int(log(float(maxi(texture.width, texture.height))) / log(2.0) + .000001), "complete loaded mip chain " + path)
	var pose_records: Array[Dictionary] = []
	for rate in [30, 60, 144]:
		rig.request_keyboard(false)
		rig._process(.30)
		rig.request_keyboard(true)
		for tick in int(ceil(.26 * rate)): rig._process(1.0 / rate)
		check(rig.typing_ready() and is_equal_approx(rig.keyboard.rotation.x, PI * .5), "keyboard reaches exact open stop at " + str(rate) + "Hz")
		check(rig.key_legends.visible, "physical legends are visible on the open keyboard " + str(rate))
		pose_records.append({"hz":rate, "angle":rig.keyboard.rotation.x, "stays":_stays(rig)})
		for label: String in ["Port", "Starboard"]:
			var upper: Node3D = rig._stays[label + "KeyboardStayUpper"]
			var lower: Node3D = rig._stays[label + "KeyboardStayLower"]
			check((upper.transform * Vector3(0, .05, 0)).distance_to(lower.position) < .000001, "support elbow remains attached at " + label + str(rate))
	var key_samples: Array[Dictionary] = []
	for index in rig._key_names.size():
		rig.pulse_key(rig._key_names[index])
		rig._process(.01)
		var current: Transform3D = rig.key_transform(index)
		var home: Transform3D = rig._key_homes[index]
		check(current.origin.z > home.origin.z + .001, "individual key depresses " + str(rig._key_names[index]))
		check(absf(rig._key_labels[index].position.z - current.origin.z + .00225) < .000001, "physical lettering follows depressed cap " + str(rig._key_names[index]))
		key_samples.append({"key":rig._key_names[index], "depression_m":current.origin.z - home.origin.z})
		rig._process(.2)
		check(rig.key_transform(index).origin.distance_to(home.origin) < .000001, "individual key returns " + str(rig._key_names[index]))
	rig.request_keyboard(false)
	rig._process(.10)
	rig.request_keyboard(true)
	rig._process(.04)
	rig.request_keyboard(false)
	rig._process(.3)
	check(is_zero_approx(rig.keyboard_open) and not rig.typing_ready(), "interrupted deployment closes and releases typing readiness")
	var count: int = rig.device.printed_count
	rig.device.set_radio_powered(false, false)
	check(not rig.device.print_telegram_card({"title":"NO RECEPTION", "body":"Suppressed"}) and rig.device.printed_count == count, "original radio owner rejects reception while off")
	rig.device.set_radio_powered(true, false)
	check(rig.device.print_telegram_card({"title":"SERVICE WIRE", "body":"Connection established. The line remains open."}) and rig.device.printed_count == count + 1, "original printer accepts one report after power returns")
	rig.device.teletype.toggle_service_cover()
	await get_tree().create_timer(.4).timeout
	check(rig.device.teletype.service_cover.rotation.x > 1.7, "service lid opens outward from the formed pan")
	rig.device.teletype.toggle_service_cover()
	await get_tree().create_timer(.4).timeout
	check(absf(rig.device.teletype.service_cover.rotation.x) < .00001, "service lid closes on its retained datum")
	var pixels: Node3D = rig.display
	pixels.set_process(false)
	check(pixels.dark.multimesh.instance_count == 384 and pixels.light.multimesh.instance_count == 384, "384 physical bistable squares use two native mesh batches")
	check(pixels.get_children().filter(func(child: Node): return child is GeometryInstance3D).size() == 2, "display has no per-pixel scene nodes")
	var pixel_source: Script = preload("res://scripts/device/companion_tile_display.gd")
	check(pixel_source.expression_pixels("speaking", .25) != pixel_source.expression_pixels("speaking", 1.0), "low-resolution mouth has distinct authored aperture images")
	var pixel_before: PackedByteArray = pixels.target.duplicate()
	check(not pixels.set_pixels(PackedByteArray([1, 0])) and pixels.target == pixel_before, "invalid display image preserves previous target atomically")
	var tile_timings: Array[int] = []
	for rate in [30, 60, 144]:
		pixels.set_expression("content", 0.0, true)
		pixels.set_expression("speaking", 1.0)
		for tick in int(ceil(2.0 * rate)):
			var before := Time.get_ticks_usec()
			pixels._process(1.0 / rate)
			tile_timings.append(Time.get_ticks_usec() - before)
			check(pixels._active.size() <= 32, "tile flip work remains bounded at " + str(rate) + "Hz tick " + str(tick))
		check(pixels.settled(), "tile mouth reaches its exact image at " + str(rate) + "Hz")
		for index in 384:
			check(is_equal_approx(pixels.angles[index], 0.0 if pixels.target[index] != 0 else PI), "tile reaches two-color stop " + str(rate) + "/" + str(index))
	var writes: int = pixels.transform_writes
	for tick in 60: pixels._process(1.0 / 60.0)
	check(pixels.transform_writes == writes and not pixels.is_processing(), "bistable image needs no resting transform writes or simulation")
	var environment := WorldEnvironment.new()
	var state := Environment.new()
	state.background_mode = Environment.BG_COLOR
	state.background_color = Color(.12, .14, .17)
	state.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	state.ambient_light_color = Color(.7, .65, .57)
	state.ambient_light_energy = .7
	environment.environment = state
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-30, -25, 0)
	light.light_energy = .8
	add_child(light)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = .57
	add_child(camera)
	camera.position = Vector3(.36, .29, .65)
	camera.look_at(Vector3(0, -.01, 0))
	camera.make_current()
	for pose: String in ["travel", "typing"]:
		rig.request_keyboard(pose == "typing")
		rig._process(.3)
		for frame in 8: await RenderingServer.frame_post_draw
		check(get_viewport().get_texture().get_image().save_png(out.path_join(pose + ".png")) == OK, "rendered imported " + pose + " pose")
	rig.request_keyboard(false)
	rig._process(.3)
	pixels.set_expression("speaking", 1.0, true)
	for frame in 8: await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(out.path_join("mouth_open.png")) == OK, "rendered actual two-color mouth image")
	var illustration: Array[String] = []
	for row in 12:
		var line := ""
		for column in 32:
			var marked := (row == 2 and column >= 12 and column <= 19) or (row == 3 and column >= 10 and column <= 21) or (row == 4 and column >= 8 and column <= 23) or (row == 5 and column >= 6 and column <= 25) or (column == 15 and row >= 5 and row <= 10) or (row == 10 and column in [16, 17])
			line += "#" if marked else "."
		illustration.append(line)
	check(pixels.show_illustration(illustration, true), "display accepts a simple low-resolution umbrella illustration")
	for frame in 8: await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(out.path_join("illustration.png")) == OK, "rendered physical pixel illustration")
	camera.size = .23
	camera.position = Vector3(.065, .065, .36)
	camera.look_at(Vector3(0, .035, .055))
	var print_deadline := Time.get_ticks_msec() + 10000
	while rig.device.teletype.printing and Time.get_ticks_msec() < print_deadline:
		await get_tree().process_frame
	check(not rig.device.teletype.printing, "original printer completes the glazed reading sample")
	for wet: bool in [false, true]:
		rig.set_glass_moisture(0.0, .8 if wet else 0.0)
		for frame in 8: await RenderingServer.frame_post_draw
		check(get_viewport().get_texture().get_image().save_png(out.path_join("glass_wet.png" if wet else "glass_reading.png")) == OK, "rendered glazed reading sample wet=" + str(wet))
	rig.set_glass_moisture(0.0, 0.0)
	check(rig.failures.is_empty(), "mechanical animation retains all native attachment constraints")
	FileAccess.open(out.path_join("mechanism_diagnostic.json"), FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT", "scope":"Imported model, native UV/PBR/mips and direct animation calls only; no player input, navigation, save or performance qualification", "checks":checks, "failures":failures, "meshes":meshes, "materials":materials, "textures":inspector.texture_rows, "poses":pose_records, "keys":key_samples, "tile_step_usec":tile_timings}, "\t"))
	metrics.free()
	inspector.free()
	print("COMPANION MECHANISM: ", checks.size(), " checks; ", failures.size(), " failures")
	_finished = true
	get_tree().quit(0 if failures.is_empty() else 1)

func _fit_contacts(rig: Node3D) -> void:
	var steel: MeshInstance3D = rig.model.find_child("ShellStudy__ShellSteel", true, false)
	var brass: MeshInstance3D = rig.model.find_child("ShellStudy__ShellBrass", true, false)
	check(steel != null and brass != null, "formed pan and fastening stock resolve")
	if steel == null or brass == null: return
	var bodies: Array[StaticBody3D] = []
	for draw in [steel, brass]:
		var body := StaticBody3D.new()
		body.collision_layer = 1 << 30
		body.collision_mask = 0
		var shape := CollisionShape3D.new()
		shape.shape = draw.mesh.create_trimesh_shape()
		draw.add_child(body)
		body.add_child(shape)
		bodies.append(body)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var space := get_world_3d().direct_space_state
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for point: Vector2 in [Vector2(sx * .1025, sy * .066), Vector2(sx * .063, sy * .093)]:
				for offset: Vector2 in [Vector2(.002, 0), Vector2(-.002, 0), Vector2(0, .002), Vector2(0, -.002)]:
					var at := point + offset
					var faces: Array[float] = []
					for index in 2:
						var start := Vector3(at.x, at.y, .5 if index == 0 else -.5)
						var end := Vector3(at.x, at.y, -.5 if index == 0 else .5)
						var query := PhysicsRayQueryParameters3D.create(rig.model.to_global(start), rig.model.to_global(end), 1 << 30)
						query.exclude = [bodies[1 - index].get_rid()]
						var hit := space.intersect_ray(query)
						check(not hit.is_empty(), "imported fastening bearing exists " + str(point) + str(offset) + str(index))
						if not hit.is_empty(): faces.append(rig.model.to_local(hit.position).z)
					if faces.size() == 2:
						check(absf(faces[0] - .0275) < .00005 and absf(faces[1] - faces[0]) < .00005, "imported guard seats on formed pan " + str(point) + str(offset))
	for body in bodies: body.queue_free()
	await get_tree().physics_frame

func _stays(rig: Node) -> Dictionary:
	var result: Dictionary = {}
	for name: String in rig._stays:
		var part: Node3D = rig._stays[name]
		result[name] = {"origin":str(part.position), "basis":str(part.basis)}
	return result
