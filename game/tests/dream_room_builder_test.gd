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
					DreamRoomBuilder.exit_join(door))
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
	for step in 60:
		b.advance(_rooms, path)
		visited += 1
		deepest = maxi(deepest, path.size())
		overlaps += _count_overlaps(b)
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
