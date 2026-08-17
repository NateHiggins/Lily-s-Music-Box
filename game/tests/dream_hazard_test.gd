extends Node
## N7: the passage ends, and it ends fairly.
##
## Six things proved here, in the order they were built:
##   A. one outcome funnel, latched, and the N6 capture path unchanged
##   B. the 28 s slot ceiling closes a run the player is surviving
##   C. the builder's hazard sockets land where the catalog authored them
##   D. the Vantry trunk is a real conditional danger, and every impact
##      got at least the warning its socket promised
##   E. the lift void is a real hole in the real floor, and gravity — not a
##      radius — is what ends the run over it
##   F. the hollow runner breaks under a sprint and holds under a walk, and
##      what breaking DOES is a stumble and a noise, not an ending
##
## Harness integrity follows the N6 idiom: exact check count, a counted
## sentinel closing every block, deterministic fixed-rate stepping, and a
## nonzero exit on any failure.

const SEED_HEX := "f123456789abcdef"
const ALT_SEED_HEX := "f123456789abcdee"
const PROFILE := "mina_release_print"
const CASE := "mina_caption_crisis"
const EXPECTED_CHECKS := 42
const DT := 1.0 / 120.0

var failures := 0
var checks := 0
var root: DreamMazeRoot
var _finished := false


func _ready() -> void:
	print("[N7] START")
	_watchdog()
	await _block_a_funnel()
	await _block_b_cap()
	_block_c_sockets()
	await _block_d_trunk()
	await _block_e_void()
	await _block_f_runner()
	if checks != EXPECTED_CHECKS:
		failures += 1
		printerr("[N7] HARNESS FAIL: %d checks ran, %d expected"
				% [checks, EXPECTED_CHECKS])
	_finished = true
	print("DREAM HAZARD TEST: %s (%d checks)" % [
			"PASS" if failures == 0 else "FAIL %d" % failures, checks])
	get_tree().quit(failures)


func _watchdog() -> void:
	await get_tree().create_timer(50.0, true, false, true).timeout
	if not _finished:
		printerr("[N7] WATCHDOG: exceeded 50 seconds — FAIL")
		get_tree().quit(1)


# --- A: the outcome funnel -------------------------------------------

func _block_a_funnel() -> void:
	root = await _spawn_root()
	_check("the dream world builds with a hazard field",
			root.maze_built and root.hazards != null)
	_check("only the case's allowed hazards are armed",
			root.hazards.hazards.size() == 3)
	var armed: Array[String] = []
	for h in root.hazards.hazards:
		armed.append(h.id)
	armed.sort()
	_check("the slot-3 rhythmic counterweight is placed but NOT armed",
			armed == ["hollow_runner", "open_lift_void",
					"vantry_signal_trunk"]
			and (root.plan.hazards as Array).size() == 4)
	# No shell here, so the commit must refuse rather than half-succeed.
	_check("an outcome cannot commit without the transaction owner",
			not root._commit_outcome("contact")
			and not root._outcome_committed)
	_end_block("A", 4)


# --- B: the run cap ---------------------------------------------------

func _block_b_cap() -> void:
	_check("the slot's authored ceiling is read from the catalog",
			absf(root.run_cap_s - 28.0) < 0.001)
	root.autonomous = false
	root.player.set_physics_process(false)
	# Park the player mid-chain and let the clock run out on them.
	var d01 := _rect("D01_F04_LONG_HALL")
	root.player.position = Vector3(d01[0] + 6.0, 0.0,
			(d01[1] + d01[3]) * 0.5)
	var before := JSON.stringify(root.pursuer.run_parameters())
	var start_at: Vector3 = root.pursuer.position
	root.run_elapsed_s = 27.9
	root.autonomous = true
	for i in range(30):
		await get_tree().physics_frame
		if root.run_elapsed_s >= root.run_cap_s:
			break
	root.autonomous = false
	_check("the ceiling expires and folds the pursuit",
			root.run_elapsed_s >= 28.0
			and root.pursuer.position != start_at)
	_check("the fold puts the Tenant on real graph space, not in a wall",
			DreamMazeBuilder.nav_module_at(root.plan,
					root.pursuer.position.x, root.pursuer.position.z) != "")
	_check("the fold does not reroll the seeded pursuit",
			JSON.stringify(root.pursuer.run_parameters()) == before)
	var frozen_from := root.run_elapsed_s
	for i in range(6):
		await get_tree().physics_frame
	_check("a non-autonomous world never advances the clock",
			absf(root.run_elapsed_s - frozen_from) < 0.0001)
	_end_block("B", 9)


# --- C: the sockets ---------------------------------------------------

func _block_c_sockets() -> void:
	var catalog := DreamMazeBuilder.load_catalog()
	var mirrored := DreamMazeBuilder.assemble(catalog, SEED_HEX, 1)
	var straight := DreamMazeBuilder.assemble(catalog, ALT_SEED_HEX, 1)
	_check("both hands assemble four sockets with no defects",
			(mirrored.hazards as Array).size() == 4
			and (straight.hazards as Array).size() == 4
			and (mirrored.defects as Array).is_empty()
			and (straight.defects as Array).is_empty())
	_check("hazards never enter the door list that cuts real openings",
			(mirrored.doors as Array).size() == 4
			and (straight.doors as Array).size() == 4)
	_check("the trunk lands on the catalog's authored point, unmirrored",
			_at(straight, "vantry_signal_trunk", 35.450, 4.165))
	_check("the seed's mirror flips it about its module's depth axis",
			_at(mirrored, "vantry_signal_trunk", 35.450, -2.915)
			and _at(mirrored, "open_lift_void", 19.650, -2.365))
	_check("the socket's authored radii survive into the plan",
			_radii(mirrored, "vantry_signal_trunk", 0.35, 5.50, 0.90))
	_end_block("C", 14)


# --- D: the trunk, and the fairness bar -------------------------------

func _block_d_trunk() -> void:
	root.queue_free()
	await get_tree().process_frame
	root = await _spawn_root()
	root.autonomous = false
	root.player.set_physics_process(false)
	var trunk := _hazard("vantry_signal_trunk")
	_check("the trunk is armed and silent before anyone is near it",
			trunk != null and trunk.tell_started_s < 0.0)

	# Walk in from well outside the tell radius, lamp OFF.
	root.player.set_lamp_enabled(false)
	_place(trunk.position + Vector3(7.5, 0.0, 0.0))
	var heard_at := -1.0
	for i in range(400):
		_step_toward(trunk.position, 4.6 * DT)
		root.hazards.advance_fixed(DT)
		if heard_at < 0.0 and trunk.tell_started_s >= 0.0:
			heard_at = trunk.tell_started_s
		if _flat_distance(trunk.position) < 0.10:
			break
	_check("the tell fires in darkness, before the danger is even live",
			heard_at >= 0.0 and not root.hazards.perception_log.is_empty())
	_check("standing on an unlit trunk is survivable, which is the lesson",
			not trunk.contacted and root.hazards.impact_log.is_empty())

	# Same spot, lamp ON: the arc reaches for the beam.
	root.player.set_lamp_enabled(true)
	root.hazards.advance_fixed(DT)
	_check("the same spot with the lamp on ends the run by contact",
			trunk.contacted and root.hazards.impact_log.size() == 1)
	var rec: Dictionary = root.hazards.impact_log[0]
	_check("the impact record carries the whole fairness story",
			str(rec.hazard_id) == "vantry_signal_trunk"
			and bool(rec.lamp_on)
			and str(rec.outcome) == "contact"
			and float(rec.tell_start_s) >= 0.0
			and float(rec.contact_s) > float(rec.tell_start_s))
	_check("the player got at least the warning the socket promised",
			root.hazards.unfair_impacts().is_empty()
			and float(rec.realised_warning_s)
					>= float(rec.minimum_warning_s))
	_check("the perception log names a bearing sector and never a distance",
			_captions_leak_nothing())
	_check("contact is one of the three legal outcomes",
			DreamHazard.NONE == ""
			and str(rec.outcome) in DreamDirector.OUTCOMES)
	_check("a contacted hazard does not fire twice",
			root.hazards.advance_fixed(DT) == DreamHazard.NONE
			and root.hazards.impact_log.size() == 1)
	_end_block("D", 23)


# --- E: the void, resolved by gravity ---------------------------------

func _block_e_void() -> void:
	root.queue_free()
	await get_tree().process_frame
	root = await _spawn_root()
	root.autonomous = false
	var allow: Array = root.profile_hazards.get("allow", [])
	var holes := DreamMazeBuilder.floor_holes(root.plan, allow)
	# An unarmed socket must cut NOTHING: a mouth with no hazard behind it is
	# a sealed pit the run cannot end in.
	_check("an unarmed socket cuts no mouth at all",
			DreamMazeBuilder.floor_holes(root.plan, []).is_empty()
			and DreamMazeBuilder.floor_holes(root.plan,
					["counterweight_passage"]).is_empty())
	_check("exactly one mouth is cut, and it is a lift doorway wide",
			holes.size() == 1
			and absf(holes[0][2] - holes[0][0] - 0.90) < 0.001
			and absf(holes[0][3] - holes[0][1] - 0.90) < 0.001)

	var void_h := _hazard("open_lift_void")
	var mod := _rect(void_h.module)
	var hole: Array = holes[0]
	var margins := [hole[0] - mod[0], mod[2] - hole[2],
			hole[1] - mod[1], mod[3] - hole[3]]
	var tightest := INF
	for m in margins:
		tightest = minf(tightest, float(m))
	_check("the mouth leaves a body's width on every side of its module",
			tightest >= 0.66)

	var clear_of_doors := true
	for door in root.plan.doors:
		if DreamMazeBuilder._rects_overlap(hole, door.aperture):
			clear_of_doors = false
	_check("no mouth eats a doorway the chain has to pass through",
			clear_of_doors)
	_check("the floor is genuinely absent there and present beside it",
			not _floor_covers(void_h.position.x, void_h.position.z)
			and _floor_covers(void_h.position.x + 1.2, void_h.position.z)
			and _floor_covers(void_h.position.x, void_h.position.z - 1.4))

	# Approach on solid floor with physics parked: the draught reaches you
	# well before the sill does, and standing beside the mouth is safe.
	root.player.set_physics_process(false)
	root.player.set_lamp_enabled(false)
	_place(void_h.position + Vector3(6.0, 0.0, 0.0))
	for i in range(300):
		_step_toward(void_h.position + Vector3(1.05, 0.0, 0.0), 4.6 * DT)
		root.hazards.advance_fixed(DT)
		if _flat_distance(void_h.position) <= 1.06:
			break
	_check("the draught arrives long before the sill, and the sill holds",
			void_h.tell_started_s >= 0.0 and not void_h.contacted)

	# Now step over the mouth and let real gravity finish the sentence.
	root.player.set_physics_process(true)
	root.player.velocity = Vector3.ZERO
	root.player.position = Vector3(void_h.position.x, 0.30,
			void_h.position.z)
	var outcome := ""
	for i in range(240):
		await get_tree().physics_frame
		outcome = root.hazards.advance_fixed(DT)
		if outcome != DreamHazard.NONE:
			break
	_check("real gravity through the real hole ends the run as a fall",
			outcome == "fall"
			and root.player.global_position.y
					< DreamMazeBuilder.FALL_TRIGGER_Y)
	var rec: Dictionary = root.hazards.impact_log[0]
	_check("the fall is recorded, attributed and fair",
			root.hazards.impact_log.size() == 1
			and str(rec.hazard_id) == "open_lift_void"
			and str(rec.outcome) == "fall"
			and root.hazards.unfair_impacts().is_empty())
	_end_block("E", 31)


## Is there a built floor slab under this point? Read from the real scene the
## builder produced, not from the plan, so the check can catch a slab that was
## computed correctly and then emitted wrong.
func _floor_covers(x: float, z: float) -> bool:
	var architecture := root.find_child("ModuleArchitecture", true, false)
	if architecture == null:
		return false
	for child in architecture.get_children():
		if not child.name.begins_with("DreamFloor"):
			continue
		var shape_node := child.get_child(0) as CollisionShape3D
		var box := shape_node.shape as BoxShape3D
		var c: Vector3 = child.position
		if x >= c.x - box.size.x * 0.5 and x <= c.x + box.size.x * 0.5 \
				and z >= c.z - box.size.z * 0.5 \
				and z <= c.z + box.size.z * 0.5:
			return true
	return false


func _captions_leak_nothing() -> bool:
	for row in root.hazards.perception_log:
		var sector := str(row.get("sector", ""))
		if sector == "":
			return false
		var caption := str(row.get("caption", ""))
		for ch in caption:
			if ch.is_valid_int():
				return false
		if caption.contains("D0") or caption.contains("m "):
			return false
	return true


# --- helpers ----------------------------------------------------------

# --- F: the hollow runner --------------------------------------------
#
# The only one of Mina's three whose consequence is not death. Its lesson is
# "sprint is not always the answer", so the whole hazard is the difference
# between two speeds across the same boards — which means a test that only
# ever walks onto it, or only ever runs, proves nothing at all.
#
# `planar_speed()` reads `velocity`, so the speed is set directly here. The
# body's physics is off for the same reason it is off in every other block:
# these checks are about the hazard's decision, not about locomotion.

func _block_f_runner() -> void:
	root.queue_free()
	await get_tree().process_frame
	root = await _spawn_root()
	root.autonomous = false
	root.player.set_physics_process(false)
	var runner := _hazard("hollow_runner")
	_check("the runner is armed, and it is the one in the long hall",
			runner != null and runner.module == "D01_F04_LONG_HALL")

	# WALKING. Start OUTSIDE the tell radius — taken from the hazard rather
	# than typed, so this still approaches from silence if the socket is ever
	# re-authored — and walk in at 1.4 m/s.
	#
	# The iteration budget is derived too. A first version stepped 400 times
	# at 1.4 m/s, which is 4.67 m, from 6.5 m out: the walk stopped short of
	# the boards and the "sprint breaks it" check failed against a hazard that
	# was working correctly. A loop that cannot reach its subject fails in the
	# same shape as a broken hazard.
	var walk_mps := 1.4
	var approach: float = runner.tell_radius + 1.0
	var steps := int(ceil(approach / walk_mps / DT)) + 60
	root.player.velocity = Vector3(walk_mps, 0.0, 0.0)
	_place(runner.position + Vector3(approach, 0.0, 0.0))
	_check("the approach begins in silence, outside the tell",
			runner.tell_started_s < 0.0)
	for i in range(steps):
		_step_toward(runner.position, walk_mps * DT)
		root.hazards.advance_fixed(DT)
		if _flat_distance(runner.position) < 0.05:
			break
	_check("and the walk actually reached the boards",
			_flat_distance(runner.position) <= runner.clearance_radius)
	_check("one dry creak arrives before the boards do",
			runner.tell_started_s >= 0.0)
	_check("walking across the runner crosses it, which is the lesson",
			not runner.contacted and root.hazards.impact_log.is_empty())

	# RUNNING, from the same spot. Nothing moves but the speed.
	var known_before: Vector3 = root.pursuer.last_known_position
	root.pursuer.last_known_position = Vector3(999.0, 0.0, 999.0)
	root.player.velocity = Vector3(runner.break_speed_mps + 0.4, 0.0, 0.0)
	root.hazards.advance_fixed(DT)
	_check("the same boards at a sprint give way",
			runner.contacted and root.hazards.impact_log.size() == 1)
	var rec: Dictionary = root.hazards.impact_log[0]
	_check("breaking a board is not one of the three endings",
			str(rec.outcome) == "" and not root._outcome_committed)
	_check("the boards were still fair about it",
			root.hazards.unfair_impacts().is_empty()
			and float(rec.realised_warning_s)
					>= float(rec.minimum_warning_s))
	# The two halves of what breaking actually DOES.
	_check("the floor gives way under the sprint and the sprint ends",
			root.player._stagger_left > 0.0)
	_check("and the loudest noise in the passage tells the Tenant where",
			root.pursuer.last_known_position.distance_to(
					Vector3(root.player.global_position.x, 0.0,
							root.player.global_position.z)) < 0.05)
	_check("the run is still alive to be lost some other way",
			not root._outcome_committed and known_before != Vector3.INF)
	_end_block("F", 42)


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


func _rect(id: String) -> Array:
	for entry in root.plan.modules:
		if str(entry.id) == id:
			return entry.rect
	return [0.0, 0.0, 0.0, 0.0]


func _at(plan: Dictionary, hid: String, x: float, z: float) -> bool:
	for h in plan.hazards:
		if str(h.id) == hid:
			return absf(float(h.position[0]) - x) < 0.002 \
					and absf(float(h.position[1]) - z) < 0.002
	return false


func _radii(plan: Dictionary, hid: String, clear: float, tell: float,
		warn: float) -> bool:
	for h in plan.hazards:
		if str(h.id) == hid:
			return absf(float(h.clearance_radius_m) - clear) < 0.001 \
					and absf(float(h.tell_radius_m) - tell) < 0.001 \
					and absf(float(h.minimum_warning_s) - warn) < 0.001
	return false


func _place(at: Vector3) -> void:
	root.player.position = Vector3(at.x, root.player.position.y, at.z)


func _flat_distance(to: Vector3) -> float:
	var p := root.player.global_position
	return Vector3(p.x, 0.0, p.z).distance_to(
			Vector3(to.x, 0.0, to.z))


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
		printerr("[N7] BLOCK %s SENTINEL FAIL: %d checks, %d expected"
				% [label, checks, expected_total])
	else:
		print("[N7] block %s complete (%d/%d)" % [label, checks,
				EXPECTED_CHECKS])


func _check(label: String, ok: bool) -> void:
	checks += 1
	if ok:
		print("  [hazard ok] ", label)
	else:
		failures += 1
		printerr("  [HAZARD FAIL] ", label)
