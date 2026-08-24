extends Node
## LC-1: pure accelerated stage and environmental reproduction contract.

const Lifecycle = preload("res://scripts/dream/dream_organelle_lifecycle.gd")

var checks := 0
var failures := 0


func _ready() -> void:
	_prove_stage_order()
	_prove_environmental_reproduction()
	_prove_accelerated_death()
	print("DREAM ORGANELLE LIFECYCLE TEST: %s (%d/%d)" % [
			"PASS" if failures == 0 else "FAIL", checks - failures, checks])
	get_tree().quit(failures)


func _prove_stage_order() -> void:
	var expected := ["folded", "bud", "juvenile", "mature", "exchange",
			"senescent", "shed", "stain"]
	var seen: Array[String] = []
	for boundary in [0.0, 0.08, 0.18, 0.38, 0.65, 0.78, 0.90, 0.97]:
		var stage: int = Lifecycle.stage_at(boundary)
		seen.append(Lifecycle.stage_name(stage))
		_check(Lifecycle.anatomy_scale(stage) == 1.0,
				"%s keeps complete anatomy" % Lifecycle.stage_name(stage))
	_check(seen == expected, "the eight life stages remain ordered")


func _prove_environmental_reproduction() -> void:
	var asexual := Lifecycle.reproduction_for({
		"food": 0.82, "ether": 0.24, "density": 0.22,
		"same_compatibility": 0.20, "cross_compatibility": 0.20,
	})
	var sexual := Lifecycle.reproduction_for({
		"food": 0.55, "ether": 0.72, "density": 0.66,
		"same_compatibility": 0.78, "cross_compatibility": 0.30,
	})
	var pansexual := Lifecycle.reproduction_for({
		"food": 0.48, "ether": 0.58, "density": 0.28, "diversity": 0.82,
		"same_compatibility": 0.18, "cross_compatibility": 0.88,
	})
	var quiet := Lifecycle.reproduction_for({
		"food": 0.18, "ether": 0.12, "density": 0.18,
		"same_compatibility": 0.20, "cross_compatibility": 0.20,
	})
	_check([Lifecycle.reproduction_name(asexual),
			Lifecycle.reproduction_name(sexual),
			Lifecycle.reproduction_name(pansexual),
			Lifecycle.reproduction_name(quiet)]
			== ["asexual", "sexual", "pansexual", "quiescent"],
			"food, ether and compatibility select all four modes")


func _prove_accelerated_death() -> void:
	var environment := {
		"food": 0.80, "ether": 0.62, "density": 0.68,
		"same_compatibility": 0.76, "cross_compatibility": 0.52,
		"stress": 0.10,
	}
	var lifespan: float = Lifecycle.life_seconds(environment)
	_check(lifespan >= Lifecycle.MIN_LIFE_S
			and lifespan <= Lifecycle.MAX_LIFE_S,
			"a complete small-organ life stays inside 45–150 seconds")
	var before := Lifecycle.new_record(0.96)
	var after := Lifecycle.advance(before, environment, lifespan * 0.08)
	_check(int(after.deaths) == 1 and int(after.stains) == 1,
			"crossing death leaves one persistent stain record")
	_check(int(after.births) == 1 and int(after.generation) == 1
			and int(after.reproduction) == Lifecycle.Reproduction.SEXUAL,
			"a permitted exchange recruits the next cohort")
	_check(before == Lifecycle.new_record(0.96),
			"classification advances a copy, not the caller's record")


func _check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("  [lifecycle ok] ", label)
	else:
		failures += 1
		printerr("  [LIFECYCLE FAIL] ", label)
