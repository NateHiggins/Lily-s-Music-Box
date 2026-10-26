extends Node3D
## Native/import/mechanism diagnostic. Does not qualify gameplay input/navigation.
var checks: Array[Dictionary] = []
var failures: Array[String] = []
var _finished := false
var _contact_observations: Array[Dictionary] = []

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
	var pane := rig.model.find_child("ShellStudy__ShellGlass", true, false) as MeshInstance3D
	var tray := rig.model.find_child("CompanionKeyboard__CompanionSteel", true, false) as MeshInstance3D
	check(absf(pane.mesh.get_aabb().size.x - .137) < .00001, "compact case preserves full original reading window width")
	check(tray.mesh.get_aabb().size.x < .157, "compact keyboard is approximately display width")
	check(rig._rotors.size() == 2 and absf(rig._rotors[0].position.x) < .00001 and absf(rig._rotors[1].position.x) < .00001
		and rig._rotors[0].position.y > rig._rotors[1].position.y + .04, "two native helical rotors share one vertically separated coaxial crown")
	rig._advance_mechanism(.016)
	check(rig._rotors[0].rotation.y * rig._rotors[1].rotation.y < 0.0, "coaxial upper and lower screw assemblies actually counter rotate")
	var rotor_heights: Array[Vector2] = []
	var swept_radius := 0.0
	for rotor: Node3D in rig._rotors:
		var heights := Vector2(INF, -INF)
		for draw: MeshInstance3D in rotor.find_children("*", "MeshInstance3D", true, false):
			for surface in draw.mesh.get_surface_count():
				var vertices: PackedVector3Array = draw.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
				for vertex: Vector3 in vertices:
					var point: Vector3 = rig.model.to_local(draw.to_global(vertex))
					heights.x = minf(heights.x, point.y); heights.y = maxf(heights.y, point.y)
					swept_radius = maxf(swept_radius, Vector2(point.x, point.z + .012).length())
		rotor_heights.append(heights)
	check(rotor_heights[0].x - rotor_heights[1].y > .005 and swept_radius < .0768, "imported coaxial assemblies retain axial separation and radial guard clearance throughout rotation")
	var aerial := rig.model.find_child("Aerial", true, false) as Node3D
	var aerial_radius := INF
	for draw: MeshInstance3D in aerial.find_children("*", "MeshInstance3D", true, false):
		for surface in draw.mesh.get_surface_count():
			var vertices: PackedVector3Array = draw.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for vertex: Vector3 in vertices:
				var point: Vector3 = rig.model.to_local(draw.to_global(vertex))
				if point.y > .139 and point.y < .225:
					aerial_radius = minf(aerial_radius, Vector2(point.x, point.z + .012).length())
	check(is_finite(aerial_radius) and aerial_radius > swept_radius + .003, "deployed native aerial clears the complete screw sweep with a positive measured margin")
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
				if material.shader.resource_path == "res://scripts/device/writer_type_decal.gdshader":
					check(true, "retained hot-type shader ABI")
					required = ["steel_albedo", "steel_roughness", "steel_normal", "type_plate"]
				else:
					check(material.shader.resource_path == "res://scripts/device/night_stock.gdshader", "registered Night Stock paper shader ABI")
					required = ["albedo_tex", "rough_tex", "normal_tex"]
			for map: String in required: check(row.maps.has(map), "loaded registered PBR map " + str(draw.name) + "/" + map)
			if material is StandardMaterial3D: check(material.normal_enabled and not material.uv1_triplanar, "native normals use authored UVs " + str(draw.name))
	check(partitions == 63, "all retained, formed-shell and sliding-carriage material primitives are present")
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
	_focus_bearing_gap(rig)
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
		check(is_equal_approx(rig.keyboard.position.z, .065) and is_equal_approx(rig.keyboard_carriage.position.z, -.045), "keyboard and hinge carriage retract together by forty-five millimetres at " + str(rate) + "Hz")
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
	FileAccess.open(out.path_join("mechanism_diagnostic.json"), FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT", "scope":"Imported model, native UV/PBR/mips and direct animation calls only; no player input, navigation, save or performance qualification", "checks":checks, "failures":failures, "meshes":meshes, "materials":materials, "textures":inspector.texture_rows, "poses":pose_records, "contacts":_contact_observations, "keys":key_samples, "tile_step_usec":tile_timings}, "\t"))
	metrics.free()
	inspector.free()
	print("COMPANION MECHANISM: ", checks.size(), " checks; ", failures.size(), " failures")
	_finished = true
	get_tree().quit(0 if failures.is_empty() else 1)

func _fit_contacts(rig: Node3D) -> void:
	var steel := rig.model.find_child("ShellStudy__ShellSteel", true, false) as MeshInstance3D
	var brass := rig.model.find_child("ShellStudy__ShellBrass", true, false) as MeshInstance3D
	check(steel != null and brass != null, "formed pan and fastening stock resolve")
	if steel == null or brass == null: return
	# Visual manufacturing contact, not gameplay collision. The retained probe
	# demonstrates metre-scale engine rays skip these small native triangles.
	# Condition arithmetic only; never scale the asset or loosen the 50 um seat.
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for point: Vector2 in [Vector2(sx * .1025, sy * .066), Vector2(sx * .063, sy * .093)]:
				for offset: Vector2 in [Vector2(.002, 0), Vector2(-.002, 0), Vector2(0, .002), Vector2(0, -.002)]:
					var center := Vector2(sx * .08091, point.y) if absf(point.x) > .09 else point
					var at := center + offset
					var pan: Variant = _contact_z(steel, rig.model, at, true)
					var guard: Variant = _contact_z(brass, rig.model, at, false)
					check(pan != null and guard != null, "conditioned imported fastening faces exist " + str(at))
					check(_seated(pan, guard), "imported guard seats on formed pan within fifty micrometres " + str(at))
					var home := brass.transform
					brass.position.z += .003
					var detached: Variant = _contact_z(brass, rig.model, at, false)
					brass.transform = home
					check(detached != null and not _seated(pan, detached), "three-millimetre detached guard is rejected " + str(at))
					if pan != null and detached != null:
						check(absf(float(detached) - float(pan) - .003) < .00005, "negative control measures the actual introduced gap " + str(at))
					_contact_observations.append({"point":[at.x, at.y], "pan_z":pan, "guard_z":guard, "detached_guard_z":detached})
	await get_tree().process_frame

func _focus_bearing_gap(rig: Node3D) -> void:
	var wheel := rig.model.find_child("FocusWheel__Brass", true, false) as MeshInstance3D
	var fixed := rig.model.find_child("ShellStudy__ShellBrass", true, false) as MeshInstance3D
	var bearing: Variant = _contact_x(fixed, rig.model, .14, .07)
	var knob: Variant = _contact_x(wheel, rig.model, .07, .14)
	check(bearing != null and knob != null, "imported reading knob and bored bearing expose their actual axial faces")
	if bearing == null or knob == null: return
	check(absf(float(knob)-float(bearing)-.001) < .00005, "reading knob retains its original one-millimetre running clearance after case narrowing")
	var pivot: Node3D = wheel.get_parent()
	var home := pivot.position
	pivot.position.x -= .003
	var penetrated: Variant = _contact_x(wheel, rig.model, .07, .14)
	pivot.position = home
	check(penetrated != null and float(penetrated)-float(bearing) < -.0019, "axial clearance negative control detects a knob driven three millimetres into its bearing")

func _contact_x(draw: MeshInstance3D, model: Node3D, from_x: float, to_x: float) -> Variant:
	var start := draw.to_local(model.to_global(Vector3(from_x, .0414, 0))) * 1000.0
	var end := draw.to_local(model.to_global(Vector3(to_x, .0414, 0))) * 1000.0
	var faces := draw.mesh.get_faces()
	var nearest := INF
	var result: Variant = null
	for index in range(0, faces.size(), 3):
		var hit: Variant = Geometry3D.segment_intersects_triangle(start, end, faces[index]*1000.0, faces[index+1]*1000.0, faces[index+2]*1000.0)
		if hit is Vector3 and start.distance_squared_to(hit) < nearest:
			nearest = start.distance_squared_to(hit)
			result = model.to_local(draw.to_global(hit/1000.0)).x
	return result

func _seated(pan: Variant, guard: Variant) -> bool:
	return pan != null and guard != null and absf(float(pan) - .0275) < .00005 and absf(float(guard) - float(pan)) < .00005

func _contact_z(draw: MeshInstance3D, model: Node3D, at: Vector2, front: bool) -> Variant:
	const MILLIMETRES := 1000.0
	var start := draw.to_local(model.to_global(Vector3(at.x, at.y, .5 if front else -.5))) * MILLIMETRES
	var end := draw.to_local(model.to_global(Vector3(at.x, at.y, -.5 if front else .5))) * MILLIMETRES
	var faces := draw.mesh.get_faces()
	var nearest := INF
	var result: Variant = null
	for index in range(0, faces.size(), 3):
		var hit: Variant = Geometry3D.segment_intersects_triangle(start, end, faces[index] * MILLIMETRES, faces[index + 1] * MILLIMETRES, faces[index + 2] * MILLIMETRES)
		if hit is not Vector3: continue
		var distance := start.distance_squared_to(hit)
		if distance < nearest:
			nearest = distance
			result = model.to_local(draw.to_global(hit / MILLIMETRES)).z
	return result

func _stays(rig: Node) -> Dictionary:
	var result: Dictionary = {}
	for name: String in rig._stays:
		var part: Node3D = rig._stays[name]
		result[name] = {"origin":str(part.position), "basis":str(part.basis)}
	return result
