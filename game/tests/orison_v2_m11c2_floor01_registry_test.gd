extends Node
## Focused production registry/configuration refusal and lifecycle proof.

const Configuration := preload(
		"res://scripts/building/floor01_geometry_configuration.gd")
const RegistryScript := preload(
		"res://scripts/building/floor01_cell_registry.gd")
const TeardownFixture := preload(
		"res://tests/orison_v2_m11c2_floor01_teardown_fixture.gd")
const SurfacePassScript := preload(
		"res://scripts/building/surface_pass.gd")

var _failures := 0


func _ready() -> void:
	var manifest := _load_manifest()
	_check(not manifest.is_empty(), "production registry manifest parses")
	if manifest.is_empty():
		get_tree().quit(1)
		return
	_test_session_configuration()
	_test_surface_pass_shared_owner_release()
	_test_refusals(manifest)
	await _test_transactional_mount_failure()
	await _test_owner_first_registry(_load_manifest())
	await _test_legacy_registry(_load_manifest())
	await _test_public_teardown_restores_global_presentation()
	Configuration.reset_for_tests()
	print("[M11C2-REGISTRY] %s (%d failure(s))" % [
			"PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)


func _test_session_configuration() -> void:
	Configuration.reset_for_tests()
	_check(Configuration.DEFAULT_MODE == Configuration.OWNER_FIRST_CELLS,
			"committed geometry default is owner_first_cells")
	_check(Configuration.selected_mode() == Configuration.OWNER_FIRST_CELLS,
			"absent override chooses owner-first cells")
	_check(Configuration.set_for_tests(Configuration.LEGACY_MONOLITH),
			"explicit legacy test injection is accepted")
	_check(Configuration.selected_mode() == Configuration.LEGACY_MONOLITH,
			"legacy injection becomes active")
	_check(not Configuration.set_for_tests("monolith_plus_cells"),
			"invalid/co-load mode is refused")
	_check(Configuration.selected_mode() == Configuration.LEGACY_MONOLITH,
			"invalid injection cannot mutate the active mode")
	Configuration.reset_for_tests()
	var receipt: Dictionary = Configuration.session_receipt()
	_check(not bool(receipt.persistent) and not bool(receipt.save_authority),
			"geometry choice is session-only and not save authority")


func _test_surface_pass_shared_owner_release() -> void:
	var first_root := Node3D.new()
	first_root.name = "FirstProvider"
	add_child(first_root)
	var second_root := Node3D.new()
	second_root.name = "SecondProvider"
	add_child(second_root)
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.55, 0.48, 0.40, 1.0))
	var texture := ImageTexture.create_from_image(image)
	var shipping := StandardMaterial3D.new()
	shipping.resource_name = "M_shared_release_fixture"
	shipping.albedo_texture = texture
	for root: Node3D in [first_root, second_root]:
		var mesh := BoxMesh.new()
		mesh.material = shipping
		var instance := MeshInstance3D.new()
		instance.name = "fixture_walls"
		instance.mesh = mesh
		root.add_child(instance)
	var surface_pass = SurfacePassScript.new()
	var applied := int(surface_pass.apply({
		"FIRST": first_root,
		"SECOND": second_root,
	}))
	var first_mesh := first_root.get_child(0) as MeshInstance3D
	var second_mesh := second_root.get_child(0) as MeshInstance3D
	_check(applied == 2 and first_mesh.get_surface_override_material(0) \
			== second_mesh.get_surface_override_material(0),
			"surface pass records a genuinely shared cross-provider material")
	var first_release: Dictionary = surface_pass.release_geometry(first_root)
	_check(bool(first_release.get("ok", false)) \
			and int(first_release.get("shared_cache_entries_preserved", 0)) == 1 \
			and first_mesh.get_surface_override_material(0) == null \
			and second_mesh.get_surface_override_material(0) != null,
			"first provider release preserves the shared material's live owner")
	var second_release: Dictionary = surface_pass.release_geometry(second_root)
	_check(bool(second_release.get("ok", false)) \
			and int(second_release.get("released_cache_entries", 0)) == 1 \
			and int(second_release.get("remaining_cache_entries", -1)) == 0 \
			and second_mesh.get_surface_override_material(0) == null,
			"last provider release clears the shared material cache entry")
	first_root.queue_free()
	second_root.queue_free()


func _test_refusals(manifest: Dictionary) -> void:
	var duplicate := manifest.duplicate(true)
	var duplicate_identity := str(duplicate.cells[0].semantic_owners[0])
	duplicate.cells[1].semantic_owners.append(duplicate_identity)
	var registry = RegistryScript.new()
	var duplicate_result: Dictionary = registry.configure(
			Configuration.LEGACY_MONOLITH, duplicate)
	_check(not bool(duplicate_result.get("ok", false)),
			"duplicate semantic owner is refused")
	registry.queue_free()

	var cycle := manifest.duplicate(true)
	cycle.cells[0].dependencies = [str(cycle.cells[1].id)]
	cycle.cells[1].dependencies = [str(cycle.cells[0].id)]
	registry = RegistryScript.new()
	var cycle_result: Dictionary = registry.configure(
			Configuration.LEGACY_MONOLITH, cycle)
	_check(not bool(cycle_result.get("ok", false)),
			"dependency cycle is refused")
	registry.queue_free()

	var unknown := manifest.duplicate(true)
	unknown.cells[0].id = "CELL_UNKNOWN"
	registry = RegistryScript.new()
	var unknown_result: Dictionary = registry.configure(
			Configuration.LEGACY_MONOLITH, unknown)
	_check(not bool(unknown_result.get("ok", false)),
			"unknown cell is refused")
	registry.queue_free()

	var unbound := _load_manifest()
	unbound.asset_manifest_sha256 = "0".repeat(64)
	registry = RegistryScript.new()
	var unbound_result: Dictionary = registry.configure(
			Configuration.OWNER_FIRST_CELLS, unbound)
	_check(not bool(unbound_result.get("ok", false)),
			"owner-first mode refuses an unbound asset-manifest hash")
	registry.queue_free()

	var incompatible_alias := _load_manifest()
	var first_alias_by_cell := {}
	var swapped := false
	for raw_alias in incompatible_alias.compatibility_alias_index:
		var targets: Array = incompatible_alias.compatibility_alias_index[raw_alias]
		if targets.size() != 1:
			continue
		var cell_id := str((targets[0] as Dictionary).cell_id)
		if first_alias_by_cell.has(cell_id):
			var first_alias := str(first_alias_by_cell[cell_id])
			var held: Array = incompatible_alias.compatibility_alias_index[first_alias]
			incompatible_alias.compatibility_alias_index[first_alias] = targets
			incompatible_alias.compatibility_alias_index[raw_alias] = held
			swapped = true
			break
		first_alias_by_cell[cell_id] = str(raw_alias)
	_check(swapped, "incompatible-alias refusal fixture found a same-cell pair")
	registry = RegistryScript.new()
	var incompatible_alias_result: Dictionary = registry.configure(
			Configuration.OWNER_FIRST_CELLS, incompatible_alias)
	_check(swapped and not bool(incompatible_alias_result.get("ok", false)),
			"registry alias content cannot diverge from the hash-bound canonical manifest")
	registry.queue_free()

	var valid_manifest := _load_manifest()
	registry = RegistryScript.new()
	var configured: Dictionary = registry.configure(
			Configuration.LEGACY_MONOLITH, valid_manifest)
	var second: Dictionary = registry.configure(
			Configuration.OWNER_FIRST_CELLS, valid_manifest)
	if not bool(configured.get("ok", false)):
		printerr("[M11C2-REGISTRY] valid refusal fixture error, cells=%d: %s" % [
				(valid_manifest.get("cells", []) as Array).size(), configured])
	_check(bool(configured.get("ok", false)) and not bool(second.get("ok", false)),
			"a configured registry refuses simultaneous/reconfiguration mode")
	registry.queue_free()


func _test_transactional_mount_failure() -> void:
	var registry = RegistryScript.new()
	registry.name = "TransactionalFailureRegistry"
	add_child(registry)
	var configured: Dictionary = registry.configure(
			Configuration.OWNER_FIRST_CELLS)
	_check(bool(configured.get("ok", false)),
			"transactional-failure fixture accepts the bound production registry")
	if not bool(configured.get("ok", false)):
		registry.queue_free()
		await get_tree().process_frame
		return
	# Corrupt only this already-validated in-memory fixture, never the committed
	# manifest or asset, so the second provider fails after the first was loaded.
	var failed_cell := RegistryScript.TARGET_CELL_IDS[1]
	var failed_descriptor := (registry._cells[failed_cell] as Dictionary).duplicate(true)
	failed_descriptor["resource_path"] = \
			"res://tests/fixtures/does_not_exist_floor01_cell.tscn"
	registry._cells[failed_cell] = failed_descriptor
	var result: Dictionary = registry.mount_default()
	_check(not bool(result.get("ok", false)),
			"partial owner-first composition fails visibly")
	_check(registry.mounted_cell_ids().is_empty(),
			"failed residency request rolls back every newly mounted provider")
	var rolled_back := registry.get_node_or_null(RegistryScript.TARGET_CELL_IDS[0])
	var rolled_back_ref: WeakRef = weakref(rolled_back)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(rolled_back_ref.get_ref() == null,
			"rolled-back provider releases without force deletion")
	var teardown: Dictionary = registry.public_teardown()
	_check(bool(teardown.get("ok", false)) \
			and int(teardown.get("retained_strong_references", -1)) == 0,
			"partial-failure teardown clears registry references")
	registry.queue_free()
	await get_tree().process_frame


func _test_owner_first_registry(manifest: Dictionary) -> void:
	var registry = RegistryScript.new()
	registry.name = "FocusedOwnerFirstRegistry"
	add_child(registry)
	var configured: Dictionary = registry.configure(
			Configuration.OWNER_FIRST_CELLS)
	_check(bool(configured.get("ok", false)),
			"production owner-first registry validates bound manifests/assets")
	if not bool(configured.get("ok", false)):
		printerr("[M11C2-REGISTRY] configure error: %s" % configured)
		registry.queue_free()
		await get_tree().process_frame
		return
	var unknown: Dictionary = registry.mount_residency("NOT_A_RESIDENCY")
	_check(not bool(unknown.get("ok", false)), "unknown residency is refused")
	var mounted: Dictionary = registry.mount_residency(
			"ORISON_INTERIOR_PLUS_FACADE")
	_check(bool(mounted.get("ok", false)),
			"independently addressed Orison interior/facade residency mounts")
	var expected_ids: Array[String] = ["CELL_ORISON_F01_INTERIOR",
			"CELL_ORISON_FACADE_SHELL"]
	_check(registry.mounted_cell_ids() == expected_ids,
			"mounted cells use the explicit reviewed IDs")
	_check(not registry.geometry_nodes_for_cells(expected_ids).is_empty(),
			"mounted owner cells contain production geometry")
	var first_identity := str(manifest.cells[0].semantic_owners[0])
	_check(registry.semantic_owner(first_identity) == str(manifest.cells[0].id),
			"semantic owner index resolves exactly")
	var alias_identity := _single_mounted_alias(manifest, expected_ids)
	_check(not alias_identity.is_empty(), "mounted compatibility alias fixture exists")
	if not alias_identity.is_empty():
		_check(not registry.resolve_compatibility_alias(alias_identity).is_empty(),
				"compatibility alias target resolves through manifest node index")
	for runtime_alias in ["F01_glazing", "F01_stone_trim"]:
		var facade_nodes: Array[Node] = registry.resolve_compatibility_alias(
				runtime_alias)
		_check(not facade_nodes.is_empty() and facade_nodes.all(func(node: Node):
			return registry.owner_cell_for_node(node) \
					== "CELL_ORISON_FACADE_SHELL"),
				"%s preserves the importer-stripped facade alias" % runtime_alias)
	for cell_id in expected_ids:
		_check(str(registry.lifecycle_state(cell_id).get("state", "")) == "RESIDENT",
				"%s lifecycle is RESIDENT" % cell_id)
	var full: Dictionary = registry.mount_default()
	_check(bool(full.get("ok", false)) \
			and registry.mounted_cell_ids().size() == RegistryScript.TARGET_CELL_IDS.size(),
			"default residency expands the same registry to all seventeen cells")
	var alias_mismatches: Array[String] = []
	var split_count := 0
	for raw_alias in manifest.compatibility_alias_index:
		var targets: Array = manifest.compatibility_alias_index[raw_alias]
		if targets.size() > 1:
			split_count += 1
		var resolved: Array[Node] = registry.resolve_compatibility_alias(str(raw_alias))
		if resolved.size() != targets.size():
			alias_mismatches.append("%s:%d/%d" % [raw_alias,
					resolved.size(), targets.size()])
	_check(split_count == 47 and alias_mismatches.is_empty(),
			"every compatibility alias resolves, including all 47 legitimate splits")
	if not alias_mismatches.is_empty():
		printerr("[M11C2-REGISTRY] alias mismatches: " + str(alias_mismatches))
	var weak_cells: Array[WeakRef] = []
	for cell_id in registry.mounted_cell_ids():
		weak_cells.append(weakref(registry.instance_for_cell(cell_id)))
	var teardown: Dictionary = registry.public_teardown()
	_check(bool(teardown.ok) and int(teardown.retained_instances) == 0 \
			and int(teardown.retained_resources) == 0 \
			and int(teardown.retained_strong_references) == 0,
			"owner-first public teardown clears registry references")
	var same_frame_reconfigure: Dictionary = registry.configure(
			Configuration.LEGACY_MONOLITH, manifest)
	var same_frame_mount: Dictionary = registry.mount_default()
	_check(not bool(same_frame_reconfigure.get("ok", false)) \
			and not bool(same_frame_mount.get("ok", false)) \
			and registry.get_node_or_null("LegacyMonolith") == null,
			"teardown retires the registry before queued cells can be replaced")
	await get_tree().process_frame
	await get_tree().process_frame
	for cell_ref in weak_cells:
		_check(cell_ref.get_ref() == null, "queued owner-cell provider is released")
	registry.queue_free()
	await get_tree().process_frame


func _test_legacy_registry(manifest: Dictionary) -> void:
	var registry = RegistryScript.new()
	registry.name = "FocusedLegacyRegistry"
	add_child(registry)
	var configured: Dictionary = registry.configure(
			Configuration.LEGACY_MONOLITH, manifest)
	var mounted: Dictionary = registry.mount_default() if bool(
			configured.get("ok", false)) else {"ok": false}
	_check(bool(configured.get("ok", false)) and bool(mounted.get("ok", false)),
			"explicit rollback configuration mounts the protected monolith")
	_check(registry.mounted_cell_ids().is_empty() \
			and bool(registry.registry_receipt().legacy_monolith_mounted),
			"rollback mode never co-mounts owner cells")
	var legacy_ref: WeakRef = weakref(registry.get_node_or_null("LegacyMonolith"))
	var teardown: Dictionary = registry.public_teardown()
	_check(bool(teardown.ok) and int(teardown.retained_strong_references) == 0,
			"legacy public teardown clears provider references")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(legacy_ref.get_ref() == null, "queued legacy provider is released")
	registry.queue_free()
	await get_tree().process_frame


func _test_public_teardown_restores_global_presentation() -> void:
	var root = TeardownFixture.new()
	root.name = "TeardownPresentationFixture"
	add_child(root)
	var geometry := MeshInstance3D.new()
	geometry.layers = 7
	root.add_child(geometry)
	root.street_core_nodes.append(geometry)
	root._zone_toggle(geometry, false, "street_core")
	_check(geometry.layers == 0, "fixture begins with an active geometry gate")
	var light := OmniLight3D.new()
	light.shadow_enabled = true
	root.add_child(light)
	root.passage_foreign_lights.append(light)
	root.passage_light_saved[light.get_instance_id()] = true
	light.shadow_enabled = false
	var teardown: Dictionary = root.teardown_floor01_geometry()
	_check(bool(teardown.ok), "BuildingRoot public geometry teardown succeeds")
	_check(geometry.layers == 7,
			"public teardown restores host-owned render layers")
	_check(light.shadow_enabled,
			"public teardown restores host-owned shadow state")
	_check(root.passage_late_saved.is_empty() \
			and root.passage_light_saved.is_empty() \
			and root.passage_foreign_lights.is_empty(),
			"public teardown clears global-state reference tables")
	root.queue_free()
	await get_tree().process_frame


func _single_mounted_alias(manifest: Dictionary,
		mounted_ids: Array[String]) -> String:
	for raw_alias in manifest.compatibility_alias_index:
		var alias_identity := str(raw_alias)
		var targets: Array = manifest.compatibility_alias_index[raw_alias]
		if targets.size() != 1:
			continue
		if str((targets[0] as Dictionary).cell_id) in mounted_ids:
			return alias_identity
	return ""


func _load_manifest() -> Dictionary:
	var file := FileAccess.open(RegistryScript.MANIFEST_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}


func _check(condition: bool, label: String) -> void:
	if condition:
		print("[M11C2-REGISTRY] PASS: %s" % label)
		return
	_failures += 1
	printerr("[M11C2-REGISTRY] FAIL: %s" % label)
