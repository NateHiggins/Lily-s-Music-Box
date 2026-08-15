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
	_check("a material enclosed-F01 population is indexed", core.size() > 1000)

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
	var neon: Node = root.find_child("F01_NEON_TENANT", true, false)
	var neon_geometry := _geometry_under(neon)
	_check("a facade-touching compound neon owner stays atomic",
			neon_geometry.size() > 20 and _none_indexed(neon_geometry, core))
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
			and _all_nonzero(neon_geometry))

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
