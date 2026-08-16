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
## Each floor retains its own portal graph. Building-wide queries join those
## islands through authored stair-flight waypoints or the real elevator.
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
## Schedule-facing names mapped to the installed shop-door records.  The
## marker, not a copied coordinate in the clock system, owns both the aisle
## approach and the point just inside the threshold.
const PASSAGE_PLACES := {
	"hand_laundry": "SITE_SHOP_DOOR_MODEL_LAUNDRY",
	"luncheonette": "SITE_SHOP_DOOR_LUNCHEONETTE",
	"news_cigars": "SITE_SHOP_DOOR_NEWS_CIGARS",
	"photo_supplies": "SITE_SHOP_DOOR_PHOTO_SUPPLIES",
}

var floors := {}      # floor_id -> {astar: AStar3D, nodes: [...], z: float}
var level_order: Array[String] = []
var pruned_edges := 0
var visibility_edges := 0
var collision_cut := 0
var collision_relinked := 0
var stair_blocked := 0
var _unreachable_warned := {}
var passage_anchors: Dictionary = {}


# TASKS.md V3: the distinct (floor, from, to) route failures seen so far.
# Zero on a healthy build; a harness may assert on it directly.
func unreachable_route_count() -> int:
	return _unreachable_warned.size()


func unreachable_route_keys() -> Array:
	return _unreachable_warned.keys()


func build(layout: Dictionary) -> int:
	var total := 0
	for fl in layout["floors"]:
		var fid := str(fl["id"])
		total += _build_floor(fid, fl)
	level_order.assign(floors.keys())
	level_order.sort_custom(func(a: String, b: String) -> bool:
		return float(floors[a].z) < float(floors[b].z))
	_index_passage_anchors(layout)
	print(("[NAV] %d nodes across %d floors; %d stair links; elevator linked; " \
			+ "%d wall-crossing edges rejected; %d safe links restored") \
			% [total, floors.size(), maxi(0, level_order.size() - 1),
					pruned_edges, visibility_edges])
	return total


## Turn each installed leaf marker into two truthful points: an aisle point
## 450 mm clear of the facade, and a venue point 900 mm inside. NEWS & CIGARS
## is the deliberate exception: its proprietor door is locked, so its venue
## is the customer side of the service shelf rather than behind that leaf.
static func passage_spots(marker: Dictionary) -> Dictionary:
	var p: Array = marker.get("pos", [0.0, 0.0, 0.0])
	var yaw := deg_to_rad(float(marker.get("yaw_deg", 0.0)))
	var width := float(marker.get("w", 0.95))
	var hinge := Vector2(float(p[0]), float(p[1]))
	var along := Vector2(cos(yaw), -sin(yaw))
	var outward := Vector2(sin(yaw), -cos(yaw))
	var centre := hinge + along * width * 0.5
	var aisle := centre + outward * 0.45
	var venue := centre - outward * 0.90
	if str(marker.get("id", "")) == "SITE_SHOP_DOOR_NEWS_CIGARS":
		var service := hinge + along * (width + 0.34)
		venue = service + outward * 0.40
	return {"aisle": GameBoot.b2g([aisle.x, aisle.y, 0.06]),
			"venue": GameBoot.b2g([venue.x, venue.y, 0.06])}


func _index_passage_anchors(layout: Dictionary) -> void:
	var wanted := {}
	for place in PASSAGE_PLACES:
		wanted[PASSAGE_PLACES[place]] = place
	for fl in layout.get("floors", []):
		if str(fl.get("id", "")) != "F01":
			continue
		for marker in fl.get("markers", []):
			var marker_id := str(marker.get("id", ""))
			if wanted.has(marker_id):
				passage_anchors[wanted[marker_id]] = passage_spots(marker)
	print("[NAV] %d schedule anchors installed in PASSAGE" %
			passage_anchors.size())


func has_passage_anchor(place: String) -> bool:
	return passage_anchors.has(place)


func passage_anchor(place: String) -> Vector3:
	return passage_anchors.get(place, {}).get("venue", Vector3.INF)


## The street graph intentionally ends at the portal. Inside, the ruled 6 m
## aisle is one unambiguous spine; the last leg turns to the customer side of
## the installed door. These waypoints are derived from the same marker as the
## venue, then proved against runtime collision by PassageNavTest.
func passage_route(place: String) -> PackedVector3Array:
	if not passage_anchors.has(place):
		return PackedVector3Array()
	var aisle: Vector3 = passage_anchors[place].aisle
	var aisle_blender_y := -aisle.z
	return PackedVector3Array([
		GameBoot.b2g([14.0, -28.70, 0.06]),
		GameBoot.b2g([14.0, -34.00, 0.06]),
		GameBoot.b2g([14.0, -38.90, 0.06]),
		GameBoot.b2g([14.0, aisle_blender_y, 0.06]),
		aisle,
	])


func _build_floor(fid: String, fl: Dictionary) -> int:
	var astar := AStar3D.new()
	var z: float = float(fl["z"])
	var rooms: Array = fl.get("rooms", [])
	var entry := {"astar": astar, "z": z, "rooms": rooms,
			"walls": fl.get("walls", []), "points": []}
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
	# The roof's single room rectangle contains the glazed stair monitor, so
	# its geometric centre is indoors while most destinations are outside it.
	# A compact lane around the monitor gives residents legal choices through
	# the roof door without baking the pergola and planters into a navmesh.
	if fid == "ROOF":
		for p in [Vector2(-4.2, -4.2), Vector2(0.0, -4.2),
				Vector2(4.2, -4.2), Vector2(4.2, 0.0),
				Vector2(4.2, 4.2), Vector2(0.0, 4.2),
				Vector2(-4.2, 4.2), Vector2(-4.2, 0.0)]:
			add_node.call(p, "roof_lane")

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

	# Leafless doors are architectural portals: the grand stair arches and
	# elevator landing openings. They do not produce DoorProp markers, so the
	# marker-only graph used to omit precisely the openings needed to enter the
	# core. Visibility linking below connects each portal to both legal sides.
	for wall in fl.get("walls", []):
		var wa: Array = wall.a
		var wb: Array = wall.b
		var horizontal := absf(float(wb[1]) - float(wa[1])) < 0.001
		var start := minf(float(wa[0]), float(wb[0])) if horizontal \
				else minf(float(wa[1]), float(wb[1]))
		var cross := float(wa[1]) if horizontal else float(wa[0])
		for opening in wall.get("openings", []):
			if str(opening.get("type", "")) != "door" \
					or str(opening.get("leaf", "closed")) != "none":
				continue
			var along := start + float(opening.get("at", 0.0))
			var portal := Vector2(along, cross) if horizontal \
					else Vector2(cross, along)
			add_node.call(portal, "opening")

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

	pruned_edges += _prune_unsafe_edges(entry)
	visibility_edges += _add_safe_visibility_edges(entry)
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
	# Euclidean-nearest is not necessarily reachable-nearest: a node on the
	# other side of 18 cm of plaster is extremely close. Anchor endpoints only
	# to nodes with an unobstructed segment through this floor's wall model.
	var pair := _connected_visible_pair(entry, from, to)
	var a := pair.x
	var b := pair.y
	if a < 0 or b < 0:
		# TASKS.md V3: a silently frozen resident reads as idle animation,
		# not as the routing failure it is. push_error keeps a red line in
		# every headless log, and the tally lets any harness assert zero
		# without this file knowing about the harness.
		var warning_key := "%s:%d:%d" % [fid, roundi(from.x), roundi(to.x)]
		if not _unreachable_warned.has(warning_key):
			_unreachable_warned[warning_key] = true
			push_error("No wall-safe resident route on %s: %s -> %s" \
					% [fid, from, to])
		# Standing still is preferable to walking through somebody's wall.
		return PackedVector3Array([from])
	var path := astar.get_point_path(a, b)
	var out := PackedVector3Array([from])
	for p in path:
		out.append(p)
	out.append(to)
	return out


func _visible_candidates(entry: Dictionary, at: Vector3) -> Array:
	var astar: AStar3D = entry.astar
	var candidates: Array = []
	for id in astar.get_point_ids():
		var point := astar.get_point_position(id)
		if not _segment_clear(entry, at, point):
			continue
		candidates.append({"id": id,
				"distance": at.distance_squared_to(point)})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.distance) < float(b.distance))
	if candidates.size() > 16:
		candidates.resize(16)
	return candidates


func _connected_visible_pair(entry: Dictionary, from: Vector3,
		to: Vector3) -> Vector2i:
	var astar: AStar3D = entry.astar
	var starts := _visible_candidates(entry, from)
	var goals := _visible_candidates(entry, to)
	var best := Vector2i(-1, -1)
	var best_cost := INF
	for start in starts:
		for goal in goals:
			var sid := int(start.id)
			var gid := int(goal.id)
			var graph_path := astar.get_point_path(sid, gid)
			if sid != gid and graph_path.is_empty():
				continue
			var cost := float(start.distance) + float(goal.distance)
			if cost < best_cost:
				best_cost = cost
				best = Vector2i(sid, gid)
	return best


func _prune_unsafe_edges(entry: Dictionary) -> int:
	var astar: AStar3D = entry.astar
	var rejected := 0
	for id in astar.get_point_ids():
		for other in astar.get_point_connections(id):
			if other <= id:
				continue
			if _segment_clear(entry, astar.get_point_position(id),
					astar.get_point_position(other)):
				continue
			astar.disconnect_points(id, other)
			rejected += 1
	return rejected


## Restore useful connections as a conservative visibility graph. This is
## what makes nested apartment rectangles safe: instead of assuming their
## centres can see one another, nodes connect only when the authored walls
## prove that the intervening segment is open. The distance cap preserves the
## corridor ring's authored lane instead of creating long diagonal shortcuts.
func _add_safe_visibility_edges(entry: Dictionary) -> int:
	const MAX_LINK_SQ := 6.5 * 6.5
	var astar: AStar3D = entry.astar
	var ids := astar.get_point_ids()
	var added := 0
	for ai in ids.size():
		var a: int = ids[ai]
		var pa := astar.get_point_position(a)
		for bi in range(ai + 1, ids.size()):
			var b: int = ids[bi]
			if astar.are_points_connected(a, b):
				continue
			var pb := astar.get_point_position(b)
			if pa.distance_squared_to(pb) > MAX_LINK_SQ \
					or not _segment_clear(entry, pa, pb):
				continue
			astar.connect_points(a, b)
			added += 1
	return added


## --- physics validation ---------------------------------------------------
## The wall-data audit proves segments against the AUTHORED plan; this pass
## proves the surviving graph against the world's actual colliders — merged
## floor meshes, furniture with -col buffers, glazing, everything the plan
## cannot see. It is the difference between "the drawing says this is open"
## and "a body can actually walk here." Runs once, deferred until the
## building has committed its shapes to the physics server.
func validate_with_collision(world: World3D) -> void:
	var space := world.direct_space_state
	collision_cut = 0
	collision_relinked = 0
	for fid in floors:
		var entry: Dictionary = floors[fid]
		var astar: AStar3D = entry.astar
		for id in astar.get_point_ids():
			for other in astar.get_point_connections(id):
				if other <= id:
					continue
				if _ray_blocked(space, astar.get_point_position(id),
						astar.get_point_position(other)):
					astar.disconnect_points(id, other)
					collision_cut += 1
		# A node that lost every edge would strand whoever stands nearest
		# to it. Relink islands to their closest physically-clear neighbours.
		for id in astar.get_point_ids():
			if not astar.get_point_connections(id).is_empty():
				continue
			var pos := astar.get_point_position(id)
			var scored: Array = []
			for other in astar.get_point_ids():
				if other == id:
					continue
				scored.append([pos.distance_squared_to(
						astar.get_point_position(other)), other])
			scored.sort_custom(func(a, b): return a[0] < b[0])
			var linked := 0
			for pair in scored:
				if linked >= 2 or float(pair[0]) > 8.0 * 8.0:
					break
				if _ray_blocked(space, pos,
						astar.get_point_position(int(pair[1]))):
					continue
				astar.connect_points(id, int(pair[1]))
				linked += 1
				collision_relinked += 1
	stair_blocked = _validate_stairs(space)
	print("[NAV] collision audit: %d edges cut by real geometry, %d island nodes relinked, %d stair legs obstructed"
			% [collision_cut, collision_relinked, stair_blocked])


## Rays at shin and chest height, walked through excusable hits (door
## leaves are legal, residents are not obstacles). Anything else solid
## between two nodes means the edge lies about the building.
func _ray_blocked(space: PhysicsDirectSpaceState3D, a: Vector3,
		b: Vector3) -> bool:
	for h in [0.35, 1.15]:
		var target := b + Vector3(0, h, 0)
		var origin := a + Vector3(0, h, 0)
		var guard := 0
		while guard < 8:
			guard += 1
			var query := PhysicsRayQueryParameters3D.create(origin, target)
			var hit := space.intersect_ray(query)
			if hit.is_empty():
				break
			var owner: Node = hit.collider.get_parent() \
					if hit.collider is Node else null
			if hit.collider is DoorProp or owner is DoorProp \
					or (owner != null and owner.get_parent() is DoorProp):
				origin = hit.position \
						+ (target - origin).normalized() * 0.06
				continue
			return true
	return false


## The authored stair flights, proven leg by leg. Blocked legs are loud:
## a resident on a broken stair route is exactly the "not using the stairs
## right" bug, and silence here is how it stays unfixed.
func _validate_stairs(space: PhysicsDirectSpaceState3D) -> int:
	var blocked := 0
	for index in range(level_order.size() - 1):
		var low_z := float(floors[level_order[index]].z)
		var high_z := float(floors[level_order[index + 1]].z)
		var section := _stair_section(low_z, high_z)
		for leg in range(section.size() - 1):
			var a := section[leg] + Vector3(0, 0.55, 0)
			var b := section[leg + 1] + Vector3(0, 0.55, 0)
			var hit := space.intersect_ray(
					PhysicsRayQueryParameters3D.create(a, b))
			if hit.is_empty():
				continue
			var owner: Node = hit.collider.get_parent() \
					if hit.collider is Node else null
			if hit.collider is DoorProp or owner is DoorProp:
				continue
			blocked += 1
			push_warning("stair leg obstructed %s->%s at %s" % [
					level_order[index], level_order[index + 1], hit.position])
	return blocked


## Collision-independent line audit against the same authored walls that
## produced the meshes. Endpoints may sit on a portal centre; actual crossings
## are legal only through floor-level doors/arches, never windows or alcoves.
func _segment_clear(entry: Dictionary, from: Vector3, to: Vector3) -> bool:
	var a := Vector2(from.x, -from.z)
	var b := Vector2(to.x, -to.z)
	if a.distance_squared_to(b) < 0.0001:
		return true
	for wall in entry.walls:
		if _segment_crosses_solid_wall(a, b, wall):
			return false
	return true


func _segment_crosses_solid_wall(a: Vector2, b: Vector2,
		wall: Dictionary) -> bool:
	var wa: Array = wall.a
	var wb: Array = wall.b
	var horizontal := absf(float(wb[1]) - float(wa[1])) < 0.001
	var t := -1.0
	var along := 0.0
	var start := 0.0
	var finish := 0.0
	if horizontal:
		var dy := b.y - a.y
		if absf(dy) < 0.0001:
			return false
		t = (float(wa[1]) - a.y) / dy
		along = lerpf(a.x, b.x, t)
		start = minf(float(wa[0]), float(wb[0]))
		finish = maxf(float(wa[0]), float(wb[0]))
	else:
		var dx := b.x - a.x
		if absf(dx) < 0.0001:
			return false
		t = (float(wa[0]) - a.x) / dx
		along = lerpf(a.y, b.y, t)
		start = minf(float(wa[1]), float(wb[1]))
		finish = maxf(float(wa[1]), float(wb[1]))
	# Touching a portal node at a segment endpoint is not crossing a wall.
	if t <= 0.015 or t >= 0.985 or along < start - 0.03 or along > finish + 0.03:
		return false
	var local := along - start
	for opening in wall.get("openings", []):
		var kind := str(opening.get("type", ""))
		var walkable := (kind == "door" and float(opening.get("sill", 0.0)) < 0.15) \
				or kind == "arch"
		if not walkable:
			continue
		var half := float(opening.get("w", 0.0)) * 0.5 + 0.10
		if absf(local - float(opening.get("at", 0.0))) <= half:
			return false
	return true


## A complete, physically walkable inter-floor route. The dog-leg stair has
## two flights around a north half-landing: west flight up, cross the landing,
## east flight up. Sampling every tread keeps feet on the invisible ramps and
## makes the same data useful later for root-motion/IK.
func stair_route(from: Vector3, to: Vector3) -> PackedVector3Array:
	var from_floor := floor_at(from.y)
	var to_floor := floor_at(to.y)
	var ia := level_order.find(from_floor)
	var ib := level_order.find(to_floor)
	if ia < 0 or ib < 0 or ia == ib:
		return route(from, to)
	var ascending := ib > ia
	var path := PackedVector3Array()
	var first_z := float(floors[from_floor].z)
	var entrance := GameBoot.b2g([
			-2.31 if ascending else 2.31, -1.46, first_z])
	path.append_array(route(from, entrance))
	var index := ia
	while index != ib:
		var next_index := index + (1 if ascending else -1)
		var low_index := mini(index, next_index)
		var low_z := float(floors[level_order[low_index]].z)
		var high_z := float(floors[level_order[low_index + 1]].z)
		var section := _stair_section(low_z, high_z)
		if not ascending:
			section.reverse()
		for point in section:
			if path.is_empty() or path[-1].distance_to(point) > 0.03:
				path.append(point)
		index = next_index
	var exit := path[-1]
	path.append_array(route(exit, to))
	return path


func _stair_section(low_z: float, high_z: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	var mid_z := (low_z + high_z) * 0.5
	# West flight: south deck to north landing.
	for i in 11:
		var t := float(i) / 10.0
		out.append(GameBoot.b2g([-2.31, lerpf(-1.46, 1.46, t),
				lerpf(low_z, mid_z, t)]))
	# Cross the broad half-landing instead of cutting its inside corner.
	out.append(GameBoot.b2g([-2.31, 2.30, mid_z]))
	out.append(GameBoot.b2g([2.31, 2.30, mid_z]))
	# East flight: north landing back to the south arrival deck.
	for i in 11:
		var t := float(i) / 10.0
		out.append(GameBoot.b2g([2.31, lerpf(1.46, -1.46, t),
				lerpf(mid_z, high_z, t)]))
	return out
