extends Node3D
## Native-only source/placement/lifecycle diagnostic. No full room installation,
## commerce, raw-stock retirement, player/NPC passage or art acceptance.
const Carrier := preload("res://scripts/building/orison_v2_arcade_native_carrier.gd")
const Seating := preload("res://scripts/building/orison_v2_shop_seating.gd")
const Counter := preload("res://scripts/building/orison_v2_diner_counter.gd")
const Till := preload("res://scripts/building/orison_v2_diner_till.gd")
const Backbar := preload("res://scripts/building/orison_v2_diner_backbar.gd")
const Urns := preload("res://scripts/building/orison_v2_diner_urns.gd")
const Apparatus := preload("res://scripts/building/orison_v2_diner_apparatus.gd")
const Overhead := preload("res://scripts/building/orison_v2_diner_overhead.gd")
const CONTRACT := "res://tests/fixtures/arcade_diner_native_projection.json"
const SOURCE := "res://data/building_layout.json"
const CELL := "res://assets/building/floor_01_cells/shop_luncheonette.gltf"
var failures: Array[String] = []
var checks := 0
var logger = preload("res://tests/guide_bell_error_capture.gd").new()
var donor: Node3D
var placed: Node3D
var preview := false
var original: Dictionary
var original_text := ""
var original_mouse: int
var output := ""
var observations: Array[Dictionary] = []

func check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok:
		failures.append(message)
		print("ARCADE NATIVE CARRIER FAIL: ", message)
	return ok

func _ready() -> void:
	run.call_deferred()

func _new_donor(layout: Dictionary) -> Node3D:
	var cell := (load(CELL) as PackedScene).instantiate() as Node3D
	cell.name = "shop_luncheonette"
	var ok := Seating.mount_cell(cell, layout) and Counter.mount_cell(cell, layout) \
		and Till.mount_cell(cell, layout) and Backbar.mount_cell(cell, layout) and Urns.mount_cell(cell, layout) \
		and Apparatus.mount_cell(cell, layout) and Overhead.mount_cell(cell, layout)
	if not ok:
		cell.free()
		return null
	return cell

func _signature(draw: MeshInstance3D) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	for surface in draw.mesh.get_surface_count():
		var arrays := draw.mesh.surface_get_arrays(surface)
		for channel in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_INDEX]:
			if arrays[channel] != null:
				hash.update(arrays[channel].to_byte_array())
	return hash.finish().hex_encode()

func _snapshot(cell: Node3D) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var helper := Carrier.new()
	for draw: MeshInstance3D in cell.find_children("*", "MeshInstance3D", true, false):
		var shapes := {}
		for shape: CollisionShape3D in draw.find_children("*", "CollisionShape3D", true, false):
			shapes[str(draw.get_path_to(shape))] = shape.shape
		rows.append({"node": draw, "path": str(cell.get_path_to(draw)), "mesh": draw.mesh,
			"signature": _signature(draw), "pose": helper._relative(draw, cell), "shapes": shapes})
	return rows

func _unchanged(cell: Node3D, rows: Array[Dictionary]) -> bool:
	var helper := Carrier.new()
	for row in rows:
		var draw: MeshInstance3D = row.node
		if not is_instance_valid(draw) or str(cell.get_path_to(draw)) != str(row.path) or draw.mesh != row.mesh \
			or _signature(draw) != str(row.signature) or not helper._same(helper._relative(draw, cell), row.pose):
			return false
	return true

func _labels(cell: Node3D) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var helper := Carrier.new()
	for words: Label3D in cell.find_children("*", "Label3D", true, false):
		rows.append({"node": words, "path": str(cell.get_path_to(words)), "pose": helper._relative(words, cell),
			"text": words.text, "font": words.font, "font_size": words.font_size, "pixel_size": words.pixel_size, "colour": words.modulate})
	return rows

func _labels_unchanged(cell: Node3D, rows: Array[Dictionary]) -> bool:
	var helper := Carrier.new()
	for row in rows:
		var words: Label3D = row.node
		if not is_instance_valid(words) or str(cell.get_path_to(words)) != row.path \
			or not helper._same(helper._relative(words, cell), row.pose) or words.text != row.text or words.font != row.font:
			return false
	return true

func run() -> void:
	OS.add_logger(logger)
	original = RealityState.data
	original_text = JSON.stringify(original, "", true, true)
	original_mouse = Input.mouse_mode
	output = OS.get_environment("SHOT_DIR")
	if not check(not output.is_empty() and DirAccess.make_dir_recursive_absolute(output) == OK, "explicit output"):
		await finish()
		return
	var input_hash := FileAccess.get_sha256(SOURCE)
	var contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONTRACT))
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	preview = RealityState.begin_preview_campaign(self)
	if not check(preview, "exclusive preview campaign"):
		await finish()
		return
	donor = _new_donor(layout)
	if not check(donor != null, "actual current seven-model source fittings"):
		await finish()
		return
	var before := _snapshot(donor)
	var before_labels := _labels(donor)
	# Every late refusal must be atomic: earlier native parts remain untouched.
	for kind: String in ["missing", "duplicate", "source_pose", "scaled", "double_frame", "nonfinite", "asset_hash", "recipe_hash", "missing_label", "label_text", "label_frame"]:
		var bad := contract.duplicate(true)
		match kind:
			"missing": bad.entries.pop_back()
			"duplicate": bad.entries.append(bad.entries[-1].duplicate(true))
			"source_pose": bad.entries[-1].source_transform[0][3] += 0.1
			"scaled":
				for axis in 3:
					for column in 3: bad.entries[-1].delta_transform[axis][column] *= 2.0
			"double_frame": bad.entries[-1].target_transform[2][3] += 9.795
			"nonfinite": bad.entries[-1].target_transform[0][3] = INF
			"asset_hash": bad.native_assets[bad.native_assets.keys()[0]] = "wrong"
			"recipe_hash": bad.source_bindings[bad.source_bindings.keys()[0]].sha256 = "wrong"
			"missing_label": bad.labels.pop_back()
			"label_text": bad.labels[-1].text = "CHANGED MENU"
			"label_frame": bad.labels[-1].target_transform[0][3] += 0.1
		var rejected := Carrier.new()
		var result := rejected.extract_native(donor, bad)
		check(result == null and not rejected.errors.is_empty(), "reject " + kind)
		if result != null:
			result.free()
		check(_unchanged(donor, before) and _labels_unchanged(donor, before_labels), "refusal preserves complete donor " + kind)
		if not failures.is_empty():
			await finish()
			return
	var helper := Carrier.new()
	placed = helper.extract_native(donor, contract)
	if not check(placed != null, "complete native projection: " + str(helper.errors)):
		await finish()
		return
	check(placed.get_parent() == null and not placed.is_inside_tree(), "result remains unpublished")
	check(is_instance_valid(donor) and not donor.is_inside_tree(), "raw source carrier retained off-tree for disposition")
	var second := Carrier.new()
	check(second.extract_native(donor, contract) == null, "same donor cannot be extracted twice")
	check(placed.get_child_count() == contract.entries.size() + contract.labels.size(), "all declared native parts and labels transferred once")
	var moved := {}
	for row in before:
		var draw: MeshInstance3D = row.node
		if draw.get_parent() != placed:
			continue
		check(draw.mesh == row.mesh and _signature(draw) == str(row.signature), "native mesh/attributes exact " + str(draw.name))
		check(draw.owner == null and not draw.has_meta("original_meshes"), "no serialized/donor ownership " + str(draw.name))
		for shape_path in row.shapes:
			check(draw.get_node(NodePath(shape_path)).shape == row.shapes[shape_path], "collision resource retained " + str(draw.name))
		moved[str(draw.name)] = draw
	for entry: Dictionary in contract.entries:
		var draw := moved.get(str(entry.target_name)) as MeshInstance3D
		check(draw != null and helper._same(draw.transform, helper._matrix(entry.target_transform)), "composed native target exact " + str(entry.part_id))
	for row in before_labels:
		var words: Label3D = row.node
		check(words.get_parent() == placed and words.text == row.text and words.font == row.font \
			and words.font_size == row.font_size and words.pixel_size == row.pixel_size and words.modulate == row.colour,
			"same authored menu/font/appearance retained " + str(words.name))
	for entry: Dictionary in contract.labels:
		var words := placed.get_node_or_null(NodePath(str(entry.target_name))) as Label3D
		check(words != null and helper._same(words.transform, helper._matrix(entry.target_transform)), "authored menu composed target exact " + str(entry.label_id))
	# This diagnostic retires the remaining donor ONLY after recording its raw
	# custody. It does not establish the full installer's raw-stock disposition.
	var raw_remaining := donor.find_children("*", "MeshInstance3D", true, false).size()
	check(raw_remaining > 0, "remaining raw/architectural source was not silently discarded")
	donor.free()
	donor = null
	placed.position.z = -9.795
	add_child(placed)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var hits := 0
	for entry: Dictionary in contract.entries:
		if not str(entry.part_id).ends_with("__countertop"):
			continue
		var draw: MeshInstance3D = moved[str(entry.target_name)]
		var bounds := draw.mesh.get_aabb()
		var point := bounds.get_center()
		point.y = bounds.end.y
		var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(draw.to_global(point) + Vector3.UP * .05, draw.to_global(point) - Vector3.UP * .05, 1))
		if not hit.is_empty() and draw.is_ancestor_of(hit.collider):
			hits += 1
	check(hits > 0, "native counter collision moves with its actual drawing")
	await _view()
	observations.append({"parts": moved.size(), "raw_donor_meshes": raw_remaining, "native_collision_hits": hits,
		"external_root_z_m": -9.795, "fabrication_source_sha256": input_hash})
	check(FileAccess.get_sha256(SOURCE) == input_hash, "protected fabrication bytes unchanged")
	await finish()

func _view() -> void:
	var bounds := AABB()
	var first := true
	for draw: MeshInstance3D in placed.find_children("*", "MeshInstance3D", true, false):
		var box := draw.global_transform * draw.mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(.1, .11, .13)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = .6
	add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -35, 0)
	add_child(light)
	var camera := Camera3D.new()
	add_child(camera)
	camera.fov = 60
	camera.look_at_from_position(bounds.get_center() + Vector3(7, 6, 7), bounds.get_center())
	camera.make_current()
	for frame in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(output.path_join("native_diner.png")) == OK, "placed native fittings frame")

func finish() -> void:
	if is_instance_valid(donor): donor.free()
	if is_instance_valid(placed): placed.free()
	if preview:
		check(RealityState.end_preview_campaign(self) and is_same(RealityState.data, original) \
			and JSON.stringify(original, "", true, true) == original_text, "exact campaign object/content restored")
	Input.mouse_mode = original_mouse
	for frame in 3: await get_tree().process_frame
	check(logger.errors.is_empty(), "no engine/teardown errors")
	OS.remove_logger(logger)
	if not output.is_empty():
		FileAccess.open(output.path_join("diagnostic.json"), FileAccess.WRITE).store_string(JSON.stringify({"evidence_class": "INERT",
			"checks": checks, "failures": failures, "engine_errors": logger.errors, "observations": observations,
			"human_played": false, "artistically_accepted": false,
			"scope": "Current Diner native-only detached carrier/projection; no full room/commerce/raw-stock installation or residency acceptance."}, "\t"))
	print("ARCADE NATIVE CARRIER RESULT: %d checks / %d failures" % [checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
