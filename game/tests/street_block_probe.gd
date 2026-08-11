extends Node
## What stops you on the street, and does it look like anything?
##
##     godot --headless --path game res://tests/StreetBlockProbe.tscn
##
## The street's own rule (gen_layout retail_block docstring) is "No invisible
## barriers. Everything that stops the player is a thing a city put there."
## This checks that claim instead of trusting it: sweep the carriageway and both
## pavements with body-width casts at walking height, and for every collider
## found, ask whether anything visible is attached to it.

const EYE := 0.95           # mid-body, where a barrier would catch you
const BODY_R := 0.33        # BODY_RADIUS
const STEP := 0.75


func _ready() -> void:
	var root: Node3D = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	await get_tree().create_timer(1.2).timeout
	root.show_all_floors = true
	await get_tree().create_timer(0.5).timeout

	var space := get_viewport().world_3d.direct_space_state
	var shape := SphereShape3D.new()
	shape.radius = BODY_R
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.collide_with_areas = false

	var blockers := {}
	var samples := 0
	# Blender x -30..46 spans the block; y -29..-12 covers both walks and road.
	var bx := -30.0
	while bx <= 46.0:
		var by := -29.0
		while by <= -12.0:
			params.transform = Transform3D(Basis(),
					GameBoot.b2g([bx, by, EYE]))
			samples += 1
			for hit in space.intersect_shape(params, 8):
				var col: Node = hit.get("collider")
				if col == null:
					continue
				var owner_name := _owner_of(col)
				if not blockers.has(owner_name):
					blockers[owner_name] = [0, _has_visible_mesh(col)]
				blockers[owner_name][0] += 1
			by += STEP
		bx += STEP

	var invisible: Array = []
	var seen: Array = []
	for k in blockers:
		if bool(blockers[k][1]):
			seen.append([blockers[k][0], k])
		else:
			invisible.append([blockers[k][0], k])
	seen.sort_custom(func(a, b): return a[0] > b[0])
	invisible.sort_custom(func(a, b): return a[0] > b[0])

	print("[STREET] %d probe points, %d distinct blockers" % [samples, blockers.size()])
	print("[STREET] --- SOLID AND VISIBLE (a thing the city put there) ---")
	for r in seen.slice(0, 14):
		print("   %5d hits  %s" % [r[0], r[1]])
	print("[STREET] --- SOLID AND INVISIBLE ---")
	if invisible.is_empty():
		print("   none")
	for r in invisible:
		print("   %5d hits  %s" % [r[0], r[1]])
	get_tree().quit(0)


## Furniture arrives merged, so the collider's own name is often a batch. Walk up
## to the first ancestor with a name worth printing.
func _owner_of(col: Node) -> String:
	var n: Node = col
	var trail: Array[String] = []
	var hops := 0
	while n != null and hops < 4:
		trail.push_front(String(n.name))
		n = n.get_parent()
		hops += 1
	return "/".join(trail)


func _has_visible_mesh(col: Node) -> bool:
	var probe: Node = col
	for i in 3:
		if probe == null:
			break
		if _visible_mesh_under(probe):
			return true
		probe = probe.get_parent()
	return false


func _visible_mesh_under(n: Node) -> bool:
	if n is MeshInstance3D and n.visible and n.mesh != null:
		return true
	for c in n.get_children():
		if c is MeshInstance3D and c.visible and c.mesh != null:
			return true
	return false
