extends Node3D
## Loaded-asset diagnostic only; not held performance, gameplay or art acceptance.
const Brush := preload("res://scripts/props/drum_brush.gd")
var failures: Array[String] = []
var checks := 0
var logger = preload("res://tests/guide_bell_error_capture.gd").new()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		print("DRUM BRUSH: FAIL ", message)

func _ready() -> void:
	run.call_deferred()

func run() -> void:
	OS.add_logger(logger)
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Brush.DATA))
	var malformed: Dictionary = source.contacts.duplicate(true)
	malformed.grip.axis = [0, 0, 2]
	check(not Brush._contacts_valid(malformed), "reject nonunit grip frame")
	malformed = source.contacts.duplicate(true)
	malformed.fan_tips.positions[0] = [10, 0, 0.3]
	check(not Brush._contacts_valid(malformed), "reject detached wire-tip datum")
	malformed = source.contacts.duplicate(true)
	malformed.grip.position = [0, INF, 0]
	check(not Brush._contacts_valid(malformed), "reject nonfinite contact datum")
	var pair: Array[Node3D] = []
	for hand in 2:
		var brush := Brush.create()
		check(brush != null, "native brush loads " + str(hand))
		if brush == null:
			continue
		add_child(brush)
		pair.append(brush)
		brush.position = Vector3(float(hand) * 0.15 - 0.075, 0, 0)
		var contacts: Dictionary = brush.get_meta("contacts")
		check(contacts.fan_tips.positions.size() == 45, "all source wire-tip datums present")
		check(is_equal_approx(float(contacts.grip.radius_m), 0.0065), "handle grip radius is measured")
		check(Brush._point(contacts.grip.axis) == Vector3.BACK and Brush._point(contacts.fan_contact.normal) == Vector3.DOWN, "explicit grip axis and contact face")
		check(contacts.fan_root.position[2] > contacts.grip.position[2], "fan is forward of the grip")
		check(float(contacts.fan_contact.half_width_m) > 0.05, "fan has useful sweep width")
		check(not str(brush.get_meta("coordinates")).is_empty() and not str(brush.get_meta("integration")).is_empty(), "frame and scope retained")
		check(brush.find_children("*", "CollisionObject3D", true, false).is_empty(), "no carrying or prop physics")
		var draws := brush.find_children("*", "MeshInstance3D", true, false)
		check(draws.size() == 2, "only wood and nickel draw partitions")
		var loaded_points: Array[Vector3] = []
		for draw: MeshInstance3D in draws:
			for surface in draw.mesh.get_surface_count():
				var arrays := draw.mesh.surface_get_arrays(surface)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				for point in vertices:
					loaded_points.append(brush.global_transform.affine_inverse() * (draw.global_transform * point))
				var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
				var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
				check(uv.size() == vertices.size() and tangents.size() == vertices.size() * 4, "imported UVs and tangents retained")
				var mat := draw.mesh.surface_get_material(surface) as StandardMaterial3D
				check(mat != null and not mat.uv1_triplanar, "physical UV projection")
				if mat == null:
					continue
				for texture: Texture2D in [mat.albedo_texture, mat.roughness_texture, mat.normal_texture]:
					check(texture != null and texture.get_image().has_mipmaps(), "custom map has loaded mip chain")
		var all_tips := true
		for row in contacts.fan_tips.positions:
			var tip := Brush._point(row)
			var nearest := INF
			for point in loaded_points:
				nearest = minf(nearest, point.distance_to(tip))
			# A datum lies on the centre of a wire's capped cross-section:
			# its nearest source vertex is one actual 0.141mm wire radius away.
			all_tips = all_tips and nearest < 0.0002
		check(all_tips, "every source tip remains attached to imported wire geometry")
	# Independent instances must not share mutable material resources.
	if pair.size() == 2:
		var a := pair[0].find_children("*", "MeshInstance3D", true, false)
		var b := pair[1].find_children("*", "MeshInstance3D", true, false)
		check(a[0].mesh.surface_get_material(0) != b[0].mesh.surface_get_material(0), "pair material mutations are isolated")
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.08, 0.09, 0.11)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color.WHITE
	settings.ambient_light_energy = 0.5
	environment.environment = settings
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -30, 0)
	add_child(light)
	var camera := Camera3D.new()
	add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 0.48
	camera.look_at_from_position(Vector3(0.22, 0.50, 0.45), Vector3(0, 0, 0.15))
	camera.make_current()
	for frame in 6:
		await get_tree().process_frame
	var directory := OS.get_environment("SHOT_DIR")
	check(not directory.is_empty(), "explicit capture directory")
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(directory)
		await RenderingServer.frame_post_draw
		check(get_viewport().get_texture().get_image().save_png(directory.path_join("loaded_pair.png")) == OK, "loaded pair frame saved")
	for brush in pair:
		brush.free()
	for frame in 3:
		await get_tree().process_frame
	check(logger.errors.is_empty(), "no engine errors")
	OS.remove_logger(logger)
	if not directory.is_empty():
		FileAccess.open(directory.path_join("diagnostic.json"), FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT", "checks":checks, "failures":failures, "engine_errors":logger.errors, "human_played":false,"artistically_accepted":false,"scope":"Loaded brush pair and maps only; held motion and production performance remain open."}, "\t"))
	print("DRUM BRUSH RESULT: %d checks / %d failures" % [checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
