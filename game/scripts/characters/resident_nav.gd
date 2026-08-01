class_name ResidentNav
extends Node
## Pathfinding for the residents: a portal graph, not a navmesh.
##
## The generator is the single authority on where walking is legal — its
## movement audit proves every clearance — so navigation is built from the
## same layout data rather than baked off the merged trimeshes, where a
## navmesh would happily learn its own opinions about the building.
##
## The graph is the building's own logic:
##   - every ROOM contributes its centre as a node
##   - every DOOR is a portal node joining the two rooms either side of it
##   - within a room, doors and centre interconnect (rooms are rects, so
##     straight lines inside one are safe for non-colliding residents)
##   - the CORRIDOR on F02..F06 is one big rect with the core (atrium,
##     utility, hall) nested inside it, so straight lines across it would
##     cut through the light court. It gets a RING LANE instead: eight
##     nodes running the rectangle midway between core and corridor wall —
##     the same lane the movement audit walks — and corridor-facing doors
##     hop onto the lane rather than crossing the middle.
##
## Floors are separate islands on purpose. Vertical travel is the lift,
## which the routine system performs as walk-in/hide/walk-out; a path query
## is always same-floor.
##
## Door adjacency is discovered by sampling, not by trusting yaw: probe
## half a metre to each side of the leaf on both axes and take the smallest
## room containing each probe (rooms nest — a bathroom sits inside its
## unit's envelope, and the smallest match is the room you are actually in).

## Half-metre probe finds the rooms either side of a leaf.
const PROBE := 0.5
## Core half-extents on ring floors (matches occluders.gd): the lane runs
## midway between this and the corridor wall.
const CORE_X := 3.43
const CORE_Y := 6.93

var floors := {}      # floor_id -> {astar: AStar3D, nodes: [...], z: float}


func build(layout: Dictionary) -> int:
	var total := 0
	for fl in layout["floors"]:
		var fid := str(fl["id"])
		if fid == "ROOF":
			continue          # the roof is one open deck; no doors to route
		total += _build_floor(fid, fl)
	print("[NAV] %d nodes across %d floors" % [total, floors.size()])
	return total


func _build_floor(fid: String, fl: Dictionary) -> int:
	var astar := AStar3D.new()
	var z: float = float(fl["z"])
	var rooms: Array = fl.get("rooms", [])
	var entry := {"astar": astar, "z": z, "rooms": rooms, "points": []}
	var next_id := [0]

	var add_node := func(pos_bl: Vector2, tag: String) -> int:
		var id: int = next_id[0]
		next_id[0] += 1
		astar.add_point(id, GameBoot.b2g([pos_bl.x, pos_bl.y, z]))
		entry.points.append({"id": id, "at": pos_bl, "tag": tag})
		return id

	# --- room centres
	var centre_of := {}       # room id -> node id
	for r in rooms:
		var rect: Array = r["rect"]
		var c := Vector2((float(rect[0]) + float(rect[2])) * 0.5,
				(float(rect[1]) + float(rect[3])) * 0.5)
		centre_of[str(r["id"])] = add_node.call(c, "room:" + str(r["id"]))

	# --- the ring lane, on floors whose corridor nests the core
	var ring_ids: Array = []
	for r in rooms:
		if str(r["kind"]) != "corridor":
			continue
		var rect: Array = r["rect"]
		var lane_x := (absf(float(rect[2])) + CORE_X) * 0.5
		var lane_y := (absf(float(rect[3])) + CORE_Y) * 0.5
		var lane: Array = [
			Vector2(-lane_x, -lane_y), Vector2(0, -lane_y),
			Vector2(lane_x, -lane_y), Vector2(lane_x, 0),
			Vector2(lane_x, lane_y), Vector2(0, lane_y),
			Vector2(-lane_x, lane_y), Vector2(-lane_x, 0),
		]
		for p in lane:
			ring_ids.append(add_node.call(p, "ring"))
		for i in ring_ids.size():
			astar.connect_points(ring_ids[i],
					ring_ids[(i + 1) % ring_ids.size()])
		# the corridor's own centre node would invite crossings through the
		# core; retarget it onto the lane instead
		var cid: int = centre_of[str(r["id"])]
		astar.set_point_position(cid,
				GameBoot.b2g([lane_x, 0.0, z]))

	# --- doors as portals. Two passes, because a door probing into VOID —
	# a walkable strip no room rect claims, which is the whole ring on F01 —
	# has to be able to summon the lane into existence before connecting.
	var door_specs: Array = []
	var needs_implicit_ring := false
	for m in fl.get("markers", []):
		if str(m.get("kind", "")) != "door" or bool(m.get("cabinet", false)):
			continue
		var p: Array = m["pos"]
		var at := Vector2(float(p[0]), float(p[1]))
		var joins: Array = []
		var void_hit := false
		var joined := {}
		for off in [Vector2(PROBE, 0), Vector2(-PROBE, 0),
				Vector2(0, PROBE), Vector2(0, -PROBE)]:
			var sample: Vector2 = at + off
			var room: Variant = _room_at(rooms, sample)
			if room == null:
				# Rooms do not tile every floor: F01 has no corridor-kind
				# rect, so its ring is void to the data while being the
				# floor's main circulation. If the void lies inside the
				# corridor envelope, the implicit lane serves it.
				if absf(sample.x) < 5.33 and absf(sample.y) < 9.65:
					void_hit = true
					needs_implicit_ring = true
				continue
			var rid := str(room["id"])
			if joined.has(rid):
				continue
			joined[rid] = true
			joins.append(room)
		door_specs.append({"at": at, "id": str(m.get("id", "")),
				"joins": joins, "void": void_hit})

	if needs_implicit_ring and ring_ids.is_empty():
		var lane_x := (5.33 + CORE_X) * 0.5
		var lane_y := (9.65 + CORE_Y) * 0.5
		var lane: Array = [
			Vector2(-lane_x, -lane_y), Vector2(0, -lane_y),
			Vector2(lane_x, -lane_y), Vector2(lane_x, 0),
			Vector2(lane_x, lane_y), Vector2(0, lane_y),
			Vector2(-lane_x, lane_y), Vector2(-lane_x, 0),
		]
		for lp in lane:
			ring_ids.append(add_node.call(lp, "ring"))
		for i in ring_ids.size():
			astar.connect_points(ring_ids[i],
					ring_ids[(i + 1) % ring_ids.size()])
		# A lane node that falls inside a real room welds that room to the
		# ring — the south run passes straight through the lobby, which is
		# exactly how the actual building works.
		for i in ring_ids.size():
			var room: Variant = _room_at(rooms, lane[i])
			if room != null:
				astar.connect_points(ring_ids[i],
						centre_of[str(room["id"])])

	for spec in door_specs:
		var did: int = add_node.call(spec.at, "door:" + str(spec.id))
		for room in spec.joins:
			if str(room["kind"]) == "corridor" and not ring_ids.is_empty():
				for rn in _nearest_two(entry, ring_ids, spec.at):
					astar.connect_points(did, rn)
			else:
				astar.connect_points(did, centre_of[str(room["id"])])
		if bool(spec.void) and not ring_ids.is_empty():
			for rn in _nearest_two(entry, ring_ids, spec.at):
				astar.connect_points(did, rn)

	# --- interconnect doors that share a non-corridor room, so a route
	# can cross an apartment without detouring through its centre
	for r in rooms:
		if str(r["kind"]) == "corridor":
			continue
		var here: Array = []
		for pt in entry.points:
			if str(pt.tag).begins_with("door:") \
					and _in_rect(r["rect"], pt.at, PROBE + 0.1):
				here.append(pt.id)
		for i in here.size():
			for j in range(i + 1, here.size()):
				if not astar.are_points_connected(here[i], here[j]):
					astar.connect_points(here[i], here[j])

	floors[fid] = entry
	return entry.points.size()


func _room_at(rooms: Array, at: Vector2) -> Variant:
	var best: Variant = null
	var best_area := INF
	for r in rooms:
		var rect: Array = r["rect"]
		if at.x < float(rect[0]) or at.x > float(rect[2]) \
				or at.y < float(rect[1]) or at.y > float(rect[3]):
			continue
		var area := (float(rect[2]) - float(rect[0])) \
				* (float(rect[3]) - float(rect[1]))
		if area < best_area:
			best_area = area
			best = r
	return best


func _in_rect(rect: Array, at: Vector2, pad: float) -> bool:
	return at.x >= float(rect[0]) - pad and at.x <= float(rect[2]) + pad \
			and at.y >= float(rect[1]) - pad and at.y <= float(rect[3]) + pad


func _nearest_two(entry: Dictionary, ids: Array, at: Vector2) -> Array:
	var scored: Array = []
	for id in ids:
		for pt in entry.points:
			if pt.id == id:
				scored.append([at.distance_to(pt.at), id])
	scored.sort_custom(func(a, b): return a[0] < b[0])
	return [scored[0][1], scored[1][1]] if scored.size() >= 2 else []


## Which floor a world-space height belongs to.
func floor_at(y: float) -> String:
	var best := ""
	var dist := INF
	for fid in floors:
		var d: float = absf(y - float(floors[fid].z))
		if d < dist:
			dist = d
			best = fid
	return best


## Same-floor route in world space, endpoints included. Falls back to a
## straight line if either end finds no node — a resident must never be
## stranded by a hole in the graph.
func route(from: Vector3, to: Vector3) -> PackedVector3Array:
	var fid := floor_at(from.y)
	if fid == "" or not floors.has(fid):
		return PackedVector3Array([from, to])
	var entry: Dictionary = floors[fid]
	var astar: AStar3D = entry.astar
	if astar.get_point_count() == 0:
		return PackedVector3Array([from, to])
	var a := astar.get_closest_point(from)
	var b := astar.get_closest_point(to)
	var path := astar.get_point_path(a, b)
	var out := PackedVector3Array([from])
	for p in path:
		out.append(p)
	out.append(to)
	return out
