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
	_finish()


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
