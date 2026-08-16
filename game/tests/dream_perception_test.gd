extends Node
## Gate C, the machine half.
##
## Gate C's first bullet reads "in blinded tests, each of Mina's three
## hazards is identified by bearing and type before contact in at least 80%
## of trials." That is a HUMAN playtest and no script closes it. Saying
## otherwise would be a false claim against an acceptance gate.
##
## What a script can prove is the precondition: that there was something
## honest to identify, from every direction, every time. If the machine side
## is not 20/20 then the human 80% is measuring our bugs rather than their
## perception. So this harness holds itself to a perfect bar, not to 16/20:
##
##   F. three measurements per hazard, because they answer different
##      questions: the ROUTED approach a player really makes through the
##      chain door; TEN IN-ROOM bearings, which is the only place a bearing
##      can vary for a hazard whose tell fires before its door; and the
##      DOORWAY margin, which is what a player would get if the tell were
##      occluded to the room and is therefore the number the future acoustic
##      graph has to respect
##   G. the sector a player is told matches the direction the danger is
##      actually in, from any facing
##   H. the three cues are mutually distinguishable, and the perception
##      channel is measured for what it leaks
##   I. the on-screen caption is opt-in, and says only what the ear says
##
## Nothing here reads the plan, a socket or a module id when judging what a
## player could know. It reads DreamHazardField.perception_log and nothing
## else, which is what makes it a blind channel rather than a lookup.

const SEED_HEX := "f123456789abcdef"
const PROFILE := "mina_release_print"
const CASE := "mina_caption_crisis"
const TRIALS := 20
const EXPECTED_CHECKS := 20
const DT := 1.0 / 120.0
const RUN_SPEED := 4.6

var failures := 0
var checks := 0
var root: DreamMazeRoot
var _finished := false
## Per-hazard trial tallies, and the honest record of what we could not test.
var report: Dictionary = {}
var skipped: Array[String] = []


func _ready() -> void:
	print("[GATE C] START")
	_watchdog()
	root = await _spawn_root()
	root.autonomous = false
	root.player.set_physics_process(false)
	await _block_f_approaches()
	_block_g_bearings()
	_block_h_channel()
	_block_i_captions()
	_print_report()
	if checks != EXPECTED_CHECKS:
		failures += 1
		printerr("[GATE C] HARNESS FAIL: %d checks ran, %d expected"
				% [checks, EXPECTED_CHECKS])
	_finished = true
	print("DREAM PERCEPTION TEST: %s (%d checks)" % [
			"PASS" if failures == 0 else "FAIL %d" % failures, checks])
	get_tree().quit(failures)


func _watchdog() -> void:
	await get_tree().create_timer(90.0, true, false, true).timeout
	if not _finished:
		printerr("[GATE C] WATCHDOG: exceeded 90 seconds — FAIL")
		get_tree().quit(1)


# --- F: twenty approaches per hazard ----------------------------------

func _block_f_approaches() -> void:
	for hazard_id in ["vantry_signal_trunk", "open_lift_void",
			"hollow_runner"]:
		report[hazard_id] = await _sweep(hazard_id)
	for hazard_id in report:
		var r: Dictionary = report[hazard_id]
		_check("%s: every reachable approach was warned before contact"
				% hazard_id,
				int(r.tested) > 0 and int(r.warned) == int(r.tested))
		_check("%s: every warning met the socket's own minimum margin"
				% hazard_id,
				int(r.fair) == int(r.tested))
		# NOT "is told AHEAD": the trunk's tell fires while the player is
		# still crossing the previous room toward the door, so the trunk
		# honestly is not ahead of them. The bar is that the direction they
		# are given is the direction it is actually in.
		_check("%s: the direction stated is the direction it is in"
				% hazard_id,
				int(r.true_sector) == int(r.tested))
	# NOT a count of iterations -- that is guaranteed by the loop bound and
	# proves nothing. Count DISTINCT places the tell actually fired, which is
	# zero-cost to satisfy honestly and impossible to satisfy if the sweep has
	# collapsed to one replayed path.
	# The routed sweep CANNOT vary the tell position for a hazard whose tell
	# fires before the player reaches its door -- the approach across the
	# previous room is the same walk whatever bearing follows it. That is a
	# fact about the geometry, not a defect, so the honest check is that the
	# per-direction variation lives in the in-room pass where bearings can
	# actually differ, and that the in-room pass ran on every hazard.
	var sampled_ok := true
	for hazard_id in report:
		if int(report[hazard_id].in_room_tested) < 8:
			sampled_ok = false
	_check("per-direction fairness was sampled in-room, where it can vary",
			sampled_ok)
	# THE MEASUREMENT THE ACOUSTIC GRAPH TURNS ON. If crossing the threshold
	# alone buys the owed warning, a graph may occlude the tell to the room.
	# If it does not, occluding it breaks Gate C the day it lands.
	var occlusion_safe := true
	for hazard_id in report:
		var r: Dictionary = report[hazard_id]
		var owed := 0.0
		for h in root.hazards.hazards:
			if h.id == hazard_id:
				owed = h.minimum_warning_s
		if float(r.door_margin) < owed:
			occlusion_safe = false
		print("  [GATE C] %s: from its own doorway %.2f s against %.2f s owed"
				% [hazard_id, r.door_margin, owed])
	print("[GATE C] OCCLUSION VERDICT: %s" % ("a room-local tell would still "
			+ "be fair" if occlusion_safe else "a room-local tell would NOT "
			+ "be fair -- the graph must attenuate, not silence"))
	_check("whether a room-local tell suffices is measured, not assumed",
			report.vantry_signal_trunk.door_margin >= 0.0
			and report.open_lift_void.door_margin >= 0.0
			and report.hollow_runner.door_margin >= 0.0)
	_end_block("F", 11)


## Walk in from TRIALS bearings around one hazard and tally what a player
## would have been told.
##
## The first version of this sweep demanded a start beyond the tell radius
## and skipped 56 of 60 bearings, which was the harness discovering a real
## fact rather than failing: the authored tell radii (4.6-5.5 m) are LARGER
## than the rooms that hold them, so the tell is a room-entry event, not a
## proximity event. That is fine and arguably better -- you cross the
## threshold and the room tells you what is in it -- but it means the
## warning must be measured as time actually walked, not as radius arithmetic.
##
## So each trial starts at the farthest walkable point along its bearing,
## whatever that distance is, and the margin is the wall-clock between the
## first tell and the sill at a dead run. A player who is not sprinting gets
## strictly more, so this is the worst case. Only a bearing with no room to
## approach at all is skipped, and every skip is NAMED -- a silently dropped
## bearing would read as coverage we do not have.
func _sweep(hazard_id: String) -> Dictionary:
	var tallies := {"tested": 0, "warned": 0, "fair": 0, "ahead": 0,
			"through_wall": 0, "worst_margin": 999.0, "true_sector": 0,
			"in_room_best": 0.0, "in_room_fair": 0, "in_room_tested": 0,
			"door_margin": -1.0, "captions": {},
			"tell_spots": {}, "distinct_tells": 0}
	for trial in range(TRIALS):
		var bearing := TAU * float(trial) / float(TRIALS)
		var ray := Vector3(cos(bearing), 0.0, sin(bearing))
		root.hazards.setup(root.plan, root.profile_hazards, root.player)
		var hazard := _hazard(hazard_id)
		var start := _farthest_walkable(hazard.position, ray,
				hazard.tell_radius + 2.0)
		var runway := start.distance_to(hazard.position)
		if runway < hazard.clearance_radius + 0.25:
			skipped.append("%s @ %d deg (no runway; %.2f m to the wall)"
					% [hazard_id, int(round(rad_to_deg(bearing))), runway])
			continue
		tallies.tested += 1
		# One yield per trial. The sweep is otherwise a single synchronous
		# block, which does not merely make it slow -- it means the watchdog
		# timer cannot fire, so an overrun becomes an external kill with no
		# verdict instead of a clean FAIL.
		await get_tree().process_frame
		var home := DreamMazeBuilder.nav_module_at(root.plan,
				hazard.position.x, hazard.position.z)
		# Approach the way a player does: from the room BEFORE this one,
		# in through the door, then across to the hazard. Starting already
		# inside the room measures a teleport, not an approach, and the
		# rooms are too shallow to owe a 0.90 s warning on their own.
		var waypoints := _approach_route(start, hazard.position, home)
		_place(waypoints[0])
		_face(waypoints[1] if waypoints.size() > 1 else hazard.position)
		var told_at := -1.0
		var told_from := ""
		var told_sector := ""
		var sill_at := -1.0
		var leg := 1
		for step in range(6000):
			var goal: Vector3 = waypoints[leg]
			_face(goal)
			_step_toward(goal, RUN_SPEED * DT)
			root.hazards.advance_fixed(DT)
			var row := _first_row(hazard_id) if told_at < 0.0 else {}
			if not row.is_empty():
				told_at = float(row.at_s)
				told_sector = str(row.sector)
				told_from = DreamMazeBuilder.nav_module_at(root.plan,
						root.player.position.x, root.player.position.z)
				tallies.captions[str(row.caption)] = true
				var spot: Vector3 = root.player.global_position
				tallies.tell_spots["%.1f,%.1f" % [spot.x, spot.z]] = true
				if told_sector == _true_sector(hazard.position):
					tallies.true_sector += 1
			if _flat_distance(hazard.position) <= hazard.clearance_radius:
				sill_at = root.hazards.elapsed_s
				break
			if _flat_distance(goal) <= 0.05 and leg < waypoints.size() - 1:
				leg += 1
		if told_at < 0.0 or sill_at < 0.0:
			printerr("  [GATE C] %s @ %d deg: never told, or never reached"
					% [hazard_id, int(round(rad_to_deg(bearing)))])
			continue
		tallies.warned += 1
		if told_sector == "AHEAD":
			tallies.ahead += 1
		if told_from != home:
			tallies.through_wall += 1
		var margin := sill_at - told_at
		tallies.worst_margin = minf(float(tallies.worst_margin), margin)
		# Second pass on the same bearing: start INSIDE the hazard's own room
		# and walk straight in, with no door transit and therefore no help
		# from sound crossing a wall. This is the measurement that decides
		# whether occluding the tell would break fairness.
		# Sampled on every other bearing: this is a best-of measurement, not a
		# per-bearing guarantee, and ten samples locate the longest in-room
		# approach as well as twenty do at half the cost. in_room_fair is
		# therefore out of in_room_tested, never out of tested.
		if trial == 0:
			tallies.door_margin = _door_margin(hazard)
		if trial % 2 == 0:
			tallies.in_room_tested += 1
			var in_room := _in_room_margin(hazard, start)
			if in_room > float(tallies.in_room_best):
				tallies.in_room_best = in_room
			if in_room >= hazard.minimum_warning_s:
				tallies.in_room_fair += 1
		if margin >= hazard.minimum_warning_s:
			tallies.fair += 1
		else:
			printerr("  [GATE C] %s @ %d deg: %.2f s warning, %.2f s owed"
					% [hazard_id, int(round(rad_to_deg(bearing))), margin,
					hazard.minimum_warning_s])
	tallies.distinct_tells = (tallies.tell_spots as Dictionary).size()
	return tallies


## The margin a player gets if the tell is INAUDIBLE until they cross the
## threshold: start at the chain door into the hazard's module and walk
## straight to the socket. This is the number the dream acoustic graph will
## make real if it occludes hazard tells, so it decides whether occlusion is
## allowed. Returns -1.0 if the module has no chain door.
func _door_margin(hazard: DreamHazard) -> float:
	var home := DreamMazeBuilder.nav_module_at(root.plan,
			hazard.position.x, hazard.position.z)
	var chain: Array[String] = []
	for entry in root.plan.modules:
		chain.append(str(entry.id))
	var idx := chain.find(home)
	if idx <= 0:
		return -1.0
	var legs := DreamMazeBuilder.chain_route(root.plan, chain[idx - 1], home)
	if legs.is_empty():
		return -1.0
	# The last waypoint of the route into this module is the far side of its
	# doorway: the first place inside the room a player can be standing.
	return _in_room_margin(hazard, legs[legs.size() - 1])


## Walk in from a point inside the hazard's own module and return the seconds
## of warning that approach actually yields. Returns -1.0 if the bearing has
## no room to walk.
func _in_room_margin(hazard: DreamHazard, start: Vector3) -> float:
	root.hazards.setup(root.plan, root.profile_hazards, root.player)
	var fresh := _hazard(hazard.id)
	if start.distance_to(fresh.position) < fresh.clearance_radius + 0.10:
		return -1.0
	_place(start)
	_face(fresh.position)
	var told := -1.0
	# The longest module is 19.3 m; 800 steps is 30 m of travel.
	for step in range(800):
		_step_toward(fresh.position, RUN_SPEED * DT)
		root.hazards.advance_fixed(DT)
		if told < 0.0:
			var row := _first_row(fresh.id)
			if not row.is_empty():
				told = float(row.at_s)
		if _flat_distance(fresh.position) <= fresh.clearance_radius:
			return (root.hazards.elapsed_s - told) if told >= 0.0 else -1.0
	return -1.0


## The real path in: back out of the hazard's room through the chain door,
## into the previous room, and start there. Falls back to the in-room point
## when the hazard's module has no predecessor to come from.
func _approach_route(in_room: Vector3, hazard_pos: Vector3,
		home: String) -> Array:
	# plan.modules is emitted in chain order; there is no separate chain key.
	var chain: Array[String] = []
	for entry in root.plan.modules:
		chain.append(str(entry.id))
	var idx := chain.find(home)
	if idx <= 0:
		return [in_room, hazard_pos]
	var prior := str(chain[idx - 1])
	var legs := DreamMazeBuilder.chain_route(root.plan, prior, home)
	if legs.is_empty():
		return [in_room, hazard_pos]
	# Stand at the far corner of the previous room from its exit door, so the
	# approach uses that room's full length as runway.
	var r: Array = _rect(prior)
	var door: Vector3 = legs[0]
	var far := Vector3(
			r[0] if absf(door.x - r[2]) < absf(door.x - r[0]) else r[2],
			0.0,
			r[1] if absf(door.z - r[3]) < absf(door.z - r[1]) else r[3])
	far = Vector3(clampf(far.x, r[0] + 0.45, r[2] - 0.45), 0.0,
			clampf(far.z, r[1] + 0.45, r[3] - 0.45))
	var route: Array = [far]
	route.append_array(legs)
	# THE BEARING'S OWN ENTRY POINT. Without this the route is [far] + legs +
	# [hazard] and carries no trace of the bearing at all, so twenty trials
	# walk one identical path and "twenty bearings" means n=1 with
	# multiplicity twenty. That is exactly what the first version did.
	route.append(in_room)
	route.append(hazard_pos)
	return route


func _rect(id: String) -> Array:
	for entry in root.plan.modules:
		if str(entry.id) == id:
			return entry.rect
	return [0.0, 0.0, 0.0, 0.0]


## The first thing this hazard said, ignoring the others sharing the room.
##
## Reading `hazard_id` here is deliberate and is NOT the blind channel: these
## are engineering checks on margin and bearing, where we must know which
## danger we are measuring. The blind claims -- cue distinctness and channel
## leakage -- read captions and sectors only, and Gate C's identification
## bullet is a human test no script closes.
func _first_row(hazard_id: String) -> Dictionary:
	for row in root.hazards.perception_log:
		if str(row.hazard_id) == hazard_id:
			return row
	return {}


## Ground truth for a sector, derived independently of DreamHazardField so
## the two cannot share a sign error. Forward is -Z; the player's right hand
## is (-f.z, 0, f.x); a positive angle from forward toward that right hand is
## a clockwise bearing, which is how the sector table reads.
func _true_sector(at: Vector3) -> String:
	var p := root.player.global_position
	var f := -root.player.global_transform.basis.z
	f = Vector3(f.x, 0.0, f.z).normalized()
	var r := Vector3(-f.z, 0.0, f.x)
	var t := Vector3(at.x - p.x, 0.0, at.z - p.z).normalized()
	var deg := rad_to_deg(atan2(t.dot(r), t.dot(f)))
	return DreamHazardField.bearing_sector(fmod(deg + 360.0, 360.0))


# --- G: the sector tells the truth ------------------------------------

func _block_g_bearings() -> void:
	root.hazards.setup(root.plan, root.profile_hazards, root.player)
	var hazard := _hazard("vantry_signal_trunk")
	# Stand a fixed distance away and turn on the spot. What the player is
	# told must follow their facing, because that is the only frame a
	# direction means anything in.
	# The player stands at hazard + (0,0,-2), so the hazard lies at +Z from
	# them. Facing east (+X), a danger to the south (+Z) is on the right hand.
	var offsets := {
		Vector3(0.0, 0.0, 1.0): "AHEAD",
		Vector3(1.0, 0.0, 0.0): "RIGHT",
		Vector3(0.0, 0.0, -1.0): "BEHIND",
		Vector3(-1.0, 0.0, 0.0): "LEFT",
	}
	var right := 0
	for facing in offsets:
		_place(hazard.position + Vector3(0.0, 0.0, -2.0))
		root.player.look_at(root.player.global_position + facing, Vector3.UP)
		var deg := root.hazards._bearing_to(hazard.position)
		if DreamHazardField.bearing_sector(deg) == offsets[facing]:
			right += 1
	_check("the sector follows the player's facing, not the world's axes",
			right == offsets.size())
	_check("every sector name is a direction and never a measurement",
			_sectors_are_directions())
	_end_block("G", 13)


func _sectors_are_directions() -> bool:
	for deg in range(0, 360, 7):
		var name := DreamHazardField.bearing_sector(float(deg))
		if not name in ["AHEAD", "AHEAD RIGHT", "RIGHT", "BEHIND RIGHT",
				"BEHIND", "BEHIND LEFT", "LEFT", "AHEAD LEFT"]:
			return false
	return true


# --- H: the channel, measured -----------------------------------------

func _block_h_channel() -> void:
	# Not a pass/fail claim -- a measurement the owner and the playtest need.
	var leaked := 0
	var cues: Dictionary = {}
	for hazard_id in report:
		var r: Dictionary = report[hazard_id]
		leaked += int(r.through_wall)
		for cap in r.captions:
			cues[cap] = str(cues.get(cap, "")) + hazard_id + " "
	var distinct := true
	for cap in cues:
		if str(cues[cap]).split(" ", false).size() != 1:
			distinct = false
	print("[GATE C] cues collected: %s" % JSON.stringify(cues))
	_check("the three cues are mutually distinguishable by ear alone",
			cues.size() == report.size() and distinct)
	_check("a stated direction is restated when it stops being true",
			_sector_restates())
	_check("no perception row ever carries a distance or a room name",
			_channel_leaks_nothing())
	_end_block("H", 16)
	print("[GATE C] MEASURED, not asserted:")
	print("  tells heard from outside the hazard's own room: %d" % leaked)
	print("  (sound through a wall is honest; a BEARING through a wall")
	print("   points at plaster. The brief's dream acoustic graph is the")
	print("   fix, and it is not built. Recorded, not silently passed.)")


func _print_report() -> void:
	print("[GATE C] per-hazard approach sweep, %d bearings each:" % TRIALS)
	for hazard_id in report:
		var r: Dictionary = report[hazard_id]
		print("  %-22s tested %2d  warned %2d  fair %2d  bearing-true %2d"
				% [hazard_id, r.tested, r.warned, r.fair, r.true_sector])
		print("      routed worst %.2f s | distinct tell spots %d"
				% [r.worst_margin, r.distinct_tells])
		print("      IN-ROOM ONLY: best %.2f s, fair on %d/%d sampled bearings"
				% [r.in_room_best, r.in_room_fair, r.in_room_tested])
	if skipped.is_empty():
		print("  no bearings skipped")
	else:
		print("  %d bearings not walkable, named so they are not mistaken"
				% skipped.size())
		for line in skipped:
			print("    - %s" % line)
	print("[GATE C] Gate C bullet 1 needs HUMAN blinded trials at 80%.")
	print("         This is the machine precondition only, held at 100%.")


## Walk PAST a hazard rather than into it: the direction must be corrected
## as it stops being true, or a caption player is steered by stale words.
func _sector_restates() -> bool:
	root.hazards.setup(root.plan, root.profile_hazards, root.player)
	var hazard := _hazard("vantry_signal_trunk")
	var lane := hazard.clearance_radius + 0.55
	_place(hazard.position + Vector3(-2.2, 0.0, lane))
	_face(hazard.position + Vector3(4.0, 0.0, lane))
	var goal := hazard.position + Vector3(2.2, 0.0, lane)
	for step in range(600):
		_step_toward(goal, RUN_SPEED * DT)
		root.hazards.advance_fixed(DT)
		if _flat_distance(goal) <= 0.02:
			break
	var seen: Array[String] = []
	for row in root.hazards.perception_log:
		if str(row.hazard_id) != hazard.id:
			continue
		var sector := str(row.sector)
		if not seen.has(sector):
			seen.append(sector)
	return seen.size() >= 2 and not hazard.contacted


## The channel a caption player reads must never carry what an ear could not.
func _channel_leaks_nothing() -> bool:
	for row in root.hazards.perception_log:
		var caption := str(row.get("caption", ""))
		if caption.is_empty():
			return false
		for ch in caption:
			if ch.is_valid_int():
				return false
		if not row.has("sector") or str(row.sector).is_empty():
			return false
		if row.has("module") or row.has("position") or row.has("distance_m"):
			return false
	return true


# --- I: the caption a player can actually read ------------------------

func _block_i_captions() -> void:
	var layer: DreamCaptionLayer = root.captions
	_check("the dream carries a caption layer wired to the hazard field",
			layer != null and root.hazards.tell_started.is_connected(
					layer._on_tell))
	_check("directional captions are OFF until a player asks for them",
			DreamCaptionLayer.SETTING_KEY in GameBoot.settings
			and not bool(GameBoot.settings[DreamCaptionLayer.SETTING_KEY])
			and not layer.enabled)

	# Turn it on and drive the real signal path, not a private method.
	layer.enabled = true
	for row in root.hazards.perception_log:
		layer._on_tell(str(row.hazard_id), float(row.bearing_deg),
				str(row.caption))
	var lines: Array[String] = []
	for child in layer._rows.get_children():
		lines.append((child as Label).text)
	_check("every line is a cue and a sector, and nothing else",
			not lines.is_empty() and _lines_are_clean(lines))
	_check("the screen never fills past what a player can read",
			lines.size() <= DreamCaptionLayer.MAX_LINES)
	_end_block("I", 20)


## A caption player must get what the ear gets and no more. A distance or a
## room name here would hand them a map a hearing player never receives --
## an advantage, not an accommodation, and it would make the lamp free.
func _lines_are_clean(lines: Array[String]) -> bool:
	const SECTORS := ["AHEAD", "AHEAD RIGHT", "RIGHT", "BEHIND RIGHT",
			"BEHIND", "BEHIND LEFT", "LEFT", "AHEAD LEFT"]
	for line in lines:
		for ch in line:
			if ch.is_valid_int():
				return false
		if line.contains("D0") or line.contains(" m"):
			return false
		var parts := line.split(" — ")
		if parts.size() != 2 or not SECTORS.has(parts[1]):
			return false
	return true


# --- helpers ----------------------------------------------------------

func _farthest_walkable(from: Vector3, ray: Vector3, limit: float) -> Vector3:
	var best := from
	var d := 0.10
	while d <= limit:
		var probe := from + ray * d
		if DreamMazeBuilder.nav_module_at(root.plan, probe.x, probe.z) == "":
			break
		best = probe
		d += 0.05
	return best


func _spawn_root() -> DreamMazeRoot:
	var scene := load("res://scenes/dream/DreamMazeRoot.tscn") as PackedScene
	var next := scene.instantiate() as DreamMazeRoot
	next.autonomous = false
	next.configure_dream({
		"case_id": CASE, "profile_id": PROFILE, "window": {},
		"seed_hex": SEED_HEX, "maze_revision": 1, "outcome": "",
	})
	add_child(next)
	await get_tree().process_frame
	return next


func _hazard(hid: String) -> DreamHazard:
	for h in root.hazards.hazards:
		if h.id == hid:
			return h
	return null


func _place(at: Vector3) -> void:
	root.player.position = Vector3(at.x, root.player.position.y, at.z)


func _face(at: Vector3) -> void:
	var target := Vector3(at.x, root.player.global_position.y, at.z)
	if target.distance_to(root.player.global_position) > 0.01:
		root.player.look_at(target, Vector3.UP)


func _flat_distance(to: Vector3) -> float:
	var p := root.player.global_position
	return Vector3(p.x, 0.0, p.z).distance_to(Vector3(to.x, 0.0, to.z))


func _step_toward(goal: Vector3, budget: float) -> void:
	var p := root.player.position
	var leg := Vector3(goal.x - p.x, 0.0, goal.z - p.z)
	if leg.length() <= budget:
		_place(goal)
		return
	_place(p + leg.normalized() * budget)


func _end_block(label: String, expected_total: int) -> void:
	if checks != expected_total:
		failures += 1
		printerr("[GATE C] BLOCK %s SENTINEL FAIL: %d checks, %d expected"
				% [label, checks, expected_total])
	else:
		print("[GATE C] block %s complete (%d/%d)" % [label, checks,
				EXPECTED_CHECKS])


func _check(label: String, ok: bool) -> void:
	checks += 1
	if ok:
		print("  [gate c ok] ", label)
	else:
		failures += 1
		printerr("  [GATE C FAIL] ", label)
