extends RefCounted
## The dream reaching into the waking building, in V2 (Lily,
## v1r_waking_organism_20261109: "Import it, onto V2 apartment walls and
## props").
##
## V1's ApartmentEncroachment owns the living fields, the case sources and the
## waking ecology. This composer hands it V2's building in the shape it reads:
## each case flat's rooms (V2 spaces, in world axes), each storey's height,
## the room nodes that make up each storey (V2 groups draws by room), and a
## storey rectangle wide enough for V2's floors. V2's walls already draw with
## the shared orison_surface shader, whose living-field uniforms the
## encroachment binds.

const EncroachmentScript := preload("res://scripts/reality/apartment_encroachment.gd")
const UNIT_SIDES := ["A", "B", "C", "D"]


static func mount(root: Node3D, blockout: Node3D, layout: Dictionary, player: Node3D) -> Node:
	var to_world := blockout.global_transform
	var levels: Dictionary = {}
	for row: Dictionary in layout.get("levels", []):
		levels[str(row.id)] = float(row.y)
	# Rooms per unit, in the V1 layout convention the encroachment reads:
	# rect [x0, y0, x1, y1] with layout y north, Godot z = -y.
	var floors: Dictionary = {}
	var storey := Vector4(INF, INF, -INF, -INF)
	for space: Dictionary in layout.get("spaces", []):
		var parts := str(space.id).split("_")
		if parts.size() < 3 or not parts[0].begins_with("F0") or parts[1] not in UNIT_SIDES:
			continue
		var floor_id := parts[0]
		var unit := floor_id.trim_prefix("F0") + parts[1]
		var r: Array = space.rect
		var y := float(levels.get(str(space.level), 0.0))
		var a := to_world * Vector3(float(r[0]), y, float(r[1]))
		var b := to_world * Vector3(float(r[2]), y, float(r[3]))
		var x0 := minf(a.x, b.x)
		var x1 := maxf(a.x, b.x)
		var z0 := minf(a.z, b.z)
		var z1 := maxf(a.z, b.z)
		storey = Vector4(minf(storey.x, x0), minf(storey.y, z0), maxf(storey.z, x1), maxf(storey.w, z1))
		if not floors.has(floor_id):
			floors[floor_id] = {"id": floor_id, "z": a.y, "rooms": []}
		(floors[floor_id].rooms as Array).append({"id": str(space.id), "unit": unit,
			"rect": [x0, -z1, x1, -z0]})
	# What each storey's field binds: only the case flats on it (Lily,
	# 2026-11-09: "bind only the flat for each case"), as their spaces
	# (F04_B_...) and their furnishings (4B_...).
	var case_units: Dictionary = {}
	for case_id: String in EncroachmentScript.CASES:
		case_units[str(EncroachmentScript.CASES[case_id].unit)] = true
	var scopes: Dictionary = {}
	var floor_nodes: Dictionary = {}
	for floor_id: String in floors:
		var digit := floor_id.trim_prefix("F0")
		var members: Array = []
		for child in blockout.get_children():
			var n := str(child.name)
			for side: String in UNIT_SIDES:
				if case_units.has(digit + side) and (n.begins_with("%s_%s_" % [floor_id, side])
						or n.begins_with(digit + side + "_")):
					members.append(child)
					break
		scopes[floor_id] = members
	var encroachment: Node = EncroachmentScript.new()
	encroachment.storey_rect = storey
	encroachment.floor_scopes = scopes
	encroachment.with_tendrils = false
	encroachment.with_critters = false
	encroachment.margin_on_storey_only = true
	encroachment.moss_waking_style = true
	encroachment.source_points = _floor_roots(root, to_world, levels, layout)
	root.add_child(encroachment)
	# The encroachment names a case's storey by its floor node. V2 has no
	# storey node, so each storey gets an empty, named anchor.
	for floor_id: String in floors:
		var anchor := Node3D.new()
		anchor.name = floor_id
		encroachment.add_child(anchor)
		floor_nodes[floor_id] = anchor
	var source_layout := {"floors": floors.values()}
	encroachment.build(source_layout, floor_nodes, null)
	encroachment.bind_player(player)
	# Organism incidents (v1r_organism_incidents_20261109): every case flat on
	# a living storey can notice a foreign organism and report it through V2's
	# work orders, with the chance of a fixable fault on one of its appliances.
	var incidents: Node = preload("res://scripts/reality/organism_incidents.gd").new()
	root.add_child(incidents)
	incidents.build(source_layout, encroachment, root.work_orders, root)
	incidents.attach_props()
	root.set("organism_incidents", incidents)
	return encroachment


## Each organism case is rooted on open floor in its flat's main room (Lily,
## 2026-11-09: "the moss needs to be on the floor"). Walk a spiral out from
## the room's centre and take the first point whose downward ray meets the
## floor itself, not a table, bed or cabinet.
static func _floor_roots(root: Node3D, to_world: Transform3D, levels: Dictionary, layout: Dictionary) -> Dictionary:
	var space := root.get_world_3d().direct_space_state
	var spaces: Dictionary = {}
	for space_row: Dictionary in layout.get("spaces", []):
		spaces[str(space_row.id)] = space_row
	var roots: Dictionary = {}
	for case_id: String in EncroachmentScript.CASES:
		var unit := str(EncroachmentScript.CASES[case_id].unit)
		var row: Dictionary = spaces.get("F0%s_%s_MAIN" % [unit.left(1), unit.substr(1)], {})
		if row.is_empty():
			continue
		var r: Array = row.rect
		var y := float(levels.get(str(row.level), 0.0))
		var centre := Vector2((float(r[0]) + float(r[2])) * 0.5, (float(r[1]) + float(r[3])) * 0.5)
		var half := Vector2(absf(float(r[2]) - float(r[0])), absf(float(r[3]) - float(r[1]))) * 0.5 - Vector2(0.6, 0.6)
		for step in 64:
			var a := float(step) * 2.399963
			var k := sqrt(float(step) / 64.0)
			var local := centre + Vector2(cos(a) * half.x, sin(a) * half.y) * k
			var top := to_world * Vector3(local.x, y + 1.6, local.y)
			var bottom := to_world * Vector3(local.x, y - 0.3, local.y)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(top, bottom))
			if hit.is_empty():
				continue
			var at: Vector3 = hit.position
			if at.y < y + 0.08 and (hit.normal as Vector3).y > 0.9:
				roots[case_id] = at + Vector3(0.0, 0.01, 0.0)
				break
	return roots
