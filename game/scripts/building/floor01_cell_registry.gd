class_name Floor01CellRegistry
extends Node3D
## Fail-closed production registry for F01 geometry providers.
##
## Gameplay and durable state remain on the geometry-free F01 host owned by
## BuildingRoot. This registry owns only imported geometry instances and their
## session-local residency/lifecycle facts.

const GeometryConfiguration := preload(
		"res://scripts/building/floor01_geometry_configuration.gd")

const MANIFEST_PATH := "res://data/floor_01_cell_registry.json"
const MANIFEST_SCHEMA := "orison.floor01.cell-registry.v1"
const ASSET_MANIFEST_SCHEMA := "orison.floor01.production-cell-assets.v1"
const COMPATIBILITY_ALIAS_MANIFEST_SCHEMA := \
		"orison.floor01.production-compatibility-aliases.v1"
const LEGACY_MONOLITH_PATH := "res://assets/building/floor_01.gltf"
const CELL_RESOURCE_PREFIX := "res://assets/building/floor_01_cells/"
const ASSET_MANIFEST_PATH := \
		"res://assets/building/floor_01_cells/floor01_asset_manifest.json"
## Repository-relative provenance sidecar kept beside the reviewed M11C1
## ownership input. The runtime binds it by SHA-256 through the asset
## manifest and never parses it at boot: no production reader consumes a
## lineage field. It is resolved from the project directory, so a source
## checkout is required for owner-first mode (fail-closed when absent).
const LINEAGE_MANIFEST_PATH := "art/data/m11c2/floor01_owner_first_lineage.json"
const COMPATIBILITY_ALIAS_MANIFEST_PATH := \
		"res://assets/building/floor_01_cells/floor01_compatibility_aliases.json"
const FULL_RECOMPOSITION := "FULL_RECOMPOSITION"

const TARGET_CELL_IDS: Array[String] = [
	"CELL_ORISON_F01_INTERIOR",
	"CELL_ORISON_FACADE_SHELL",
	"CELL_SITE_STREET_COMMON",
	"CELL_PASSAGE",
	"CELL_SHOP_BAR",
	"CELL_SHOP_BODEGA",
	"CELL_SHOP_MODEL_LAUNDRY",
	"CELL_SHOP_SHOE_REBUILDING",
	"CELL_SHOP_KEYS_CUT",
	"CELL_SHOP_HARDWARE_PAINT",
	"CELL_SHOP_FUNERAL_PARLOUR",
	"CELL_SHOP_PHOTO_SUPPLIES",
	"CELL_SHOP_RADIO_SERVICE",
	"CELL_SHOP_PAWNBROKER",
	"CELL_SHOP_NEWS_CIGARS",
	"CELL_SHOP_OTIS_SON",
	"CELL_SHOP_LUNCHEONETTE",
]

const PASSAGE_SHOP_CELL_IDS: Array[String] = [
	"CELL_SHOP_MODEL_LAUNDRY",
	"CELL_SHOP_SHOE_REBUILDING",
	"CELL_SHOP_KEYS_CUT",
	"CELL_SHOP_HARDWARE_PAINT",
	"CELL_SHOP_FUNERAL_PARLOUR",
	"CELL_SHOP_PHOTO_SUPPLIES",
	"CELL_SHOP_RADIO_SERVICE",
	"CELL_SHOP_PAWNBROKER",
	"CELL_SHOP_NEWS_CIGARS",
	"CELL_SHOP_OTIS_SON",
	"CELL_SHOP_LUNCHEONETTE",
]

var _configured := false
var _mode := ""
var _manifest: Dictionary = {}
var _cells: Dictionary = {}
var _residency_sets: Dictionary = {}
var _semantic_owner_index: Dictionary = {}
var _compatibility_alias_index: Dictionary = {}
var _cell_node_names: Dictionary = {}
var _facade_sharing: Array[Dictionary] = []
var _mounted: Dictionary = {}
var _lifecycle: Dictionary = {}
var _legacy_instance: Node
var _last_error := ""
## Wall-clock phase timings for the last configure()/mount call, in ms.
## Diagnostic only; never compared between modes as a semantic fact.
var _startup_timing: Dictionary = {}
## Public teardown is a terminal lifecycle boundary for this registry instance.
## BuildingRoot owns a fresh registry per complete root; keeping a torn-down
## registry one-shot prevents a same-frame mode swap while old providers are
## still awaiting their queued deletion.
var _retired := false


func configure(mode: String, manifest_override: Dictionary = {}) -> Dictionary:
	if _retired:
		return _failure("retired registry cannot be reconfigured")
	if _configured or not _mounted.is_empty() or _legacy_instance != null:
		return _failure("registry may only be configured once")
	if not GeometryConfiguration.is_valid_mode(mode):
		return _failure("invalid F01 geometry mode: %s" % mode)
	var configure_started := Time.get_ticks_usec()
	_startup_timing = {"mode": mode}
	var source := manifest_override.duplicate(true)
	if source.is_empty():
		var read_started := Time.get_ticks_usec()
		var loaded := _load_manifest()
		_startup_timing["configure.registry_manifest_read_parse_ms"] = \
				_elapsed_ms(read_started)
		if not bool(loaded.get("ok", false)):
			return loaded
		source = loaded.get("manifest", {}) as Dictionary
	var validate_started := Time.get_ticks_usec()
	var errors := _validate_manifest(source)
	_startup_timing["configure.registry_manifest_validate_ms"] = \
			_elapsed_ms(validate_started)
	if mode == GeometryConfiguration.OWNER_FIRST_CELLS:
		var bound_started := Time.get_ticks_usec()
		_validate_bound_files(source, errors)
		_startup_timing["configure.bound_files_total_ms"] = \
				_elapsed_ms(bound_started)
	if not errors.is_empty():
		_cell_node_names.clear()
		return _failure("; ".join(errors), {"validation_errors": errors})
	_mode = mode
	var index_started := Time.get_ticks_usec()
	_manifest = source.duplicate(true)
	_index_manifest(_manifest)
	_startup_timing["configure.index_ms"] = _elapsed_ms(index_started)
	_configured = true
	_last_error = ""
	_startup_timing["configure.total_ms"] = _elapsed_ms(configure_started)
	print("[F01 REGISTRY] %s configure %s" % [mode,
			_timing_summary("configure.")])
	return {
		"ok": true,
		"mode": _mode,
		"manifest_path": MANIFEST_PATH,
		"cell_count": _cells.size(),
		"semantic_owner_count": _semantic_owner_index.size(),
		"compatibility_alias_count": _compatibility_alias_index.size(),
		"save_authority": false,
		"timing_ms": _startup_timing.duplicate(true),
	}


func mount_default() -> Dictionary:
	return mount_residency(FULL_RECOMPOSITION)


func mount_residency(residency_id: String) -> Dictionary:
	if _retired:
		return _failure("retired registry cannot mount geometry")
	if not _configured:
		return _failure("registry is not configured")
	if _mode == GeometryConfiguration.LEGACY_MONOLITH:
		if residency_id != FULL_RECOMPOSITION:
			return _failure("legacy monolith only supports FULL_RECOMPOSITION")
		return _mount_legacy()
	if _legacy_instance != null:
		return _failure("legacy monolith and owner-first cells cannot be composed together")
	if not _residency_sets.has(residency_id):
		return _failure("unknown F01 residency set: %s" % residency_id)
	var requested := _string_array(_residency_sets[residency_id])
	var ordered: Array[String] = []
	var visiting := {}
	var visited := {}
	for cell_id in requested:
		if not _append_dependencies(cell_id, visiting, visited, ordered):
			return _failure(_last_error)
	var loads: Array[Dictionary] = []
	var mounted_this_call: Array[String] = []
	var mount_started := Time.get_ticks_usec()
	for key: String in ["mount.load_ms", "mount.instantiate_ms",
			"mount.attach_ms", "mount.cell_count"]:
		_startup_timing[key] = 0.0
	for cell_id in ordered:
		if _mounted.has(cell_id):
			loads.append({"ok": true, "cell_id": cell_id, "already_mounted": true})
			continue
		var row := _mount_cell(cell_id)
		loads.append(row)
		if bool(row.get("ok", false)):
			for key: String in ["load_ms", "instantiate_ms", "attach_ms"]:
				_startup_timing["mount." + key] = \
						float(_startup_timing["mount." + key]) + float(row.get(key, 0.0))
			_startup_timing["mount.cell_count"] = \
					float(_startup_timing["mount.cell_count"]) + 1.0
		if not bool(row.get("ok", false)):
			_rollback_cells(mounted_this_call)
			return _failure("failed to mount %s: %s" % [cell_id,
					str(row.get("error", "unknown error"))], {
				"residency_id": residency_id,
				"loads": loads,
				"rolled_back_cell_ids": mounted_this_call,
			})
		mounted_this_call.append(cell_id)
	_startup_timing["mount.total_ms"] = _elapsed_ms(mount_started)
	print("[F01 REGISTRY] %s mount %s %s" % [_mode, residency_id,
			_timing_summary("mount.")])
	return {
		"ok": true,
		"mode": _mode,
		"residency_id": residency_id,
		"requested_cell_ids": requested,
		"mounted_cell_ids": mounted_cell_ids(),
		"loads": loads,
		"owner_first_cells_loaded": true,
		"legacy_monolith_loaded": false,
		"simultaneous_composition": false,
		"timing_ms": _startup_timing.duplicate(true),
	}


func active_mode() -> String:
	return _mode


func is_owner_first() -> bool:
	return _mode == GeometryConfiguration.OWNER_FIRST_CELLS


func mounted_cell_ids() -> Array[String]:
	var ids: Array[String] = []
	for raw_id in _mounted:
		ids.append(str(raw_id))
	ids.sort_custom(func(a: String, b: String) -> bool:
		return TARGET_CELL_IDS.find(a) < TARGET_CELL_IDS.find(b))
	return ids


func instance_for_cell(cell_id: String) -> Node:
	return _mounted.get(cell_id) as Node


func owner_cell_for_node(node: Node) -> String:
	var cursor := node
	while cursor != null and cursor != self:
		if cursor.has_meta(&"floor01_owner_cell"):
			return str(cursor.get_meta(&"floor01_owner_cell"))
		cursor = cursor.get_parent()
	return ""


func geometry_nodes_for_cell(cell_id: String) -> Array[GeometryInstance3D]:
	var result: Array[GeometryInstance3D] = []
	var root := instance_for_cell(cell_id)
	if root != null:
		_collect_geometry(root, result)
	return result


func geometry_nodes_for_cells(cell_ids: Array[String]) -> Array[GeometryInstance3D]:
	var result: Array[GeometryInstance3D] = []
	for cell_id in cell_ids:
		result.append_array(geometry_nodes_for_cell(cell_id))
	return result


func semantic_owner(identity: String) -> String:
	return str(_semantic_owner_index.get(identity, ""))


func cell_ids_for_alias(alias_identity: String) -> Array[String]:
	var result: Array[String] = []
	var targets: Variant = _compatibility_alias_index.get(
			_canonical_alias_identity(alias_identity), [])
	if targets is not Array:
		return result
	for raw_target in targets:
		if raw_target is not Dictionary:
			continue
		var cell_id := str((raw_target as Dictionary).get("cell_id", ""))
		if not cell_id.is_empty() and cell_id not in result:
			result.append(cell_id)
	result.sort_custom(func(a: String, b: String) -> bool:
		return TARGET_CELL_IDS.find(a) < TARGET_CELL_IDS.find(b))
	return result


func compatibility_aliases() -> Array[String]:
	var result: Array[String] = []
	for alias_identity in _compatibility_alias_index:
		result.append(str(alias_identity))
	result.sort()
	return result


## Compatibility aliases may intentionally span multiple owner cells after
## rebatching. Return every exact-name match in canonical owner order.
func resolve_compatibility_alias(alias_identity: String) -> Array[Node]:
	var result: Array[Node] = []
	if _mode == GeometryConfiguration.LEGACY_MONOLITH:
		if is_instance_valid(_legacy_instance):
			_collect_exact_name(_legacy_instance, alias_identity, result)
		return result
	var canonical_identity := _canonical_alias_identity(alias_identity)
	var raw_targets: Variant = _compatibility_alias_index.get(canonical_identity, [])
	if raw_targets is not Array:
		return result
	for raw_target in raw_targets:
		if raw_target is not Dictionary:
			continue
		var target := raw_target as Dictionary
		var cell_id := str(target.get("cell_id", ""))
		var root := instance_for_cell(cell_id)
		if root == null:
			continue
		var names: Variant = _cell_node_names.get(cell_id, [])
		var node_index := int(target.get("node_index", -1))
		if names is Array and node_index >= 0 and node_index < (names as Array).size():
			var imported_name := str((names as Array)[node_index])
			var before := result.size()
			_collect_exact_name(root, imported_name, result)
			# The production importer currently retains the source mesh and adds a
			# stripped collision owner. The manifest target names the source mesh;
			# use the stripped form only as a portability fallback, never as a
			# second answer for one exact target.
			if result.size() == before and imported_name.ends_with("-col"):
				_collect_exact_name(root, imported_name.trim_suffix("-col"), result)
			elif result.size() == before and imported_name.ends_with("-colonly"):
				_collect_exact_name(root, imported_name.trim_suffix("-colonly"), result)
	return result


func lifecycle_state(cell_id: String) -> Dictionary:
	return (_lifecycle.get(cell_id, {}) as Dictionary).duplicate(true)


func facade_sharing_rules() -> Array[Dictionary]:
	return _facade_sharing.duplicate(true)


func registry_receipt() -> Dictionary:
	return {
		"ok": _configured and _last_error.is_empty(),
		"configured": _configured,
		"mode": _mode,
		"manifest_path": MANIFEST_PATH,
		"legacy_monolith_path": LEGACY_MONOLITH_PATH,
		"mounted_cell_ids": mounted_cell_ids(),
		"legacy_monolith_mounted": is_instance_valid(_legacy_instance),
		"cell_count": _cells.size(),
		"semantic_owner_count": _semantic_owner_index.size(),
		"compatibility_alias_count": _compatibility_alias_index.size(),
		"lifecycle": _lifecycle.duplicate(true),
		"last_error": _last_error,
		"simultaneous_composition": false,
		"session_only": true,
		"save_authority": false,
		"retired": _retired,
		"startup_timing_ms": _startup_timing.duplicate(true),
	}


## Clear every registry-held node/resource reference before queuing providers.
## The caller waits process frames and performs the independent ObjectDB check.
func public_teardown() -> Dictionary:
	if _retired:
		return {
			"ok": true,
			"api": "Floor01CellRegistry.public_teardown",
			"already_torn_down": true,
			"retired": true,
			"queued_instance_ids": [],
			"retained_instances": 0,
			"retained_resources": 0,
			"retained_strong_references": 0,
			"forced_object_deletion": false,
			"node_name_reach_ins": false,
		}
	_retired = true
	var queued_instance_ids: Array[int] = []
	var providers: Array[Node] = []
	for cell_id in _mounted:
		var provider := _mounted[cell_id] as Node
		if is_instance_valid(provider):
			providers.append(provider)
	if is_instance_valid(_legacy_instance):
		providers.append(_legacy_instance)
	_mounted.clear()
	_legacy_instance = null
	_lifecycle.clear()
	_cells.clear()
	_residency_sets.clear()
	_semantic_owner_index.clear()
	_compatibility_alias_index.clear()
	_cell_node_names.clear()
	_facade_sharing.clear()
	_manifest.clear()
	_mode = ""
	_configured = false
	_last_error = ""
	for provider in providers:
		if is_instance_valid(provider):
			queued_instance_ids.append(provider.get_instance_id())
			provider.queue_free()
	providers.clear()
	return {
		"ok": true,
		"api": "Floor01CellRegistry.public_teardown",
		"queued_instance_ids": queued_instance_ids,
		"retained_instances": 0,
		"retained_resources": 0,
		"retained_strong_references": 0,
		"forced_object_deletion": false,
		"node_name_reach_ins": false,
		"retired": true,
	}


func _exit_tree() -> void:
	# Tree exit owns child destruction; only sever registry references here.
	_retired = true
	_mounted.clear()
	_legacy_instance = null
	_lifecycle.clear()
	_cells.clear()
	_residency_sets.clear()
	_semantic_owner_index.clear()
	_compatibility_alias_index.clear()
	_cell_node_names.clear()
	_facade_sharing.clear()
	_manifest.clear()


func _load_manifest() -> Dictionary:
	if not FileAccess.file_exists(MANIFEST_PATH):
		return _failure("F01 cell registry manifest is missing: %s" % MANIFEST_PATH)
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		return _failure("F01 cell registry manifest could not be opened")
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is not Dictionary:
		return _failure("F01 cell registry manifest is not a JSON object")
	return {"ok": true, "manifest": parsed}


func _validate_manifest(source: Dictionary) -> Array[String]:
	var errors: Array[String] = []
	if str(source.get("schema", "")) != MANIFEST_SCHEMA:
		errors.append("schema must be %s" % MANIFEST_SCHEMA)
	if str(source.get("status", "")) != "PASS":
		errors.append("status must be PASS")
	if str(source.get("floor_id", "")) != "F01":
		errors.append("floor_id must be F01")
	if str(source.get("default_mode", "")) != GeometryConfiguration.OWNER_FIRST_CELLS:
		errors.append("default_mode must be owner_first_cells")
	var supported_modes := _string_array(source.get("supported_session_modes", []))
	var expected_modes: Array[String] = [GeometryConfiguration.OWNER_FIRST_CELLS,
			GeometryConfiguration.LEGACY_MONOLITH]
	supported_modes.sort()
	expected_modes.sort()
	if supported_modes != expected_modes:
		errors.append("supported_session_modes must contain cells and monolith")
	if str(source.get("legacy_monolith_path", "")) != LEGACY_MONOLITH_PATH:
		errors.append("legacy_monolith_path differs from protected rollback input")
	if str(source.get("asset_manifest_path", "")) != ASSET_MANIFEST_PATH:
		errors.append("asset_manifest_path differs from production manifest")
	if not _valid_sha256(str(source.get("asset_manifest_sha256", ""))):
		errors.append("asset_manifest_sha256 must be a lowercase SHA-256")
	if str(source.get("lineage_manifest_path", "")) != LINEAGE_MANIFEST_PATH:
		errors.append("lineage_manifest_path differs from the production lineage sidecar")
	if str(source.get("compatibility_alias_manifest_path", "")) \
			!= COMPATIBILITY_ALIAS_MANIFEST_PATH:
		errors.append("compatibility_alias_manifest_path differs from production aliases")
	var persistent_host: Variant = source.get("persistent_host", null)
	if persistent_host is not Dictionary:
		errors.append("persistent_host must be an object")
	else:
		var host := persistent_host as Dictionary
		if str(host.get("id", "")) != "F01" \
				or not bool(host.get("geometry_free", false)) \
				or not bool(host.get(
						"gameplay_authority_survives_cell_unload", false)):
			errors.append("persistent_host must preserve the geometry-free F01 authority host")
	if bool(source.get("simultaneous_monolith_and_cells_allowed", true)):
		errors.append("simultaneous monolith/cell composition must be refused")
	if bool(source.get("session_mode_is_save_authority", true)):
		errors.append("session geometry mode may not be save authority")
	var refusals: Variant = source.get("refusals", null)
	if refusals is not Dictionary:
		errors.append("refusals must be an object")
	else:
		for refusal in ["unknown_cell", "duplicate_semantic_owner",
				"dependency_cycle", "incompatible_alias",
				"simultaneous_monolith_and_cells"]:
			if not bool((refusals as Dictionary).get(refusal, false)):
				errors.append("registry must declare %s refusal" % refusal)
	_validate_cells(source.get("cells", []), errors)
	_validate_residency(source.get("residency_sets", []), errors)
	_validate_indexes(source, errors)
	_validate_facade_sharing(source.get("facade_sharing", []), errors)
	return errors


func _validate_cells(raw_cells: Variant, errors: Array[String]) -> void:
	if raw_cells is not Array:
		errors.append("cells must be an array")
		return
	var seen := {}
	var local_semantics := {}
	var local_aliases := {}
	for raw_cell in raw_cells:
		if raw_cell is not Dictionary:
			errors.append("each cell descriptor must be an object")
			continue
		var cell := raw_cell as Dictionary
		var cell_id := str(cell.get("id", ""))
		if cell_id not in TARGET_CELL_IDS:
			errors.append("unknown cell id: %s" % cell_id)
			continue
		if seen.has(cell_id):
			errors.append("duplicate cell id: %s" % cell_id)
			continue
		seen[cell_id] = true
		var resource_path := str(cell.get("resource_path", ""))
		if not resource_path.begins_with(CELL_RESOURCE_PREFIX) \
				or not resource_path.ends_with(".gltf"):
			errors.append("%s has an invalid production resource path" % cell_id)
		var bin_path := str(cell.get("bin_resource_path", ""))
		if not bin_path.begins_with(CELL_RESOURCE_PREFIX) \
				or not bin_path.ends_with(".bin"):
			errors.append("%s has an invalid production BIN path" % cell_id)
		for hash_key in ["gltf_sha256", "bin_sha256"]:
			if not _valid_sha256(str(cell.get(hash_key, ""))):
				errors.append("%s.%s must be a SHA-256" % [cell_id, hash_key])
		if not bool(cell.get("independently_addressable", false)):
			errors.append("%s must be independently addressable" % cell_id)
		for dependency in _require_string_array(cell, "dependencies", errors, cell_id):
			if dependency not in TARGET_CELL_IDS or dependency == cell_id:
				errors.append("%s has invalid dependency %s" % [cell_id, dependency])
		for identity in _require_string_array(cell, "semantic_owners", errors, cell_id):
			if local_semantics.has(identity):
				errors.append("semantic identity %s has duplicate owners" % identity)
			local_semantics[identity] = cell_id
		for alias_identity in _require_string_array(cell,
				"compatibility_aliases", errors, cell_id):
			var owners: Array = local_aliases.get(alias_identity, [])
			owners.append(cell_id)
			local_aliases[alias_identity] = owners
		var lifecycle: Variant = cell.get("lifecycle", null)
		if lifecycle is not Dictionary:
			errors.append("%s has no lifecycle declaration" % cell_id)
		else:
			_validate_lifecycle(cell_id, lifecycle as Dictionary, errors)
	if seen.size() != TARGET_CELL_IDS.size():
		errors.append("cells must declare exactly the 17 reviewed owner cells")
	for cell_id in TARGET_CELL_IDS:
		if not seen.has(cell_id):
			errors.append("missing cell id: %s" % cell_id)
	if errors.is_empty():
		_validate_dependency_cycles(raw_cells as Array, errors)


func _validate_residency(raw_sets: Variant, errors: Array[String]) -> void:
	if raw_sets is not Array:
		errors.append("residency_sets must be an array")
		return
	var seen := {}
	for raw_set in raw_sets:
		if raw_set is not Dictionary:
			errors.append("each residency set must be an object")
			continue
		var row := raw_set as Dictionary
		var set_id := str(row.get("id", ""))
		if set_id.is_empty() or seen.has(set_id):
			errors.append("residency set ids must be nonempty and unique")
			continue
		seen[set_id] = true
		var cell_ids := _require_string_array(row, "cell_ids", errors, set_id)
		for cell_id in cell_ids:
			if cell_id not in TARGET_CELL_IDS:
				errors.append("%s contains unknown cell %s" % [set_id, cell_id])
		if set_id == FULL_RECOMPOSITION:
			var sorted := cell_ids.duplicate()
			sorted.sort()
			var expected := TARGET_CELL_IDS.duplicate()
			expected.sort()
			if sorted != expected:
				errors.append("FULL_RECOMPOSITION must contain each reviewed cell exactly once")
	if not seen.has(FULL_RECOMPOSITION):
		errors.append("FULL_RECOMPOSITION residency set is required")


func _validate_indexes(source: Dictionary, errors: Array[String]) -> void:
	var semantic_raw: Variant = source.get("semantic_owner_index", null)
	if semantic_raw is not Dictionary:
		errors.append("semantic_owner_index must be an object")
	else:
		var expected_semantic := {}
		for raw_cell in source.get("cells", []):
			if raw_cell is not Dictionary:
				continue
			var cell := raw_cell as Dictionary
			for identity in _string_array(cell.get("semantic_owners", [])):
				expected_semantic[identity] = str(cell.get("id", ""))
		if semantic_raw != expected_semantic:
			errors.append("semantic_owner_index does not exactly match cell ownership")
	var alias_raw: Variant = source.get("compatibility_alias_index", null)
	if alias_raw is not Dictionary:
		errors.append("compatibility_alias_index must be an object")
	else:
		var expected_alias := {}
		for raw_cell in source.get("cells", []):
			if raw_cell is not Dictionary:
				continue
			var cell := raw_cell as Dictionary
			var cell_id := str(cell.get("id", ""))
			for alias_identity in _string_array(cell.get("compatibility_aliases", [])):
				var owners: Array = expected_alias.get(alias_identity, [])
				owners.append(cell_id)
				expected_alias[alias_identity] = owners
		for alias_identity in expected_alias:
			var targets := _validate_alias_targets(alias_identity,
					(alias_raw as Dictionary).get(alias_identity, []), errors)
			var actual: Array[String] = []
			for target in targets:
				var cell_id := str(target.get("cell_id", ""))
				if cell_id not in actual:
					actual.append(cell_id)
			var expected := _string_array(expected_alias[alias_identity])
			actual.sort()
			expected.sort()
			if actual != expected:
				errors.append("compatibility alias index differs for %s" % alias_identity)
		if (alias_raw as Dictionary).size() != expected_alias.size():
			errors.append("compatibility_alias_index has missing or undeclared aliases")


func _validate_facade_sharing(raw_rules: Variant, errors: Array[String]) -> void:
	if raw_rules is not Array:
		errors.append("facade_sharing must be an array")
		return
	var seen := {}
	for raw_rule in raw_rules:
		if raw_rule is not Dictionary:
			errors.append("each facade sharing rule must be an object")
			continue
		var rule := raw_rule as Dictionary
		var rule_id := str(rule.get("id", ""))
		if rule_id.is_empty() or seen.has(rule_id):
			errors.append("facade sharing rule ids must be nonempty and unique")
			continue
		seen[rule_id] = true
		var referenced := _facade_rule_cells(rule)
		if referenced.size() < 2:
			errors.append("%s must name at least two sharing cells" % rule_id)
		for cell_id in referenced:
			if cell_id not in TARGET_CELL_IDS:
				errors.append("%s references unknown cell %s" % [rule_id, cell_id])
	var exact_rules := {
		"F01_ORISON_INTERIOR_FACADE": {
			"cell_ids": ["CELL_ORISON_F01_INTERIOR",
					"CELL_ORISON_FACADE_SHELL"],
			"rule": "facade remains independently owned and co-resident for the interior envelope view",
		},
		"F01_STREET_FACADE": {
			"cell_ids": ["CELL_SITE_STREET_COMMON",
					"CELL_ORISON_FACADE_SHELL"],
			"rule": "the same facade cell is shared by the street-side envelope without geometry duplication",
		},
	}
	if seen.size() != exact_rules.size():
		errors.append("facade_sharing must contain exactly the two reviewed rules")
	for raw_rule in raw_rules:
		if raw_rule is not Dictionary:
			continue
		var rule := raw_rule as Dictionary
		var rule_id := str(rule.get("id", ""))
		if not exact_rules.has(rule_id):
			errors.append("unknown facade sharing rule: %s" % rule_id)
			continue
		var expected := exact_rules[rule_id] as Dictionary
		if _string_array(rule.get("cell_ids", [])) \
				!= _string_array(expected.cell_ids) \
				or str(rule.get("rule", "")) != str(expected.rule):
			errors.append("%s differs from the reviewed facade-sharing rule" % rule_id)


func _validate_lifecycle(cell_id: String, lifecycle: Dictionary,
		errors: Array[String]) -> void:
	var expected_transitions: Array[String] = [
		"UNLOADED_TO_LOADING",
		"LOADING_TO_RESIDENT",
		"RESIDENT_TO_UNLOADING",
		"UNLOADING_TO_UNLOADED",
	]
	if str(lifecycle.get("initial_state", "")) != "UNLOADED":
		errors.append("%s lifecycle must begin UNLOADED" % cell_id)
	if _string_array(lifecycle.get("allowed_transitions", [])) != expected_transitions:
		errors.append("%s lifecycle transitions differ" % cell_id)
	if bool(lifecycle.get("persistent_gameplay_authority", true)):
		errors.append("%s geometry may not own gameplay authority" % cell_id)
	if bool(lifecycle.get("unload_destroys_durable_authority", true)):
		errors.append("%s unload may not destroy durable authority" % cell_id)
	if not bool(lifecycle.get("teardown_api_required", false)):
		errors.append("%s must require public teardown" % cell_id)


func _validate_alias_targets(alias_identity: String, raw_targets: Variant,
		errors: Array[String]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if raw_targets is not Array or (raw_targets as Array).is_empty():
		errors.append("compatibility alias %s has no target array" % alias_identity)
		return result
	var seen := {}
	for raw_target in raw_targets:
		if raw_target is not Dictionary:
			errors.append("compatibility alias %s has a malformed target" % alias_identity)
			continue
		var target := raw_target as Dictionary
		var cell_id := str(target.get("cell_id", ""))
		var node_index: int = int(target.get("node_index", -1))
		var mesh_index: int = int(target.get("mesh_index", -1))
		if cell_id not in TARGET_CELL_IDS or node_index < 0 or mesh_index < 0:
			errors.append("compatibility alias %s has an invalid target" % alias_identity)
			continue
		var key := "%s:%d:%d" % [cell_id, node_index, mesh_index]
		if seen.has(key):
			errors.append("compatibility alias %s has a duplicate target" % alias_identity)
			continue
		seen[key] = true
		result.append(target.duplicate(true))
	return result


func _validate_bound_files(source: Dictionary, errors: Array[String]) -> void:
	for required_path in [ASSET_MANIFEST_PATH, COMPATIBILITY_ALIAS_MANIFEST_PATH]:
		if not FileAccess.file_exists(required_path):
			errors.append("bound production manifest is missing: %s" % required_path)
	if FileAccess.file_exists(ASSET_MANIFEST_PATH) \
			and _timed_sha256(ASSET_MANIFEST_PATH,
					"configure.asset_manifest_sha256_ms") \
			!= str(source.get("asset_manifest_sha256", "")):
		errors.append("asset manifest hash differs from registry binding")
	var asset_parse_started := Time.get_ticks_usec()
	var asset_manifest := _read_json_object(ASSET_MANIFEST_PATH)
	_startup_timing["configure.asset_manifest_parse_ms"] = \
			_elapsed_ms(asset_parse_started)
	var alias_manifest: Dictionary = {}
	if asset_manifest.is_empty():
		errors.append("asset manifest is malformed")
	else:
		if str(asset_manifest.get("schema", "")) != ASSET_MANIFEST_SCHEMA \
				or str(asset_manifest.get("status", "")) != "PASS" \
				or str(asset_manifest.get("floor_id", "")) != "F01":
			errors.append("asset manifest header is not the accepted F01 production contract")
		var generated: Variant = asset_manifest.get("generated_manifests", null)
		if generated is not Dictionary:
			errors.append("asset manifest generated_manifests binding is missing")
		else:
			# The lineage sidecar is bound by hash only. It is never parsed at
			# boot; its content has no production reader.
			_validate_generated_manifest_binding("lineage",
					LINEAGE_MANIFEST_PATH,
					_repository_file_path(LINEAGE_MANIFEST_PATH), "",
					generated as Dictionary, errors, false)
			alias_manifest = _validate_generated_manifest_binding(
					"compatibility_aliases",
					"game/" + COMPATIBILITY_ALIAS_MANIFEST_PATH.trim_prefix("res://"),
					COMPATIBILITY_ALIAS_MANIFEST_PATH,
					COMPATIBILITY_ALIAS_MANIFEST_SCHEMA,
					generated as Dictionary, errors, true)
	_validate_alias_manifest_contract(source, alias_manifest, errors)
	var parsed_cells := {}
	_cell_node_names.clear()
	var cell_hash_key := "configure.cell_asset_sha256_ms"
	var descriptor_key := "configure.cell_descriptor_parse_ms"
	_startup_timing[cell_hash_key] = 0.0
	_startup_timing[descriptor_key] = 0.0
	_startup_timing["configure.cell_asset_files_hashed"] = 0.0
	for raw_cell in source.get("cells", []):
		if raw_cell is not Dictionary:
			continue
		var cell := raw_cell as Dictionary
		var cell_id := str(cell.get("id", ""))
		var gltf_path := str(cell.get("resource_path", ""))
		var bin_path := str(cell.get("bin_resource_path", ""))
		if not FileAccess.file_exists(gltf_path):
			errors.append("%s GLTF is missing" % cell_id)
			continue
		if not FileAccess.file_exists(bin_path):
			errors.append("%s BIN is missing" % cell_id)
		if _timed_sha256(gltf_path, cell_hash_key) != str(cell.get("gltf_sha256", "")):
			errors.append("%s GLTF hash differs" % cell_id)
		_startup_timing["configure.cell_asset_files_hashed"] += 1.0
		if FileAccess.file_exists(bin_path):
			if _timed_sha256(bin_path, cell_hash_key) != str(cell.get("bin_sha256", "")):
				errors.append("%s BIN hash differs" % cell_id)
			_startup_timing["configure.cell_asset_files_hashed"] += 1.0
		var descriptor_started := Time.get_ticks_usec()
		var file := FileAccess.open(gltf_path, FileAccess.READ)
		var parsed: Variant = JSON.parse_string(file.get_as_text()) \
				if file != null else null
		_startup_timing[descriptor_key] += _elapsed_ms(descriptor_started)
		if parsed is not Dictionary:
			errors.append("%s GLTF descriptor is malformed" % cell_id)
			continue
		parsed_cells[cell_id] = parsed
		var names: Array[String] = []
		var nodes: Variant = (parsed as Dictionary).get("nodes", [])
		if nodes is not Array:
			errors.append("%s GLTF nodes are malformed" % cell_id)
			continue
		for raw_node in nodes:
			names.append(str((raw_node as Dictionary).get("name", "")) \
					if raw_node is Dictionary else "")
		_cell_node_names[cell_id] = names
	var alias_check_started := Time.get_ticks_usec()
	for alias_identity in source.get("compatibility_alias_index", {}):
		var targets := _validate_alias_targets(str(alias_identity),
				source.compatibility_alias_index[alias_identity], errors)
		for target in targets:
			var cell_id := str(target.cell_id)
			if not parsed_cells.has(cell_id):
				continue
			var gltf := parsed_cells[cell_id] as Dictionary
			var nodes: Array = gltf.get("nodes", []) as Array
			var meshes: Array = gltf.get("meshes", []) as Array
			var node_index := int(target.node_index)
			var mesh_index := int(target.mesh_index)
			if node_index >= nodes.size() or mesh_index >= meshes.size():
				errors.append("compatibility alias %s target is outside %s" % [
					alias_identity, cell_id])
				continue
			var node := nodes[node_index] as Dictionary
			if int(node.get("mesh", -1)) != mesh_index:
				errors.append("compatibility alias %s node/mesh binding differs" \
						% alias_identity)
	_startup_timing["configure.alias_target_check_ms"] = \
			_elapsed_ms(alias_check_started)


## Bind one generated manifest recorded in the asset manifest. The file is
## always hash-verified; when `parse_header` is false it is never read as
## JSON; when true the parsed object is returned for the caller to reuse.
func _validate_generated_manifest_binding(binding_id: String,
		repository_path: String, file_path: String, expected_schema: String,
		generated: Dictionary, errors: Array[String],
		parse_header: bool) -> Dictionary:
	var raw_binding: Variant = generated.get(binding_id, null)
	if raw_binding is not Dictionary:
		errors.append("asset manifest has no %s binding" % binding_id)
		return {}
	var binding := raw_binding as Dictionary
	if str(binding.get("path", "")) != repository_path:
		errors.append("asset manifest %s path differs" % binding_id)
	var expected_hash := str(binding.get("sha256", ""))
	if not _valid_sha256(expected_hash):
		errors.append("asset manifest %s hash is malformed" % binding_id)
	elif not FileAccess.file_exists(file_path):
		errors.append("bound %s manifest is missing: %s" % [binding_id,
				repository_path])
	elif _timed_sha256(file_path, "configure.%s_sha256_ms" % binding_id) \
			!= expected_hash:
		errors.append("asset manifest %s hash differs" % binding_id)
	_startup_timing["configure.%s_parsed" % binding_id] = parse_header
	if not parse_header:
		return {}
	var parse_started := Time.get_ticks_usec()
	var child_manifest := _read_json_object(file_path)
	_startup_timing["configure.%s_parse_ms" % binding_id] = \
			_elapsed_ms(parse_started)
	if child_manifest.is_empty() \
			or str(child_manifest.get("schema", "")) != expected_schema \
			or str(child_manifest.get("status", "")) != "PASS" \
			or str(child_manifest.get("floor_id", "")) != "F01":
		errors.append("%s manifest header is not the accepted F01 contract" % binding_id)
	return child_manifest


func _validate_alias_manifest_contract(source: Dictionary,
		alias_manifest: Dictionary, errors: Array[String]) -> void:
	if alias_manifest.is_empty():
		return
	var canonical_raw: Variant = alias_manifest.get("aliases", null)
	var registry_raw: Variant = source.get("compatibility_alias_index", null)
	if canonical_raw is not Dictionary or registry_raw is not Dictionary:
		errors.append("canonical alias content or registry alias index is malformed")
		return
	var canonical := canonical_raw as Dictionary
	var registry_aliases := registry_raw as Dictionary
	if not bool(alias_manifest.get("production_asset", false)):
		errors.append("canonical alias manifest is not marked as a production asset")
	if int(alias_manifest.get("identity_count", -1)) != canonical.size():
		errors.append("canonical alias identity_count differs from alias content")
	var incompatible: Variant = alias_manifest.get("incompatible_aliases", null)
	if incompatible is not Array or not (incompatible as Array).is_empty():
		errors.append("canonical alias manifest reports incompatible aliases")
	var canonical_ids: Array[String] = []
	var registry_ids: Array[String] = []
	var derived_splits: Array[String] = []
	for raw_identity in canonical:
		var identity := str(raw_identity)
		canonical_ids.append(identity)
		if canonical[raw_identity] is Array \
				and (canonical[raw_identity] as Array).size() > 1:
			derived_splits.append(identity)
	for raw_identity in registry_aliases:
		registry_ids.append(str(raw_identity))
	canonical_ids.sort()
	registry_ids.sort()
	derived_splits.sort()
	if canonical_ids != registry_ids:
		errors.append("registry alias identities differ from canonical alias manifest")
	var declared_splits := _string_array(alias_manifest.get("split_identities", []))
	declared_splits.sort()
	if declared_splits != derived_splits \
			or int(alias_manifest.get("split_identity_count", -1)) \
			!= derived_splits.size():
		errors.append("canonical split-alias receipt differs from alias content")
	var resource_paths := {}
	for raw_cell in source.get("cells", []):
		if raw_cell is Dictionary:
			var cell := raw_cell as Dictionary
			resource_paths[str(cell.get("id", ""))] = str(
					cell.get("resource_path", ""))
	for alias_identity in canonical_ids:
		if not registry_aliases.has(alias_identity):
			continue
		var canonical_targets: Variant = canonical[alias_identity]
		var registry_targets: Variant = registry_aliases[alias_identity]
		if canonical_targets is not Array or registry_targets is not Array:
			errors.append("alias %s target content is malformed" % alias_identity)
			continue
		if (canonical_targets as Array).size() != (registry_targets as Array).size():
			errors.append("alias %s target count differs from canonical manifest" \
					% alias_identity)
			continue
		for index in (canonical_targets as Array).size():
			var canonical_target: Variant = (canonical_targets as Array)[index]
			var registry_target: Variant = (registry_targets as Array)[index]
			if canonical_target is not Dictionary or registry_target is not Dictionary:
				errors.append("alias %s target %d is malformed" % [alias_identity, index])
				continue
			var expected := canonical_target as Dictionary
			var actual := registry_target as Dictionary
			for field in ["cell_id", "node_index", "mesh_index"]:
				if str(actual.get(field, "")) != str(expected.get(field, "")):
					errors.append("alias %s target %d %s differs from canonical manifest" % [
						alias_identity, index, field])
			var cell_id := str(expected.get("cell_id", ""))
			if str(expected.get("resource_path", "")) != str(
					resource_paths.get(cell_id, "")):
				errors.append("alias %s target %d resource path differs from owner cell" % [
					alias_identity, index])


func _read_json_object(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}


func _validate_dependency_cycles(raw_cells: Array, errors: Array[String]) -> void:
	var graph := {}
	for raw_cell in raw_cells:
		var cell := raw_cell as Dictionary
		graph[str(cell.get("id", ""))] = _string_array(cell.get("dependencies", []))
	var visiting := {}
	var visited := {}
	for cell_id in TARGET_CELL_IDS:
		if not _cycle_visit(cell_id, graph, visiting, visited):
			errors.append("cell dependency cycle includes %s" % cell_id)
			return


func _cycle_visit(cell_id: String, graph: Dictionary, visiting: Dictionary,
		visited: Dictionary) -> bool:
	if visiting.has(cell_id):
		return false
	if visited.has(cell_id):
		return true
	visiting[cell_id] = true
	for dependency in _string_array(graph.get(cell_id, [])):
		if not _cycle_visit(dependency, graph, visiting, visited):
			return false
	visiting.erase(cell_id)
	visited[cell_id] = true
	return true


func _index_manifest(source: Dictionary) -> void:
	_cells.clear()
	_residency_sets.clear()
	_lifecycle.clear()
	for raw_cell in source.cells:
		var cell := raw_cell as Dictionary
		var cell_id := str(cell.id)
		_cells[cell_id] = cell.duplicate(true)
		_lifecycle[cell_id] = {
			"declared": cell.get("lifecycle"),
			"state": "UNLOADED",
			"instance_id": 0,
		}
	for raw_set in source.residency_sets:
		var row := raw_set as Dictionary
		_residency_sets[str(row.id)] = _string_array(row.cell_ids)
	_semantic_owner_index = (source.semantic_owner_index as Dictionary).duplicate(true)
	_compatibility_alias_index.clear()
	for alias_identity in source.compatibility_alias_index:
		_compatibility_alias_index[str(alias_identity)] = (
				source.compatibility_alias_index[alias_identity] as Array).duplicate(true)
	_facade_sharing.clear()
	for raw_rule in source.facade_sharing:
		_facade_sharing.append((raw_rule as Dictionary).duplicate(true))


func _mount_cell(cell_id: String) -> Dictionary:
	if _legacy_instance != null:
		return _failure("cannot mount a cell while the legacy monolith is mounted")
	var descriptor := _cells.get(cell_id, {}) as Dictionary
	if descriptor.is_empty():
		return _failure("unknown F01 cell: %s" % cell_id)
	var resource_path := str(descriptor.resource_path)
	if not resource_path.begins_with(CELL_RESOURCE_PREFIX) \
			or resource_path.get_extension().to_lower() != "gltf" \
			or not FileAccess.file_exists(resource_path):
		return _failure("invalid or missing production cell resource: %s" \
				% resource_path)
	var started := Time.get_ticks_usec()
	var packed := ResourceLoader.load(resource_path, "PackedScene",
			ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	var load_ms := float(Time.get_ticks_usec() - started) / 1000.0
	if packed == null:
		return _failure("could not load %s" % resource_path)
	started = Time.get_ticks_usec()
	var imported := packed.instantiate()
	var instantiate_ms := float(Time.get_ticks_usec() - started) / 1000.0
	packed = null
	if imported == null:
		return _failure("could not instantiate %s" % resource_path)
	var wrapper := Node3D.new()
	wrapper.name = cell_id
	wrapper.set_meta(&"floor01_owner_cell", cell_id)
	wrapper.set_meta(&"floor01_geometry_provider", "owner_first_cell")
	started = Time.get_ticks_usec()
	wrapper.add_child(imported)
	add_child(wrapper)
	var attach_ms := float(Time.get_ticks_usec() - started) / 1000.0
	_mounted[cell_id] = wrapper
	_lifecycle[cell_id] = {
		"declared": descriptor.lifecycle,
		"state": "RESIDENT",
		"instance_id": wrapper.get_instance_id(),
		"resource_path": resource_path,
	}
	return {
		"ok": true,
		"cell_id": cell_id,
		"resource_path": resource_path,
		"instance_id": wrapper.get_instance_id(),
		"load_ms": load_ms,
		"instantiate_ms": instantiate_ms,
		"attach_ms": attach_ms,
	}


func _mount_legacy() -> Dictionary:
	if not _mounted.is_empty():
		return _failure("owner-first cells and legacy monolith cannot be composed together")
	if is_instance_valid(_legacy_instance):
		return {
			"ok": true,
			"mode": _mode,
			"residency_id": FULL_RECOMPOSITION,
			"already_mounted": true,
			"owner_first_cells_loaded": false,
			"legacy_monolith_loaded": true,
			"simultaneous_composition": false,
		}
	var mount_started := Time.get_ticks_usec()
	var started := mount_started
	var packed := ResourceLoader.load(LEGACY_MONOLITH_PATH, "PackedScene",
			ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	_startup_timing["mount.load_ms"] = _elapsed_ms(started)
	if packed == null:
		return _failure("could not load protected F01 rollback monolith")
	started = Time.get_ticks_usec()
	var imported := packed.instantiate()
	_startup_timing["mount.instantiate_ms"] = _elapsed_ms(started)
	packed = null
	if imported == null:
		return _failure("could not instantiate protected F01 rollback monolith")
	imported.name = "LegacyMonolith"
	imported.set_meta(&"floor01_geometry_provider", "legacy_monolith")
	started = Time.get_ticks_usec()
	add_child(imported)
	_startup_timing["mount.attach_ms"] = _elapsed_ms(started)
	_legacy_instance = imported
	_startup_timing["mount.cell_count"] = 0.0
	_startup_timing["mount.total_ms"] = _elapsed_ms(mount_started)
	print("[F01 REGISTRY] %s mount %s %s" % [_mode, FULL_RECOMPOSITION,
			_timing_summary("mount.")])
	return {
		"ok": true,
		"mode": _mode,
		"residency_id": FULL_RECOMPOSITION,
		"legacy_monolith_path": LEGACY_MONOLITH_PATH,
		"instance_id": imported.get_instance_id(),
		"owner_first_cells_loaded": false,
		"legacy_monolith_loaded": true,
		"simultaneous_composition": false,
		"timing_ms": _startup_timing.duplicate(true),
	}


func _rollback_cells(cell_ids: Array[String]) -> void:
	# A residency request is transactional for the cells it introduces. Keep any
	# provider that was resident before the request, but release every provider
	# mounted by a request that later fails.
	for cell_id in cell_ids:
		var provider := _mounted.get(cell_id) as Node
		_mounted.erase(cell_id)
		if _lifecycle.has(cell_id):
			var lifecycle := _lifecycle[cell_id] as Dictionary
			lifecycle["state"] = "UNLOADED"
			lifecycle["instance_id"] = 0
			lifecycle.erase("resource_path")
			_lifecycle[cell_id] = lifecycle
		if is_instance_valid(provider):
			provider.queue_free()


func _append_dependencies(cell_id: String, visiting: Dictionary,
		visited: Dictionary, ordered: Array[String]) -> bool:
	if visiting.has(cell_id):
		_last_error = "dependency cycle reached %s" % cell_id
		return false
	if visited.has(cell_id):
		return true
	if not _cells.has(cell_id):
		_last_error = "unknown dependency cell %s" % cell_id
		return false
	visiting[cell_id] = true
	for dependency in _string_array((_cells[cell_id] as Dictionary).dependencies):
		if not _append_dependencies(dependency, visiting, visited, ordered):
			return false
	visiting.erase(cell_id)
	visited[cell_id] = true
	ordered.append(cell_id)
	return true


func _collect_geometry(root: Node, output: Array[GeometryInstance3D]) -> void:
	if root is GeometryInstance3D:
		output.append(root as GeometryInstance3D)
	for child in root.get_children():
		_collect_geometry(child, output)


func _collect_exact_name(root: Node, wanted: String, output: Array[Node]) -> void:
	if String(root.name) == wanted and root not in output:
		output.append(root)
	for child in root.get_children():
		_collect_exact_name(child, wanted, output)


func _require_string_array(row: Dictionary, key: String,
		errors: Array[String], owner: String) -> Array[String]:
	if not row.has(key) or row[key] is not Array:
		errors.append("%s.%s must be an array" % [owner, key])
		return []
	var result := _string_array(row[key])
	if result.size() != (row[key] as Array).size():
		errors.append("%s.%s must contain nonempty unique strings" % [owner, key])
	return result


func _string_array(raw: Variant) -> Array[String]:
	var result: Array[String] = []
	if raw is not Array:
		return result
	for value in raw:
		var text := str(value).strip_edges()
		if text.is_empty() or text in result:
			continue
		result.append(text)
	return result


func _canonical_alias_identity(requested: String) -> String:
	if _compatibility_alias_index.has(requested):
		return requested
	for suffix: String in ["-col", "-colonly"]:
		var source_identity: String = requested + suffix
		if _compatibility_alias_index.has(source_identity):
			return source_identity
	return requested


func _facade_rule_cells(rule: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for key in ["cell_ids", "cells", "owners"]:
		for cell_id in _string_array(rule.get(key, [])):
			if cell_id not in result:
				result.append(cell_id)
	for key in ["owner", "dependent_cell", "counterpart", "facade_cell",
			"interior_cell", "exterior_cell"]:
		var cell_id := str(rule.get(key, ""))
		if not cell_id.is_empty() and cell_id not in result:
			result.append(cell_id)
	return result


func _valid_sha256(value: String) -> bool:
	if value.length() != 64 or value != value.to_lower():
		return false
	for character in value:
		if character not in "0123456789abcdef":
			return false
	return true


func _failure(error: String, extra: Dictionary = {}) -> Dictionary:
	_last_error = error
	var result := {"ok": false, "error": error}
	result.merge(extra, true)
	return result


## Resolve a repository-relative path from the project directory. The game
## project lives one level below the repository root, so this is only
## reachable from a source checkout.
func _repository_file_path(repository_relative: String) -> String:
	var project_dir := ProjectSettings.globalize_path("res://").trim_suffix("/")
	return project_dir.get_base_dir().path_join(repository_relative)


func _timed_sha256(path: String, timing_key: String) -> String:
	var started := Time.get_ticks_usec()
	var digest := FileAccess.get_sha256(path)
	_startup_timing[timing_key] = float(_startup_timing.get(timing_key, 0.0)) \
			+ _elapsed_ms(started)
	return digest


func _elapsed_ms(started_usec: int) -> float:
	return float(Time.get_ticks_usec() - started_usec) / 1000.0


func _timing_summary(prefix: String) -> String:
	var keys: Array[String] = []
	for raw_key in _startup_timing:
		if str(raw_key).begins_with(prefix):
			keys.append(str(raw_key))
	keys.sort()
	var parts: Array[String] = []
	for key in keys:
		var value: Variant = _startup_timing[key]
		var short := key.trim_prefix(prefix)
		if value is float and short.ends_with("_ms"):
			parts.append("%s=%.3f" % [short, float(value)])
		else:
			parts.append("%s=%s" % [short, str(value)])
	return " ".join(parts)
