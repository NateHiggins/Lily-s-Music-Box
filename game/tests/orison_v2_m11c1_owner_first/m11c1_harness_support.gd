extends RefCounted
## Shared, fail-closed input and measurement support for the M11C1 test-only
## owner-first rehearsal. Ownership is read only from author/export receipts.

const CONFIG_SCHEMA := "orison.m11c1.target-cell-runtime-config.v1"
const PARTITION_SCHEMA := "orison.floor01.owner-first-partition.v1"
const LINEAGE_SCHEMA := "orison.floor01.owner-first-lineage.v1"
const EQUIVALENCE_SCHEMA := "orison.floor01.owner-first-equivalence.v1"
const RECOMPOSITION_SCHEMA := "orison.m11c0.floor01-recomposition.v1"
const EXPORT_SCHEMA := "orison.floor01.owner-first-export.v1"
const TRANSACTION_SCHEMA := "orison.floor01.owner-first-transaction.v1"
const CONFIG_ENV := "M11C1_RUNTIME_CONFIG"

const TARGET_CELL_IDS := [
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

const SHOP_CELL_IDS := [
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

const PASSAGE_SHOP_CELL_IDS := [
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

const REQUIRED_RESIDENCY := {
	"ORISON_INTERIOR_PLUS_FACADE": [
		"CELL_ORISON_F01_INTERIOR", "CELL_ORISON_FACADE_SHELL"],
	"STREET_PLUS_FACADE": [
		"CELL_SITE_STREET_COMMON", "CELL_ORISON_FACADE_SHELL"],
	"PASSAGE_ONLY": ["CELL_PASSAGE"],
	"SHOP_BAR_ONLY": ["CELL_SHOP_BAR"],
	"SHOP_BODEGA_ONLY": ["CELL_SHOP_BODEGA"],
	"SHOP_MODEL_LAUNDRY_ONLY": ["CELL_SHOP_MODEL_LAUNDRY"],
	"SHOP_SHOE_REBUILDING_ONLY": ["CELL_SHOP_SHOE_REBUILDING"],
	"SHOP_KEYS_CUT_ONLY": ["CELL_SHOP_KEYS_CUT"],
	"SHOP_HARDWARE_PAINT_ONLY": ["CELL_SHOP_HARDWARE_PAINT"],
	"SHOP_FUNERAL_PARLOUR_ONLY": ["CELL_SHOP_FUNERAL_PARLOUR"],
	"SHOP_PHOTO_SUPPLIES_ONLY": ["CELL_SHOP_PHOTO_SUPPLIES"],
	"SHOP_RADIO_SERVICE_ONLY": ["CELL_SHOP_RADIO_SERVICE"],
	"SHOP_PAWNBROKER_ONLY": ["CELL_SHOP_PAWNBROKER"],
	"SHOP_NEWS_CIGARS_ONLY": ["CELL_SHOP_NEWS_CIGARS"],
	"SHOP_OTIS_SON_ONLY": ["CELL_SHOP_OTIS_SON"],
	"SHOP_LUNCHEONETTE_ONLY": ["CELL_SHOP_LUNCHEONETTE"],
	"FULL_RECOMPOSITION": TARGET_CELL_IDS,
}

const REQUIRED_SEAM_IDS := [
	"SEAM_ORISON_SOUTH_SHELL_STREET",
	"SEAM_STREET_PASSAGE_PORTAL",
	"SEAM_PASSAGE_SHOP_AISLES",
	"SEAM_BODEGA_STREET",
	"SEAM_SHELL_INTERIOR",
]

const SPECIAL_SEMANTICS := [
	"F01_DOOR_06",
	"F01_BODEGA_DOOR",
	"F01_BAR_DOOR",
	"PASSAGE_PORTAL_LT_W",
	"PASSAGE_PORTAL_LT_E",
]

const SITE_SHOP_SUBPREFIXES := [
	"SITE_SHOP_DOOR_",
	"SITE_SHOP_HOURS_",
	"SITE_SHOP_SIGN_",
	"SITE_SHOP_LT_",
	"SITE_SHOP_IN",
]

const PROTECTED_RESOURCE_PATHS := [
	"res://assets/building/floor_01.gltf",
	"res://assets/building/floor_01.bin",
	"res://data/building_layout.json",
]


static func load_inputs() -> Dictionary:
	var errors: Array[String] = []
	var blockers: Array[String] = []
	var config_path := OS.get_environment(CONFIG_ENV).strip_edges()
	if config_path.is_empty():
		errors.append("%s must name the explicit disposable runtime config" % CONFIG_ENV)
		return _input_result(config_path, {}, "", {}, "", {}, "", {},
				[], {}, {}, errors, blockers)
	var config := load_json(config_path, errors, "runtime config")
	if str(config.get("schema", "")) != CONFIG_SCHEMA:
		errors.append("runtime config schema must be %s" % CONFIG_SCHEMA)
	if str(config.get("authority", "")) != "disposable_harness_only":
		errors.append("runtime config authority must be disposable_harness_only")

	var partition_path := resolve_path(str(config.get("partition_manifest", "")),
			config_path)
	var lineage_path := resolve_path(str(config.get("lineage_manifest", "")),
			config_path)
	var equivalence_path := resolve_path(str(config.get(
			"equivalence_receipt", "")), config_path)
	var partition := load_json(partition_path, errors, "owner-first partition")
	var lineage := load_json(lineage_path, errors, "owner-first lineage")
	var equivalence := load_json(equivalence_path, errors,
			"owner-first equivalence")
	_validate_authoritative_sources(config, errors)
	_validate_receipt_headers(partition, lineage, equivalence, errors)
	var bound_receipts := _validate_partition_transaction(config, partition_path,
			partition, lineage_path, lineage, equivalence_path, equivalence, errors)
	var cells := _cell_descriptors(config, partition, partition_path, errors,
			blockers)
	var residency_sets := _residency_sets(config, errors)
	var lineage_rows := _lineage_rows(lineage)
	var semantic_index := _validate_lineage_and_semantics(config, lineage,
			lineage_rows, errors)
	_validate_seams_and_capture(config, semantic_index, errors, blockers)
	_validate_protected_boundary(config, partition, cells, errors)
	var result := _input_result(config_path, config, partition_path, partition,
			lineage_path, lineage, equivalence_path, equivalence, cells,
			residency_sets, semantic_index, errors, blockers)
	result["bound_receipts"] = bound_receipts
	result["authoritative_sources"] = authoritative_source_receipt(config)
	return result


static func _validate_authoritative_sources(config: Dictionary,
		errors: Array[String]) -> void:
	var raw: Variant = config.get("authoritative_sources", {})
	if raw is not Dictionary:
		errors.append("runtime config authoritative_sources must be an object")
		return
	var sources := raw as Dictionary
	var required := {
		"layout":"res://data/building_layout.json",
		"exterior_regions":"res://data/orison_v2/exterior/regions.json",
	}
	for source_id: String in required:
		var path_key := "%s_path" % source_id
		var hash_key := "%s_sha256" % source_id
		var path := str(sources.get(path_key, ""))
		var expected_hash := str(sources.get(hash_key, ""))
		var actual_hash := file_sha256(path)
		if path != str(required[source_id]):
			errors.append("%s authoritative source path differs" % source_id)
		if expected_hash.length() != 64 or actual_hash != expected_hash:
			errors.append("%s authoritative source hash differs in scratch" % source_id)


static func authoritative_source_receipt(config: Dictionary) -> Dictionary:
	var sources: Dictionary = config.get("authoritative_sources", {}) \
			if config.get("authoritative_sources", {}) is Dictionary else {}
	var rows := {}
	var complete := true
	for source_id: String in ["layout", "exterior_regions"]:
		var path := str(sources.get("%s_path" % source_id, ""))
		var expected := str(sources.get("%s_sha256" % source_id, ""))
		var actual := file_sha256(path)
		var exact := expected.length() == 64 and actual == expected
		complete = complete and exact
		rows[source_id] = {"path":path, "expected_sha256":expected,
				"actual_sha256":actual, "exact":exact}
	return {"status":"PASS" if complete else "FAIL", "sources":rows}


static func _input_result(config_path: String, config: Dictionary,
		partition_path: String, partition: Dictionary, lineage_path: String,
		lineage: Dictionary, equivalence_path: String, equivalence: Dictionary,
		cells: Array, residency_sets: Dictionary, semantic_index: Dictionary,
		errors: Array[String], blockers: Array[String]) -> Dictionary:
	return {
		"ok": errors.is_empty(),
		"errors": errors,
		"blockers": blockers,
		"config_path": config_path,
		"config": config,
		"config_sha256": file_sha256(config_path),
		"partition_path": partition_path,
		"partition": partition,
		"partition_sha256": file_sha256(partition_path),
		"lineage_path": lineage_path,
		"lineage": lineage,
		"lineage_sha256": file_sha256(lineage_path),
		"equivalence_path": equivalence_path,
		"equivalence": equivalence,
		"equivalence_sha256": file_sha256(equivalence_path),
		"cells": cells,
		"cells_by_id": index_by_id(cells),
		"residency_sets": residency_sets,
		"semantic_index": semantic_index,
	}


static func _validate_receipt_headers(partition: Dictionary,
		lineage: Dictionary, equivalence: Dictionary,
		errors: Array[String]) -> void:
	if str(partition.get("schema", "")) != PARTITION_SCHEMA:
		errors.append("partition schema must be %s" % PARTITION_SCHEMA)
	if str(lineage.get("schema", "")) != LINEAGE_SCHEMA:
		errors.append("lineage schema must be %s" % LINEAGE_SCHEMA)
	if str(equivalence.get("schema", "")) != EQUIVALENCE_SCHEMA:
		errors.append("equivalence schema must be %s" % EQUIVALENCE_SCHEMA)
	for pair: Array in [["partition", partition], ["lineage", lineage],
			["equivalence", equivalence]]:
		var status := str((pair[1] as Dictionary).get("status", ""))
		if status != "PASS":
			errors.append("%s receipt status must be exact PASS: %s" % [pair[0], status])
	for key: String in ["production_asset", "spatial_inference_used",
			"legacy_mixed_cell_present"]:
		if bool(partition.get(key, true)):
			errors.append("partition critical false field differs: %s" % key)
	for key: String in ["owner_before_material", "canonical_equivalence_passed",
			"lineage_complete", "protected_unchanged", "cell_hashes_bound"]:
		if not bool(partition.get(key, false)):
			errors.append("partition critical true field differs: %s" % key)
	for key: String in ["lineage_complete", "legacy_aliases_complete",
			"semantic_owners_unique", "owner_before_material"]:
		if not bool(lineage.get(key, false)):
			errors.append("lineage critical true field differs: %s" % key)
	if bool(lineage.get("spatial_inference_used", true)):
		errors.append("lineage reports spatial inference")
	for key: String in ["all_checks_passed", "unexplained_differences_empty"]:
		if not bool(equivalence.get(key, false)):
			errors.append("equivalence critical true field differs: %s" % key)
	if bool(equivalence.get("raw_descriptor_byte_identity_required", true)):
		errors.append("equivalence descriptor-byte boundary differs")
	var checks: Variant = equivalence.get("checks", {})
	if checks is not Dictionary or checks.is_empty():
		errors.append("equivalence checks dictionary is missing")
	else:
		for check: Variant in checks:
			if not bool(checks[check]):
				errors.append("equivalence check failed: %s" % str(check))
	if not (equivalence.get("unexplained_differences", []) is Array) \
			or not (equivalence.get("unexplained_differences", []) as Array).is_empty():
		errors.append("equivalence contains unexplained differences")
	var hosts: Variant = partition.get("persistent_hosts", [])
	var valid_host := false
	if hosts is Array:
		for raw: Variant in hosts:
			if raw is Dictionary and str(raw.get("id", "")) == "F01" \
					and bool(raw.get("geometry_free", false)):
				valid_host = true
	if not valid_host:
		errors.append("partition must declare geometry-free persistent F01 host")
	if str(partition.get("forbidden_cell_absent", "")) != "CELL_LEGACY_MIXED":
		errors.append("partition must receipt CELL_LEGACY_MIXED as absent")
	if int(partition.get("target_cell_count", -1)) != TARGET_CELL_IDS.size():
		errors.append("partition target_cell_count must be exactly 17")
	var unresolved_value: Variant = lineage.get("unresolved_lineage_records",
			lineage.get("unresolved_records", lineage.get("unresolved_count", 0)))
	var unresolved := 0
	if unresolved_value is Array:
		unresolved = (unresolved_value as Array).size()
	else:
		unresolved = int(unresolved_value)
	if unresolved != 0:
		errors.append("lineage receipt reports %d unresolved record(s)" % unresolved)


static func _validate_partition_transaction(config: Dictionary,
		partition_path: String, partition: Dictionary, lineage_path: String,
		lineage: Dictionary, equivalence_path: String,
		equivalence: Dictionary, errors: Array[String]) -> Dictionary:
	var declared := {
		"lineage":resolve_path(str(partition.get("lineage_manifest", "")),
				partition_path),
		"equivalence":resolve_path(str(partition.get("equivalence_receipt", "")),
				partition_path),
		"recomposition":resolve_path(str(partition.get(
				"recomposition_receipt", "")), partition_path),
		"export":resolve_path(str(partition.get("export_receipt", "")),
				partition_path),
		"transaction":resolve_path(str(partition.get("transaction_manifest", "")),
				partition_path),
	}
	if not _same_path(str(declared.lineage), lineage_path):
		errors.append("supplied lineage is not the partition-declared lineage")
	if not _same_path(str(declared.equivalence), equivalence_path):
		errors.append("supplied equivalence is not the partition-declared equivalence")
	var recomposition := load_json(str(declared.recomposition), errors,
			"partition-bound recomposition")
	var export_receipt := load_json(str(declared.export), errors,
			"partition-bound export receipt")
	var transaction := load_json(str(declared.transaction), errors,
			"partition-bound transaction")
	var exact_headers := [
		["recomposition", recomposition, RECOMPOSITION_SCHEMA],
		["export", export_receipt, EXPORT_SCHEMA],
		["transaction", transaction, TRANSACTION_SCHEMA],
	]
	for header: Array in exact_headers:
		var receipt: Dictionary = header[1]
		if str(receipt.get("schema", "")) != str(header[2]) \
				or str(receipt.get("status", "")) != "PASS":
			errors.append("%s receipt schema/status is not exact PASS contract" \
					% str(header[0]))
	for key: String in ["whole_node_only"]:
		if not bool(recomposition.get(key, false)):
			errors.append("recomposition critical true field differs: %s" % key)
	if bool(recomposition.get("spatial_primitive_splitting", true)) \
			or not (recomposition.get("failures", []) is Array) \
			or not (recomposition.get("failures", []) as Array).is_empty():
		errors.append("recomposition reports splitting/failures")
	if int(recomposition.get("source_node_count", -1)) \
			!= int(recomposition.get("recomposed_node_count", -2)) \
			or int(recomposition.get("source_primitive_count", -1)) \
			!= int(recomposition.get("recomposed_primitive_count", -2)):
		errors.append("recomposition exact-once counts differ")
	for key: String in ["protected_unchanged", "owner_before_material",
			"cell_hashes_bound"]:
		if not bool(export_receipt.get(key, false)):
			errors.append("export critical true field differs: %s" % key)
	if bool(export_receipt.get("production_mutation", true)) \
			or bool(export_receipt.get("spatial_inference_used", true)):
		errors.append("export reports production mutation or spatial inference")
	if not (export_receipt.get("unresolved_lineage_records", []) is Array) \
			or not (export_receipt.get("unresolved_lineage_records", []) as Array).is_empty():
		errors.append("export has unresolved lineage records")
	for key: String in ["generated_last", "all_artifacts_bound",
			"json_artifact_closure_verified"]:
		if not bool(transaction.get(key, false)):
			errors.append("transaction critical true field differs: %s" % key)

	var run_id := str(partition.get("run_id", ""))
	var disposable_root := absolute_file_path(str(partition.get(
			"disposable_root", ""))).simplify_path()
	var expected_root := absolute_file_path(partition_path).get_base_dir().simplify_path()
	if run_id.is_empty() or disposable_root != expected_root:
		errors.append("partition run/root transaction identity is invalid")
	for pair: Array in [["lineage", lineage], ["equivalence", equivalence],
			["recomposition", recomposition], ["export", export_receipt],
			["transaction", transaction]]:
		var receipt: Dictionary = pair[1]
		if str(receipt.get("run_id", "")) != run_id \
				or absolute_file_path(str(receipt.get(
						"disposable_root", ""))).simplify_path() != disposable_root:
			errors.append("%s receipt belongs to a different run/root" % str(pair[0]))

	var artifacts: Variant = transaction.get("artifacts", {})
	var artifact_paths := {
		str(partition.get("lineage_manifest", "")):str(declared.lineage),
		str(partition.get("equivalence_receipt", "")):str(declared.equivalence),
		str(partition.get("recomposition_receipt", "")):str(declared.recomposition),
		str(partition.get("export_receipt", "")):str(declared.export),
		"owner_first_partition_manifest.json":partition_path,
	}
	if artifacts is not Dictionary:
		errors.append("transaction artifacts map is missing")
	else:
		if (artifacts as Dictionary).size() != 7:
			errors.append("transaction JSON closure must bind exactly seven artifacts")
		for relative_path: Variant in artifacts:
			var rel_all := str(relative_path)
			var bound_all: Variant = (artifacts as Dictionary).get(rel_all, {})
			var actual_all := disposable_root.path_join(rel_all).simplify_path()
			if bound_all is not Dictionary \
					or str(bound_all.get("relative_path", "")) != rel_all \
					or str(bound_all.get("status", "")) != "PASS" \
					or str(bound_all.get("schema", "")).is_empty() \
					or str(bound_all.get("sha256", "")) != file_sha256(actual_all):
				errors.append("transaction JSON closure binding differs: %s" % rel_all)
		for relative_path: Variant in artifact_paths:
			var rel := str(relative_path)
			var bound: Variant = artifacts.get(rel, {})
			if bound is not Dictionary:
				errors.append("transaction does not bind artifact %s" % rel)
				continue
			var actual_path := str(artifact_paths[relative_path])
			if str(bound.get("relative_path", "")) != rel \
					or str(bound.get("status", "")) != "PASS" \
					or str(bound.get("sha256", "")) != file_sha256(actual_path):
				errors.append("transaction artifact binding differs: %s" % rel)

	var source: Dictionary = partition.get("source", {}) \
			if partition.get("source", {}) is Dictionary else {}
	var candidate_hashes: Dictionary = source.get("candidate_hashes", {}) \
			if source.get("candidate_hashes", {}) is Dictionary else {}
	if export_receipt.get("candidate_hashes", {}) != candidate_hashes:
		errors.append("partition/export candidate hashes differ")
	var transaction_candidate: Dictionary = transaction.get("candidate", {}) \
			if transaction.get("candidate", {}) is Dictionary else {}
	if str(transaction_candidate.get("descriptor_sha256", "")) \
			!= str(candidate_hashes.get("gltf", "")) \
			or str(transaction_candidate.get("binary_sha256", "")) \
			!= str(candidate_hashes.get("bin", "")) \
			or str(transaction_candidate.get("generated_lineage_sha256", "")) \
			!= str(candidate_hashes.get("generated_lineage", "")):
		errors.append("transaction candidate hashes differ from partition")
	var source_candidate_paths := {
		"descriptor_path":str(source.get("candidate_gltf", "")),
		"binary_path":str(source.get("candidate_bin", "")),
		"generated_lineage_path":str(source.get("generated_lineage", "")),
	}
	var source_candidate_hash_keys := {
		"descriptor_path":"gltf",
		"binary_path":"bin",
		"generated_lineage_path":"generated_lineage",
	}
	for path_key: String in source_candidate_paths:
		var candidate_path := absolute_file_path(str(source_candidate_paths[path_key])) \
				.simplify_path()
		var transaction_path := absolute_file_path(str(transaction_candidate.get(
				path_key, ""))).simplify_path()
		var hash_key := str(source_candidate_hash_keys[path_key])
		if candidate_path != transaction_path \
				or candidate_path.get_base_dir().get_base_dir() != disposable_root \
				or file_sha256(candidate_path) != str(candidate_hashes.get(hash_key, "")):
			errors.append("candidate transaction path/hash differs: %s" % path_key)
	if export_receipt.get("candidate_recomposition", {}) != recomposition:
		errors.append("export embeds a different recomposition receipt")

	var transaction_cells := index_by_id(transaction.get("cells", []))
	for raw: Variant in partition.get("cells", []):
		if raw is not Dictionary:
			continue
		var cell := raw as Dictionary
		var bound: Dictionary = transaction_cells.get(str(cell.get("id", "")), {})
		for key: String in ["gltf_path", "gltf_sha256", "bin_path", "bin_sha256"]:
			if str(cell.get(key, "")) != str(bound.get(key, "")):
				errors.append("transaction cell binding differs for %s/%s" % [
						cell.get("id", ""), key])
	return {
		"run_id":run_id,
		"disposable_root":disposable_root,
		"paths":declared,
		"hashes":{
			"recomposition":file_sha256(str(declared.recomposition)),
			"export":file_sha256(str(declared.export)),
			"transaction":file_sha256(str(declared.transaction)),
		},
		"transaction":transaction,
	}


static func _cell_descriptors(config: Dictionary, partition: Dictionary,
		partition_path: String, errors: Array[String],
		blockers: Array[String]) -> Array[Dictionary]:
	var resource_map: Variant = config.get("cell_resources", {})
	if resource_map is not Dictionary:
		errors.append("cell_resources must be an explicit dictionary")
		resource_map = {}
	var raw_cells: Variant = partition.get("cells", [])
	if raw_cells is not Array:
		errors.append("partition cells must be an array")
		return []
	var result: Array[Dictionary] = []
	var ids: Array[String] = []
	for raw: Variant in raw_cells:
		if raw is not Dictionary:
			errors.append("partition cell record is not an object")
			continue
		var cell := raw as Dictionary
		var cell_id := str(cell.get("id", ""))
		if cell_id.is_empty() or cell_id in ids:
			errors.append("partition cell ID is empty or duplicated: %s" % cell_id)
			continue
		ids.append(cell_id)
		var resource_path := str((resource_map as Dictionary).get(cell_id, ""))
		if not resource_path.begins_with("res://"):
			errors.append("%s cell_resources path must be res://" % cell_id)
		if not resource_path.to_lower().ends_with(".gltf"):
			errors.append("%s imported resource must be its bound disposable GLTF, not a detached TSCN" % cell_id)
		var gltf_path := resolve_path(str(cell.get("gltf_path", "")),
				partition_path)
		var bin_path := resolve_path(str(cell.get("bin_path", "")), partition_path)
		var expected_gltf_hash := str(cell.get("gltf_sha256", ""))
		var expected_bin_hash := str(cell.get("bin_sha256", ""))
		var manifest_gltf_hash := file_sha256(gltf_path)
		var manifest_bin_hash := file_sha256(bin_path)
		if expected_gltf_hash.length() != 64 \
				or expected_gltf_hash != manifest_gltf_hash:
			errors.append("%s manifest GLTF hash does not bind its written cell" % cell_id)
		if expected_bin_hash.length() != 64 \
				or expected_bin_hash != manifest_bin_hash:
			errors.append("%s manifest BIN hash does not bind its written cell" % cell_id)
		var imported_gltf_hash := file_sha256(resource_path)
		var imported_bin_path := resource_path.get_basename() + ".bin"
		var imported_bin_hash := file_sha256(imported_bin_path)
		if imported_gltf_hash != expected_gltf_hash \
				or imported_bin_hash != expected_bin_hash:
			errors.append("%s imported res:// cell is stale, swapped, or detached from its manifest GLTF/BIN" % cell_id)
		var import_ready := not resource_path.is_empty() \
				and ResourceLoader.exists(resource_path, "PackedScene")
		if not import_ready:
			blockers.append("%s has no imported PackedScene at %s; collision/nav proof refuses raw GLTF" % [cell_id, resource_path])
		if not file_exists(gltf_path):
			errors.append("%s disposable GLTF is missing: %s" % [cell_id, gltf_path])
		result.append({
			"id": cell_id,
			"slug": str(cell.get("slug", cell_id.to_lower())),
			"resource_path": resource_path,
			"gltf_path": gltf_path,
			"bin_path": bin_path,
			"gltf_sha256":expected_gltf_hash,
			"bin_sha256":expected_bin_hash,
			"imported_gltf_sha256":imported_gltf_hash,
			"imported_bin_sha256":imported_bin_hash,
			"imported_bin_path":imported_bin_path,
			"import_binding_exact":imported_gltf_hash == expected_gltf_hash \
					and imported_bin_hash == expected_bin_hash,
			"import_ready": import_ready,
			"manifest_record": cell.duplicate(true),
		})
	ids.sort()
	var expected := string_array(TARGET_CELL_IDS)
	expected.sort()
	if ids != expected:
		errors.append("partition cell IDs do not equal the canonical 17 target IDs")
	for configured: Variant in (resource_map as Dictionary):
		if str(configured) not in TARGET_CELL_IDS:
			errors.append("cell_resources declares unknown cell %s" % str(configured))
	return result


static func _residency_sets(config: Dictionary,
		errors: Array[String]) -> Dictionary:
	var result := {}
	var raw_sets: Variant = config.get("residency_sets", [])
	if raw_sets is not Array:
		errors.append("residency_sets must be an array")
		return result
	for raw: Variant in raw_sets:
		if raw is not Dictionary:
			continue
		var set_id := str(raw.get("id", ""))
		var members := string_array(raw.get("cell_ids", []))
		if set_id.is_empty() or result.has(set_id):
			errors.append("residency set ID is empty or duplicated: %s" % set_id)
			continue
		result[set_id] = members
	for raw_id: Variant in REQUIRED_RESIDENCY:
		var set_id := str(raw_id)
		if not result.has(set_id):
			errors.append("required residency set is missing: %s" % set_id)
			continue
		var actual: Array[String] = string_array(result[set_id])
		var required: Array[String] = string_array(REQUIRED_RESIDENCY[set_id])
		actual.sort()
		required.sort()
		if actual != required:
			errors.append("residency set %s has noncanonical membership" % set_id)
	for raw_id: Variant in result:
		if str(raw_id) not in REQUIRED_RESIDENCY:
			errors.append("undeclared residency set %s" % str(raw_id))
	return result


static func _lineage_rows(lineage: Dictionary) -> Array:
	for key: String in ["contributions", "records", "lineage", "rows",
			"source_ranges"]:
		var value: Variant = lineage.get(key, [])
		if value is Array and not value.is_empty():
			return value
	return []


static func _validate_lineage_and_semantics(config: Dictionary,
		lineage: Dictionary, rows: Array, errors: Array[String]) -> Dictionary:
	if rows.is_empty():
		errors.append("lineage receipt has no deterministic source-range rows")
	for index in rows.size():
		var raw: Variant = rows[index]
		if raw is not Dictionary:
			errors.append("lineage row %d is not an object" % index)
			continue
		var row := raw as Dictionary
		for key: String in ["source_id", "owner_cell", "emission_kind",
				"material", "collision_class", "source_range", "output"]:
			if not row.has(key):
				errors.append("lineage row %d lacks %s" % [index, key])
		var owner := str(row.get("owner_cell", ""))
		if owner not in TARGET_CELL_IDS:
			errors.append("lineage row %d names undeclared owner %s" % [index, owner])
		var output: Variant = row.get("output", {})
		if output is not Dictionary or str(output.get("cell_id", "")) != owner:
			errors.append("lineage row %d output cell differs from source owner" % index)

	# Marker semantics are source records and are intentionally separate from
	# mesh legacy aliases. Never manufacture semantic ownership from an emitted
	# mesh name or compatibility string.
	var identities := {}
	var semantic_rows: Variant = lineage.get("semantic_owners", [])
	if semantic_rows is not Array or semantic_rows.is_empty():
		errors.append("lineage receipt has no authoritative semantic_owners array")
		semantic_rows = []
	for index in semantic_rows.size():
		var raw: Variant = semantic_rows[index]
		if raw is not Dictionary:
			errors.append("semantic owner row %d is not an object" % index)
			continue
		var row := raw as Dictionary
		var identity := str(row.get("identity", ""))
		var source_id := str(row.get("source_id", ""))
		var owner := str(row.get("owner_cell", ""))
		var semantic_kind := str(row.get("semantic_kind", ""))
		if identity.is_empty() or source_id.is_empty() or semantic_kind.is_empty():
			errors.append("semantic owner row %d lacks identity/source_id/kind" % index)
			continue
		if owner not in TARGET_CELL_IDS:
			errors.append("semantic owner %s names undeclared cell %s" % [identity, owner])
		if identities.has(identity):
			errors.append("semantic identity is not unique: %s" % identity)
			continue
		identities[identity] = {
			"identity": identity,
			"source_id": source_id,
			"source_locator": row.get("source_locator", {}),
			"owner_cells": [owner],
			"unique_owner": true,
			"semantic_kind": semantic_kind,
			"compatibility_aliases": compatibility_identities(row.get(
					"compatibility_aliases", [])),
		}

	var expected := {}
	var raw_expectations: Variant = config.get("semantic_expectations", [])
	if raw_expectations is not Array:
		errors.append("semantic_expectations must be an array")
		raw_expectations = []
	for raw: Variant in raw_expectations:
		if raw is not Dictionary:
			continue
		var identity := str(raw.get("identity", ""))
		var owner := str(raw.get("owner_cell", ""))
		if identity.is_empty() or expected.has(identity):
			errors.append("semantic expectation is empty or duplicated: %s" % identity)
			continue
		if owner not in TARGET_CELL_IDS:
			errors.append("semantic expectation %s has invalid owner %s" % [identity, owner])
		expected[identity] = owner
	for identity: String in SPECIAL_SEMANTICS:
		if not expected.has(identity):
			errors.append("mandatory semantic expectation missing: %s" % identity)
	for raw_identity: Variant in identities:
		var identity := str(raw_identity)
		var entry: Dictionary = identities[identity]
		var owners: Array[String] = string_array(entry.get("owner_cells", []))
		if not expected.has(identity):
			errors.append("source semantic %s lacks an explicit expectation" % identity)
		elif owners.size() == 1 and owners[0] != str(expected[identity]):
			errors.append("semantic identity %s owner is %s, expected %s" % [identity, owners[0], expected[identity]])
	for raw_identity: Variant in expected:
		if not identities.has(raw_identity):
			errors.append("expected semantic identity absent from lineage: %s" % str(raw_identity))
	var site_ids: Array[String] = []
	for raw_identity: Variant in identities:
		if str(raw_identity).begins_with("SITE_SHOP_"):
			site_ids.append(str(raw_identity))
	if site_ids.is_empty():
		errors.append("lineage contains no SITE_SHOP_* identities")
	for prefix: String in SITE_SHOP_SUBPREFIXES:
		var found := false
		for identity: String in site_ids:
			if identity.begins_with(prefix):
				found = true
				break
		if not found:
			errors.append("SITE_SHOP family lacks required subprefix %s" % prefix)
	if not expected.has("THRESHOLD_SHOP_BODEGA_FRONT"):
		errors.append("v2 bodega threshold semantic expectation is missing")
	else:
		# They legitimately share the bodega cell, but not an identity, source or
		# semantic kind. Sharing a cell is never treated as alias evidence.
		var door: Dictionary = identities.get("F01_BODEGA_DOOR", {})
		var threshold: Dictionary = identities.get("THRESHOLD_SHOP_BODEGA_FRONT", {})
		if door.is_empty() or threshold.is_empty():
			errors.append("v1 bodega door or v2 threshold source semantic is absent")
		elif str(door.get("source_id", "")) == str(threshold.get("source_id", "")) \
				or str(door.get("semantic_kind", "")) == str(threshold.get(
						"semantic_kind", "")):
			errors.append("v1 bodega door and v2 threshold are semantically conflated")
	return identities


static func _source_overlap(first: Variant, second: Variant) -> bool:
	if first is not Array or second is not Array:
		return false
	for value: Variant in first:
		if value in second:
			return true
	return false


static func _validate_seams_and_capture(config: Dictionary,
		semantic_index: Dictionary, errors: Array[String],
		_blockers: Array[String]) -> void:
	var seam_ids: Array[String] = []
	var passage_coverage: Array[String] = []
	var passage_traversal_coverage: Array[String] = []
	var passage_accessible: Array[String] = []
	var shoe_traversal_found := false
	var shoe_probe_found := false
	var news_locked_service_found := false
	var seam_cells := {}
	var seams: Variant = config.get("seams", [])
	if seams is not Array:
		errors.append("seams must be an array")
		seams = []
	for raw: Variant in seams:
		if raw is not Dictionary:
			errors.append("seam record is not an object")
			continue
		var seam := raw as Dictionary
		var seam_id := str(seam.get("id", ""))
		if seam_id.is_empty() or seam_id in seam_ids:
			errors.append("seam ID is empty or duplicated: %s" % seam_id)
			continue
		seam_ids.append(seam_id)
		var cell_ids := string_array(seam.get("cell_ids", []))
		seam_cells[seam_id] = cell_ids.duplicate()
		if cell_ids.size() < 2:
			errors.append("seam %s must mount at least two explicit cells" % seam_id)
		for cell_id: String in cell_ids:
			if cell_id not in TARGET_CELL_IDS:
				errors.append("seam %s names undeclared cell %s" % [seam_id, cell_id])
		var seam_expected := string_array(seam.get(
				"expected_collision_owner_cells", []))
		if seam_expected.is_empty():
			errors.append("seam %s has no positive collision-owner expectation" % seam_id)
		for owner: String in seam_expected:
			if owner not in cell_ids:
				errors.append("seam %s expects collision from nonresident %s" % [
						seam_id, owner])
		var door_ids: Array[String] = string_array(seam.get("door_identities", []))
		for identity: String in door_ids:
			if not semantic_index.has(identity):
				errors.append("seam %s door %s lacks source semantic ownership" % [
						seam_id, identity])
		var traversals: Variant = seam.get("traversals", [])
		if traversals is not Array or traversals.is_empty():
			errors.append("seam %s has no explicit traversal" % seam_id)
			continue
		for traversal_raw: Variant in traversals:
			if traversal_raw is not Dictionary:
				errors.append("seam %s traversal is not an object" % seam_id)
				continue
			var traversal := traversal_raw as Dictionary
			var traversal_id := str(traversal.get("id", ""))
			var door_identity := str(traversal.get("door_identity", ""))
			var door_action := str(traversal.get("door_action", "none"))
			if not door_identity.is_empty() and door_identity not in door_ids:
				errors.append("seam %s traversal door is not in door_identities" % seam_id)
			var expectation := str(traversal.get("expectation", "crossable"))
			if expectation not in ["crossable", "locked_non_crossable"]:
				errors.append("seam %s traversal has invalid accessibility expectation" % seam_id)
			if door_action not in ["none", "interact_open",
					"interact_locked_refusal"]:
				errors.append("seam %s traversal has invalid DoorProp action" % seam_id)
			if not door_identity.is_empty() and expectation == "crossable" \
					and door_action != "interact_open":
				errors.append("seam %s crossable door must use its public open contract" % seam_id)
			if expectation == "locked_non_crossable" \
					and door_action != "interact_locked_refusal":
				errors.append("seam %s locked door must exercise public refusal" % seam_id)
			var start := vector3(traversal.get("start", []))
			var forward := vector3_list(traversal.get("forward_waypoints", []))
			var back := vector3_list(traversal.get("return_waypoints", []))
			var plane: Variant = traversal.get("plane", {})
			if not start.is_finite() or forward.is_empty() or back.is_empty() \
					or plane is not Dictionary:
				errors.append("seam %s traversal lacks finite bidirectional facts" % seam_id)
			for point: Vector3 in forward + back:
				if not point.is_finite():
					errors.append("seam %s traversal has non-finite waypoint" % seam_id)
			var plane_point := vector3(plane.get("point", [])) \
					if plane is Dictionary else Vector3.INF
			var plane_normal := vector3(plane.get("normal", [])) \
					if plane is Dictionary else Vector3.ZERO
			if not plane_point.is_finite() or not plane_normal.is_finite() \
					or plane_normal.length_squared() < 0.99:
				errors.append("seam %s traversal plane is invalid" % seam_id)
			var opening: Variant = traversal.get("opening_bounds", {})
			if opening is not Dictionary:
				errors.append("seam %s traversal lacks authored opening bounds" % seam_id)
			else:
				var centre := vector3(opening.get("center", []))
				var right := vector3(opening.get("right_axis", []))
				var half_width := float(opening.get("half_width_m", 0.0))
				var bottom := float(opening.get("bottom_y_m", NAN))
				var top := float(opening.get("top_y_m", NAN))
				if not centre.is_finite() or not right.is_finite() \
						or right.length_squared() < 0.99 or half_width <= 0.33 \
						or not is_finite(bottom) or not is_finite(top) \
						or top - bottom <= 1.524:
					errors.append("seam %s authored opening cannot admit production capsule" % seam_id)
				if absf(right.normalized().dot(plane_normal.normalized())) > 0.02:
					errors.append("seam %s opening right axis is not in its plane" % seam_id)
			var grounded_floor := float(traversal.get(
					"minimum_grounded_fraction", -1.0))
			if grounded_floor < 0.90 or grounded_floor > 1.0:
				errors.append("seam %s cannot weaken grounded proof below 0.90" % seam_id)
			var expected_owners := string_array(traversal.get(
					"expected_collision_owner_cells", []))
			if expected_owners.is_empty():
				errors.append("seam %s traversal %s lacks positive owner observations" % [
						seam_id, traversal_id])
			for owner: String in expected_owners:
				if owner not in cell_ids or owner not in seam_expected:
					errors.append("seam %s traversal expects unconstrained owner %s" % [
							seam_id, owner])
			if seam_id == "SEAM_PASSAGE_SHOP_AISLES":
				var shop_cell := str(traversal.get("shop_cell_id", ""))
				if shop_cell not in PASSAGE_SHOP_CELL_IDS \
						or shop_cell in passage_traversal_coverage:
					errors.append("Passage traversal shop cell is invalid/duplicated: %s" % shop_cell)
				else:
					passage_traversal_coverage.append(shop_cell)
				if "CELL_PASSAGE" not in expected_owners or shop_cell not in expected_owners:
					errors.append("Passage traversal must observe Passage and its shop owner")
				if expectation == "crossable":
					passage_accessible.append(shop_cell)
				if shop_cell == "CELL_SHOP_NEWS_CIGARS":
					news_locked_service_found = expectation == "locked_non_crossable" \
							and door_identity == "SITE_SHOP_DOOR_NEWS_CIGARS"
				elif expectation != "crossable":
					errors.append("only NEWS_CIGARS may use the locked service-frontage exception")
				if shop_cell == "CELL_SHOP_SHOE_REBUILDING":
					shoe_traversal_found = expectation == "crossable" \
							and door_identity == "SITE_SHOP_DOOR_SHOE_REBUILDING" \
							and traversal_id == "PASSAGE_SHOE_REBUILDING_BIDIRECTIONAL"
		for probe_raw: Variant in seam.get("collision_probes", []):
			if probe_raw is not Dictionary:
				continue
			var probe := probe_raw as Dictionary
			if str(probe.get("id", "")) == "M11C0_PASSAGE_AISLE_WEST_055":
				shoe_probe_found = seam_id == "SEAM_PASSAGE_SHOP_AISLES" \
						and vector3(probe.get("from", [])).is_equal_approx(
								Vector3(11.02, 2.0, 45.0)) \
						and vector3(probe.get("to", [])).is_equal_approx(
								Vector3(11.02, -1.0, 45.0)) \
						and str(probe.get("expected_owner_cell", "")) == "CELL_PASSAGE" \
						and str(probe.get("forbidden_owner_cell", "")) \
								== "CELL_SHOP_SHOE_REBUILDING" \
						and is_equal_approx(float(probe.get(
								"legacy_hit_elevation_m", -1.0)), 0.55)
		if seam_id == "SEAM_PASSAGE_SHOP_AISLES":
			passage_coverage = string_array(seam.get("coverage_cells", []))
			var door_owners: Array[String] = []
			for identity: String in door_ids:
				var semantic: Dictionary = semantic_index.get(identity, {})
				for owner: String in string_array(semantic.get("owner_cells", [])):
					if owner in PASSAGE_SHOP_CELL_IDS and owner not in door_owners:
						door_owners.append(owner)
			door_owners.sort()
			var required_door_owners := string_array(PASSAGE_SHOP_CELL_IDS)
			required_door_owners.sort()
			if door_owners != required_door_owners:
				errors.append("Passage seam must mount all eleven source-owned doors")
	for required: String in REQUIRED_SEAM_IDS:
		if required not in seam_ids:
			errors.append("dangerous seam is missing: %s" % required)
	var required_shops := string_array(PASSAGE_SHOP_CELL_IDS)
	for coverage: Array[String] in [passage_coverage, passage_traversal_coverage]:
		coverage.sort()
	required_shops.sort()
	if passage_coverage != required_shops or passage_traversal_coverage != required_shops:
		errors.append("Passage/shop seam must execute exactly all eleven shop frontages")
	var expected_accessible: Array[String] = []
	expected_accessible.assign(required_shops)
	expected_accessible.erase("CELL_SHOP_NEWS_CIGARS")
	passage_accessible.sort()
	expected_accessible.sort()
	if passage_accessible != expected_accessible or not news_locked_service_found:
		errors.append("Passage proof must be ten bidirectional doors plus NEWS locked service frontage")
	if not shoe_traversal_found or not shoe_probe_found:
		errors.append("shoe-shop proof must cross its real door and resolve the historical 0.55 m-elevation owner intercept")
	var nav_seams: Array[String] = []
	var passage_nav_shops: Array[String] = []
	var news_service_nav := false
	var nav_queries: Variant = config.get("resident_nav_queries", [])
	if nav_queries is not Array:
		errors.append("resident_nav_queries must be an array")
		nav_queries = []
	for raw: Variant in nav_queries:
		if raw is not Dictionary:
			errors.append("ResidentNav query is not an object")
			continue
		var query := raw as Dictionary
		var seam_id := str(query.get("seam_id", ""))
		if seam_id in REQUIRED_SEAM_IDS and seam_id not in nav_seams:
			nav_seams.append(seam_id)
		if not bool(query.get("expected_reachable", false)):
			errors.append("ResidentNav query %s must require a reachable route" % str(
					query.get("id", "")))
		var tolerance := float(query.get("terminal_tolerance_m", 0.0))
		if tolerance <= 0.0 or tolerance > 0.35:
			errors.append("ResidentNav terminal tolerance must be (0, 0.35]")
		if not vector3(query.get("from", [])).is_finite() \
				or not vector3(query.get("to", [])).is_finite():
			errors.append("ResidentNav query has non-finite endpoints")
		for cell_id: String in string_array(query.get("cell_ids", [])):
			if cell_id not in TARGET_CELL_IDS:
				errors.append("ResidentNav query names undeclared cell %s" % cell_id)
		if seam_id == "SEAM_PASSAGE_SHOP_AISLES":
			var shop_cell := str(query.get("shop_cell_id", ""))
			if shop_cell in PASSAGE_SHOP_CELL_IDS \
					and shop_cell not in passage_nav_shops:
				passage_nav_shops.append(shop_cell)
			else:
				errors.append("Passage ResidentNav query shop is invalid/duplicated: %s" % shop_cell)
			if shop_cell == "CELL_SHOP_NEWS_CIGARS":
				news_service_nav = str(query.get("passage_place", "")) \
						== "news_cigars"
	for required: String in REQUIRED_SEAM_IDS:
		if required not in nav_seams:
			errors.append("dangerous seam lacks an expected-reachable ResidentNav query: %s" % required)
	passage_nav_shops.sort()
	if passage_nav_shops != required_shops or not news_service_nav:
		errors.append("ResidentNav must cover all eleven Passage frontages and NEWS customer-side service anchor")
	var captured_seams: Array[String] = []
	var views: Variant = config.get("capture_views", [])
	if views is Array:
		for raw: Variant in views:
			if raw is Dictionary:
				var seam_id := str(raw.get("seam_id", ""))
				if seam_id in captured_seams:
					errors.append("dangerous seam has more than one capture view: %s" % seam_id)
				if not seam_cells.has(seam_id):
					errors.append("capture view names unknown seam: %s" % seam_id)
				elif string_array(raw.get("cell_ids", [])) != seam_cells[seam_id]:
					errors.append("capture view cell_ids differ from seam residency: %s" % seam_id)
				if vector3(raw.get("eye", [])).is_finite() \
						and vector3(raw.get("target", [])).is_finite():
					captured_seams.append(seam_id)
	for required: String in REQUIRED_SEAM_IDS:
		if required not in captured_seams:
			errors.append("dangerous seam lacks authored capture view: %s" % required)
	if captured_seams.size() != REQUIRED_SEAM_IDS.size():
		errors.append("capture packet must declare exactly one view per dangerous seam")


static func _validate_protected_boundary(config: Dictionary,
		partition: Dictionary, cells: Array[Dictionary],
		errors: Array[String]) -> void:
	for cell: Dictionary in cells:
		for key: String in ["resource_path", "gltf_path", "bin_path"]:
			var value := str(cell.get(key, "")).replace("\\", "/").to_lower()
			if value.ends_with("/assets/building/floor_01.gltf") \
					or value.ends_with("/assets/building/floor_01.bin"):
				errors.append("disposable cell path targets protected floor_01 asset: %s" % value)
	for protected: String in PROTECTED_RESOURCE_PATHS:
		if str(config.get("output_path", "")) == protected:
			errors.append("runtime config output_path targets protected resource")
	var source: Variant = partition.get("source", {})
	var protected_hashes: Variant = source.get("protected_hashes", {}) \
			if source is Dictionary else {}
	var expected: Variant = config.get("protected_source", {})
	if protected_hashes is not Dictionary or expected is not Dictionary:
		errors.append("partition/config must bind protected floor_01 hashes")
		return
	var required_paths := {
		"gltf":"res://assets/building/floor_01.gltf",
		"bin":"res://assets/building/floor_01.bin",
	}
	for kind: String in ["gltf", "bin"]:
		var observed := str((protected_hashes as Dictionary).get(kind, ""))
		var pinned := str((expected as Dictionary).get("%s_sha256" % kind, ""))
		var actual_path := str((expected as Dictionary).get("%s_path" % kind, ""))
		var actual_hash := file_sha256(actual_path)
		if actual_path != str(required_paths[kind]):
			errors.append("protected %s path must be the actual project floor_01 asset" % kind)
		if observed.length() != 64 or pinned.length() != 64 \
				or observed != pinned or actual_hash != pinned:
			errors.append("protected %s hash is missing or differs from config pin" % kind)


static func protected_hash_receipt(config: Dictionary) -> Dictionary:
	var expected: Dictionary = config.get("protected_source", {}) \
			if config.get("protected_source", {}) is Dictionary else {}
	var result := {}
	for kind: String in ["gltf", "bin"]:
		var path := str(expected.get("%s_path" % kind, ""))
		result[kind] = {
			"path":path,
			"expected_sha256":str(expected.get("%s_sha256" % kind, "")),
			"actual_sha256":file_sha256(path),
		}
	return result


static func instantiate_cell(descriptor: Dictionary,
		allow_raw_diagnostic := true) -> Dictionary:
	var resource_path := str(descriptor.get("resource_path", ""))
	var started := Time.get_ticks_usec()
	if not resource_path.is_empty() \
			and ResourceLoader.exists(resource_path, "PackedScene"):
		var packed := ResourceLoader.load(resource_path, "PackedScene",
				ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
		var load_ms := elapsed_ms(started)
		if packed == null:
			return {"ok":false, "error":"imported PackedScene load failed",
					"load_ms":load_ms, "instantiate_ms":0.0}
		started = Time.get_ticks_usec()
		var instance := packed.instantiate()
		var instantiate_ms := elapsed_ms(started)
		packed = null
		return {"ok":instance != null, "node":instance,
				"mode":"godot_imported_resource", "collision_contract_proven":true,
				"load_ms":load_ms, "instantiate_ms":instantiate_ms}
	if not allow_raw_diagnostic:
		return {"ok":false,
				"error":"imported res:// PackedScene required for this proof",
				"mode":"refused_raw_gltf", "collision_contract_proven":false,
				"load_ms":elapsed_ms(started), "instantiate_ms":0.0}
	var gltf_path := absolute_file_path(str(descriptor.get("gltf_path", "")))
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_file(gltf_path, state)
	var load_ms := elapsed_ms(started)
	if error != OK:
		return {"ok":false, "error":"GLTFDocument append failed: %d" % error,
				"mode":"raw_gltf_diagnostic", "collision_contract_proven":false,
				"load_ms":load_ms, "instantiate_ms":0.0}
	started = Time.get_ticks_usec()
	var instance := document.generate_scene(state)
	return {"ok":instance != null, "node":instance,
			"mode":"raw_gltf_diagnostic", "collision_contract_proven":false,
			"load_ms":load_ms, "instantiate_ms":elapsed_ms(started)}


static func tree_metrics(root: Node) -> Dictionary:
	var data := {
		"nodes": 0,
		"mesh_instances": 0,
		"mesh_surfaces": 0,
		"triangles": 0,
		"vertices": 0,
		"collision_objects": 0,
		"collision_shapes": 0,
		"lights": 0,
		"aabb_valid": false,
		"aabb_min": Vector3.ZERO,
		"aabb_max": Vector3.ZERO,
	}
	_collect_tree_metrics(root, data)
	var result := data.duplicate()
	result["aabb_min"] = vector3_array(data.aabb_min) if bool(data.aabb_valid) else []
	result["aabb_max"] = vector3_array(data.aabb_max) if bool(data.aabb_valid) else []
	return result


static func _collect_tree_metrics(node: Node, data: Dictionary) -> void:
	data.nodes = int(data.nodes) + 1
	if node is CollisionObject3D:
		data.collision_objects = int(data.collision_objects) + 1
	if node is CollisionShape3D:
		data.collision_shapes = int(data.collision_shapes) + 1
	if node is Light3D:
		data.lights = int(data.lights) + 1
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		data.mesh_instances = int(data.mesh_instances) + 1
		if mesh_instance.mesh != null:
			var mesh := mesh_instance.mesh
			data.mesh_surfaces = int(data.mesh_surfaces) \
					+ mesh.get_surface_count()
			for surface in mesh.get_surface_count():
				var arrays := mesh.surface_get_arrays(surface)
				if arrays.is_empty():
					continue
				var vertices: Variant = arrays[Mesh.ARRAY_VERTEX]
				var indices: Variant = arrays[Mesh.ARRAY_INDEX]
				var vertex_count: int = int(vertices.size()) \
						if vertices != null else 0
				var element_count: int = int(indices.size()) \
						if indices != null else vertex_count
				data.vertices = int(data.vertices) + vertex_count
				# Godot 4.7 exposes surface_get_primitive_type on ArrayMesh,
				# while built-in PrimitiveMesh subclasses (QuadMesh, BoxMesh,
				# CylinderMesh) are triangle surfaces without that public call.
				var triangle_surface := mesh is PrimitiveMesh
				if mesh.has_method("surface_get_primitive_type"):
					triangle_surface = int(mesh.call(
							"surface_get_primitive_type", surface)) \
							== Mesh.PRIMITIVE_TRIANGLES
				if triangle_surface:
					data.triangles = int(data.triangles) + element_count / 3
			_expand_bounds(mesh_instance, data)
	for child: Node in node.get_children():
		_collect_tree_metrics(child, data)


static func _expand_bounds(mesh_instance: MeshInstance3D,
		data: Dictionary) -> void:
	var local := mesh_instance.get_aabb()
	for corner_index in 8:
		var local_point := local.position + Vector3(
				local.size.x if (corner_index & 1) else 0.0,
				local.size.y if (corner_index & 2) else 0.0,
				local.size.z if (corner_index & 4) else 0.0)
		var point := mesh_instance.global_transform * local_point
		if not bool(data.aabb_valid):
			data.aabb_valid = true
			data.aabb_min = point
			data.aabb_max = point
		else:
			data.aabb_min = (data.aabb_min as Vector3).min(point)
			data.aabb_max = (data.aabb_max as Vector3).max(point)


static func object_counts() -> Dictionary:
	return {
		"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphan_nodes": int(Performance.get_monitor(
				Performance.OBJECT_ORPHAN_NODE_COUNT)),
	}


static func object_delta(after: Dictionary, before: Dictionary) -> Dictionary:
	var result := {}
	for key: String in ["objects", "resources", "nodes", "orphan_nodes"]:
		result[key] = int(after.get(key, 0)) - int(before.get(key, 0))
	return result


static func performance_snapshot(viewport: Viewport = null) -> Dictionary:
	var display := DisplayServer.get_name()
	var vram_bytes := int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))
	var gpu_ms := 0.0
	if viewport != null:
		gpu_ms = RenderingServer.viewport_get_measured_render_time_gpu(
				viewport.get_viewport_rid())
	var gpu_trustworthy := gpu_ms > 0.0 and display != "headless"
	var vram_trustworthy := vram_bytes > 0 and display != "headless"
	return {
		"process_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"physics_process_ms": Performance.get_monitor(
				Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		"draw_calls": RenderingServer.get_rendering_info(
				RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		"visible_primitives": RenderingServer.get_rendering_info(
				RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
		"render_objects": RenderingServer.get_rendering_info(
				RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		"gpu_ms": gpu_ms if gpu_trustworthy else null,
		"gpu_timing_trustworthy": gpu_trustworthy,
		"gpu_unavailable_reason":"headless or renderer returned no measured time"
				if not gpu_trustworthy else "",
		"vram_bytes": vram_bytes if vram_trustworthy else null,
		"vram_trustworthy": vram_trustworthy,
		"vram_unavailable_reason":"headless or backend did not expose video memory"
				if not vram_trustworthy else "",
		"display_server": display,
		"renderer": RenderingServer.get_current_rendering_method(),
	}


static func disk_metrics(inputs: Dictionary) -> Dictionary:
	var cell_gltf := 0
	var cell_bin := 0
	var cells: Array = inputs.get("cells", [])
	for cell_raw: Variant in cells:
		if cell_raw is not Dictionary:
			continue
		var cell := cell_raw as Dictionary
		cell_gltf += file_size(str(cell.get("gltf_path", "")))
		cell_bin += file_size(str(cell.get("bin_path", "")))
	var config: Dictionary = inputs.get("config", {})
	var protected: Dictionary = config.get("protected_source", {}) \
			if config.get("protected_source", {}) is Dictionary else {}
	var protected_gltf_path := str(protected.get("gltf_path", ""))
	var protected_bin_path := str(protected.get("bin_path", ""))
	var source_gltf := file_size(protected_gltf_path)
	var source_bin := file_size(protected_bin_path)
	var protected_hashes_exact := source_gltf > 0 and source_bin > 0 \
			and file_sha256(protected_gltf_path) == str(protected.get(
					"gltf_sha256", "")) \
			and file_sha256(protected_bin_path) == str(protected.get(
					"bin_sha256", ""))
	var complete := cells.size() == TARGET_CELL_IDS.size() and cell_gltf > 0 \
			and cell_bin > 0 and protected_hashes_exact
	return {
		"status":"PASS" if complete else "FAIL",
		"target_cell_count":cells.size(),
		"cell_gltf_bytes": cell_gltf,
		"cell_bin_bytes": cell_bin,
		"cell_total_bytes": cell_gltf + cell_bin,
		"protected_gltf_bytes": source_gltf,
		"protected_bin_bytes": source_bin,
		"protected_total_bytes": source_gltf + source_bin,
		"descriptor_overhead_bytes": cell_gltf - source_gltf,
		"bin_overhead_bytes": cell_bin - source_bin,
		"total_overhead_bytes": cell_gltf + cell_bin - source_gltf - source_bin,
		"protected_gltf_path":protected_gltf_path,
		"protected_bin_path":protected_bin_path,
		"protected_hashes_exact":protected_hashes_exact,
	}


static func index_by_id(rows: Array) -> Dictionary:
	var result := {}
	for raw: Variant in rows:
		if raw is Dictionary:
			result[str(raw.get("id", ""))] = raw
	return result


static func compatibility_identities(raw: Variant) -> Array[String]:
	var result: Array[String] = []
	if raw is String and not raw.strip_edges().is_empty():
		result.append(raw.strip_edges())
	elif raw is Array:
		for item: Variant in raw:
			var identity := str(item).strip_edges()
			if not identity.is_empty() and identity not in result:
				result.append(identity)
	return result


static func vector3(raw: Variant) -> Vector3:
	if raw is Array and raw.size() == 3:
		return Vector3(float(raw[0]), float(raw[1]), float(raw[2]))
	return Vector3(NAN, NAN, NAN)


static func vector3_array(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]


static func vector3_list(raw: Variant) -> Array[Vector3]:
	var result: Array[Vector3] = []
	if raw is Array:
		for value: Variant in raw:
			result.append(vector3(value))
	return result


static func string_array(raw: Variant) -> Array[String]:
	var result: Array[String] = []
	if raw is Array:
		for value: Variant in raw:
			result.append(str(value))
	return result


static func f01_layout(layout: Dictionary) -> Dictionary:
	var scoped := layout.duplicate(true)
	var f01_floors: Array = []
	for raw: Variant in layout.get("floors", []):
		if raw is Dictionary and str(raw.get("id", "")) == "F01":
			f01_floors.append((raw as Dictionary).duplicate(true))
	if f01_floors.size() != 1:
		return {}
	scoped["floors"] = f01_floors
	return scoped


static func load_json(path: String, errors: Array[String], label: String) -> Dictionary:
	if path.is_empty() or not file_exists(path):
		errors.append("%s is missing: %s" % [label, path])
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is not Dictionary:
		errors.append("%s is not a JSON object: %s" % [label, path])
		return {}
	return parsed as Dictionary


static func resolve_path(raw: String, anchor: String) -> String:
	var path := raw.strip_edges().replace("\\", "/")
	if path.is_empty() or path.begins_with("res://") \
			or path.begins_with("user://") or path.is_absolute_path():
		return path
	var absolute_anchor := absolute_file_path(anchor)
	return absolute_anchor.get_base_dir().path_join(path).simplify_path()


static func _same_path(first: String, second: String) -> bool:
	return absolute_file_path(first).replace("\\", "/").simplify_path().to_lower() \
			== absolute_file_path(second).replace("\\", "/").simplify_path().to_lower()


static func absolute_file_path(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://"):
		return ProjectSettings.globalize_path(path)
	return path


static func file_exists(path: String) -> bool:
	return not path.is_empty() and FileAccess.file_exists(path)


static func file_size(path: String) -> int:
	if not file_exists(path):
		return 0
	var file := FileAccess.open(path, FileAccess.READ)
	return file.get_length() if file != null else 0


static func file_sha256(path: String) -> String:
	if not file_exists(path):
		return ""
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK \
			or context.update(FileAccess.get_file_as_bytes(path)) != OK:
		return ""
	return context.finish().hex_encode()


static func write_json(path: String, payload: Dictionary) -> bool:
	var absolute := absolute_file_path(path)
	if absolute.is_empty():
		return false
	DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	var file := FileAccess.open(absolute, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload, "\t") + "\n")
	return true


static func elapsed_ms(started_usec: int) -> float:
	return float(Time.get_ticks_usec() - started_usec) / 1000.0
