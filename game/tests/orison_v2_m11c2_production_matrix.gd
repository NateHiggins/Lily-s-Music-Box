extends Node
## M11C2 production-cut proof.
##
## This test never selects v2.  It instantiates the production v1 scene through
## BuildingRootSelector twice under each session-only F01 geometry provider,
## then reconstructs each provider through CampaignShell.  Spatial traversal
## records are read from the immutable, hash-bound M11C1 packet; no copy of
## those coordinates is maintained here.

const Selector := preload("res://scripts/building/building_root_selector.gd")
const MatLib := preload("res://scripts/material_library.gd")
const Support := preload(
		"res://tests/orison_v2_m11c1_owner_first/m11c1_harness_support.gd")
const DoorCrossingSupport := preload(
		"res://tests/orison_v2_m11c2_door_crossing_support.gd")

const CONFIGURATION_PATH := \
		"res://scripts/building/floor01_geometry_configuration.gd"
const M11C1_CONFIG_PATH := \
		"res://../art/renders/orison_v2/m11c1_owner_first_rehearsal_01/" + \
		"runtime/m11c1_runtime_config.json"
const M11C1_CONFIG_LF_SHA256 := \
		"98b57247de62133d270b155bd9b0d8b21c533290887a7ee46bb2012f62918fd7"
const PROD_LAYOUT_PATH := "res://data/building_layout.json"
const LEGACY_MONOLITH_PATH := "res://assets/building/floor_01.gltf"
const M11A_SCENE_PATH := "res://scenes/building/orison_v2_exterior_cell.tscn"
const PLAYER_SCRIPT_PATH := "res://scripts/player/player_controller.gd"
const MATRIX_HARNESS_PATH := "res://tests/orison_v2_m11c2_production_matrix.gd"
const RECEIPT_ENV := "M11C2_MATRIX_RECEIPT"
const DEFAULT_RECEIPT := "user://m11c2/production_matrix_receipt.json"
const DOOR_PHYSICAL_SETTLE_SECONDS := 0.60
const PROOF_CLOCK := "12:30"
const PROOF_MINUTE := 750
const MODES := [&"legacy_monolith", &"owner_first_cells"]
const REQUIRED_SPECIAL_SEMANTICS := [
	"F01_DOOR_06", "F01_BODEGA_DOOR", "F01_BAR_DOOR",
	"PASSAGE_PORTAL_LT_W", "PASSAGE_PORTAL_LT_E",
]
const REQUIRED_CONSUMERS := [
	"Player", "WorkOrders", "MaintenanceInventory", "MaintenanceShopService",
	"VantryPointNetwork", "ResidentRoutines", "FirstShiftDirector",
	"ServiceRoundDirector", "CoreLoopDirector",
]
const REQUIRED_NESTED_CONSUMERS := [
	"CallInterface", "VirusSoundDirector", "OrisonDetailPass",
	"ExteriorDetailPass", "ResidentNav", "PauseServices",
	"Floor01CellRegistry",
]
const M11A_PROCESS_SHARED_MATLIB_KEYS := [
	"brass_dull|948563ff|1.00",
	"brass_dull|ccb378ff|1.00",
	"oak_quartered|6b4d33ff|0.80",
]

var _configuration: Script
var _save_directory := ""
var _save_bundles: Dictionary = {}
const SAVE_BUNDLE_SUFFIXES := ["", ".bak", ".txn", ".tmp"]
var _m11c1: Dictionary = {}
var _layout: Dictionary = {}
var _checks: Array[Dictionary] = []
var _failures: Array[String] = []
var _mode_semantics: Dictionary = {}
var _mode_cycles := {"legacy_monolith": [], "owner_first_cells": []}
var _receipt := {
	"schema": "orison.m11c2.production-matrix.v1",
	"task": "ORISON-V2-M11C2",
	"status": "RUNNING",
	"selector": {},
	"source_contract": {},
	"warmup": [],
	"m11a_warmup": {},
	"m11a_lifecycle": {},
	"cycles": {},
	"reconstruction": {},
	"equivalence": {},
	"lifecycle": {},
}


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var globals := _snapshot_globals()
	if not _prepare_save_directory():
		_fail("could not create a fresh matrix save directory")
		await _finish(globals)
		return
	_receipt["matrix_harness_sha256"] = FileAccess.get_sha256(
			MATRIX_HARNESS_PATH)
	# Compare both providers at the same deterministic public trading hour.
	# Noon keeps every ordinarily accessible Passage shop open while the
	# independently locked NEWS/CIGARS leaf still proves its refusal contract.
	# The prior process environment is restored by _finish().
	OS.set_environment("DAYNIGHT_FORCE", PROOF_CLOCK)
	if not _load_sources():
		await _finish(globals)
		return
	_configuration = load(CONFIGURATION_PATH) as Script
	_check(_configuration != null,
			"production Floor01GeometryConfiguration loads")
	if _configuration == null:
		await _finish(globals)
		return
	Selector.reset_for_tests("v1")
	_check(Selector.DEFAULT_ID == "v2", "BuildingRootSelector default is v2")
	_check(Selector.scene_path() == "res://scenes/building/orison_root.tscn",
			"explicit v1 selector resolves the production BuildingRoot")
	_receipt.selector = {
		"default_id": Selector.DEFAULT_ID,
		"requested_id": Selector.selected_id(),
		"scene_path": Selector.scene_path(),
	}
	_receipt["comparison_controls"] = {
		"same_root": Selector.scene_path(),
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"logical_residency": "FULL_RECOMPOSITION",
		"simulation_time": PROOF_CLOCK,
		"production_clock_frozen": true,
		"route_shop_access_state": "ordinary trading hours; NEWS/CIGARS locked",
		"both_providers_prewarmed": true,
		"counterbalanced_measured_order": true,
	}

	# Import and production one-time provider caches are warmed symmetrically
	# before the lifecycle baseline. Warmup is not measured performance and does
	# not duplicate the expensive route that each provider proves in cycle 1.
	for mode: StringName in MODES:
		var warm := await _run_direct_cycle(str(mode), "warmup", false, false)
		(_receipt.warmup as Array).append(warm)
		print("[M11C2-WARMUP] %s components=%s contract_failures=%s" % [mode,
				JSON.stringify(warm.get("ok_components", {})),
				JSON.stringify((warm.get("contract", {}) as Dictionary).get(
						"failures", []))])
		print("[M11C2-SERVICE] %s %s" % [mode, JSON.stringify(
				(warm.get("contract", {}) as Dictionary).get(
						"service_fact_boundary", {}))])
		var warm_semantic: Dictionary = (warm.get("contract", {}) as Dictionary).get(
				"semantic_world", {}) as Dictionary
		print("[M11C2-CONSUMERS] %s %s" % [mode, JSON.stringify(
				(warm_semantic.get("runtime_contract", {}) as Dictionary).get(
						"gate_breakdown", {}))])
		_check(str(warm.get("status", "FAIL")) == "PASS",
				"%s production warmup" % mode)
	# M11A remains an independent production scene, never a child of the F01
	# provider. Warm its own import/resource cache before taking the shared
	# lifecycle baseline used by measured mode runs.
	var m11a_warmup := await _exercise_m11a_lifecycle(
			"owner_first_cells", false)
	_receipt.m11a_warmup = m11a_warmup
	_check(str(m11a_warmup.get("status", "FAIL")) == "PASS",
			"independent M11A production scene warmup")
	var warmed_counts := Support.object_counts()
	_receipt.lifecycle["warmed_baseline"] = warmed_counts

	# Counterbalanced order keeps the second provider from receiving every warm
	# cache advantage.  Exactly two measured complete cycles are retained per
	# provider; the first cycle carries the expensive continuous route proof.
	var schedule := [
		{"mode": "legacy_monolith", "id": "cycle_1", "route": true},
		{"mode": "owner_first_cells", "id": "cycle_1", "route": true},
		{"mode": "owner_first_cells", "id": "cycle_2", "route": false},
		{"mode": "legacy_monolith", "id": "cycle_2", "route": false},
	]
	for row: Dictionary in schedule:
		var result := await _run_direct_cycle(str(row.mode), str(row.id), true,
				bool(row.route))
		(_mode_cycles[str(row.mode)] as Array).append(result)
		print("[M11C2-CYCLE] %s/%s components=%s route=%s" % [
				str(row.mode), str(row.id),
				JSON.stringify(result.get("ok_components", {})),
				str((result.get("route", {}) as Dictionary).get(
						"status", "NOT_RUN"))])
		_check(str(result.get("status", "FAIL")) == "PASS",
				"%s %s complete production cycle" % [row.mode, row.id])
	_receipt.cycles = _mode_cycles.duplicate(true)

	var m11a_normalized: Dictionary = {}
	var m11a_shared_signatures: Dictionary = {
		"warmup": _shared_dependency_signature((m11a_warmup.get(
				"process_shared_dependency_disposition", {}) as Dictionary)),
	}
	for mode: StringName in MODES:
		var m11a := await _exercise_m11a_lifecycle(str(mode), true)
		_receipt.m11a_lifecycle[str(mode)] = m11a
		m11a_normalized[str(mode)] = m11a.get("normalized_result", {})
		m11a_shared_signatures[str(mode)] = _shared_dependency_signature(
				(m11a.get("process_shared_dependency_disposition", {}) \
				as Dictionary))
		_check(str(m11a.get("status", "FAIL")) == "PASS",
				"%s independent M11A lifecycle" % mode)
	var m11a_modes_equal := _canonical_json(m11a_normalized.get(
			"legacy_monolith", {})) == _canonical_json(m11a_normalized.get(
					"owner_first_cells", {})) \
			and not (m11a_normalized.get("legacy_monolith", {}) as Dictionary).is_empty()
	_receipt.m11a_lifecycle["normalized_modes_equal"] = m11a_modes_equal
	_check(m11a_modes_equal,
			"M11A independent lifecycle is mode-independent and normalized-equal")
	var m11a_shared_stable := _canonical_json(m11a_shared_signatures.warmup) \
			== _canonical_json(m11a_shared_signatures.legacy_monolith) \
			and _canonical_json(m11a_shared_signatures.warmup) \
			== _canonical_json(m11a_shared_signatures.owner_first_cells)
	_receipt.m11a_lifecycle["process_shared_dependencies_stable"] = \
			m11a_shared_stable
	_receipt.m11a_lifecycle["process_shared_dependency_signatures"] = \
			m11a_shared_signatures
	_check(m11a_shared_stable,
			"M11A MatLib dependencies reuse the exact warmed resources in both modes")

	var reconstruction_pairs := [
		{"id": "legacy_monolith_to_legacy_monolith",
				"save_mode": "legacy_monolith",
				"reconstruction_mode": "legacy_monolith"},
		{"id": "owner_first_cells_to_owner_first_cells",
				"save_mode": "owner_first_cells",
				"reconstruction_mode": "owner_first_cells"},
		{"id": "legacy_monolith_to_owner_first_cells",
				"save_mode": "legacy_monolith",
				"reconstruction_mode": "owner_first_cells"},
		{"id": "owner_first_cells_to_legacy_monolith",
				"save_mode": "owner_first_cells",
				"reconstruction_mode": "legacy_monolith"},
	]
	for pair: Dictionary in reconstruction_pairs:
		var save_mode := str(pair.save_mode)
		var reconstruction_mode := str(pair.reconstruction_mode)
		var transaction_id := str(pair.id)
		var reconstruction := await _campaign_reconstruction(
				save_mode, reconstruction_mode)
		_receipt.reconstruction[transaction_id] = reconstruction
		_check(str(reconstruction.get("status", "FAIL")) == "PASS",
				"%s save/destroy/CampaignShell reconstruction" % transaction_id)

	var legacy_semantics: Dictionary = _mode_semantics.get("legacy_monolith", {})
	var cell_semantics: Dictionary = _mode_semantics.get("owner_first_cells", {})
	var semantic_equal := not legacy_semantics.is_empty() \
			and _canonical_json(legacy_semantics) == _canonical_json(cell_semantics)
	_receipt.equivalence = {
		"semantic_world_equal": semantic_equal,
		"legacy_sha256": _canonical_json(legacy_semantics).sha256_text(),
		"cells_sha256": _canonical_json(cell_semantics).sha256_text(),
		"raw_coordinates_compared": false,
		"node_or_asset_paths_compared_as_semantic_facts": false,
		"matched_performance": _matched_performance_comparison(),
	}
	_check(semantic_equal,
			"legacy monolith and owner-first cells expose the same semantic world")

	await _settle(6)
	var final_counts := Support.object_counts()
	var final_delta := Support.object_delta(final_counts, warmed_counts)
	_receipt.lifecycle["final"] = final_counts
	_receipt.lifecycle["final_delta_from_warmed"] = final_delta
	_receipt.lifecycle["aggregate_object_resource_delta_observational"] = true
	_check(int(final_delta.get("nodes", 0)) <= 0
			and int(final_delta.get("orphan_nodes", 0)) <= 0,
			"warmed matrix retains no production nodes or orphans")
	await _finish(globals)


func _load_sources() -> bool:
	if not FileAccess.file_exists(M11C1_CONFIG_PATH):
		_fail("committed M11C1 runtime config is missing")
		return false
	var text := FileAccess.get_file_as_string(M11C1_CONFIG_PATH)
	var normalized := text.replace("\r\n", "\n")
	var normalized_sha := normalized.sha256_text()
	_check(normalized_sha == M11C1_CONFIG_LF_SHA256,
			"M11C1 seam/traversal config matches its immutable normalized hash")
	var parsed: Variant = JSON.parse_string(text)
	_check(parsed is Dictionary, "M11C1 seam/traversal config parses")
	if parsed is not Dictionary:
		return false
	_m11c1 = parsed
	var layout_value: Variant = JSON.parse_string(
			FileAccess.get_file_as_string(PROD_LAYOUT_PATH))
	_check(layout_value is Dictionary, "production layout parses read-only")
	if layout_value is not Dictionary:
		return false
	_layout = layout_value
	var required_cells := _required_cell_ids()
	_check((_m11c1.get("seams", []) as Array).size() == 5,
			"M11C1 contract supplies exactly five dangerous seams")
	_check((_m11c1.get("capture_views", []) as Array).size() == 5,
			"M11C1 contract supplies exactly five matched cameras")
	_check(required_cells.size() == 17 and not "CELL_LEGACY_MIXED" in required_cells,
			"M11C1 contract supplies the reviewed seventeen-cell set")
	_receipt.source_contract = {
		"path": M11C1_CONFIG_PATH,
		"normalized_sha256": normalized_sha,
		"seams": (_m11c1.get("seams", []) as Array).size(),
		"capture_views": (_m11c1.get("capture_views", []) as Array).size(),
		"required_cell_ids": required_cells,
		"coordinate_authority": "immutable M11C1 runtime config",
		"vertical_route_authority": PROD_LAYOUT_PATH,
		"embedded_spatial_literals": false,
	}
	return _failures.is_empty()


func _run_direct_cycle(mode: String, cycle_id: String, measured: bool,
		run_route: bool) -> Dictionary:
	_prepare_campaign_facts()
	if not bool(_configuration.call("set_for_tests", mode)):
		return _blocked_cycle(mode, cycle_id,
				"session geometry configuration refused the requested mode")
	Selector.reset_for_tests("v1")
	var before := Support.object_counts()
	var load_started := Time.get_ticks_usec()
	var packed := load(Selector.scene_path()) as PackedScene
	var load_ms := _elapsed_ms(load_started)
	if packed == null:
		return _blocked_cycle(mode, cycle_id, "production v1 scene did not load")
	var instantiate_started := Time.get_ticks_usec()
	var root := packed.instantiate()
	var instantiate_ms := _elapsed_ms(instantiate_started)
	var root_weak: WeakRef = weakref(root)
	var ready_started := Time.get_ticks_usec()
	add_child(root)
	await _settle_root()
	var ready_ms := _elapsed_ms(ready_started)
	var contract := _root_contract(root, mode)
	# Sample the matched root immediately after the same startup/contract work in
	# each mode. The long traversal follows this sample so route duration and
	# incidental resident activity cannot bias the provider comparison.
	var interaction_started := Time.get_ticks_usec()
	var first_prompt := _first_interaction_prompt(root)
	var interaction_ms := _elapsed_ms(interaction_started)
	var metrics := Support.tree_metrics(root)
	var performance := Support.performance_snapshot(get_viewport())
	var route := await _continuous_route(root, mode) if run_route else {
		"status": "NOT_RUN_SECOND_CYCLE",
		"reason": "route is executed once per provider after symmetric warmup",
	}
	var semantic := contract.get("semantic_world", {}) as Dictionary
	if cycle_id == "cycle_1" and measured:
		_mode_semantics[mode] = semantic.duplicate(true)
	var registry: Node = root.call("floor01_geometry_registry") \
			if root.has_method("floor01_geometry_registry") else null
	var host: Node = root.call("floor01_geometry_host") \
			if root.has_method("floor01_geometry_host") else null
	var resource_watch := _geometry_resource_watch(registry)
	var tracked: Array[WeakRef] = [root_weak]
	if host != null:
		tracked.append(weakref(host))
	if registry != null:
		tracked.append(weakref(registry))
		for cell_id: String in _required_cell_ids():
			var instance: Node = registry.call("instance_for_cell", cell_id) \
					if registry.has_method("instance_for_cell") else null
			if instance != null:
				tracked.append(weakref(instance))
	var authority_before_teardown := _authority_census(root)
	var teardown: Dictionary = root.call("teardown_floor01_geometry") \
			if root.has_method("teardown_floor01_geometry") else {}
	await _settle(3)
	var resource_release := _resource_release_receipt(resource_watch)
	var authority_after_teardown := _authority_census(root)
	var authorities_survive := _canonical_json(authority_before_teardown) \
			== _canonical_json(authority_after_teardown)
	var receipt_zero := _teardown_receipt_zero(teardown)
	# Mirror CampaignShell's production scene-replacement boundary.  The F01
	# public teardown only unloads geometry; removing and immediately freeing the
	# complete root is the normal owner operation that ends all remaining
	# gameplay/director/timer lifetimes deterministically.
	registry = null
	host = null
	packed = null
	if root.get_parent() != null:
		root.get_parent().remove_child(root)
	root.free()
	root = null
	await _settle_teardown(6)
	var released := _weakrefs_released(tracked)
	var after := Support.object_counts()
	var delta := Support.object_delta(after, before)
	# Loading a provider for the first time may populate Godot's process-wide
	# import/resource cache.  That one-time cache cost is isolated to the named
	# warmup cycle; measured cycles and the final warmed baseline remain strict.
	var no_node_or_orphan_growth := int(delta.get("nodes", 0)) <= 0 \
			and int(delta.get("orphan_nodes", 0)) <= 0
	var no_object_or_resource_growth := int(delta.get("objects", 0)) <= 0 \
			and int(delta.get("resources", 0)) <= 0
	# Performance's process-wide object/resource monitors include caches and
	# autonomous campaign RefCounted work that cannot be attributed to this
	# provider.  The leak gate is owner-specific: every F01 mesh/material/shape
	# is weak-tracked across public teardown, as are the root, host, registry and
	# cell instances.  Global totals remain in the receipt as an observation.
	var no_positive_lifecycle := no_node_or_orphan_growth \
			and bool(resource_release.get("ok", false))
	var ok_components := {
		"contract": str(contract.get("status", "FAIL")) == "PASS",
		"route": not run_route or str(route.get("status", "FAIL")) == "PASS",
		"public_interaction_prompt": not first_prompt.is_empty(),
		"authorities_survive_geometry_teardown": authorities_survive,
		"public_teardown_receipt_zero": receipt_zero,
		"tracked_weakrefs_released": released,
		"production_cut_resources_released":
				bool(resource_release.get("ok", false)),
		"lifecycle_delta_clean": no_positive_lifecycle,
	}
	var ok := bool(ok_components.contract) and bool(ok_components.route) \
			and bool(ok_components.public_interaction_prompt) \
			and bool(ok_components.authorities_survive_geometry_teardown) \
			and bool(ok_components.public_teardown_receipt_zero) \
			and bool(ok_components.tracked_weakrefs_released) \
			and bool(ok_components.production_cut_resources_released) \
			and bool(ok_components.lifecycle_delta_clean)
	return {
		"status": "PASS" if ok else "FAIL",
		"mode": mode,
		"cycle_id": cycle_id,
		"measured": measured,
		"root_scene": Selector.scene_path(),
		"contract": contract,
		"route": route,
		"performance": {
			"cache_state": "both providers prewarmed" if measured else "warmup",
			"load_ms": load_ms,
			"instantiate_ms": instantiate_ms,
			"ready_and_settle_ms": ready_ms,
			"first_interaction_ms": interaction_ms,
			"first_interaction_nonempty": not first_prompt.is_empty(),
			"tree": metrics,
			"engine": performance,
		},
		"authority_before_geometry_teardown": authority_before_teardown,
		"authority_after_geometry_teardown": authority_after_teardown,
		"authorities_survive_geometry_unload": authorities_survive,
		"teardown": teardown,
		"teardown_receipt_zero": receipt_zero,
		"tracked_weakrefs_released": released,
		"production_cut_resource_release": resource_release,
		"process_before": before,
		"process_after": after,
		"process_delta": delta,
		"ok_components": ok_components,
		"no_retained_production_cut_resources_nodes_or_orphans":
				no_positive_lifecycle,
		"aggregate_object_resource_delta_observational": true,
		"warmup_cache_growth_permitted": not measured,
		"aggregate_object_and_resource_growth_clean_observation":
				no_object_or_resource_growth if measured else null,
	}


func _root_contract(root: Node, mode: String) -> Dictionary:
	var failures: Array[String] = []
	var active_mode := str(root.call("active_floor01_geometry_mode")) \
			if root.has_method("active_floor01_geometry_mode") else ""
	var host: Node = root.call("floor01_geometry_host") \
			if root.has_method("floor01_geometry_host") else null
	var registry: Node = root.call("floor01_geometry_registry") \
			if root.has_method("floor01_geometry_registry") else null
	var startup: Dictionary = root.call("floor01_geometry_receipt") \
			if root.has_method("floor01_geometry_receipt") else {}
	if active_mode != mode:
		failures.append("active mode %s does not equal requested %s" % [active_mode, mode])
	var floor_nodes: Dictionary = root.get("floor_nodes") \
			if root.get("floor_nodes") is Dictionary else {}
	if host == null or floor_nodes.get("F01") != host:
		failures.append("floor_nodes.F01 is not the public persistent host")
	if host == null or host is GeometryInstance3D or host is CollisionObject3D:
		failures.append("public F01 host owns geometry or collision itself")
	if registry == null:
		failures.append("public F01 registry is missing")
	var mounted: Array[String] = []
	if registry != null and registry.has_method("mounted_cell_ids"):
		for raw: Variant in registry.call("mounted_cell_ids"):
			mounted.append(str(raw))
	mounted.sort()
	var expected := _required_cell_ids()
	expected.sort()
	var scene_sources: Array[String] = []
	_collect_scene_sources(root, scene_sources)
	var monolith_loaded := LEGACY_MONOLITH_PATH in scene_sources \
			or _recursive_truth(startup, ["legacy_monolith_loaded",
					"monolith_loaded", "legacy_monolith_mounted"])
	var cells_loaded := mounted == expected
	var xor_ok := (monolith_loaded and not cells_loaded) \
			if mode == "legacy_monolith" else (cells_loaded and not monolith_loaded)
	if not xor_ok:
		failures.append("legacy/cell resource XOR was not proven")
	if mode == "legacy_monolith" and not mounted.is_empty():
		failures.append("legacy mode reports mounted owner-first cells")
	if mode == "owner_first_cells" and mounted != expected:
		failures.append("cell mode does not mount exactly seventeen reviewed cells")

	var service_boundary := _establish_service_fact_boundary(root)
	if not bool(service_boundary.get("ok", false)):
		failures.append("public first-shift/service-round fact boundary failed")
	var semantic := _semantic_world(root, registry)
	if not bool(semantic.get("all_unique", false)):
		failures.append("semantic owners are not complete and unique")
	if not bool((semantic.get("runtime_contract", {}) as Dictionary).get(
			"ok", false)):
		failures.append("mode-independent production consumer facts are incomplete")
	var consumers := _consumer_census(root, host, registry)
	if not bool(consumers.get("all_present_once", false)):
		failures.append("production consumer census is incomplete or duplicated")
	if not bool(startup.get("ok", false)):
		failures.append("BuildingRoot startup receipt is not ok")
	return {
		"status": "PASS" if failures.is_empty() else "FAIL",
		"failures": failures,
		"requested_mode": mode,
		"active_mode": active_mode,
		"selector_id": Selector.selected_id(),
		"selector_path": Selector.scene_path(),
		"host": {
			"present": host != null,
			"same_as_floor_nodes_f01": floor_nodes.get("F01") == host,
			"geometry_free_node": host != null and not (host is GeometryInstance3D)
					and not (host is CollisionObject3D),
		},
		"resource_xor": {
			"passed": xor_ok,
			"legacy_monolith_loaded": monolith_loaded,
			"mounted_cell_ids": mounted,
			"expected_cell_ids": expected,
			"simultaneous": monolith_loaded and cells_loaded,
		},
		"startup_receipt": startup,
		"service_fact_boundary": service_boundary,
		"semantic_world": semantic,
		"consumers": consumers,
	}


func _semantic_world(root: Node, registry: Node) -> Dictionary:
	var owners: Dictionary = {}
	var missing: Array[String] = []
	var duplicate_or_wrong: Array[Dictionary] = []
	for raw: Variant in _m11c1.get("semantic_expectations", []):
		if raw is not Dictionary:
			continue
		var identity := str(raw.get("identity", ""))
		var expected := str(raw.get("owner_cell", ""))
		var actual := str(registry.call("semantic_owner", identity)) \
				if registry != null and registry.has_method("semantic_owner") else ""
		owners[identity] = actual
		if actual.is_empty():
			missing.append(identity)
		elif actual != expected:
			duplicate_or_wrong.append({"identity": identity,
					"expected": expected, "actual": actual})
	for identity: String in REQUIRED_SPECIAL_SEMANTICS:
		if not owners.has(identity):
			missing.append(identity)
	var site_shop_count := 0
	for identity: String in owners:
		if identity.begins_with("SITE_SHOP_"):
			site_shop_count += 1
	var authorities := _authority_census(root)
	var runtime_contract := _mode_independent_world_facts(root)
	return {
		"all_unique": missing.is_empty() and duplicate_or_wrong.is_empty()
				and owners.size() == 189 and site_shop_count == 72,
		"owners": owners,
		"owner_count": owners.size(),
		"site_shop_owner_count": site_shop_count,
		"missing": missing,
		"wrong": duplicate_or_wrong,
		"authorities": authorities,
		"runtime_contract": runtime_contract,
		"layout_sha256": FileAccess.get_sha256(PROD_LAYOUT_PATH),
		"save_authority": "RealityState",
		"geometry_configuration_is_save_authority": false,
	}


## Exercise the existing WorkOrders transition surface just far enough to
## establish the already-ruled boundary between the completed opening job and
## the waiting service round.  The normalized world receipt below records only
## semantic stages/evidence; timestamps remain owned by WorkOrders and are not
## compared as geometry facts.
func _establish_service_fact_boundary(root: Node) -> Dictionary:
	var orders := root.get("work_orders") as WorkOrders
	var director := root.get("service_round") as ServiceRoundDirector
	var coordinator := root.get("core_loop") as CoreLoopDirector
	var shift := root.get("first_shift_director") as FirstShiftDirector
	if orders == null or director == null or coordinator == null or shift == null:
		return {"ok": false,
				"reason": "production first-shift/service authorities absent",
				"owners": {"work_orders": orders != null,
						"service_round": director != null,
						"core_loop": coordinator != null,
						"first_shift": shift != null}}
	var previous := ServiceRoundDirector.PREVIOUS_JOB_ID
	var before := _service_boundary_snapshot(orders, director, shift)
	var transitions: Array[Dictionary] = []
	var guard := 0
	while orders.job_stage(previous) != "closed" and guard < 8:
		guard += 1
		var from_stage := orders.job_stage(previous)
		var action := ""
		var accepted := false
		match from_stage:
			"missing":
				action = "CoreLoopDirector.offer_opening_report"
				accepted = coordinator.offer_opening_report()
			"issued":
				action = "WorkOrders.acknowledge_job"
				accepted = orders.acknowledge_job(previous)
			"acknowledged":
				action = "WorkOrders.diagnose_job"
				accepted = orders.diagnose_job(previous)
			"diagnosed":
				action = "WorkOrders.mark_job_awaiting_part"
				accepted = orders.mark_job_awaiting_part(previous)
			"awaiting_part":
				action = "WorkOrders.mark_job_repairable"
				accepted = orders.mark_job_repairable(previous)
			"repairable":
				action = "WorkOrders.record_job_repair"
				accepted = orders.record_job_repair(previous, {
						"quality": "good",
						"note": "M11C2 parity boundary"})
			"repaired":
				action = "WorkOrders.close_job"
				accepted = orders.close_job(previous)
			_:
				return _service_transition_failure(
						"unexpected prior-job stage", before, transitions,
						orders, director, shift)
		var to_stage := orders.job_stage(previous)
		transitions.append({"action": action, "from": from_stage,
				"accepted": accepted, "to": to_stage})
		if not accepted or to_stage == from_stage:
			return _service_transition_failure(
					"public transition refused or did not advance", before,
					transitions, orders, director, shift)
	if orders.job_stage(previous) != "closed":
		return _service_transition_failure("transition guard exhausted", before,
				transitions, orders, director, shift)
	var previous_state := orders.job_state(previous)
	var service_state := orders.job_state(ServiceRoundDirector.JOB_ID)
	var incoming := director.has_incoming_call()
	var clock_status := orders.status(ClockProp.ORDER_ID)
	var has_open_work := orders.has_open_work()
	var open_work := _open_work_snapshot(orders)
	var exact_expected_open_work: bool = open_work.get("open_simple_order_ids", []) \
			== [ClockProp.ORDER_ID] \
			and (open_work.get("open_maintenance_job_ids", []) as Array).is_empty()
	# Production starts the existing 4B winding order through ClockProp's public
	# WorkOrders seam.  Therefore `has_open_work()` is truthfully true even when
	# the completed chirp leaves the service-round call waiting.  The earlier
	# fixture incorrectly treated an empty queue as the valid boundary.
	var ok: bool = orders.job_stage(previous) == "closed" \
			and orders.job_stage(ServiceRoundDirector.JOB_ID) == "missing" \
			and incoming and clock_status == "active" and has_open_work \
			and exact_expected_open_work \
			and shift.ritual_phase() == FirstShiftDirector.PHASE_COMPLETE
	return {
		"ok": ok,
		"public_work_orders_surface": true,
		"public_core_loop_offer_surface": true,
		"public_service_round_surface": true,
		"before": before,
		"transitions_applied_this_root": transitions,
		"previous_job": _normalized_job_state(previous_state,
				orders.job_stage(previous)),
		"service_job": _normalized_job_state(service_state,
				orders.job_stage(ServiceRoundDirector.JOB_ID)),
		"service_round_incoming_call": incoming,
		"first_shift_phase": shift.ritual_phase(),
		"production_clock_order": {"id": ClockProp.ORDER_ID,
				"status": clock_status},
		"has_open_work": has_open_work,
		"open_work": open_work,
		"exact_expected_open_work": exact_expected_open_work,
		"after": _service_boundary_snapshot(orders, director, shift),
	}


func _service_transition_failure(reason: String, before: Dictionary,
		transitions: Array[Dictionary], orders: WorkOrders,
		director: ServiceRoundDirector, shift: FirstShiftDirector) -> Dictionary:
	return {"ok": false, "reason": reason, "before": before,
			"transitions": transitions.duplicate(true),
			"after": _service_boundary_snapshot(orders, director, shift)}


func _service_boundary_snapshot(orders: WorkOrders,
		director: ServiceRoundDirector, shift: FirstShiftDirector) -> Dictionary:
	return {
		"first_shift_phase": shift.ritual_phase(),
		"previous_job_stage": orders.job_stage(
				ServiceRoundDirector.PREVIOUS_JOB_ID),
		"service_job_stage": orders.job_stage(ServiceRoundDirector.JOB_ID),
		"service_round_incoming_call": director.has_incoming_call(),
		"clock_order_id": ClockProp.ORDER_ID,
		"clock_order_status": orders.status(ClockProp.ORDER_ID),
		"has_open_work": orders.has_open_work(),
		"open_work": _open_work_snapshot(orders),
		"maintenance_jobs": _normalized_serialized_jobs(orders.serialize_jobs()),
	}


func _open_work_snapshot(orders: WorkOrders) -> Dictionary:
	var open_simple: Array[String] = []
	var simple_records: Dictionary = RealityState.data.get("work_orders", {}) \
			as Dictionary
	for raw_id: Variant in simple_records:
		var order_id := str(raw_id)
		if orders.status(order_id) != "closed":
			open_simple.append(order_id)
	open_simple.sort()
	var open_jobs: Array[String] = []
	var serialized: Dictionary = orders.serialize_jobs()
	var jobs: Dictionary = serialized.get("jobs", {}) as Dictionary
	for raw_id: Variant in jobs:
		var job_id := str(raw_id)
		if orders.job_stage(job_id) != "closed":
			open_jobs.append(job_id)
	open_jobs.sort()
	return {
		"open_simple_order_ids": open_simple,
		"open_maintenance_job_ids": open_jobs,
		"aggregate_has_open_work": orders.has_open_work(),
		"durable_owner": "RealityState via WorkOrders public status/serialization",
	}


func _mode_independent_world_facts(root: Node) -> Dictionary:
	var detail := root.get("environment_detail_pass") as OrisonDetailPass
	var exterior := root.get("exterior_detail_pass") as ExteriorDetailPass
	var vantry := root.get("vantry_points") as VantryPointNetwork
	var routines := root.get("resident_routines") as ResidentRoutines
	var nav: ResidentNav = routines.nav if routines != null else null
	var player := root.get("player") as PlayerController
	var pause: Node = player.pause_services if player != null else null
	var shift := root.get("first_shift_director") as FirstShiftDirector
	var service := root.get("service_round") as ServiceRoundDirector
	var orders := root.get("work_orders") as WorkOrders

	var acoustic_keys: Array[String] = []
	for raw_key: Variant in AcousticGraphData.nodes.keys():
		acoustic_keys.append(str(raw_key))
	acoustic_keys.sort()
	var accessibility_keys: Array[String] = [
		"always_warn_before_sleep", "gameplay_sound_captions",
		"dream_directional_captions", "reduce_camera_roll", "reduce_flashing",
		"look_sensitivity", "controller_look_sensitivity",
		"controller_look_deadzone", "controller_look_curve",
		"controller_invert_y",
	]
	var accessibility_values: Dictionary = {}
	for key: String in accessibility_keys:
		accessibility_values[key] = GameBoot.settings.get(key)

	var nav_levels: Array[String] = []
	var passage_places: Array[String] = []
	var nav_ok := nav != null
	if nav != null:
		for raw_level: Variant in nav.level_order:
			nav_levels.append(str(raw_level))
		for place: String in ResidentNav.PASSAGE_PLACES.keys():
			if nav.has_passage_anchor(place):
				passage_places.append(place)
		nav_levels.sort()
		passage_places.sort()
		nav_ok = nav.unreachable_route_count() == 0 \
				and nav_levels.size() == 8 \
				and passage_places.size() == ResidentNav.PASSAGE_PLACES.size()

	var detail_facts := {
		"owner_present": detail != null,
		"detail_count": detail.detail_count if detail != null else -1,
		"decal_count": detail.decal_count if detail != null else -1,
	}
	var exterior_facts := {
		"owner_present": exterior != null,
		"detail_count": exterior.detail_count if exterior != null else -1,
		"decal_count": exterior.decal_count if exterior != null else -1,
		"puddle_count": exterior.puddle_count if exterior != null else -1,
		"boundary_count": exterior.boundary_count if exterior != null else -1,
		"faulty_lamp_count": exterior.faulty_lamp_count if exterior != null else -1,
	}
	var vantry_ids: Array[String] = vantry.cached_point_ids() \
			if vantry != null else []
	var vantry_floor_ids: Array[String] = []
	var vantry_points_missing_floor: Array[String] = []
	if vantry != null:
		for point_id: String in vantry_ids:
			var point: Dictionary = vantry.point_spec(point_id)
			var floor_id := str(point.get("floor", ""))
			if floor_id.is_empty():
				vantry_points_missing_floor.append(point_id)
			elif floor_id not in vantry_floor_ids:
				vantry_floor_ids.append(floor_id)
	vantry_floor_ids.sort()
	vantry_points_missing_floor.sort()
	var vantry_static_draws := vantry.static_draws_per_floor() \
			if vantry != null else -1
	var vantry_facts := {
		"owner_present": vantry != null,
		"point_count": vantry_ids.size(),
		"point_id_sha256": JSON.stringify(vantry_ids).sha256_text(),
		"authored_floor_ids": vantry_floor_ids,
		"authored_floor_id_sha256": JSON.stringify(vantry_floor_ids).sha256_text(),
		"points_missing_floor": vantry_points_missing_floor,
		"floor_batch_count": vantry.floor_batch_count() if vantry != null else -1,
		"static_draws_per_floor": vantry_static_draws,
		"active_mesh_count": vantry.active_mesh_count() if vantry != null else -1,
	}
	var shift_state: Dictionary = shift.ritual_state() if shift != null else {}
	var previous_stage := orders.job_stage(ServiceRoundDirector.PREVIOUS_JOB_ID) \
			if orders != null else "owner_missing"
	var service_stage := orders.job_stage(ServiceRoundDirector.JOB_ID) \
			if orders != null else "owner_missing"
	var service_facts := {
		"owner_present": service != null and orders != null,
		"previous_job": _normalized_job_state(orders.job_state(
				ServiceRoundDirector.PREVIOUS_JOB_ID), previous_stage) \
				if orders != null else {},
		"service_job": _normalized_job_state(orders.job_state(
				ServiceRoundDirector.JOB_ID), service_stage) \
				if orders != null else {},
		"incoming_call": service.has_incoming_call() if service != null else false,
		"has_open_work": orders.has_open_work() if orders != null else false,
		"clock_order_id": ClockProp.ORDER_ID,
		"clock_order_status": orders.status(ClockProp.ORDER_ID) \
				if orders != null else "owner_missing",
		"open_work": _open_work_snapshot(orders) if orders != null else {},
	}
	var acoustic_required := ["F02_A_MAIN_VANTRY_POINT", "F04_B_MONITOR_01"]
	var acoustic_ok := root.get("virus_director") != null \
			and root.get("call_interface") != null
	for identity: String in acoustic_required:
		acoustic_ok = acoustic_ok and identity in acoustic_keys
	var details_ok := detail != null and detail.detail_count > 0 \
			and exterior != null and exterior.detail_count > 0
	var vantry_ok := vantry != null and vantry_ids.size() > 0 \
			and vantry_points_missing_floor.is_empty() \
			and not vantry_floor_ids.is_empty() \
			and vantry.floor_batch_count() == vantry_floor_ids.size() \
			and vantry_static_draws > 0
	var accessibility_ok: bool = pause != null and pause.has_method("can_open") \
			and pause.get("player") == player
	var shift_ok := shift != null \
			and shift.ritual_phase() == FirstShiftDirector.PHASE_COMPLETE \
			and str(shift_state.get("report_id", "")) == ChirpHunt.JOB_ID \
			and str(shift_state.get("filing", "")) == "fault_corrected"
	var service_open_work: Dictionary = service_facts.get("open_work", {}) \
			as Dictionary
	var service_ok: bool = bool(service_facts.owner_present) \
			and previous_stage == "closed" and service_stage == "missing" \
			and bool(service_facts.incoming_call) \
			and bool(service_facts.has_open_work) \
			and str(service_facts.clock_order_status) == "active" \
			and (service_open_work.get(
					"open_simple_order_ids", []) as Array) == [ClockProp.ORDER_ID] \
			and (service_open_work.get(
					"open_maintenance_job_ids", []) as Array).is_empty()
	return {
		"ok": details_ok and vantry_ok and nav_ok and accessibility_ok \
				and acoustic_ok and shift_ok and service_ok,
		"gate_breakdown": {
			"details": details_ok,
			"vantry": vantry_ok,
			"resident_nav": nav_ok,
			"accessibility": accessibility_ok,
			"acoustic": acoustic_ok,
			"first_shift": shift_ok,
			"service_round": service_ok,
		},
		"OrisonDetailPass": detail_facts,
		"ExteriorDetailPass": exterior_facts,
		"VantryPointNetwork": vantry_facts,
		"ResidentNav": {
			"owner_present": nav != null,
			"floor_ids": nav_levels,
			"unreachable_route_count": nav.unreachable_route_count() \
					if nav != null else -1,
			"passage_places": passage_places,
			"accessibility_route_contract": nav_ok,
		},
		"accessibility": {
			"pause_services_owner_present": pause != null,
			"bound_to_production_player": pause != null \
					and pause.get("player") == player,
			"can_open": bool(pause.call("can_open")) \
					if pause != null and pause.has_method("can_open") else false,
			"setting_values": accessibility_values,
		},
		"acoustic": {
			"VirusSoundDirector_owner_count": root.find_children(
					"*", "VirusSoundDirector", true, false).size(),
			"CallInterface_owner_present": root.get("call_interface") != null,
			"node_key_count": acoustic_keys.size(),
			"node_keys": acoustic_keys,
			"required_origins": acoustic_required,
			"high_band_origin": VirusSoundDirector.BAND_ORIGINS.get("high", ""),
		},
		"first_shift": {
			"owner_present": shift != null,
			"phase": shift.ritual_phase() if shift != null else "owner_missing",
			"state": shift_state,
			"opening_job_id": FirstShiftDirector.OPENING_JOB_ID,
		},
		"service_round": service_facts,
		"work_orders": {
			"owner_present": orders != null,
			"job_library_present": orders != null and orders.job_library != null,
			"public_serialization_normalized": _normalized_serialized_jobs(
					orders.serialize_jobs()) if orders != null else {},
		},
	}


func _normalized_job_state(state: Dictionary, stage: String) -> Dictionary:
	var evidence: Array[String] = []
	for raw: Variant in state.get("evidence", []):
		evidence.append(str(raw))
	evidence.sort()
	var repair: Dictionary = state.get("repair_result", {}) \
			if state.get("repair_result", {}) is Dictionary else {}
	return {
		"stage": stage,
		"origin": str(state.get("origin", "")),
		"evidence": evidence,
		"repair_quality": str(repair.get("quality", "")),
		"repair_note": str(repair.get("note", "")),
	}


func _normalized_serialized_jobs(payload: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var jobs: Dictionary = payload.get("jobs", {}) \
			if payload.get("jobs", {}) is Dictionary else {}
	var ids: Array[String] = []
	for raw_id: Variant in jobs:
		ids.append(str(raw_id))
	ids.sort()
	for job_id: String in ids:
		var state: Dictionary = jobs.get(job_id, {}) \
				if jobs.get(job_id, {}) is Dictionary else {}
		result[job_id] = _normalized_job_state(state,
				str(state.get("stage", "missing")))
	return {"job_ids": ids, "jobs": result}


func _consumer_census(root: Node, host: Node, registry: Node) -> Dictionary:
	var census := _authority_census(root)
	var rows: Array[Dictionary] = []
	var all_once := true
	for identity: String in REQUIRED_CONSUMERS + REQUIRED_NESTED_CONSUMERS:
		var row: Dictionary = census.get(identity, {})
		rows.append(row)
		all_once = all_once and int(row.get("count", 0)) == 1 \
				and bool(row.get("public_reference_is_unique_instance", false))
	return {
		"all_present_once": all_once and host != null and registry != null,
		"authorities": rows,
		"f01_host_persistent": host != null,
		"registry_present": registry != null,
		"registry_public_reference_is_unique_instance": registry != null \
				and bool((census.get("Floor01CellRegistry", {}) as Dictionary).get(
						"public_reference_is_unique_instance", false)),
		"m11a_exterior_composition":
				"separate public-scene lifecycle; never co-mounted with F01 geometry",
	}


func _authority_census(root: Node) -> Dictionary:
	var result: Dictionary = {}
	var scope := _authority_composition_scope(root)
	for identity: String in REQUIRED_CONSUMERS + REQUIRED_NESTED_CONSUMERS:
		var type_name := "PlayerController" if identity == "Player" else identity
		var found := scope.find_children("*", type_name, true, false)
		var public_ref := _public_authority_reference(root, identity)
		result[identity] = {
			"identity": identity,
			"runtime_type": type_name,
			"composition_scope": "campaign_shell" \
					if scope != root else "building_root",
			"count": found.size(),
			"public_reference_present": public_ref != null,
			"public_reference_is_unique_instance": found.size() == 1 \
					and public_ref != null and found[0] == public_ref,
		}
	return result


func _authority_composition_scope(root: Node) -> Node:
	# CampaignShell deliberately owns CoreLoopDirector across waking-world
	# replacement.  Count the complete production composition in that case;
	# direct BuildingRoot tests count the root itself.  This catches both a
	# missing external owner and an accidental duplicate local owner.
	var ancestor := root.get_parent()
	while ancestor != null:
		if ancestor.is_in_group("campaign_shell"):
			return ancestor
		ancestor = ancestor.get_parent()
	return root


func _public_authority_reference(root: Node, identity: String) -> Node:
	match identity:
		"Player": return root.get("player") as Node
		"WorkOrders": return root.get("work_orders") as Node
		"MaintenanceInventory": return root.get("maintenance_inventory") as Node
		"MaintenanceShopService": return root.get("shop_service") as Node
		"VantryPointNetwork": return root.get("vantry_points") as Node
		"ResidentRoutines": return root.get("resident_routines") as Node
		"FirstShiftDirector": return root.get("first_shift_director") as Node
		"ServiceRoundDirector": return root.get("service_round") as Node
		"CoreLoopDirector": return root.get("core_loop") as Node
		"CallInterface": return root.get("call_interface") as Node
		"VirusSoundDirector": return root.get("virus_director") as Node
		"OrisonDetailPass": return root.get("environment_detail_pass") as Node
		"ExteriorDetailPass": return root.get("exterior_detail_pass") as Node
		"Floor01CellRegistry": return root.get("floor01_cell_registry") as Node
		"ResidentNav":
			var routines := root.get("resident_routines") as ResidentRoutines
			return routines.nav if routines != null else null
		"PauseServices":
			var player := root.get("player") as PlayerController
			return player.pause_services if player != null else null
	return null


func _exercise_m11a_lifecycle(mode: String, measured: bool) -> Dictionary:
	_prepare_campaign_facts()
	if not bool(_configuration.call("set_for_tests", mode)):
		return {"status": "FAIL", "mode": mode,
				"reason": "geometry configuration refused M11A lifecycle mode"}
	Selector.reset_for_tests("v1")
	var complete_root_count := 0
	for child: Node in get_children():
		if child.has_method("active_floor01_geometry_mode"):
			complete_root_count += 1
	var before := Support.object_counts()
	var started := Time.get_ticks_usec()
	var packed := load(M11A_SCENE_PATH) as PackedScene
	if packed == null:
		return {"status": "FAIL", "mode": mode,
				"reason": "M11A production scene is missing"}
	var instance := packed.instantiate() as Node3D
	if instance == null:
		return {"status": "FAIL", "mode": mode,
				"reason": "M11A production scene did not instantiate"}
	var tracked: Array[WeakRef] = [weakref(instance)]
	add_child(instance)
	await _settle_root()
	var module_parent_is_harness := instance.get_parent() == self
	var module_transform_identity := instance.global_transform.is_equal_approx(
			Transform3D.IDENTITY)
	var startup_failed := bool(instance.get("startup_failed"))
	var player := instance.get("player") as PlayerController
	var production_player_ok := player != null \
			and str(player.get_script().resource_path) == PLAYER_SCRIPT_PATH
	if player != null:
		tracked.append(weakref(player))
	var resolver: Variant = instance.get("spatial_resolver")
	if resolver is Object:
		tracked.append(weakref(resolver))
	var bucket_registry: Variant = instance.get("shop_bucket_registry")
	if bucket_registry is Object:
		tracked.append(weakref(bucket_registry))
	var census: Dictionary = instance.call("authority_census") \
			if instance.has_method("authority_census") else {}
	var cost: Dictionary = instance.call("cost_report") \
			if instance.has_method("cost_report") else {}
	var fixture: Dictionary = _m11c1.get("save_reconstruction", {}) as Dictionary
	var route_id := str(fixture.get("route_id", ""))
	var threshold_id := str(fixture.get("threshold_id", ""))
	var route: Dictionary = instance.call("route", route_id) \
			if instance.has_method("route") else {}
	var threshold: Dictionary = resolver.call(
			"resolve_threshold", threshold_id) \
			if resolver is Object and resolver.has_method("resolve_threshold") else {}
	var route_threshold_ids: Array[String] = []
	for raw_threshold: Variant in route.get("thresholds", []):
		if raw_threshold is Dictionary:
			route_threshold_ids.append(str(raw_threshold.get("id", "")))
	route_threshold_ids.sort()
	var v1_door := _semantic_expectation("F01_BODEGA_DOOR")
	var v2_threshold := _semantic_expectation(threshold_id)
	var semantic_distinct := not v1_door.is_empty() \
			and not v2_threshold.is_empty() \
			and str(v1_door.get("identity", "")) != threshold_id \
			and str(v1_door.get("role", "")) == "layout_marker" \
			and str(v2_threshold.get("role", "")) \
					== "m11a_exterior_threshold"
	var route_ok := str(route.get("id", "")) == route_id \
			and threshold_id in route_threshold_ids
	var threshold_ok := str(threshold.get("id", "")) == threshold_id \
			and not str(threshold.get("interactive_leaf_id", "")).is_empty()
	var authorities_once := _all_m11a_authorities_once(census)
	# The module owns its authored cell resources explicitly.  DoorProp and
	# production-player children also reference MaterialLibrary's process-shared
	# materials; those are dependencies, not resources owned by this lifecycle.
	var resource_watch := _geometry_resource_watch(instance,
			&"orison_v2_exterior_owned")
	var all_resource_watch := _geometry_resource_watch(instance)
	var teardown: Dictionary = instance.call("shutdown_for_tests") \
			if instance.has_method("shutdown_for_tests") else {}
	var repeated_teardown: Dictionary = instance.call("shutdown_for_tests") \
			if instance.has_method("shutdown_for_tests") else {}
	remove_child(instance)
	instance.free()
	instance = null
	player = null
	resolver = null
	bucket_registry = null
	packed = null
	await _settle(8)
	var released := _weakrefs_released(tracked)
	var resource_release := _resource_release_receipt(resource_watch)
	var shared_dependency_disposition := _shared_dependency_disposition(
			all_resource_watch)
	var after := Support.object_counts()
	var delta := Support.object_delta(after, before)
	var no_node_or_orphan_growth := int(delta.get("nodes", 0)) <= 0 \
			and int(delta.get("orphan_nodes", 0)) <= 0
	var no_object_or_resource_growth := int(delta.get("objects", 0)) <= 0 \
			and int(delta.get("resources", 0)) <= 0
	var lifecycle_clean := no_node_or_orphan_growth \
			and bool(resource_release.get("ok", false)) \
			and bool(shared_dependency_disposition.get("ok", false))
	var teardown_ok := bool(teardown.get("ok", false)) \
			and int(teardown.get("retained_strong_references", -1)) == 0 \
			and bool(repeated_teardown.get("already_torn_down", false))
	var normalized := {
		"production_scene": M11A_SCENE_PATH,
		"production_player": production_player_ok,
		"authority_census": census,
		"cost_report": cost,
		"route_id": route_id,
		"route_resolved": route_ok,
		"threshold_id": threshold_id,
		"threshold_resolved": threshold_ok,
		"v1_v2_semantic_identity_distinct": semantic_distinct,
		"module_root_transform_identity": module_transform_identity,
		"module_parent_is_isolated_harness": module_parent_is_harness,
		"complete_building_root_co_mounted": complete_root_count > 0,
		"public_teardown_ok": teardown_ok,
	}
	var ok := complete_root_count == 0 and module_parent_is_harness \
			and module_transform_identity and not startup_failed \
			and production_player_ok and authorities_once \
			and route_ok and threshold_ok and semantic_distinct \
			and teardown_ok and released and lifecycle_clean \
			and str(_configuration.call("selected_mode")) == mode
	return {
		"status": "PASS" if ok else "FAIL",
		"mode": mode,
		"measured": measured,
		"selector_id": Selector.selected_id(),
		"geometry_configuration": str(_configuration.call("selected_mode")),
		"production_scene": M11A_SCENE_PATH,
		"adaptation_topology": "separate lifecycle; never co-mounted with F01 providers",
		"startup_failed": startup_failed,
		"authority_census": census,
		"all_authorities_exactly_once": authorities_once,
		"cost_report": cost,
		"route_id": route_id,
		"route_resolved": route_ok,
		"route_threshold_ids": route_threshold_ids,
		"threshold_id": threshold_id,
		"threshold_resolved": threshold_ok,
		"v1_bodega_door_source": v1_door,
		"v2_bodega_threshold_source": v2_threshold,
		"v1_v2_semantic_identity_distinct": semantic_distinct,
		"complete_building_root_co_mounted": complete_root_count > 0,
		"public_teardown": teardown,
		"repeated_public_teardown": repeated_teardown,
		"tracked_weakrefs_released": released,
		"production_module_resource_release": resource_release,
		"process_shared_dependency_disposition":
				shared_dependency_disposition,
		"process_before": before,
		"process_after": after,
		"process_delta": delta,
		"warmup_cache_growth_permitted": not measured,
		"aggregate_object_and_resource_growth_clean_observation":
				no_object_or_resource_growth if measured else null,
		"aggregate_object_resource_delta_observational": true,
		"elapsed_ms": _elapsed_ms(started),
		"normalized_result": normalized,
	}


func _semantic_expectation(identity: String) -> Dictionary:
	for raw: Variant in _m11c1.get("semantic_expectations", []):
		if raw is Dictionary and str(raw.get("identity", "")) == identity:
			return (raw as Dictionary).duplicate(true)
	return {}


func _all_m11a_authorities_once(census: Dictionary) -> bool:
	for identity: String in ["player_controller", "work_orders",
			"maintenance_inventory", "maintenance_shop_service",
			"shop_bucket_registry", "spatial_resolver"]:
		if int(census.get(identity, 0)) != 1:
			return false
	return true


func _continuous_route(root: Node, mode: String) -> Dictionary:
	var player := root.get("player") as PlayerController
	if player == null or str(player.get_script().resource_path) != PLAYER_SCRIPT_PATH:
		return {"status": "FAIL", "reason": "production PlayerController unavailable"}
	var seams := _seams_by_id()
	var shell: Dictionary = _traversal(seams, "SEAM_ORISON_SOUTH_SHELL_STREET", 0)
	var facade: Dictionary = _traversal(seams, "SEAM_SHELL_INTERIOR", 0)
	var bodega: Dictionary = _traversal(seams, "SEAM_BODEGA_STREET", 0)
	var portal: Dictionary = _traversal(seams, "SEAM_STREET_PASSAGE_PORTAL", 0)
	var passage: Dictionary = seams.get("SEAM_PASSAGE_SHOP_AISLES", {})
	if shell.is_empty() or facade.is_empty() or bodega.is_empty() \
			or portal.is_empty() or passage.is_empty():
		return {"status": "FAIL", "reason": "hash-bound route records incomplete"}
	var initial := Support.vector3((shell.get("forward_waypoints", []) as Array)[0])
	player.global_position = initial
	player.velocity = Vector3.ZERO
	player.autopilot = Vector3.ZERO
	await _settle_player(player)
	var rows: Array[Dictionary] = []
	var semantic_seam_chains: Array[Dictionary] = []
	var crossings: Dictionary = {}
	var ok := not player.noclip and player.collision_layer != 0 \
			and player.collision_mask != 0 and player.is_on_floor()
	var initial_grounded := player.is_on_floor()
	var orison_door := await _open_public_door(root,
			str(shell.get("door_identity", "")), player, false)
	ok = ok and bool(orison_door.get("ok", false))
	# Leave Orison.  This one movement crosses both facade/interior and
	# shell/street planes; the reverse leg is performed at the end.
	var outside := Support.vector3(shell.get("start", []))
	var leave := await _walk_to(player, outside, shell, "orison_to_street")
	rows.append(leave)
	crossings["facade_out"] = _crossed_between(initial, player.global_position,
			facade.get("plane", {}))
	crossings["shell_out"] = _crossed_between(initial, player.global_position,
			shell.get("plane", {}))
	ok = ok and bool(leave.get("reached", false)) and bool(crossings.facade_out) \
			and bool(crossings.shell_out)

	# Bodega round trip.
	rows.append(await _walk_to(player, Support.vector3(bodega.get("start", [])),
			bodega, "street_to_bodega_start"))
	var bodega_door := await _open_public_door(root,
			str(bodega.get("door_identity", "")), player, false)
	var bodega_inside := await _walk_to(player,
			Support.vector3((bodega.get("forward_waypoints", []) as Array)[0]),
			bodega, "bodega_enter")
	var bodega_return := await _walk_to(player,
			Support.vector3((bodega.get("return_waypoints", []) as Array)[0]),
			bodega, "bodega_return")
	rows.append(bodega_inside)
	rows.append(bodega_return)
	ok = ok and bool(bodega_door.get("ok", false)) \
			and bool(bodega_inside.get("reached", false)) \
			and bool(bodega_return.get("reached", false))

	# The bodega and Passage are independently authored seams.  Join them via
	# the Orison-side exterior endpoint whose outbound connector already passed,
	# then the Passage endpoint.  Every target remains owned by the immutable
	# M11C1 seam records; the receipt stores identities and hashes, not a copied
	# coordinate path.
	var street_to_passage := await _walk_semantic_seam_chain(player, [
		{
			"authority_id": "SEAM_ORISON_SOUTH_SHELL_STREET",
			"record": shell,
			"endpoint_role": "start",
			"relationship": "reverse of passed Orison-to-bodega connector",
		},
		{
			"authority_id": "SEAM_STREET_PASSAGE_PORTAL",
			"record": portal,
			"endpoint_role": "start",
			"relationship": "Passage exterior approach",
		},
	], "bodega_to_passage_start")
	semantic_seam_chains.append(street_to_passage)
	rows.append(street_to_passage)
	ok = ok and bool(street_to_passage.get("reached", false))
	var portal_enter := await _walk_to(player,
			Support.vector3((portal.get("forward_waypoints", []) as Array)[0]),
			portal, "passage_enter")
	rows.append(portal_enter)
	ok = ok and bool(portal_enter.get("reached", false))
	var shop_results: Array[Dictionary] = []
	for raw: Variant in passage.get("traversals", []):
		if raw is not Dictionary:
			continue
		var spec: Dictionary = raw
		var connector := await _walk_to(player, Support.vector3(spec.get("start", [])),
				spec, "%s_connector" % str(spec.get("id", "shop")))
		rows.append(connector)
		var locked := str(spec.get("expectation", "")) == "locked_non_crossable"
		var door_result := await _open_public_door(root,
				str(spec.get("door_identity", "")), player, locked)
		var before_attempt := player.global_position
		var crossing_path := {"ok": true, "receipt": {
			"applicable": false, "reason": "locked_non_crossable"}}
		var enter: Dictionary
		if locked:
			enter = await _walk_to(player,
					Support.vector3((spec.get("forward_waypoints", []) as Array)[0]),
					spec, "%s_enter" % str(spec.get("id", "shop")), true)
		else:
			crossing_path = DoorCrossingSupport.derive(root, spec)
			if bool(crossing_path.get("ok", false)):
				enter = await _walk_waypoints(player,
						crossing_path.get("forward_waypoints", []) as Array[Vector3],
						spec, "%s_enter" % str(spec.get("id", "shop")))
			else:
				enter = {"reached": false,
						"reason": crossing_path.get("reason", "crossing derivation failed")}
		var crossed := _crossed_between(before_attempt, player.global_position,
				spec.get("plane", {}))
		var return_leg: Dictionary
		if locked:
			return_leg = await _walk_to(player, Support.vector3(spec.get("start", [])),
					spec, "%s_locked_return" % str(spec.get("id", "shop")))
		elif bool(crossing_path.get("ok", false)):
			return_leg = await _walk_waypoints(player,
					crossing_path.get("return_waypoints", []) as Array[Vector3],
					spec, "%s_return" % str(spec.get("id", "shop")))
		else:
			return_leg = {"reached": false,
					"reason": crossing_path.get("reason", "crossing derivation failed")}
		rows.append(enter)
		rows.append(return_leg)
		var shop_ok := bool(connector.get("reached", false)) \
				and bool(door_result.get("ok", false)) \
				and bool(return_leg.get("reached", false)) \
				and ((not bool(enter.get("reached", false)) and not crossed) if locked \
				else (bool(enter.get("reached", false)) and crossed))
		shop_results.append({
			"id": spec.get("id", ""),
			"status": "PASS" if shop_ok else "FAIL",
			"locked": locked,
			"door": door_result,
			"derived_crossing": crossing_path.get("receipt", {}),
			"crossed": crossed,
			"enter": enter,
			"return": return_leg,
		})
		ok = ok and shop_ok

	# Passage and Orison return.
	rows.append(await _walk_to(player,
			Support.vector3((portal.get("forward_waypoints", []) as Array)[0]),
			portal, "passage_to_portal"))
	var portal_return := await _walk_to(player,
			Support.vector3((portal.get("return_waypoints", []) as Array)[0]),
			portal, "passage_to_street")
	rows.append(portal_return)
	var street_to_orison := await _walk_semantic_seam_chain(player, [
		{
			"authority_id": "SEAM_ORISON_SOUTH_SHELL_STREET",
			"record": shell,
			"endpoint_role": "start",
			"relationship": "Passage return to Orison exterior",
		},
	], "street_to_orison")
	semantic_seam_chains.append(street_to_orison)
	rows.append(street_to_orison)
	var inside := Support.vector3((shell.get("forward_waypoints", []) as Array)[0])
	var enter_orison := await _walk_to(player, inside, shell, "street_to_interior")
	rows.append(enter_orison)
	crossings["shell_return"] = _crossed_between(outside, player.global_position,
			shell.get("plane", {}))
	crossings["facade_return"] = _crossed_between(outside, player.global_position,
			facade.get("plane", {}))
	ok = ok and bool(portal_return.get("reached", false)) \
			and bool(street_to_orison.get("reached", false)) \
			and bool(enter_orison.get("reached", false)) \
			and bool(crossings.shell_return) and bool(crossings.facade_return)

	var vertical := await _vertical_core_round_trip(player)
	ok = ok and str(vertical.get("status", "FAIL")) == "PASS"
	player.autopilot = Vector3.ZERO
	return {
		"status": "PASS" if ok else "FAIL",
		"mode": mode,
		"production_player_script": str(player.get_script().resource_path),
		"initial_placement_count": 1,
		"intermediate_transform_writes": 0,
		"teleports": 0,
		"noclip": player.noclip,
		"initial_grounded": initial_grounded,
		"source_contract": M11C1_CONFIG_PATH,
		"source_contract_sha256": M11C1_CONFIG_LF_SHA256,
		"crossings": crossings,
		"semantic_seam_chains": semantic_seam_chains,
		"shop_routes": shop_results,
		"legs": rows,
		"vertical_core": vertical,
	}


func _vertical_core_round_trip(player: PlayerController) -> Dictionary:
	var stairs: Array = _layout.get("stairs", [])
	if stairs.is_empty() or stairs[0] is not Dictionary:
		return {"status": "FAIL", "reason": "production stair record missing"}
	var parts: Array = (stairs[0] as Dictionary).get("parts", [])
	var first: Dictionary = {}
	var turn: Dictionary = {}
	var second: Dictionary = {}
	var arrival: Dictionary = {}
	for raw: Variant in parts:
		if raw is not Dictionary:
			continue
		var part: Dictionary = raw
		if str(part.get("kind", "")) == "flight" \
				and is_equal_approx(float(part.get("z0", -99.0)), 0.0):
			first = part
		elif str(part.get("kind", "")) == "landing" \
				and is_equal_approx(float(part.get("z", -99.0)), 1.6):
			turn = part
		elif str(part.get("kind", "")) == "flight" \
				and is_equal_approx(float(part.get("z0", -99.0)), 1.6):
			second = part
		elif str(part.get("kind", "")) == "landing" \
				and is_equal_approx(float(part.get("z", -99.0)), 3.2):
			arrival = part
	if first.is_empty() or turn.is_empty() or second.is_empty() or arrival.is_empty():
		return {"status": "FAIL", "reason": "F01/F02 stair topology incomplete"}
	var offset := _route_ground_offset()
	var f01_hall := _room_rect("F01", "F01_HALL")
	var f01_atrium := _room_rect("F01", "F01_ATRIUM")
	var f02_hall := _room_rect("F02", "F02_HALL")
	var f02_atrium := _room_rect("F02", "F02_ATRIUM")
	if f01_hall.size() != 4 or f01_atrium.size() != 4 \
			or f02_hall.size() != 4 or f02_atrium.size() != 4:
		return {"status": "FAIL", "reason": "authored F01/F02 hall topology missing"}
	# Reach the flight through the two authored common-space openings.  A direct
	# lobby-to-flight diagonal cuts the wall at the south edge of F01_ATRIUM and
	# is not a valid PlayerController route.  Every point below is derived from
	# room and stair records in the production layout.
	var first_x := (float(first.get("b0", 0.0)) \
			+ float(first.get("b1", 0.0))) * 0.5
	var hall_x := (float(f01_hall[0]) + float(f01_hall[2])) * 0.5
	var hall_y := (float(f01_hall[1]) + float(f01_hall[3])) * 0.5
	var atrium_x := (float(f01_atrium[0]) + float(f01_atrium[2])) * 0.5
	var atrium_south_y := float(f01_atrium[1])
	var atrium_depth := float(f01_atrium[3]) - atrium_south_y
	var atrium_inside_y := atrium_south_y + atrium_depth * 0.1
	var foot_y := (atrium_south_y + float(first.get("start", 0.0))) * 0.5
	var entry_path: Array[Vector3] = [
		_plan_point(hall_x, hall_y, float(first.get("z0", 0.0)) + offset),
		_plan_point(atrium_x, atrium_inside_y,
				float(first.get("z0", 0.0)) + offset),
		_plan_point(first_x, foot_y, float(first.get("z0", 0.0)) + offset),
	]
	var up: Array[Vector3] = []
	_append_flight_waypoints(up, first, offset)
	_append_landing_turn(up, turn, first, second, offset)
	_append_flight_waypoints(up, second, offset)
	var arrival_rect: Array = arrival.get("rect", [])
	up.append(_plan_point((float(arrival_rect[0]) + float(arrival_rect[2])) * 0.5,
			(float(arrival_rect[1]) + float(arrival_rect[3])) * 0.5,
			float(arrival.get("z", 0.0)) + offset))
	var f02_hall_x := (float(f02_hall[0]) + float(f02_hall[2])) * 0.5
	var f02_hall_y := (float(f02_hall[1]) + float(f02_hall[3])) * 0.5
	var f02_atrium_x := (float(f02_atrium[0]) + float(f02_atrium[2])) * 0.5
	var f02_atrium_south_y := float(f02_atrium[1])
	var f02_atrium_depth := float(f02_atrium[3]) - f02_atrium_south_y
	up.append(_plan_point(f02_atrium_x,
			f02_atrium_south_y + f02_atrium_depth * 0.1,
			float(arrival.get("z", 0.0)) + offset))
	up.append(_plan_point(f02_hall_x, f02_hall_y,
			float(arrival.get("z", 0.0)) + offset))
	var connector := await _walk_waypoints(player, entry_path, {},
			"lobby_to_public_core")
	var ascent := await _walk_waypoints(player, up, {}, "f01_to_f02_public_stair")
	var down: Array[Vector3] = up.duplicate()
	down.reverse()
	down.append(entry_path[entry_path.size() - 1])
	var descent := await _walk_waypoints(player, down, {}, "f02_to_f01_public_stair")
	var return_path: Array[Vector3] = entry_path.duplicate()
	return_path.reverse()
	var return_to_hall := await _walk_waypoints(player, return_path, {},
			"public_core_to_f01_hall")
	var elevator: Dictionary = _layout.get("elevator", {})
	var stops: Dictionary = elevator.get("stops", {})
	var elevator_contract := stops.has("F01") and stops.has("F02") \
			and is_equal_approx(float(stops.F01), 0.0) \
			and float(elevator.get("door_w", 0.0)) >= PlayerController.BODY_RADIUS * 2.0
	var ok := bool(connector.get("reached", false)) \
			and bool(ascent.get("reached", false)) \
			and bool(descent.get("reached", false)) \
			and bool(return_to_hall.get("reached", false)) and elevator_contract
	return {
		"status": "PASS" if ok else "FAIL",
		"source": PROD_LAYOUT_PATH,
		"derived_without_embedded_coordinates": true,
		"connector": connector,
		"ascent": ascent,
		"descent": descent,
		"return_to_hall": return_to_hall,
		"elevator_f01_f02_contract": elevator_contract,
	}


func _room_rect(floor_id: String, room_id: String) -> Array:
	for raw_floor: Variant in _layout.get("floors", []):
		if raw_floor is not Dictionary or str(raw_floor.get("id", "")) != floor_id:
			continue
		for raw_room: Variant in raw_floor.get("rooms", []):
			if raw_room is Dictionary and str(raw_room.get("id", "")) == room_id:
				return (raw_room.get("rect", []) as Array).duplicate()
	return []


## A fresh invocation owns a fresh directory. Never reopen the historical
## fixed filenames: missing primary + backup is a production recovery decision.
func _prepare_save_directory() -> bool:
	if not _save_directory.is_empty(): return false
	var parent := ProjectSettings.globalize_path("user://tests/m11c2_runs")
	if DirAccess.make_dir_recursive_absolute(parent) != OK: return false
	var token := "%d_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec(), get_instance_id()]
	var directory := parent.path_join(token)
	if DirAccess.dir_exists_absolute(directory) or FileAccess.file_exists(directory): return false
	if DirAccess.make_dir_absolute(directory) != OK: return false
	if not DirAccess.get_files_at(directory).is_empty() or not DirAccess.get_directories_at(directory).is_empty(): return false
	_save_directory = directory
	_receipt["save_fixture_directory"] = directory
	return true


func _claim_save_bundle(save_mode: String, reconstruction_mode: String) -> String:
	if save_mode not in MODES or reconstruction_mode not in MODES: return ""
	if _save_directory.is_empty() and not _prepare_save_directory(): return ""
	var path := _save_directory.path_join("%s_to_%s.json" % [save_mode, reconstruction_mode])
	if _save_bundles.has(path): return ""
	for suffix: String in SAVE_BUNDLE_SUFFIXES:
		if FileAccess.file_exists(path + suffix) or DirAccess.dir_exists_absolute(path + suffix): return ""
	_save_bundles[path] = {"cleanup_allowed":false}
	return path


func _save_bundle_evidence(path: String, passed: bool) -> Dictionary:
	if not _save_bundles.has(path) or path.get_base_dir() != _save_directory:
		return {"ok":false,"reason":"unowned save bundle"}
	_save_bundles[path].cleanup_allowed = passed
	var files: Array[Dictionary] = []
	for suffix: String in SAVE_BUNDLE_SUFFIXES:
		var artifact := path + suffix
		if FileAccess.file_exists(artifact):
			files.append({"path":artifact,"bytes":FileAccess.get_file_as_bytes(artifact).size(),
				"sha256":FileAccess.get_sha256(artifact)})
	return {"ok":true,"path":path,"directory":_save_directory,"files":files,
		"preserved_on_failure":not passed,"cleanup_after_receipt":passed}


func _cleanup_successful_save_bundles() -> Dictionary:
	var removed: Array[String] = []
	var failures: Array[String] = []
	for path: String in _save_bundles:
		if not bool(_save_bundles[path].cleanup_allowed): continue
		if path.get_base_dir() != _save_directory:
			failures.append("unowned path: " + path)
			continue
		for suffix: String in SAVE_BUNDLE_SUFFIXES:
			var artifact := path + suffix
			if not FileAccess.file_exists(artifact): continue
			if DirAccess.remove_absolute(artifact) == OK: removed.append(artifact)
			else: failures.append(artifact)
	# Unknown artifacts and every failed bundle survive. Only an empty directory
	# created by this invocation can be retired; no recursive deletion is used.
	if not _save_directory.is_empty() and DirAccess.get_files_at(_save_directory).is_empty() \
			and DirAccess.get_directories_at(_save_directory).is_empty():
		if DirAccess.remove_absolute(_save_directory) != OK: failures.append(_save_directory)
	return {"ok":failures.is_empty(),"removed":removed,"failures":failures}


func _campaign_reconstruction(save_mode: String,
		reconstruction_mode: String) -> Dictionary:
	var old_path := RealityState.save_path
	var old_persistence := RealityState.persistence_enabled
	var transaction_id := "%s_to_%s" % [save_mode, reconstruction_mode]
	var save_path := _claim_save_bundle(save_mode, reconstruction_mode)
	if save_path.is_empty():
		return {"status":"FAIL","transaction_id":transaction_id,
			"reason":"fresh save bundle could not be claimed","reconstruction_attempted":false,
			"last_save_result":{},"load_status":{"status":"not_attempted"}}
	RealityState.save_path = save_path
	_prepare_campaign_facts()
	# _prepare_campaign_facts deliberately disables writes while it resets the
	# singleton.  Enable persistence only after that reset so this is a real
	# disk save, not an in-memory reconstruction proxy.
	RealityState.persistence_enabled = true
	var save_configuration_selected := bool(_configuration.call(
			"set_for_tests", save_mode))
	Selector.reset_for_tests("v1")
	var before := Support.object_counts()
	var origin_started := Time.get_ticks_usec()
	var origin := CampaignShell.new()
	var origin_weak: WeakRef = weakref(origin)
	add_child(origin)
	await _settle_root()
	var origin_compose_ms := _elapsed_ms(origin_started)
	var origin_world: Node = origin.active_world
	var origin_world_weak: WeakRef = weakref(origin_world) \
			if origin_world != null else null
	var origin_mode := str(origin_world.call("active_floor01_geometry_mode")) \
			if origin_world != null and origin_world.has_method(
					"active_floor01_geometry_mode") else ""
	# Validate and establish the same public service boundary before writing.
	# The reconstructed root must then observe those saved semantic facts; it
	# cannot manufacture them after load to make the comparison pass.
	var origin_contract := _root_contract(origin_world, save_mode) \
			if origin_world != null else {"status": "FAIL"}
	var save_started := Time.get_ticks_usec()
	var saved := RealityState.save_game()
	var save_result := RealityState.last_save_result()
	var origin_load_status := RealityState.load_status()
	var save_ms := _elapsed_ms(save_started)
	var save_text := FileAccess.get_file_as_string(save_path) if saved else ""
	var save_bytes := save_text.to_utf8_buffer().size()
	var forbidden := _forbidden_save_fact(JSON.parse_string(save_text), "save") \
			if saved else "save was not written"
	var origin_resource_watch := _geometry_resource_watch(
			origin_world.call("floor01_geometry_registry") \
			if origin_world != null and origin_world.has_method(
					"floor01_geometry_registry") else null)
	var origin_teardown: Dictionary = origin.teardown_active_world()
	await _settle_teardown(3)
	var origin_resource_release := _resource_release_receipt(
			origin_resource_watch)
	# The production CampaignShell boundary has already queued and detached its
	# active world after public F01 teardown. Retire the empty shell at the same
	# safe frame boundary.
	origin.queue_free()
	origin = null
	origin_world = null
	await _settle_teardown(6)
	var origin_released := origin_weak.get_ref() == null \
			and (origin_world_weak == null or origin_world_weak.get_ref() == null)
	# A refused write has no new generation to reconstruct. Retire the origin
	# above, preserve its bundle, and never recover an older file as this proof.
	if not saved or not forbidden.is_empty() or str(origin_contract.get("status", "FAIL")) != "PASS":
		var bundle := _save_bundle_evidence(save_path, false)
		RealityState.save_path = old_path
		RealityState.persistence_enabled = old_persistence
		return {"status":"FAIL","transaction_id":transaction_id,
			"save_mode":save_mode,"reconstruction_mode":reconstruction_mode,
			"saved":saved,"last_save_result":save_result,"origin_load_status":origin_load_status,
			"forbidden_save_fact":forbidden,"origin_world_contract":origin_contract,
			"origin_shell_released":origin_released,"origin_public_teardown":origin_teardown,
			"origin_production_cut_resource_release":origin_resource_release,
			"reconstruction_attempted":false,"reason":"origin save boundary failed",
			"load_status":{"status":"not_attempted","reason":"origin save boundary failed"},
			"save_bundle":bundle,"performance":{"save_ms":save_ms,"save_bytes":save_bytes}}
	# The geometry choice is intentionally changed after the saved root is
	# destroyed and before CampaignShell reconstructs it.  A passing cross-mode
	# row therefore proves that provider identity is session authority rather
	# than a hidden durable save fact.
	var reconstruction_configuration_selected := bool(_configuration.call(
			"set_for_tests", reconstruction_mode))
	RealityState.reset_campaign_for_tests()
	var load_started := Time.get_ticks_usec()
	RealityState.load_game()
	var load_status := RealityState.load_status()
	var state_load_ms := _elapsed_ms(load_started)
	if str(load_status.get("status", "")) != "loaded" or RealityState.save_write_blocked:
		var bundle := _save_bundle_evidence(save_path, false)
		RealityState.save_path = old_path
		RealityState.persistence_enabled = old_persistence
		return {"status":"FAIL","transaction_id":transaction_id,
			"saved":saved,"last_save_result":save_result,"origin_load_status":origin_load_status,
			"load_status":load_status,"reconstruction_attempted":false,
			"reason":"saved generation did not load directly","save_bundle":bundle,
			"origin_shell_released":origin_released,"origin_public_teardown":origin_teardown,
			"origin_production_cut_resource_release":origin_resource_release}
	var reconstruct_started := Time.get_ticks_usec()
	var shell := CampaignShell.new()
	var shell_weak: WeakRef = weakref(shell)
	add_child(shell)
	await _settle_root()
	var reconstruct_compose_ms := _elapsed_ms(reconstruct_started)
	var reconstructed: Node = shell.active_world
	var reconstructed_world_weak: WeakRef = weakref(reconstructed) \
			if reconstructed != null else null
	var reconstructed_mode := str(reconstructed.call(
			"active_floor01_geometry_mode")) if reconstructed != null \
			and reconstructed.has_method("active_floor01_geometry_mode") else ""
	var shift: Dictionary = RealityState.data.get("first_shift", {})
	var loop: Dictionary = RealityState.data.get("core_loop", {})
	var facts_ok := str(shift.get("phase", "")) == FirstShiftDirector.PHASE_COMPLETE \
			and str(shift.get("report_id", "")) == ChirpHunt.JOB_ID \
			and str(shift.get("filing", "")) == "fault_corrected" \
			and str(loop.get("safe_return_anchor", "")) == "F04_B_BED" \
			and str(loop.get("boundary", "")) == "wake_complete"
	var world_contract := _root_contract(reconstructed, reconstruction_mode) \
			if reconstructed != null else {"status": "FAIL"}
	var origin_semantic: Dictionary = origin_contract.get("semantic_world", {})
	var reconstructed_semantic: Dictionary = world_contract.get(
			"semantic_world", {})
	var semantic_world_equal := not origin_semantic.is_empty() \
			and _canonical_json(origin_semantic) \
			== _canonical_json(reconstructed_semantic)
	var reconstructed_resource_watch := _geometry_resource_watch(
			reconstructed.call("floor01_geometry_registry") \
			if reconstructed != null and reconstructed.has_method(
					"floor01_geometry_registry") else null)
	var reconstructed_teardown: Dictionary = shell.teardown_active_world()
	await _settle_teardown(3)
	var reconstructed_resource_release := _resource_release_receipt(
			reconstructed_resource_watch)
	shell.queue_free()
	shell = null
	reconstructed = null
	await _settle_teardown(6)
	var shell_released := shell_weak.get_ref() == null \
			and (reconstructed_world_weak == null \
					or reconstructed_world_weak.get_ref() == null)
	var after := Support.object_counts()
	var delta := Support.object_delta(after, before)
	var no_node_or_orphan_growth := int(delta.get("nodes", 0)) <= 0 \
			and int(delta.get("orphan_nodes", 0)) <= 0
	var no_retained_cut_resources := bool(origin_resource_release.get(
			"ok", false)) and bool(reconstructed_resource_release.get(
					"ok", false))
	var focused_lifecycle_clean := no_node_or_orphan_growth \
			and no_retained_cut_resources \
			and _teardown_receipt_zero(origin_teardown) \
			and _teardown_receipt_zero(reconstructed_teardown)
	var ok := save_configuration_selected and reconstruction_configuration_selected \
			and origin_mode == save_mode \
			and str(origin_contract.get("status", "FAIL")) == "PASS" \
			and saved and forbidden.is_empty() \
			and origin_released and reconstructed_mode == reconstruction_mode \
			and facts_ok and semantic_world_equal \
			and str(world_contract.get("status", "FAIL")) == "PASS" \
			and shell_released and focused_lifecycle_clean \
			and str(_configuration.call("selected_mode")) == reconstruction_mode
	var save_bundle := _save_bundle_evidence(save_path, ok)
	RealityState.save_path = old_path
	RealityState.persistence_enabled = old_persistence
	return {
		"status": "PASS" if ok else "FAIL",
		"transaction_id": transaction_id,
		"save_mode": save_mode,
		"reconstruction_mode": reconstruction_mode,
		"cross_mode": save_mode != reconstruction_mode,
		"selector_id": Selector.selected_id(),
		"origin_mode": origin_mode,
		"origin_world_contract": origin_contract,
		"reconstructed_mode": reconstructed_mode,
		"save_configuration_selected": save_configuration_selected,
		"reconstruction_configuration_selected":
				reconstruction_configuration_selected,
		"session_configuration_survived_replacement":
				str(_configuration.call("selected_mode")) == reconstruction_mode,
		"provider_identity_absent_from_save": forbidden.is_empty(),
		"saved": saved,
		"last_save_result": save_result,
		"origin_load_status": origin_load_status,
		"load_status": load_status,
		"reconstruction_attempted": true,
		"save_bundle": save_bundle,
		"performance": {
			"origin_campaign_shell_compose_ms": origin_compose_ms,
			"save_ms": save_ms,
			"save_bytes": save_bytes,
			"state_load_ms": state_load_ms,
			"reconstructed_campaign_shell_compose_ms": reconstruct_compose_ms,
		},
		"forbidden_save_fact": forbidden,
		"semantic_facts_reconstructed": facts_ok,
		"semantic_world_equal_across_transaction": semantic_world_equal,
		"origin_semantic_sha256": _canonical_json(origin_semantic).sha256_text(),
		"reconstructed_semantic_sha256": _canonical_json(
				reconstructed_semantic).sha256_text(),
		"world_contract": world_contract,
		"origin_shell_released": origin_released,
		"reconstructed_shell_released": shell_released,
		"origin_public_teardown": origin_teardown,
		"reconstructed_public_teardown": reconstructed_teardown,
		"origin_production_cut_resource_release": origin_resource_release,
		"reconstructed_production_cut_resource_release":
				reconstructed_resource_release,
		"process_delta": delta,
		"no_retained_production_cut_resources_nodes_or_orphans":
				focused_lifecycle_clean,
		"aggregate_object_resource_delta_observational": true,
	}


func _matched_performance_comparison() -> Dictionary:
	var summaries: Dictionary = {}
	for mode: String in ["legacy_monolith", "owner_first_cells"]:
		var rows: Array = _mode_cycles.get(mode, [])
		var accumulators := {
			"load_ms": 0.0,
			"instantiate_ms": 0.0,
			"ready_and_settle_ms": 0.0,
			"first_interaction_ms": 0.0,
			"process_ms": 0.0,
			"physics_process_ms": 0.0,
			"draw_calls": 0.0,
			"nodes": 0.0,
			"mesh_instances": 0.0,
			"collision_objects": 0.0,
			"collision_shapes": 0.0,
		}
		var count := 0
		var gpu_values: Array[float] = []
		var vram_values: Array[float] = []
		for raw: Variant in rows:
			if raw is not Dictionary or not bool(raw.get("measured", false)):
				continue
			var performance: Dictionary = raw.get("performance", {})
			var engine: Dictionary = performance.get("engine", {})
			var tree: Dictionary = performance.get("tree", {})
			for key: String in ["load_ms", "instantiate_ms",
					"ready_and_settle_ms", "first_interaction_ms"]:
				accumulators[key] = float(accumulators[key]) \
						+ float(performance.get(key, 0.0))
			for key: String in ["process_ms", "physics_process_ms", "draw_calls"]:
				accumulators[key] = float(accumulators[key]) \
						+ float(engine.get(key, 0.0))
			for key: String in ["nodes", "mesh_instances", "collision_objects",
					"collision_shapes"]:
				accumulators[key] = float(accumulators[key]) \
						+ float(tree.get(key, 0.0))
			if bool(engine.get("gpu_timing_trustworthy", false)):
				gpu_values.append(float(engine.get("gpu_ms", 0.0)))
			if bool(engine.get("vram_trustworthy", false)):
				vram_values.append(float(engine.get("vram_bytes", 0.0)))
			count += 1
		var average: Dictionary = {}
		for key: String in accumulators:
			average[key] = float(accumulators[key]) / maxf(1.0, float(count))
		average["gpu_ms"] = _mean(gpu_values) if not gpu_values.is_empty() else null
		average["gpu_timing_trustworthy"] = not gpu_values.is_empty()
		average["vram_bytes"] = _mean(vram_values) \
				if not vram_values.is_empty() else null
		average["vram_trustworthy"] = not vram_values.is_empty()
		average["measured_cycle_count"] = count
		summaries[mode] = average
	var legacy: Dictionary = summaries.get("legacy_monolith", {})
	var cells: Dictionary = summaries.get("owner_first_cells", {})
	var delta: Dictionary = {}
	for key: String in ["load_ms", "instantiate_ms", "ready_and_settle_ms",
			"first_interaction_ms", "process_ms", "physics_process_ms",
			"draw_calls", "nodes", "mesh_instances", "collision_objects",
			"collision_shapes"]:
		delta[key] = float(cells.get(key, 0.0)) - float(legacy.get(key, 0.0))
	if bool(legacy.get("gpu_timing_trustworthy", false)) \
			and bool(cells.get("gpu_timing_trustworthy", false)):
		delta["gpu_ms"] = float(cells.gpu_ms) - float(legacy.gpu_ms)
	else:
		delta["gpu_ms"] = null
	if bool(legacy.get("vram_trustworthy", false)) \
			and bool(cells.get("vram_trustworthy", false)):
		delta["vram_bytes"] = float(cells.vram_bytes) - float(legacy.vram_bytes)
	else:
		delta["vram_bytes"] = null
	return {
		"profile": "same process, root, renderer, fixed simulation facts, warm cache",
		"legacy_monolith": legacy,
		"owner_first_cells": cells,
		"cells_minus_legacy": delta,
		"gpu_or_vram_not_inferred_when_unavailable": true,
	}


func _mean(values: Array[float]) -> float:
	var total := 0.0
	for value: float in values:
		total += value
	return total / maxf(1.0, float(values.size()))


func _prepare_campaign_facts() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	RealityState.data.intro_complete = true
	RealityState.data.first_shift = {
		"phase": FirstShiftDirector.PHASE_COMPLETE,
		"report_id": ChirpHunt.JOB_ID,
		"filing": "fault_corrected",
	}
	RealityState.data.core_loop = {
		"safe_return_anchor": "F04_B_BED",
		"boundary": "wake_complete",
	}
	var fixed_clock := CampaignClock.new()
	if not fixed_clock.configure_start("mon", 243, PROOF_MINUTE):
		_fail("public CampaignClock refused deterministic M11C2 trading hour")


func _first_interaction_prompt(root: Node) -> String:
	for detector: Node in root.find_children(
			"F01_WATCHMAN_DETECTOR", "", true, false):
		if detector.has_method("control_prompt"):
			return str(detector.call("control_prompt", "detector"))
	for bodega: Node in root.find_children("F01_BODEGA_DOOR", "", true, false):
		if bodega.has_method("interact_prompt"):
			return str(bodega.call("interact_prompt"))
	return ""


func _open_public_door(root: Node, identity: String, player: PlayerController,
		expect_locked: bool) -> Dictionary:
	if identity.is_empty():
		return {"ok": true, "identity": "", "action": "none"}
	var matches := root.find_children(identity, "", true, false)
	var interactables: Array[Node] = []
	for candidate: Node in matches:
		if candidate.has_method("interact"):
			interactables.append(candidate)
	if interactables.size() != 1:
		return {"ok": false, "identity": identity,
				"reason": "public door must resolve exactly once",
				"matching_interactable_count": interactables.size(),
				"all_name_matches": matches.size()}
	var door: Node = interactables[0]
	var was_open := bool(door.get("open"))
	var interaction_called := false
	var settle_physics_frames := 0
	var settle_wall_ms := 0.0
	var settle_simulated_seconds := 0.0
	if not was_open or expect_locked:
		interaction_called = true
		var settle_started := Time.get_ticks_usec()
		door.call("interact", player)
		var physics_ticks := maxi(1, Engine.physics_ticks_per_second)
		settle_physics_frames = mini(120,
				maxi(1, ceili(DOOR_PHYSICAL_SETTLE_SECONDS * physics_ticks)))
		for _frame: int in settle_physics_frames:
			await get_tree().physics_frame
		settle_wall_ms = _elapsed_ms(settle_started)
		settle_simulated_seconds = float(settle_physics_frames) \
				/ float(physics_ticks)
	var is_open := bool(door.get("open"))
	var leaf_state := str(door.get("leaf_state"))
	var ok := (not is_open and leaf_state == "locked") if expect_locked else is_open
	return {"ok": ok, "identity": identity, "class": door.get_class(),
			"was_open": was_open, "open_after": is_open,
			"leaf_state_after": leaf_state, "public_interact": true,
			"interaction_called": interaction_called,
			"physical_settle_required_seconds": DOOR_PHYSICAL_SETTLE_SECONDS,
			"physical_settle_physics_frames": settle_physics_frames,
			"physical_settle_simulated_seconds": settle_simulated_seconds,
			"physical_settle_wall_ms": settle_wall_ms,
			"matching_interactable_count": interactables.size(),
			"all_name_matches": matches.size()}


func _walk_to(player: PlayerController, target: Vector3, spec: Dictionary,
		label: String, expect_blocked := false) -> Dictionary:
	return await _walk_waypoints(player, [target], spec, label, expect_blocked)


func _walk_semantic_seam_chain(player: PlayerController, raw_sublegs: Array,
		label: String) -> Dictionary:
	var reached_all := not raw_sublegs.is_empty()
	var sublegs: Array[Dictionary] = []
	for index: int in raw_sublegs.size():
		var raw: Variant = raw_sublegs[index]
		if raw is not Dictionary:
			reached_all = false
			sublegs.append({"index": index, "reached": false,
					"reason": "semantic subleg is not a dictionary"})
			break
		var subleg: Dictionary = raw
		var authority_id := str(subleg.get("authority_id", ""))
		var endpoint_role := str(subleg.get("endpoint_role", ""))
		var record: Dictionary = subleg.get("record", {}) as Dictionary
		var raw_endpoint: Variant = record.get(endpoint_role)
		var endpoint_valid := not authority_id.is_empty() \
				and endpoint_role == "start" and raw_endpoint is Array \
				and (raw_endpoint as Array).size() == 3
		var target := Support.vector3(raw_endpoint) if endpoint_valid else Vector3.INF
		endpoint_valid = endpoint_valid and target.is_finite()
		var authority_payload := {
			"seam_id": authority_id,
			"traversal_id": str(record.get("id", "")),
			"record": record,
		}
		var authority_sha256 := _canonical_json(authority_payload).sha256_text()
		var endpoint_sha256 := _canonical_json(raw_endpoint).sha256_text() \
				if endpoint_valid else ""
		var movement: Dictionary
		if endpoint_valid:
			movement = await _walk_to(player, target, record,
					"%s_%02d" % [label, index + 1])
		else:
			movement = {"reached": false,
					"reason": "invalid semantic endpoint record"}
		var reached := endpoint_valid and bool(movement.get("reached", false))
		sublegs.append({
			"index": index,
			"reached": reached,
			"authority_id": authority_id,
			"traversal_id": str(record.get("id", "")),
			"endpoint_role": endpoint_role,
			"relationship": str(subleg.get("relationship", "")),
			"authority_sha256": authority_sha256,
			"endpoint_sha256": endpoint_sha256,
			"source_contract_sha256": M11C1_CONFIG_LF_SHA256,
			"endpoint_coordinates_recorded": false,
			"movement": _coordinate_free_movement_receipt(movement),
		})
		if not reached:
			reached_all = false
			break
	return {
		"id": label,
		"reached": reached_all,
		"authority": "immutable M11C1 semantic seam endpoints",
		"source_contract": M11C1_CONFIG_PATH,
		"source_contract_sha256": M11C1_CONFIG_LF_SHA256,
		"endpoint_coordinates_recorded": false,
		"subleg_count": sublegs.size(),
		"sublegs": sublegs,
	}


func _coordinate_free_movement_receipt(movement: Dictionary) -> Dictionary:
	return {
		"reached": bool(movement.get("reached", false)),
		"physics_frames": int(movement.get("physics_frames", 0)),
		"path_distance_m": float(movement.get("path_distance_m", 0.0)),
		"grounded_fraction": float(movement.get("grounded_fraction", 0.0)),
		"noclip": bool(movement.get("noclip", false)),
		"collision_layer": int(movement.get("collision_layer", 0)),
		"collision_mask": int(movement.get("collision_mask", 0)),
		"coordinate_fields_omitted": true,
	}


func _walk_waypoints(player: PlayerController, waypoints: Array[Vector3],
		spec: Dictionary, label: String, expect_blocked := false) -> Dictionary:
	var tolerance := float(spec.get("waypoint_tolerance_m", 0.16))
	var vertical_tolerance := float(spec.get("vertical_tolerance_m", 0.24))
	var samples := 0
	var grounded := 0
	var path_distance := 0.0
	var rows: Array[Dictionary] = []
	var reached_all := true
	var slide_colliders: Dictionary = {}
	var slide_collision_samples := 0
	for target: Vector3 in waypoints:
		var start := player.global_position
		var frames := 0
		var distance := _planar_distance(start, target)
		var max_frames := maxi(int(spec.get("max_frames_per_waypoint", 420)),
				int(ceil(distance * 48.0)) + 180)
		if expect_blocked:
			max_frames = mini(max_frames, 180)
		while not _point_reached(player.global_position, target, tolerance,
				vertical_tolerance) and frames < max_frames:
			var delta := target - player.global_position
			delta.y = 0.0
			player.autopilot = delta.normalized() \
					if delta.length_squared() > 0.0001 else Vector3.ZERO
			var previous := player.global_position
			await get_tree().physics_frame
			path_distance += previous.distance_to(player.global_position)
			slide_collision_samples += _collect_slide_collisions(player,
					slide_colliders)
			frames += 1
			samples += 1
			if player.is_on_floor():
				grounded += 1
		var reached := _point_reached(player.global_position, target, tolerance,
				vertical_tolerance)
		rows.append({"target": Support.vector3_array(target),
				"finish": Support.vector3_array(player.global_position),
				"frames": frames, "reached": reached})
		if not reached:
			reached_all = false
			break
	player.autopilot = Vector3.ZERO
	await get_tree().physics_frame
	var grounded_fraction := float(grounded) / maxf(1.0, float(samples))
	var collision_rows := _sorted_slide_collision_rows(slide_colliders)
	print("[M11C2-ROUTE] %s reached=%s samples=%d grounded=%.4f finish=%s" % [
			label, str(reached_all), samples, grounded_fraction,
			str(Support.vector3_array(player.global_position))])
	if not reached_all:
		print("[M11C2-ROUTE-COLLISIONS] %s %s" % [label,
				JSON.stringify(collision_rows)])
	return {
		"id": label,
		"reached": reached_all and grounded_fraction >= 0.90,
		"expected_blocked": expect_blocked,
		"waypoints": rows,
		"physics_frames": samples,
		"path_distance_m": path_distance,
		"grounded_fraction": grounded_fraction,
		"noclip": player.noclip,
		"collision_layer": player.collision_layer,
		"collision_mask": player.collision_mask,
		"unique_slide_collision_collider_count": collision_rows.size(),
		"slide_collision_sample_count": slide_collision_samples,
		"slide_collision_colliders": collision_rows,
	}


func _collect_slide_collisions(player: PlayerController,
		colliders: Dictionary) -> int:
	var samples := 0
	for collision_index: int in player.get_slide_collision_count():
		var collision: KinematicCollision3D = player.get_slide_collision(
				collision_index)
		if collision == null:
			continue
		var collider: Object = collision.get_collider()
		var collider_node := collider as Node
		var collider_path := str(collider_node.get_path()) \
				if collider_node != null and collider_node.is_inside_tree() else ""
		var collider_class := collider.get_class() if collider != null else ""
		var collider_name := str(collider_node.name) if collider_node != null else ""
		var key := "%s|%s|%s" % [collider_path, collider_class, collider_name]
		var normal := collision.get_normal()
		var position := collision.get_position()
		var row: Dictionary = colliders.get(key, {
			"collider_path": collider_path,
			"collider_class": collider_class,
			"collider_name": collider_name,
			"first_normal": Support.vector3_array(normal),
			"first_position": Support.vector3_array(position),
			"sample_count": 0,
		}) as Dictionary
		row["sample_count"] = int(row.get("sample_count", 0)) + 1
		row["last_normal"] = Support.vector3_array(normal)
		row["last_position"] = Support.vector3_array(position)
		colliders[key] = row
		samples += 1
	return samples


func _sorted_slide_collision_rows(colliders: Dictionary) -> Array[Dictionary]:
	var keys: Array[String] = []
	for raw_key: Variant in colliders:
		keys.append(str(raw_key))
	keys.sort()
	var rows: Array[Dictionary] = []
	for key: String in keys:
		rows.append((colliders.get(key, {}) as Dictionary).duplicate(true))
	return rows


func _settle_player(player: PlayerController) -> void:
	for _index in 45:
		player.autopilot = Vector3.ZERO
		await get_tree().physics_frame
		if player.is_on_floor():
			return


func _point_reached(at: Vector3, target: Vector3, horizontal: float,
		vertical: float) -> bool:
	return _planar_distance(at, target) <= horizontal \
			and absf(at.y - target.y) <= vertical


func _planar_distance(first: Vector3, second: Vector3) -> float:
	return Vector2(first.x, first.z).distance_to(Vector2(second.x, second.z))


func _crossed_between(first: Vector3, second: Vector3, raw_plane: Variant) -> bool:
	if raw_plane is not Dictionary:
		return false
	var point := Support.vector3(raw_plane.get("point", []))
	var normal := Support.vector3(raw_plane.get("normal", [])).normalized()
	if not point.is_finite() or not normal.is_finite() or normal.is_zero_approx():
		return false
	var a := (first - point).dot(normal)
	var b := (second - point).dot(normal)
	return a * b < 0.0 and absf(a) >= 0.15 and absf(b) >= 0.15


func _append_flight_waypoints(out: Array[Vector3], flight: Dictionary,
		offset: float) -> void:
	var n := int(flight.get("n", 0))
	var rise := float(flight.get("rise", 0.0))
	var tread := float(flight.get("tread", 0.0))
	var start := float(flight.get("start", 0.0))
	var direction := float(flight.get("dir", 0.0))
	var x := (float(flight.get("b0", 0.0)) \
			+ float(flight.get("b1", 0.0))) * 0.5
	var z0 := float(flight.get("z0", 0.0))
	for index in range(1, n):
		out.append(_plan_point(x, start + direction * float(index) * tread,
				z0 + float(index) * rise + offset))


func _append_landing_turn(out: Array[Vector3], landing: Dictionary,
		first: Dictionary, second: Dictionary, offset: float) -> void:
	var rect: Array = landing.get("rect", [])
	var y := (float(rect[1]) + float(rect[3])) * 0.5
	var first_x := (float(first.get("b0", 0.0)) \
			+ float(first.get("b1", 0.0))) * 0.5
	var second_x := (float(second.get("b0", 0.0)) \
			+ float(second.get("b1", 0.0))) * 0.5
	var height := float(landing.get("z", 0.0)) + offset
	out.append(_plan_point(first_x, y, height))
	out.append(_plan_point(second_x, y, height))
	out.append(_plan_point(second_x, float(second.get("start", 0.0)), height))


func _flight_start(flight: Dictionary, offset: float) -> Vector3:
	return _plan_point((float(flight.get("b0", 0.0)) \
			+ float(flight.get("b1", 0.0))) * 0.5,
			float(flight.get("start", 0.0)),
			float(flight.get("z0", 0.0)) + offset)


func _plan_point(x: float, plan_y: float, height: float) -> Vector3:
	return Vector3(x, height, -plan_y)


func _route_ground_offset() -> float:
	var seam := _traversal(_seams_by_id(),
			"SEAM_ORISON_SOUTH_SHELL_STREET", 0)
	return Support.vector3(seam.get("start", [])).y


func _seams_by_id() -> Dictionary:
	var result: Dictionary = {}
	for raw: Variant in _m11c1.get("seams", []):
		if raw is Dictionary:
			result[str(raw.get("id", ""))] = raw
	return result


func _traversal(seams: Dictionary, seam_id: String, index: int) -> Dictionary:
	var seam: Dictionary = seams.get(seam_id, {})
	var rows: Array = seam.get("traversals", [])
	return rows[index] as Dictionary if index >= 0 and index < rows.size() \
			and rows[index] is Dictionary else {}


func _required_cell_ids() -> Array[String]:
	var result: Array[String] = []
	var save: Dictionary = _m11c1.get("save_reconstruction", {})
	for raw: Variant in save.get("required_cell_ids", []):
		result.append(str(raw))
	return result


func _collect_scene_sources(node: Node, out: Array[String]) -> void:
	var source := str(node.scene_file_path)
	if not source.is_empty() and source not in out:
		out.append(source)
	for child: Node in node.get_children():
		_collect_scene_sources(child, out)


func _recursive_truth(value: Variant, keys: Array[String]) -> bool:
	if value is Dictionary:
		for key: Variant in value:
			if str(key) in keys and bool(value[key]):
				return true
			if _recursive_truth(value[key], keys):
				return true
	elif value is Array:
		for item: Variant in value:
			if _recursive_truth(item, keys):
				return true
	return false


func _teardown_receipt_zero(receipt: Dictionary) -> bool:
	return bool(receipt.get("ok", false)) \
			and int(receipt.get("retained_instances", -1)) == 0 \
			and int(receipt.get("retained_resources", -1)) == 0 \
			and int(receipt.get("retained_strong_references", -1)) == 0


func _weakrefs_released(refs: Array[WeakRef]) -> bool:
	for item: WeakRef in refs:
		if item.get_ref() != null:
			return false
	return true


## Track the resources whose lifetime is actually owned by the selected F01
## provider.  Performance.OBJECT_COUNT and OBJECT_RESOURCE_COUNT are global
## process monitors: resident routines, audio caches and unrelated RefCounted
## work can change them while a route runs.  Weak references to every mounted
## mesh, collision shape and material give teardown an attributable boundary.
func _geometry_resource_watch(owner: Node,
		required_owner_meta: StringName = &"") -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if owner == null or not is_instance_valid(owner):
		return rows
	var seen := {}
	var nodes: Array[Node] = [owner]
	for candidate: Node in owner.find_children("*", "", true, false):
		nodes.append(candidate)
	for node: Node in nodes:
		var owner_id := _geometry_owner_identity(node, owner)
		if node is MeshInstance3D:
			var mesh_instance := node as MeshInstance3D
			_watch_resource(rows, seen, mesh_instance.mesh, owner_id, "mesh",
					required_owner_meta, str(node.get_path()))
			_watch_resource(rows, seen, mesh_instance.material_override,
					owner_id, "material_override", required_owner_meta,
					str(node.get_path()))
			_watch_resource(rows, seen, mesh_instance.material_overlay,
					owner_id, "material_overlay", required_owner_meta,
					str(node.get_path()))
			if mesh_instance.mesh != null:
				for surface_index in mesh_instance.mesh.get_surface_count():
					_watch_resource(rows, seen,
							mesh_instance.mesh.surface_get_material(surface_index),
							owner_id, "mesh_surface_material",
							required_owner_meta, str(node.get_path()))
			for surface_index in mesh_instance.get_surface_override_material_count():
				_watch_resource(rows, seen,
						mesh_instance.get_surface_override_material(surface_index),
						owner_id, "surface_override_material",
						required_owner_meta, str(node.get_path()))
		elif node is MultiMeshInstance3D:
			var multimesh_instance := node as MultiMeshInstance3D
			_watch_resource(rows, seen, multimesh_instance.multimesh,
					owner_id, "multimesh", required_owner_meta,
					str(node.get_path()))
			if multimesh_instance.multimesh != null:
				_watch_resource(rows, seen, multimesh_instance.multimesh.mesh,
						owner_id, "multimesh_mesh", required_owner_meta,
						str(node.get_path()))
		elif node is CollisionShape3D:
			_watch_resource(rows, seen, (node as CollisionShape3D).shape,
					owner_id, "collision_shape", required_owner_meta,
					str(node.get_path()))
	return rows


func _watch_resource(rows: Array[Dictionary], seen: Dictionary,
		candidate: Variant, owner_id: String, role: String,
		required_owner_meta: StringName, node_path: String) -> void:
	if candidate is not Resource:
		return
	var resource := candidate as Resource
	if required_owner_meta != &"" and not resource.has_meta(required_owner_meta):
		return
	var instance_id := resource.get_instance_id()
	if seen.has(instance_id):
		return
	seen[instance_id] = true
	rows.append({
		"weak": weakref(resource),
		"class": resource.get_class(),
		"owner": owner_id,
		"role": role,
		"node_path": node_path,
		"resource_name": resource.resource_name,
		"resource_path": resource.resource_path,
		"required_owner_meta": str(required_owner_meta),
	})


func _geometry_owner_identity(node: Node, boundary: Node) -> String:
	var cursor: Node = node
	while cursor != null:
		if cursor.has_meta(&"floor01_owner_cell"):
			return str(cursor.get_meta(&"floor01_owner_cell"))
		if str(cursor.get_meta(&"floor01_geometry_provider", "")) \
				== "legacy_monolith":
			return "LEGACY_MONOLITH"
		if cursor == boundary:
			break
		cursor = cursor.get_parent()
	return str(boundary.get_meta(&"floor01_geometry_provider", "F01_PROVIDER"))


func _resource_release_receipt(watch: Array[Dictionary]) -> Dictionary:
	var retained: Array[Dictionary] = []
	for row: Dictionary in watch:
		var item := row.get("weak") as WeakRef
		if item == null or item.get_ref() == null:
			continue
		retained.append({
			"class": str(row.get("class", "Resource")),
			"owner": str(row.get("owner", "F01_PROVIDER")),
			"role": str(row.get("role", "resource")),
			"node_path": str(row.get("node_path", "")),
			"resource_name": str(row.get("resource_name", "")),
			"resource_path": str(row.get("resource_path", "")),
			"required_owner_meta": str(row.get("required_owner_meta", "")),
		})
	return {
		"ok": not watch.is_empty() and retained.is_empty(),
		"tracked_count": watch.size(),
		"retained_count": retained.size(),
		"retained": retained,
		"owner_specific": true,
		"ownership_scope": "direct provider-owned Mesh, Material, Shape3D and MultiMesh resources",
		"shared_dependency_textures_and_shaders_excluded": true,
		"aggregate_process_monitor_used_as_owner_evidence": false,
	}


## M11A composes existing DoorProp and PlayerController implementations.  Some
## of their assigned materials are deliberately process-shared through MatLib;
## they are dependencies, not resources created or owned by the exterior
## module.  Classify every non-released watched resource so that only an exact
## MatLib identity may remain outside the module-owned release gate.
func _shared_dependency_disposition(watch: Array[Dictionary]) -> Dictionary:
	var shared: Array[Dictionary] = []
	var unexpected: Array[Dictionary] = []
	for row: Dictionary in watch:
		var item := row.get("weak") as WeakRef
		var resource := item.get_ref() as Resource if item != null else null
		if resource == null:
			continue
		var cache_key := _matlib_cache_key(resource)
		var record := {
			"class": resource.get_class(),
			"instance_id": resource.get_instance_id(),
			"node_path": str(row.get("node_path", "")),
			"role": str(row.get("role", "resource")),
		}
		if not cache_key.is_empty():
			record["owner"] = "MatLib._cache"
			record["cache_key"] = cache_key
			shared.append(record)
		else:
			record["owner"] = "UNRESOLVED"
			unexpected.append(record)
	var cache_ids: Array[int] = []
	for raw_key: Variant in MatLib._cache:
		var material: Variant = MatLib._cache[raw_key]
		if material is Resource:
			cache_ids.append((material as Resource).get_instance_id())
	cache_ids.sort()
	var shared_keys: Array[String] = []
	for record: Dictionary in shared:
		shared_keys.append(str(record.get("cache_key", "")))
	shared_keys.sort()
	var expected_keys: Array[String] = []
	for key: String in M11A_PROCESS_SHARED_MATLIB_KEYS:
		expected_keys.append(key)
	expected_keys.sort()
	return {
		"ok": unexpected.is_empty() and shared_keys == expected_keys,
		"classification": "PROCESS_SHARED_MATLIB",
		"shared_dependency_count": shared.size(),
		"shared_dependencies": shared,
		"shared_cache_keys": shared_keys,
		"expected_shared_cache_keys": expected_keys,
		"expected_shared_cache_keys_match": shared_keys == expected_keys,
		"unexpected_retained_count": unexpected.size(),
		"unexpected_retained": unexpected,
		"matlib_cache_size": MatLib._cache.size(),
		"matlib_cache_resource_ids": cache_ids,
		"module_owned_resources_are_gated_separately": true,
	}


func _shared_dependency_signature(disposition: Dictionary) -> Dictionary:
	var rows: Array[Dictionary] = []
	for raw: Variant in disposition.get("shared_dependencies", []):
		if raw is not Dictionary:
			continue
		var record := raw as Dictionary
		rows.append({
			"cache_key": str(record.get("cache_key", "")),
			"instance_id": int(record.get("instance_id", 0)),
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.cache_key) < str(b.cache_key))
	return {
		"classification": str(disposition.get("classification", "")),
		"resources": rows,
	}


func _matlib_cache_key(resource: Resource) -> String:
	for raw_key: Variant in MatLib._cache:
		if MatLib._cache[raw_key] == resource:
			return str(raw_key)
	return ""


func _forbidden_save_fact(value: Variant, path: String) -> String:
	if value is Dictionary:
		for raw_key: Variant in value:
			var key := str(raw_key)
			var lower := key.to_lower()
			if "floor01_geometry" in lower or "cell_registry" in lower \
					or lower in ["selector", "selector_id", "asset_path", "node_path",
					"world_position", "global_position", "coordinates"]:
				return "%s.%s" % [path, key]
			var child := _forbidden_save_fact(value[raw_key], "%s.%s" % [path, key])
			if not child.is_empty():
				return child
	elif value is Array:
		for index in value.size():
			var child := _forbidden_save_fact(value[index], "%s[%d]" % [path, index])
			if not child.is_empty():
				return child
	elif value is String:
		var text := str(value).to_lower()
		if text in ["legacy_monolith", "owner_first_cells"] \
				or "res://" in text or ".gltf" in text or ".bin" in text \
				or "cell_orison_" in text or "cell_shop_" in text:
			return path
	return ""


func _canonical_json(value: Variant) -> String:
	if value is Dictionary:
		var result: Dictionary = {}
		var keys: Array = value.keys()
		keys.sort_custom(func(a: Variant, b: Variant) -> bool:
			return str(a) < str(b))
		for key: Variant in keys:
			result[str(key)] = JSON.parse_string(_canonical_json(value[key]))
		return JSON.stringify(result)
	if value is Array:
		var result: Array = []
		for item: Variant in value:
			result.append(JSON.parse_string(_canonical_json(item)))
		return JSON.stringify(result)
	return JSON.stringify(value)


func _snapshot_globals() -> Dictionary:
	return {
		"reality_data": RealityState.data.duplicate(true),
		"save_path": RealityState.save_path,
		"persistence": RealityState.persistence_enabled,
		"save_write_blocked": RealityState.save_write_blocked,
		"incompatible_save_version": RealityState.incompatible_save_version,
		"acoustic_nodes": AcousticGraphData.nodes.duplicate(true),
		"daynight_present": OS.has_environment("DAYNIGHT"),
		"daynight": OS.get_environment("DAYNIGHT"),
		"daynight_force_present": OS.has_environment("DAYNIGHT_FORCE"),
		"daynight_force": OS.get_environment("DAYNIGHT_FORCE"),
	}


func _restore_globals(snapshot: Dictionary) -> void:
	if _configuration != null:
		_configuration.call("reset_for_tests")
	Selector.reset_for_tests()
	RealityState.data = (snapshot.get("reality_data", {}) as Dictionary).duplicate(true)
	RealityState.save_path = str(snapshot.get("save_path", RealityState.SAVE_PATH))
	RealityState.persistence_enabled = bool(snapshot.get("persistence", true))
	RealityState.save_write_blocked = bool(snapshot.get("save_write_blocked", false))
	RealityState.incompatible_save_version = int(snapshot.get(
			"incompatible_save_version", 0))
	AcousticGraphData.nodes = (snapshot.get("acoustic_nodes", {}) as Dictionary).duplicate(true)
	if bool(snapshot.get("daynight_present", false)):
		OS.set_environment("DAYNIGHT", str(snapshot.get("daynight", "")))
	else:
		OS.unset_environment("DAYNIGHT")
	if bool(snapshot.get("daynight_force_present", false)):
		OS.set_environment("DAYNIGHT_FORCE", str(snapshot.get(
				"daynight_force", "")))
	else:
		OS.unset_environment("DAYNIGHT_FORCE")


func _blocked_cycle(mode: String, cycle_id: String, reason: String) -> Dictionary:
	_fail("%s %s blocked: %s" % [mode, cycle_id, reason])
	return {"status": "BLOCKED", "mode": mode, "cycle_id": cycle_id,
			"reason": reason}


func _settle_root() -> void:
	# ResidentNav performs its collision validation after two physics frames;
	# compare providers only after that same public consumer has settled.
	for _index in 3:
		await get_tree().process_frame
		await get_tree().physics_frame
	await get_tree().process_frame


func _settle(frames: int) -> void:
	for _index in frames:
		await get_tree().process_frame


func _settle_teardown(frames: int) -> void:
	for _index in frames:
		await get_tree().physics_frame
		await get_tree().process_frame


func _elapsed_ms(started_usec: int) -> float:
	return float(Time.get_ticks_usec() - started_usec) / 1000.0


func _check(ok: bool, label: String) -> void:
	_checks.append({"label": label, "pass": ok})
	if ok:
		print("  PASS  " + label)
	else:
		_fail(label)


func _fail(reason: String) -> void:
	if reason not in _failures:
		_failures.append(reason)
	push_error("  FAIL  " + reason)


func _write_matrix_receipt() -> bool:
	_receipt["checks"] = _checks
	_receipt["failures"] = _failures
	_receipt["passes"] = _checks.filter(func(row: Dictionary) -> bool:
		return bool(row.get("pass", false))).size()
	_receipt["status"] = "PASS" if _failures.is_empty() else "FAIL"
	var path := OS.get_environment(RECEIPT_ENV).strip_edges()
	if path.is_empty(): path = DEFAULT_RECEIPT
	if not path.begins_with("user://") and not path.is_absolute_path(): return false
	var absolute := ProjectSettings.globalize_path(path) if path.begins_with("user://") else path
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK: return false
	var file := FileAccess.open(absolute, FileAccess.WRITE)
	if file == null: return false
	var stored := file.store_buffer(JSON.stringify(_receipt, "\t").to_utf8_buffer())
	file.flush()
	var error := file.get_error()
	file.close()
	return stored and error == OK


func _finish(globals: Dictionary) -> void:
	_restore_globals(globals)
	if _write_matrix_receipt():
		var cleanup := _cleanup_successful_save_bundles()
		_receipt["save_bundle_cleanup"] = cleanup
		if not bool(cleanup.ok): _fail("matrix test-owned save bundle cleanup failed")
		if not _write_matrix_receipt(): _fail("could not update M11C2 matrix cleanup receipt")
	else:
		_fail("could not write M11C2 matrix receipt; save bundles preserved")
	print("ORISON V2 M11C2 PRODUCTION MATRIX: %s checks=%d failures=%d" % [
			"PASS" if _failures.is_empty() else "FAIL", _checks.size(), _failures.size()])
	get_tree().quit(0 if _failures.is_empty() else mini(255, _failures.size()))
