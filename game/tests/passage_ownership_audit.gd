extends Node
## Every GeometryInstance3D under F01, classified against the Passage zone
## index — and the count that matters is the UNCLASSIFIED one.
##
##     godot --headless --path game res://tests/PassageOwnershipAudit.tscn
##
## `_index_passage_geometry()` (building_root.gd:919) classifies the F01
## subtree exactly once, at line 210 — before VantryPointNetwork,
## HeightmapPass, OrisonDetailPass, MaintenanceHeadquarters, the lobby
## notices and the Orison ad board have built anything. Geometry parented
## into F01 after that line lands in NO list, so `_set_passage_visibility`
## cannot hide it when the player is inside the Passage: it is foreign-zone
## work submitted at the exact station that blocks M0.5.
##
## Classification, in precedence order, mirroring the index and its two
## explicit exemptions:
##   interior   — in passage_interior_nodes  (`_retail_shop_`)
##   shell      — in passage_shell_nodes     (`_retail_passage_shell_` plus
##                the finish pass's registered draws, building_root.gd:300)
##   proxy      — name contains `_retail_passage_proxy_` (STREET-owned,
##                deliberately visible from both zones, never indexed)
##   foreign    — in passage_foreign_f01_nodes (hidden inside Passage)
##   runtime    — self-or-ancestor in the `passage_runtime` group
##                (zone-owned actors/props, gated by the prop loop)
##   LEAK       — none of the above. The defect population. Must be zero.
##
## Exit code is the leak count, so this is an executable regression, not a
## report.

var root: Node3D


func _ready() -> void:
	OS.set_environment("DAYNIGHT", "0")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	# Everything in _ready has run once add_child returns; the settle timer
	# covers deferred builders and the first visibility pass.
	await get_tree().create_timer(2.0).timeout

	var f01: Node = root.floor_nodes.get("F01")
	if f01 == null:
		push_error("[OWN AUDIT] no F01 floor node")
		get_tree().quit(120)
		return

	# Membership in an index list is not the defect; SUBMISSION is. A node
	# absent from every list may still be hidden by the FunctionalProp zone
	# loop (building_root.gd:1503-1520), which gates props by ownership even
	# though their child geometry never appears in any passage array. So the
	# census is taken FROM THE FAILING STATION: view override parked at the
	# northbound camera, visibility settled, and the leak is what is both
	# unclassified and actually visible in tree.
	var eye := Node3D.new()
	add_child(eye)
	eye.global_position = Vector3(14.0, 1.68, 63.6)
	root.view_override = eye
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame

	var interior := _id_set(root.passage_interior_nodes)
	interior.merge(_id_set(root.passage_late_interior_nodes))
	var shell := _id_set(root.passage_shell_nodes)
	var foreign := _id_set(root.passage_foreign_f01_nodes)
	foreign.merge(_id_set(root.passage_late_foreign_nodes))
	var shared := _id_set(root.passage_shared_f01_nodes)

	var counts := {"interior": 0, "shell": 0, "proxy": 0, "foreign": 0,
			"shared": 0, "runtime": 0}
	var leaks: Array = []
	for candidate in f01.find_children("*", "GeometryInstance3D", true, false):
		var g := candidate as GeometryInstance3D
		if g == null:
			continue
		var id := g.get_instance_id()
		if interior.has(id):
			counts["interior"] += 1
		elif shell.has(id):
			counts["shell"] += 1
		elif String(g.name).contains("_retail_passage_proxy_"):
			counts["proxy"] += 1
		elif foreign.has(id):
			counts["foreign"] += 1
		elif shared.has(id):
			# Explicitly shared, with a recorded reason: straddles the
			# portal, moves under another system's authority, or a prop
			# ancestor already zone-gates it. Classified, not leaked.
			counts["shared"] += 1
		elif _in_runtime_group(g):
			counts["runtime"] += 1
		elif not g.is_visible_in_tree():
			# Unindexed but already suppressed at this station — the prop
			# loop or a parent toggle owns it. Not a submission leak, but
			# not explicit zone ownership either; counted separately.
			counts["gated_elsewhere"] = int(counts.get("gated_elsewhere", 0)) + 1
		else:
			leaks.append(g)

	print("[OWN AUDIT] F01 census at northbound: %d interior, %d shell,"
			% [counts["interior"], counts["shell"]]
			+ " %d proxy, %d foreign, %d shared, %d runtime,"
			% [counts["proxy"], counts["foreign"], counts["shared"],
			counts["runtime"]]
			+ " %d gated elsewhere, %d VISIBLE UNCLASSIFIED"
			% [int(counts.get("gated_elsewhere", 0)), leaks.size()])

	# Group the leaks by their top-level owner under F01, because "31 meshes"
	# is a symptom and "LobbyOrisonAdBoard" is a cause.
	var by_owner := {}
	for g in leaks:
		var owner: Node = g
		while owner.get_parent() != null and owner.get_parent() != f01:
			owner = owner.get_parent()
		var key := "%s (%s)" % [owner.name, owner.get_class()]
		if not by_owner.has(key):
			by_owner[key] = {"n": 0, "casters": 0}
		by_owner[key]["n"] += 1
		if g.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			by_owner[key]["casters"] += 1
	var rows: Array = []
	for k in by_owner:
		rows.append([by_owner[k]["n"], by_owner[k]["casters"], k])
	rows.sort_custom(func(a, b): return a[0] > b[0])
	for r in rows:
		print("[OWN AUDIT]   LEAK %-52s %4d draws, %d shadow casters"
				% [r[2], r[0], r[1]])
	if leaks.is_empty():
		print("[OWN AUDIT] PASS - every F01 draw is classified")
	else:
		print("[OWN AUDIT] FAIL - %d unclassified F01 draws" % leaks.size())
	get_tree().quit(mini(leaks.size(), 100))


func _id_set(arr: Array) -> Dictionary:
	var out := {}
	for node in arr:
		if is_instance_valid(node):
			out[node.get_instance_id()] = true
	return out


func _in_runtime_group(n: Node) -> bool:
	var cursor: Node = n
	while cursor != null:
		if cursor.is_in_group("passage_runtime"):
			return true
		cursor = cursor.get_parent()
	return false
