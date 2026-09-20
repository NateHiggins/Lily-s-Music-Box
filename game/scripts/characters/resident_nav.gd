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
var collision_detour_nodes := 0
var collision_detour_edges := 0
var stair_blocked := 0
var _unreachable_warned := {}
var passage_anchors: Dictionary = {}

const DIRECT_MAX_LENGTH := 1.25
const DIRECT_RADIUS := 0.33
const DIRECT_HEIGHT := 1.65
var _validated_world: WeakRef
var _direct_shape: CapsuleShape3D
## Both resident constructors use this Body capsule. Portal/endpoint checks
## need its actual width: a valid resident can stand beside a switch where
## the separate conservative direct/detour envelope correctly refuses.
const RESIDENT_BODY_RADIUS := 0.28
const RESIDENT_BODY_HEIGHT := 1.55
var _resident_shape: CapsuleShape3D
var _managed_leaf_rids: Array[RID] = []


# TASKS.md V3: the distinct (floor, from, to) route failures seen so far.
# Zero on a healthy build; a harness may assert on it directly.
func unreachable_route_count() -> int:
	return _unreachable_warned.size()


func unreachable_route_keys() -> Array:
	return _unreachable_warned.keys()


func build(layout: Dictionary) -> int:
	_validated_world = null
	_managed_leaf_rids.clear()
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
			"walls": fl.get("walls", []), "slabs": fl.get("slabs", []), "points": []}
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
		var portal: Dictionary = _door_portal_spec(m, entry.walls)
		var at: Vector2 = portal.point
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
		# A centre alone still invites grazing diagonal paths from the sparse
		# corridor ring. The final approach to each matched aperture is normal
		# to its wall, with body clearance independent of room-sampling PROBE.
		if portal.has("normal"):
			for side in [-1.0, 1.0]:
				add_node.call(at + Vector2(portal.normal) * float(portal.approach_distance) * side,
						"door_approach:" + str(m.get("id", "")) + ":" + str(side))

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


## collect_door_markers stores each leaf's HINGE; DoorProp extends along
## local +X. Match that hinge/width/orientation to an authored wall opening
## before moving the navigation point to its centre. Separately authored
## exterior/shop anchors and already-centred points keep their coordinates.
func _door_portal_spec(marker: Dictionary, walls: Array) -> Dictionary:
	var p: Array = marker["pos"]
	var hinge := Vector2(float(p[0]), float(p[1]))
	var width := float(marker.get("w", 0.81))
	var angle := deg_to_rad(-float(marker.get("yaw_deg", 0.0)))
	var center := hinge + Vector2(cos(angle), sin(angle)) * width * 0.5
	for wall in walls:
		var wa: Array = wall.a
		var wb: Array = wall.b
		var horizontal := absf(float(wb[1]) - float(wa[1])) < 0.001
		var start := minf(float(wa[0]), float(wb[0])) if horizontal \
				else minf(float(wa[1]), float(wb[1]))
		var cross := float(wa[1]) if horizontal else float(wa[0])
		for opening in wall.get("openings", []):
			if str(opening.get("type", "")) != "door" or str(opening.get("leaf", "closed")) == "none" \
					or absf(float(opening.get("w", 0.0)) - width) > 0.001:
				continue
			var along := start + float(opening.get("at", 0.0))
			var aperture := Vector2(along, cross) if horizontal else Vector2(cross, along)
			if hinge.distance_to(aperture) < 0.001:
				return {"point": hinge}
			if center.distance_to(aperture) < 0.001:
				# Same resident radius used by PassageNav's capsule contract;
				# wall half-thickness plus 8cm margin keeps endpoint bodies clear.
				var clearance := float(wall.get("t", 0.18)) * 0.5 + 0.33 + 0.08
				return {"point": aperture, "normal": Vector2(-sin(angle), cos(angle)),
						"approach_distance": clearance}
	return {"point": hinge}


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


## Same-floor route in world space, endpoints included. A validated floor
## refuses disconnected endpoints rather than crossing a wall or collider.
func route(from: Vector3, to: Vector3) -> PackedVector3Array:
	var fid := floor_at(from.y)
	if fid == "" or not floors.has(fid):
		return PackedVector3Array([from, to])
	var entry: Dictionary = floors[fid]
	var astar: AStar3D = entry.astar
	if astar.get_point_count() == 0:
		return PackedVector3Array([from, to])
	if floor_at(to.y) == fid and _direct_segment_clear(entry, from, to):
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


## A short public leg can be safer than detouring through a nearest portal.
## This is a conservative envelope, not the actor's Body shape: its cap centres
## at .33/1.32 with radius .33 contain Body's .28/1.27 with radius .28.
## Longer, sloped, unvalidated or obstructed routes retain the existing graph.
func _direct_segment_clear(entry: Dictionary, from: Vector3, to: Vector3) -> bool:
	if not from.is_finite() or not to.is_finite() \
			or absf(from.y - to.y) > 0.001 \
			or from.distance_squared_to(to) > DIRECT_MAX_LENGTH * DIRECT_MAX_LENGTH \
			or _validated_world == null or not is_inside_tree():
		return false
	var world: World3D = _validated_world.get_ref()
	if world == null or world != get_viewport().find_world_3d() \
			or not _segment_clear(entry, from, to) \
			or not _direct_slab_clear(entry, from, to):
		return false
	return _capsule_segment_clear(entry, from, to, world.direct_space_state)


## Shared capsule/support proof; callers own length and World3D admission.
## Direct routes and room detours default to the conservative envelope with
## no exclusions. Original portal/endpoint proof supplies the actual Body.
func _capsule_segment_clear(entry: Dictionary, from: Vector3, to: Vector3,
		space: PhysicsDirectSpaceState3D, floor_finish: bool = false,
		body: CapsuleShape3D = null, exclusions: Array[RID] = []) -> bool:
	var capsule := body
	if capsule == null:
		if _direct_shape == null:
			_direct_shape = CapsuleShape3D.new()
			_direct_shape.radius = DIRECT_RADIUS
			_direct_shape.height = DIRECT_HEIGHT
		capsule = _direct_shape
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.exclude = exclusions
	query.collide_with_areas = false
	query.margin = 0.001
	query.transform = Transform3D(Basis(), from + Vector3.UP * capsule.height * 0.5)
	# cast_motion ignores initial overlap, so neither endpoint may overlap.
	# Direct and detour callers supply no exclusions. Original portal checks
	# may supply only cached NPC-owned DoorProp leaf bodies; fixed geometry
	# and elevator panels are never excluded. Resident bodies use layer zero.
	if not space.intersect_shape(query, 1).is_empty():
		return false
	query.transform.origin = to + Vector3.UP * capsule.height * 0.5
	if not space.intersect_shape(query, 1).is_empty():
		return false
	query.transform.origin = from + Vector3.UP * capsule.height * 0.5
	query.motion = to - from
	var fractions := space.cast_motion(query)
	if fractions.size() != 2 or fractions[0] < 1.0 or fractions[1] < 1.0:
		return false
	# Authored holes are excluded continuously below. Physical support is a
	# separate sampled check: centre plus eight rim points at <= .20 m spacing.
	# A graph body proof may cross a thin physical floor finish above the authored
	# slab datum only while it remains strictly below the actual foot plane.
	# The full capsule sweep above still rejects raised/penetrating surfaces;
	# lower datum, normal, gaps, authored holes and rim checks stay unchanged.
	# Direct-route callers retain their original +/-1cm datum policy.
	var steps := maxi(1, ceili(from.distance_to(to) / 0.20))
	for i in range(steps + 1):
		var at := from.lerp(to, float(i) / float(steps))
		for spoke in range(9):
			var offset := Vector3.ZERO
			if spoke > 0:
				var angle := TAU * float(spoke - 1) / 8.0
				offset = Vector3(cos(angle), 0, sin(angle)) * capsule.radius
			var ray := PhysicsRayQueryParameters3D.create(
					at + offset + Vector3.UP * 0.10,
					at + offset - Vector3.UP * 0.10)
			ray.hit_from_inside = true
			ray.exclude = exclusions
			var hit := space.intersect_ray(ray)
			if hit.is_empty() or hit.normal.y < 0.99:
				return false
			var height := float(hit.position.y)
			var finish_below_feet := floor_finish and height >= float(entry.z) \
					and height < at.y - query.margin
			if absf(height - float(entry.z)) > 0.01 and not finish_below_feet:
				return false
	return true


func _direct_slab_clear(entry: Dictionary, from: Vector3, to: Vector3) -> bool:
	# The flat public leg keeps the actor's foot offset; it cannot bridge a step.
	var clearance := from.y - float(entry.z)
	if clearance < 0.015 or clearance > 0.08:
		return false
	var a := Vector2(from.x, -from.z)
	var b := Vector2(to.x, -to.z)
	for slab in entry.get("slabs", []):
		if absf(float(slab.z_top) - float(entry.z)) > 0.001 \
				or not _in_rect(slab.rect, a, -DIRECT_RADIUS) \
				or not _in_rect(slab.rect, b, -DIRECT_RADIUS):
			continue
		var blocked := false
		for hole in slab.get("holes", []):
			if _direct_hole_crossed(a, b, hole):
				blocked = true
				break
		if not blocked:
			return true
	return false


func _direct_hole_crossed(a: Vector2, b: Vector2, hole: Array) -> bool:
	# Clip against the radius-expanded hole rectangle, including its boundary.
	# Checking the whole segment avoids stepping over a narrow authored opening.
	var lo := Vector2(float(hole[0]), float(hole[1])) - Vector2.ONE * DIRECT_RADIUS
	var hi := Vector2(float(hole[2]), float(hole[3])) + Vector2.ONE * DIRECT_RADIUS
	var first := 0.0
	var last := 1.0
	for axis in range(2):
		var delta: float = b[axis] - a[axis]
		if absf(delta) < 0.000001:
			if a[axis] < lo[axis] or a[axis] > hi[axis]:
				return false
			continue
		var enter: float = (lo[axis] - a[axis]) / delta
		var leave: float = (hi[axis] - a[axis]) / delta
		first = maxf(first, minf(enter, leave))
		last = minf(last, maxf(enter, leave))
		if first > last:
			return false
	return true


func _exit_tree() -> void:
	_validated_world = null
	_managed_leaf_rids.clear()


func _visible_candidates(entry: Dictionary, at: Vector3) -> Array:
	var astar: AStar3D = entry.astar
	var candidates: Array = []
	for id in astar.get_point_ids():
		var point := astar.get_point_position(id)
		if not _segment_clear(entry, at, point): continue
		candidates.append({"id": id, "distance": at.distance_squared_to(point)})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.distance) < float(b.distance))
	var world: World3D = _validated_world.get_ref() if _validated_world != null else null
	var physical := world != null and is_inside_tree() and world == get_viewport().find_world_3d()
	var admitted: Array = []
	for candidate: Dictionary in candidates:
		var point := astar.get_point_position(int(candidate.id))
		if entry.get("detour_ids", {}).has(candidate.id):
			if not _detour_endpoint_clear(entry, at, point): continue
		elif physical and not _resident_endpoint_clear(entry, at, point):
			continue
		admitted.append(candidate)
		if admitted.size() == 16: break
	return admitted


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
	_validated_world = null
	_managed_leaf_rids.clear()
	if world == null:
		return
	var collision_started := Time.get_ticks_usec()
	var space := world.direct_space_state
	var live_world := is_inside_tree() and world == get_viewport().find_world_3d()
	if live_world: _index_managed_leaves(world)
	collision_cut = 0
	collision_relinked = 0
	collision_detour_nodes = 0
	collision_detour_edges = 0
	for fid in floors:
		var entry: Dictionary = floors[fid]
		var astar: AStar3D = entry.astar
		var portals := {}
		for point: Dictionary in entry.points:
			var tag := str(point.tag)
			if tag.begins_with("door:") or tag.begins_with("door_approach:") or tag == "opening":
				portals[point.id] = true
		for id in astar.get_point_ids():
			for other in astar.get_point_connections(id):
				if other <= id:
					continue
				var a := astar.get_point_position(id)
				var b := astar.get_point_position(other)
				var detours: Dictionary = entry.get("detour_ids", {})
				if _ray_blocked(space, a, b) or ((detours.has(id) or detours.has(other))
						and not _room_link_clear(entry, space, a, b)) \
						or (live_world and (portals.has(id) or portals.has(other))
						and not _resident_body_link_clear(entry, space, a, b)):
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
				var other := int(pair[1])
				var target := astar.get_point_position(other)
				var detours: Dictionary = entry.get("detour_ids", {})
				if _ray_blocked(space, pos, target) or ((detours.has(id) or detours.has(other))
						and not _room_link_clear(entry, space, pos, target)) \
						or (live_world and not _resident_body_link_clear(entry, space, pos, target)):
					continue
				astar.connect_points(id, other)
				linked += 1
				collision_relinked += 1
	stair_blocked = _validate_stairs(space)
	if is_inside_tree() and world == get_viewport().find_world_3d():
		_validated_world = weakref(world)
		var detour_started := Time.get_ticks_usec()
		for fid in floors:
			_repair_split_rooms(floors[fid], space)
		print("[NAV] room detour validation: %.3f ms" % ((Time.get_ticks_usec() - detour_started) / 1000.0))
	print("[NAV] full collision validation: %.3f ms" % ((Time.get_ticks_usec() - collision_started) / 1000.0))
	print("[NAV] room detours: %d body-clear nodes, %d body-clear links"
			% [collision_detour_nodes, collision_detour_edges])
	print("[NAV] collision audit: %d edges cut by real geometry, %d island nodes relinked, %d stair legs obstructed"
			% [collision_cut, collision_relinked, stair_blocked])


## Collect only the moving leaf owned by DoorProp. Fixed frames and lift
## panels cannot inherit a door exception merely by sharing a scene branch.
## RID-only cache is rebuilt with validation and cleared on build/tree exit.
func _index_managed_leaves(world: World3D) -> void:
	var pending: Array[Node] = [get_viewport()]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		var sub_view := node as SubViewport
		if sub_view != null and sub_view != get_viewport() and sub_view.find_world_3d() != world: continue
		var door := node as DoorProp
		if door != null:
			if is_instance_valid(door._body): _managed_leaf_rids.append(door._body.get_rid())
			continue
		for child in node.get_children(): pending.append(child)


func _resident_body_clear(entry: Dictionary, space: PhysicsDirectSpaceState3D,
		from: Vector3, to: Vector3) -> bool:
	if not from.is_finite() or not to.is_finite() or absf(from.y - to.y) > 0.001: return false
	if not _segment_clear(entry, from, to) or not _direct_slab_clear(entry, from, to): return false
	if _resident_shape == null:
		_resident_shape = CapsuleShape3D.new()
		_resident_shape.radius = RESIDENT_BODY_RADIUS
		_resident_shape.height = RESIDENT_BODY_HEIGHT
	return _capsule_segment_clear(entry, from, to, space, true, _resident_shape, _managed_leaf_rids)


func _resident_body_link_clear(entry: Dictionary, space: PhysicsDirectSpaceState3D,
		from: Vector3, to: Vector3) -> bool:
	var a := Vector3(from.x, float(entry.z) + 0.03, from.z)
	var b := Vector3(to.x, float(entry.z) + 0.03, to.z)
	return _resident_body_clear(entry, space, a, b)


func _resident_endpoint_clear(entry: Dictionary, from: Vector3, point: Vector3) -> bool:
	if _validated_world == null or not is_inside_tree(): return false
	var world: World3D = _validated_world.get_ref()
	if world == null or world != get_viewport().find_world_3d(): return false
	return _resident_body_clear(entry, world.direct_space_state, from, Vector3(point.x, from.y, point.z))


## Collision pruning can split a furnished room into two multi-node islands.
## The zero-neighbour repair above cannot see that case. Try eight interior
## samples derived from this room's rectangle, retaining only components that
## actually bridge existing islands. Never restore the obstructed old edge.
func _repair_split_rooms(entry: Dictionary, space: PhysicsDirectSpaceState3D) -> void:
	var graph: AStar3D = entry.astar
	for room: Dictionary in entry.rooms:
		if str(room.kind) == "corridor": continue
		var components := _graph_components(graph)
		var here: Array[int] = []
		var groups := {}
		for id in graph.get_point_ids():
			var at := graph.get_point_position(id)
			var owner: Variant = _room_at(entry.rooms, Vector2(at.x, -at.z))
			if owner == null or str(owner.id) != str(room.id): continue
			here.append(id)
			groups[components[id]] = true
		if groups.size() < 2: continue
		var trial := AStar3D.new()
		for id in here: trial.add_point(id, graph.get_point_position(id))
		# These trial-only links represent existing global connectivity. They
		# are never copied to the production graph or used as movement edges.
		var representative := {}
		for id in here:
			var group: int = components[id]
			if representative.has(group): trial.connect_points(id, representative[group])
			else: representative[group] = id
		var added: Array[int] = []
		var next_id := graph.get_available_point_id()
		var rect: Array = room.rect
		for u in [0.25, 0.5, 0.75]:
			for v in [0.25, 0.5, 0.75]:
				if u == 0.5 and v == 0.5: continue
				var xy := Vector2(lerpf(float(rect[0]), float(rect[2]), u),
						lerpf(float(rect[1]), float(rect[3]), v))
				var owner: Variant = _room_at(entry.rooms, xy)
				if owner == null or str(owner.id) != str(room.id): continue
				var at := Vector3(xy.x, float(entry.z), -xy.y)
				var duplicate := false
				for existing in here:
					if graph.get_point_position(existing).distance_squared_to(at) < 0.000001:
						duplicate = true
						break
				if duplicate: continue
				if not _room_link_clear(entry, space, at, at): continue
				while graph.has_point(next_id) or trial.has_point(next_id): next_id += 1
				trial.add_point(next_id, at)
				added.append(next_id)
				next_id += 1
		var links: Array[Vector2i] = []
		for id in added:
			for other in trial.get_point_ids():
				if other == id or (other in added and other < id): continue
				if not _room_link_clear(entry, space, trial.get_point_position(id),
						trial.get_point_position(other)): continue
				trial.connect_points(id, other)
				links.append(Vector2i(id, other))
		var trial_components := _graph_components(trial)
		var reached := {}
		for id in here:
			var group: int = trial_components[id]
			if not reached.has(group): reached[group] = {}
			reached[group][components[id]] = true
		for id in added:
			if reached.get(trial_components[id], {}).size() < 2: continue
			var at := trial.get_point_position(id)
			graph.add_point(id, at)
			entry.points.append({"id": id, "at": Vector2(at.x, -at.z),
					"tag": "room_detour:" + str(room.id)})
			if not entry.has("detour_ids"): entry.detour_ids = {}
			entry.detour_ids[id] = true
			collision_detour_nodes += 1
		for link in links:
			if not graph.has_point(link.x) or not graph.has_point(link.y): continue
			graph.connect_points(link.x, link.y)
			collision_detour_edges += 1


func _graph_components(graph: AStar3D) -> Dictionary:
	var components := {}
	for id in graph.get_point_ids():
		if components.has(id): continue
		var pending: Array[int] = [id]
		components[id] = id
		while not pending.is_empty():
			var current: int = pending.pop_back()
			for neighbour in graph.get_point_connections(current):
				if components.has(neighbour): continue
				components[neighbour] = id
				pending.append(neighbour)
	return components


func _room_link_clear(entry: Dictionary, space: PhysicsDirectSpaceState3D,
		from: Vector3, to: Vector3) -> bool:
	# Graph points use slab height; ordinary resident locomotion keeps the
	# actor's 3 cm foot offset. Limit links to the existing visibility radius.
	if from.distance_squared_to(to) > 6.5 * 6.5: return false
	var a := Vector3(from.x, float(entry.z) + 0.03, from.z)
	var b := Vector3(to.x, float(entry.z) + 0.03, to.z)
	return _segment_clear(entry, a, b) and _direct_slab_clear(entry, a, b) \
			and _capsule_segment_clear(entry, a, b, space, true)


func _detour_endpoint_clear(entry: Dictionary, from: Vector3, point: Vector3) -> bool:
	if _validated_world == null or not is_inside_tree() or not from.is_finite() \
			or not point.is_finite() or from.distance_squared_to(point) > 6.5 * 6.5: return false
	var world: World3D = _validated_world.get_ref()
	if world == null or world != get_viewport().find_world_3d(): return false
	var to := Vector3(point.x, from.y, point.z)
	return _direct_slab_clear(entry, from, to) \
			and _capsule_segment_clear(entry, from, to, world.direct_space_state, true)


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
