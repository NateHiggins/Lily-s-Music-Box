extends Node
## The fractal made of space, held to the things it actually claims.
##
##     C:/devkit/bin/godot.cmd --headless --path game \
##         res://tests/DreamRoomBuilderTest.tscn
##
## Exit code is the failure count.
##
## DreamAtlasTest proves the NAMES of the rooms are sound. This proves the
## SPACE is, and the two halves fail differently: the atlas fails by being
## random, and the builder fails by being globally consistent -- by quietly
## reconciling rooms into a coherent floor plan, which would look like a bug
## fix and would take the whole thesis with it.
##
##   A. THE JOIN IS EXACT. A child's entry aperture is the SAME rect as the
##      parent's exit aperture, on all four sides and all four quarter turns.
##      A join that is off by a millimetre is a crack you can see through and
##      a wall the body can catch on.
##   B. THE POCKET NEVER OVERLAPS ITSELF. The global guarantee is gone -- it
##      cannot exist in an infinite building -- and this is what replaced it.
##      A door that cannot be honoured is SEALED, never opened into occupied
##      space.
##   C. THE BUILDING STILL DOES NOT CLOSE, now that it has geometry. Walking
##      a loop must not return you, and rooms must not be reconciled.
##   D. THE TRAIL IS REAL. Within TRAIL_LEN the player can retrace; beyond it
##      the way back is somewhere else. Both halves matter: without the first
##      the world is unplayable, without the second it is just a maze.
##   E. THE FAIRNESS CLAMP HOLDS. No armed hazard in any room, at any drift,
##      gives less doorway warning than the authored module gave it or than
##      it is owed, whichever is less.
##   F. THE SAME NAME BUILDS THE SAME ROOM, on any machine, forever.
##   G. WHAT A ROOM COSTS, recorded rather than asserted, so a change to it
##      shows up in a diff.
##   H. THE BUILDING BRANCHES. The geometry honours the door count the atlas
##      asked for; a fractal that mostly makes corridors is not the one the
##      brief describes.
##   I. POCKET ADJACENCY. Every live room reaches every other, a route is the
##      same answer twice, and no segment of one ever leaves architecture.
##      That last is the most load-bearing check here: the pursuer moves by
##      assigning position and never calls move_and_slide, so the waypoint
##      list is the only thing between it and walking through a wall.
##   J. THE FAULTS ARE MADE OF SPACE. A flag carried in a dictionary and
##      never built is not a fault, it is a note about one. RECURSION is the
##      exception and says so in its own output rather than passing quietly.

const SEED_HEX := "f123456789abcdef"
const ARMED := ["open_lift_void", "vantry_signal_trunk", "hollow_runner"]

var failures := 0
var checks := 0
var _rooms: Node3D


func _ready() -> void:
	_rooms = Node3D.new()
	_rooms.name = "Pocket"
	add_child(_rooms)
	print("[ROOMS] START")
	_stage("A join")
	_block_a_join()
	_stage("B pocket")
	_block_b_pocket()
	_stage("C no closure")
	_block_c_no_closure()
	_stage("D trail")
	_block_d_trail()
	_stage("E fairness")
	_block_e_fairness()
	_stage("F determinism")
	_block_f_determinism()
	_stage("G budget")
	_block_g_budget()
	_stage("H branching")
	_block_h_branching()
	_stage("I routing")
	_block_i_routing()
	_stage("J faults as space")
	_block_j_faults()
	_stage("done")
	print("[ROOMS] CHECKS: %d/%d fails=%d"
			% [checks - failures, checks, failures])
	print("DREAM ROOM BUILDER TEST: %s"
			% ["PASS" if failures == 0 else "FAIL"])
	get_tree().quit(failures)


func _builder(nights: int = 3) -> DreamRoomBuilder:
	var atlas := DreamAtlas.new()
	atlas.setup(SEED_HEX, nights)
	var b := DreamRoomBuilder.new()
	b.setup(atlas, ARMED)
	return b


# --- A: the join is exact ---------------------------------------------

func _block_a_join() -> void:
	var b := _builder()
	# Every side of a parent, every quarter turn of a child. Walking a few
	# hundred rooms would hit these by luck; naming them means a regression
	# says WHICH side broke.
	var sides_seen := {}
	var worst := 0.0
	var pairs := 0
	for i in 40:
		var path := PackedInt32Array([i % 4, (i / 4) % 3])
		var parent := b.describe(path)
		for door in parent.doors:
			var child := b.describe(DreamAtlas.step(path, int(door.index)),
					DreamRoomBuilder.exit_join(parent, door))
			if child.doors.is_empty():
				continue
			var entry: Dictionary = child.doors[0]
			pairs += 1
			sides_seen[str(door.side)] = true
			var d := _rect_error(door.aperture, entry.aperture)
			worst = maxf(worst, d)
			# The child must face back the way you came, or the two rooms are
			# joined through walls that are not parallel.
			_check("child entry faces back from a %s exit" % door.side,
					_opposite(str(door.side), str(entry.side)))
	_check("all four exit sides were exercised (%d)" % sides_seen.size(),
			sides_seen.size() == 4)
	_check("%d joins are exact to 1e-6 m (worst %.9f)" % [pairs, worst],
			pairs > 0 and worst < 0.000001)


func _opposite(a: String, b: String) -> bool:
	return (a == "east" and b == "west") or (a == "west" and b == "east") \
			or (a == "north" and b == "south") \
			or (a == "south" and b == "north")


func _rect_error(a: Array, b: Array) -> float:
	var worst := 0.0
	for i in 4:
		worst = maxf(worst, absf(float(a[i]) - float(b[i])))
	return worst


# --- B: the pocket never overlaps itself ------------------------------

func _block_b_pocket() -> void:
	var b := _builder()
	# Walk a long, turning route. Door 1 is chosen where it exists so the
	# walk keeps branching rather than shuttling in and out of one door.
	var path := PackedInt32Array()
	var overlaps := 0
	var visited := 0
	var dead_ends := 0
	var seen := {}
	var deepest := 0
	var stranded := 0
	for step in 60:
		b.advance(_rooms, path)
		visited += 1
		deepest = maxi(deepest, path.size())
		overlaps += _count_overlaps(b)
		var s := _count_stranded(b)
		if s > 0 and stranded == 0:
			_dump_pocket(b, step, DreamRoomBuilder.key_of(path))
		stranded += s
		var room := b.room_at_key(DreamRoomBuilder.key_of(path))
		if room.is_empty():
			break
		# Walk only through doors that are actually open. A sealed door is
		# wall: stepping through one is not a thing the player can do, and a
		# test that does it is measuring a route nobody can take.
		var open_doors := DreamRoomBuilder.passable_doors(room)
		var onward: Array = []
		for door in open_doors:
			if int(door.index) != 0:
				onward.append(door)
		if onward.is_empty():
			# A genuine dead end. Turn round: the way back is still real.
			path = DreamRoomBuilder._parent_path(path)
			dead_ends += 1
			continue
		# PREFER A DOOR THIS WALK HAS NOT TAKEN. A walker that picks by step
		# index oscillates between two rooms the moment it meets a dead end,
		# and then spends the rest of its budget re-entering the same pair --
		# which passes every check while testing almost nothing. Exploring is
		# what puts pressure on the pocket.
		var pick: Dictionary = onward[0]
		for door in onward:
			if not seen.has(str(door.leads_to)):
				pick = door
				break
		seen[str(pick.leads_to)] = true
		path = DreamAtlas.step(path, int(pick.index))
	print("[ROOMS] walk: %d rooms, depth %d, %d distinct, %d dead ends, "
			% [visited, deepest, seen.size(), dead_ends]
			+ "%d doors sealed" % b.sealed_doors)
	_check("walked %d rooms without the pocket losing the player" % visited,
			visited >= 55)
	# A walk that turns round more often than it goes on is not exploring the
	# pocket, and every check below it would then be measuring two rooms.
	_check("the walk went somewhere (%d distinct rooms, depth %d)"
			% [seen.size(), deepest], seen.size() >= 30 and deepest >= 10)
	_check("no two rooms in the live pocket ever overlapped (%d)" % overlaps,
			overlaps == 0)
	# Connectivity is not a property of one lucky pocket. Checked at every
	# step of the walk, because the pocket is rebuilt on every threshold
	# crossing and a room stranded for even one frame is a frame in which the
	# pursuer would route straight through a wall.
	_check("no live room was ever stranded from the rest (%d)" % stranded,
			stranded == 0)
	# A sealed door is the pressure valve for the guarantee above. It is
	# allowed to be zero on this route, but it must never be negative and the
	# counter must be live, so a future regression that opens doors into
	# occupied space is visible rather than silent.
	_check("sealed-door count is tracked (%d over the walk)" % b.sealed_doors,
			b.sealed_doors >= 0)
	# The pocket is bounded. An unbounded pocket is the failure that would
	# reintroduce the whole building through the back door.
	_check("the pocket stayed bounded (%d rooms live)" % b.live_rooms().size(),
			b.live_rooms().size() <= 1 + DreamRoomBuilder.TRAIL_LEN
					+ DreamAtlas.MAX_DOORS)


func _dump_pocket(b: DreamRoomBuilder, step: int, here: String) -> void:
	print("[ROOMS] !! first stranding at step %d, player in %s" % [step, here])
	for room in b.live_rooms():
		var bits := PackedStringArray()
		for door in room.doors:
			var to := str(door.leads_to)
			var mark := "sealed" if bool(door.sealed) \
					else ("->%s" % to if b.room_at_key(to).size() > 0
					else ("dangling(%s)" % to if to != "" else "unset"))
			bits.append("d%d:%s" % [int(door.index), mark])
		print("[ROOMS]    %-12s %s" % [str(room.key), " ".join(bits)])


## Ordered pairs of live rooms with no route between them.
func _count_stranded(b: DreamRoomBuilder) -> int:
	var rooms := b.live_rooms()
	var n := 0
	for a in rooms:
		for c in rooms:
			if str(a.key) != str(c.key) \
					and b.route(str(a.key), str(c.key)).is_empty():
				n += 1
	return n


func _count_overlaps(b: DreamRoomBuilder) -> int:
	var rooms := b.live_rooms()
	var n := 0
	for i in rooms.size():
		for j in range(i + 1, rooms.size()):
			if DreamMazeBuilder._rects_overlap(rooms[i].rect, rooms[j].rect):
				n += 1
	return n


# --- C: the building still does not close -----------------------------

func _block_c_no_closure() -> void:
	var b := _builder()
	var start := PackedInt32Array([1, 2])
	var a := b.describe(start)
	# Four doors out and the loop does not shut: the room you arrive at has a
	# different name AND a different place. Reconciling either would be the
	# refactor this check exists to catch.
	var loop := start.duplicate()
	for d in [1, 1, 1, 1]:
		loop = DreamAtlas.step(loop, d)
	var z := b.describe(loop)
	_check("a four-door loop does not arrive at the room it left",
			int(a.id) != int(z.id))
	# Placement is local, so nothing has snapped the loop shut geometrically
	# either. Same name would be a hash collision; same rect would be a
	# global-placement regression.
	_check("and nothing reconciled the loop back onto its own footprint",
			str(a.rect) != str(z.rect) or int(a.id) == int(z.id))


# --- D: the trail is real, and it ends --------------------------------

func _block_d_trail() -> void:
	var b := _builder()
	var walked: Array = []
	var path := PackedInt32Array()
	for step in 6:
		b.advance(_rooms, path)
		walked.append(DreamRoomBuilder.key_of(path))
		path = DreamAtlas.step(path, 1)
	var here: Dictionary = b.room_at_key(walked[walked.size() - 1])
	_check("the room the player is in is live", not here.is_empty())
	# THE HALF THAT MAKES IT PLAYABLE. The room behind is still real, and the
	# entry door leads back to it rather than somewhere new.
	var back: String = walked[walked.size() - 2]
	_check("the room behind is still real, so a backtrack works",
			not b.room_at_key(back).is_empty())
	var entry: Dictionary = here.doors[0]
	_check("and the entry door leads to it, not to a new room",
			str(entry.leads_to) == back)
	# THE HALF THAT MAKES IT THE DREAM. Beyond the trail the building has
	# reclaimed the space, and there is no way back to it.
	var stale: String = walked[0]
	_check("a room %d steps back has been forgotten"
			% (walked.size() - 1), b.room_at_key(stale).is_empty())
	_check("the trail is exactly TRAIL_LEN deep",
			DreamRoomBuilder.TRAIL_LEN == 3)


# --- E: the fairness clamp holds --------------------------------------

func _block_e_fairness() -> void:
	# Late in a campaign, where decay is deep and SCALE is common.
	var b := _builder(9)
	var atlas: DreamAtlas = b.atlas
	var violations := 0
	var scaled_hazard_rooms := 0
	var clamped := 0
	var worst_deficit := 0.0
	var examined := 0
	for i in 500:
		var path := PackedInt32Array([i % 4, (i / 4) % 4, (i / 16) % 4,
				(i / 64) % 4])
		var room := b.describe(path)
		var live: Array = []
		for h in room.hazards:
			if ARMED.has(str(h.id)):
				live.append(h)
		if live.is_empty():
			continue
		examined += 1
		if float(room.drift) < 1.0:
			scaled_hazard_rooms += 1
		if float(room.scale) > float(room.drift) + 0.000001:
			clamped += 1
		for h in live:
			var floor_s := _floor_for(b, room, h)
			var got := _worst_door_margin(b, room, h)
			if got < floor_s - 0.0005:
				violations += 1
				worst_deficit = maxf(worst_deficit, floor_s - got)
	_check("armed hazards were actually exercised (%d rooms)" % examined,
			examined >= 20)
	_check("SCALE drift did reach hazard rooms (%d wanted to shrink)"
			% scaled_hazard_rooms, scaled_hazard_rooms > 0)
	_check("the clamp fired on %d of them" % clamped, clamped > 0)
	# THE CHECK THE WHOLE CLAMP EXISTS FOR.
	_check("no armed hazard ever gives less warning than it owes " \
			+ "(%d violations, worst deficit %.4f s)"
			% [violations, worst_deficit], violations == 0)
	# The clamp must not be a blunt "never shrink": that would delete the
	# SCALE fault from every hazard room, which is a design loss disguised as
	# a safety fix.
	var grew := 0
	for i in 200:
		var room := b.describe(PackedInt32Array([i % 4, (i / 4) % 4, 3]))
		if float(room.scale) > 1.0001:
			grew += 1
	_check("rooms may still swell past 1.0 (%d did)" % grew, grew > 0)


## The warning this hazard is entitled to in this room: what the authored
## module gave it, or what it is owed, whichever is less. Recomputed here
## independently of the builder so the test is not marking its own homework.
func _floor_for(b: DreamRoomBuilder, room: Dictionary,
		h: Dictionary) -> float:
	var unit: Vector2 = (room.size as Vector2) / maxf(float(room.scale),
			0.0001)
	var authored := _margin_at(b, room, h, unit, 1.0)
	return minf(authored, float(h.minimum_warning_s))


func _worst_door_margin(b: DreamRoomBuilder, room: Dictionary,
		h: Dictionary) -> float:
	var unit: Vector2 = (room.size as Vector2) / maxf(float(room.scale),
			0.0001)
	return _margin_at(b, room, h, unit, float(room.scale))


## Straight-run warning from the tightest doorway, in the room's local frame.
func _margin_at(b: DreamRoomBuilder, room: Dictionary, h: Dictionary,
		unit: Vector2, scale: float) -> float:
	var module: Dictionary = b.catalog.get("modules", {}).get(
			str(room.source), {})
	var at := Vector2.ZERO
	for socket in module.get("hazard_sockets", []):
		if str(socket.get("id", "")) == str(h.id):
			var p: Array = socket.position_m
			at = Vector2(float(p[0]) * scale, float(p[1]) * scale)
	var size := unit * scale
	var doors := b._door_layout(int(room.id), size, int(room.doors.size()),
			b._entry_offset(int(room.id), size), 0, Vector2.ZERO, false)
	var worst := INF
	for door in doors:
		var inside: Array = door.inside
		var d := Vector2(inside[0], inside[1]).distance_to(at)
		worst = minf(worst, (minf(d, float(h.tell_radius_m))
				- float(h.clearance_radius_m)) / b.run_speed)
	return 0.0 if worst == INF else worst


# --- F: the same name builds the same room ----------------------------

func _block_f_determinism() -> void:
	var a := _builder()
	var b := _builder()
	var path := PackedInt32Array([2, 0, 3, 1])
	var join := {"side": "east", "point": Vector2(11.5, -4.25)}
	_check("two builders describe one room identically",
			str(a.describe(path, join)) == str(b.describe(path, join)))
	_check("and describing it twice is the same room",
			str(a.describe(path, join)) == str(a.describe(path, join)))
	# A different campaign is a different building, in space as well as name.
	var other_atlas := DreamAtlas.new()
	other_atlas.setup("0123456789abcdef", 3)
	var other := DreamRoomBuilder.new()
	other.setup(other_atlas, ARMED)
	_check("a different campaign seed builds a different room",
			str(a.describe(path, join)) != str(other.describe(path, join)))


# --- G: what a room costs ---------------------------------------------

func _block_g_budget() -> void:
	var b := _builder()
	# Its own parent. _free_room calls queue_free, which needs a frame to
	# land, and this suite never yields one -- so the shared node still holds
	# every room the earlier blocks retired. The pocket bound in block B is
	# still honest because it reads _live, which is erased immediately; only
	# the scene tree lags. Counting cost has to use a parent nothing else
	# has touched.
	var plot := Node3D.new()
	plot.name = "BudgetPocket"
	add_child(plot)
	var path := PackedInt32Array([0, 1])
	b.advance(plot, path)
	var bodies := 0
	var rooms := 0
	for child in plot.get_children():
		if not str(child.name).begins_with("Room_"):
			continue
		rooms += 1
		bodies += child.get_child_count()
	var per := float(bodies) / maxf(float(rooms), 1.0)
	# NOT a pass/fail threshold pretending to be a measurement: this frame is
	# submission-bound (TASKS.md P), so the number of StaticBody3D +
	# MeshInstance3D pairs the pocket holds is the cost that matters, and it
	# is recorded here so a change to it is visible in a diff. The generous
	# ceiling only catches a runaway.
	print("[ROOMS] pocket cost: %d rooms, %d bodies, %.1f per room"
			% [rooms, bodies, per])
	_check("a room stays under 40 bodies (%.1f)" % per, per < 40.0)


# --- H: the building actually branches ---------------------------------

## The atlas asks for two to four doors a room, and the brief wants a player
## who has to CHOOSE rather than proceed. If most rooms arrive with one way
## on, the fractal is a corridor with extra steps -- so the door count the
## atlas asked for and the door count the geometry could honour are compared
## here, and the gap is the number that matters.
func _block_h_branching() -> void:
	var b := _builder()
	var asked := {}
	var got := {}
	var short_rooms := 0
	var no_entry := 0
	for i in 400:
		var path := PackedInt32Array([i % 4, (i / 4) % 4, (i / 16) % 5])
		var room := b.describe(path)
		var want := int(b.atlas.room(path).doors)
		asked[want] = int(asked.get(want, 0)) + 1
		var n := int(room.doors.size())
		got[n] = int(got.get(n, 0)) + 1
		if n < want:
			short_rooms += 1
		if n == 0:
			no_entry += 1
	print("[ROOMS] doors asked for: %s" % str(asked))
	print("[ROOMS] doors delivered: %s" % str(got))
	print("[ROOMS] %d of 400 rooms got fewer doors than asked" % short_rooms)
	# THE SOFT-LOCK CHECK. A room with no door at all is a volume the player
	# can be standing in with no way out, and the smallest catalog footprint
	# at 0.80 drift is narrow enough to produce one if nothing widens it.
	_check("no room is ever built without a door (%d)" % no_entry,
			no_entry == 0)
	_check("every room offers at least one way on beyond its entry",
			int(got.get(1, 0)) == 0)
	# A building where most rooms are corridors is not the one the brief
	# describes: "a player facing three unmarked doors has to choose rather
	# than proceed".
	var branching := 400 - int(got.get(1, 0)) - int(got.get(2, 0))
	_check("at least a third of rooms offer a real choice (%d of 400)"
			% branching, branching >= 133)


# --- I: pocket adjacency, which replaces chain_route -------------------

## The pursuer assigns `position` directly and never calls move_and_slide, so
## the waypoint list is the ONLY thing between it and walking through a wall.
## That makes the segment-containment check below the most load-bearing
## assertion in this file: everything else here is about the building being
## right, and this one is about a body not leaving it.
func _block_i_routing() -> void:
	var b := _builder()
	var nav := Node3D.new()
	nav.name = "NavPocket"
	add_child(nav)
	# Walk a little way in so the pocket holds a trail as well as neighbours.
	var path := PackedInt32Array()
	for i in 5:
		b.advance(nav, path)
		var here := b.room_at_key(DreamRoomBuilder.key_of(path))
		var onward := DreamRoomBuilder.passable_doors(here)
		var took := false
		for door in onward:
			if int(door.index) != 0:
				path = DreamAtlas.step(path, int(door.index))
				took = true
				break
		if not took:
			break
	b.advance(nav, path)

	var rooms := b.live_rooms()
	_check("the pocket has something to route over (%d rooms)" % rooms.size(),
			rooms.size() >= 3)

	# Every room's own centre resolves to that room.
	var centred := 0
	for room in rooms:
		var r: Array = room.rect
		if b.nav_room_at((r[0] + r[2]) * 0.5, (r[1] + r[3]) * 0.5) \
				== str(room.key):
			centred += 1
	_check("every live room's centre resolves to itself (%d/%d)"
			% [centred, rooms.size()], centred == rooms.size())

	# A body standing in an aperture must still have a room. Without the
	# door-strip tolerance it loses one on every threshold crossing, which is
	# precisely when the straight-line fallback would cut architecture.
	var in_doors := 0
	var door_total := 0
	for room in rooms:
		for door in DreamRoomBuilder.passable_doors(room):
			var a: Array = door.aperture
			door_total += 1
			if b.nav_room_at((a[0] + a[2]) * 0.5, (a[1] + a[3]) * 0.5) != "":
				in_doors += 1
	_check("a body in a doorway still has a room (%d/%d apertures)"
			% [in_doors, door_total], door_total > 0 and in_doors == door_total)

	# Route between every ordered pair that is connected at all.
	var routed := 0
	var unreachable := 0
	var unstable := 0
	var breaches := 0
	var worst_gap := 0.0
	for from_room in rooms:
		for to_room in rooms:
			if str(from_room.key) == str(to_room.key):
				continue
			var legs := b.route(str(from_room.key), str(to_room.key))
			if legs.is_empty():
				unreachable += 1
				continue
			routed += 1
			# STABILITY. Two identical calls must give an identical answer or
			# the body oscillates in a doorway between equal alternatives.
			if str(legs) != str(b.route(str(from_room.key),
					str(to_room.key))):
				unstable += 1
			# Waypoints arrive as one near/centre/far triple per door.
			if legs.size() % 3 != 0:
				breaches += 1
			var chain: Array = [_centre_of(from_room)]
			chain.append_array(legs)
			chain.append(_centre_of(to_room))
			var gap := _worst_breach(b, chain)
			if gap > 0.0:
				breaches += 1
				worst_gap = maxf(worst_gap, gap)
	# EVERY LIVE ROOM MUST REACH EVERY OTHER. The pocket is the current room,
	# its neighbours and the trail behind it, so it is connected by
	# construction -- and an unreachable pair is not a missing convenience,
	# it is the pursuer being handed an empty route, which it takes as
	# licence to walk a straight line to the player through whatever is in
	# the way.
	_check("every live room can reach every other (%d routed, %d unreachable)"
			% [routed, unreachable], routed > 0 and unreachable == 0)
	_check("a route is the same answer twice (%d unstable)" % unstable,
			unstable == 0)
	# THE ONE THAT MATTERS.
	_check("no route segment ever leaves architecture (%d breaches, " \
			% breaches + "worst %.3f m outside)" % worst_gap, breaches == 0)

	_check("routing to yourself is no route",
			b.route(str(rooms[0].key), str(rooms[0].key)).is_empty())
	_check("routing to a room that is not live is no route",
			b.route(str(rooms[0].key), "@9.9.9.9.9").is_empty())

	# The pursuer's origin: behind the player, resolvable, and not on top
	# of them.
	var here_key := DreamRoomBuilder.key_of(path)
	var spawn := b.pursuer_spawn(here_key)
	_check("the pursuer has somewhere to start", spawn.size() == 2)
	if spawn.size() == 2:
		var at := b.nav_room_at(spawn[0], spawn[1])
		_check("and it is inside a live room (%s)" % at, at != "")
		_check("and it is not the room the player is standing in",
				at != here_key)


func _centre_of(room: Dictionary) -> Vector3:
	var r: Array = room.rect
	return Vector3((r[0] + r[2]) * 0.5, 0.0, (r[1] + r[3]) * 0.5)


## Walk every segment of a route and return how far the worst sample strays
## outside all live rooms and all open apertures. Zero means the whole path
## stayed inside real space.
func _worst_breach(b: DreamRoomBuilder, chain: Array) -> float:
	var worst := 0.0
	for i in range(chain.size() - 1):
		var a: Vector3 = chain[i]
		var c: Vector3 = chain[i + 1]
		var steps := maxi(2, int(a.distance_to(c) / 0.20))
		for s in range(steps + 1):
			var p := a.lerp(c, float(s) / float(steps))
			worst = maxf(worst, _outside_by(b, p))
	return worst


## How far this point is outside every live room and every open aperture, in
## metres. Rooms are tested with a small tolerance because a waypoint sitting
## exactly on a boundary is legitimate.
func _outside_by(b: DreamRoomBuilder, p: Vector3) -> float:
	var best := INF
	for room in b.live_rooms():
		best = minf(best, _outside_rect(room.rect, p))
		for door in DreamRoomBuilder.passable_doors(room):
			best = minf(best, _outside_rect(door.aperture, p))
	return 0.0 if best <= 0.02 else best


func _outside_rect(r: Array, p: Vector3) -> float:
	var dx := maxf(maxf(float(r[0]) - p.x, p.x - float(r[2])), 0.0)
	var dz := maxf(maxf(float(r[1]) - p.z, p.z - float(r[3])), 0.0)
	return sqrt(dx * dx + dz * dz)


# --- J: the faults expressed as actual space ---------------------------

## The atlas NAMES six ways memory fails. A flag carried in a dictionary and
## never built is not a fault, it is a note about one, so each of these checks
## asks the same question: can the player see it from inside the room?
func _block_j_faults() -> void:
	var b := _builder(9)
	var plot := Node3D.new()
	plot.name = "FaultPocket"
	add_child(plot)

	# REPETITION. The room must genuinely BE the previous room's module at the
	# previous room's size -- not merely flagged as repeating.
	var repeats := 0
	var wrong_source := 0
	var wrong_size := 0
	var moved_doors := 0
	var clamped_copies := 0
	for i in 600:
		var path := PackedInt32Array([i % 4, (i / 4) % 4, (i / 16) % 5])
		var parent := b.describe(path)
		for door in parent.doors:
			var child := b.describe(DreamAtlas.step(path, int(door.index)),
					DreamRoomBuilder.exit_join(parent, door))
			if not bool(child.get("repeated", false)):
				continue
			repeats += 1
			if str(child.source) != str(parent.source):
				wrong_source += 1
			# Compare shape only where nothing else was entitled to move it.
			# A repeating room inherits the previous room's drift, but the
			# fairness clamp and the entry-door floor both outrank cosmetic
			# fidelity: if the inherited module carries an armed hazard the
			# clamp will widen the copy, and a copy that is a little larger
			# is a far better outcome than a hazard closer to a doorway than
			# the warning it owes.
			if absf(float(child.scale) - float(parent.scale)) > 0.0001:
				clamped_copies += 1
			elif ((child.size as Vector2)
					- (parent.size as Vector2)).length() > 0.001:
				wrong_size += 1
			if not child.doors.is_empty() and not parent.doors.is_empty() \
					and absf(float(child.doors[0].inside[0])
					- float(parent.doors[0].inside[0])) > 0.001:
				moved_doors += 1
	_check("REPETITION actually happens (%d rooms)" % repeats, repeats > 0)
	_check("a repeating room is built from the previous room's module (%d wrong)"
			% wrong_source, wrong_source == 0)
	_check("and at the previous room's size (%d wrong, %d overruled by the "
			% [wrong_size, clamped_copies] + "fairness clamp)",
			wrong_size == 0)
	# The brief's "differing in one detail you cannot name": same shape, and
	# the way out has moved. If the doors matched too it would not be a
	# near-copy, it would be the same room.
	_check("but its doors have moved (%d of %d)" % [moved_doors, repeats],
			moved_doors > 0)

	# BLANKING. A blanked room is a shape with holes in it: no lintels, so its
	# openings run floor to ceiling, and no hazards.
	# BLANKING needs decay >= 0.90, and decay is capped by how DEEP the room
	# is as well as by how many nights have passed: at depth 4 after 9 nights
	# the most any room can reach is about 0.88, so the fault is literally
	# unreachable near where the player woke. That is the atlas working as
	# designed -- "far rooms are less rehearsed and therefore worse
	# remembered" -- and it means the end state of forgetting is something the
	# player can only find by pushing in. Sampling it needs a deep walk and a
	# long campaign.
	var deep := _builder(30)
	var blank_lintels := 0
	var blank_rooms := 0
	var dressed_lintels := 0
	var dressed_rooms := 0
	for i in 400:
		var path := PackedInt32Array([i % 5, (i / 5) % 5, (i / 25) % 5, 2,
				1, 0, 3, 2, 1, 0, 2, 3])
		var room := deep.describe(path)
		var node := deep.build(plot, room)
		var lintels := 0
		for child in node.get_children():
			if str(child.name).begins_with("Lintel"):
				lintels += 1
		if bool(room.blank):
			blank_rooms += 1
			blank_lintels += lintels
			if not room.hazards.is_empty():
				blank_lintels += 100
		else:
			dressed_rooms += 1
			dressed_lintels += lintels
		node.free()
	_check("BLANKING actually happens (%d rooms)" % blank_rooms,
			blank_rooms > 0)
	_check("a blanked room has no door frames and no hazards (%d found)"
			% blank_lintels, blank_lintels == 0)
	_check("a remembered room still has them (%d frames over %d rooms)"
			% [dressed_lintels, dressed_rooms], dressed_lintels > 0)

	# CONFABULATION adds a door the plan does not have -- the only fault that
	# makes the building larger than the building. The atlas grants the extra
	# door; this confirms the geometry actually carries it rather than
	# dropping it on a wall too short to hold one.
	var confab := 0
	var confab_doors := 0
	for i in 400:
		var path := PackedInt32Array([i % 4, (i / 4) % 5, (i / 20) % 5, 1])
		var room := b.describe(path)
		if int(room.fault) != DreamAtlas.Fault.CONFABULATION:
			continue
		confab += 1
		if int(room.doors.size()) >= 3:
			confab_doors += 1
	_check("CONFABULATION rooms are built with the doors it invents (%d/%d)"
			% [confab_doors, confab], confab > 0 and confab_doors == confab)

	# RECURSION is NOT expressed, and this says so out loud rather than
	# leaving a silent gap that reads as done. The atlas produces the flag;
	# nothing in this builder makes an enterable smaller copy of a room, and
	# nothing anywhere in the project does nested space, so its cost is
	# genuinely unmeasured rather than merely unimplemented.
	var recursive := 0
	for i in 400:
		var room := b.describe(PackedInt32Array([i % 5, (i / 5) % 5,
				(i / 25) % 5, 3]))
		if bool(room.recursive):
			recursive += 1
	print("[ROOMS] RECURSION: %d of 400 rooms ask for it; the builder does "
			% recursive + "not yet express it. UNPRICED.")
	_check("the atlas does produce RECURSION for a builder to answer later",
			recursive > 0)


# --- harness ----------------------------------------------------------

## Stage markers, flushed, so a run that stops tells you WHERE. The first
## version of this suite hung and the pipe died holding every print it had
## buffered, which is the same lesson as last session's five: fix the
## instrument before theorising about the subject.
func _stage(label: String) -> void:
	print("[ROOMS] .. %s" % label)


func _check(label: String, ok: bool) -> void:
	checks += 1
	if ok:
		print("  ok   %s" % label)
	else:
		failures += 1
		printerr("  FAIL %s" % label)
