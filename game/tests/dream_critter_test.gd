extends Node
## Ecology architecture §16, §17, §24, §38 — the first three species.
##     godot --headless --path game res://tests/DreamCritterTest.tscn
var checks := 0
var failures := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var S := DreamCritterSpecies
	var G := DreamCritterGenerator
	var kinds: Array = [S.Kind.SEAM_GRAZER, S.Kind.CRYSTAL_LISTENER, S.Kind.FOLD_CRAB]

	# --- §16: SPECIES IDENTITY COMES BEFORE VARIETY ----------------------
	# Every individual a species can generate must still be that species. The
	# rules are executable, so a generator bug fails a test rather than merely
	# looking wrong to whoever happens to be watching.
	var violations := 0
	var first_violation := ""
	for kind in kinds:
		for i in 400:
			var m: Dictionary = G.generate(kind, 9000 + i * 37 + kind * 101)
			var bad: String = S.violates_identity(kind, m)
			if bad != "":
				violations += 1
				if first_violation == "":
					first_violation = "%s: %s" % [S.name_of(kind), bad]
	_check("1200 individuals across 3 species, none violates its own species "
			+ "rules (%d violations%s)" % [violations,
			"" if first_violation == "" else " — " + first_violation],
			violations == 0)

	# --- §38: ten of one species, all clearly the same, several memorable --
	var pack: Array = []
	for i in 10:
		pack.append(G.generate(S.Kind.SEAM_GRAZER, 4400 + i * 13))
	var within_max := 0.0
	var within_min := 9.0
	for i in pack.size():
		for j in range(i + 1, pack.size()):
			var d: float = G.visual_distance(pack[i], pack[j])
			within_max = maxf(within_max, d)
			within_min = minf(within_min, d)
	print("[critter] within-species spread %.3f .. %.3f" % [within_min, within_max])
	_check("ten of one species are individually distinguishable (max %.2f)"
			% within_max, within_max > 0.5)

	# --- and three species nobody should confuse -------------------------
	var between_min := 9.0
	for a in kinds:
		for b in kinds:
			if a >= b:
				continue
			for i in 12:
				var x: Dictionary = G.generate(a, 700 + i * 29)
				var y: Dictionary = G.generate(b, 700 + i * 29)
				between_min = minf(between_min, G.visual_distance(x, y))
	print("[critter] closest pair from DIFFERENT species: %.3f" % between_min)
	_check("species do not overlap: the closest cross-species pair (%.2f) is "
			% between_min + "further apart than the furthest same-species pair "
			+ "(%.2f)" % within_max, between_min > within_max)

	# --- §26: MATERIAL VARIES, INSIDE THE COLOUR LANGUAGE ----------------
	# "Avoid arbitrary hue randomization. Everything remains within Dream
	# color language." So the test is two-sided: individuals must differ, AND
	# none may leave the bounds. A generator that produced a green critter
	# would pass a variation test and fail the brief.
	var hues: Array = []
	var wets: Array = []
	var out_of_language := 0
	for i in 500:
		var m: Dictionary = G.generate(S.Kind.CRYSTAL_LISTENER, 5000 + i)
		hues.append(float(m.hue_bias))
		wets.append(float(m.wetness))
		for key in ["hue_bias", "perfusion", "wetness", "iridescence",
				"skin_coarse", "alloy_tint"]:
			var v: float = float(m[key])
			if v < 0.0 or v > 1.6:
				out_of_language += 1
	print("[critter] hue bias %.2f..%.2f, wetness %.2f..%.2f across 500"
			% [hues.min(), hues.max(), wets.min(), wets.max()])
	_check("individuals differ in material balance (hue spread %.2f)"
			% (hues.max() - hues.min()), hues.max() - hues.min() > 0.5)
	_check("§26 nothing leaves the Dream colour language (%d strays)"
			% out_of_language, out_of_language == 0)

	# --- §20: two of a species walk differently --------------------------
	var a1: Dictionary = G.generate(S.Kind.FOLD_CRAB, 8801)
	var a2: Dictionary = G.generate(S.Kind.FOLD_CRAB, 8802)
	var gait_differs := 0
	for key in ["lead_limb", "pause_bias", "turn_bias", "gait_phase",
			"gait_asymmetry", "stride_phase", "body_bob"]:
		if not is_equal_approx(float(a1[key]), float(a2[key])):
			gait_differs += 1
	print("[critter] two crabs differ in %d of 7 movement properties" % gait_differs)
	_check("§20 two of a species move differently in more than speed (%d/7)"
			% gait_differs, gait_differs >= 5)

	# --- §24: one impossible rule each, and only one ---------------------
	var laws := {}
	for kind in kinds:
		var m: Dictionary = G.generate(kind, 55)
		laws[String(m.law)] = true
		_check("%s carries a thesis and exactly one law" % S.name_of(kind),
				String(m.thesis).length() > 20 and String(m.law).length() > 3)
	_check("each species has its OWN law, not a shared effect (%d laws / 3)"
			% laws.size(), laws.size() == 3)

	# --- §17: rare morphs exist and are actually rare --------------------
	var rare := 0
	var great := 0
	for i in 2000:
		var m: Dictionary = G.generate(S.Kind.SEAM_GRAZER, 20000 + i)
		if String(m.morph) == "extra_feelers":
			rare += 1
		elif String(m.morph) == "great_crystal":
			great += 1
	print("[critter] in 2000: %d extra-feelered, %d great-crystal" % [rare, great])
	_check("rare morphs occur (%d) and stay rare (%.1f%%)"
			% [rare, 100.0 * rare / 2000.0], rare > 20 and rare < 200)
	_check("very rare morphs are very rare (%d in 2000)" % great,
			great >= 1 and great < 60)

	# --- §30: the same seed is always the same individual ----------------
	var one: Dictionary = G.generate(S.Kind.FOLD_CRAB, 31337)
	var two: Dictionary = G.generate(S.Kind.FOLD_CRAB, 31337)
	_check("a seed always produces the same individual",
			is_equal_approx(float(one.length), float(two.length))
			and int(one.limbs) == int(two.limbs)
			and is_equal_approx(float(one.gold), float(two.gold)))
	await _in_world()
	_finish()


## They must actually live somewhere. §21: "This turns the wall into a
## functioning biome" — which requires being on the wall.
func _in_world() -> void:
	OS.set_environment("DAYNIGHT", "0")
	OS.set_environment("ENCROACH_FORCE", "mina:0.9")
	OS.set_environment("LIVING_ALL", "1")
	# §22 needs the hero present to test whether critters react to it.
	OS.set_environment("DREAM_HERO", "1")
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	for case_id in RealityCases.definitions:
		RealityState.ensure_case(case_id,
				str(RealityCases.definitions[case_id].get("resident_id", "")))
	var root: Node3D = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	await get_tree().create_timer(12.0).timeout
	var enc: Node = root.get("apartment_encroachment")
	var ctrl = enc.get("critters") if enc != null else null
	_check("the encroachment owns a critter controller", ctrl != null)
	if ctrl == null:
		return
	var start: Dictionary = {}
	for c in ctrl.critters:
		start[int(c.id)] = c.pos
	await get_tree().create_timer(9.0).timeout
	var cen: Dictionary = ctrl.census()
	print("[critter] in world: %s" % [cen])
	_check("individuals are born on surfaces (%d live, %d born)"
			% [int(cen.live), int(cen.born)], int(cen.born) >= 2)
	_check("more than one species is present (%d)" % int(cen.species.size()),
			int(cen.species.size()) >= 2)
	# They must MOVE, and they must stay attached to architecture.
	var moved := 0.0
	var airborne := 0
	var space := get_viewport().find_world_3d().direct_space_state
	for c in ctrl.critters:
		if start.has(int(c.id)):
			moved = maxf(moved, (c.pos as Vector3).distance_to(start[int(c.id)]))
		# A critter on a surface has that surface just beneath it.
		var q := PhysicsRayQueryParameters3D.create(
				(c.pos as Vector3) + (c.up as Vector3) * 0.05,
				(c.pos as Vector3) - (c.up as Vector3) * 0.25)
		if space.intersect_ray(q).is_empty():
			airborne += 1
	print("[critter] furthest travelled %.3f m, %d of %d airborne"
			% [moved, airborne, ctrl.critters.size()])
	_check("they walk (furthest %.3f m in 9 s)" % moved, moved > 0.02)
	_check("they stay on the architecture (%d airborne)" % airborne, airborne == 0)
	_check("the whole population draws in one mesh",
			ctrl.get_node_or_null("Critters") != null)

	# --- §24: THE LAWS ARE ENACTED, NOT DECLARED -------------------------
	# A species whose impossible rule exists only in a dictionary is not yet
	# a Dream animal. Each of these watches for the creature DOING the thing.
	var twin_seen := false
	var twin_gap := 0.0
	var spin_start := {}
	var spin_moved := 0.0
	var fold_seen := false
	var fold_root_moved := 0.0
	var fold_feet: Dictionary = {}
	for c in ctrl.critters:
		if int(c.morph.kind) == DreamCritterSpecies.Kind.CRYSTAL_LISTENER:
			spin_start[int(c.id)] = float(c.spin)
	for probe in 60:
		await get_tree().create_timer(0.3).timeout
		for c in ctrl.critters:
			var kind: int = int(c.morph.kind)
			if kind == DreamCritterSpecies.Kind.SEAM_GRAZER and bool(c.twin):
				twin_seen = true
				# The two appearances must be genuinely apart -- on opposite
				# faces -- not coincident.
				twin_gap = maxf(twin_gap,
						(c.pos as Vector3).distance_to(c.twin_pos))
			elif kind == DreamCritterSpecies.Kind.CRYSTAL_LISTENER:
				if spin_start.has(int(c.id)):
					spin_moved = maxf(spin_moved,
							absf(float(c.spin) - float(spin_start[int(c.id)])))
			elif kind == DreamCritterSpecies.Kind.FOLD_CRAB:
				var key := int(c.id)
				if float(c.fold) > 0.25:
					fold_seen = true
					# Within ONE fold event. The first version compared across
					# every event over eighteen seconds, and between them the
					# crab simply walks -- which measured its locomotion, not
					# its law.
					if fold_feet.has(key):
						fold_root_moved = maxf(fold_root_moved,
								(c.pos as Vector3).distance_to(fold_feet[key]))
					else:
						fold_feet[key] = c.pos
				else:
					fold_feet.erase(key)
	print("[critter] laws: twin %s (gap %.3f m), spin advanced %.2f rad, "
			% [twin_seen, twin_gap, spin_moved]
			+ "leg folded %s (body moved %.3f m during it)"
			% [fold_seen, fold_root_moved])
	# Emergent observation only. Whether a grazer WANDERS onto a thin wall in
	# any given twenty seconds is chance, and asserting on chance produces a
	# test that fails for reasons that have nothing to do with the code. The
	# mechanism gets a constructed test below.
	print("[critter] (emergent, not asserted) grazer twinned: %s" % twin_seen)
	_check("crystal listener: its resonator turned (%.2f rad) while its shell "
			% spin_moved + "orientation is never written at all", spin_moved > 0.5)
	_check("fold crab: a leg went shorter than the gap it spans", fold_seen)
	_check("and it did so without the animal moving (%.3f m)" % fold_root_moved,
			fold_root_moved < 0.06)
	# --- §21: THE MARGIN IS HABITAT --------------------------------------
	# "This turns the wall into a functioning biome." A biome is not two
	# populations sharing a wall and ignoring each other.
	var peak_nudged := 0
	var peak_following := 0
	for probe in 50:
		await get_tree().create_timer(0.3).timeout
		var cc: Dictionary = ctrl.census()
		peak_nudged = maxi(peak_nudged, int(cc.get("nudged_by_a_palp", 0)))
		peak_following = maxi(peak_following, int(cc.get("following_a_palp", 0)))
	print("[critter] habitat: %d shoved by a palp, %d following one"
			% [peak_nudged, peak_following])
	_check("critters and the margin share a world rather than ignoring it "
			+ "(%d shoved, %d following)" % [peak_nudged, peak_following],
			peak_nudged + peak_following >= 1)
	# --- §22: THE HERO, AND WHO IS BRAVE ---------------------------------
	# The beat only works if individuals differ: several flee and one remains.
	# §19 already gave every critter a confidence, so this costs no authoring.
	var hero = enc.get("hero")
	_check("the hero is present for the critters to react to", hero != null)
	if hero != null:
		var peak_feel := 0
		var peak_brave := 0
		var hero_noticed := false
		for probe in 40:
			await get_tree().create_timer(0.4).timeout
			var cc: Dictionary = ctrl.census()
			peak_feel = maxi(peak_feel, int(cc.get("feel_hero", 0)))
			peak_brave = maxi(peak_brave, int(cc.get("approaching_hero", 0)))
			if bool(hero.census().get("noticing_a_critter", false)):
				hero_noticed = true
		print("[critter] hero: %d felt it, %d approached anyway, hero noticed one: %s"
				% [peak_feel, peak_brave, hero_noticed])
		print("[critter] (emergent, not asserted) felt hero %d, approached %d, "
				% [peak_feel, peak_brave] + "hero noticed: %s" % hero_noticed)
	await _constructed(ctrl, hero)
	var cen2: Dictionary = ctrl.census()
	print("[critter] %s" % [cen2])


## The mechanisms, tested by BUILDING the situation rather than waiting for
## the simulation to wander into it. Same reasoning as §37's arranged row: a
## rare event observed in a fixed window makes a flaky assertion, and a flaky
## assertion is worse than none because it fails for reasons unrelated to the
## thing it names.
func _constructed(ctrl, hero) -> void:
	# A thin panel, and a seam grazer standing on it.
	var panel := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.4, 1.4, 0.06)      # 6 cm: thin enough to be on both sides
	shape.shape = box
	panel.add_child(shape)
	add_child(panel)
	panel.global_position = Vector3(0.0, 200.0, 0.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var g: Dictionary = ctrl.critters[0]
	for c in ctrl.critters:
		if int(c.morph.kind) == DreamCritterSpecies.Kind.SEAM_GRAZER:
			g = c
			break
	_check("a seam grazer exists to test the mechanism on",
			int(g.morph.kind) == DreamCritterSpecies.Kind.SEAM_GRAZER)
	g.pos = Vector3(0.0, 200.0, 0.03 + float(g.morph.tall) * 0.5)
	g.up = Vector3(0.0, 0.0, 1.0)
	g.fwd = Vector3(1.0, 0.0, 0.0)
	ctrl._apply_law(g, 0.016)
	print("[critter] constructed: twin=%s at %s (body at %s)"
			% [g.twin, g.twin_pos, g.pos])
	_check("§24 seam grazer: on a 6 cm panel it occupies BOTH faces",
			bool(g.twin))
	if bool(g.twin):
		var gap: float = (g.pos as Vector3).distance_to(g.twin_pos)
		_check("its two appearances are on opposite faces (%.3f m apart)" % gap,
				gap > 0.03 and gap < 0.25)
		_check("and it faces one way, not two",
				(g.twin_fwd as Vector3).dot(g.fwd) > 0.5)
	# And the hero notices something alive placed beside it.
	if hero != null:
		var probe: Dictionary = ctrl.critters[0]
		probe.pos = hero.tip_world() + Vector3(0.0, 0.06, 0.0)
		hero._notice_neighbours(0.016)
		_check("§22 the hero notices a critter placed beside its club",
				hero.noticing != Vector3.INF)
	panel.queue_free()


func _finish() -> void:
	print("DREAM CRITTER TEST: %s (%d/%d)" % ["PASS" if failures == 0 else "FAIL",
			checks - failures, checks])
	get_tree().quit(failures)


func _check(label: String, ok: bool) -> void:
	checks += 1
	if ok:
		print("[critter ok] " + label)
	else:
		failures += 1
		printerr("[CRITTER FAIL] " + label)
