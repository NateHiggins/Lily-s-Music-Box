extends Node
## THE FRACTAL AS THE LIVE DREAM, not as a builder in a jar.
##
##     C:/devkit/bin/godot.cmd --headless --path game \
##         res://tests/DreamFractalRunTest.tscn
##
## Exit code is the failure count. WITHOUT the environment flag this suite
## skips every check and passes trivially, because the world it is written
## against is not the one that gets built. The DREAM_FRACTAL flag this suite
## was written behind is gone: the pocket is the only world there is now.
##
## DreamRoomBuilderTest proves the pocket is correct on its own. This proves
## the RUNTIME agrees with it: that DreamMazeRoot builds the fractal instead of
## the chain, that the body starts inside it, that crossing a threshold rolls
## the pocket underneath a moving player without dropping them out of the
## world, and that the three things which cache against rooms -- practicals,
## hazards and the pursuer's route -- survive rooms being forgotten.
##
## The check that matters most is the clock one. DreamHazardField.setup zeroes
## elapsed_s and clears both logs, and elapsed_s is what every realised-warning
## number in Gate C is measured against; re-arming a changed pocket by calling
## setup would silently reset the run clock mid-passage and make the fairness
## evidence meaningless while everything still looked fine.

const CASE := "mina_caption_crisis"
const PROFILE := "mina_release_print"
const SEED_HEX := "f123456789abcdef"

var failures := 0
var checks := 0
var root: DreamMazeRoot
var _finished := false


func _ready() -> void:
	print("[FRACTAL] START")
	_watchdog()
	await _block_a_builds()
	await _block_b_threshold()
	await _block_c_pursuit()
	_finished = true
	print("[FRACTAL] CHECKS: %d/%d fails=%d"
			% [checks - failures, checks, failures])
	print("DREAM FRACTAL RUN TEST: %s"
			% ["PASS" if failures == 0 else "FAIL"])
	get_tree().quit(failures)


func _watchdog() -> void:
	await get_tree().create_timer(60.0, true, false, true).timeout
	if not _finished:
		printerr("[FRACTAL] WATCHDOG: exceeded 60 seconds — FAIL")
		get_tree().quit(1)


# --- A: the runtime builds the fractal, not the chain -----------------

func _block_a_builds() -> void:
	root = await _spawn_root()
	_check("the dream world built at all", root.maze_built)
	_check("it built the fractal rather than the chain",
			root.rooms != null and not root.rooms.live_rooms().is_empty())
	_check("the plan carries no defects",
			(root.plan.get("defects", ["unbuilt"]) as Array).is_empty())
	# The body must be INSIDE a room. A plan whose spawn lands outside every
	# rect drops the player through the floor on the first frame, and the
	# chain's own spawn point is meaningless here.
	var at := root.rooms.nav_room_at(root.player.position.x,
			root.player.position.z)
	_check("the body woke inside a real room (%s)" % at, at != "")
	_check("and that room is the one the atlas named",
			at == root.start_module_id())
	# OWNER RULING 2026-08-18: not D00, and not a root the player could learn
	# to recognise as an entrance.
	_check("the waking room is not the old D00 threshold",
			root.start_module_id() != "D00_4B_THRESHOLD")
	# Every consumer reads these directly and crashes on a missing key.
	var keys_ok := true
	for key in ["modules", "doors", "hazards", "spawn_player",
			"spawn_pursuer", "defects"]:
		if not root.plan.has(key):
			keys_ok = false
			printerr("  [FRACTAL] plan is missing %s" % key)
	_check("the plan carries every key its consumers read directly", keys_ok)
	# A hazard id must name ONE hazard. The fractal can place the same catalog
	# module in several live rooms at once, and a duplicate id would attribute
	# a tell in one room to a hole in another.
	var seen := {}
	var dupes := 0
	for record in root.plan.hazards:
		var hid := str(record.id)
		if seen.has(hid):
			dupes += 1
		seen[hid] = true
	_check("no two live hazards share an id (%d duplicates)" % dupes,
			dupes == 0)
	# YOU MUST NOT WAKE INSIDE A HAZARD. The chain never had to ask -- it
	# always began at D00, which carries no sockets -- so nothing anywhere
	# checked it. The fractal wakes the player wherever the seed points, and a
	# waking room holding the lift void would drop them through the floor in
	# the first frame of the dream, with no warning and no chance to act.
	var worst := INF
	var owed_by := ""
	for hazard in root.hazards.hazards:
		var owed: float = hazard.clearance_radius \
				+ 4.6 * hazard.minimum_warning_s
		var gap := Vector2(root.player.position.x - hazard.position.x,
				root.player.position.z - hazard.position.z).length() - owed
		if gap < worst:
			worst = gap
			owed_by = hazard.socket
	_check("the waking place owes no hazard warning it cannot pay " \
			+ "(worst %.2f m spare, %s)"
			% [0.0 if worst == INF else worst,
			owed_by if owed_by != "" else "no armed hazard"],
			worst == INF or worst >= 0.0)
	_check("and the armed ones still carry their catalog socket",
			root.hazards == null or root.hazards.hazards.is_empty()
			or str(root.hazards.hazards[0].socket) != "")

	# DORMANT SOCKETS: the danger this building remembers from other nights.
	# Owner ruling 2026-08-18. They travel in the plan and they are visible,
	# and the whole risk of showing them is that a player might mistake one
	# for a live hazard -- so what is asserted here is that they are inert in
	# every way that could ever hurt someone.
	var dormant := 0
	var live := 0
	for record in root.plan.hazards:
		if bool(record.get("armed", false)):
			live += 1
		else:
			dormant += 1
	print("[FRACTAL] hazards in plan: %d live, %d dormant" % [live, dormant])
	_check("the plan carries the building's whole danger vocabulary (%d dormant)"
			% dormant, dormant > 0)
	# 1. A scar can never fire. The field arms on the profile allowlist, so a
	#    dormant socket must produce no DreamHazard at all.
	var armed_ids := {}
	for hazard in root.hazards.hazards:
		armed_ids[hazard.id] = true
	var firing_scars := 0
	for record in root.plan.hazards:
		if not bool(record.get("armed", false)) \
				and armed_ids.has(str(record.id)):
			firing_scars += 1
	_check("no dormant socket ever became a live hazard (%d)" % firing_scars,
			firing_scars == 0)
	# 2. A scar is never a hole. Cutting the floor for a socket nothing can
	#    attribute would leave a real 6 m shaft with no way to end the run --
	#    the exact argument DreamMazeBuilder.build_geometry makes for taking
	#    the allowlist in the first place.
	var scar_holes := 0
	for room in root.rooms.live_rooms():
		for hole in root.rooms._room_holes(room):
			scar_holes += 1
	var armed_positional := 0
	for hazard in root.hazards.hazards:
		if hazard.falls_through:
			armed_positional += 1
	_check("only armed voids cut the floor (%d holes, %d armed positional)"
			% [scar_holes, armed_positional], scar_holes == armed_positional)
	# 3. A scar is not solid. It is a mark on the floor, not a thing to walk
	#    into, so it must carry no collision.
	var solid_scars := 0
	for room in root.rooms.live_rooms():
		var node: Node3D = root.rooms._nodes.get(str(room.key))
		if node == null or not is_instance_valid(node):
			continue
		for child in node.get_children():
			if str(child.name).begins_with("Scar") and child is CollisionObject3D:
				solid_scars += 1
	_check("a scar is a mark, not an obstacle (%d solid)" % solid_scars,
			solid_scars == 0)


# --- B: the pocket rolls under a moving body --------------------------

func _block_b_threshold() -> void:
	var start_key := root.start_module_id()
	var crossings := 0
	var lost := 0
	var clock_resets := 0
	var last_clock := 0.0
	var visited := {start_key: true}
	# Walk the body through doors by hand. This is not a physics test: the
	# point is that the WORLD keeps up, so the body is placed rather than
	# driven.
	for hop in 12:
		var here := root.rooms.room_at_key(root.start_module_id() if hop == 0
				else root.rooms.nav_room_at(root.player.position.x,
				root.player.position.z))
		if here.is_empty():
			lost += 1
			break
		var onward: Array = []
		for door in DreamRoomBuilder.passable_doors(here):
			if int(door.index) != 0:
				onward.append(door)
		if onward.is_empty():
			break
		# Step to the far side of the opening, which is a point inside the
		# next room, then let the world notice.
		var door: Dictionary = onward[hop % onward.size()]
		var p: Array = door.point
		var inside: Array = door.inside
		var out := Vector2(p[0] - inside[0], p[1] - inside[1]).normalized()
		root.player.position = Vector3(p[0] + out.x * 0.6, 0.0,
				p[1] + out.y * 0.6)
		root.hazards.advance_fixed(0.05)
		last_clock = root.hazards.elapsed_s
		await get_tree().physics_frame
		await get_tree().process_frame
		if root.hazards.elapsed_s < last_clock - 0.0001:
			clock_resets += 1
		var now := root.rooms.nav_room_at(root.player.position.x,
				root.player.position.z)
		if now == "":
			lost += 1
			break
		if now != root.start_module_id():
			# The world did not follow the body across the threshold.
			lost += 1
			break
		if not visited.has(now):
			crossings += 1
			visited[now] = true
	print("[FRACTAL] walked %d new rooms, %d live now"
			% [crossings, root.rooms.live_rooms().size()])
	_check("the body crossed into new rooms (%d)" % crossings, crossings >= 4)
	_check("and the world followed it every time (%d losses)" % lost,
			lost == 0)
	# THE ONE THAT PROTECTS GATE C.
	_check("re-arming a changed pocket never reset the run clock (%d resets)"
			% clock_resets, clock_resets == 0)
	_check("the pocket stayed bounded while walking (%d rooms)"
			% root.rooms.live_rooms().size(),
			root.rooms.live_rooms().size() <= 8)
	# Exactly one fixture burns, and it stands beyond a door of the room the
	# body is in rather than at a chain index that no longer exists.
	var lit := 0
	for practical in root._practicals:
		if practical.visible:
			lit += 1
	_check("at most one practical burns (%d)" % lit, lit <= 1)


# --- C: the Tenant routes over the pocket -----------------------------

func _block_c_pursuit() -> void:
	_check("the pursuer exists and was handed the fractal",
			root.pursuer != null and root.pursuer.rooms != null)
	# It must resolve to a live room; a pursuer standing nowhere routes by
	# straight line, and a straight line goes through walls.
	var at := root.rooms.nav_room_at(root.pursuer.position.x,
			root.pursuer.position.z)
	_check("the Tenant is standing in a real room (%s)" % at, at != "")
	var mine := root.rooms.nav_room_at(root.player.position.x,
			root.player.position.z)
	_check("and it is not already on top of the player", at != mine
			or root.pursuer.position.distance_to(root.player.position) > 0.75)
	# Drive it and confirm it stays inside architecture the whole way.
	var breaches := 0
	var steps := 0
	for i in 90:
		root.pursuer.advance_fixed(0.05)
		steps += 1
		if root.rooms.nav_room_at(root.pursuer.position.x,
				root.pursuer.position.z) == "":
			breaches += 1
		if root.pursuer.is_captured:
			break
	_check("the Tenant never left the building over %d steps (%d breaches)"
			% [steps, breaches], breaches == 0)
	# The run-cap fold has no terminal module to aim at any more; it must
	# still put the Tenant somewhere real.
	root._cap_fold()
	var folded := root.rooms.nav_room_at(root.pursuer.position.x,
			root.pursuer.position.z)
	_check("the run-cap fold lands the Tenant in a real room (%s)" % folded,
			folded != "")


# --- harness ----------------------------------------------------------

func _spawn_root() -> DreamMazeRoot:
	var scene := load("res://scenes/dream/DreamMazeRoot.tscn") as PackedScene
	var next := scene.instantiate() as DreamMazeRoot
	next.autonomous = false
	next.configure_dream({
		"case_id": CASE, "profile_id": PROFILE, "window": {},
		"seed_hex": SEED_HEX, "maze_revision": 1, "outcome": "",
		"night_index": 3, "spawn_anchor": 1,
	})
	add_child(next)
	await get_tree().process_frame
	await get_tree().physics_frame
	return next


func _check(label: String, ok: bool) -> void:
	checks += 1
	if ok:
		print("  ok   %s" % label)
	else:
		failures += 1
		printerr("  FAIL %s" % label)
