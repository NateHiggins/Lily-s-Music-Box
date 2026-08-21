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
const DreamLineageBodyScript := preload(
		"res://scripts/dream/dream_lineage_body.gd")
const DreamOrisonFurnisherScript := preload(
		"res://scripts/dream/dream_orison_furnisher.gd")
const DreamOrisonInteriorScript := preload(
		"res://scripts/dream/dream_orison_interior.gd")

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
## R6 does not let the renderer invent whatever view happens to look good.
## These salts let the topology owner select one already-live room and one of
## its real approaches. They do not alter room identity, placement or doors.
const SALT_VIEW_FAULT_VANTAGE := 0x71E7A63E
const SALT_VIEW_FAULT_ROLL := 0x71E79011
## Juno's feedback chooses among already-real joints. Golden once shipped.
const SALT_CHANNEL_PARTITION := 0xC4A66E1

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
## Case grammar is data, not a subclass. Mina supplies an empty dictionary;
## Peter supplies one junction-reversal rule. The builder remains the sole
## owner of rooms and doors either way.
var profile_grammar: Dictionary = {}
## A physics frame can ask about the same threshold more than once while the
## capsule straddles it. One crossing earns one consequence.
var _last_profile_transition := ""
var _profile_partitions: Array[Dictionary] = []

## THE ROOM YOU OPEN YOUR EYES IN DOES NOT ARM.
##
## Every other room's fairness rests on the APPROACH. A hazard's tell is not
## occluded, so it crosses the wall and starts sounding while the player is
## still in the previous room, walking toward the door -- that approach is
## where the owed seconds are actually spent, and it is why six of the eight
## authored sockets survive Gate C despite being short at their own doorway.
##
## The waking room has no approach. The player is not walking in; they are
## simply there, with the whole of their warning already behind them. Moving
## the spawn cannot fix it either: the room the seed picked for this campaign
## may be D05, 2.08 m deep with the signal trunk at its centre, where no point
## at all clears the 4.49 m that socket owes.
##
## So it does not arm, and the geometry agrees -- no mouth is cut for a void
## that cannot fire. One quiet room in an infinite building, and the player
## gets a moment before the dream starts hunting them.
var waking_key := ""

## WHERE THE GOLD IS KEPT. Optional: every headless suite in this subsystem
## builds rooms without one and must keep working, so every touch of it is
## guarded.
##
## When it IS set, the pocket owns its lifecycle -- a room stamps its baseline
## on entry and zeroes on exit -- and that is not bookkeeping, it is what
## makes DreamExposureField's tiling sound. See that file: the field wraps
## every 48 m and is only safe because "rooms are stamped when built and
## zeroed when freed, so a region wrapping back into use was cleared by
## whoever left it." The pocket is the only thing that knows when that
## happens, so the pocket is where it has to be done.
##
## It is also the brief's own ruling made literal (workstream A): "Rooms
## leaving the pocket may lose it. That is correct and thematically right: the
## building forgets what you did to it once it forgets the room."
var exposure: DreamExposureField

## key -> room record. The pocket. Never the building.
var _live: Dictionary = {}
## key -> Node3D of built geometry, parallel to _live.
var _nodes: Dictionary = {}
## The walked path, most recent last, at most TRAIL_LEN entries.
var _trail: Array[String] = []
## Diagnostics for the harness and the tests; never read by gameplay.
var sealed_doors := 0
var clamped_rooms := 0


func setup(dream_atlas: DreamAtlas, hazard_allowlist: Array = [],
		case_grammar: Dictionary = {}) -> void:
	atlas = dream_atlas
	catalog = DreamMazeBuilder.load_catalog()
	armed = hazard_allowlist
	profile_grammar = case_grammar.duplicate(true)
	_last_profile_transition = ""
	_profile_partitions.clear()
	var constants: Dictionary = catalog.get("constants", {})
	clear_ceiling = float(constants.get("clear_ceiling_m", 3.015))
	run_speed = float(constants.get("player_run_speed_mps", 4.6))
	door_w = float(constants.get("connector_width_m", 0.91))
	door_h = float(constants.get("connector_height_m", 2.13))


## One data-authored reaction to crossing a threshold. The caller reports only
## the two real rooms involved; this owner decides whether that movement has a
## spatial consequence and performs it without inventing a parallel graph.
##
## Peter's `duplicate_pending_corridor` rule fires when the body reverses out
## of a junction into its parent. The room just re-entered is rebuilt from the
## exact same source, scale, origin and footprint, but its deterministic door
## deal is allowed one additional opening. To the player it is the corridor
## they just walked, returned with another demand. Identity, route and hazard
## records remain ordinary pocket data; save code stores none of this chase
## frame, exactly like every other room currently held in short-term memory.
func apply_profile_transition(parent: Node3D, from_key: String,
		to_key: String) -> Dictionary:
	var convergence := _apply_convergence_return(parent, from_key, to_key)
	if not convergence.is_empty():
		return convergence
	var event_name := str(profile_grammar.get("junction_reverse_event", ""))
	if event_name.is_empty() or from_key.is_empty() or to_key.is_empty():
		_last_profile_transition = ""
		return {}
	var from_room: Dictionary = _live.get(from_key, {})
	var to_room: Dictionary = _live.get(to_key, {})
	if from_room.is_empty() or to_room.is_empty():
		_last_profile_transition = ""
		return {}
	var from_path: PackedInt32Array = from_room.path
	var is_reverse := from_path.size() > 0 \
			and key_of(_parent_path(from_path)) == to_key
	var is_junction := passable_doors(from_room).size() >= int(
			profile_grammar.get("junction_min_doors", 3))
	if not is_reverse or not is_junction:
		_last_profile_transition = ""
		return {}
	var token := "%s>%s" % [from_key, to_key]
	if token == _last_profile_transition:
		return {}
	_last_profile_transition = token

	var old_doors: Array = to_room.doors
	var before := old_doors.size()
	var want := mini(DreamAtlas.MAX_DOORS, before + int(
			profile_grammar.get("doors_added", 1)))
	var entry_offset := _entry_offset(int(to_room.id), to_room.size)
	var replacement := _door_layout(int(to_room.id), to_room.size, want,
			entry_offset, int(to_room.rot), to_room.origin,
			(to_room.path as PackedInt32Array).size() > 0)
	# The old openings keep their exact graph facts. Only the newly dealt door
	# begins unresolved; advance(), called immediately after this event, either
	# builds its real neighbour or seals it under the normal overlap rule.
	for i in mini(old_doors.size(), replacement.size()):
		replacement[i].leads_to = old_doors[i].leads_to
		replacement[i].sealed = old_doors[i].sealed
	to_room.doors = replacement
	to_room["profile_duplicate"] = true
	to_room["profile_event"] = event_name
	to_room["form_stamps"] = int(to_room.get("form_stamps", 0)) + 1
	to_room["duplicated_from"] = from_key
	to_room["profile_stamp_door_index"] = before if replacement.size() > before \
			else maxi(0, replacement.size() - 1)
	_live[to_key] = to_room
	_rebuild(to_room)
	return {
		"event": event_name,
		"from": from_key,
		"to": to_key,
		"source": str(to_room.source),
		"doors_before": before,
		"doors_after": replacement.size(),
		"form_stamps": int(to_room.form_stamps),
	}


## Two ordinary reciprocal branches may return to one remembered junction.
## The room and antique remain one identity; only the approached provenance
## accumulates. The first account informs pursuit, later contradiction does not.
func _apply_convergence_return(_parent: Node3D, from_key: String,
		to_key: String) -> Dictionary:
	var event_name := str(profile_grammar.get("convergence_return_event", ""))
	if event_name.is_empty() or from_key.is_empty() or to_key.is_empty():
		return {}
	var from_room: Dictionary = _live.get(from_key, {})
	var target: Dictionary = _live.get(to_key, {})
	if from_room.is_empty() or target.is_empty():
		return {}
	var from_path: PackedInt32Array = from_room.path
	if from_path.size() == 0 or key_of(_parent_path(from_path)) != to_key \
			or passable_doors(target).size() < int(
					profile_grammar.get("convergence_min_doors", 3)):
		return {}
	var approached_door := -1
	for door in target.doors:
		if str(door.get("leads_to", "")) == from_key:
			approached_door = int(door.get("index", -1))
			break
	if approached_door < 0:
		return {}
	var returns: Dictionary = target.get("convergence_returns", {})
	if returns.has(str(approached_door)):
		return {}
	var provenances: Array = profile_grammar.get("provenances", [])
	if provenances.size() < 2:
		return {}
	returns[str(approached_door)] = str(provenances[returns.size() % 2])
	target["convergence_returns"] = returns
	target["contradictory_antique"] = true
	target["contradiction_complete"] = returns.size() >= 2
	target["contradictory_object_id"] = "antique_%s" % to_key
	_live[to_key] = target
	_rebuild(target)
	return {"event": event_name if returns.size() == 1 else "",
			"room": to_key, "door_index": approached_door,
			"provenance": str(returns[str(approached_door)]),
			"accounts": returns.size(),
			"object_id": str(target.contradictory_object_id)}


## Turn one live aperture into load-bearing feedback. Both reciprocal records
## change together because the joint, not either room's drawing, is the fact.
func congeal_channel_partition(_parent: Node3D, player_key: String,
		player_position: Vector3, pursuer_key: String, ordinal: int) -> Dictionary:
	var event_name := str(profile_grammar.get("channel_echo_event", ""))
	var maximum := int(profile_grammar.get("max_partitions", 0))
	if event_name.is_empty() or maximum <= 0 \
			or _profile_partitions.size() >= maximum:
		return {}
	var candidates: Array[Dictionary] = []
	var keys: Array = _live.keys()
	keys.sort()
	for key_value in keys:
		var key := str(key_value)
		var room: Dictionary = _live[key]
		for door in room.doors:
			if bool(door.get("sealed", false)) or bool(door.get("partitioned", false)):
				continue
			var other_key := str(door.get("leads_to", ""))
			if other_key.is_empty() or not _live.has(other_key) or key > other_key:
				continue
			if key == player_key and int(door.get("index", -1)) == 0:
				continue
			var reciprocal := _door_to_any(other_key, key)
			if reciprocal.is_empty() or bool(reciprocal.get("sealed", false)):
				continue
			var aperture: Array = door.get("aperture", [])
			if aperture.size() >= 4:
				var centre := Vector2((float(aperture[0]) + float(aperture[2])) * 0.5,
						(float(aperture[1]) + float(aperture[3])) * 0.5)
				if Vector2(player_position.x, player_position.z).distance_to(centre) < 1.0:
					continue
			if key == player_key and passable_doors(room).size() <= 1:
				continue
			if other_key == player_key and passable_doors(_live[other_key]).size() <= 1:
				continue
			door.sealed = true
			reciprocal.sealed = true
			var route_safe := pursuer_key == player_key \
					or not route(pursuer_key, player_key).is_empty()
			door.sealed = false
			reciprocal.sealed = false
			if not route_safe:
				continue
			candidates.append({"key": key, "other": other_key, "door": door,
					"reciprocal": reciprocal, "score": atlas.aspect(int(room.id),
					SALT_CHANNEL_PARTITION + ordinal * 0x101)})
	if candidates.is_empty():
		return {}
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.score) < float(b.score))
	var chosen: Dictionary = candidates[0]
	for record in [chosen.door, chosen.reciprocal]:
		record["sealed"] = true
		record["partitioned"] = true
		record["partition_ordinal"] = ordinal
	_profile_partitions.append({"key": str(chosen.key),
			"other": str(chosen.other), "ordinal": ordinal})
	_rebuild(_live[str(chosen.key)])
	_rebuild(_live[str(chosen.other)])
	return {"event": event_name, "from": str(chosen.key),
			"to": str(chosen.other), "ordinal": ordinal}


func release_oldest_channel_partition() -> Dictionary:
	_prune_profile_partitions()
	if _profile_partitions.is_empty():
		return {}
	var entry: Dictionary = _profile_partitions.pop_front()
	var key := str(entry.key)
	var other := str(entry.other)
	if not _live.has(key) or not _live.has(other):
		return {}
	var first := _door_to_any(key, other)
	var second := _door_to_any(other, key)
	if first.is_empty() or second.is_empty() \
			or not bool(first.get("partitioned", false)) \
			or not bool(second.get("partitioned", false)):
		return {}
	for record in [first, second]:
		record["sealed"] = false
		record["partitioned"] = false
		record.erase("partition_ordinal")
	_rebuild(_live[key])
	_rebuild(_live[other])
	return {"from": key, "to": other, "ordinal": int(entry.ordinal)}


func channel_partition_count() -> int:
	_prune_profile_partitions()
	return _profile_partitions.size()


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
		"lineage": atlas_room.lineage,
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
		if bool(door.get("partitioned", false)):
			# The wall remembers both faces while it is load-bearing. Keeping the
			# reciprocal room live does not make the joint passable; it prevents
			# advance() from erasing the very wall the player must outlast.
			var held := str(door.get("leads_to", ""))
			if not held.is_empty() and _live.has(held):
				keep[held] = true
			continue
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
	_stamp_exposure(room)
	_nodes[room.key] = build(parent, room)
	return true


## Lay this room's exposure baseline the moment it becomes real.
##
## Both terms come straight off the record the atlas already produced. `decay`
## is "how far gone this room is" -- nights compounded and distance from where
## you woke -- which is the brief's ask that the surface evolve "as time in the
## maze continues AND light is cast"; the lamp supplies the second term later.
##
## The seed is aspect(id, salt), the same call every other per-room property in
## this subsystem comes through, so the blotching is a pure read of the room's
## identity rather than a rolled value. Two rooms at one decay therefore grow
## differently, and the same room grows identically on every replay of a save.
func _stamp_exposure(room: Dictionary) -> void:
	if exposure == null or atlas == null:
		return
	exposure.stamp_room(str(room.key), room.rect, float(room.decay),
			atlas.aspect(int(room.id), DreamExposureField.SALT_EXPOSURE))


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
	# The gold goes with the room. Not a cleanup step -- it is the mechanic:
	# the building forgets what you did to it once it forgets the room.
	if exposure != null:
		exposure.clear_room(key)
	if _nodes.has(key):
		var node: Node3D = _nodes[key]
		if is_instance_valid(node):
			node.queue_free()
		_nodes.erase(key)
	_live.erase(key)
	_prune_profile_partitions()


func _prune_profile_partitions() -> void:
	var kept: Array[Dictionary] = []
	for entry in _profile_partitions:
		if _live.has(str(entry.key)) and _live.has(str(entry.other)):
			kept.append(entry)
	_profile_partitions = kept


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


## ONE WINDOW INTO SOMETHING THE POCKET ALREADY REMEMBERS.
##
## The renderer may consume this record but may not choose its own destination.
## Candidates are the rooms already held by the bounded pocket, so the result
## cannot create topology, keep a forgotten room alive or name an unbuilt
## space. The destination is deliberately not linked to the source: this is a
## view fault, not a graph edge. Its odd quarter-turn belongs to the image only;
## the player, gravity, collision and navigation remain in the source room.
func view_fault(source_key: String) -> Dictionary:
	var source: Dictionary = _live.get(source_key, {})
	if source.is_empty() or atlas == null:
		return {}
	var candidates: Array[String] = []
	# The first real door is already the receding practical's authored lure.
	# Looking through the wound therefore shows a place the player can know is
	# real, while the odd orientation says the VIEW is the violation. This list
	# follows the source's door order; no renderer-facing aesthetic score may
	# choose a more convenient room.
	for door_value in source.get("doors", []):
		var door: Dictionary = door_value
		var key := str(door.get("leads_to", ""))
		if not bool(door.get("sealed", false)) and not key.is_empty() \
				and key != source_key and _live.has(key) \
				and not candidates.has(key):
			candidates.append(key)
	# A source can be a surviving trail room whose own door record was sealed
	# before its neighbour was retained. The fault still cannot invent space:
	# the deterministic fallback is another room already held by the pocket.
	if candidates.is_empty():
		for key_value in _live.keys():
			var key := str(key_value)
			if key != source_key:
				candidates.append(key)
		candidates.sort()
	if candidates.is_empty():
		return {}
	var destination_key := candidates[0]
	var destination: Dictionary = _live[destination_key]
	var rect: Array = destination.get("rect", [])
	if rect.size() < 4:
		return {}
	var target := Vector3((float(rect[0]) + float(rect[2])) * 0.5, 1.38,
			(float(rect[1]) + float(rect[3])) * 0.5)
	var vantage := target
	var open_doors := passable_doors(destination)
	if not open_doors.is_empty():
		var vantage_pick := int(atlas.aspect(int(destination.id),
				SALT_VIEW_FAULT_VANTAGE) * float(open_doors.size()))
		vantage_pick = clampi(vantage_pick, 0, open_doors.size() - 1)
		var inside: Array = (open_doors[vantage_pick] as Dictionary).get(
				"inside", [])
		if inside.size() >= 2:
			vantage = Vector3(float(inside[0]), 1.38, float(inside[1]))
	if vantage.distance_to(target) < 0.35:
		# The waking room can have no meaningful entry. Use a real point inside
		# its footprint rather than manufacturing a doorway for the camera.
		vantage = Vector3(lerpf(float(rect[0]), float(rect[2]), 0.22), 1.38,
				lerpf(float(rect[1]), float(rect[3]), 0.22))
	else:
		# Clear the doorway's wall thickness and casing before taking the view.
		# The camera is still inside the same authored room; this merely stops a
		# 56-degree portrait lens from spending most of its frame on the jamb.
		vantage = vantage.move_toward(target,
				minf(1.20, vantage.distance_to(target) * 0.22))
	var forward := target - vantage
	forward.y = 0.0
	if forward.length() < 0.01:
		forward = Vector3.FORWARD
	else:
		forward = forward.normalized()
	var roll_pick := atlas.aspect(int(source.id), SALT_VIEW_FAULT_ROLL)
	var quarter_turns := 1 if roll_pick < 0.5 else 3
	return {
		"id": "view/%s/%s" % [source_key, destination_key],
		"owner": "DreamAtlas/DreamRoomBuilder",
		"source_key": source_key,
		"source_path": (source.path as PackedInt32Array).duplicate(),
		"source_room_id": int(source.id),
		"destination_key": destination_key,
		"destination_path": (destination.path as PackedInt32Array).duplicate(),
		"destination_room_id": int(destination.id),
		"destination_source": str(destination.source),
		"destination_origin": vantage,
		"destination_forward": forward,
		"orientation_quarters": quarter_turns,
		"recursion_depth": 0,
		"render_source": "shared_world_existing_room",
		"navigation": "none_authoritative_wall_intact",
	}


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


func _door_to_any(a: String, b: String) -> Dictionary:
	if not _live.has(a):
		return {}
	for door in _live[a].doors:
		if str(door.get("leads_to", "")) == b:
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
## AND SHE MUST START FAR. The chain put the Tenant five modules away, at the far
## end of the terminal room. The first version of this put it at the CENTRE of
## the nearest room behind, which on the opening frame of a passage is a single
## doorway from a player who has not moved yet -- and it caught them before the
## lamp decision could express itself at all. Two of Gate-adjacent pursuit's
## measurements (light-on shortening capture by a third, extinguishing buying
## audible time) simply cannot be measured if the passage is over first.
##
## The pocket cannot offer five rooms, but it does not have to: rooms here run
## up to 19.3 m, so the FAR CORNER of the furthest live room is a comparable
## distance to what the chain gave. So candidates are ranked by how far their
## furthest standable point is from the player, and the trail is preferred
## only among equals -- being behind matters, but not more than being far
## enough away that the passage is decided by the chase.
func pursuer_spawn(player_key: String) -> Array:
	var here: Dictionary = _live.get(player_key, {})
	if here.is_empty():
		return []
	var hr: Array = here.rect
	var from := Vector2((hr[0] + hr[2]) * 0.5, (hr[1] + hr[3]) * 0.5)
	var best: Array = []
	var best_score := -1.0
	for k in _live:
		if str(k) == player_key:
			continue
		var r: Array = _live[k].rect
		# The corner of this room furthest from the player, pulled inside by
		# more than the body radius so the spawn is standable rather than in
		# a wall.
		var inset := 0.6
		var x0: float = float(r[0]) + inset
		var x1: float = float(r[2]) - inset
		var z0: float = float(r[1]) + inset
		var z1: float = float(r[3]) - inset
		if x1 <= x0 or z1 <= z0:
			continue
		var px: float = x0 if absf(x0 - from.x) > absf(x1 - from.x) else x1
		var pz: float = z0 if absf(z0 - from.y) > absf(z1 - from.y) else z1
		var score := Vector2(px, pz).distance_to(from)
		# Behind beats ahead at equal distance: the thing that follows you
		# comes from where you have already been.
		if _trail.has(str(k)):
			score += 0.5
		if score > best_score:
			best_score = score
			best = [px, pz]
	return best


# ── THE POCKET AS A PLAN ──────────────────────────────────────────────────

## WHERE IN THE WAKING ROOM IT IS SAFE TO OPEN YOUR EYES.
##
## The chain never had to ask: the passage always began at D00, and D00 carries
## no hazard sockets. The fractal wakes the player in whatever room the seed
## picked, and that room may hold the lift void or the signal trunk -- so the
## room centre, which is what the chain used, can be inside a hazard's
## clearance radius. The player then falls or is burned in the first frame of
## the dream, having been given no warning at all and no chance to act. It is
## the least fair thing this world could possibly do, and it is invisible until
## the seed happens to pick such a room.
##
## The waking room owes the player exactly what every other room owes them:
## clearance plus the seconds of warning the socket promises, at running speed.
## That is the same owed radius the fairness clamp protects, so the two agree
## by construction rather than by coincidence.
##
## Sampled on a fixed grid rather than solved, because the answer only has to
## be good and deterministic, and a grid is both. If nothing clears the owed
## radius the furthest point still wins -- a bad waking spot in a cramped room
## is survivable, and refusing to place the player at all is not.
func safe_spawn(room: Dictionary) -> Array:
	var r: Array = room.rect
	var live: Array = []
	if str(room.get("key", "")) != waking_key:
		# The waking room does not arm at all, so there is nothing here to
		# stand clear of. Asking anyway would warn about a hazard that will
		# never fire.
		for record in room.hazards:
			if armed.has(str(record.id)):
				live.append(record)
	var centre := [(r[0] + r[2]) * 0.5, (r[1] + r[3]) * 0.5]
	if live.is_empty():
		return centre
	# Keep the body off the walls by more than its own radius.
	var inset := 0.6
	var x0: float = float(r[0]) + inset
	var x1: float = float(r[2]) - inset
	var z0: float = float(r[1]) + inset
	var z1: float = float(r[3]) - inset
	if x1 <= x0 or z1 <= z0:
		return centre
	var best := centre
	var best_clear := -1.0
	for ix in 7:
		for iz in 7:
			var p := Vector2(lerpf(x0, x1, float(ix) / 6.0),
					lerpf(z0, z1, float(iz) / 6.0))
			var clear := INF
			for record in live:
				var h: Array = record.position
				var owed := float(record.clearance_radius_m) \
						+ run_speed * float(record.minimum_warning_s)
				# Measured as a shortfall against what THIS socket owes, so a
				# generous hazard and a tight one are compared fairly rather
				# than by raw metres.
				clear = minf(clear, p.distance_to(Vector2(h[0], h[1])) - owed)
			if clear > best_clear:
				best_clear = clear
				best = [p.x, p.y]
	if best_clear < 0.0:
		push_warning(("dream: waking room %s cannot give full owed warning "
				+ "from any spawn point (short by %.2f m)")
				% [str(room.key), -best_clear])
	return best


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
			# DORMANT SOCKETS TRAVEL TOO. Owner ruling 2026-08-18. A socket
			# this case did not allow has no tuning, so it has no outcome, no
			# caption and no trigger condition -- it is inert by construction
			# rather than by suppression, and DreamHazardField filters it out
			# so no DreamHazard is ever made for it and _room_holes never cuts
			# for it. What carrying it buys is that the building keeps the
			# whole of its danger vocabulary: the live hazards are THIS
			# haunting's signature, and the dormant ones are other hauntings
			# showing through the walls of the same Orison.
			var live := armed.has(socket) and str(key) != waking_key
			var copy: Dictionary = record.duplicate(true)
			copy["socket"] = socket
			copy["id"] = "%s%s" % [socket, str(key)]
			copy["module"] = str(key)
			copy["armed"] = live
			hazards.append(copy)
	plan["modules"] = modules
	plan["doors"] = doors
	plan["hazards"] = hazards
	plan["defects"] = []
	var here: Dictionary = _live.get(player_key, {})
	if not here.is_empty():
		# THE HAZARD-CLEARANCE SEARCH IS FOR THE WAKING ROOM ONLY. Every other
		# room is entered through a door, with the approach the tell needs, so
		# there is nothing to stand clear of -- running safe_spawn on them
		# warned that a room could not pay a warning nobody was owed.
		#
		# It still writes the key on every call. An earlier attempt to skip
		# the write entirely once it was set could leave spawn_player ABSENT,
		# and DreamMazeRoot reads it directly and unguarded -- the boundary
		# suite went from clean to nine failures on that alone.
		if str(player_key) == waking_key:
			plan["spawn_player"] = safe_spawn(here)
		else:
			var r: Array = here.rect
			plan["spawn_player"] = [(r[0] + r[2]) * 0.5,
					(r[1] + r[3]) * 0.5]
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
	var r: Array = room.rect

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
	# THE APARTMENT IS THE GROUND TRUTH.  The global material default predates
	# the 60/40 composition ruling and allowed the filter to consume more than
	# half of every architectural plane before exposure had done any work.  A
	# room now begins as recognisable plaster/timber/terrazzo; persistent
	# exposure can still overtake it, but the filter no longer wins by default.
	for pair in [[wall_mat, 0.30], [floor_mat, 0.34], [ceiling_mat, 0.28],
			[door_mat, 0.26], [shaft_mat, 0.46]]:
		if pair[0] is ShaderMaterial:
			(pair[0] as ShaderMaterial).set_shader_parameter("consumed", pair[1])
	# R2: every architectural class receives the same live room bounds, then a
	# class-specific pull toward the seams it actually owns. This does not add a
	# growth field or a material surface; it teaches the existing field where
	# the waking building's joints are.
	configure_architecture_material(wall_mat, r, 1, 0.18, 0.012, 0.038,
			clear_ceiling)
	configure_architecture_material(floor_mat, r, 2, 0.15, 0.010, 0.026,
			clear_ceiling)
	configure_architecture_material(ceiling_mat, r, 3, 0.17, 0.010, 0.042,
			clear_ceiling)
	configure_architecture_material(door_mat, r, 6, 0.15, 0.009, 0.030,
			clear_ceiling)
	configure_architecture_material(shaft_mat, r, 7, 0.20, 0.012, 0.034,
			clear_ceiling)

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
	_build_scars(node, room)
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
	_build_profile_form_stamp(node, room)
	_build_channel_partition_skin(node, room)
	_build_contradictory_antique(node, room)
	_build_orison_interior(node, room)
	_build_orison_furnishing(node, room)
	_build_lineage_body(node, room)
	return node


## One object, two mutually exclusive records. Geometry never swaps: later
## returns add the second plaque around the same stable cabinet silhouette.
func _build_contradictory_antique(parent: Node3D, room: Dictionary) -> void:
	if not bool(room.get("contradictory_antique", false)):
		return
	var r: Array = room.rect
	var centre := Vector3((float(r[0]) + float(r[2])) * 0.5, 0.0,
			(float(r[1]) + float(r[3])) * 0.5)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color("2b1712")
	wood.roughness = 0.72
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color("b98b38")
	brass.metallic = 0.68
	brass.roughness = 0.34
	brass.emission_enabled = true
	brass.emission = Color("6d4212")
	brass.emission_energy_multiplier = 1.8
	_profile_stamp_instances(parent, "ContradictoryAntique", wood, [{
			"size": Vector3(0.72, 1.18, 0.46),
			"at": centre + Vector3.UP * 0.59}])
	var plaques: Array[Dictionary] = []
	var count := (room.get("convergence_returns", {}) as Dictionary).size()
	for i in count:
		var plaque_size := Vector3(0.58, 0.20, 0.028) if i == 0 \
				else Vector3(0.66, 0.72, 0.030)
		plaques.append({"size": plaque_size,
				"at": centre + Vector3(0.0, 0.70 + float(i) * 0.24, -0.255)})
	_profile_stamp_instances(parent, "ContradictoryProvenance", brass, plaques)


## A partition is still the ordinary wall collision above, but its visible
## face is compressed signal: dark speaker cloth and four delayed brass traces.
## These two batches own no collision, navigation, timing or danger.
func _build_channel_partition_skin(parent: Node3D, room: Dictionary) -> void:
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color("170f1c")
	cloth.roughness = 0.98
	var trace := StandardMaterial3D.new()
	trace.albedo_color = Color("a67c2e")
	trace.metallic = 0.72
	trace.roughness = 0.36
	var panels: Array[Dictionary] = []
	var traces: Array[Dictionary] = []
	for door in room.get("doors", []):
		if not bool(door.get("partitioned", false)):
			continue
		var point: Array = door.point
		var inside: Array = door.inside
		var inward := Vector3(float(inside[0]) - float(point[0]), 0.0,
				float(inside[1]) - float(point[1])).normalized()
		var along := Vector3(-inward.z, 0.0, inward.x)
		var centre := Vector3(float(point[0]), 0.0, float(point[1])) \
				+ inward * (WALL_T + 0.018)
		var panel_size := Vector3(0.018, door_h - 0.10, door_w - 0.10) \
				if absf(inward.x) > 0.5 \
				else Vector3(door_w - 0.10, door_h - 0.10, 0.018)
		panels.append({"size": panel_size,
				"at": centre + Vector3.UP * (door_h * 0.5)})
		for i in 4:
			var width := door_w * (0.78 - float(i) * 0.13)
			var y := 0.43 + float(i) * 0.39
			var trace_size := Vector3(0.026, 0.018, width) \
					if absf(inward.x) > 0.5 else Vector3(width, 0.018, 0.026)
			traces.append({"size": trace_size,
					"at": centre + inward * 0.016 + Vector3.UP * y
							+ along * (0.025 if i % 2 == 0 else -0.025)})
	_profile_stamp_instances(parent, "ChannelEchoCloth", cloth, panels)
	_profile_stamp_instances(parent, "ChannelEchoTraces", trace, traces)


## Peter's duplicate is still an Orison corridor, so the evidence belongs to
## the building rather than a UI: an oxblood frame and a stack of period paper
## forms on the additionally dealt door. If overlap forces that opening shut,
## the papers fill the solid wall as a false door. If it opens, the frame and
## header remain and the forms do not obstruct the route. Nothing here owns
## collision or topology, and the repeated pieces are MultiMeshes so making
## the case readable costs three submissions rather than a draw per slip.
func _build_profile_form_stamp(parent: Node3D, room: Dictionary) -> void:
	if not bool(room.get("profile_duplicate", false)):
		return
	var door_index := int(room.get("profile_stamp_door_index", -1))
	var doors: Array = room.get("doors", [])
	if door_index < 0 or door_index >= doors.size():
		return
	var door: Dictionary = doors[door_index]
	var point: Array = door.point
	var inside: Array = door.inside
	var inward := Vector3(float(inside[0]) - float(point[0]), 0.0,
			float(inside[1]) - float(point[1])).normalized()
	if inward.length_squared() < 0.5:
		return
	var along := Vector3(-inward.z, 0.0, inward.x)
	var frame_material := StandardMaterial3D.new()
	frame_material.albedo_color = Color("53171d")
	frame_material.roughness = 0.74
	frame_material.metallic = 0.08
	var paper_material := StandardMaterial3D.new()
	paper_material.albedo_color = Color("b6a080")
	paper_material.roughness = 0.94
	paper_material.albedo_texture = load(
			"res://assets/building/textures/T_library_furniture_aged_paper_albedo.png")
	paper_material.normal_enabled = true
	paper_material.normal_texture = load(
			"res://assets/building/textures/T_library_furniture_aged_paper_normal.png")
	paper_material.roughness_texture = load(
			"res://assets/building/textures/T_library_furniture_aged_paper_rough.png")
	paper_material.uv1_scale = Vector3(1.8, 1.8, 1.8)
	var ink_material := StandardMaterial3D.new()
	ink_material.albedo_color = Color("481016")
	ink_material.roughness = 0.88
	# `point` is the FAR face of the shared wall. The first version placed the
	# frame only 35 mm back from that face, leaving it buried in the 200 mm wall
	# (or visible only from the room the player has not entered). Put it a hair
	# proud of this room's clear face instead. The form must be evidence in the
	# corridor which earned it, not decoration on the void beyond the opening.
	var centre := Vector3(float(point[0]), 0.0, float(point[1])) \
			+ inward * (WALL_T + 0.012)
	var frame_w := 0.085
	var frame_d := 0.035
	var post_size := Vector3(frame_d, door_h, frame_w) \
			if absf(inward.x) > 0.5 else Vector3(frame_w, door_h, frame_d)
	var head_size := Vector3(frame_d, frame_w, door_w) \
			if absf(inward.x) > 0.5 else Vector3(door_w, frame_w, frame_d)
	var frame_boxes: Array[Dictionary] = []
	for side in [-1.0, 1.0]:
		frame_boxes.append({
			"size": post_size,
			"at": centre + along * side * (door_w * 0.5 - frame_w * 0.5)
					+ Vector3.UP * (door_h * 0.5),
		})
	frame_boxes.append({
		"size": head_size,
		"at": centre + Vector3.UP * (door_h - frame_w * 0.5),
	})
	var plaque_size := Vector3(frame_d * 1.2, 0.18, 0.38) \
			if absf(inward.x) > 0.5 else Vector3(0.38, 0.18, frame_d * 1.2)
	frame_boxes.append({
		"size": plaque_size,
		"at": centre + inward * 0.006 + Vector3.UP * (door_h + 0.16),
	})
	_profile_stamp_instances(parent, "ProceedUncertainStamp", frame_material,
			frame_boxes)

	# The frame itself is papered whether the route opens or seals: the demand
	# must read at a glance from Peter's side of the threshold. A sealed demand
	# then becomes the full visual joke he is trapped in: the wall supplies the
	# missing door entirely out of forms, each carrying the same red line.
	var paper_boxes: Array[Dictionary] = []
	var ink_boxes: Array[Dictionary] = []
	var edge_slip := Vector3(0.008, 0.185, 0.135) \
			if absf(inward.x) > 0.5 else Vector3(0.135, 0.185, 0.008)
	var edge_ink := Vector3(0.005, 0.022, 0.070) \
			if absf(inward.x) > 0.5 else Vector3(0.070, 0.022, 0.005)
	for side in [-1.0, 1.0]:
		for i in 8:
			var y := 0.16 + float(i) * 0.247
			var tilt := deg_to_rad(float(((i * 5 + (1 if side > 0.0 else 3))
					% 7) - 3) * 0.85)
			var edge_at: Vector3 = centre + inward * 0.028 \
					+ along * side * (door_w * 0.5 + 0.045) \
					+ Vector3.UP * y
			paper_boxes.append({
				"size": edge_slip, "at": edge_at,
				"axis": inward, "angle": tilt,
			})
			ink_boxes.append({
				"size": edge_ink,
				"at": edge_at + inward * 0.007 + along * side * 0.018
						+ Vector3.DOWN * 0.047,
				"axis": inward, "angle": tilt,
			})
	var header_slip := Vector3(0.008, 0.16, 0.17) \
			if absf(inward.x) > 0.5 else Vector3(0.17, 0.16, 0.008)
	var header_ink := Vector3(0.005, 0.021, 0.085) \
			if absf(inward.x) > 0.5 else Vector3(0.085, 0.021, 0.005)
	for i in 5:
		var tilt := deg_to_rad(float((i % 3) - 1) * 1.1)
		var header_at: Vector3 = centre + inward * 0.028 \
				+ along * (-0.34 + float(i) * 0.17) \
				+ Vector3.UP * (door_h + 0.12)
		paper_boxes.append({
			"size": header_slip, "at": header_at,
			"axis": inward, "angle": tilt,
		})
		ink_boxes.append({
			"size": header_ink,
			"at": header_at + inward * 0.007 + Vector3.DOWN * 0.040,
			"axis": inward, "angle": tilt,
		})
	if bool(door.get("sealed", false)):
		var panel_size := Vector3(0.020, door_h - 0.16, door_w - 0.12) \
				if absf(inward.x) > 0.5 \
				else Vector3(door_w - 0.12, door_h - 0.16, 0.020)
		_profile_stamp_instances(parent, "FormDoorLeaf", frame_material, [{
			"size": panel_size,
			"at": centre + inward * 0.010 + Vector3.UP * (door_h * 0.5),
		}])
		var slip_size := Vector3(0.010, 0.205, 0.61) \
				if absf(inward.x) > 0.5 else Vector3(0.61, 0.205, 0.010)
		var ink_size := Vector3(0.006, 0.025, 0.48) \
				if absf(inward.x) > 0.5 else Vector3(0.48, 0.025, 0.006)
		for i in 6:
			var y := 0.38 + float(i) * 0.285
			var stagger := along * (0.018 if i % 2 == 0 else -0.014)
			paper_boxes.append({
				"size": slip_size,
				"at": centre + inward * 0.030 + stagger + Vector3.UP * y,
			})
			ink_boxes.append({
				"size": ink_size,
				"at": centre + inward * 0.038 + stagger
						+ Vector3.UP * (y - 0.040),
			})
	_profile_stamp_instances(parent, "FormPaperStack", paper_material,
			paper_boxes)
	_profile_stamp_instances(parent, "FormDecisionLines", ink_material,
			ink_boxes)


static func _profile_stamp_instances(parent: Node3D, node_name: String,
		material: Material, boxes: Array[Dictionary]) -> void:
	if boxes.is_empty():
		return
	var mesh_instance := MultiMeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	mesh.material = material
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = mesh
	batch.instance_count = boxes.size()
	for i in boxes.size():
		var box: Dictionary = boxes[i]
		var basis := Basis()
		if box.has("axis"):
			basis = Basis(box.axis as Vector3, float(box.get("angle", 0.0)))
		batch.set_instance_transform(i, Transform3D(
				basis.scaled(box.size as Vector3), box.at as Vector3))
	mesh_instance.multimesh = batch
	parent.add_child(mesh_instance)


## Bind one Klimt material to the measured room which owns it.  The constants
## mirror dream_architecture_relief.gdshaderinc and stay integers because Godot
## shader uniforms do not expose a shared enum to GDScript. Standard-material
## DREAM_PLAIN controls correctly ignore this presentation-only contract.
static func configure_architecture_material(material: Material, rect: Array,
		surface_kind: int, pull: float, tessera_m: float,
		medallion_m: float, clear_height: float = 3.015) -> void:
	if not material is ShaderMaterial or rect.size() < 4:
		return
	var shader_material := material as ShaderMaterial
	shader_material.set_shader_parameter("architecture_bounds", Vector4(
			float(rect[0]), float(rect[1]), float(rect[2]), float(rect[3])))
	shader_material.set_shader_parameter("architecture_clear_ceiling",
			clear_height)
	shader_material.set_shader_parameter("architecture_surface", surface_kind)
	shader_material.set_shader_parameter("architecture_pull", pull)
	shader_material.set_shader_parameter("tessera_relief_m", tessera_m)
	shader_material.set_shader_parameter("medallion_relief_m", medallion_m)
	shader_material.set_shader_parameter("relief_parallax", 0.62)
	shader_material.set_shader_parameter("phase_stage_thresholds",
			Vector4(0.10, 0.34, 0.48, 0.78))
	shader_material.set_shader_parameter("phase_gold_thresholds",
			Vector2(0.70, 0.92))
	var debug_value := clampi(OS.get_environment(
			"DREAM_SURFACE_DEBUG").to_int(), 0, 3)
	shader_material.set_shader_parameter("surface_debug_view", debug_value)


## The wall boxes above still own collision and the exact aperture schedule.
## This is their shallow historic relief: a batched Orison dado, millwork,
## casings and ceiling medallion which cannot alter a route by even a
## millimetre because it carries no physics object.
func _build_orison_interior(parent: Node3D, room: Dictionary) -> void:
	var interior := DreamOrisonInteriorScript.new()
	parent.add_child(interior)
	interior.configure(room, clear_ceiling)


## The atlas has always selected a real Orison room as every generation's
## source, but until now it inherited only that room's measurements.  Borrow a
## small, source-specific set of the production procedural props as inert
## rendered meshes.  BLANKING remains honest: the furnisher reads the same
## blank flag and contributes nothing when a room has forgotten its contents.
func _build_orison_furnishing(parent: Node3D, room: Dictionary) -> void:
	var furnishing := DreamOrisonFurnisherScript.new()
	parent.add_child(furnishing)
	furnishing.configure(room)


## THE PATH IS HER REPRODUCTIVE ANATOMY.
##
## Door zero is special only while its parent is still in the pocket. In that
## state the branch wears THIS room's genome, because the child is what meets
## the parent at the shared aperture. Once short-term memory drops the parent,
## door zero becomes another future child and receives that child's genome.
## That is why this relationship is resolved here rather than in DreamAtlas:
## only the live pocket knows whether an aperture is ancestry or possibility.
func _build_lineage_body(parent: Node3D, room: Dictionary) -> void:
	var branches: Array = []
	var path: PackedInt32Array = room.path
	var parent_key := ""
	if not path.is_empty():
		parent_key = key_of(_parent_path(path))
	for door in room.doors:
		var is_parent := not parent_key.is_empty() \
				and str(door.leads_to) == parent_key
		var branch_path := path
		if not is_parent:
			branch_path = DreamAtlas.step(path, int(door.index))
		branches.append({
			"door": door,
			"is_parent": is_parent,
			"lineage": room.lineage if is_parent
					else atlas.lineage(branch_path),
		})
	var body := DreamLineageBodyScript.new()
	body.configure(room, branches, clear_ceiling)
	body.material_override = _lineage_material(room.lineage)
	parent.add_child(body)


## A PHYSICAL OBJECT NEEDS A PHYSICAL MATERIAL.
##
## The wall shader is an exposure filter over a broad architectural plane. On
## tubes a few centimetres wide its dark ground wins and the first production
## render reduced the reproductive body to a cut-out against the illuminated
## ceiling. This is antique gold alloy under the real service SpotLight3D:
## metallic, never emissive, black outside the beam, with enough diffuse alloy
## content that a curved filament can still be read when its mirror angle is
## not pointed directly at the eye.
func _lineage_material(lineage: Dictionary) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/dream_lineage_gold.gdshader")
	material.set_shader_parameter("gene_phase",
			float(lineage.get("phase", 0.0)))
	# Faint enough that darkness still owns the room, present enough that
	# switching the lamp off does not make her anatomy cease to exist.
	material.set_shader_parameter("dark_glow", 0.016)
	material.set_shader_parameter("motion_gain", 0.0)
	return material


## THE SCARS. Where a hazard would be if this were somebody else's night.
##
## A live hazard and a dormant one wear the same motif -- the watching eyes,
## which is this maze's own word for danger -- so on their own they would be
## indistinguishable, and a hazard you can SEE and misjudge is worse than one
## you cannot see at all. What tells them apart is the ruling of 2026-08-18
## about what light does: the lamp makes the dream overcome the real building.
##
## So a live hazard is the dream showing through, and wakes into gold when the
## beam finds it. A scar never does. Its material is pinned to zero reveal at
## any light level, so however much lamp is spent on it, it stays what the real
## Orison has underneath -- stained plaster, dark and cold and flat. The
## distinction is not a label the player has to learn; it is the one rule they
## have already been taught by every other surface in the building.
##
## No collision, and it is thin enough to walk over without a step. A scar is
## a mark on the floor, not a thing in the room.
func _build_scars(parent: Node3D, room: Dictionary) -> void:
	var index := 0
	for record in room.hazards:
		if armed.has(str(record.id)) and str(room.get("key", "")) != waking_key:
			continue
		var p: Array = record.position
		var half := float(record.clearance_radius_m)
		index += 1
		var mesh := MeshInstance3D.new()
		mesh.name = "Scar%02d" % index
		var box := BoxMesh.new()
		box.size = Vector3(half * 2.0, 0.012, half * 2.0)
		mesh.mesh = box
		# Just proud of the floor plane, so it never z-fights the slab.
		mesh.position = Vector3(float(p[0]), 0.006, float(p[1]))
		mesh.material_override = DreamMazeBuilder._material(
				Color("1d1a20"), 0.94, DreamMazeBuilder.MOTIF_EYE, true)
		parent.add_child(mesh)


## Same derivation as DreamMazeBuilder.floor_holes and for the same reason:
## only a socket whose kind is exactly `positional` is a hazard whose danger
## IS its place, and only an armed one gets a real hole cut for it.
func _room_holes(room: Dictionary) -> Array:
	var holes: Array = []
	if str(room.get("key", "")) == waking_key:
		# Geometry and arming must come from one decision, exactly as
		# DreamMazeBuilder.build_geometry argues: cutting a mouth for a void
		# that will never be armed leaves a real 6 m shaft nothing can
		# attribute, and the body falls into a pit in a run with no way to end.
		return holes
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
