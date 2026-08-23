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
