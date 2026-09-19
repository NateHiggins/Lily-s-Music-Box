extends Node
## Real registry refusals against the source-bound imported resource. Off-tree
## instantiation controls do not construct a gameplay world or prove rendering.

const Registry := preload("res://scripts/building/floor01_cell_registry.gd")
const Definition := preload("res://scripts/building/floor01_registry_data.gd")
const Root := preload("res://scripts/building/building_root.gd")
const CASES := ["drop_alias_target", "surface_class", "source_owner", "semantic_owner",
		"texture_wrong_name", "texture_dependency_missing", "duplicate_image_index",
		"malformed_image_row", "cell_scene_missing", "source_passage_role"]
var checks: Array[Dictionary] = []
var refusals: Array[Dictionary] = []
var failures := 0
var directory := ""


func _ready() -> void:
	directory = OS.get_environment("F01_PROVIDER_RECEIPT_DIR")
	if directory.is_empty() or DirAccess.make_dir_recursive_absolute(directory) != OK:
		get_tree().quit(2)
		return
	var resource := load("res://data/floor01_provider_registry.tres") as Resource
	if not _check("actual typed registry resource loaded", resource != null and resource.get("definition") is Dictionary):
		await _finish()
		return
	var original: Dictionary = resource.get("definition")
	var registry = Registry.new()
	if not _check("unmodified logical resource configures", registry.configure_resource(resource)):
		registry.release_references()
		registry = null
		await _finish()
		return
	registry.release_references()
	_check("configured logical references release", registry.public_census().aliases == 0)
	registry = null
	for kind: String in CASES:
		_refusal(kind, original)
	_instantiation_refusal("non_spatial_root", original)
	_instantiation_refusal("missing_imported_target", original)
	resource = null
	original = {}
	await _finish()


func _refusal(kind: String, original: Dictionary) -> void:
	var data: Dictionary = original.duplicate(true)
	var first: String = str(data.targets.keys()[0])
	var expected := ""
	match kind:
		"drop_alias_target":
			for alias: String in data.aliases:
				if data.aliases[alias].size() > 1:
					data.aliases[alias].pop_back()
					break
			expected = "one-to-many alias target set is incomplete"
		"surface_class":
			data.targets[first].surface_class = "__wrong_surface_class__"
			expected = "current SurfacePass class differs"
		"source_owner":
			data.source_owners[str(data.targets[first].source_ids[0])] = "__wrong_owner__"
			expected = "target differs from explicit source owner catalog"
		"semantic_owner":
			data.semantics[str(data.semantics.keys()[0])].owner_cell = "__wrong_owner__"
			expected = "semantic source or owner membership changed"
		"texture_wrong_name":
			var image: Dictionary = data.cells[0].image_uri_rewrites[0]
			image.project_uri = str(image.project_uri).get_base_dir().path_join("WRONG_" + str(image.project_uri).get_file())
			expected = "logical image basename or dependency identity changed"
		"texture_dependency_missing":
			data.texture_dependencies.erase(data.texture_dependencies.keys()[0])
			expected = "logical texture dependency membership changed"
		"duplicate_image_index":
			data.cells[0].image_uri_rewrites.append(data.cells[0].image_uri_rewrites[0].duplicate(true))
			expected = "logical image mapping index malformed or repeated"
		"malformed_image_row":
			data.cells[0].image_uri_rewrites[0] = false
			expected = "logical image mapping record malformed"
		"cell_scene_missing":
			data.cells[0].scene = null
			expected = "imported PackedScene dependency missing"
		"source_passage_role":
			for key: String in data.targets:
				if str(data.targets[key].passage_role) == "foreign":
					data.targets[key].source_node_name = str(data.targets[key].source_node_name) + "_retail_passage_proxy_"
					break
			expected = "Passage alias classification drift"
	var definition = Definition.new()
	definition.definition = data
	var registry = Registry.new()
	var accepted: bool = registry.configure_resource(definition)
	var actual_error := str(registry.error)
	_check(kind + "/mutated input refused", not accepted)
	_check(kind + "/declared refusal reason", actual_error.contains(expected) and not expected.is_empty())
	_check(kind + "/no configured targets or aliases", registry.public_census().targets == 0 and registry.public_census().aliases == 0)
	refusals.append({"case":kind, "accepted":accepted, "error":actual_error, "expected_reason":expected,
			"scope":"logical input mutation; texture wrong-name control preserves the original declared hash"})
	registry.release_references()
	registry = null
	definition = null


func _instantiation_refusal(kind: String, original: Dictionary) -> void:
	var data: Dictionary = original.duplicate(true)
	var pack_ok := true
	if kind == "non_spatial_root":
		var authored := Node.new()
		authored.name = "NonSpatialControl"
		var packed := PackedScene.new()
		pack_ok = packed.pack(authored) == OK
		authored.free()
		data.cells[0].scene = packed
	else:
		data.targets[str(data.targets.keys()[0])].import_name_candidates = ["__definitely_missing_import_target__"]
	var definition = Definition.new()
	definition.definition = data
	var registry = Registry.new()
	var configured: bool = registry.configure_resource(definition)
	_check(kind + "/control configures before actual instantiation", pack_ok and configured)
	var host := Node3D.new()
	var host_id: int = host.get_instance_id()
	var orphan_before: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var accepted: bool = registry.instantiate_into(host, Root.ENVELOPE_BATCHES) if configured else false
	var expected := "cell importer returned a non-spatial root" if kind == "non_spatial_root" else "imported target is missing or ambiguous"
	_check(kind + "/actual importer mismatch refused", not accepted)
	_check(kind + "/declared importer refusal reason", str(registry.error).contains(expected))
	var ids: Array[int] = [host_id]
	for node: Node in host.find_children("*", "Node", true, false):
		ids.append(node.get_instance_id())
	var actual_error := str(registry.error)
	registry.release_references()
	host.free()
	var retired := true
	for identity: int in ids:
		retired = retired and not is_instance_id_valid(identity)
	var orphan_after: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	_check(kind + "/owned subtree and rejected root retire", retired and orphan_after == orphan_before - 1)
	_check(kind + "/registry target references cleared", registry.public_census().targets == 0 and registry.public_census().cells == 0)
	refusals.append({"case":kind, "accepted":accepted, "error":actual_error, "retired_ids":ids,
			"all_owned_ids_retired":retired, "orphan_before":orphan_before, "orphan_after":orphan_after,
			"scope":"actual off-tree imported subtree preparation and failure cleanup; no gameplay root"})
	registry = null
	definition = null


func _finish() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_check("fixture has no owned child nodes", get_child_count() == 0)
	var receipt := {"scope":"source-bound logical input refusals plus real off-tree importer failure cleanup",
			"checks":checks, "failures":failures, "refusals":refusals, "world_composed":false}
	var file := FileAccess.open(directory.path_join("registry_contract.json"), FileAccess.WRITE)
	if file == null:
		get_tree().quit(2)
		return
	file.store_string(JSON.stringify(receipt, "\t"))
	file.close()
	print("F01_REGISTRY_COMPLETE=" + JSON.stringify({"checks":checks.size(), "failures":failures}))
	get_tree().quit(0 if failures == 0 else 1)


func _check(label: String, okay: bool) -> bool:
	checks.append({"label":label, "pass":okay})
	if not okay:
		failures += 1
		print("F01_REGISTRY_FAIL=" + label)
	return okay
