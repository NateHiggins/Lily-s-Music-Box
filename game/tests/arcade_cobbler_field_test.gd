extends "res://tests/arcade_all_native_carrier_test.gd"
## Nearby loaded support test, not complete arcade/startup/art acceptance.
const Field := preload("res://scripts/building/orison_v2_arcade_cobbler_field.gd")
var holder: Node3D

func run() -> void:
	OS.add_logger(logger)
	RealityState.persistence_enabled = false
	old_mouse = Input.mouse_mode
	original = RealityState.data
	original_text = JSON.stringify(original, "", true, true)
	preview = RealityState.begin_preview_campaign(self)
	if not check(preview, "exclusive preview campaign"):
		await done()
		return
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/building_layout.json"))
	var roster: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONTRACT))
	var contract: Dictionary
	for item: Dictionary in roster.cells:
		if item.cell == "shop_shoe_rebuilding": contract = item
	var cell := (load(str(contract.cell_source)) as PackedScene).instantiate() as Node3D
	cell.name = str(contract.cell)
	for mount: Dictionary in contract.mounts:
		var arguments: Array = []
		for argument: String in mount.arguments:
			arguments.append(cell if argument == "cell" else layout)
		check(bool(load(str(mount.wrapper)).callv(str(mount.method), arguments)), "actual original fitting owner " + str(mount.family))
	var helper := Carrier.new()
	var projected := helper.extract_native(cell, contract)
	if not check(projected != null, "actual relocated apparatus projection: " + str(helper.errors)):
		cell.free()
		await done()
		return
	var snapshot := _snapshot(cell, helper)
	var moved_before := _snapshot(projected, helper)
	var spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Field.DATA))
	var support: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/arcade_cobbler_field_native.json")).support
	for kind: String in ["schema", "asset", "binding", "substituted_binding", "missing_witness", "duplicate_witness", "disposal"]:
		var bad := spec.duplicate(true)
		match kind:
			"schema": bad.schema = "wrong"
			"asset": bad.asset_sha256 = "wrong"
			"binding": bad.source_bindings["res://data/building_layout.json"].sha256 = "wrong"
			"substituted_binding":
				bad.source_bindings.erase("res://data/building_layout.json")
				bad.source_bindings["res://project.godot"] = {"kind":"lf", "sha256":FileAccess.get_file_as_string("res://project.godot").replace("\r\n", "\n").sha256_text()}
			"missing_witness": bad.source_parts.pop_back()
			"duplicate_witness": bad.source_parts[1] = bad.source_parts[0].duplicate(true)
			"disposal": bad.source_disposal_authorized = true
		var refused := Field.new()
		var rejected := refused.prepare(bad, cell, contract)
		check(rejected == null and not refused.errors.is_empty(), "refuse field " + kind)
		if rejected != null: rejected.free()
	var originals: Array[Dictionary] = []
	for row: Dictionary in contract.rebuild_entries:
		if not str(row.part_id).begins_with("storm_shop_shoe_rebuilding_dust_felt__"): continue
		var draw := _part(cell, row)
		originals.append({"draw":draw,"material":draw.material_override})
		var wrong := draw.get_active_material(0).duplicate() as StandardMaterial3D
		wrong.albedo_texture = MatLib.get_mat("metal").albedo_texture
		draw.material_override = wrong
	var rejected_helper := Field.new()
	var wrong_maps := rejected_helper.prepare(spec, cell, contract)
	check(wrong_maps == null and not rejected_helper.errors.is_empty(), "matching wrong donor maps refused")
	if wrong_maps != null: wrong_maps.free()
	for old: Dictionary in originals: old.draw.material_override = old.material
	var field_helper := Field.new()
	var field := field_helper.prepare(spec, cell, contract)
	if not check(field != null, "actual fitted supporting field: " + str(field_helper.errors)):
		projected.free()
		cell.free()
		await done()
		return
	for pair: Array in [[cell, snapshot], [projected, moved_before]]:
		for key: int in pair[1]:
			var old: Dictionary = pair[1][key]
			check(old.node.mesh == old.mesh and _signature(old.node) == old.signature and helper._same(helper._relative(old.node, pair[0]), old.pose) and old.node.material_override == old.material_override, "field preparation preserves original geometry/frame/material " + str(old.node.name))
	check(field.get_meta("arcade_native_successors").size() == 2 and not field.get_meta("source_disposal_authorized"), "both retained donor fields have named successor without disposal")
	var draw := field.get_node("CobblerSupportingFelt") as MeshInstance3D
	var metrics := preload("res://tests/orison_v2_domestic_native_test.gd").new()
	metrics._check_cap_mapping(draw.mesh, true)
	check(metrics.failures.is_empty(), "strict loaded field UV/normal/tangent derivatives: " + str(metrics.failures))
	metrics.free()
	print("COBBLER STAGE: loaded metric check complete")
	var material := draw.material_override as ShaderMaterial
	check(material != null and int(material.get_shader_parameter("uv_mode")) == 0 and material.get_meta("v2_owner_finish") == "shop/linen", "original linen maps use shop recipe and authored UV")
	for key: String in ["albedo_tex", "rough_tex", "normal_tex"]:
		var texture := material.get_shader_parameter(key) as Texture2D
		check(texture != null and texture.get_image().has_mipmaps(), "loaded custom field map mips " + key)
		print("COBBLER STAGE: loaded ", key)
	var shape := draw.get_node("ActualNativeSupportingField").get_child(0) as CollisionShape3D
	var expected := draw.mesh.create_trimesh_shape()
	check(shape.shape.get_faces().to_byte_array() == expected.get_faces().to_byte_array(), "actual engine-created native triangle collider")
	print("COBBLER STAGE: collider verified")
	holder = Node3D.new()
	holder.position.z = -9.795
	add_child(holder)
	holder.add_child(projected)
	holder.add_child(field)
	var shell_helper := preload("res://scripts/building/orison_v2_arcade_plaza_shell.gd").new()
	var shell_spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/arcade_plaza_shells.json"))
	var shell := shell_helper.prepare(shell_spec)
	print("COBBLER STAGE: shell prepared")
	if check(shell != null, "actual prepared shell/floor: " + str(shell_helper.errors)): holder.add_child(shell)
	var excluded: Array[RID] = []
	for body: CollisionObject3D in projected.find_children("*", "CollisionObject3D", true, false): excluded.append(body.get_rid())
	await get_tree().physics_frame
	print("COBBLER STAGE: physics publication1")
	await get_tree().physics_frame
	print("COBBLER STAGE: physics publication2")
	var hits: Array = []
	for row: Dictionary in support.felt_contacts:
		var p := helper._point(row.target_point)
		var query := PhysicsRayQueryParameters3D.create(holder.to_global(p + Vector3.UP * .002), holder.to_global(p - Vector3.UP * .02), 1, excluded)
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		check(not hit.is_empty() and draw.is_ancestor_of(hit.collider) and absf(hit.position.y - p.y) < .00001, "actual field supports native foot " + str(row.id))
		hits.append({"id":row.id,"point":row.target_point,"hit":not hit.is_empty(),"field":not hit.is_empty() and draw.is_ancestor_of(hit.collider)})
	for row: Dictionary in support.floor_contacts:
		var p := helper._point(row.target_point)
		var query := PhysicsRayQueryParameters3D.create(holder.to_global(p + Vector3.UP * .02), holder.to_global(p - Vector3.UP * .02), 1, excluded)
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		check(not hit.is_empty() and not draw.is_ancestor_of(hit.collider) and absf(hit.position.y) < .00001, "actual floor foot remains clear of felt " + str(row.id))
	observations.append({"kind":"native_support_contacts","felt":support.felt_contacts.size(),"floor":support.floor_contacts.size(),"hits":hits,"external_vantry_once":holder.position.z})
	await render_review(shell, projected)
	cell.free()
	await done()

func render_review(shell: Node3D, projected: Node3D) -> void:
	var output := OS.get_environment("SHOT_DIR")
	if output.is_empty(): return
	DirAccess.make_dir_recursive_absolute(output)
	# Diagnostic cutaway: retain actual floor/material but hide roof/walls for
	# the nearby support view. Physics and native source buffers stay untouched.
	for draw: MeshInstance3D in shell.find_children("*", "MeshInstance3D", true, false):
		draw.visible = draw.get_meta("arcade_shell_owner", "") == "shop_shoe_rebuilding" and str(draw.get_meta("material_key", "")) in ["floor_oak_b", "quarry_tile_b", "linoleum_b", "terrazzo_b", "concrete_b"]
	preload("res://scripts/building/orison_v2_owner_finishes.gd").new().apply_shop_cell(projected)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(.1, .11, .13)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = .65
	add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -35, 0)
	add_child(light)
	var camera := Camera3D.new()
	add_child(camera)
	camera.make_current()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	for shot: Dictionary in [
		{"name":"overview.png", "eye":Vector3(12,10,54), "at":Vector3(5.3,.4,46.8), "size":9.5},
		{"name":"supports.png", "eye":Vector3(8,3.7,51), "at":Vector3(4.9,.4,47.5), "size":5.5}]:
		camera.size = float(shot.size)
		camera.look_at_from_position(holder.to_global(shot.eye), holder.to_global(shot.at))
		for frame in 4: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		check(get_viewport().get_texture().get_image().save_png(output.path_join(str(shot.name))) == OK, "loaded support cutaway " + str(shot.name))

func done() -> void:
	if is_instance_valid(holder): holder.free()
	if preview:
		check(RealityState.end_preview_campaign(self) and is_same(RealityState.data, original) and JSON.stringify(original, "", true, true) == original_text, "exact campaign object/content restored")
	Input.mouse_mode = old_mouse
	for frame in 3: await get_tree().process_frame
	check(logger.errors.is_empty(), "no engine/teardown errors")
	OS.remove_logger(logger)
	var output := OS.get_environment("SHOT_DIR")
	if not output.is_empty():
		DirAccess.make_dir_recursive_absolute(output)
		FileAccess.open(output.path_join("diagnostic.json"), FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Nearby actual native cobbler support/material/retained source test; not installed arcade, play/save or artistic acceptance","checks":checks,"failures":failures,"engine_errors":logger.errors,"observations":observations},"\t"))
	print("ARCADE COBBLER FIELD RESULT: %d checks / %d failures" % [checks, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
