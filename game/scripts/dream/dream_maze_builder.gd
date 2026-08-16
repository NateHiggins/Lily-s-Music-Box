class_name DreamMazeBuilder
extends RefCounted
## N6: deterministic runtime assembly of the N2 module catalog.
##
## The catalog and its generated control packing remain the authorities for
## module facts and non-overlap feasibility (art/renders/dream_maze_n2). This
## builder consumes the same source catalog at runtime and lays the slot's
## eligible chain out in dream-local coordinates. It never reads the packing
## coordinates as world placement and never inserts a portal teleport: every
## joined pair shares one real 0.20 m wall with one authored 0.91 x 2.13 m
## opening cut through it.
##
## Scope guard: this assembles LINEAR chains only, which is exactly the
## slot-1 (Mina) exposure. Branch reconvergence and the terminal D09 fold are
## later-slot topology work and fail loudly here rather than silently
## approximating.

const CATALOG_PATH := "res://data/dream_module_catalog.json"
const WALL_T := 0.20
const START_MODULE := "D00_4B_THRESHOLD"


static func load_catalog() -> Dictionary:
	var parsed: Variant = JSON.parse_string(
			FileAccess.get_file_as_string(CATALOG_PATH))
	return parsed if parsed is Dictionary else {}


## The exact 64-bit campaign seed travels as sixteen hex digits (N4 contract).
## Consume it as two 32-bit halves; never round-trip it through a float or a
## single signed conversion with the high bit set.
static func seed_halves(seed_hex: String) -> Array[int]:
	if seed_hex.length() != 16 or not seed_hex.is_valid_hex_number(false):
		return [0, 0]
	return [seed_hex.substr(0, 8).hex_to_int(),
			seed_hex.substr(8, 8).hex_to_int()]


## Deterministic plan: pure data, JSON-stable, no nodes. `slot` is the
## campaign slot whose unlocked modules and edges are eligible.
static func assemble(catalog: Dictionary, seed_hex: String,
		slot: int) -> Dictionary:
	var plan := {
		"seed_hex": seed_hex,
		"slot": slot,
		"mirrored": false,
		"modules": [],
		"doors": [],
		"spawn_player": [0.0, 0.0],
		"spawn_pursuer": [0.0, 0.0],
		"defects": [],
	}
	var modules: Dictionary = catalog.get("modules", {})
	var topology: Array = catalog.get("topology", [])
	var constants: Dictionary = catalog.get("constants", {})
	if modules.is_empty() or topology.is_empty():
		plan.defects.append("catalog missing modules or topology")
		return plan
	var halves := seed_halves(seed_hex)
	if halves == [0, 0]:
		plan.defects.append("invalid campaign seed hex")
		return plan
	# Handedness: the ruled seed freedom is left/right presentation. One bit
	# of the low half mirrors the assembly across its long axis.
	var mirrored: bool = (halves[1] & 1) == 1
	plan.mirrored = mirrored

	# Walk the eligible chain from D00. Exactly one eligible outgoing edge
	# per module is the linear-chain contract this builder supports.
	var chain_ids: Array[String] = [START_MODULE]
	var used_edges: Array[String] = []
	var guard := 0
	while guard < 32:
		guard += 1
		var current := chain_ids[chain_ids.size() - 1]
		var outgoing: Array = []
		for edge in topology:
			if int(edge.get("unlock_slot", 99)) <= slot \
					and str(edge.from[0]) == current:
				outgoing.append(edge)
		if outgoing.is_empty():
			break
		if outgoing.size() > 1:
			plan.defects.append(
					"module %s has %d eligible edges; linear chains only at slot %d"
					% [current, outgoing.size(), slot])
			return plan
		var edge: Dictionary = outgoing[0]
		used_edges.append(str(edge.id))
		chain_ids.append(str(edge.to[0]))
	plan["edges"] = used_edges

	# Place the chain. Module-local: origin at the rect minimum, footprint
	# [size_x, size_z]; west x=min, east x=max, north z=min, south z=max.
	var rects := {}  # id -> [x0, z0, x1, z1]
	var first_fp: Array = modules[START_MODULE].footprint_m
	rects[START_MODULE] = [0.0, 0.0, float(first_fp[0]), float(first_fp[1])]
	for i in range(used_edges.size()):
		var edge: Dictionary = _edge_by_id(topology, used_edges[i])
		var a_id := str(edge.from[0])
		var b_id := str(edge.to[0])
		var con_a := _connector(modules[a_id], str(edge.from[1]), mirrored)
		var con_b := _connector(modules[b_id], str(edge.to[1]), mirrored)
		if con_a.is_empty() or con_b.is_empty():
			plan.defects.append("edge %s names a missing connector"
					% used_edges[i])
			return plan
		if not _opposite(str(con_a.side), str(con_b.side)):
			plan.defects.append("edge %s joins non-opposite sides %s/%s"
					% [used_edges[i], con_a.side, con_b.side])
			return plan
		var a: Array = rects[a_id]
		var b_fp: Array = modules[b_id].footprint_m
		var bx := 0.0
		var bz := 0.0
		match str(con_a.side):
			"east":
				bx = a[2] + WALL_T
				bz = a[1] + float(con_a.offset) - float(con_b.offset)
			"west":
				bx = a[0] - WALL_T - float(b_fp[0])
				bz = a[1] + float(con_a.offset) - float(con_b.offset)
			"south":
				bz = a[3] + WALL_T
				bx = a[0] + float(con_a.offset) - float(con_b.offset)
			"north":
				bz = a[1] - WALL_T - float(b_fp[1])
				bx = a[0] + float(con_a.offset) - float(con_b.offset)
		rects[b_id] = [bx, bz, bx + float(b_fp[0]), bz + float(b_fp[1])]
		plan.doors.append(_door_record(a_id, b_id, str(con_a.side),
				rects[a_id], con_a, constants))

	for id in chain_ids:
		plan.modules.append({"id": id, "rect": rects[id]})

	# Non-overlap is a hard guarantee, not a hope: strictly positive shared
	# area between any two clear footprints is a defect.
	for i in range(chain_ids.size()):
		for j in range(i + 1, chain_ids.size()):
			if _rects_overlap(rects[chain_ids[i]], rects[chain_ids[j]]):
				plan.defects.append("footprint overlap %s/%s"
						% [chain_ids[i], chain_ids[j]])

	var start: Array = rects[START_MODULE]
	plan.spawn_player = [(start[0] + start[2]) * 0.5,
			(start[1] + start[3]) * 0.5]
	plan.spawn_pursuer = _far_spawn(chain_ids, rects, plan.doors)
	return plan


## Emit graybox architecture for a plan: one floor and ceiling slab, module
## walls of real opaque StaticBody3D collision, and each chain door cut
## through its shared wall as two jambs and a lintel. Sealed connectors of
## later slots stay solid wall, which is the authored "sealed grille" state.
static func build_geometry(parent: Node3D, plan: Dictionary,
		clear_ceiling: float) -> void:
	var architecture := Node3D.new()
	architecture.name = "ModuleArchitecture"
	parent.add_child(architecture)
	var wall_mat := _material(Color("272a31"), 0.94)
	var floor_mat := _material(Color("343139"), 0.90)

	var bounds := _plan_bounds(plan)
	var margin := WALL_T
	_solid_box(architecture, "DreamFloor", floor_mat,
			[bounds[0] - margin, bounds[1] - margin,
			bounds[2] + margin, bounds[3] + margin], -WALL_T, 0.0)
	_solid_box(architecture, "DreamCeiling", wall_mat,
			[bounds[0] - margin, bounds[1] - margin,
			bounds[2] + margin, bounds[3] + margin],
			clear_ceiling, clear_ceiling + WALL_T)

	var boxes: Array = []
	for entry in plan.modules:
		var r: Array = entry.rect
		# West and east bands own the corners; north and south stay inside.
		boxes.append([r[0] - WALL_T, r[1] - WALL_T, r[0], r[3] + WALL_T])
		boxes.append([r[2], r[1] - WALL_T, r[2] + WALL_T, r[3] + WALL_T])
		boxes.append([r[0], r[1] - WALL_T, r[2], r[1]])
		boxes.append([r[0], r[3], r[2], r[3] + WALL_T])

	var lintel_jobs: Array = []
	for door in plan.doors:
		var aperture: Array = door.aperture
		var split: Array = []
		for box in boxes:
			if not _rects_overlap(box, aperture):
				split.append(box)
				continue
			# Cut the full-height opening; keep the jambs beside it.
			if door.axis == "z":
				if box[1] < aperture[1]:
					split.append([box[0], box[1], box[2], aperture[1]])
				if box[3] > aperture[3]:
					split.append([box[0], aperture[3], box[2], box[3]])
			else:
				if box[0] < aperture[0]:
					split.append([box[0], box[1], aperture[0], box[3]])
				if box[2] > aperture[2]:
					split.append([aperture[2], box[1], box[2], box[3]])
		boxes = split
		lintel_jobs.append(aperture)

	var index := 0
	for box in boxes:
		index += 1
		_solid_box(architecture, "Wall%03d" % index, wall_mat, box,
				0.0, clear_ceiling)
	index = 0
	for aperture in lintel_jobs:
		index += 1
		_solid_box(architecture, "Lintel%02d" % index, wall_mat, aperture,
				float(_door_height(plan)), clear_ceiling)


## Which module's clear footprint contains the point; empty when outside all.
static func module_at(plan: Dictionary, x: float, z: float) -> String:
	for entry in plan.modules:
		var r: Array = entry.rect
		if x >= r[0] and x <= r[2] and z >= r[1] and z <= r[3]:
			return str(entry.id)
	return ""


## Navigation lookup: a body standing inside a door strip is treated as
## already belonging to that door's near module, so routing never degrades
## to a straight line that could cut architecture.
static func nav_module_at(plan: Dictionary, x: float, z: float) -> String:
	var strict := module_at(plan, x, z)
	if strict != "":
		return strict
	for door in plan.doors:
		var a: Array = door.aperture
		if x >= a[0] - 0.06 and x <= a[2] + 0.06 \
				and z >= a[1] - 0.06 and z <= a[3] + 0.06:
			return str(door.from)
	return ""


## Waypoints between two chain modules, in travel order. Every door
## contributes three points — a perpendicular approach half a metre inside
## the near module, the aperture centre, and the matching exit inside the
## far module — so a body deep in a room squares up before the opening
## instead of clipping the wall band beside it. Modules are convex, so the
## segments between consecutive points never cross architecture: the body
## follows the validated graph instead of free space.
static func chain_route(plan: Dictionary, from_id: String,
		to_id: String) -> Array:
	var order: Array[String] = []
	for entry in plan.modules:
		order.append(str(entry.id))
	var a := order.find(from_id)
	var b := order.find(to_id)
	if a < 0 or b < 0 or a == b:
		return []
	var waypoints: Array = []
	if a < b:
		for i in range(a, b):
			waypoints.append_array(_door_waypoints(plan, i, true))
	else:
		for i in range(a - 1, b - 1, -1):
			waypoints.append_array(_door_waypoints(plan, i, false))
	return waypoints


const _APPROACH_M := 0.5


static func _door_waypoints(plan: Dictionary, chain_index: int,
		forward: bool) -> Array:
	var door: Dictionary = plan.doors[chain_index]
	var aperture: Array = door.aperture
	var center := Vector3((aperture[0] + aperture[2]) * 0.5, 0.0,
			(aperture[1] + aperture[3]) * 0.5)
	var side_a: Vector3
	var side_b: Vector3
	if str(door.axis) == "z":
		side_a = Vector3(aperture[0] - _APPROACH_M, 0.0, center.z)
		side_b = Vector3(aperture[2] + _APPROACH_M, 0.0, center.z)
	else:
		side_a = Vector3(center.x, 0.0, aperture[1] - _APPROACH_M)
		side_b = Vector3(center.x, 0.0, aperture[3] + _APPROACH_M)
	var from_rect: Array = []
	for entry in plan.modules:
		if str(entry.id) == str(door.from):
			from_rect = entry.rect
	var a_in_from: bool = side_a.x >= from_rect[0] \
			and side_a.x <= from_rect[2] and side_a.z >= from_rect[1] \
			and side_a.z <= from_rect[3]
	var near := side_a if a_in_from else side_b
	var far := side_b if a_in_from else side_a
	if forward:
		return [near, center, far]
	return [far, center, near]


static func _edge_by_id(topology: Array, id: String) -> Dictionary:
	for edge in topology:
		if str(edge.id) == id:
			return edge
	return {}


static func _connector(module: Dictionary, id: String,
		mirrored: bool) -> Dictionary:
	for con in module.get("connectors", []):
		if str(con.id) != id:
			continue
		var side := str(con.side)
		var offset := float(con.offset_m)
		if mirrored:
			var fp: Array = module.footprint_m
			match side:
				"north":
					side = "south"
				"south":
					side = "north"
				"west", "east":
					offset = float(fp[1]) - offset
		return {"side": side, "offset": offset,
				"width": float(con.width_m), "height": float(con.height_m)}
	return {}


static func _opposite(a: String, b: String) -> bool:
	return (a == "east" and b == "west") or (a == "west" and b == "east") \
			or (a == "north" and b == "south") \
			or (a == "south" and b == "north")


static func _door_record(a_id: String, b_id: String, side: String,
		a_rect: Array, con_a: Dictionary, constants: Dictionary) -> Dictionary:
	var half := float(con_a.width) * 0.5
	var aperture: Array = []
	var axis := "z"
	match side:
		"east":
			var center_z: float = a_rect[1] + float(con_a.offset)
			aperture = [a_rect[2], center_z - half,
					a_rect[2] + WALL_T, center_z + half]
			axis = "z"
		"west":
			var center_z2: float = a_rect[1] + float(con_a.offset)
			aperture = [a_rect[0] - WALL_T, center_z2 - half,
					a_rect[0], center_z2 + half]
			axis = "z"
		"south":
			var center_x: float = a_rect[0] + float(con_a.offset)
			aperture = [center_x - half, a_rect[3],
					center_x + half, a_rect[3] + WALL_T]
			axis = "x"
		"north":
			var center_x2: float = a_rect[0] + float(con_a.offset)
			aperture = [center_x2 - half, a_rect[1] - WALL_T,
					center_x2 + half, a_rect[1]]
			axis = "x"
	return {"from": a_id, "to": b_id, "axis": axis, "aperture": aperture,
			"width": float(con_a.width), "height": float(con_a.height),
			"clear_ceiling": float(constants.get("clear_ceiling_m", 3.015))}


static func _door_height(plan: Dictionary) -> float:
	if plan.doors.is_empty():
		return 2.13
	return float(plan.doors[0].height)


static func _far_spawn(chain_ids: Array[String], rects: Dictionary,
		doors: Array) -> Array:
	var last_id := chain_ids[chain_ids.size() - 1]
	var r: Array = rects[last_id]
	var center := Vector2((r[0] + r[2]) * 0.5, (r[1] + r[3]) * 0.5)
	if doors.is_empty():
		return [center.x, center.y]
	var last_door: Dictionary = doors[doors.size() - 1]
	var aperture: Array = last_door.aperture
	var door_at := Vector2((aperture[0] + aperture[2]) * 0.5,
			(aperture[1] + aperture[3]) * 0.5)
	# The far end of the terminal module: opposite its entry door, kept
	# clear of the wall by more than the body capsule radius.
	var away := (center - door_at)
	if away.length() < 0.001:
		return [center.x, center.y]
	away = away.normalized()
	var spot := center
	while spot.x + away.x * 0.5 > r[0] + 0.6 \
			and spot.x + away.x * 0.5 < r[2] - 0.6 \
			and spot.y + away.y * 0.5 > r[1] + 0.6 \
			and spot.y + away.y * 0.5 < r[3] - 0.6:
		spot += away * 0.5
	return [spot.x, spot.y]


static func _plan_bounds(plan: Dictionary) -> Array:
	var b := [INF, INF, -INF, -INF]
	for entry in plan.modules:
		var r: Array = entry.rect
		b[0] = minf(b[0], r[0])
		b[1] = minf(b[1], r[1])
		b[2] = maxf(b[2], r[2])
		b[3] = maxf(b[3], r[3])
	return b


static func _rects_overlap(a: Array, b: Array) -> bool:
	return a[0] < b[2] - 0.0005 and b[0] < a[2] - 0.0005 \
			and a[1] < b[3] - 0.0005 and b[1] < a[3] - 0.0005


static func _solid_box(parent: Node3D, node_name: String, material: Material,
		rect: Array, y0: float, y1: float) -> StaticBody3D:
	var size := Vector3(rect[2] - rect[0], y1 - y0, rect[3] - rect[1])
	var at := Vector3((rect[0] + rect[2]) * 0.5, (y0 + y1) * 0.5,
			(rect[1] + rect[3]) * 0.5)
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = at
	body.collision_layer = 1
	body.collision_mask = 0
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	shape_node.shape = shape
	body.add_child(shape_node)
	var mesh_node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_node.mesh = mesh
	mesh_node.material_override = material
	body.add_child(mesh_node)
	parent.add_child(body)
	return body


static func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material
