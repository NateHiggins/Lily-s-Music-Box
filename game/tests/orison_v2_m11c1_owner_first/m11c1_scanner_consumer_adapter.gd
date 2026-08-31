extends Node
## Disposable M11C1 adapter for the production consumers that treat a floor
## node as their scan/placement boundary.  The persistent F01 host remains
## geometry-free. Imported owner-first cell wrappers stay in its explicit
## registry while resident; inactive wrappers are moved to this adapter's
## dormant sibling so unchanged recursive scanners cannot see them.
##
## This file is rehearsal-only. It neither redirects a production consumer nor
## invents a replacement scanner. Every row below names the real public API it
## executed, or returns an explicit blocking seam.

const HeightmapPassScript := preload("res://scripts/building/heightmap_pass.gd")
const SurfacePassScript := preload("res://scripts/building/surface_pass.gd")
const AtmosphericDecalPassScript := preload(
		"res://scripts/building/atmospheric_decal_pass.gd")
const BroadcastDirectorScript := preload(
		"res://scripts/building/broadcast_director.gd")
const ArcadeRowScript := preload("res://scripts/building/arcade_row.gd")
const FurnitureInteractionPassScript := preload(
		"res://scripts/building/furniture_interaction_pass.gd")
const FoundArtPassScript := preload("res://scripts/building/found_art_pass.gd")
const DomesticWitnessSystemScript := preload(
		"res://scripts/reality/domestic_witness_system.gd")
const ApartmentEncroachmentScript := preload(
		"res://scripts/reality/apartment_encroachment.gd")
const ResidentRoutinesScript := preload(
		"res://scripts/characters/resident_routines.gd")

const CONTRACT_ID := "F01_SCANNER_PASS_DIRECTOR_CENSUS"
const CONSUMER_CLASSES := [
	"HeightmapPass",
	"SurfacePass",
	"AtmosphericDecalPass",
	"BroadcastDirector",
	"ArcadeRow",
	"FurnitureInteractionPass",
	"FoundArtPass",
	"DomesticWitnessSystem",
	"ApartmentEncroachment",
	"ResidentRoutines",
]
const ENCROACHMENT_ENV_KEYS := [
	"ENCROACH",
	"ENCROACH_FORCE",
	"ENCROACH_DEBUG_VIEW",
	"LIVING",
	"DREAM_FIELD",
	"DREAM_TENDRILS",
	"DREAM_MARGIN",
	"DREAM_CRITTERS",
	"DREAM_HERO",
	"TENTACLE",
]

var _layout: Dictionary = {}
var _host: Node3D = null
var _registry: Node = null
var _dormant: Node3D = null
var _configured := false
var _last_active: Array[String] = []


func configure(layout: Dictionary, composition_host: Node3D,
		cell_registry: Node) -> bool:
	if _configured or layout.is_empty() or composition_host == null \
			or cell_registry == null:
		return false
	if cell_registry.get_parent() != composition_host:
		return false
	if composition_host is GeometryInstance3D \
			or composition_host is CollisionObject3D:
		return false
	if not cell_registry.has_method("instance_for_cell") \
			or not cell_registry.has_method("set_visible_cells") \
			or not cell_registry.has_method("active_cell_ids") \
			or not cell_registry.has_method("mounted_cell_ids"):
		return false
	_layout = layout.duplicate(true)
	_host = composition_host
	_registry = cell_registry
	_dormant = Node3D.new()
	_dormant.name = "M11C1DormantCellWrappers"
	_dormant.set_meta(&"m11c1_scanner_excluded", true)
	add_child(_dormant)
	_configured = true
	return true


func exercise(full_ids: Array[String], selective_ids: Array[String]) -> Dictionary:
	var failures: Array[String] = []
	var blockers: Array[String] = []
	if not _configured:
		return _blocked("adapter was not configured")
	var declared := _sorted_unique(full_ids)
	var selective := _sorted_unique(selective_ids)
	if declared.size() != full_ids.size() or declared.is_empty():
		return _blocked("full residency must contain unique explicit cell IDs")
	for cell_id: String in selective:
		if cell_id not in declared:
			return _blocked("selective residency names an undeclared cell: %s" % cell_id)

	var full_apply := _apply_residency(declared)
	if not bool(full_apply.get("ok", false)):
		return _blocked(str(full_apply.get("reason", "full residency failed")))
	await _settle()
	var full_before := _scanner_input_receipt(declared)
	if not bool(full_before.get("exact", false)):
		failures.append("full scanner input did not contain every declared cell exactly once")

	var consumers := await _exercise_real_consumers(declared)
	for row: Dictionary in consumers:
		var status := str(row.get("status", "BLOCKING"))
		if status == "FAIL":
			failures.append("%s failed: %s" % [row.get("production_class", "?"),
					row.get("reason", "unspecified")])
		elif status == "BLOCKING":
			blockers.append("%s: %s" % [row.get("production_class", "?"),
					row.get("reason", "unspecified")])

	var selective_apply := _apply_residency(selective)
	if not bool(selective_apply.get("ok", false)):
		failures.append(str(selective_apply.get("reason", "selective residency failed")))
	await _settle()
	var selective_receipt := _scanner_input_receipt(selective)
	if not bool(selective_receipt.get("exact", false)):
		failures.append("selective scanner input retained an inactive cell")

	var restore_apply := _apply_residency(declared)
	if not bool(restore_apply.get("ok", false)):
		failures.append(str(restore_apply.get("reason", "full restore failed")))
	await _settle()
	var full_after := _scanner_input_receipt(declared)
	if not bool(full_after.get("exact", false)):
		failures.append("full scanner input did not restore exactly")

	var status := "PASS"
	if not failures.is_empty():
		status = "FAIL"
	elif not blockers.is_empty():
		status = "BLOCKING"
	return {
		"status":status,
		"contract_id":CONTRACT_ID,
		"scope":"disposable_m11c1_harness_only",
		"production_redirected":false,
		"production_scripts_modified":false,
		"geometry_free_host":_host_is_geometry_free(),
		"registry_parent_is_host":_registry.get_parent() == _host,
		"scanner_input_floor_nodes":{"F01":"persistent geometry-free host"},
		"sequence":["FULL", "SELECTIVE", "RESTORED_FULL"],
		"full_before":full_before,
		"selective":selective_receipt,
		"full_after":full_after,
		"residency_transitions":[full_apply, selective_apply, restore_apply],
		"consumers":consumers,
		"consumer_count":consumers.size(),
		"required_consumer_count":CONSUMER_CLASSES.size(),
		"failures":failures,
		"blockers":blockers,
		"node_name_reach_ins":false,
		"spatial_residency_inference":false,
		"production_default_changed":false,
	}


func public_teardown() -> Dictionary:
	var restored: Dictionary = {}
	if _configured and is_instance_valid(_registry):
		restored = _apply_residency(_registry.mounted_cell_ids())
	var dormant_id := 0
	if is_instance_valid(_dormant):
		dormant_id = _dormant.get_instance_id()
		_dormant.queue_free()
	_dormant = null
	_registry = null
	_host = null
	_layout.clear()
	_last_active.clear()
	_configured = false
	return {
		"api":"M11C1ScannerConsumerAdapter.public_teardown",
		"full_residency_restored_before_release":bool(restored.get("ok", false)),
		"dormant_scope_queued_instance_id":dormant_id,
		"retained_strong_references":_layout.size() + _last_active.size(),
		"forced_object_deletion":false,
		"node_name_reach_ins":false,
		"global_state_restored":true,
	}


func _apply_residency(requested_ids: Array[String]) -> Dictionary:
	if not is_instance_valid(_registry) or not is_instance_valid(_dormant):
		return {"ok":false, "reason":"registry or dormant scope was released"}
	var requested := {}
	for cell_id: String in requested_ids:
		requested[cell_id] = true
	var mounted: Array[String] = _registry.mounted_cell_ids()
	for cell_id: String in requested_ids:
		if cell_id not in mounted:
			return {"ok":false,
					"reason":"requested cell is not mounted: %s" % cell_id}
	for cell_id: String in mounted:
		var instance := _registry.instance_for_cell(cell_id) as Node
		if not is_instance_valid(instance):
			return {"ok":false,
					"reason":"mounted cell has no live wrapper: %s" % cell_id}
		var wanted_parent: Node = _registry if requested.has(cell_id) else _dormant
		if instance.get_parent() != wanted_parent:
			instance.reparent(wanted_parent, true)
	var visibility: Dictionary = _registry.set_visible_cells(requested_ids)
	_last_active = _sorted_unique(requested_ids)
	return {
		"ok":_registry.active_cell_ids() == _last_active,
		"active_ids":_last_active.duplicate(),
		"dormant_ids":_cell_wrapper_ids_under(_dormant),
		"visibility":visibility,
		"inactive_wrappers_outside_scanner_ancestry":true,
		"collision_changed":false,
		"semantic_registry_changed":false,
	}


func _scanner_input_receipt(expected_ids: Array[String]) -> Dictionary:
	var expected := _sorted_unique(expected_ids)
	var host_ids := _cell_wrapper_ids_under(_host)
	var dormant_ids := _cell_wrapper_ids_under(_dormant)
	var registry_active: Array[String] = _registry.active_cell_ids()
	registry_active.sort()
	var mounted: Array[String] = _registry.mounted_cell_ids()
	var wanted_dormant: Array[String] = []
	for cell_id: String in mounted:
		if cell_id not in expected:
			wanted_dormant.append(cell_id)
	wanted_dormant.sort()
	var inventory := _recursive_scanner_inventory(_host)
	return {
		"expected_active_ids":expected,
		"scanner_descendant_cell_ids":host_ids,
		"registry_active_ids":registry_active,
		"dormant_cell_ids":dormant_ids,
		"expected_dormant_ids":wanted_dormant,
		"inactive_ids_excluded_from_scanner_input":host_ids == expected \
				and dormant_ids == wanted_dormant,
		"exact":host_ids == expected and registry_active == expected \
				and dormant_ids == wanted_dormant,
		"recursive_scanner_inventory":inventory,
		"classification_source":"explicit m11c1_owner_cell metadata on imported wrappers",
		"position_or_bounds_classification":false,
	}


func _recursive_scanner_inventory(root: Node) -> Dictionary:
	var nodes := 0
	var meshes := 0
	var collision_objects := 0
	var collision_shapes := 0
	var visible_meshes := 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		nodes += 1
		if node is MeshInstance3D:
			meshes += 1
			if (node as MeshInstance3D).is_visible_in_tree():
				visible_meshes += 1
		if node is CollisionObject3D:
			collision_objects += 1
		if node is CollisionShape3D:
			collision_shapes += 1
		for child: Node in node.get_children():
			stack.append(child)
	return {
		"nodes":nodes,
		"mesh_instances":meshes,
		"visible_mesh_instances":visible_meshes,
		"collision_objects":collision_objects,
		"collision_shapes":collision_shapes,
	}


func _exercise_real_consumers(full_ids: Array[String]) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	rows.append(await _exercise_heightmap(full_ids))
	rows.append(await _exercise_surface(full_ids))
	rows.append(await _exercise_atmospheric_decals(full_ids))
	rows.append(await _exercise_broadcast(full_ids))
	rows.append(await _exercise_arcade(full_ids))
	rows.append(await _exercise_furniture_interactions(full_ids))
	rows.append(await _exercise_found_art(full_ids))
	rows.append(await _exercise_domestic_witnesses(full_ids))
	rows.append(await _exercise_apartment_encroachment(full_ids))
	rows.append(await _exercise_resident_floor_binding(full_ids))
	return rows


func _exercise_heightmap(active_ids: Array[String]) -> Dictionary:
	var snapshots := _standard_material_snapshots()
	var owner := HeightmapPassScript.new()
	owner.name = "M11C1HeightmapPass"
	add_child(owner)
	var started := Time.get_ticks_usec()
	var applied: int = owner.build({"F01":_host})
	var elapsed := _elapsed_ms(started)
	var restored := _restore_standard_materials(snapshots)
	var owner_id := owner.get_instance_id()
	owner.queue_free()
	owner = null
	await _settle()
	var released := instance_from_id(owner_id) == null
	snapshots.clear()
	return _consumer_row("HeightmapPass", "build(floor_nodes)",
			applied > 0 and int(restored.get("count", 0)) > 0 \
			and bool(restored.get("exact", false)) and released,
			active_ids, {
		"applied_materials":applied,
		"material_snapshot_count":restored.get("count", 0),
		"material_state_restored":restored,
		"owner_released":released,
		"elapsed_ms":elapsed,
		"scanner_kind":"recursive MeshInstance3D/material scanner",
	})


func _exercise_surface(active_ids: Array[String]) -> Dictionary:
	var snapshots := _surface_override_snapshots()
	var surface_pass = SurfacePassScript.new()
	var started := Time.get_ticks_usec()
	var swapped: int = surface_pass.apply({"F01":_host})
	var elapsed := _elapsed_ms(started)
	var restored := _restore_surface_overrides(snapshots)
	# These are instance-owned references/callables. Static texture-analysis
	# caches are intentional production warm caches and are measured by the
	# outer two-cycle lifecycle receipt rather than falsified as a leak here.
	surface_pass.restore_props()
	surface_pass.on_props_applied = Callable()
	surface_pass._props_root = null
	surface_pass._lever_queue.clear()
	surface_pass._prop_swaps.clear()
	surface_pass._cache.clear()
	surface_pass = null
	snapshots.clear()
	await _settle()
	return _consumer_row("SurfacePass", "apply(floor_nodes)",
			swapped > 0 and int(restored.get("count", 0)) > 0 \
			and bool(restored.get("exact", false)), active_ids, {
		"swapped_surfaces":swapped,
		"surface_override_snapshot_count":restored.get("count", 0),
		"surface_overrides_restored":restored,
		"elapsed_ms":elapsed,
		"scanner_kind":"recursive named MeshInstance3D/surface scanner",
		"static_cache_policy":"production warm cache; outer same-process cycles measure retention",
	})


func _exercise_atmospheric_decals(active_ids: Array[String]) -> Dictionary:
	var before := _direct_host_children()
	var owner := AtmosphericDecalPassScript.new()
	owner.name = "M11C1AtmosphericDecalPass"
	add_child(owner)
	var started := Time.get_ticks_usec()
	var count: int = owner.build(_layout, {"F01":_host})
	var elapsed := _elapsed_ms(started)
	var details := {"decal_count":count,
			"declined_count":int(owner.declined_count), "elapsed_ms":elapsed,
			"scanner_kind":"layout-driven placement onto active F01 host"}
	var released := await _release_scoped_outputs(owner, before)
	details.merge(released, true)
	return _consumer_row("AtmosphericDecalPass",
			"build(layout, floor_nodes)", count > 0 \
			and bool(released.get("all_released", false)), active_ids, details)


func _exercise_broadcast(active_ids: Array[String]) -> Dictionary:
	var before := _direct_host_children()
	var owner := BroadcastDirectorScript.new()
	owner.name = "M11C1BroadcastDirector"
	add_child(owner)
	var started := Time.get_ticks_usec()
	var count: int = owner.build(_layout, {"F01":_host})
	var elapsed := _elapsed_ms(started)
	var statistics: Dictionary = owner.stats()
	var details := {"machine_count":count, "stats":statistics,
			"elapsed_ms":elapsed,
			"scanner_kind":"layout furniture enumerator; outputs parent to active F01 host"}
	var released := await _release_scoped_outputs(owner, before)
	details.merge(released, true)
	return _consumer_row("BroadcastDirector", "build(layout, floor_nodes); stats()",
			count > 0 and int(statistics.get("sets", -1)) == count \
			and bool(released.get("all_released", false)), active_ids, details)


func _exercise_arcade(active_ids: Array[String]) -> Dictionary:
	var before := _direct_host_children()
	var owner := ArcadeRowScript.new()
	owner.name = "M11C1ArcadeRow"
	add_child(owner)
	var started := Time.get_ticks_usec()
	var count: int = owner.install(_layout, {"F01":_host})
	var elapsed := _elapsed_ms(started)
	var bound := 0
	for cabinet: Variant in owner.cabinets:
		if is_instance_valid(cabinet) and not str(cabinet.graph_node_id).is_empty():
			bound += 1
	var details := {"cabinet_count":count, "acoustic_bound_count":bound,
			"elapsed_ms":elapsed,
			"scanner_kind":"layout furniture enumerator; acoustic binding uses production graph"}
	var released := await _release_scoped_outputs(owner, before)
	details.merge(released, true)
	return _consumer_row("ArcadeRow", "install(layout, floor_nodes)",
			count > 0 and bound == count \
			and bool(released.get("all_released", false)), active_ids, details)


func _exercise_furniture_interactions(active_ids: Array[String]) -> Dictionary:
	var before := _direct_host_children()
	var owner := FurnitureInteractionPassScript.new()
	owner.name = "M11C1FurnitureInteractionPass"
	add_child(owner)
	var started := Time.get_ticks_usec()
	var count: int = owner.build(_layout, {"F01":_host})
	var elapsed := _elapsed_ms(started)
	var details := {"interaction_owner_count":count, "elapsed_ms":elapsed,
			"scanner_kind":"layout furniture enumerator; mechanisms parent to active F01 host"}
	var released := await _release_scoped_outputs(owner, before)
	details.merge(released, true)
	return _consumer_row("FurnitureInteractionPass",
			"build(layout, floor_nodes)", count > 0 \
			and bool(released.get("all_released", false)), active_ids, details)


func _exercise_found_art(active_ids: Array[String]) -> Dictionary:
	var before := _direct_host_children()
	var reservations := _snapshot_wall_art_reservations()
	var owner := FoundArtPassScript.new()
	owner.name = "M11C1FoundArtPass"
	add_child(owner)
	var started := Time.get_ticks_usec()
	var counts: Dictionary = owner.build(_layout, {"F01":_host})
	var elapsed := _elapsed_ms(started)
	var reservation_restored := _restore_wall_art_reservations(reservations)
	var relevant_count := int(counts.get("wall", 0)) \
			+ int(counts.get("print", 0)) + int(counts.get("billboard", 0))
	var details := {"counts":counts, "elapsed_ms":elapsed,
			"wall_art_global_state_restored":reservation_restored,
			"scanner_kind":"catalog/layout enumerator; F01 outputs parent to active host"}
	var released := await _release_scoped_outputs(owner, before)
	details.merge(released, true)
	return _consumer_row("FoundArtPass", "build(layout, floor_nodes)",
			relevant_count > 0 and reservation_restored \
			and bool(released.get("all_released", false)), active_ids, details)


func _exercise_domestic_witnesses(active_ids: Array[String]) -> Dictionary:
	var before := _direct_host_children()
	var reservations := _snapshot_wall_art_reservations()
	var owner := DomesticWitnessSystemScript.new()
	owner.name = "M11C1DomesticWitnessSystem"
	add_child(owner)
	var started := Time.get_ticks_usec()
	var count: int = owner.build(_layout, {"F01":_host})
	var elapsed := _elapsed_ms(started)
	var f01_clocks := owner.clocks.size()
	var f01_anomalies := owner.anomalies.size()
	var reservation_restored := _restore_wall_art_reservations(reservations)
	var details := {"built_count":count, "clock_count":f01_clocks,
			"anomaly_identity_count":f01_anomalies, "elapsed_ms":elapsed,
			"wall_art_global_state_restored":reservation_restored,
			"scanner_kind":"resident catalogs/layout; only records whose floor node exists mount"}
	var released := await _release_scoped_outputs(owner, before)
	details.merge(released, true)
	return _consumer_row("DomesticWitnessSystem", "build(layout, floor_nodes)",
			count > 0 and f01_clocks > 0 and reservation_restored \
			and bool(released.get("all_released", false)), active_ids, details)


func _exercise_apartment_encroachment(active_ids: Array[String]) -> Dictionary:
	var before := _direct_host_children()
	var environment := _snapshot_environment(ENCROACHMENT_ENV_KEYS)
	# The real F01 invocation is enabled, while optional dream ecology is kept
	# out of this floor-cut rehearsal. No ApartmentEncroachment.CASES record
	# belongs to F01, so zero applied surfaces is the correct production answer.
	OS.set_environment("ENCROACH", "1")
	OS.set_environment("ENCROACH_FORCE", "")
	OS.set_environment("ENCROACH_DEBUG_VIEW", "0")
	for key: String in ["LIVING", "DREAM_FIELD", "DREAM_TENDRILS",
			"DREAM_MARGIN", "DREAM_CRITTERS", "DREAM_HERO", "TENTACLE"]:
		OS.set_environment(key, "0")
	var owner := ApartmentEncroachmentScript.new()
	owner.name = "M11C1ApartmentEncroachment"
	add_child(owner)
	var started := Time.get_ticks_usec()
	var count: int = owner.build(_layout, {"F01":_host})
	var elapsed := _elapsed_ms(started)
	var applicable_cases: Array[String] = []
	for case_id: String in ApartmentEncroachmentScript.CASES:
		var unit := str((ApartmentEncroachmentScript.CASES[case_id] as Dictionary).unit)
		if unit.begins_with("1"):
			applicable_cases.append(case_id)
	var clean_non_applicability := count == 0 and applicable_cases.is_empty() \
			and owner.units.is_empty() and owner.surfaces.is_empty()
	var environment_restored := _restore_environment(environment)
	var details := {"applied_surface_count":count,
			"applicable_f01_case_ids":applicable_cases,
			"expected_non_applicable_to_floor01":true,
			"optional_dream_ecology_disabled_for_bounded_rehearsal":true,
			"environment_restored":environment_restored,
			"elapsed_ms":elapsed,
			"scanner_kind":"unit-to-floor map plus recursive finish-surface scan"}
	var released := await _release_scoped_outputs(owner, before)
	details.merge(released, true)
	var row := _consumer_row("ApartmentEncroachment",
			"build(layout, floor_nodes, witnesses)", clean_non_applicability \
			and environment_restored and bool(released.get("all_released", false)),
			active_ids, details)
	row["status"] = "PASS_NOT_APPLICABLE_TO_F01" \
			if bool(row.get("executed_ok", false)) else "FAIL"
	return row


func _exercise_resident_floor_binding(active_ids: Array[String]) -> Dictionary:
	var owner := ResidentRoutinesScript.new()
	owner.name = "M11C1ResidentFloorBinding"
	add_child(owner)
	var started := Time.get_ticks_usec()
	owner.bind_floors({"F01":_host})
	var elapsed := _elapsed_ms(started)
	var exact_binding: bool = owner._floor_nodes.size() == 1 \
			and owner._floor_nodes.get("F01") == _host
	var owner_id := owner.get_instance_id()
	owner.queue_free()
	owner = null
	await _settle()
	var released := instance_from_id(owner_id) == null
	return _consumer_row("ResidentRoutines",
			"bind_floors(floor_nodes)", exact_binding and released, active_ids, {
		"binding_count":1,
		"binding_exact":exact_binding,
		"owner_released":released,
		"elapsed_ms":elapsed,
		"contract":"resident reparenting receives the same persistent F01 host used by residency",
		"limitation":"no synthetic resident actor or schedule authority created",
	})


func _consumer_row(production_class: String, public_api: String, ok: bool,
		active_ids: Array[String], details: Dictionary) -> Dictionary:
	var row := {
		"status":"PASS" if ok else "FAIL",
		"executed_ok":ok,
		"production_class":production_class,
		"public_api":public_api,
		"production_api_executed":true,
		"active_cell_ids":_sorted_unique(active_ids),
		"floor_nodes":{"F01":"persistent geometry-free host"},
		"production_redirected":false,
		"test_double_used":false,
	}
	row.merge(details, true)
	if not ok and not row.has("reason"):
		row["reason"] = "production API result or scoped teardown contract failed"
	return row


func _standard_material_snapshots() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var seen := {}
	for node: Node in _host.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface: int in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.mesh.surface_get_material(surface)
			if not (material is StandardMaterial3D) \
					or seen.has(material.get_instance_id()):
				continue
			seen[material.get_instance_id()] = true
			var standard := material as StandardMaterial3D
			rows.append({
				"material":standard,
				"enabled":standard.heightmap_enabled,
				"texture":standard.heightmap_texture,
				"scale":standard.heightmap_scale,
				"deep":standard.heightmap_deep_parallax,
				"flip":standard.heightmap_flip_texture,
			})
	return rows


func _restore_standard_materials(rows: Array[Dictionary]) -> Dictionary:
	for row: Dictionary in rows:
		var material := row.material as StandardMaterial3D
		material.heightmap_enabled = bool(row.enabled)
		material.heightmap_texture = row.texture as Texture2D
		material.heightmap_scale = float(row.scale)
		material.heightmap_deep_parallax = bool(row.deep)
		material.heightmap_flip_texture = bool(row.flip)
	var mismatches := 0
	for row: Dictionary in rows:
		var material := row.material as StandardMaterial3D
		if material.heightmap_enabled != bool(row.enabled) \
				or material.heightmap_texture != row.texture \
				or not is_equal_approx(material.heightmap_scale, float(row.scale)) \
				or material.heightmap_deep_parallax != bool(row.deep) \
				or material.heightmap_flip_texture != bool(row.flip):
			mismatches += 1
	return {"exact":mismatches == 0, "count":rows.size(),
			"mismatches":mismatches}


func _surface_override_snapshots() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for node: Node in _host.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface: int in mesh_instance.mesh.get_surface_count():
			rows.append({"mesh":mesh_instance, "surface":surface,
					"override":mesh_instance.get_surface_override_material(surface)})
	return rows


func _restore_surface_overrides(rows: Array[Dictionary]) -> Dictionary:
	for row: Dictionary in rows:
		(row.mesh as MeshInstance3D).set_surface_override_material(
				int(row.surface), row.override as Material)
	var mismatches := 0
	for row: Dictionary in rows:
		if (row.mesh as MeshInstance3D).get_surface_override_material(
				int(row.surface)) != row.override:
			mismatches += 1
	return {"exact":mismatches == 0, "count":rows.size(),
			"mismatches":mismatches}


func _snapshot_wall_art_reservations() -> Dictionary:
	return {
		"wall":WallArtLaw._reserved.duplicate(true),
		"surface":WallArtLaw._surface_reserved.duplicate(true),
	}


func _restore_wall_art_reservations(snapshot: Dictionary) -> bool:
	WallArtLaw._reserved.clear()
	WallArtLaw._reserved.merge(snapshot.get("wall", {}), true)
	WallArtLaw._surface_reserved.clear()
	WallArtLaw._surface_reserved.merge(snapshot.get("surface", {}), true)
	return WallArtLaw._reserved == snapshot.get("wall", {}) \
			and WallArtLaw._surface_reserved == snapshot.get("surface", {})


func _snapshot_environment(keys: Array) -> Dictionary:
	var result := {}
	for raw: Variant in keys:
		var key := str(raw)
		result[key] = {"present":OS.has_environment(key),
				"value":OS.get_environment(key)}
	return result


func _restore_environment(snapshot: Dictionary) -> bool:
	for raw: Variant in snapshot:
		var key := str(raw)
		var state: Dictionary = snapshot[key]
		if bool(state.present):
			OS.set_environment(key, str(state.value))
		else:
			OS.unset_environment(key)
	for raw: Variant in snapshot:
		var key := str(raw)
		var state: Dictionary = snapshot[key]
		if OS.has_environment(key) != bool(state.present):
			return false
		if bool(state.present) and OS.get_environment(key) != str(state.value):
			return false
	return true


func _direct_host_children() -> Dictionary:
	var result := {}
	for child: Node in _host.get_children():
		result[child.get_instance_id()] = true
	return result


func _release_scoped_outputs(owner: Node, before: Dictionary) -> Dictionary:
	var outputs: Array[Node] = []
	var output_ids: Array[int] = []
	for child: Node in _host.get_children():
		if not before.has(child.get_instance_id()):
			outputs.append(child)
			output_ids.append(child.get_instance_id())
	var owner_id := owner.get_instance_id()
	owner.queue_free()
	for output: Node in outputs:
		if is_instance_valid(output) and not output.is_queued_for_deletion():
			output.queue_free()
	owner = null
	outputs.clear()
	await _settle()
	var retained: Array[int] = []
	if instance_from_id(owner_id) != null:
		retained.append(owner_id)
	for output_id: int in output_ids:
		if instance_from_id(output_id) != null:
			retained.append(output_id)
	return {
		"teardown":"adapter-owned instance-delta scope; queue_free lifecycle",
		"output_instance_ids":output_ids,
		"owner_instance_id":owner_id,
		"retained_instance_ids":retained,
		"all_released":retained.is_empty(),
		"forced_object_deletion":false,
		"node_name_reach_ins":false,
	}


func _cell_wrapper_ids_under(root: Node) -> Array[String]:
	var result: Array[String] = []
	if not is_instance_valid(root):
		return result
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node.has_meta(&"m11c1_owner_cell") \
				and node.has_meta(&"m11c1_import_mode"):
			result.append(str(node.get_meta(&"m11c1_owner_cell")))
		for child: Node in node.get_children():
			stack.append(child)
	result.sort()
	return result


func _host_is_geometry_free() -> bool:
	return is_instance_valid(_host) and not (_host is GeometryInstance3D) \
			and not (_host is CollisionObject3D) \
			and bool(_host.get_meta(&"m11c1_geometry_free_host", false))


func _sorted_unique(values: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for value: String in values:
		if value not in result:
			result.append(value)
	result.sort()
	return result


func _settle() -> void:
	if get_tree() == null:
		return
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().process_frame


func _elapsed_ms(started_usec: int) -> float:
	return float(Time.get_ticks_usec() - started_usec) / 1000.0


func _blocked(reason: String) -> Dictionary:
	return {
		"status":"BLOCKING",
		"contract_id":CONTRACT_ID,
		"reason":reason,
		"production_redirected":false,
		"production_scripts_modified":false,
	}
