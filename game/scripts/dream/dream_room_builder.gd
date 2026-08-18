class_name DreamRoomBuilder
extends RefCounted
## ONE ROOM, PLACED AGAINST THE DOOR YOU CAME THROUGH.
##
## DreamAtlas names the rooms of the fractal Orison; this turns one of those
## names into space. It is the second half of the ruling of 2026-08-17 and it
## replaces DreamMazeBuilder.assemble(), which walks a global chain from D00
## and lays the whole building out at once. Nothing here ever holds the whole
## building, because there isn't one.
##
## ─────────────────────────────────────────────────────────────────────────
## THE ONE RULE OF PLACEMENT
##
## A room is positioned so that its entry door IS the door you just left
## through -- the same aperture, the same 0.20 m wall, from the other side.
## That is the whole placement algorithm. It is DreamMazeBuilder._door_record
## read backwards: that function asks "given this room and this connector,
## where is the opening", and this one asks "given this opening, where is the
## room". Nothing reconciles a room against one placed anywhere else, and that
## refusal is the thesis, not an omission. See dream_atlas.gd, idea 2.
##
## ─────────────────────────────────────────────────────────────────────────
## THE POCKET, AND WHY IT IS SHORT-TERM MEMORY
##
## Rooms are built ahead of the player and freed behind. The set that is live
## at any moment is the POCKET, and it is deliberately not just "what is
## nearby": it is the last TRAIL_LEN rooms the player actually walked, plus
## every immediate neighbour of the room they are in.
##
## That shape is a mechanic, not a memory budget. While the room you came from
## is still in the trail, walking back through your entry door returns you to
## it -- the building is locally consistent and you can retrace. Once it falls
## out of the trail the space is reclaimed, and that same door now opens on
## DreamAtlas.step(path, 0), which is somewhere else with the same feeling.
## The player can therefore LEARN the rule "I can go back three rooms", which
## is the brief's target emotion ("I know this building, I am getting better
## at surviving it") rather than undirected disorientation. It is also just
## true to the fiction: a mind holds a few rooms and confabulates the rest.
##
## The global non-overlap guarantee of the chain builder is gone -- it cannot
## exist in an infinite building. What replaces it is exact and enforced here:
## NO TWO ROOMS IN THE LIVE POCKET OVERLAP. Where a neighbour cannot be placed
## without overlapping a live room, its door is built SEALED (solid wall, no
## opening), which is an authored state this project already ships for
## later-slot connectors. A remembered building with a door that does not open
## is not a degradation; it is the correct picture.
##
## ─────────────────────────────────────────────────────────────────────────
## THE FAIRNESS CLAMP, AND WHAT MEASURING IT TURNED UP
##
## DreamAtlas's SCALE fault drifts a room to 0.80..1.22x. Hazard sockets are
## authored in module-local metres, so a room that shrinks a fifth carries its
## hazard a fifth closer to its own doorway -- and the warning a hazard owes
## the player is a fixed number of SECONDS, which does not shrink with it.
## Gate C's margins are therefore no longer constants a test can measure once.
## They are a per-room constraint this builder has to enforce at build time.
##
## Enforcing it required first measuring what the authored building actually
## provides, and the answer was not what the ring assumed: SIX OF THE EIGHT
## authored sockets are ALREADY below their owed warning when that warning is
## measured from their own doorway. counterweight_passage is 0.011 s against
## 0.75 s owed. The shipped dream passes Gate C only because the tell is not
## occluded -- it crosses the wall and fires while the player is still in the
## previous room. dream_perception_test.gd knows this and prints it as a
## verdict rather than a failure ("a room-local tell would NOT be fair -- the
## graph must attenuate, not silence").
##
## So an absolute clamp is the wrong instrument. Requiring every room to give
## its owed warning at its own doorway would force scale >= 1.0 on six of the
## eight, and would be enforcing a standard the real building never met.
##
## The clamp is RELATIVE, and it is one line of intent:
##
##     SCALE MAY GROW A ROOM FREELY. IT MAY ONLY SHRINK A ROOM WHILE EVERY
##     ARMED HAZARD KEEPS THE DOORWAY WARNING THE AUTHORED MODULE GAVE IT,
##     OR THE WARNING IT IS OWED, WHICHEVER IS LESS.
##
## The "whichever is less" is what makes it both sound and satisfiable: a room
## already below owed may not get worse, and a room above owed may shrink down
## to owed but no further. Fairness can never regress, and the clamp never
## demands something the authored geometry could not do either. In practice it
## costs the two roomy hazards a little drift (D01 floors near 0.66, D06 near
## 0.85) and pins the six tight ones at 1.00 -- they may still swell to 1.22x,
## so the fault stays visible in the direction where it is safe to be.

const CATALOG_PATH := "res://data/dream_module_catalog.json"

## Shared with DreamMazeBuilder rather than redefined: a joint is one real
## wall, and two different thicknesses would leave a seam you could see.
const WALL_T := DreamMazeBuilder.WALL_T

## How many rooms of the walked path stay real behind the player. Three is
## chosen to be learnable: far enough that an ordinary backtrack works and the
## world feels solid, short enough that the player finds the edge of it within
## one passage and understands that the building forgets.
const TRAIL_LEN := 3

## The first place inside a room a player can be standing, measured from the
## aperture. This is not a new number: it is DreamMazeBuilder._APPROACH_M, and
## dream_perception_test.gd measures its door margins from exactly this point
## (_door_margin takes the last waypoint of the route in). The fairness clamp
## below must use the same point the gate uses, or it is clamping a different
## quantity than the one being judged.
const DOOR_INSIDE_M := 0.5

## Keep an aperture off the corner by more than the catalog's own minimum
## connector margin, so a door never lands where two wall bands meet.
const CORNER_MARGIN_M := 0.10

## Salts. THESE ARE GOLDEN VECTORS THE MOMENT THEY SHIP. Every one of them
## names a geometric fact of every room in every campaign; changing one
## silently relays the whole building for every existing save, with no error,
## exactly as dream_atlas.gd's salts do. If a placement test fails, the
## question is never "what is the new number".
const SALT_ENTRY_OFFSET := 0x0E17A1
const SALT_DOOR_SIDE := 0x5DEA11
const SALT_DOOR_OFFSET := 0x0FF5E7

## Bisection steps for the fairness clamp. A fixed count rather than a
## tolerance loop, so the result is bit-identical on every machine.
const CLAMP_STEPS := 24

var atlas: DreamAtlas
var catalog: Dictionary = {}
var clear_ceiling := 3.015
var run_speed := 4.6
var door_w := 0.91
var door_h := 2.13
## The profile's hazard allowlist. Same argument as
## DreamMazeBuilder.build_geometry: geometry and arming must come from one
## decision, and the fairness clamp must only pay for hazards that can fire.
var armed: Array = []

## key -> room record. The pocket. Never the building.
var _live: Dictionary = {}
## key -> Node3D of built geometry, parallel to _live.
var _nodes: Dictionary = {}
## The walked path, most recent last, at most TRAIL_LEN entries.
var _trail: Array[String] = []
## Diagnostics for the harness and the tests; never read by gameplay.
var sealed_doors := 0
var clamped_rooms := 0


func setup(dream_atlas: DreamAtlas, hazard_allowlist: Array = []) -> void:
	atlas = dream_atlas
	catalog = DreamMazeBuilder.load_catalog()
	armed = hazard_allowlist
	var constants: Dictionary = catalog.get("constants", {})
	clear_ceiling = float(constants.get("clear_ceiling_m", 3.015))
	run_speed = float(constants.get("player_run_speed_mps", 4.6))
	door_w = float(constants.get("connector_width_m", 0.91))
	door_h = float(constants.get("connector_height_m", 2.13))


## A path is a room's name; this is that name as a dictionary key. Dots rather
## than raw concatenation because door indices reach 3 and "1,2" must never
## collide with "12".
##
## The "@" is not decoration. The room the player wakes in has an EMPTY path,
## so without a prefix its key is the empty string -- and the empty string is
## also how every other part of this file says "no room": an unset leads_to, a
## nav lookup that found nothing, a child with no parent. Conflating those cost
## an afternoon: children of the waking room silently never linked back to it,
## which stranded it from the pocket, and a stranded room hands the pursuer an
## empty route, which it takes as licence to walk a straight line through the
## walls. A room's name must never be the same string as no room's name.
static func key_of(path: PackedInt32Array) -> String:
	var parts := PackedStringArray()
	for step in path:
		parts.append(str(step))
	return "@" + ".".join(parts)


# ── LOCAL FRAME ───────────────────────────────────────────────────────────
#
# A room's own geometry is always the rect [0, 0, size.x, size.y], with its
# ENTRY DOOR ON THE LOCAL WEST WALL. Fixing the entry to one wall is what
# makes placement a single case instead of sixteen: the room is then rotated
# by whichever quarter turn points its west wall back the way you came.
#
# rot 0..3 maps local (x, z) to world as below, so local west's outward
# normal (-1, 0) becomes west, north, east, south respectively.

const SIDES := ["west", "north", "east", "south"]


static func rotate_local(r: int, x: float, z: float) -> Vector2:
	match r & 3:
		0: return Vector2(x, z)
		1: return Vector2(-z, x)
		2: return Vector2(-x, -z)
		_: return Vector2(z, -x)


## The quarter turn that makes this room's entry face back toward the room it
## was entered from. `from_side` is the side of the PARENT the exit door sat
## on, so the child's entry must face the opposite way.
static func rot_for_entry(from_side: String) -> int:
	match from_side:
		"east": return 0
		"south": return 1
		"west": return 2
		_: return 3


static func side_after_rot(local_side: String, r: int) -> String:
	return SIDES[(SIDES.find(local_side) + r) & 3]


# ── ONE ROOM, DESCRIBED ───────────────────────────────────────────────────

## Everything about one room as pure data: no nodes, JSON-stable, testable
## headless. `entry` is the join this room hangs from, as produced by
## `exit_join()` on the room being left; pass an empty dictionary for the room
## the player wakes in, which hangs from nothing.
func describe(path: PackedInt32Array, entry: Dictionary = {}) -> Dictionary:
	var atlas_room := atlas.room(path)
	var source := str(atlas_room.source)

	# Recover the room's shape before SCALE touched it, so the clamp has an
	# authored quantity to protect. CONFLATION leaves scale at 1.0, so this is
	# exact for both faults rather than only for SCALE.
	var drift := float(atlas_room.scale)
	var unit_size: Vector2 = (atlas_room.size as Vector2) / maxf(drift, 0.0001)

	# REPETITION, MADE OF SPACE RATHER THAN OF A FLAG.
	#
	# The atlas names this fault and cannot express it: it picks a room's
	# source module from the room's own id, so the "near-copy of the corridor
	# you already walked" was drawing an unrelated room out of the catalog and
	# the fault was completely invisible. Only the builder is in a position to
	# fix that, because only the builder knows what the previous room WAS --
	# and it learns it through the door, which is the one thing that crosses
	# between two rooms.
	#
	# So a repeating room is genuinely built from the previous room's module
	# and the previous room's size. What differs is the thing the atlas varies
	# per room and cannot help varying: where the doors are, since those come
	# off this room's own id. That is exactly the brief's "differing in one
	# detail you cannot name" -- the shape is the shape you just walked, and
	# the way out has moved.
	var repeated := false
	if bool(atlas_room.repeats_previous) \
			and not str(entry.get("from_source", "")).is_empty():
		var prior := str(entry.from_source)
		if catalog.get("modules", {}).has(prior):
			source = prior
			# The previous room's own shape, conflation included, not the
			# catalog's idea of what that module measures.
			unit_size = entry.get("from_unit", unit_size) as Vector2
			# Inherit the previous room's drift too. A copy that is a fifth
			# larger reads as a different room, which is the one thing this
			# fault must not do.
			drift = float(entry.get("from_scale", 1.0))
			repeated = true

	var module: Dictionary = catalog.get("modules", {}).get(source, {})

	var want_doors := int(atlas_room.doors)
	var sockets: Array = []
	if not bool(atlas_room.blank):
		# BLANKING has forgotten the room's furniture, and a hazard is
		# furniture. A blank room is a shape with doors in it.
		sockets = module.get("hazard_sockets", [])

	var scale := _clamp_scale(atlas_room, unit_size, want_doors, sockets,
			drift)
	if scale > drift + 0.000001:
		clamped_rooms += 1
	var size := unit_size * scale
	# A ROOM MUST BE ABLE TO HOLD ITS OWN ENTRY DOOR. The smallest catalog
	# footprint is D00 at 1.25 m deep, and 0.80 drift takes that to 1.00 m --
	# under the 1.11 m an aperture needs once it is held off both corners. The
	# room would then be built with no way in at all: not a dead end, which is
	# a legitimate and useful thing for this building to contain, but a sealed
	# volume the player can be standing in. Widen instead. This is a floor on
	# one axis rather than on the scale, so the room still reads as shrunken.
	size.y = maxf(size.y, door_w + CORNER_MARGIN_M * 2.0)

	var rot := 0
	var origin := Vector2.ZERO
	var entry_offset := _entry_offset(int(atlas_room.id), size)
	if not entry.is_empty():
		rot = rot_for_entry(str(entry.side))
		# The child's local (0, entry_offset) is its entry aperture centre on
		# its own clear boundary, and that point must land exactly on the join
		# the parent handed over.
		var jp: Vector2 = entry.point
		origin = jp - rotate_local(rot, 0.0, entry_offset)

	var doors := _door_layout(int(atlas_room.id), size, want_doors,
			entry_offset, rot, origin, not entry.is_empty())

	return {
		"key": key_of(path),
		"path": path,
		"id": int(atlas_room.id),
		"depth": int(atlas_room.depth),
		"source": source,
		"repeated": repeated,
		"conflated_with": str(atlas_room.conflated_with),
		"fault": int(atlas_room.fault),
		"fault_name": DreamAtlas.fault_name(atlas_room.fault),
		"decay": float(atlas_room.decay),
		"blank": bool(atlas_room.blank),
		"recursive": bool(atlas_room.recursive),
		"repeats_previous": bool(atlas_room.repeats_previous),
		"drift": drift,
		"scale": scale,
		"size": size,
		"rot": rot,
		"origin": origin,
		"rect": _world_rect(rot, origin, size),
		"doors": doors,
		"hazards": _place_hazards(sockets, scale, rot, origin, source),
	}


## The world-space axis-aligned clear footprint. A quarter turn swaps the
## extents and moves the origin corner, so this is the AABB of the rotated
## local rect rather than the rect itself.
static func _world_rect(rot: int, origin: Vector2, size: Vector2) -> Array:
	var a := rotate_local(rot, 0.0, 0.0) + origin
	var b := rotate_local(rot, size.x, size.y) + origin
	return [minf(a.x, b.x), minf(a.y, b.y), maxf(a.x, b.x), maxf(a.y, b.y)]


## Where along the west wall this room's entry sits. Deterministic from the
## room id, so the same name always has its door in the same place -- the
## player recognising a room depends on it.
func _entry_offset(id: int, size: Vector2) -> float:
	return _offset_on_wall(size.y, atlas.aspect(id, SALT_ENTRY_OFFSET))


## Keep the aperture wholly inside the wall, off both corners. A wall too
## short to hold a door returns -1.0 and gets none: at 0.80 drift the smallest
## catalog footprint (D00, 1.25 m deep) cannot carry an opening, and a door
## half in a corner is worse than a wall.
func _offset_on_wall(extent: float, t: float) -> float:
	var half := door_w * 0.5 + CORNER_MARGIN_M
	if extent < half * 2.0:
		return -1.0
	return lerpf(half, extent - half, clampf(t, 0.0, 1.0))


## THE DOORS OF ONE ROOM. Index 0 is always the entry, on the local west wall.
## The rest are dealt to the other three walls in an order the room id picks,
## so a four-door room is not always north-east-south.
func _door_layout(id: int, size: Vector2, want: int, entry_offset: float,
		rot: int, origin: Vector2, has_entry: bool) -> Array:
	var out: Array = []
	if entry_offset >= 0.0:
		out.append(_make_door(0, "west", entry_offset, size, rot, origin,
				has_entry))
	var order := _side_order(id)
	var index := 0
	for local_side in order:
		if out.size() >= want:
			break
		var extent: float = size.y if local_side == "east" else size.x
		var t := atlas.aspect(id, SALT_DOOR_OFFSET + index * 7)
		var offset := _offset_on_wall(extent, t)
		index += 1
		if offset < 0.0:
			continue
		out.append(_make_door(out.size(), local_side, offset, size, rot,
				origin, false))
	return out


## A deterministic permutation of the three non-entry walls.
func _side_order(id: int) -> Array:
	var pool := ["north", "east", "south"]
	var out: Array = []
	var salt := SALT_DOOR_SIDE
	while not pool.is_empty():
		var pick := int(atlas.aspect(id, salt) * float(pool.size())) \
				% pool.size()
		out.append(pool[pick])
		pool.remove_at(pick)
		salt += 0x11
	return out


## One door as the rest of the dream expects to read it. The aperture rect,
## the axis and the clear ceiling are the same fields DreamMazeBuilder
## _door_record emits, because every consumer of plan.doors already reads
## exactly those and there is no reason to make them learn a second shape.
func _make_door(index: int, local_side: String, offset: float, size: Vector2,
		rot: int, origin: Vector2, is_entry: bool) -> Dictionary:
	var half := door_w * 0.5
	# The aperture centre on the room's own clear boundary, in local metres.
	var c := Vector2.ZERO
	var outward := Vector2.ZERO
	match local_side:
		"west":
			c = Vector2(0.0, offset)
			outward = Vector2(-1.0, 0.0)
		"east":
			c = Vector2(size.x, offset)
			outward = Vector2(1.0, 0.0)
		"north":
			c = Vector2(offset, 0.0)
			outward = Vector2(0.0, -1.0)
		_:
			c = Vector2(offset, size.y)
			outward = Vector2(0.0, 1.0)
	var world_c := rotate_local(rot, c.x, c.y) + origin
	var world_out := rotate_local(rot, outward.x, outward.y)
	var world_side := side_after_rot(local_side, rot)
	# The aperture spans the shared wall, outward from the clear boundary.
	var far := world_c + world_out * WALL_T
	var along := Vector2(-world_out.y, world_out.x) * half
	var a := world_c + along
	var b := far - along
	var aperture := [minf(a.x, b.x), minf(a.y, b.y),
			maxf(a.x, b.x), maxf(a.y, b.y)]
	# The first place inside this room a body can stand, which is the point
	# the fairness clamp and dream_perception_test both measure from.
	var inside := world_c - world_out * DOOR_INSIDE_M
	return {
		"index": index,
		"local_side": local_side,
		"side": world_side,
		# Consumers of plan.doors read `axis` to know which way to split a
		# wall band; a door on an east/west wall is cut along z.
		"axis": "z" if world_side == "east" or world_side == "west" else "x",
		"aperture": aperture,
		"point": [far.x, far.y],
		"inside": [inside.x, inside.y],
		"width": door_w,
		"height": door_h,
		"clear_ceiling": clear_ceiling,
		"is_entry": is_entry,
		"sealed": false,
		"leads_to": "",
	}


## The join to hand a neighbour: the side of THIS room the door sits on, and
## the world point its far face reaches. The neighbour's entry aperture centre
## lands exactly here, which is what makes the pair share one real wall.
##
## It also carries WHAT THIS ROOM WAS. REPETITION needs it: a room that is a
## near-copy of the one before it can only be built by something that knows
## what the one before it was, and the door is the only thing that crosses
## between them.
static func exit_join(room: Dictionary, door: Dictionary) -> Dictionary:
	var p: Array = door.point
	var scale := float(room.get("scale", 1.0))
	return {
		"side": str(door.side),
		"point": Vector2(p[0], p[1]),
		"from_source": str(room.get("source", "")),
		"from_scale": scale,
		# The previous room's shape BEFORE its own drift, carried rather than
		# looked up again. A conflated room is one module wearing another
		# module's proportions, so its footprint is not its source module's
		# footprint -- and a copy that re-derived the shape from the catalog
		# would silently un-conflate it and come out a different size than the
		# room it is supposed to be repeating.
		"from_unit": (room.get("size", Vector2.ZERO) as Vector2)
				/ maxf(scale, 0.0001),
	}


# ── HAZARDS AND THE FAIRNESS CLAMP ────────────────────────────────────────

## Emit the same record shape DreamMazeBuilder.assemble puts in plan.hazards,
## so DreamHazardField and DreamHazard need no change at all. Positions are
## the module-local socket scaled with the room and carried into world space.
func _place_hazards(sockets: Array, scale: float, rot: int, origin: Vector2,
		source: String) -> Array:
	var out: Array = []
	for socket in sockets:
		var local: Array = socket.get("position_m", [])
		if local.size() < 2:
			continue
		var p := rotate_local(rot, float(local[0]) * scale,
				float(local[1]) * scale) + origin
		out.append({
			"id": str(socket.get("id", "")),
			"kind": str(socket.get("kind", "")),
			"module": source,
			"position": [p.x, p.y],
			# Clearance is a body-sized fact, not a room-sized one: the hole
			# you fall down is the same hole whatever the room remembers its
			# own size to be. Scaling it would change how much floor is
			# missing, which is a different hazard.
			"clearance_radius_m": float(socket.get("clearance_radius_m",
					0.35)),
			"tell_radius_m": float(socket.get("tell_radius_m", 4.60)),
			"minimum_warning_s": float(socket.get("minimum_warning_s", 0.50)),
		})
	return out


## The seconds of warning a straight run from `inside` to the socket yields
## once the tell has fired. This is the same quantity dream_perception_test
## calls a door margin, computed rather than walked.
func _door_margin(inside: Vector2, socket_at: Vector2,
		socket: Dictionary) -> float:
	var d := inside.distance_to(socket_at)
	var tell := float(socket.get("tell_radius_m", 4.60))
	var clear := float(socket.get("clearance_radius_m", 0.35))
	# Beyond the tell radius the player is warned on the way in and gets the
	# full authored approach; inside it the tell fires the moment they cross
	# the sill and the walk is all they get.
	return (minf(d, tell) - clear) / run_speed


## THE CLAMP. Returns the scale this room may actually be built at: the
## atlas's drift, raised only as far as fairness requires. Bisection rather
## than a closed form because door offsets are clamped off the corners and so
## do not scale perfectly linearly with the room -- the honest thing is to
## evaluate the real layout rather than a model of it.
func _clamp_scale(atlas_room: Dictionary, unit_size: Vector2, want: int,
		sockets: Array, drift: float) -> float:
	if sockets.is_empty() or drift >= 1.0:
		return drift
	var live: Array = []
	for socket in sockets:
		if armed.has(str(socket.get("id", ""))):
			live.append(socket)
	if live.is_empty():
		return drift
	# What the authored module gives, and what each hazard is owed. The lesser
	# of the two is the floor this room must not fall below. See the header.
	var floors: Array = []
	for socket in live:
		var authored := _worst_margin(atlas_room, unit_size, want, socket, 1.0)
		floors.append(minf(authored,
				float(socket.get("minimum_warning_s", 0.50))))
	if _satisfies(atlas_room, unit_size, want, live, floors, drift):
		return drift
	# Somewhere between the drift and the authored size there is a least scale
	# that holds. 1.0 always holds: at 1.0 every margin equals its authored
	# value, and the floor is never above that.
	var lo := drift
	var hi := 1.0
	for _i in CLAMP_STEPS:
		var mid := (lo + hi) * 0.5
		if _satisfies(atlas_room, unit_size, want, live, floors, mid):
			hi = mid
		else:
			lo = mid
	return hi


func _satisfies(atlas_room: Dictionary, unit_size: Vector2, want: int,
		live: Array, floors: Array, scale: float) -> bool:
	for i in live.size():
		if _worst_margin(atlas_room, unit_size, want, live[i], scale) \
				< float(floors[i]) - 0.0005:
			return false
	return true


## The least warning this socket gives across every door of the room at this
## scale. Evaluated in the room's LOCAL frame: rotation and origin are rigid
## and move doors and sockets together, so they cannot change a distance.
func _worst_margin(atlas_room: Dictionary, unit_size: Vector2, want: int,
		socket: Dictionary, scale: float) -> float:
	var size := unit_size * scale
	var local: Array = socket.get("position_m", [])
	var at := Vector2(float(local[0]) * scale, float(local[1]) * scale)
	var doors := _door_layout(int(atlas_room.id), size, want,
			_entry_offset(int(atlas_room.id), size), 0, Vector2.ZERO, false)
	var worst := INF
	for door in doors:
		var inside: Array = door.inside
		worst = minf(worst, _door_margin(Vector2(inside[0], inside[1]), at,
				socket))
	return 0.0 if worst == INF else worst


# ── THE POCKET ────────────────────────────────────────────────────────────

## Move the player to `path` and roll the pocket around them: build the room
## and every neighbour it can reach, free everything that is neither on the
## trail nor adjacent. `parent` is the node the geometry hangs under.
func advance(parent: Node3D, path: PackedInt32Array) -> void:
	var here := key_of(path)
	# The trail is the walked path, so a room re-entered moves to the front
	# rather than appearing twice.
	_trail.erase(here)
	_trail.push_back(here)
	while _trail.size() > TRAIL_LEN:
		_trail.pop_front()

	if not _live.has(here):
		# The player is somewhere the pocket does not contain: the first room
		# of a passage, or a jump. There is no join to hang this room from, so
		# it goes at the origin -- which can only be safe if nothing is there.
		# Emptying the pocket first is therefore not a fallback, it is the
		# operation: the building is being remembered afresh around them.
		if not _ensure_room(parent, path, {}):
			_clear()
			# _clear takes the trail with it, which is right -- nothing behind
			# this room is real any more -- but the room the player is
			# standing in is the one thing that must survive it.
			_trail = [here]
			_ensure_room(parent, path, {})
	if not _live.has(here):
		push_error("dream room builder could not place room %s" % here)
		return
	var room: Dictionary = _live[here]

	var keep := {}
	for k in _trail:
		keep[k] = true
	keep[here] = true

	# Build outward through every door this room has. Door 0 is the way back;
	# it only leads anywhere new once the room behind has been forgotten.
	var changed := false
	for door in room.doors:
		var was_sealed := bool(door.sealed)
		if int(door.index) == 0 and (room.path as PackedInt32Array).size() > 0:
			var back := key_of(_parent_path(room.path))
			if _live.has(back):
				# The room behind is still real. Walking back returns you to
				# it, and the pair is already joined -- nothing to build.
				door.leads_to = back
				door.sealed = false
				keep[back] = true
				changed = changed or was_sealed
				continue
		var neighbour := neighbour_path(room, int(door.index))
		var nkey := key_of(neighbour)
		if not _live.has(nkey):
			if not _ensure_room(parent, neighbour, exit_join(room, door), here):
				# No room fits here without eating a live one.
				door.sealed = true
				door.leads_to = ""
				if not was_sealed:
					sealed_doors += 1
					changed = true
				continue
		door.sealed = false
		door.leads_to = nkey
		keep[nkey] = true
		changed = changed or was_sealed

	for k in _live.keys():
		if not keep.has(k):
			_free_room(str(k))
	# The door records were mutated after the geometry was cut, so a door
	# whose state flipped has to have its opening cut or filled back in. Only
	# when it actually flipped: a room is a few dozen bodies and rebuilding it
	# on every threshold crossing for nothing is exactly the kind of cost this
	# frame cannot afford, being submission-bound.
	if changed:
		_rebuild(room)


static func _parent_path(path: PackedInt32Array) -> PackedInt32Array:
	var out := path.duplicate()
	if out.size() > 0:
		out.remove_at(out.size() - 1)
	return out


## Where door `index` of this room leads. Index 0 is the entry: it goes back
## to the room you came from while that room is still real, and otherwise it
## is DreamAtlas.step(path, 0), which is somewhere else. Every other door is
## simply a step deeper.
func neighbour_path(room: Dictionary, index: int) -> PackedInt32Array:
	var path: PackedInt32Array = room.path
	if index == 0 and path.size() > 0:
		var back := _parent_path(path)
		if _live.has(key_of(back)):
			return back
	return DreamAtlas.step(path, index)


## Describe, test against the pocket, and build. Returns false when the room
## cannot exist here without overlapping something already live, which is the
## caller's cue to seal the door instead.
func _ensure_room(parent: Node3D, path: PackedInt32Array,
		entry: Dictionary, from_key: String = "") -> bool:
	var room := describe(path, entry)
	if _overlaps_live(room):
		return false
	# LINK IT BOTH WAYS AT PLACEMENT. Only the room the player is standing in
	# gets its doors resolved by advance(), so without this a neighbour knows
	# nothing about the room that built it and route() cannot get OUT of it.
	# That is not a cosmetic gap: the pursuer takes an empty route as licence
	# to walk a straight line to the player, and a straight line goes through
	# walls. The joint is one shared aperture, so the reciprocal is a fact
	# about the geometry, not a convenience.
	if not from_key.is_empty() and not (room.doors as Array).is_empty():
		room.doors[0].leads_to = from_key
	_live[room.key] = room
	_nodes[room.key] = build(parent, room)
	return true


## THE ONE SPATIAL GUARANTEE LEFT. Not "no two rooms in the building overlap"
## -- there is no building -- but "no two rooms you can currently be in or see
## into overlap". Rooms joined at a door are separated by the shared wall, so
## a true overlap is always a fault.
func _overlaps_live(room: Dictionary) -> bool:
	for k in _live:
		if DreamMazeBuilder._rects_overlap(room.rect, _live[k].rect):
			return true
	return false


## The doors of this room a body can actually walk through. A sealed door is
## wall, and pocket adjacency and pursuit both have to route over this rather
## than over `room.doors`.
static func passable_doors(room: Dictionary) -> Array:
	var out: Array = []
	for door in room.get("doors", []):
		if not bool(door.sealed):
			out.append(door)
	return out


## Forget everything. Not a teardown: this is what the building does when the
## player arrives somewhere it was not holding.
func _clear() -> void:
	for k in _live.keys():
		_free_room(str(k))
	_trail.clear()


func _free_room(key: String) -> void:
	if _nodes.has(key):
		var node: Node3D = _nodes[key]
		if is_instance_valid(node):
			node.queue_free()
		_nodes.erase(key)
	_live.erase(key)


## Rebuild one room's geometry after its doors changed state. Cheap enough to
## do wholesale: a room is a few dozen boxes, and this happens on a threshold
## crossing rather than per frame.
func _rebuild(room: Dictionary) -> void:
	var node: Node3D = _nodes.get(room.key)
	if node == null or not is_instance_valid(node):
		return
	var parent := node.get_parent()
	if parent == null:
		return
	# Out of the tree BEFORE the replacement goes in. queue_free is deferred,
	# so a node still holding the name would push the rebuilt room to
	# "Room_1.2@2" and the harness's node lookups would quietly stop matching.
	parent.remove_child(node)
	node.queue_free()
	_nodes[room.key] = build(parent, room)


## Every room currently real, in no particular order. The replacement for
## plan.modules, and the thing pocket adjacency will route over.
func live_rooms() -> Array:
	return _live.values()


## A standable point just inside this room's entry door -- the doorway the
## player came in through. Falls back to the room centre for the waking room,
## which was entered through nothing. Used by the run-cap fold, which needs a
## real place behind the body rather than an invented one.
func entry_waypoint(key: String) -> Vector3:
	var room: Dictionary = _live.get(key, {})
	if room.is_empty():
		return Vector3.ZERO
	for door in room.doors:
		if int(door.index) == 0 and not bool(door.sealed):
			var inside: Array = door.inside
			return Vector3(inside[0], 0.0, inside[1])
	var r: Array = room.rect
	return Vector3((r[0] + r[2]) * 0.5, 0.0, (r[1] + r[3]) * 0.5)


## The path a live room was reached by. Empty for the waking room, which was
## reached by nothing, and also empty for a room that is not live -- callers
## that need to tell those apart should ask room_at_key first.
func path_of(key: String) -> PackedInt32Array:
	var room: Dictionary = _live.get(key, {})
	return room.path if room.has("path") else PackedInt32Array()


## One live room by its name, or an empty dictionary if the building has
## already forgotten it. The empty return is the interesting one: it is how a
## caller asks "is the way back still there".
func room_at_key(key: String) -> Dictionary:
	return _live.get(key, {})


func room_at(x: float, z: float) -> Dictionary:
	for k in _live:
		var r: Array = _live[k].rect
		if x >= r[0] and x <= r[2] and z >= r[1] and z <= r[3]:
			return _live[k]
	return {}


# ── POCKET ADJACENCY ──────────────────────────────────────────────────────
#
# What replaces DreamMazeBuilder.chain_route. That function was not a graph
# search: it turned plan.modules into an ordered id list, found both endpoints'
# INDICES and walked the integer range between them, so the chain order WAS the
# adjacency relation. A pocket has no order, so the relation has to be carried
# explicitly -- which the doors already do, in `leads_to`.
#
# Three properties this owes the pursuer, and none of them are optional:
#
#  1. IT IS CALLED EVERY PHYSICS FRAME, per body, with no memoisation
#     (dream_pursuer.gd _advance_along_route re-derives the whole route from
#     scratch each step). The pocket is at most a handful of rooms, so a
#     breadth-first walk over it is cheaper than the dictionary lookups the
#     old index arithmetic needed. Nothing here caches, so nothing here can
#     go stale when a room is freed.
#  2. IT MUST BE STABLE FRAME TO FRAME. The same (from, to) must give the
#     same route every time or the body stalls in a doorway oscillating
#     between two equal-length answers. Doors are visited in index order and
#     the first arrival wins, so the walk is a pure function of the pocket.
#  3. EVERY CONSECUTIVE PAIR OF WAYPOINTS MUST LIE INSIDE ONE CONVEX RECT OR
#     ONE APERTURE. The pursuer assigns `position` directly and never calls
#     move_and_slide, so this list is the only thing between it and walking
#     through a wall. Hence the near/centre/far triple per door, unchanged
#     from _door_waypoints: a body deep in a room squares up to the opening
#     before it goes through instead of clipping the jamb beside it.


## Which live room contains this point, by key. The 0.06 m door-strip
## tolerance and the near-side bias are carried over verbatim from
## DreamMazeBuilder.nav_module_at and are not cosmetic: a body standing in an
## aperture belongs to the room it is leaving, and without that a body loses
## its room on every threshold crossing -- exactly when the straight-line
## fallback in the pursuer is most dangerous.
func nav_room_at(x: float, z: float) -> String:
	var strict := room_at(x, z)
	if not strict.is_empty():
		return str(strict.key)
	for k in _live:
		for door in _live[k].doors:
			if bool(door.sealed):
				continue
			var a: Array = door.aperture
			if x >= a[0] - 0.06 and x <= a[2] + 0.06 \
					and z >= a[1] - 0.06 and z <= a[3] + 0.06:
				return str(k)
	return ""


## The three waypoints that carry a body through one door: square up inside
## the near room, cross the aperture, arrive inside the far room.
func _door_waypoints(door: Dictionary) -> Array:
	var inside: Array = door.inside
	var point: Array = door.point
	var near := Vector2(inside[0], inside[1])
	var face := Vector2(point[0], point[1])
	# The door's outward normal, recovered rather than stored: `point` is the
	# far face of the shared wall and `inside` is DOOR_INSIDE_M back from the
	# near face, so the difference is the normal times a known positive
	# length. Deriving it keeps the door record JSON-stable.
	var out := (face - near).normalized()
	var a: Array = door.aperture
	var centre := Vector3((a[0] + a[2]) * 0.5, 0.0, (a[1] + a[3]) * 0.5)
	var far := face + out * DOOR_INSIDE_M
	return [Vector3(near.x, 0.0, near.y), centre, Vector3(far.x, 0.0, far.y)]


## Waypoints from one live room to another, in travel order, NOT including the
## goal itself -- the caller appends that, which is the contract chain_route
## already had with the pursuer. Empty when either end is not live, when they
## are the same room, or when no sequence of open doors connects them.
func route(from_key: String, to_key: String) -> Array:
	if from_key == to_key or not _live.has(from_key) \
			or not _live.has(to_key):
		return []
	# Breadth-first over open doors. First arrival wins and doors are taken in
	# index order, so the answer is the same on every frame and every machine.
	var came_from := {from_key: ""}
	var frontier: Array[String] = [from_key]
	var found := false
	while not frontier.is_empty() and not found:
		var next: Array[String] = []
		for key in frontier:
			for door in _live[key].doors:
				if bool(door.sealed):
					continue
				var to := str(door.leads_to)
				if to.is_empty() or came_from.has(to) or not _live.has(to):
					continue
				came_from[to] = key
				if to == to_key:
					found = true
					break
				next.append(to)
			if found:
				break
		frontier = next
	if not found:
		return []
	# Unwind, then walk it forwards emitting the door each hop goes through.
	var chain: Array[String] = [to_key]
	var cursor := to_key
	while str(came_from[cursor]) != "":
		cursor = str(came_from[cursor])
		chain.push_front(cursor)
	var waypoints: Array = []
	for i in range(chain.size() - 1):
		var door := _door_between(chain[i], chain[i + 1])
		if door.is_empty():
			return []
		waypoints.append_array(_door_waypoints(door))
	return waypoints


## The open door of `a` that leads to `b`, as `a` sees it. Direction matters:
## the near/far waypoints are built from the door record's own room, so taking
## `b`'s copy of the same joint would walk the body backwards through it.
func _door_between(a: String, b: String) -> Dictionary:
	if not _live.has(a):
		return {}
	for door in _live[a].doors:
		if not bool(door.sealed) and str(door.leads_to) == b:
			return door
	return {}


## WHERE THE THING THAT HUNTS YOU BEGINS. The chain builder put it at the far
## end of the terminal module; a building that never closes has no terminal
## module, and _far_spawn cannot be ported.
##
## What the pursuer actually requires of a spawn is not terminality (see
## dream_pursuer.gd: it heads for the player from the first physics frame, and
## there is no patrol phase to hide a bad choice behind). It requires a point
## that resolves to a live room, is well clear of the capture radius, and is
## far enough away by ROUTE -- not by line of sight -- that the lit/dark speed
## difference still decides the passage.
##
## So it starts BEHIND: the oldest room still on the trail, which is the room
## the player has most recently finished with. That is reproducible, always
## exists, and is the reading the fiction wants -- the thing that follows you
## comes from where you have already been, not from where you are going.
## Spawning it ahead would be _cap_fold's endgame applied at t=0, which
## collapses the run ceiling and destroys the lamp decision.
func pursuer_spawn(player_key: String) -> Array:
	var pick := ""
	for k in _trail:
		if str(k) != player_key and _live.has(k):
			pick = str(k)
			break
	if pick.is_empty():
		# First room of the passage: nothing is behind yet. Take a branch the
		# player has not walked instead, preferring the last door -- the one
		# they are least likely to have been looking through.
		var here: Dictionary = _live.get(player_key, {})
		for door in passable_doors(here):
			if int(door.index) != 0 and _live.has(str(door.leads_to)):
				pick = str(door.leads_to)
	if pick.is_empty() or not _live.has(pick):
		return []
	var r: Array = _live[pick].rect
	return [(r[0] + r[2]) * 0.5, (r[1] + r[3]) * 0.5]


# ── THE POCKET AS A PLAN ──────────────────────────────────────────────────

## Write the live pocket into `plan` IN PLACE, in the shape DreamMazeRoot and
## everything downstream of it already reads.
##
## In place, and that is not a style choice. DreamPursuer takes `plan` by
## reference once at setup and DreamMazeRoot assigns it exactly once; nothing
## ever re-hands it over. Building a fresh dictionary each time the pocket
## rolled would leave the pursuer routing against the first one forever, and
## it would keep working -- against a building that no longer exists.
##
## Field by field, this is the closed set the chain builder emitted:
##   modules      the live rooms, `id` now a path key rather than a module id.
##                Unique among live rooms, which module ids no longer are.
##   doors        open doors only. A sealed door is wall and must not appear,
##                or routing will try to walk through it.
##   hazards      every armed socket of every live room, `id` made unique per
##                room and `socket` carrying the catalog name.
##   spawn_player where the atlas says this campaign wakes.
##   spawn_pursuer  behind the player, on the trail. See pursuer_spawn().
##   defects      MUST be present and empty. DreamMazeRoot treats a missing
##                key as ["unbuilt"] and bails before building anything.
##   mirrored/edges/slot/seed_hex  emitted by the chain builder and read by
##                nothing; not carried forward.
func write_plan(plan: Dictionary, player_key: String) -> void:
	var modules: Array = []
	var doors: Array = []
	var hazards: Array = []
	for key in _live:
		var room: Dictionary = _live[key]
		modules.append({"id": str(key), "rect": room.rect})
		for door in room.doors:
			if bool(door.sealed) or str(door.leads_to).is_empty():
				continue
			doors.append({
				"from": str(key),
				"to": str(door.leads_to),
				"axis": str(door.axis),
				"aperture": door.aperture,
				"width": float(door.width),
				"height": float(door.height),
				"clear_ceiling": float(door.clear_ceiling),
			})
		for record in room.hazards:
			var socket := str(record.id)
			if not armed.has(socket):
				continue
			var copy: Dictionary = record.duplicate(true)
			copy["socket"] = socket
			copy["id"] = "%s%s" % [socket, str(key)]
			copy["module"] = str(key)
			hazards.append(copy)
	plan["modules"] = modules
	plan["doors"] = doors
	plan["hazards"] = hazards
	plan["defects"] = []
	var here: Dictionary = _live.get(player_key, {})
	if not here.is_empty():
		var r: Array = here.rect
		plan["spawn_player"] = [(r[0] + r[2]) * 0.5, (r[1] + r[3]) * 0.5]
	var far := pursuer_spawn(player_key)
	if not far.is_empty():
		plan["spawn_pursuer"] = far
	elif not plan.has("spawn_pursuer"):
		plan["spawn_pursuer"] = plan.get("spawn_player", [0.0, 0.0])


# ── GEOMETRY ──────────────────────────────────────────────────────────────

## One room's architecture. Floor, ceiling, four wall bands with the doors cut
## out of them, and any shaft its armed sockets require. Every primitive here
## comes from DreamMazeBuilder: _solid_box, _subtract_rect, _build_shafts and
## the Klimt materials were already room-local or per-joint, which is why the
## chain builder's assembly could be retired without taking them with it.
func build(parent: Node3D, room: Dictionary) -> Node3D:
	var node := Node3D.new()
	node.name = "Room_%s" % (str(room.key) if str(room.key) != "" else "root")
	parent.add_child(node)

	var wall_mat := DreamMazeBuilder._material(Color("272a31"), 0.94,
			DreamMazeBuilder.MOTIF_SPIRAL)
	var floor_mat := DreamMazeBuilder._material(Color("343139"), 0.90,
			DreamMazeBuilder.MOTIF_MOSAIC)
	var ceiling_mat := DreamMazeBuilder._material(Color("2b2b31"), 0.92,
			DreamMazeBuilder.MOTIF_CANOPY)
	var door_mat := DreamMazeBuilder._material(Color("2a2730"), 0.86,
			DreamMazeBuilder.MOTIF_TRIANGLE)
	var shaft_mat := DreamMazeBuilder._material(Color("1d1a20"), 0.90,
			DreamMazeBuilder.MOTIF_EYE)

	var r: Array = room.rect
	# The slab runs under the walls so a joint has no gap to see through.
	var slab := [r[0] - WALL_T, r[1] - WALL_T, r[2] + WALL_T, r[3] + WALL_T]
	var holes := _room_holes(room)
	var slabs: Array = [slab]
	for hole in holes:
		slabs = DreamMazeBuilder._subtract_rect(slabs, hole)
	var i := 0
	for piece in slabs:
		i += 1
		DreamMazeBuilder._solid_box(node, "Floor%02d" % i, floor_mat, piece,
				-WALL_T, 0.0)
	DreamMazeBuilder._build_shafts(node, holes, shaft_mat)
	DreamMazeBuilder._solid_box(node, "Ceiling", ceiling_mat, slab,
			clear_ceiling, clear_ceiling + WALL_T)

	# West and east bands own the corners; north and south stay between them.
	# Same convention as the chain builder, so a joint between a room built
	# here and one built there meets flush.
	var boxes: Array = [
		[r[0] - WALL_T, r[1] - WALL_T, r[0], r[3] + WALL_T],
		[r[2], r[1] - WALL_T, r[2] + WALL_T, r[3] + WALL_T],
		[r[0], r[1] - WALL_T, r[2], r[1]],
		[r[0], r[3], r[2], r[3] + WALL_T],
	]
	var lintels: Array = []
	for door in room.doors:
		if bool(door.sealed):
			# A sealed door is wall. Not a locked door with a handle: the
			# opening was never remembered, so there is nothing there.
			continue
		var aperture: Array = door.aperture
		var split: Array = []
		for box in boxes:
			if not DreamMazeBuilder._rects_overlap(box, aperture):
				split.append(box)
				continue
			if str(door.axis) == "z":
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
		lintels.append(aperture)

	i = 0
	for box in boxes:
		i += 1
		DreamMazeBuilder._solid_box(node, "Wall%02d" % i, wall_mat, box,
				0.0, clear_ceiling)
	# BLANKING, MADE OF SPACE. "Doors without frames" is the brief's own
	# phrase, and in this builder a door's frame IS the lintel -- the box that
	# fills the wall from the 2.13 m head up to the ceiling. A blanked room
	# simply does not get one, so its openings run floor to ceiling: a gap in
	# a wall rather than a doorway, which reads as a room that has forgotten
	# what a door looks like and kept only the hole. It is also the only fault
	# that makes a room CHEAPER, which is right -- nothing was added, something
	# stopped being there.
	if not bool(room.get("blank", false)):
		i = 0
		for aperture in lintels:
			i += 1
			DreamMazeBuilder._solid_box(node, "Lintel%02d" % i, door_mat,
					aperture, door_h, clear_ceiling)
	return node


## Same derivation as DreamMazeBuilder.floor_holes and for the same reason:
## only a socket whose kind is exactly `positional` is a hazard whose danger
## IS its place, and only an armed one gets a real hole cut for it.
func _room_holes(room: Dictionary) -> Array:
	var holes: Array = []
	for record in room.hazards:
		if str(record.get("kind", "")) != "positional":
			continue
		if not armed.has(str(record.get("id", ""))):
			continue
		var p: Array = record.position
		var half := float(record.clearance_radius_m)
		holes.append([float(p[0]) - half, float(p[1]) - half,
				float(p[0]) + half, float(p[1]) + half])
	return holes
