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
		"hazards": [],
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

	# N7: HAZARD SOCKETS BECOME PLAN SPACE. The catalog has authored eight
	# of these since N2 and nothing has ever read them. Every socket of
	# every placed module is emitted -- the builder gets no profile and
	# stays a pure function of (catalog, seed_hex, slot); WHICH hazards a
	# case actually runs is the profile's business, not the geometry's.
	#
	# They go in their own list and never into plan.doors: build_geometry
	# cuts a real 0.91 m opening through every door aperture, so a hazard
	# in that list would saw a hole in a sealed wall.
	for id in chain_ids:
		var module: Dictionary = modules[id]
		var fp: Array = module.footprint_m
		var r: Array = rects[id]
		for socket in module.get("hazard_sockets", []):
			var local: Array = socket.get("position_m", [])
			if local.size() < 2:
				plan.defects.append("hazard socket %s has no local point"
						% str(socket.get("id", "?")))
				continue
			# Mirroring is the assembly's one seed freedom and it flips
			# the module about its own depth axis, so a socket's offset
			# measures from the far edge instead of the near one.
			var oz: float = float(local[1])
			if mirrored:
				oz = float(fp[1]) - float(local[1])
			plan.hazards.append({
				"id": str(socket.get("id", "")),
				"kind": str(socket.get("kind", "")),
				"module": id,
				"position": [r[0] + float(local[0]), r[1] + oz],
				"clearance_radius_m": float(socket.get(
						"clearance_radius_m", 0.35)),
				"tell_radius_m": float(socket.get("tell_radius_m", 4.60)),
				"minimum_warning_s": float(socket.get(
						"minimum_warning_s", 0.50)),
			})

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
## `armed` is the profile's hazard allowlist. It is REQUIRED for correctness,
## not decoration: plan.hazards holds every socket of every placed module,
## while DreamHazardField arms only the allowed ones. Cutting a mouth for an
## unarmed void would leave a real 6 m shaft that no hazard can attribute, so
## the body falls into a sealed pit in a run that has no way to end. Geometry
## and arming must come from one decision. An empty array arms nothing.
static func build_geometry(parent: Node3D, plan: Dictionary,
		clear_ceiling: float, armed: Array = []) -> void:
	var architecture := Node3D.new()
	architecture.name = "ModuleArchitecture"
	parent.add_child(architecture)
	# ONE MOTIF PER SURFACE CLASS. The Stoclet Frieze is five pattern languages
	# sharing a palette, not one texture, so each thing the maze is made of
	# wears its own: the ornament becomes wayfinding rather than decoration,
	# and in a maze whose job is to lose you, the pattern says what a thing IS.
	var wall_mat := _material(Color("272a31"), 0.94, MOTIF_SPIRAL)
	var floor_mat := _material(Color("343139"), 0.90, MOTIF_MOSAIC)
	# The ceiling is the frieze's vast ivory field: nearly unornamented, and
	# quiet on purpose so the walls and the floor can speak.
	var ceiling_mat := _material(Color("2b2b31"), 0.92, MOTIF_IVORY)
	# Doors wear the robe of Expectation — stacked chevrons, sharp and
	# directional, because an opening should announce itself as a way THROUGH.
	var door_mat := _material(Color("2a2730"), 0.86, MOTIF_TRIANGLE)
	# A shaft is a hazard you can fall into, so it takes the watching eyes.
	var shaft_mat := _material(Color("1d1a20"), 0.90, MOTIF_EYE)

	var bounds := _plan_bounds(plan)
	var margin := WALL_T
	# The floor is one slab with the void mouths taken out of it, so a fall is
	# real physics through real missing floor rather than a radius that
	# teleports an outcome. Everything else about the void follows from that.
	var slabs: Array = [[bounds[0] - margin, bounds[1] - margin,
			bounds[2] + margin, bounds[3] + margin]]
	var holes := floor_holes(plan, armed)
	for hole in holes:
		slabs = _subtract_rect(slabs, hole)
	var slab_index := 0
	for slab in slabs:
		slab_index += 1
		_solid_box(architecture, "DreamFloor%02d" % slab_index, floor_mat,
				slab, -WALL_T, 0.0)
	_build_shafts(architecture, holes, shaft_mat)
	_solid_box(architecture, "DreamCeiling", ceiling_mat,
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
		_solid_box(architecture, "Lintel%02d" % index, door_mat, aperture,
				float(_door_height(plan)), clear_ceiling)


## How deep a void reads before the fall is called. The player never lands:
## the outcome commits well above this, and the pit floor exists only so a
## runaway body has something to stop on.
const SHAFT_DEPTH := 6.0
## A body whose feet pass this far below the floor plane is falling and is
## not coming back. Deep enough that a step down a lintel or a physics
## jitter can never read as a fall, shallow enough to commit while the drop
## still feels like the player's own mistake.
const FALL_TRIGGER_Y := -0.90


## The floor openings a plan requires, as rects.
##
## Derived, never authored: a socket whose kind is exactly `positional` is a
## hazard whose danger IS its place, and the only such socket in the catalog
## is the open lift void. Its `clearance_radius_m` of 0.45 is half the 0.91
## connector width, so the mouth this cuts is a lift doorway laid into the
## floor -- the opening you would have stepped through if the car were there.
##
## Deriving it means the catalog SHA is untouched and Gate A stays valid.
static func floor_holes(plan: Dictionary, armed: Array = []) -> Array:
	var holes: Array = []
	for record in plan.get("hazards", []):
		if str(record.get("kind", "")) != "positional":
			continue
		if not armed.has(str(record.get("id", ""))):
			continue
		var p: Array = record.get("position", [])
		if p.size() < 2:
			continue
		var half := float(record.get("clearance_radius_m", 0.45))
		holes.append([float(p[0]) - half, float(p[1]) - half,
				float(p[0]) + half, float(p[1]) + half])
	return holes


## Line each mouth with a shaft so a fall reads as a shaft and not as the
## world running out. Sides are inset by their own thickness so they never
## narrow the opening the player can fall through.
static func _build_shafts(parent: Node3D, holes: Array,
		material: Material) -> void:
	var index := 0
	for hole in holes:
		index += 1
		var t := WALL_T
		_solid_box(parent, "ShaftPit%02d" % index, material,
				[hole[0] - t, hole[1] - t, hole[2] + t, hole[3] + t],
				-SHAFT_DEPTH - t, -SHAFT_DEPTH)
		_solid_box(parent, "ShaftW%02d" % index, material,
				[hole[0] - t, hole[1] - t, hole[0], hole[3] + t],
				-SHAFT_DEPTH, -WALL_T)
		_solid_box(parent, "ShaftE%02d" % index, material,
				[hole[2], hole[1] - t, hole[2] + t, hole[3] + t],
				-SHAFT_DEPTH, -WALL_T)
		_solid_box(parent, "ShaftN%02d" % index, material,
				[hole[0], hole[1] - t, hole[2], hole[1]],
				-SHAFT_DEPTH, -WALL_T)
		_solid_box(parent, "ShaftS%02d" % index, material,
				[hole[0], hole[3], hole[2], hole[3] + t],
				-SHAFT_DEPTH, -WALL_T)


## Remove a rect from a set of rects, returning the remainder as up to four
## bands per box. Same law as the door cut above: keep what does not overlap,
## split what does, never emit a zero-area piece.
static func _subtract_rect(boxes: Array, hole: Array) -> Array:
	var out: Array = []
	for box in boxes:
		if not _rects_overlap(box, hole):
			out.append(box)
			continue
		var inner_x0 := maxf(box[0], hole[0])
		var inner_x1 := minf(box[2], hole[2])
		if box[1] < hole[1]:
			out.append([box[0], box[1], box[2], hole[1]])
		if box[3] > hole[3]:
			out.append([box[0], hole[3], box[2], box[3]])
		var band_y0 := maxf(box[1], hole[1])
		var band_y1 := minf(box[3], hole[3])
		if box[0] < inner_x0:
			out.append([box[0], band_y0, inner_x0, band_y1])
		if box[2] > inner_x1:
			out.append([inner_x1, band_y0, box[2], band_y1])
	return out


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


## Motif ids, mirrored from dream_klimt.gdshader. Kept as plain ints rather
## than an enum because the shader uniform is an int and a mismatch here would
## silently paint a floor with a ceiling's pattern.
const MOTIF_IVORY := 0
const MOTIF_SPIRAL := 1
const MOTIF_MOSAIC := 2
const MOTIF_TRIANGLE := 3
const MOTIF_EYE := 4
const MOTIF_FLOWERBED := 5


static func _material(color: Color, roughness: float,
		motif: int = MOTIF_SPIRAL) -> Material:
	# GOLD IS THE DEFAULT NOW. Owner ruling 2026-08-17: "this is a
	# demonstration project of what we can create, the rule of cool is key.
	# Make it good, not correct." The graybox is kept only as a control for
	# renders and perf comparison — `DREAM_PLAIN=1`.
	if OS.get_environment("DREAM_PLAIN") != "1":
		return _klimt_material(color, roughness, motif)
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material


## Gold leaf over the same geometry. The ground colour is carried through from
## the graybox so a wall and a floor stay distinguishable in the dark, where
## the ornament is not lit and the ground is all there is.
static func _klimt_material(color: Color, roughness: float,
		motif: int) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/dream_klimt.gdshader")
	material.set_shader_parameter("motif", motif)
	material.set_shader_parameter("ground_roughness", roughness)
	# Each language wants its own mark size. The frieze's coils are large and
	# structural; its mosaic is tiny and dense; the chevrons sit between.
	var scale := 7.0
	match motif:
		MOTIF_MOSAIC:
			scale = 5.5
		MOTIF_IVORY:
			scale = 4.0
		MOTIF_TRIANGLE:
			scale = 6.0
		MOTIF_EYE:
			scale = 5.0
	material.set_shader_parameter("pattern_scale", scale)
	return material
