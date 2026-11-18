extends Node3D
## Loaded original fitting owners and detached source custody only. No room,
## input, service, save, surface appearance or source-disposal acceptance.
const Carrier := preload("res://scripts/building/orison_v2_arcade_native_carrier.gd")
const Portraits := preload("res://scripts/building/orison_v2_photo_portraits.gd")
const CONTRACT := "res://tests/fixtures/arcade_all_native_projection.json"
var failures: Array[String] = []
var observations: Array = []
var checks := 0
var logger = preload("res://tests/guide_bell_error_capture.gd").new()
var original: Dictionary
var original_text := ""
var old_mouse: int
var preview := false
var raw_contracts: Dictionary = {}

func check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok:
		failures.append(message)
		print("ALL ARCADE NATIVE FAIL: ", message)
	return ok

func _ready() -> void:
	run.call_deferred()

func _signature(draw: MeshInstance3D) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	for surface in draw.mesh.get_surface_count():
		var arrays := draw.mesh.surface_get_arrays(surface)
		for channel in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_INDEX]:
			if arrays[channel] != null: hash.update(arrays[channel].to_byte_array())
	return hash.finish().hex_encode()

func _snapshot(root: Node3D, helper: RefCounted) -> Dictionary:
	var result := {}
	for draw: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		result[draw.get_instance_id()] = {"node":draw, "mesh":draw.mesh, "signature":_signature(draw),
			"pose":helper._relative(draw, root), "material_override":draw.material_override}
	return result

func _part(root: Node3D, row: Dictionary) -> MeshInstance3D:
	var model := root.get_node_or_null(NodePath(str(row.model)))
	if model == null: return null
	for draw: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if str(draw.get_meta(str(row.part_meta), "")) == str(row.part_id): return draw
	return null

func _auxiliary_snapshot(root: Node3D, contract: Dictionary) -> Dictionary:
	var result := {}
	for row: Dictionary in contract.get("auxiliary_entries", []):
		var path := str(row.model)+"/"+str(row.node_path)
		var node := root.get_node(NodePath(path)) as Node3D
		var properties := {}
		for key: String in row.properties: properties[key] = node.get(key)
		var record := {"node":node,"parent":node.get_parent(),"pose":node.transform,"properties":properties}
		if node is MeshInstance3D:
			record.mesh = node.mesh
			record.material = node.material_override
		result[path] = record
	return result

func _raw(cell: Node3D, native: Node3D, helper: RefCounted, spec: Dictionary) -> bool:
	var before := _snapshot(cell,helper)
	var native_before := _snapshot(native,helper)
	# A false original-node witness must refuse without changing either source.
	var bad := spec.duplicate(true)
	bad.raw_stocks[0].source_selections[0].node = "unregistered_original_node"
	var refused: Node3D = helper.extract_raw(cell,bad)
	check(refused == null and not helper.errors.is_empty(), "raw exact original-node witness enforced " + str(spec.cell))
	if refused != null: refused.free()
	var raw := helper.extract_raw(cell,spec) as Node3D
	var ok := check(raw != null, "complete original raw stock %s: %s" % [spec.cell,helper.errors])
	for snapshot: Dictionary in [before,native_before]:
		for key: int in snapshot:
			var old: Dictionary = snapshot[key]
			var owner: Node3D = cell if snapshot == before else native
			check(old.node.mesh == old.mesh and _signature(old.node) == old.signature and helper._same(helper._relative(old.node,owner),old.pose), "raw attempt preserves original mesh/buffers/frame " + str(old.node.name))
	if raw != null:
		check(raw.get_child_count() == spec.raw_stock_ids.size(), "complete original stock IDs " + str(spec.cell))
		check(int(raw.get_meta("retained_source_triangles")) == int(spec.expected_triangles), "complete original raw triangles " + str(spec.cell))
		for group: Node3D in raw.get_children():
			var rows: Array = spec.raw_stocks.filter(func(row: Dictionary) -> bool: return str(row.id) == str(group.name))
			check(rows.size() == 1, "exact declared raw stock " + str(group.name))
			for draw: MeshInstance3D in group.find_children("*","MeshInstance3D",true,false):
				var source := cell.get_node(NodePath(str(draw.get_meta("arcade_raw_source_path")))) as MeshInstance3D
				check(helper._same(draw.transform,helper._matrix(rows[0].delta_transform)*helper._relative(source,cell)), "raw target applied exactly once " + str(group.name))
				var surfaces: Array = draw.get_meta("arcade_raw_source_surfaces")
				for surface in draw.mesh.get_surface_count():
					var a := draw.mesh.surface_get_arrays(surface)
					var b := source.mesh.surface_get_arrays(int(surfaces[surface]))
					for channel in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_TANGENT,Mesh.ARRAY_TEX_UV]:
						check(a[channel].to_byte_array() == b[channel].to_byte_array(), "exact raw original attribute " + str(group.name)+"/"+str(channel))
					check(draw.mesh.surface_get_material(surface) == source.mesh.surface_get_material(int(surfaces[surface])) and draw.get_surface_override_material(surface) == source.get_surface_override_material(int(surfaces[surface])) and draw.material_override == source.material_override, "exact raw original material " + str(group.name))
				var shapes := draw.find_children("*","CollisionShape3D",true,false)
				check(shapes.size() == 1 and shapes[0].shape is ConcavePolygonShape3D, "raw original selected collision " + str(group.name))
				if shapes.size() == 1:
					var expected := ConcavePolygonShape3D.new()
					expected.set_faces(draw.mesh.get_faces())
					check(shapes[0].shape.get_faces().to_byte_array() == expected.get_faces().to_byte_array(), "raw collider equals actual engine triangle construction " + str(group.name))
				check(draw.mesh.shadow_mesh == null, "no unrelated original shadow mesh " + str(group.name))
		observations.append({"kind":"raw_extraction","cell":spec.cell,"stocks":raw.get_child_count(),"triangles":raw.get_meta("retained_source_triangles"),"published":raw.is_inside_tree()})
		raw.free()
	else:
		var probe := preload("res://tests/arcade_native_carrier_test.gd").new()
		var row: Dictionary = spec.raw_stocks[0]
		for candidate: Dictionary in spec.raw_stocks:
			if str(helper.errors).contains(str(candidate.id)): row = candidate
		probe._raw_source_probe(cell,row)
		observations.append({"kind":"raw_refusal","cell":spec.cell,"errors":helper.errors.duplicate(),"probe":probe.observations})
		probe.free()
	return ok

func _cell(contract: Dictionary, layout: Dictionary, atlas: RefCounted) -> void:
	var started := Time.get_ticks_msec()
	var walls_before := WallArtLaw._reserved.duplicate(true)
	var cell := (load(str(contract.cell_source)) as PackedScene).instantiate() as Node3D
	if not check(cell != null, "original cell " + str(contract.cell)): return
	cell.name = str(contract.cell)
	var mounted := true
	for mount: Dictionary in contract.mounts:
		var script := load(str(mount.wrapper)) as GDScript
		var arguments: Array = []
		for argument: String in mount.arguments:
			match argument:
				"cell": arguments.append(cell)
				"original_layout": arguments.append(layout)
				"portrait_atlas_cache": arguments.append(atlas)
				_:
					check(false, "unknown fitting argument " + argument)
					mounted = false
		if not mounted or not check(script != null and bool(script.callv(str(mount.method), arguments)), "actual fitting owner %s/%s" % [contract.cell, mount.family]):
			mounted = false
			break
	var helper := Carrier.new()
	var projected: Node3D
	if mounted:
		var before := _snapshot(cell, helper)
		var auxiliary_before := _auxiliary_snapshot(cell, contract)
		var presentation_before := {}
		for model: Dictionary in contract.models:
			for key: String in model.get("presentation_metadata", []):
				presentation_before[str(model.name)+"/"+key] = cell.get_node(NodePath(str(model.name))).get_meta(key)
		var parts := {}
		var labels := {}
		for row: Dictionary in contract.entries + contract.rebuild_entries:
			var part := _part(cell, row)
			if not check(part != null, "original native identity " + str(row.part_id)):
				mounted = false
				break
			parts[str(row.model)+"/"+str(row.part_id)] = part
		for row: Dictionary in contract.labels:
			var words := cell.get_node_or_null(NodePath(str(row.model)+"/"+str(row.node_name))) as Label3D
			if check(words != null, "original lettering owner " + str(row.node_name)):
				labels[str(row.node_name)] = {"node":words,"font":words.font,"text":words.text,"pixel_size":words.pixel_size,"font_size":words.font_size}
		if mounted:
			if not auxiliary_before.is_empty():
				for kind: String in ["missing", "duplicate", "frame", "owner", "state", "haze_shader"]:
					var bad := contract.duplicate(true)
					match kind:
						"missing": bad.auxiliary_entries.pop_front()
						"duplicate": bad.auxiliary_entries.append(bad.auxiliary_entries[0])
						"frame": bad.auxiliary_entries[0].target_transform[0][3] += .1
						"owner": bad.auxiliary_entries[0].owner_part_id = "wrong_owner"
						"state": bad.auxiliary_entries[0].properties.light_energy += 1
						"haze_shader":
							for row: Dictionary in bad.auxiliary_entries:
								if str(row.kind)=="glass_haze": row.shader = "res://wrong_haze.gdshader"
					var rejected := Carrier.new()
					var output := rejected.extract_native(cell,bad)
					check(output == null and not rejected.errors.is_empty(), "reject optical attachment " + kind)
					if output != null: output.free()
					for path: String in auxiliary_before:
						var record: Dictionary = auxiliary_before[path]
						check(record.node.get_parent()==record.parent and helper._same(record.node.transform,record.pose), "refusal preserves optical attachment owner/frame " + kind)
						for property: String in record.properties:
							check(helper._property_same(record.node.get(property),record.properties[property]), "refusal preserves optical attachment state " + kind)
			projected = helper.extract_native(cell, contract)
			if check(projected != null, "complete detached projection %s: %s" % [contract.cell, helper.errors]):
				for row: Dictionary in contract.entries:
					var draw := _part(projected, row)
					var source: MeshInstance3D = parts[str(row.model)+"/"+str(row.part_id)]
					var old: Dictionary = before[source.get_instance_id()]
					check(draw == source and draw.mesh == old.mesh and _signature(draw) == str(old.signature) and draw.material_override == old.material_override, "same native node/buffers/material " + str(row.part_id))
					check(helper._same(helper._relative(draw, projected), helper._matrix(row.target_transform)), "target applied exactly once " + str(row.part_id))
				for row: Dictionary in contract.rebuild_entries:
					var draw := _part(cell, row)
					var old: Dictionary = before[draw.get_instance_id()]
					check(draw.mesh == old.mesh and _signature(draw) == str(old.signature) and helper._same(helper._relative(draw, cell), old.pose), "exact rebuild retained on source " + str(row.part_id))
				for row: Dictionary in contract.labels:
					var words := projected.get_node_or_null(NodePath(str(row.model)+"/"+str(row.target_name))) as Label3D
					var old: Dictionary = labels[str(row.node_name)]
					check(words == old.node and words.font == old.font and words.text == old.text and words.pixel_size == old.pixel_size and words.font_size == old.font_size, "same authored lettering appearance " + str(row.node_name))
					check(helper._same(helper._relative(words, projected), helper._matrix(row.target_transform)), "authored lettering follows its real owner " + str(row.node_name))
				check(projected.get_meta("arcade_native_rebuild_inventory").size() == contract.rebuild_entries.size(), "complete unresolved rebuild custody " + str(contract.cell))
				check(projected.get_meta("arcade_native_auxiliary_inventory").size()==auxiliary_before.size(), "complete optical attachment custody " + str(contract.cell))
				for row: Dictionary in contract.get("auxiliary_entries", []):
					var path := str(row.model)+"/"+str(row.node_path)
					var node := projected.get_node_or_null(NodePath(path)) as Node3D
					var old: Dictionary = auxiliary_before[path]
					check(node == old.node and helper._same(helper._relative(node,projected),helper._matrix(row.target_transform)), "same optical node follows owner exactly once " + path)
					for property: String in old.properties:
						check(helper._property_same(node.get(property),old.properties[property]), "same live optical property " + path)
					if node is MeshInstance3D:
						check(node.mesh==old.mesh and node.material_override==old.material and node.get_parent()==old.parent, "same haze mesh/material/native parent " + path)
				for path: String in presentation_before:
					var split := path.split("/")
					check(projected.get_node(NodePath(split[0])).get_meta(split[1])==presentation_before[path], "same declared presentation metadata " + path)
				check(not projected.is_inside_tree() and not cell.is_inside_tree(), "unfinished room never published " + str(contract.cell))
	var raw_ok := _raw(cell,projected,helper,raw_contracts[str(contract.cell)]) if projected != null else false
	if projected != null: _owner_finish(projected,contract)
	var did_project := projected != null
	if projected != null: projected.free()
	cell.free()
	check(WallArtLaw._reserved == walls_before, "original wall reservations restored " + str(contract.cell))
	observations.append({"cell":contract.cell,"mounts_completed":mounted,"projection_completed":did_project,"raw_completed":raw_ok,"transfers_declared":contract.entries.size(),"rebuilds":contract.rebuild_entries.size(),"labels":contract.labels.size(),"auxiliary":contract.get("auxiliary_entries",[]).size(),"elapsed_ms":Time.get_ticks_msec()-started})

func _owner_finish(projected: Node3D, contract: Dictionary) -> void:
	var helper := Carrier.new()
	var geometry := _snapshot(projected,helper)
	var optics := _auxiliary_snapshot(projected,contract)
	var finish := preload("res://scripts/building/orison_v2_owner_finishes.gd").new()
	var guarded: Array[Dictionary] = []
	var emissive := 0
	for draw: MeshInstance3D in projected.find_children("*","MeshInstance3D",true,false):
		for surface: int in draw.mesh.get_surface_count():
			var material := draw.get_active_material(surface) as StandardMaterial3D
			if material != null and (material.emission_enabled or material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED):
				guarded.append({"draw":draw,"surface":surface,"material":material})
				if material.emission_enabled: emissive += 1
	finish.apply_shop_cell(projected)
	for record: Dictionary in guarded:
		check(record.draw.get_active_material(int(record.surface)) == record.material,"owner finish retains exact original emissive/transparent resource")
	if str(contract.cell) == "shop_otis_son": check(emissive >= 4,"actual four show-globe emissive owner controls present")
	var materials := {}
	var slots := 0
	for model: Node in projected.get_children():
		check(not model.has_meta("original_meshes"), "projected finish does not borrow retired donor metadata " + str(model.name))
		slots += int(model.get_meta("v2_owner_finish_slots",0))
	for draw: MeshInstance3D in projected.find_children("*","MeshInstance3D",true,false):
		var old: Dictionary = geometry[draw.get_instance_id()]
		check(draw.mesh == old.mesh and _signature(draw) == old.signature and helper._same(helper._relative(draw,projected),old.pose), "finish keeps exact native geometry/frame " + str(draw.name))
		var active: Array[Material] = []
		for surface: int in draw.mesh.get_surface_count(): active.append(draw.get_active_material(surface))
		materials[draw.get_instance_id()] = active
	finish.apply_shop_cell(projected)
	for draw: MeshInstance3D in projected.find_children("*","MeshInstance3D",true,false):
		for surface: int in draw.mesh.get_surface_count():
			check(draw.get_active_material(surface) == materials[draw.get_instance_id()][surface], "repeat finish keeps tuned resource " + str(draw.name))
	for path: String in optics:
		var node := projected.get_node(NodePath(path)) as Node3D
		var old: Dictionary = optics[path]
		for key: String in old.properties: check(node.get(key) == old.properties[key], "finish preserves optical property " + path)
		if node is MeshInstance3D: check(node.material_override == old.material and node.mesh == old.mesh, "finish preserves optical haze resource " + path)
	if str(contract.cell) == "shop_pawnbroker":
		add_child(projected)
		for offset: Vector3 in [Vector3(7,2,-9),Vector3(-8,1,6)]:
			projected.position=offset
			finish.apply_shop_wear(projected)
			var wear_slots := 0
			for draw: MeshInstance3D in projected.find_children("*","MeshInstance3D",true,false):
				if not str(draw.get_meta("pawn_display_part","")).contains("_case_"):continue
				var material := draw.get_active_material(0) as ShaderMaterial
				if material == null or str(material.get_meta("v2_owner_finish","")) != "shop/wood_dark":continue
				var bounds := draw.global_transform*draw.mesh.get_aabb()
				var expected := Vector4(bounds.position.x-.005,bounds.position.z-.005,bounds.end.x+.005,bounds.end.z+.005)
				check((material.get_shader_parameter("state_rect") as Vector4).is_equal_approx(expected), "Pawn wear follows actual relocated world bounds")
				check((material.get_shader_parameter("state_y") as Vector2).is_equal_approx(Vector2(bounds.end.y-.045,bounds.end.y+.002)), "Pawn wear stays at actual rail height")
				wear_slots += 1
			check(wear_slots > 0,"actual Pawn case wear slots at placement " + str(offset))
		remove_child(projected)
		projected.position=Vector3.ZERO
	observations.append({"kind":"projected_owner_finish","cell":contract.cell,"tuned_slots":slots,"native_meshes":geometry.size(),"optical_attachments":optics.size(),"guarded_original_materials":guarded.size(),"emissive_owner_slots":emissive})

func run() -> void:
	OS.add_logger(logger)
	original = RealityState.data
	original_text = JSON.stringify(original, "", true, true)
	old_mouse = Input.mouse_mode
	var contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONTRACT))
	var raw_spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/arcade_all_raw_projection.json"))
	for row: Dictionary in raw_spec.cells: raw_contracts[str(row.cell)] = row
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/building_layout.json"))
	var source_hash := FileAccess.get_sha256("res://data/building_layout.json")
	var selected: Array = []
	var requested := OS.get_environment("ORISON_ARCADE_CELLS")
	if not requested.is_empty(): selected = JSON.parse_string(requested)
	if selected.is_empty():
		for cell: Dictionary in contract.cells: selected.append(str(cell.cell))
	preview = RealityState.begin_preview_campaign(self)
	if check(preview, "exclusive preview campaign"):
		var atlas := Portraits.AtlasCache.new()
		for cell: Dictionary in contract.cells:
			if str(cell.cell) in selected: _cell(cell, layout, atlas)
		check(observations.filter(func(row: Dictionary) -> bool: return row.has("mounts_completed")).size() == selected.size(), "every selected cell executed")
		check(FileAccess.get_sha256("res://data/building_layout.json") == source_hash, "protected fabrication bytes unchanged")
		check(RealityState.end_preview_campaign(self) and is_same(RealityState.data, original) and JSON.stringify(original,"",true,true)==original_text, "exact campaign object/content restored")
	Input.mouse_mode = old_mouse
	for frame in 3: await get_tree().process_frame
	check(logger.errors.is_empty(), "no engine/teardown errors")
	OS.remove_logger(logger)
	var directory := OS.get_environment("SHOT_DIR")
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(directory)
		FileAccess.open(directory.path_join("diagnostic.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Actual fitting owners and detached native/raw/rebuild custody; no installed room, source-disposal, physical route, service/save or art acceptance.","checks":checks,"failures":failures,"engine_errors":logger.errors,"requested_cells":selected,"observations":observations},"\t"))
	print("ALL ARCADE NATIVE RESULT: %d checks / %d failures" % [checks,failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
