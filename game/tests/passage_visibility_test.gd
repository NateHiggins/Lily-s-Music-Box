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
	return nodes.all(func(node): return node.visible and _submits(node))


func _all_hidden(nodes: Array) -> bool:
	return nodes.all(func(node): return (not node.visible) or (not _submits(node)))


## The zone gate suppresses LATE-built nodes via render layers, not
## `visible` — visibility has other legitimate owners (per-floor passes,
## glow, cabinet boot) and layers compose with them instead of stomping.
## "Hidden" for this test means DOES NOT SUBMIT: either owner-hidden or
## zone-gated to layers == 0.
func _submits(node: Node) -> bool:
	if node is VisualInstance3D:
		return (node as VisualInstance3D).layers != 0
	return true


## find_children returns DESCENDANTS only, so a leaf geometry owner (the
## street-end multimeshes) must be tested as its own subtree — the first
## draft forgot that and reported a leaf as "restored: no" forever.
func _owner_geometry(owner: Node) -> Array:
	var out: Array = owner.find_children("*", "GeometryInstance3D", true, false)
	if owner is GeometryInstance3D:
		out.append(owner)
	return out


func _named_owner_hidden(owner: Node) -> bool:
	for g in _owner_geometry(owner):
		if g.is_visible_in_tree() and _submits(g):
			return false
	return true


func _named_owner_showing(owner: Node) -> bool:
	for g in _owner_geometry(owner):
		if g.is_visible_in_tree() and _submits(g):
			return true
	return false


## The audit probe's core claim, inline: with the eye inside the hall, every
## visible F01 draw belongs to a list. A regression here means a NEW builder
## started parenting geometry into F01 without the sweep noticing — which is
## impossible while the sweep runs on the transition, and that is the point.
func _count_unclassified_visible(root: Node) -> int:
	var known := {}
	for arr: Array in [root.passage_interior_nodes, root.passage_shell_nodes,
			root.passage_foreign_f01_nodes, root.passage_late_interior_nodes,
			root.passage_late_foreign_nodes, root.passage_shared_f01_nodes]:
		for g in arr:
			if is_instance_valid(g):
				known[g.get_instance_id()] = true
	var missed := 0
	for candidate in root.floor_nodes["F01"].find_children(
			"*", "GeometryInstance3D", true, false):
		var g := candidate as GeometryInstance3D
		if g == null or not g.is_visible_in_tree():
			continue
		if String(g.name).contains("_retail_passage_proxy_"):
			continue
		if known.has(g.get_instance_id()):
			continue
		# Zone-owned actors and registered props are gated per node by the
		# prop loop; their child geometry is classified by that ownership.
		var cursor: Node = g
		var owned := false
		while cursor != null:
			if cursor.is_in_group("passage_runtime"):
				owned = true
				break
			cursor = cursor.get_parent()
		if not owned:
			missed += 1
	return missed


func _ready() -> void:
	# The 03:00 composition assertions require the canonical clock. Without
	# this pin the test follows the real wall clock and fails in the
	# 06:30-02:00 trading window — found 2026-08-16 when a green battery
	# went red between runs purely because the machine crossed 2 AM.
	OS.set_environment("DAYNIGHT", "0")
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
	# 69 marker actors + 3 handcarts + the hours owner + the V4 passage light
	# pass, which `fdfa560` added to passage_runtime_nodes on 2026-08-17 so the
	# zone gate would hide its lanterns with everything else. The count was
	# authored at 73 by PS6 on 2026-08-15 and nothing updated it, so this check
	# has been failing on a correct build ever since.
	#
	# Printing the count is the actual repair. A bare `== 73` that reports only
	# FAIL tells the next reader nothing about whether the building gained an
	# actor or lost one, which is the only thing they need to know.
	_check("69 marker actors, 3 handcarts, hours owner and the V4 light "
			+ "pass are zone-owned (%d)" % actors.size(),
			actors.size() == 74)
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
	var architectural_shell := shell.filter(func(node):
		return not node.is_in_group("passage_hours_geometry"))
	_check("architectural hall shell submits after crossing the portal",
			_all_visible(architectural_shell))
	_check("hours buffers restore their exact 03:00 composition",
			root.passage_finish.hours_director._closed_grilles.visible
			and not root.passage_finish.hours_director._folded_regular.visible
			and root.passage_finish.hours_director._folded_night_service.visible)
	_check("Passage actors submit after crossing the portal", _all_visible(actors))
	_check("portal glazing remains submitted inside", _all_visible(proxies))

	# The expanded hall is bounded, not a broad south-of-building heuristic.
	root._apply_visibility(Vector3(14.0, 1.0, 50.0))
	_check("main hall remains inside PASSAGE", root.passage_visible)
	_check("PASSAGE retains its F01 host but not the Orison apartment stack",
			root.floor_nodes["F01"].visible
			and ["F02", "F03", "F04", "F05", "F06", "ROOF"].all(
					func(fid): return not root.floor_nodes[fid].visible))
	var foreign_f01: Array = root.functional_props_by_floor.get("F01", []).filter(
			func(prop): return not prop.is_in_group("passage_runtime"))
	_check("non-Passage F01 actors do not submit inside the hall",
			foreign_f01.size() > 0 and _all_hidden(foreign_f01))
	_check("the giant non-Passage F01 site host is absent inside the hall",
			root.passage_foreign_f01_nodes.size() > 0
			and _all_hidden(root.passage_foreign_f01_nodes))
	# LATE-BUILT F01 geometry — the post-index leak. `_index_passage_geometry`
	# runs before VantryPointNetwork, the detail passes, the boards, the
	# wall-art catalogs, MaintenanceHeadquarters, the street ends and the
	# arcade spawner have constructed anything; before the transition sweep
	# existed, 532 of their draws (~500 shadow casters) were still submitted
	# from inside the hall. These checks hold the sweep to its contract.
	var named_foreign := ["OrisonOriginalSalesBoard", "LobbyBulletinBoard",
			"RealityMaintenanceHeadquarters", "LobbyMailBank",
			"Arcade_lobby_cab", "StreetEndHoardingFaces"]
	var found_named: Array = []
	for wanted in named_foreign:
		var node: Node = root.floor_nodes["F01"].find_child(wanted, true, false)
		_check("late-built %s exists to be owned" % wanted, node != null)
		if node != null:
			found_named.append(node)
	var late_foreign: Array = root.passage_late_foreign_nodes
	var late_interior: Array = root.passage_late_interior_nodes
	root._apply_visibility(Vector3(14.0, 1.0, 50.0))
	_check("late-built foreign F01 draws do not submit inside the hall",
			late_foreign.size() > 300 and _all_hidden(late_foreign))
	_check("every named late foreign owner is hidden inside the hall",
			found_named.all(_named_owner_hidden))
	_check("late-built Passage-side draws stay submitted inside the hall",
			late_interior.size() > 100 and _all_visible(late_interior))
	_check("zero unclassified visible F01 draws inside the hall",
			_count_unclassified_visible(root) == 0)

	# Leaving restores what the gate saved — to its OWN prior state, not to
	# a forced true: window glow and cabinet boot own their quads' downtime.
	root._apply_visibility(Vector3(0.0, 1.0, 9.0))
	for owner in found_named:
		if not _named_owner_showing(owner):
			print("  [restore debug] %s: no visible geometry after exit"
					% owner.name)
	_check("leaving PASSAGE restores late foreign geometry",
			found_named.all(_named_owner_showing))
	_check("leaving PASSAGE re-hides late Passage-side draws",
			_all_hidden(late_interior))
	var stale_saves := 0
	for id in root.passage_late_saved:
		var obj: Object = instance_from_id(id)
		if obj != null and late_foreign.has(obj):
			stale_saves += 1
	_check("the zone gate's save table drains on restore", stale_saves == 0)

	root._apply_visibility(Vector3(16.0, 12.0, 34.0))
	_check("the aerial street-elevation station is not inside PASSAGE",
			not root.passage_visible and root.floor_nodes["F06"].visible
			and _all_visible(root.passage_foreign_f01_nodes))
	root._apply_visibility(Vector3(3.99, 1.0, 50.0))
	_check("outside the west enclosing fabric is not PASSAGE",
			not root.passage_visible)

	# The streaming answer changes at boundaries, not for every centimetre of
	# motion. Production physics therefore caches the exact region signature;
	# direct `_apply_visibility()` probes above remain authoritative.
	root.view_override = null
	root.show_all_floors = false
	root.player.global_position = Vector3(4.3, 3.35, 0.0)
	root._visibility_key = -1
	root._visibility_apply_count = 0
	root._update_floor_visibility()
	var first_apply: int = root._visibility_apply_count
	root.player.global_position += Vector3(0.05, 0.0, 0.05)
	root._update_floor_visibility()
	_check("motion inside one visibility region does not rescan every actor",
			first_apply == 1 and root._visibility_apply_count == first_apply)
	root.player.global_position = Vector3(14.0, 1.0, 50.0)
	root._update_floor_visibility()
	_check("crossing into PASSAGE invalidates the visibility cache",
			root._visibility_apply_count == first_apply + 1
			and root.passage_visible)
	root.show_all_floors = true
	root._update_floor_visibility()
	_check("the all-floors override invalidates the visibility cache",
			root._visibility_apply_count == first_apply + 2
			and root.floor_nodes.values().all(
					func(floor): return floor.visible))

	# Direct attribution: no frames advance inside these loops, so weather,
	# residents, traffic and renderer population cannot be mistaken for the
	# script cost. The timing is reported, not asserted; the structural cache
	# behavior above is the deterministic contract.
	const PROFILE_ITERATIONS := 500
	var profile_eye := Vector3(16.0, 12.0, 34.0)
	var signature_start := Time.get_ticks_usec()
	for i in PROFILE_ITERATIONS:
		root._visibility_signature(profile_eye)
	var signature_usec := Time.get_ticks_usec() - signature_start
	var scan_start := Time.get_ticks_usec()
	for i in PROFILE_ITERATIONS:
		root._apply_visibility(profile_eye)
	var scan_usec := Time.get_ticks_usec() - scan_start
	print("[PASSAGE VISIBILITY] direct profile: %.3f ms/signature, "
			% (float(signature_usec) / PROFILE_ITERATIONS / 1000.0)
			+ "%.3f ms/full scan, %.3f ms avoided"
			% [float(scan_usec) / PROFILE_ITERATIONS / 1000.0,
					float(scan_usec - signature_usec)
					/ PROFILE_ITERATIONS / 1000.0])

	print("[PASSAGE VISIBILITY] RESULT: %s (%d failures)" %
			["PASS" if _fails == 0 else "FAIL", _fails])
	get_tree().quit(_fails)
