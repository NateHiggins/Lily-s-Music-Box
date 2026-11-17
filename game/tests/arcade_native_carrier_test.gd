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
const Shell := preload("res://scripts/building/orison_v2_arcade_plaza_shell.gd")
const Player := preload("res://scripts/player/player_controller.gd")
const CONTRACT := "res://tests/fixtures/arcade_diner_native_projection.json"
const SOURCE := "res://data/building_layout.json"
const CELL := "res://assets/building/floor_01_cells/shop_luncheonette.gltf"
var failures: Array[String] = []
var checks := 0
var logger = preload("res://tests/guide_bell_error_capture.gd").new()
var donor: Node3D
var placed: Node3D
var raw: Node3D
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

func _rebuild_custody(layout: Dictionary, contract: Dictionary) -> void:
	var source := _new_donor(layout)
	if not check(source != null, "actual donor for explicit rebuild custody"):
		return
	var before := _snapshot(source)
	var selected: Dictionary = contract.entries[0]
	var original_draw: MeshInstance3D
	for draw: MeshInstance3D in source.find_children("*", "MeshInstance3D", true, false):
		if str(draw.get_meta(str(selected.part_meta), "")) == str(selected.part_id): original_draw = draw
	if not check(original_draw != null, "explicit retained rebuild source identified"):
		source.free()
		return
	var deferred := contract.duplicate(true)
	deferred.entries.remove_at(0)
	var retained := selected.duplicate(true)
	retained.material_key = str(original_draw.get_meta("material_key"))
	retained.source_role = "TEST_ONLY_CUSTODY_NO_INSTALLATION"
	retained.reason = "Verify that an explicit reconstruction obligation never discards source stock."
	deferred.rebuild_entries = [retained]
	for kind: String in ["frame", "count", "material", "unexplained", "duplicate", "double_disposition"]:
		var bad := deferred.duplicate(true)
		match kind:
			"frame": bad.rebuild_entries[0].source_transform[0][3] += .1
			"count": bad.rebuild_entries[0].triangles += 1
			"material": bad.rebuild_entries[0].material_key = "wrong"
			"unexplained": bad.rebuild_entries[0].reason = ""
			"duplicate": bad.rebuild_entries.append(bad.rebuild_entries[0])
			"double_disposition": bad.entries.append(selected)
		var refused := Carrier.new()
		var result := refused.extract_native(source, bad)
		check(result == null and not refused.errors.is_empty(), "reject invalid native rebuild " + kind)
		if result != null: result.free()
		check(_unchanged(source, before), "rebuild refusal leaves entire donor intact " + kind)
	var helper := Carrier.new()
	var result := helper.extract_native(source, deferred)
	if check(result != null, "explicitly retained rebuild admits complete custody: " + str(helper.errors)):
		var still_owned: Array[Dictionary] = []
		for row: Dictionary in before:
			if source.is_ancestor_of(row.node): still_owned.append(row)
		check(_unchanged(source, still_owned) and source.is_ancestor_of(original_draw), "all remaining raw/rebuild buffers and frames stay on detached source")
		check(result.find_children("*", "MeshInstance3D", true, false).size() == contract.entries.size()-1, "only declared transfer parts leave source")
		check(result.get_meta("arcade_native_rebuild_inventory") == [str(selected.model)+"/"+str(selected.part_id)], "published metadata retains exact unresolved rebuild identity")
		check(not source.is_inside_tree() and not result.is_inside_tree(), "rebuild test publishes no unfinished room")
		observations.append({"kind":"explicit_rebuild_custody", "retained_rebuild_parts":1, "unchanged_remaining_meshes":still_owned.size(), "scope":"test-only disposition, not installation or source disposal"})
		result.free()
	source.free()

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
	_rebuild_custody(layout, contract)
	if not failures.is_empty():
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
	check(placed.find_children("*", "MeshInstance3D", true, false).size() == contract.entries.size() \
		and placed.find_children("*", "Label3D", true, false).size() == contract.labels.size(), "all declared native parts and labels transferred once")
	check(placed.get_child_count() == contract.models.size(), "stable native model containers retained without donor FitJobs")
	var moved := {}
	for row in before:
		var draw: MeshInstance3D = row.node
		if not placed.is_ancestor_of(draw):
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
		check(placed.is_ancestor_of(words) and words.text == row.text and words.font == row.font \
			and words.font_size == row.font_size and words.pixel_size == row.pixel_size and words.modulate == row.colour,
			"same authored menu/font/appearance retained " + str(words.name))
	for entry: Dictionary in contract.labels:
		var words := placed.get_node_or_null(NodePath(str(entry.model)+"/"+str(entry.target_name))) as Label3D
		check(words != null and helper._same(words.transform, helper._matrix(entry.target_transform)), "authored menu composed target exact " + str(entry.label_id))
	var remaining_before := _snapshot(donor)
	var native_before := _snapshot(placed)
	for kind: String in ["missing", "duplicate", "false_record", "false_bounds", "wrong_target", "wrong_count", "binary_hash"]:
		var bad := contract.duplicate(true)
		match kind:
			"missing": bad.raw_stocks.pop_back()
			"duplicate": bad.raw_stocks.append(bad.raw_stocks[-1].duplicate(true))
			"false_record": bad.raw_stocks[-1].source_record.h += .01
			"false_bounds": bad.raw_stocks[-1].source_low[0] += .1
			"wrong_target": bad.raw_stocks[-1].target_low[2] += 9.795
			"wrong_count": bad.raw_stocks[-1].expected_triangles += 1
			"binary_hash":
				for path: String in bad.source_bindings:
					if path.ends_with(".bin"): bad.source_bindings[path].sha256 = "wrong"
		var rejected := Carrier.new()
		var result := rejected.extract_raw(donor, bad)
		check(result == null and not rejected.errors.is_empty(), "reject raw " + kind)
		if result != null: result.free()
		check(_unchanged(donor, remaining_before) and _unchanged(placed, native_before), "raw refusal preserves donor and projected native geometry " + kind)
		if not failures.is_empty():
			await finish()
			return
	raw = helper.extract_raw(donor, contract)
	if not check(raw != null, "complete original raw stock recovered: " + str(helper.errors)):
		_raw_source_probe(donor, contract.raw_stocks[0])
		await finish()
		return
	check(raw.get_child_count() == contract.raw_stock_ids.size(), "complete raw stock identity inventory")
	check(int(raw.get_meta("retained_source_triangles")) == 144, "all144 original raw triangles retained")
	check(_unchanged(donor, remaining_before), "raw recovery does not mutate remaining source buffers")
	check(Carrier.new().extract_raw(donor, contract) == null, "same raw donor cannot be recovered twice")
	for draw: MeshInstance3D in raw.find_children("*", "MeshInstance3D", true, false):
		var source_draw := donor.get_node(NodePath(str(draw.get_meta("arcade_raw_source_path")))) as MeshInstance3D
		var surfaces: Array = draw.get_meta("arcade_raw_source_surfaces")
		for surface in draw.mesh.get_surface_count():
			var a := draw.mesh.surface_get_arrays(surface)
			var b := source_draw.mesh.surface_get_arrays(int(surfaces[surface]))
			for channel in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT, Mesh.ARRAY_TEX_UV]:
				check(a[channel].to_byte_array() == b[channel].to_byte_array(), "raw source attribute buffer exact %s/%d" % [draw.get_parent().name, channel])
			check(draw.mesh.surface_get_material(surface) == source_draw.mesh.surface_get_material(int(surfaces[surface])) \
				and draw.get_surface_override_material(surface) == source_draw.get_surface_override_material(int(surfaces[surface])), "raw original material resource retained")
		check(draw.mesh.shadow_mesh == null, "no unrelated legacy shadow mesh")
		var shapes := draw.find_children("*", "CollisionShape3D", true, false)
		check(shapes.size() == 1 and shapes[0].shape is ConcavePolygonShape3D, "raw native collision present")
		if shapes.size() == 1:
			var expected := ConcavePolygonShape3D.new()
			expected.set_faces(draw.mesh.get_faces())
			check(shapes[0].shape.get_faces().to_byte_array() == expected.get_faces().to_byte_array(), "raw collision matches full rendered selection under current engine construction")
	placed.add_child(raw)
	var shell_spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Shell.DATA))
	var shell_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/arcade_plaza_shells_contract.json"))
	check(shell_contract.schema == "orison.v2.arcade-plaza-shell-contract.v1" and shell_contract.asset_sha256 == shell_spec.asset_sha256, "shell test contract binds actual native payload")
	var optical_recipe: Dictionary = {}
	for recipe: Dictionary in shell_spec.materials:
		if str(recipe.id) == "glazing": optical_recipe = recipe.runtime_optics
	for kind: String in ["asset", "missing", "duplicate", "owner", "material", "optical_map"]:
		var bad := shell_spec.duplicate(true)
		match kind:
			"asset": bad.asset_sha256 = "changed"
			"missing": bad.native_parts.pop_back()
			"duplicate": bad.native_parts.append(bad.native_parts[0])
			"owner": bad.native_parts[0].owner = "unregistered"
			"material": bad.materials[0].catalog_key = "unregistered"
			"optical_map":
				for recipe: Dictionary in bad.materials:
					if str(recipe.id) == "glazing": recipe.runtime_optics.normal_tex = "res://wrong_normal.png"
		var rejected := Shell.new()
		var result := rejected.prepare(bad)
		check(result == null and not rejected.errors.is_empty(), "reject malformed shell " + kind)
		if result != null: result.free()
	var shell_loader := Shell.new()
	var shell := shell_loader.prepare(shell_spec)
	if not check(shell != null, "native shell admitted: " + str(shell_loader.errors)):
		await finish()
		return
	var finish_frames: Array = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/arcade_door_frames.json")).frames
	var bad_trim := shell_contract.duplicate(true)
	bad_trim.trade_floors.pop_back()
	check(not preload("res://scripts/building/orison_v2_shop_millwork.gd").mount_prepared(shell,bad_trim,finish_frames), "refuse incomplete prepared room inventory before mutation")
	check(shell.find_children("StandardWallMillwork","Node3D",true,false).is_empty(), "refused millwork leaves shell unchanged")
	for kind: String in ["foreign_cell","duplicate_role","wrong_angle"]:
		var bad_frames := finish_frames.duplicate(true)
		match kind:
			"foreign_cell": bad_frames[0].cell="not_a_shop"
			"duplicate_role": bad_frames[2].cell=bad_frames[0].cell
			"wrong_angle": bad_frames[0].opening_angle_deg=45
		check(not preload("res://scripts/building/orison_v2_shop_millwork.gd").mount_prepared(shell,shell_contract,bad_frames), "refuse wrong millwork swing declaration " + kind)
		check(shell.find_children("StandardWallMillwork","Node3D",true,false).is_empty(), "wrong swing leaves all rooms unchanged " + kind)
	check(preload("res://scripts/building/orison_v2_shop_millwork.gd").mount_prepared(shell,shell_contract,finish_frames), "native profile kit fitted to new sales and stock rooms")
	check(not preload("res://scripts/building/orison_v2_shop_millwork.gd").mount_prepared(shell,shell_contract,finish_frames), "duplicate prepared millwork refused")
	var trim_rooms := 0
	var trim_instances := 0
	for cell: Node3D in shell.get_children():
		var trim := cell.get_node_or_null("StandardWallMillwork")
		if trim == null: continue
		trim_rooms += trim.get_child_count()
		for batch: MultiMeshInstance3D in trim.find_children("*","MultiMeshInstance3D",true,false):
			trim_instances += batch.multimesh.instance_count
			check(batch.multimesh.mesh != null and batch.multimesh.use_custom_data, "native profile and metric instance data " + str(batch.name))
			var material := batch.material_override as ShaderMaterial
			check(material != null and material.shader.resource_path == "res://shaders/v2_millwork_stock.gdshader", "existing stock shader owns fitted millwork")
			for key: String in ["albedo_tex","normal_tex","rough_tex"]:
				var texture := material.get_shader_parameter(key) as Texture2D
				check(texture != null and texture.get_image().has_mipmaps(), "fitted millwork loaded custom map mips " + key)
	check(trim_rooms == 22 and trim_instances > 0, "millwork covers all22expanded sales/stock rooms")
	observations.append({"kind":"prepared_millwork","rooms":trim_rooms,"instances":trim_instances,"source_disposal_authorized":false})
	placed.add_child(shell)
	check(shell.get_child_count() == 12, "shell preserves passage and eleven cell identities")
	var metrics := preload("res://tests/orison_v2_domestic_native_test.gd").new()
	for draw: MeshInstance3D in shell.find_children("*", "MeshInstance3D", true, false):
		metrics._check_cap_mapping(draw.mesh, true)
		check(draw.mesh.get_surface_count() == 1 and draw.find_children("*", "CollisionShape3D", true, false).size() == 1, "native shell draw has exact collider")
		var arrays := draw.mesh.surface_get_arrays(0)
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var valid_uv := uv.size() == vertices.size()
		for start in range(0, indices.size(), 3):
			var a := uv[indices[start]]
			var b := uv[indices[start+1]]
			var c := uv[indices[start+2]]
			valid_uv = valid_uv and a.is_finite() and b.is_finite() and c.is_finite() and absf((b-a).cross(c-a)) > 0.0
		check(valid_uv, "native shell finite noncollapsed UV charts")
		var material := draw.get_active_material(0) as ShaderMaterial
		var optical := draw.has_meta("arcade_shell_optical_role")
		check(material != null and (material.shader.resource_path == "res://shaders/lamp_glass_surface.gdshader" if optical else int(material.get_shader_parameter("uv_mode")) == 0), "shell primary maps use registered UV or clear optical owner")
		if optical and material != null:
			var recipe: Dictionary = optical_recipe
			check(is_equal_approx(float(material.get_shader_parameter("surface_roughness")), .06), "clear optical microroughness retained")
			check(str(draw.get_meta("material_key")) == str(recipe.material_key) and is_equal_approx(float(material.get_shader_parameter("normal_strength")), float(recipe.normal_strength)), "runtime clear recipe identity and normal strength match declaration")
			for parameter: String in ["rough_tex", "normal_tex"]:
				var texture := material.get_shader_parameter(parameter) as Texture2D
				check(texture != null and texture.resource_path == str(recipe[parameter]), "exact declared runtime optical map " + parameter)
		if material != null:
			for parameter: String in (["rough_tex", "normal_tex"] if optical else ["albedo_tex", "rough_tex", "normal_tex"]):
				var texture := material.get_shader_parameter(parameter) as Texture2D
				check(texture != null and texture.get_image().has_mipmaps(), "shell loaded custom map mip chain " + parameter)
	check(metrics.failures.is_empty(), "strict loaded shell metric charts/normals/tangent derivatives")
	observations.append({"kind": "loaded_shell_metrics", "failures": metrics.failures.duplicate(), "draws": shell.find_children("*", "MeshInstance3D", true, false).size()})
	metrics.free()
	_trade_floor_sampling(shell, shell_spec, shell_contract)
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
	_shell_apertures(shell_contract)
	_shell_glazing(shell_contract)
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
		"raw_stocks": contract.raw_stock_ids.size(), "raw_triangles": raw.get_meta("retained_source_triangles"),
		"external_root_z_m": -9.795, "fabrication_source_sha256": input_hash})
	check(FileAccess.get_sha256(SOURCE) == input_hash, "protected fabrication bytes unchanged")
	await finish()

func _trade_floor_sampling(shell: Node3D, spec: Dictionary, contract: Dictionary) -> void:
	check(contract.get("trade_floors", []).size() == 22, "all original sales/stock floors retained")
	var top_triangles := 0
	var draws := 0
	var maximum_phase_error := 0.0
	var families := {}
	for draw: MeshInstance3D in shell.find_children("*", "MeshInstance3D", true, false):
		var key := str(draw.get_meta("material_key", ""))
		if key not in ["floor_oak_b", "quarry_tile_b", "linoleum_b", "terrazzo_b", "concrete_b"]: continue
		draws += 1
		families[key] = true
		var material := draw.get_active_material(0) as ShaderMaterial
		if not check(material != null, "floor surface owner " + key): continue
		var tile := float(MatLib.SETS[key][3])
		var scale: Vector2 = material.get_shader_parameter("mesh_uv_scale")
		var offset: Vector2 = material.get_shader_parameter("mesh_uv_offset")
		check(scale.is_equal_approx(Vector2.ONE / tile), "floor physical repeat " + key)
		check(offset.is_equal_approx(Vector2(0,1.0-1.0/tile)), "source glTF V phase " + key)
		check(int(material.get_shader_parameter("rough_channel")) == 1, "actual GREEN roughness sampling " + key)
		check(is_equal_approx(float(material.get_shader_parameter("normal_scale")), .35) and is_equal_approx(float(material.get_shader_parameter("roughness_mul")), 1.0), "source floor PBR strengths " + key)
		check(material.get_shader_parameter("albedo_color") == Color.WHITE, "source floor pixels without additional tint " + key)
		for channel: int in 3:
			var texture: Texture2D = material.get_shader_parameter(["albedo_tex","rough_tex","normal_tex"][channel])
			check(texture != null and texture.resource_path.get_file() == str(MatLib.SETS[key][channel]) and texture.get_image().has_mipmaps(), "exact retained floor map with loaded mips %s/%d" % [key,channel])
		var arrays := draw.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var valid := true
		for start in range(0, indices.size(), 3):
			var a := vertices[indices[start]]
			var b := vertices[indices[start+1]]
			var c := vertices[indices[start+2]]
			if absf(a.y) > .000001 or absf(b.y) > .000001 or absf(c.y) > .000001: continue
			top_triangles += 1
			for i: int in 3:
				var index := indices[start+i]
				var point := vertices[index]
				# Independently measured original11glTF floors: U=X/t,V=1+Z/t.
				var expected := Vector2(point.x/tile,1.0+point.z/tile)
				var delta := uv[index]*scale+offset-expected
				delta -= delta.round()
				maximum_phase_error = maxf(maximum_phase_error, maxf(absf(delta.x),absf(delta.y)))
				valid = valid and absf(delta.x)<.000005 and absf(delta.y)<.000005
		check(valid, "loaded floor top triangle phase matches original source " + str(draw.name))
	check(top_triangles == 44 and families.size() == 5, "all44 top triangles and five trade finishes examined")
	for kind: String in ["nonfinite_phase","unregistered_phase"]:
		var bad := spec.duplicate(true)
		for recipe: Dictionary in bad.materials:
			if recipe.get("catalog_key") == "floor_oak_b":
				if kind == "nonfinite_phase": recipe.uv_offset = [INF,0]
				else: recipe.roughness_channel = "red"
		var loader := Shell.new()
		var result := loader.prepare(bad)
		check(result == null and not loader.errors.is_empty(), "refuse floor sampling mutation " + kind)
		if result != null: result.free()
	observations.append({"kind":"loaded_trade_floor_sampling","draws":draws,"top_triangles":top_triangles,"families":families.keys(),"maximum_repeat_phase_error":maximum_phase_error})

func _shell_apertures(spec: Dictionary) -> void:
	# Empty framed openings only. Real directional input, opposing NPC traffic,
	# leaves/locks/hours and service routes still need installed qualification.
	var shape := CapsuleShape3D.new()
	shape.radius = Player.BODY_RADIUS
	shape.height = Player.STANDING_HEIGHT
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 1
	query.margin = .001
	var origin: Array = spec.source_origin_blender_m
	for shop: Dictionary in spec.shops:
		for stock in [false, true]:
			var along_y := str(shop.front) in ["west", "east"]
			var at: Array = shop.entrance_center_m
			if stock:
				var cut: Array = shop.partition_rect_m
				along_y = float(cut[3])-float(cut[1]) > float(cut[2])-float(cut[0])
				at = shop.get("stock_opening_center_m", [(float(cut[0])+float(cut[2]))*.5, (float(cut[1])+float(cut[3]))*.5])
			var centre := Vector3(float(origin[0])+float(at[0]), shape.height*.5+.01, -float(origin[1])+float(at[1]))
			var normal := Vector3.RIGHT if along_y else Vector3.BACK
			for step in 11:
				query.transform = Transform3D(Basis.IDENTITY, placed.to_global(centre+normal*(float(step)/10.0-.5)))
				check(get_world_3d().direct_space_state.intersect_shape(query).is_empty(), "full standing capsule clears empty frame %s/%s/%d" % [shop.id, "stock" if stock else "front", step])
			query.transform = Transform3D(Basis.IDENTITY, placed.to_global(centre-normal*.5))
			query.motion = normal
			var fractions := get_world_3d().direct_space_state.cast_motion(query)
			check(fractions.size() == 2 and fractions[0] == 1.0 and fractions[1] == 1.0, "continuous capsule sweep clears empty frame %s/%s" % [shop.id, stock])
			query.motion = Vector3.ZERO
			var tangent := Vector3.BACK if along_y else Vector3.RIGHT
			var width := float(spec.stock_frame_clear_m if stock else spec.front_frame_clear_m)
			query.transform = Transform3D(Basis.IDENTITY, placed.to_global(centre+tangent*(width*.5+.2)+normal*.06))
			check(not get_world_3d().direct_space_state.intersect_shape(query).is_empty(), "actual frame/wall blocks adjacent capsule %s/%s" % [shop.id, stock])

func _shell_glazing(spec: Dictionary) -> void:
	var origin: Array = spec.source_origin_blender_m
	var panes := 0
	for stock: Dictionary in spec.closed_stocks:
		if str(stock.material) not in spec.optical_material_ids: continue
		panes += 1
		var centre: Vector3
		var normal: Vector3
		if stock.has("pane_probe"):
			var c: Array = stock.pane_probe.centre
			var n: Array = stock.pane_probe.normal
			# Source probe is PLAN(u,v,height); exporter maps it to Godot(x,y,z).
			centre = Vector3(float(origin[0])+float(c[0]), float(origin[2])+float(c[2]), -float(origin[1])+float(c[1]))
			normal = Vector3(float(n[0]), float(n[2]), float(n[1])).normalized()
		else:
			var r: Array = stock.plan_rect_m
			centre = Vector3(float(origin[0])+(float(r[0])+float(r[2]))*.5,
				(float(stock.bottom_m)+float(stock.top_m))*.5, -float(origin[1])+(float(r[1])+float(r[3]))*.5)
			normal = Vector3.RIGHT if float(r[2])-float(r[0]) < float(r[3])-float(r[1]) else Vector3.BACK
		for side in [-1.0, 1.0]:
			var query := PhysicsRayQueryParameters3D.create(placed.to_global(centre+normal*.12*side), placed.to_global(centre-normal*.12*side), 1)
			var hit := get_world_3d().direct_space_state.intersect_ray(query)
			var draw: MeshInstance3D = hit.collider.get_parent() as MeshInstance3D if not hit.is_empty() else null
			check(draw != null and draw.has_meta("arcade_shell_optical_role"), "actual pane with no hidden opaque wall %s/%s" % [stock.name, side])
	check(panes > 0, "actual facade/transom/borrowed/vault glazing exists")
	observations.append({"kind":"two_sided_glazing_apertures", "panes":panes})

func _raw_source_probe(cell: Node3D, row: Dictionary) -> void:
	var helper := Carrier.new()
	var low := helper._point(row.source_low)
	var high := helper._point(row.source_high)
	var box := AABB(low, high - low).grow(.005)
	var rows: Array = []
	for draw: MeshInstance3D in cell.find_children("*", "MeshInstance3D", true, false):
		var frame := helper._relative(draw, cell)
		for surface in draw.mesh.get_surface_count():
			var arrays := draw.mesh.surface_get_arrays(surface)
			var points: Array = []
			var largest := 0.0
			for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
				var point := frame * vertex
				if not box.has_point(point): continue
				var expected := Vector3(low.x if absf(point.x-low.x)<absf(point.x-high.x) else high.x,
					low.y if absf(point.y-low.y)<absf(point.y-high.y) else high.y,
					low.z if absf(point.z-low.z)<absf(point.z-high.z) else high.z)
				largest = maxf(largest, point.distance_to(expected))
				points.append([point.x, point.y, point.z])
			if not points.is_empty(): rows.append({"draw":str(draw.name),"surface":surface,"nearby_points":points,"largest_corner_error_m":largest})
	observations.append({"kind":"raw_selector_failure_probe","stock":row.id,"source_low":row.source_low,"source_high":row.source_high,"rows":rows})

func _view() -> void:
	var bounds := AABB()
	var native_bounds := AABB()
	var native_first := true
	var first := true
	for draw: MeshInstance3D in placed.find_children("*", "MeshInstance3D", true, false):
		var box := draw.global_transform * draw.mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
		if draw.has_meta("arcade_native_identity"):
			native_bounds = box if native_first else native_bounds.merge(box)
			native_first = false
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
	camera.look_at_from_position(bounds.get_center() + Vector3(.7, .9, 1).normalized()*bounds.size.length()*1.05, bounds.get_center())
	camera.make_current()
	for frame in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	check(get_viewport().get_texture().get_image().save_png(output.path_join("plaza_shell.png")) == OK, "complete unfinished shell frame")
	# Eye-level receiving stations expose roof joints and apparatus that an
	# overhead frame would hide behind the newly complete shop ceilings.
	for view: Dictionary in [
		{"file":"native_diner.png", "eye":Vector3(21.5,1.65,62.0), "at":Vector3(25.0,1.65,64.0)},
		{"file":"nave.png", "eye":Vector3(14.0,1.65,43.0), "at":Vector3(14.0,5.0,61.0)},
		{"file":"court.png", "eye":Vector3(14.0,1.65,31.0), "at":Vector3(14.0,5.0,43.0)}]:
		camera.look_at_from_position(placed.to_global(view.eye), placed.to_global(view.at))
		for frame in 6: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		check(get_viewport().get_texture().get_image().save_png(output.path_join(view.file)) == OK, "receiving construction view " + str(view.file))

func finish() -> void:
	if is_instance_valid(donor): donor.free()
	if is_instance_valid(raw) and raw.get_parent() == null: raw.free()
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
