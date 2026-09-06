extends RefCounted
## Optional all-resident F01 geometry registry. No gameplay state or streaming.
## Runtime aliases address complete imported target sets, never first matches.

const Surface := preload("res://scripts/building/surface_pass.gd")
const SCHEMA := "orison.floor01.provider-parity-resource.v1"
const EXPECTED_TARGETS := 609
const EXPECTED_ALIASES := 531
const EXPECTED_MULTI_ALIASES := 47
const EXPECTED_CELLS := 17
const CELL_IDS := ["CELL_ORISON_F01_INTERIOR", "CELL_ORISON_FACADE_SHELL", "CELL_SITE_STREET_COMMON",
		"CELL_PASSAGE", "CELL_SHOP_BAR", "CELL_SHOP_BODEGA", "CELL_SHOP_MODEL_LAUNDRY",
		"CELL_SHOP_SHOE_REBUILDING", "CELL_SHOP_KEYS_CUT", "CELL_SHOP_HARDWARE_PAINT",
		"CELL_SHOP_FUNERAL_PARLOUR", "CELL_SHOP_PHOTO_SUPPLIES", "CELL_SHOP_RADIO_SERVICE",
		"CELL_SHOP_PAWNBROKER", "CELL_SHOP_NEWS_CIGARS", "CELL_SHOP_OTIS_SON", "CELL_SHOP_LUNCHEONETTE"]

var error := ""
var _data: Dictionary = {}
var _cells: Dictionary = {}
var _targets: Dictionary = {}
var _roles: Dictionary = {}


func configure(path: String) -> bool:
	if not path.begins_with("res://") or not path.ends_with(".tres"):
		return _fail("imported registry resource path required")
	var resource := load(path) as Resource
	if resource == null:
		return _fail("registry resource unavailable")
	return configure_resource(resource)


func configure_resource(resource: Resource) -> bool:
	if not _data.is_empty() or resource == null:
		return _fail("registry must be configured once")
	var decoded: Variant = resource.get("definition")
	if not decoded is Dictionary:
		return _fail("typed logical registry definition required")
	var data: Dictionary = decoded
	if str(data.get("schema", "")) != SCHEMA or data.get("all_cells_resident") != true:
		return _fail("unsupported provider schema or residency contract")
	for key: String in ["targets", "aliases", "semantics", "source_owners", "texture_dependencies"]:
		if not data.get(key) is Dictionary:
			return _fail("registry dictionary missing: " + key)
	for key: String in ["cells", "protected_aliases", "expected_semantic_ids", "expected_texture_paths"]:
		if not data.get(key) is Array:
			return _fail("registry array missing: " + key)
	var texture_paths: Array = data.texture_dependencies.keys()
	texture_paths.sort()
	if texture_paths.size() != 304 or texture_paths != data.expected_texture_paths:
		return _fail("logical texture dependency membership changed")
	var cells: Array = data.cells
	var targets: Dictionary = data.targets
	var aliases: Dictionary = data.aliases
	if cells.size() != EXPECTED_CELLS or targets.size() != EXPECTED_TARGETS \
			or aliases.size() != EXPECTED_ALIASES or data.semantics.size() != 189:
		return _fail("verified C1 cardinality changed")
	var cell_ids := {}
	var mapped_textures := {}
	for raw: Variant in cells:
		if not raw is Dictionary:
			return _fail("cell record is not an object")
		var row: Dictionary = raw
		var identity := str(row.get("id", ""))
		if identity not in CELL_IDS or cell_ids.has(identity):
			return _fail("missing, mixed or duplicate cell owner")
		cell_ids[identity] = true
		if not row.get("scene") is PackedScene or not str(row.get("gltf_path", "")).begins_with("res://assets/building/floor_01_cells/"):
			return _fail("imported PackedScene dependency missing: " + identity)
		if not row.get("image_uri_rewrites") is Array:
			return _fail("logical image mapping missing")
		var image_indices := {}
		for raw_image: Variant in row.image_uri_rewrites:
			if not raw_image is Dictionary:
				return _fail("logical image mapping record malformed")
			var image: Dictionary = raw_image
			if not image.get("image_index") is int or image_indices.has(image.image_index):
				return _fail("logical image mapping index malformed or repeated")
			image_indices[image.image_index] = true
			var logical := str(image.get("protected_path", ""))
			var name := logical.get_file()
			if not data.texture_dependencies.has(logical) \
					or str(data.texture_dependencies[logical]) != str(image.get("source_sha256", "")) \
					or name != str(image.get("source_uri", "")).get_file() \
					or name != str(image.get("project_uri", "")).get_file():
				return _fail("logical image basename or dependency identity changed")
			mapped_textures[logical] = str(image.source_sha256)
	if mapped_textures != data.texture_dependencies:
		return _fail("logical texture mappings do not cover declared dependency set")
	var expected_aliases := {}
	for raw_alias: Variant in data.protected_aliases:
		var alias := str(raw_alias)
		if alias.is_empty() or expected_aliases.has(alias):
			return _fail("compiled protected alias set is malformed")
		expected_aliases[alias] = true
	if expected_aliases.size() != EXPECTED_ALIASES:
		return _fail("compiled protected alias cardinality changed")
	var seen_targets := {}
	var multi := 0
	for raw_alias: Variant in aliases:
		var alias := str(raw_alias)
		if not expected_aliases.has(alias) or not aliases[alias] is Array or aliases[alias].is_empty():
			return _fail("unknown or empty compatibility alias")
		var keys: Array = aliases[alias]
		if keys.size() > 1:
			multi += 1
		var local_seen := {}
		for raw_key: Variant in keys:
			var key := str(raw_key)
			if not targets.has(key) or local_seen.has(key) or seen_targets.has(key):
				return _fail("missing, duplicate or conflicting alias target")
			local_seen[key] = true
			seen_targets[key] = true
			if not targets[key] is Dictionary:
				return _fail("target record malformed")
			var target: Dictionary = targets[key]
			if not cell_ids.has(str(target.get("cell_id", ""))) \
					or target.get("aliases") != [alias]:
				return _fail("target owner or reverse alias mismatch")
			if not target.get("import_name_candidates") is Array or target.import_name_candidates.is_empty() \
					or str(target.get("collision_class", "")) not in ["VISIBLE_TRIMESH", "NONE", "COLLISION_ONLY_TRIMESH"] \
					or not target.get("envelope_exempt") is bool:
				return _fail("target importer or classification contract malformed")
			var expected_class := str(Surface._class_for(alias).get("key", ""))
			if str(target.get("surface_class", "")) != expected_class \
					or str(Surface._class_for(str(target.get("source_node_name", ""))).get("key", "")) != expected_class:
				return _fail("current SurfacePass class differs from legacy alias")
			if str(target.get("passage_role", "")) != passage_role_for_name(alias) \
					or passage_role_for_name(str(target.get("source_node_name", ""))) != passage_role_for_name(alias):
				return _fail("Passage alias classification drift")
	if seen_targets.size() != EXPECTED_TARGETS or multi != EXPECTED_MULTI_ALIASES:
		return _fail("one-to-many alias target set is incomplete")
	for target: Dictionary in targets.values():
		if not target.get("source_ids") is Array or target.source_ids.is_empty():
			return _fail("target source membership missing")
		for source_id: Variant in target.source_ids:
			if str(data.source_owners.get(str(source_id), "")) != str(target.cell_id):
				return _fail("target differs from explicit source owner catalog")
	var semantic_ids: Array = data.semantics.keys()
	semantic_ids.sort()
	if semantic_ids != data.expected_semantic_ids or semantic_ids.size() != 189:
		return _fail("semantic identity membership changed")
	var semantic_sources := {}
	for raw_id: Variant in semantic_ids:
		var identity := str(raw_id)
		if not data.semantics[identity] is Dictionary:
			return _fail("semantic record malformed")
		var semantic: Dictionary = data.semantics[identity]
		var source_id := str(semantic.get("source_id", ""))
		if str(semantic.get("identity", "")) != identity or source_id.is_empty() \
				or semantic_sources.has(source_id) or str(semantic.get("source_locator", "")).is_empty() \
				or str(data.source_owners.get(source_id, "")) != str(semantic.get("owner_cell", "")):
			return _fail("semantic source or owner membership changed")
		semantic_sources[source_id] = true
		if str(semantic.get("semantic_kind", "")) == "layout_marker":
			if source_id != identity:
				return _fail("layout marker identity changed")
		elif identity != "THRESHOLD_SHOP_BODEGA_FRONT" or source_id != "M11A_THRESHOLD_SHOP_BODEGA_FRONT" \
				or str(semantic.get("semantic_kind", "")) != "m11a_exterior_threshold":
			return _fail("unknown non-layout semantic")
	_data = data.duplicate(true)
	return true


func instantiate_into(host: Node3D, envelope_tokens: Array) -> bool:
	if _data.is_empty() or host == null or host.is_inside_tree() or host.get_child_count() != 0 or not _cells.is_empty():
		return _fail("all-cell preparation requires one empty off-tree host")
	for row: Dictionary in _data.cells:
		var packed := row.scene as PackedScene
		if packed == null:
			return _fail("Godot-imported cell scene unavailable: " + str(row.id))
		var instance: Node = packed.instantiate()
		if not instance is Node3D:
			if instance != null:
				instance.free()
			return _fail("cell importer returned a non-spatial root")
		var cell := instance as Node3D
		# Do not flatten the imported scene or reassign Node.owner. SurfacePass
		# distinguishes these imported meshes from actual procedural props.
		cell.name = str(row.id)
		host.add_child(cell)
		_cells[str(row.id)] = cell
	for raw_key: Variant in _data.targets:
		var key := str(raw_key)
		var row: Dictionary = _data.targets[key]
		var cell: Node3D = _cells[str(row.cell_id)]
		var collision_only := str(row.collision_class) == "COLLISION_ONLY_TRIMESH"
		var matches: Array[Node3D] = []
		for node: Node in cell.find_children("*", "Node3D", true, false):
			if node is SubViewport or node.owner != cell:
				continue
			if collision_only and not node is StaticBody3D:
				continue
			if not collision_only and not node is MeshInstance3D:
				continue
			if str(node.name) in row.import_name_candidates:
				matches.append(node as Node3D)
		if matches.size() != 1:
			return _fail("imported target is missing or ambiguous: " + key)
		var target := matches[0]
		if not collision_only:
			var draw := target as MeshInstance3D
			if draw.mesh == null or not Surface._is_imported(draw) \
					or str(Surface._class_for(str(draw.name)).get("key", "")) != str(row.surface_class):
				return _fail("imported ownership or live surface class drift: " + key)
		var envelope := false
		for alias: String in row.aliases:
			for token: Variant in envelope_tokens:
				if alias.trim_prefix("F01_").contains(str(token)):
					envelope = true
		if envelope != row.envelope_exempt:
			return _fail("current exterior exemption differs from bound alias map")
		_targets[key] = target
		_roles[target.get_instance_id()] = str(row.passage_role)
	var visible_meshes := 0
	for cell: Node3D in _cells.values():
		for mesh: Node in cell.find_children("*", "MeshInstance3D", true, false):
			visible_meshes += 1
			if not _roles.has(mesh.get_instance_id()):
				return _fail("unregistered imported geometry")
	if visible_meshes != 597:
		return _fail("expected 597 visible imported targets plus 12 collision-only targets")
	return true


func alias_targets(alias: String) -> Array[Node3D]:
	var result: Array[Node3D] = []
	for key: Variant in _data.get("aliases", {}).get(alias, []):
		var target: Node3D = _targets.get(str(key))
		if is_instance_valid(target):
			result.append(target)
	return result


func envelope_targets() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for key: Variant in _targets:
		if _data.targets[key].envelope_exempt:
			result.append(_targets[key] as Node3D)
	return result


func role_for(node: Node) -> String:
	return str(_roles.get(node.get_instance_id(), ""))


func public_census() -> Dictionary:
	return {"cells": _cells.size(), "targets": _targets.size(), "aliases": _data.get("aliases", {}).size(),
			"semantics": _data.get("semantics", {}).size(), "all_cells_resident": true,
			"target_ids": _targets.values().map(func(node: Node) -> int: return node.get_instance_id())}


func release_references() -> void:
	_targets.clear()
	_roles.clear()
	_cells.clear()
	_data.clear()


static func passage_role_for_name(value: String) -> String:
	if value.contains("_retail_shop_"):
		return "interior"
	if value.contains("_retail_passage_shell_"):
		return "shell"
	if value.contains("_retail_passage_proxy_"):
		return "proxy"
	return "foreign"


func _fail(message: String) -> bool:
	error = message
	return false
