extends Node3D
## Isolated interface adapter and census. It exercises the cut-facing seams of
## each known consumer without pretending to be, or redirecting, that
## production authority.

const Support := preload("res://tests/orison_v2_m11c1_owner_first/m11c1_harness_support.gd")
const RegistryScript := preload("res://tests/orison_v2_m11c1_owner_first/m11c1_cell_registry.gd")

const CONSUMER_CONTRACTS := [
	{
		"id":"BUILDING_ROOT_LOADING",
		"production_owner":"BuildingRoot",
		"isolated_adapter":"explicit residency -> M11C1CellRegistry.mount_cells",
	},
	{
		"id":"BUILDING_ROOT_INDEX_VISIBILITY",
		"production_owner":"BuildingRoot",
		"isolated_adapter":"cell ID registry + explicit visibility membership",
	},
	{
		"id":"F01_HOST_PASSES_DIRECTORS",
		"production_owner":"F01 passes/directors",
		"isolated_adapter":"persistent geometry-free F01 composition host binding",
	},
	{
		"id":"ORISON_DETAIL_PASS",
		"production_owner":"OrisonDetailPass",
		"isolated_adapter":"persistent F01 host binding; no geometry-cell parenting",
	},
	{
		"id":"VANTRY_POINT_NETWORK",
		"production_owner":"VantryPointNetwork",
		"isolated_adapter":"persistent F01 host binding; no geometry-cell parenting",
	},
	{
		"id":"EXTERIOR_DETAIL_PASS",
		"production_owner":"ExteriorDetailPass",
		"isolated_adapter":"governed CELL_SITE_STREET_COMMON binding",
	},
	{
		"id":"RESIDENT_NAV",
		"production_owner":"ResidentNav",
		"isolated_adapter":"real F01-scoped build + active-world collision validation",
	},
	{
		"id":"M11A_EXTERIOR_COMPOSITION",
		"production_owner":"OrisonV2ExteriorCell",
		"isolated_adapter":"independent production scene lifecycle; never a floor cell",
	},
	{
		"id":"SAVE_RECONSTRUCTION",
		"production_owner":"RealityState",
		"isolated_adapter":"real isolated semantic save/load; no geometry path or coordinate",
	},
]

var composition_host: Node3D
var registry
var _inputs := {}
var _residency_id := ""


func configure(inputs: Dictionary) -> bool:
	if is_inside_tree() or not _inputs.is_empty():
		return false
	# Keep teardown local. Clearing this adapter must never clear the caller's
	# authoritative input transaction between lifecycle cycles.
	_inputs = inputs.duplicate(true)
	composition_host = Node3D.new()
	composition_host.name = "F01"
	composition_host.set_meta(&"m11c1_geometry_free_host", true)
	registry = RegistryScript.new()
	registry.name = "OwnerFirstGeometryCells"
	if not registry.configure(inputs.get("cells_by_id", {})):
		return false
	add_child(composition_host)
	composition_host.add_child(registry)
	return true


func mount_residency(residency_id: String,
		allow_raw_diagnostic := true) -> Dictionary:
	var sets: Dictionary = _inputs.get("residency_sets", {})
	if not sets.has(residency_id):
		return {"ok":false, "error":"unknown explicit residency set",
				"residency_id":residency_id}
	_residency_id = residency_id
	var cells: Array[String] = Support.string_array(sets[residency_id])
	var mounted: Dictionary = registry.mount_cells(cells,
			allow_raw_diagnostic)
	mounted["residency_id"] = residency_id
	return mounted


func mount_explicit_cells(cell_ids: Array[String],
		allow_raw_diagnostic := false) -> Dictionary:
	_residency_id = "EXPLICIT_SEAM_SET"
	return registry.mount_cells(cell_ids, allow_raw_diagnostic)


func exercise_consumer_contracts(executions: Dictionary = {}) -> Dictionary:
	var active: Array[String] = registry.mounted_cell_ids()
	var full_visibility: Dictionary = registry.set_visible_cells(active)
	var selective_ids: Array[String] = []
	if not active.is_empty():
		selective_ids.append(active[0])
	var selective_visibility: Dictionary = registry.set_visible_cells(selective_ids)
	var selective_index_ok: bool = registry.active_cell_ids() == selective_ids
	for cell_id: String in active:
		var should_be_active := cell_id in selective_ids
		selective_index_ok = selective_index_ok \
				and (registry.active_instance_for_cell(cell_id) != null) \
				== should_be_active
	var restored_visibility: Dictionary = registry.set_visible_cells(active)
	var restored_index_ok: bool = registry.active_cell_ids() == active
	var host_metrics: Dictionary = Support.tree_metrics(composition_host)
	# Pass/director output may legitimately live beneath the composition host.
	# "Geometry-free host" means the host node itself owns no protected or cell
	# geometry; its explicit registry children and gameplay/detail outputs are
	# legitimate descendants for unchanged recursive scanners.
	var imported_cell_descendants: int = 0
	for cell_id: String in active:
		var cell_node: Node = registry.instance_for_cell(cell_id)
		if cell_node != null and composition_host.is_ancestor_of(cell_node):
			imported_cell_descendants += 1
	var host_geometry_free: bool = composition_host is Node3D \
			and not (composition_host is GeometryInstance3D) \
			and not (composition_host is CollisionObject3D) \
			and imported_cell_descendants == active.size() \
			and registry.get_parent() == composition_host
	var indexed: Array[Dictionary] = []
	for cell_id: String in active:
		indexed.append({"cell_id":cell_id,
				"instance_id":registry.instance_for_cell(cell_id).get_instance_id(),
				"lookup":"explicit_cell_id"})
	var rows: Array[Dictionary] = []
	var all_real_pass: bool = host_geometry_free and selective_index_ok \
			and restored_index_ok
	for raw: Dictionary in CONSUMER_CONTRACTS:
		var row: Dictionary = raw.duplicate(true)
		var contract_id := str(raw.id)
		var built_in_adapter: bool = contract_id in ["BUILDING_ROOT_LOADING",
				"BUILDING_ROOT_INDEX_VISIBILITY"]
		var execution_key := "F01_SCANNER_PASS_DIRECTOR_CENSUS" \
				if contract_id == "F01_HOST_PASSES_DIRECTORS" else contract_id
		var execution: Dictionary = executions.get(execution_key, {})
		var status := "PASS_ISOLATED_ADAPTER" if built_in_adapter else str(
				execution.get("status", "BLOCKED"))
		row.merge({
			"scope":"m11c1_test_harness_only",
			"production_redirected":false,
			"production_script_modified":false,
			"geometry_host":"F01" if str(raw.id) in [
					"F01_HOST_PASSES_DIRECTORS", "ORISON_DETAIL_PASS",
					"VANTRY_POINT_NETWORK"] else "",
			"active_residency_id":_residency_id,
			"active_cell_ids":active,
			"status":status,
			"production_api_executed":not built_in_adapter,
			"equivalent_isolated_contract_executed":built_in_adapter,
			"proof_limit":"BuildingRoot class itself is not instantiated; explicit-ID loading/index/visibility calls are exercised under the user-authorized isolated adapter" \
					if built_in_adapter else "",
			"execution":execution,
		}, true)
		if str(raw.id) == "EXTERIOR_DETAIL_PASS":
			row["governed_owner_cell"] = "CELL_SITE_STREET_COMMON"
		if str(raw.id) == "M11A_EXTERIOR_COMPOSITION":
			row["floor_cell_absorbed"] = false
		all_real_pass = all_real_pass and status in ["PASS",
				"PASS_ISOLATED_ADAPTER", "PASS_WITH_OFF_SLICE_DEPENDENCY"]
		rows.append(row)
	return {
		"status":"PASS" if all_real_pass else "BLOCKED",
		"contracts":rows,
		"required_contract_count":CONSUMER_CONTRACTS.size(),
		"host":{
			"id":"F01",
			"persistent":true,
			"geometry_free":host_geometry_free,
			"imported_cell_wrapper_descendants":imported_cell_descendants,
			"host_node_is_geometry_or_collision":false,
			"scanner_topology":"production floor scanners receive F01 host and traverse active registry child wrappers",
			"pass_or_director_descendants_allowed":true,
			"metrics":host_metrics,
		},
		"index":indexed,
		"visibility_exercise":{
			"full":full_visibility,
			"selective":selective_visibility,
			"selective_index_ok":selective_index_ok,
			"restore":restored_visibility,
			"restored_index_ok":restored_index_ok,
			"collision_scope":"visibility-only; collision residency is proven by independent mount/teardown sets",
		},
		"node_name_reach_ins":false,
		"spatial_inference":false,
	}


func public_teardown() -> Dictionary:
	var registry_receipt: Dictionary = registry.public_teardown() \
			if is_instance_valid(registry) else {}
	var queued: Array[int] = []
	if is_instance_valid(registry):
		queued.append(registry.get_instance_id())
		registry.queue_free()
	if is_instance_valid(composition_host):
		queued.append(composition_host.get_instance_id())
		composition_host.queue_free()
	registry = null
	composition_host = null
	_inputs.clear()
	_residency_id = ""
	return {
		"api":"M11C1ConsumerAdaptation.public_teardown",
		"registry":registry_receipt,
		"queued_instance_ids":queued,
		"retained_strong_references":_inputs.size(),
		"production_redirected":false,
		"forced_object_deletion":false,
	}
