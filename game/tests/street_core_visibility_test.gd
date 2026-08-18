extends Node
## Focused proof for T7c's low-STREET enclosed-geometry gate.

var _passed := 0
var _failed := 0


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	await get_tree().create_timer(1.5).timeout
	root._index_street_core_geometry()
	var core: Array = root.street_core_nodes
	_check("both enclosed F01 masses produce a material index", core.size() > 1300)
	var harukiya_core: Array = core.filter(func(geometry):
		return root._fully_in_harukiya_core(geometry))
	_check("the ruled Harukiya prism contributes its own population",
			harukiya_core.size() > 250)

	var original_layers := {}
	for geometry in core:
		if is_instance_valid(geometry):
			original_layers[geometry.get_instance_id()] = geometry.layers

	var entry: Node = root.find_child("F01_DOOR_06", true, false)
	var entry_geometry := _geometry_under(entry)
	_check("the authored street entry exists", entry != null
			and not entry_geometry.is_empty())
	_check("the authored street entry is never indexed as enclosed",
			_none_indexed(entry_geometry, core))
	var glow_geometry := _geometry_under(root.window_glow)
	_check("WindowGlow remains the exterior occupied-room view",
			not glow_geometry.is_empty() and _none_indexed(glow_geometry, core))
	# The owner's report: the lower windows lose "their treatment and glass
	# entirely" from the carriageway. Both whole-floor batches sit inside the
	# 15.2 x 11.2 core envelope, so both were indexed and layered off, taking
	# every ground-floor pane and every limestone jamb, head, projecting sill
	# and sash meeting rail with them.
	var envelope: Array = []
	for batch in ["F01_glazing", "F01_stone_trim"]:
		var node: Node = root.floor_nodes["F01"].get_node_or_null(batch)
		_check("%s is a real draw to argue about" % batch,
				node is GeometryInstance3D)
		if node is GeometryInstance3D:
			envelope.append(node)
	_check("the ground floor's glass and joinery are never enclosed content",
			envelope.size() == 2 and _none_indexed(envelope, core))
	# And they survive only because they are named. The core envelope is the
	# STREET REGION, 15.2 x 11.2, and the building stands inside it, so the
	# geometric test on its own still calls both batches enclosed. Deleting
	# the protection because "nothing indexes them anyway" puts the owner's
	# raw holes in the brick straight back.
	_check("the containment test alone would still swallow both batches",
			envelope.size() == 2 and envelope.all(func(node):
				return root._fully_in_street_core(node)))
	# A multimesh or particle node reports an EMPTY aabb here, and an empty box
	# at the origin passes any containment test that spans the origin. That is
	# how the street-end hoardings at |x| ~ 20 m came to be indexed as enclosed
	# F01 content. Nothing unmeasurable may be classed as enclosed.
	var degenerate: Array = core.filter(func(geometry):
		return root._measured_world_aabb(geometry).size.length_squared() <= 0.0)
	_check("nothing is indexed on an extent nobody computed",
			degenerate.is_empty())
	var street_end: Array = []
	for node in root.get_tree().get_nodes_in_group("street_end_architecture"):
		street_end.append_array(_geometry_under(node))
	_check("the street-end works stay visible from the street they close",
			street_end.size() >= 2 and _none_indexed(street_end, core))
	var neon: Node = root.find_child("F01_NEON_TENANT", true, false)
	var neon_geometry := _geometry_under(neon)
	_check("a facade-touching compound neon owner stays atomic",
			neon_geometry.size() > 5 and _none_indexed(neon_geometry, core))
	var bar_stage: Node = root.find_child("F01_BAR_STAGE_SIGN", true, false)
	var bar_stage_geometry := _geometry_under(bar_stage)
	_check("the deep Harukiya stage sign is enclosed, not exterior",
			not bar_stage_geometry.is_empty()
			and _all_indexed(bar_stage_geometry, core))
	var bar_front: Node = root.find_child("F01_BAR_SIGNAGE", true, false)
	var bar_front_geometry := _geometry_under(bar_front)
	_check("Harukiya street-face signage remains eligible",
			not bar_front_geometry.is_empty()
			and _none_indexed(bar_front_geometry, core))
	var resident_geometry: Array = []
	for node in root.find_children("NPC_*", "Node3D", true, false):
		resident_geometry.append_array(_geometry_under(node))
	_check("moving residents are not frozen into a static spatial class",
			not resident_geometry.is_empty()
			and _none_indexed(resident_geometry, core))

	var street := Vector3(-16.0, 0.27, 13.5)
	root._apply_visibility(street)
	_check("low STREET activates the enclosed-content blocker",
			not root.street_core_visible)
	_check("every indexed core draw leaves all render passes in STREET",
			_all_layers(core, 0))
	_check("entry, WindowGlow and complete neon remain eligible outdoors",
			_all_nonzero(entry_geometry) and _all_nonzero(glow_geometry)
			and _all_nonzero(neon_geometry)
			and _all_nonzero(bar_front_geometry))
	_check("the windows keep their glass and joinery from the carriageway",
			envelope.size() == 2 and _all_nonzero(envelope))
	_check("the street-end works are lit from the carriageway",
			not street_end.is_empty() and _all_nonzero(street_end))

	var bar_interior := Vector3(3.0, -1.39, 34.0)
	root._apply_visibility(bar_interior)
	_check("descending into Harukiya restores its complete interior",
			root.street_core_visible and _layers_match(core, original_layers))

	var lobby := Vector3(0.0, 0.27, 9.0)
	root._apply_visibility(lobby)
	_check("entering ORISON restores the core gate", root.street_core_visible)
	_check("ORISON restores each node's exact prior render layers",
			_layers_match(core, original_layers))

	root._apply_visibility(Vector3(16.0, 12.0, 34.0))
	_check("the aerial station is not treated as low STREET",
			root.street_core_visible and _layers_match(core, original_layers))

	var overlap: GeometryInstance3D
	for geometry in core:
		if root.passage_late_foreign_nodes.has(geometry):
			overlap = geometry
			break
	_check("the STREET and PASSAGE gates have a measured overlap owner",
			overlap != null)
	root._apply_visibility(street)
	root._apply_visibility(Vector3(14.0, 1.0, 50.0))
	_check("direct STREET to PASSAGE keeps foreign overlap hidden",
			overlap != null and overlap.layers == 0)
	root._apply_visibility(street)
	_check("direct PASSAGE to STREET keeps enclosed overlap hidden",
			overlap != null and overlap.layers == 0)
	root._apply_visibility(lobby)
	_check("both blockers drain before overlap is restored in ORISON",
			overlap != null
			and overlap.layers == int(original_layers[overlap.get_instance_id()])
			and not root._zone_layer_blocks.has(overlap.get_instance_id()))

	print("[STREET CORE TEST] %d passed, %d failed" % [_passed, _failed])
	get_tree().quit(0 if _failed == 0 else 1)


func _geometry_under(owner: Node) -> Array:
	var out: Array = []
	if owner == null:
		return out
	_collect(owner, out)
	return out


func _collect(node: Node, out: Array) -> void:
	if node is SubViewport:
		return
	if node is GeometryInstance3D:
		out.append(node)
	for child in node.get_children():
		_collect(child, out)


func _none_indexed(geometry: Array, core: Array) -> bool:
	return geometry.all(func(node): return not core.has(node))


func _all_indexed(geometry: Array, core: Array) -> bool:
	return geometry.all(func(node): return core.has(node))


func _all_layers(geometry: Array, wanted: int) -> bool:
	return geometry.all(func(node):
		return not is_instance_valid(node) or node.layers == wanted)


func _all_nonzero(geometry: Array) -> bool:
	return geometry.all(func(node):
		return not is_instance_valid(node) or node.layers != 0)


func _layers_match(geometry: Array, wanted: Dictionary) -> bool:
	for node in geometry:
		if not is_instance_valid(node):
			continue
		var id: int = node.get_instance_id()
		if not wanted.has(id) or node.layers != int(wanted[id]):
			return false
	return true


func _check(label: String, condition: bool) -> void:
	if condition:
		_passed += 1
		print("  PASS  " + label)
	else:
		_failed += 1
		push_error("  FAIL  " + label)
