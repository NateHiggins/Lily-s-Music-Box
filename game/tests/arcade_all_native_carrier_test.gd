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
	var did_project := projected != null
	if projected != null: projected.free()
	cell.free()
	check(WallArtLaw._reserved == walls_before, "original wall reservations restored " + str(contract.cell))
	observations.append({"cell":contract.cell,"mounts_completed":mounted,"projection_completed":did_project,"transfers_declared":contract.entries.size(),"rebuilds":contract.rebuild_entries.size(),"labels":contract.labels.size(),"auxiliary":contract.get("auxiliary_entries",[]).size(),"elapsed_ms":Time.get_ticks_msec()-started})

func run() -> void:
	OS.add_logger(logger)
	original = RealityState.data
	original_text = JSON.stringify(original, "", true, true)
	old_mouse = Input.mouse_mode
	var contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CONTRACT))
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
		check(observations.size() == selected.size(), "every selected cell executed")
		check(FileAccess.get_sha256("res://data/building_layout.json") == source_hash, "protected fabrication bytes unchanged")
		check(RealityState.end_preview_campaign(self) and is_same(RealityState.data, original) and JSON.stringify(original,"",true,true)==original_text, "exact campaign object/content restored")
	Input.mouse_mode = old_mouse
	for frame in 3: await get_tree().process_frame
	check(logger.errors.is_empty(), "no engine/teardown errors")
	OS.remove_logger(logger)
	var directory := OS.get_environment("SHOT_DIR")
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(directory)
		FileAccess.open(directory.path_join("diagnostic.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Actual fitting owners and detached native/rebuild custody; no installed room, source-disposal, physical route, service/save or art acceptance.","checks":checks,"failures":failures,"engine_errors":logger.errors,"requested_cells":selected,"observations":observations},"\t"))
	print("ALL ARCADE NATIVE RESULT: %d checks / %d failures" % [checks,failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
