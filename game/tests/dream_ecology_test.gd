extends Node
## §13, §31, §32, §33, §40 — the ecology director and the one-mind reveal.
##     godot --headless --path game res://tests/DreamEcologyTest.tscn
var checks := 0
var failures := 0
var root: Node3D


func _ready() -> void:
	OS.set_environment("DAYNIGHT", "0")
	OS.set_environment("ENCROACH_FORCE", "mina:0.9")
	OS.set_environment("LIVING_ALL", "1")
	OS.set_environment("DREAM_HERO", "1")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	for case_id in RealityCases.definitions:
		RealityState.ensure_case(case_id,
				str(RealityCases.definitions[case_id].get("resident_id", "")))
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	call_deferred("_run")


func _run() -> void:
	await get_tree().create_timer(14.0).timeout
	var enc: Node = root.get("apartment_encroachment")
	var dir: DreamEcologyDirector = enc.get("ecology")
	var margin = enc.get("margin")
	var critters = enc.get("critters")
	var hero = enc.get("hero")
	_check("the encroachment owns an ecology director", dir != null)
	if dir == null:
		return _finish()
	_check("it can see all three levels",
			dir.margin != null and dir.critters != null and dir.hero != null)

	# --- §32/§33: STATES BIAS, THEY DO NOT COMMAND -----------------------
	var seen_states := {}
	for s in DreamEcologyDirector.State.values():
		dir.state = s
		var b: Dictionary = dir.bias()
		seen_states[dir.state_name()] = b
		_check("%s biases behaviour without commanding it" % dir.state_name(),
				b.has("move") and b.has("orient") and float(b.move) > 0.0)
	_check("watching favours orientation over locomotion",
			float(seen_states["watching"].orient) > float(seen_states["watching"].move))
	_check("foraging favours contact",
			float(seen_states["foraging"].contact) > float(seen_states["curious"].contact))
	dir.state = DreamEcologyDirector.State.CURIOUS

	# --- §33: NORMALLY, NOBODY IS SYNCHRONISED ---------------------------
	var acts := {}
	for p in margin.palps:
		acts[int(p.act)] = true
	print("[ecology] before: %d palps doing %d different things, %d critters"
			% [margin.palps.size(), acts.size(), critters.critters.size()])
	_check("normally the ecology is many agents, not one (%d behaviours)"
			% acts.size(), acts.size() >= 3)
	_check("there are enough agents for the reveal to mean anything (%d + %d)"
			% [margin.palps.size(), critters.critters.size()],
			margin.palps.size() >= 8 and critters.critters.size() >= 2)

	# --- §32: THE BIASES ARE ACTUALLY CONSUMED ---------------------------
	# A director whose states are read by nobody is decoration. Measured by
	# driving the area to opposite extremes and watching how far the critters
	# actually travel.
	_check("the margin and critters can see the director",
			margin.director != null and critters.director != null)
	var travelled := {}
	var results := {}
	for pair in [[DreamEcologyDirector.State.DORMANT, "dormant"],
			[DreamEcologyDirector.State.FORAGING, "foraging"]]:
		dir.state = int(pair[0])
		dir.state_clock = 0.0
		travelled.clear()
		for c in critters.critters:
			travelled[int(c.id)] = float(c.get("walked", 0.0))
		var total := 0.0
		for probe in 24:
			await get_tree().create_timer(0.25).timeout
			dir.state = int(pair[0])     # hold it there against the drift
		# Their own locomotion only. Straight-line displacement also counts
		# being shoved by a palp and fleeing the hero, which the move bias
		# does not govern -- that pollution pushed dormant travel from 0.48 m
		# to 0.79 m and the check began failing for a reason unrelated to it.
		for c in critters.critters:
			if travelled.has(int(c.id)):
				total += maxf(0.0, float(c.get("walked", 0.0))
						- float(travelled[int(c.id)]))
		results[String(pair[1])] = total
	print("[ecology] travelled while dormant %.3f m, while foraging %.3f m"
			% [results["dormant"], results["foraging"]])
	_check("§32 the area state changes what actually happens (%.2f vs %.2f m)"
			% [results["dormant"], results["foraging"]],
			results["foraging"] > results["dormant"] * 1.3)
	dir.state = DreamEcologyDirector.State.CURIOUS

	# --- THE PLAYER'S OWN HAND ------------------------------------------
	# Owner direction: this fires whenever the player modifies the
	# environment. Test the WHOLE CHAIN -- the player's signal, the director's
	# gate, the three levels reacting -- not just that a function exists.
	var player = root.get("player")
	_check("the player emits world_modified", player != null
			and player.has_signal("world_modified"))
	if player != null and player.has_signal("world_modified"):
		var connected: bool = player.world_modified.is_connected(
				dir.on_world_modified)
		_check("the ecology director is listening to it", connected)
		var somewhere := Vector3(-9.2, 4.4, 3.6)
		player.world_modified.emit(somewhere, "test_door")
		await get_tree().process_frame
		_check("opening something seizes the ecology",
				dir.attending != Vector3.INF)
		_check("and it looks at what was touched",
				dir.attending.distance_to(somewhere) < 0.01)
		# §40 — rare enough to stay meaningful. A door opened ten times in ten
		# seconds is one event, not ten.
		var held: Vector3 = dir.attending
		player.world_modified.emit(Vector3(-11.0, 4.4, 2.0), "test_door_again")
		await get_tree().process_frame
		_check("a second modification does not re-seize mid-event",
				dir.attending == held)
		# Let the event finish so the rest of the test starts clean.
		for _w in 40:
			await get_tree().create_timer(0.25).timeout
			if dir.attending == Vector3.INF:
				break
		_check("the event ends on its own", dir.attending == Vector3.INF)
		player.world_modified.emit(Vector3(-9.0, 4.4, 3.0), "immediately_after")
		await get_tree().process_frame
		_check("§40 and it will not fire again straight away (cooldown)",
				dir.attending == Vector3.INF)

	# --- §13/§40: THE SNAP -----------------------------------------------
	# "At the same instant" is the whole beat, so it is measured on the very
	# next frame rather than after a settling period.
	var at := Vector3(-9.0, 4.5, 3.5)
	# HOLD THE POPULATION STILL FOR THE MEASUREMENT. The margin spawns
	# continuously, so comparing a seized count against a count taken a moment
	# earlier is a race -- and waiting longer made it worse, because waiting
	# is exactly what gives it time to spawn. The question is not "were the
	# palps that existed a moment ago seized" but "is every palp alive right
	# now attending", which is what the beat requires.
	margin.frozen = true
	await get_tree().physics_frame
	dir.seize_attention(at)
	await get_tree().process_frame
	var palps_before: int = margin.palps.size()
	var critters_before: int = critters.critters.size()
	var held_palps := 0
	for p in margin.palps:
		if p.attend_override != Vector3.INF:
			held_palps += 1
	var held_critters := 0
	for c in critters.critters:
		if c.attend_override != Vector3.INF:
			held_critters += 1
	print("[ecology] snap: %d/%d palps, %d/%d critters, hero %s"
			% [held_palps, palps_before, held_critters, critters_before,
			hero.attention_override != Vector3.INF])
	_check("§40 the snap is TOTAL: every palp is seized (%d/%d)"
			% [held_palps, palps_before], held_palps == palps_before)
	_check("every critter too (%d/%d)" % [held_critters, critters_before],
			held_critters == critters_before)
	_check("and the hero", hero.attention_override != Vector3.INF)
	_check("all of them are looking at the SAME point",
			margin.palps.is_empty() or margin.palps[0].attend_override == at)
	margin.frozen = false

	# --- §13: AND THE RELEASE IS ASYNCHRONOUS ----------------------------
	# A coordinated release would read as a machine switching off rather than
	# as attention lapsing, so the individuals must let go at different times.
	var release_times := {}
	var t := 0.0
	for probe in 90:
		await get_tree().create_timer(0.1).timeout
		t += 0.1
		for p in margin.palps:
			var id: int = int(p.id)
			var ov: Vector3 = p.get("attend_override", Vector3.INF)
			if ov == Vector3.INF and not release_times.has(id):
				release_times[id] = t
		if dir.attending == Vector3.INF:
			break
	var times: Array = release_times.values()
	times.sort()
	var spread := 0.0
	if times.size() >= 2:
		spread = float(times[times.size() - 1]) - float(times[0])
	print("[ecology] %d released across %.2f s" % [times.size(), spread])
	_check("individuals let go at different times (%d over %.2f s)"
			% [times.size(), spread], times.size() >= 3 and spread > 0.4)
	_check("the whole event ends and autonomy returns",
			dir.attending == Vector3.INF)
	print("[ecology] %s" % [dir.census()])
	await _hero_touches_an_animal(margin, critters, hero)
	_finish()


## §22 — THE HERO'S CLUB TOUCHES AN ANIMAL AND THE ANIMAL ANSWERS.
##
## CONSTRUCTED, NOT WAITED FOR. The beat needs a critter within 18 cm of the
## club at the moment the creature is minding it, which in an unforced run is
## a coincidence of two independent wanderings -- an assertion that waits for
## it is an assertion that fails on the days it does not happen. So the
## situation is built: an animal is placed against the club and the state is
## entered by hand. What is under test is what the systems then do, which is
## the part that would be broken by a real defect.
func _hero_touches_an_animal(margin, critters, hero) -> void:
	if critters == null or hero == null or critters.critters.is_empty():
		_check("§22 there is an animal and a hero to test with", false)
		return
	# --- THE PUSH ITSELF, ON AN ANIMAL THAT IS ACTUALLY STANDING SOMEWHERE ---
	#
	# Tested where the critter already is, rather than somewhere convenient.
	# A nudge is re-seated by a ray cast down at the destination, so an animal
	# moved into the middle of a room first has nothing to be nudged along --
	# the first version of this test put one at the club, which is out in the
	# air, and read a working push as a broken one. The push direction is
	# taken tangent to the animal's own surface for the same reason.
	var c: Dictionary = critters.critters[0]
	c.unfold = 0.0
	var before: Vector3 = c.pos
	var found: Dictionary = critters.nudged_by_hero(
			c.pos, (c.pos as Vector3) - (c.fwd as Vector3) * 0.12, 0.2)
	_check("§22 the club finds the animal nearest what it is minding",
			not found.is_empty())
	_check("§22 and the animal answers by unfolding its sensory structures (%.2f)"
			% float(c.get("unfold", 0.0)), float(c.get("unfold", 0.0)) > 0.5)
	_check("§22 the nudge is a real displacement, not an animation (%.1f mm)"
			% (before.distance_to(c.pos) * 1000.0),
			before.distance_to(c.pos) > 0.0002)

	# --- AND THE HERO ACTUALLY REACHES FOR IT --------------------------------
	var club: Vector3 = hero.tip_world()
	c.pos = club
	hero._minding = c.pos
	hero._nudged_one = false
	hero.state = 16                       # INTERACT_CRITTER
	hero.state_clock = 0.0
	var was: int = int(hero.nudged_critters)
	for _f in 30:
		await get_tree().process_frame
		if int(hero.nudged_critters) > was:
			break
	_check("§22 the hero's club actually nudges the animal it is minding",
			int(hero.nudged_critters) > was)
	# ONE PER MEETING. A club resting against an animal is not nudging it
	# sixty times a second, and a counter that says it is would make the
	# rarest interaction in the ecology look like a machine gun.
	var after_first: int = int(hero.nudged_critters)
	for _f in 20:
		await get_tree().process_frame
	_check("§22 and it happens once per meeting, not once per frame (%d)"
			% (int(hero.nudged_critters) - after_first),
			int(hero.nudged_critters) == after_first)
	# CUT THE HERO OFF FROM THE MARGIN BEFORE MEASURING WHAT IT LEFT THERE.
	#
	# What follows is a test of the margin's own timer, and the hero is the
	# only thing that starts one. Left connected it goes on turning appendages
	# throughout the measurement -- so the population being counted is not the
	# population that was marked, and palps that had been looking for half a
	# second were reported as palps that could not stop. Their look_left was
	# counting down perfectly normally the whole time.
	#
	# This is the third form of this check. It began as "the field decrements
	# within two frames", which measured a race and reported two identical
	# appendages differently in the same frame. What a caller can depend on is
	# that a look expires, so that is what is asserted, over a fixed batch
	# that nothing is adding to.
	hero.critters = null
	hero._minding = Vector3.INF
	hero.margin = null
	if margin != null and not margin.palps.is_empty():
		# WHETHER THE NEIGHBOURS CAN TURN, tested at a palp that is definitely
		# in range. The margin may legitimately have nobody within ninety
		# centimetres of wherever the club happens to be, and an assertion
		# about the club's actual surroundings would be an assertion about
		# where two wanderings met.
		# From a clean slate, so what is counted afterwards is only what this
		# call turned.
		for p in margin.palps:
			p.attend_override = Vector3.INF
			p.local_look = false
			p.look_left = 0.0
		var witness: Dictionary = margin.palps[0]
		var turned: int = margin.orient_nearby(witness.anchor, 0.9)
		_check("§22 nearby palps orient toward the interaction (%d turned)"
				% turned, turned >= 1
				and witness.get("attend_override", Vector3.INF) != Vector3.INF)
		# LOOKS EXPIRE. That is the invariant worth holding, and it is the one
		# stated as the reason the timer exists at all -- an appendage must not
		# be left staring at an old event for the rest of its life.
		#
		# Asserted by waiting out the longest possible look rather than by
		# watching a field decrement over two frames. The frame-level version
		# was a measurement of a race and read as one: two identical
		# appendages reported differently in the same frame, with nothing to
		# distinguish them in either. What a caller can actually depend on is
		# that the look is gone a moment later, and that is what a defect here
		# would break.
		var watched_ids := {}
		for p in margin.palps:
			if bool(p.get("local_look", false)):
				watched_ids[int(p.id)] = true
		# WAITED IN THE CLOCK THE TIMER ACTUALLY RUNS ON. The look counts down
		# in _physics_process, and this scene is heavy enough headless that
		# physics falls behind the wall clock -- so a 3.6 second real-time
		# wait delivered appreciably less than 3.6 seconds of margin time, and
		# the appendages left looking were simply the ones that had drawn the
		# longest looks. Their look_left was counting down correctly the whole
		# time, which is why every earlier form of this check reported a
		# different arbitrary subset.
		#
		# The longest look is 1.4 + curiosity * 1.6, so 3.0 s at most. The
		# budget is far larger than that in frames, because the margin does not
		# advance on every physics frame -- it is one node in a loaded building
		# and its own step is gated -- so frames are an upper bound on elapsed
		# margin time, not a measure of it. The loop stops the moment the batch
		# is clear, so the budget only costs anything when something is
		# genuinely wrong, which is the case it exists for.
		for _f in 900:
			await get_tree().physics_frame
			var any := false
			for p in margin.palps:
				if watched_ids.has(int(p.id)) and bool(p.get("local_look", false)):
					any = true
					break
			if not any:
				break
		var stuck := 0
		for p in margin.palps:
			if watched_ids.has(int(p.id)) and bool(p.get("local_look", false)):
				stuck += 1
		_check("§22 a local look expires instead of staring forever (%d of %d still looking)"
				% [stuck, watched_ids.size()], stuck == 0)
	print("[ecology] hero %s" % [hero.census()])


func _finish() -> void:
	print("DREAM ECOLOGY TEST: %s (%d/%d)" % ["PASS" if failures == 0 else "FAIL",
			checks - failures, checks])
	get_tree().quit(failures)


func _check(label: String, ok: bool) -> void:
	checks += 1
	if ok:
		print("[ecology ok] " + label)
	else:
		failures += 1
		printerr("[ECOLOGY FAIL] " + label)
