extends Node
## Visibility-only proof over actual builders and V2 production composition.
## Bare blockouts are retired sequentially; no runtime actors are teleported.

const BLOCKOUT := preload("res://scenes/building/orison_v2_blockout.tscn")
const Selector := preload("res://scripts/building/building_root_selector.gd")
var checks: Array = []
var failed := 0
var output := ""
var witnesses: Dictionary = {}
var target_paths: Array[String] = []
var envelope_paths: Array[String] = []
var landing_paths: Array[String] = []

func _ready() -> void:
	output = OS.get_environment("SHOT_DIR")
	if output.is_empty() or DirAccess.make_dir_recursive_absolute(output) != OK:
		push_error("V2 RESERVATION requires writable SHOT_DIR")
		get_tree().quit(2)
		return
	CampaignTime.set_frozen_for_tests(true)
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	RealityState.data.intro_complete = true
	RealityState.data.first_shift = {"phase": FirstShiftDirector.PHASE_COMPLETE}
	_check("authored campaign calendar is valid", CampaignClock.new().configure_date(1928,11,10,180.0))
	var acoustic_before: Dictionary = AcousticGraphData.nodes.duplicate(true)
	var review := BLOCKOUT.instantiate() as Node3D
	add_child(review)
	var layout: Dictionary = review.get("layout")
	for row: Dictionary in layout.get("envelopes", []): envelope_paths.append(str(row.id))
	for row: Dictionary in layout.get("lift_landings", []): landing_paths.append(str(row.id) + "/Clearance")
	target_paths.append_array(envelope_paths)
	target_paths.append_array(landing_paths)
	_check("actual schema retains seventy envelopes and eight landing clearances", envelope_paths.size() == 70 and landing_paths.size() == 8)
	_check("dedicated blockout defaults to reservation display", review.get("show_reservation_volumes") == true)
	var review_rows: Dictionary = _snapshot(review)
	witnesses.review = review_rows
	_check("dedicated review resolves every reservation exactly once", _unique_targets(review))
	_check("dedicated review displays all seventy envelopes", _visible_count(review_rows, envelope_paths) == 70)
	_check("dedicated review displays all eight landing clearances", _visible_count(review_rows, landing_paths) == 8)
	_check("dedicated reservations contain no collision owners", _targets_nonphysical(review))
	var review_weak: WeakRef = weakref(review)
	review.queue_free()
	await _retirement_frames()
	witnesses.retirement = {"review": review_weak.get_ref() == null}
	_check("actual dedicated review blockout retires", review_weak.get_ref() == null)
	var hidden := BLOCKOUT.instantiate() as Node3D
	hidden.set("show_reservation_volumes", false)
	add_child(hidden)
	var hidden_rows: Dictionary = _snapshot(hidden)
	witnesses.hidden = hidden_rows
	_check("hidden blockout resolves every reservation exactly once", _unique_targets(hidden))
	_check("hidden blockout suppresses all seventy envelopes", _visible_count(hidden_rows, envelope_paths) == 0)
	_check("hidden blockout suppresses all eight landing clearances", _visible_count(hidden_rows, landing_paths) == 0)
	var review_comparison: Dictionary = _comparison_identity(review_rows)
	var hidden_comparison: Dictionary = _comparison_identity(hidden_rows)
	witnesses.comparison_identity = {"review": _identity_evidence(review_comparison), "hidden": _identity_evidence(hidden_comparison)}
	var identities_valid: bool = review_comparison.valid == true and hidden_comparison.valid == true
	_check("authored paths and unambiguous shape identities retain exact transforms geometry and semantics", identities_valid and _geometry(review_comparison.rows) == _geometry(hidden_comparison.rows))
	_check("all collision owners shapes and masks remain exact", identities_valid and _collision_rows(review_comparison.rows) == _collision_rows(hidden_comparison.rows))
	_check("every non-reservation display state remains exact", identities_valid and _other_display(review_comparison.rows) == _other_display(hidden_comparison.rows))
	_check("hidden reservations contain no collision owners", _targets_nonphysical(hidden))
	var hidden_weak: WeakRef = weakref(hidden)
	hidden.queue_free()
	await _retirement_frames()
	witnesses.retirement.hidden = hidden_weak.get_ref() == null
	_check("actual hidden blockout retires", hidden_weak.get_ref() == null)
	Selector.reset_for_tests("v2")
	var shell := CampaignShell.new()
	shell.sleep_manual_clock = true
	add_child(shell)
	var world := shell.active_world as OrisonV2RuntimeRoot
	_check("CampaignShell composes the actual V2 production root", world != null and world.scene_file_path == Selector.path_for("v2"))
	_check("actual V2 production startup succeeds", world != null and not world.startup_failed)
	var production: Node3D = world._blockout if world != null and not world.startup_failed else null
	var production_rows: Dictionary = _snapshot(production) if production != null else {}
	witnesses.production_targets = _targets_only(production_rows)
	witnesses.production_flag = production.get("show_reservation_volumes") if production != null else null
	_check("production selects reservation suppression before construction", production != null and production.get("show_reservation_volumes") == false)
	_check("production resolves every reservation exactly once", production != null and _unique_targets(production))
	_check("production suppresses all seventy envelopes", _visible_count(production_rows, envelope_paths) == 0)
	_check("production suppresses all eight landing clearances", _visible_count(production_rows, landing_paths) == 0)
	_check("production retains exact reservation transforms bounds and semantic records", _geometry(_targets_only(production_rows)) == _geometry(_targets_only(review_rows)))
	_check("production reservations contain no collision owners", production != null and _targets_nonphysical(production))
	var terminal: Node3D = world.adapter.resolve("F04_B_MONITOR_01") as Node3D if production != null else null
	var semantic: Node3D = world.adapter.resolve("F04_B_MONITOR_01_Semantic") as Node3D if production != null else null
	_check("actual mounted terminal and original semantic anchor remain distinct", terminal is SignalTerminalProp and semantic != null and terminal != semantic and terminal.global_position.is_equal_approx(semantic.global_position))
	var world_weak: WeakRef = weakref(world) if world != null else null
	var shell_weak: WeakRef = weakref(shell)
	shell.queue_free()
	await _retirement_frames()
	witnesses.retirement.production = world_weak != null and world_weak.get_ref() == null
	witnesses.retirement.shell = shell_weak.get_ref() == null
	witnesses.retirement.acoustic = AcousticGraphData.nodes == acoustic_before
	_check("actual V2 production root retires", world_weak != null and world_weak.get_ref() == null)
	_check("actual CampaignShell retires", shell_weak.get_ref() == null)
	_check("retirement restores original acoustic records", AcousticGraphData.nodes == acoustic_before)
	witnesses.complete = true
	witnesses.target_paths = target_paths
	witnesses.envelope_paths = envelope_paths
	witnesses.landing_paths = landing_paths
	_finish()

func _snapshot(root: Node3D) -> Dictionary:
	var rows: Dictionary = {}
	var nodes: Array[Node] = [root]
	nodes.append_array(root.find_children("*", "", true, false))
	for node: Node in nodes:
		var path := str(root.get_path_to(node))
		var row: Dictionary = {"class": node.get_class(), "script": "", "metadata": {}}
		var script := node.get_script() as Script
		if script != null: row.script = script.resource_path
		for key: StringName in node.get_meta_list(): row.metadata[str(key)] = _exact(node.get_meta(key))
		if node is Node3D:
			row.transform = _exact((node as Node3D).transform)
			row.global_transform = _exact((node as Node3D).global_transform)
			row.global_position_values = _vec((node as Node3D).global_position)
			row.visible = (node as Node3D).visible
			row.visible_in_tree = (node as Node3D).is_visible_in_tree()
		if node is MeshInstance3D:
			var mesh := node as MeshInstance3D
			row.layers = mesh.layers
			row.local_aabb = _exact(mesh.get_aabb())
			row.world_aabb = _exact(mesh.global_transform * mesh.get_aabb())
			var bounds: AABB = mesh.global_transform * mesh.get_aabb()
			row.world_aabb_values = [_vec(bounds.position), _vec(bounds.size)]
			row.mesh_class = mesh.mesh.get_class() if mesh.mesh != null else ""
			row.box_size = _exact((mesh.mesh as BoxMesh).size) if mesh.mesh is BoxMesh else ""
			row.surface_count = mesh.mesh.get_surface_count() if mesh.mesh != null else 0
			row.collision_descendants = []
			for child: Node in mesh.find_children("*", "", true, false):
				if child is CollisionObject3D or child is CollisionShape3D:
					row.collision_descendants.append(str(root.get_path_to(child)))
			row.materials = []
			for slot in int(row.surface_count):
				var material: Material = mesh.get_active_material(slot)
				var m: Dictionary = {"class": material.get_class() if material != null else "", "path": material.resource_path if material != null else ""}
				if material is BaseMaterial3D:
					m.albedo = _exact((material as BaseMaterial3D).albedo_color)
					m.roughness = (material as BaseMaterial3D).roughness
					m.transparency = (material as BaseMaterial3D).transparency
				row.materials.append(m)
		if node is CollisionObject3D:
			row.collision_layer = (node as CollisionObject3D).collision_layer
			row.collision_mask = (node as CollisionObject3D).collision_mask
		if node is StaticBody3D:
			row.constant_linear_velocity = _exact((node as StaticBody3D).constant_linear_velocity)
			row.constant_angular_velocity = _exact((node as StaticBody3D).constant_angular_velocity)
		if node is CollisionShape3D:
			var shape := node as CollisionShape3D
			row.disabled = shape.disabled
			row.shape_class = shape.shape.get_class() if shape.shape != null else ""
			row.shape_margin = shape.shape.margin if shape.shape != null else -1.0
			row.box_shape_size = _exact((shape.shape as BoxShape3D).size) if shape.shape is BoxShape3D else ""
		rows[path] = row
	return rows

func _unique_targets(root: Node3D) -> bool:
	var seen: Dictionary = {}
	for path: String in target_paths:
		var node := root.get_node_or_null(NodePath(path)) as MeshInstance3D
		if node == null or seen.has(path): return false
		seen[path] = true
		var matches: Array[Node] = root.find_children(str(node.name), "MeshInstance3D", true, false)
		# Landing children share the legitimate name Clearance; the full path is
		# the identity. Top-level authored envelope identities must be unique.
		if envelope_paths.has(path) and matches.size() != 1: return false
	return seen.size() == 78

func _targets_nonphysical(root: Node3D) -> bool:
	for path: String in target_paths:
		var node := root.get_node_or_null(NodePath(path))
		if node == null or node is CollisionObject3D or not node.find_children("*", "CollisionObject3D", true, false).is_empty() or not node.find_children("*", "CollisionShape3D", true, false).is_empty(): return false
	return true

func _visible_count(rows: Dictionary, paths: Array[String]) -> int:
	var count := 0
	for path: String in paths:
		if not rows.has(path): return -1
		var row: Dictionary = rows[path]
		if row.get("visible") == true and row.get("visible_in_tree") == true: count += 1
		elif row.get("visible") != false or row.get("visible_in_tree") != false: return -1
	return count

func _comparison_identity(raw_rows: Dictionary) -> Dictionary:
	# Preserve raw snapshot keys. Only a unique anonymous leaf shape receives
	# a comparison identity under its unchanged authored parent path.
	var failure: Dictionary = {"valid": false, "rows": {}, "aliases": {}, "reference_rewrites": 0, "raw_count": raw_rows.size()}
	var pattern := RegEx.new()
	if pattern.compile("(^|/)@CollisionShape3D@[0-9]+$") != OK: return failure
	var nonleaves: Dictionary = {}
	for raw_path: String in raw_rows:
		var ancestor: String = raw_path.get_base_dir()
		while not ancestor.is_empty() and ancestor != ".":
			nonleaves[ancestor] = true
			ancestor = ancestor.get_base_dir()
	var identities: Dictionary = {}
	var aliases: Dictionary = {}
	var occupied: Dictionary = {}
	for raw_path: String in raw_rows:
		var identity: String = raw_path
		var match_result: RegExMatch = pattern.search(raw_path)
		if match_result != null:
			if raw_rows[raw_path].get("class") != "CollisionShape3D" or nonleaves.has(raw_path): return failure
			var parent: String = raw_path.get_base_dir()
			if not raw_rows.has(parent if not parent.is_empty() else "."): return failure
			identity = parent + "/@CollisionShape3D" if not parent.is_empty() else "@CollisionShape3D"
			aliases[raw_path] = identity
		if occupied.has(identity): return failure
		occupied[identity] = raw_path
		identities[raw_path] = identity
	var normalized: Dictionary = {}
	var rewrites := 0
	for raw_path: String in raw_rows:
		var row: Dictionary = raw_rows[raw_path].duplicate(true)
		if row.has("collision_descendants"):
			var references: Array = []
			if not row.collision_descendants is Array: return failure
			for reference: Variant in row.collision_descendants:
				if not reference is String or not identities.has(reference): return failure
				var canonical: String = identities[reference]
				if references.has(canonical): return failure
				references.append(canonical)
				if canonical != reference: rewrites += 1
			row.collision_descendants = references
		normalized[identities[raw_path]] = row
	return {"valid": true, "rows": normalized, "aliases": aliases, "reference_rewrites": rewrites, "raw_count": raw_rows.size()}

func _identity_evidence(comparison: Dictionary) -> Dictionary:
	return {"valid": comparison.valid, "aliases": comparison.aliases,
		"reference_rewrites": comparison.reference_rewrites, "raw_count": comparison.raw_count}

func _geometry(rows: Dictionary) -> Dictionary:
	var copy: Dictionary = rows.duplicate(true)
	for row: Dictionary in copy.values():
		row.erase("visible")
		row.erase("visible_in_tree")
	return copy

func _collision_rows(rows: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for path: String in rows:
		if rows[path].has("collision_layer") or rows[path].has("shape_class"):
			result[path] = rows[path]
	return result

func _other_display(rows: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for path: String in rows:
		if not target_paths.has(path) and rows[path].has("visible"):
			result[path] = [rows[path].visible, rows[path].visible_in_tree]
	return result

func _targets_only(rows: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for path: String in target_paths:
		if rows.has(path): result[path] = rows[path]
	return result

func _exact(value: Variant) -> String:
	# Binary Variant encoding retains exact float components; avoid rounded
	# display strings as transform/AABB equality oracles.
	return var_to_bytes(value).hex_encode()

func _vec(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

func _retirement_frames() -> void:
	for _index in 4: await get_tree().process_frame
	await get_tree().create_timer(0.2).timeout

func _check(label: String, okay: bool) -> void:
	checks.append({"label": label, "passed": okay})
	print("[V2 RESERVATION] %s %s" % ["PASS" if okay else "FAIL", label])
	if not okay: failed += 1

func _finish() -> void:
	var file := FileAccess.open(output.path_join("reservation_display.json"), FileAccess.WRITE)
	if file == null:
		push_error("V2 RESERVATION receipt write failed")
		get_tree().quit(2)
		return
	file.store_string(JSON.stringify({"schema": "astra.v2-reservation-display.probe.v1", "pid": OS.get_process_id(),
		"root": "v2", "renderer": RenderingServer.get_current_rendering_method(), "checks": checks,
		"failures": failed, "witnesses": witnesses,
		"scope": "raw generated paths retained; exact authored paths plus proven unique anonymous leaf-shape identities for geometry/semantic/collision and display comparison; actual V2 targets; no route, input or perceptual proof"}, "\t"))
	file.close()
	print("[V2 RESERVATION] checks=%d failures=%d" % [checks.size(), failed])
	get_tree().quit(0 if failed == 0 else 1)
