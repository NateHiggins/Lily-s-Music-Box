extends Node
## Proves the M0.5 zone boundary with the actual imported scene.
##
## Source records are necessary but insufficient: an assembly can still fall
## into a floor-wide render buffer during Blender export.  This test asks the
## live tree which named draws the build produced, then crosses the ruled
## portal plane and verifies both imported geometry and marker-built actors.

var _fails := 0


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
	if not ok:
		_fails += 1


func _all_visible(nodes: Array) -> bool:
	return nodes.all(func(node): return node.visible)


func _all_hidden(nodes: Array) -> bool:
	return nodes.all(func(node): return not node.visible)


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	await get_tree().create_timer(1.6).timeout
	# Stop the parked lobby player from immediately replacing each explicit
	# probe position in BuildingRoot._physics_process().
	root.set_physics_process(false)

	var interiors: Array = root.passage_interior_nodes
	var shell: Array = root.passage_shell_nodes
	var actors: Array = root.passage_runtime_nodes
	var proxies: Array = []
	for candidate in root.floor_nodes["F01"].find_children(
			"*", "GeometryInstance3D", true, false):
		if String(candidate.name).contains("_retail_passage_proxy_"):
			proxies.append(candidate)

	_check("eleven shop batches produced imported interior draws",
			interiors.size() > 11)
	_check("hall and vault produced separately gated shell draws",
			shell.size() > 0)
	_check("69 marker actors plus three handcarts are zone-owned",
			actors.size() == 72)
	_check("three finish draws join the gated shell",
			get_tree().get_nodes_in_group("passage_finish_geometry").size() == 3
			and get_tree().get_nodes_in_group("passage_pushcarts").size() == 3)
	_check("street owns a separate portal-glazing proxy", proxies.size() > 0)

	# The street side of the exact portal plane owns only its shallow proxy.
	root._apply_visibility(Vector3(14.0, 1.0, 28.316))
	_check("shop interiors do not submit from STREET", _all_hidden(interiors))
	_check("hall shell does not submit from STREET", _all_hidden(shell))
	_check("Passage actors do not submit from STREET", _all_hidden(actors))
	_check("portal glazing remains submitted from STREET", _all_visible(proxies))

	# The first point beyond the plane is already in the architectural throat.
	root._apply_visibility(Vector3(14.0, 1.0, 28.317))
	_check("shop interiors submit after crossing the portal",
			_all_visible(interiors))
	_check("hall shell submits after crossing the portal", _all_visible(shell))
	_check("Passage actors submit after crossing the portal", _all_visible(actors))
	_check("portal glazing remains submitted inside", _all_visible(proxies))

	# The expanded hall is bounded, not a broad south-of-building heuristic.
	root._apply_visibility(Vector3(14.0, 1.0, 50.0))
	_check("main hall remains inside PASSAGE", root.passage_visible)
	root._apply_visibility(Vector3(3.99, 1.0, 50.0))
	_check("outside the west enclosing fabric is not PASSAGE",
			not root.passage_visible)

	print("[PASSAGE VISIBILITY] RESULT: %s (%d failures)" %
			["PASS" if _fails == 0 else "FAIL", _fails])
	get_tree().quit(_fails)
