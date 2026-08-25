extends Node
## LC-6A: the shared lifecycle reaches margin palps without replacing their
## morphology or §12's branch/cilia work sequence.

const Lifecycle = preload("res://scripts/dream/dream_organelle_lifecycle.gd")

var checks := 0
var failures := 0
var margin: DreamMarginController
var renderer: DreamPalpRenderer


func _ready() -> void:
	margin = DreamMarginController.new()
	add_child(margin)
	margin.setup(null, 0x6C6A)
	margin.frozen = true
	margin._birth_specific(DreamMarginController.TIER_PRIMARY, Vector3.ZERO,
			Vector3.FORWARD, DreamPalpMorphology.Kind.SOFT_PALP)
	renderer = DreamPalpRenderer.new()
	add_child(renderer)
	renderer.setup(margin)
	_prove_top_level_clock()
	_prove_complete_postures()
	_prove_branch_work_clock()
	_prove_review_override_and_submission()
	_prove_death_memory_and_recruitment()
	print("DREAM MARGIN LIFECYCLE TEST: %s (%d/%d)" % [
			"PASS" if failures == 0 else "FAIL", checks - failures, checks])
	get_tree().quit(failures)


func _palp() -> Dictionary:
	return margin.palps[0]


func _prove_top_level_clock() -> void:
	var p := _palp()
	p.lifecycle_override = -1
	p.life = 100.0
	var progress := [0.04, 0.13, 0.28, 0.515, 0.715, 0.84, 0.935, 0.985]
	for stage in Lifecycle.Stage.values():
		p.age = float(progress[stage]) * p.life
		_check(DreamMarginController.lifecycle_stage_of(p) == stage,
				"owner clock reaches %s" % Lifecycle.stage_name(stage))
		_check(is_equal_approx(float(p.grow), 1.0),
				"%s keeps complete anatomy" % Lifecycle.stage_name(stage))
	_check(p.life >= Lifecycle.MIN_LIFE_S and p.life <= Lifecycle.MAX_LIFE_S,
			"top-level primary life stays inside the shared 45–150 second band")
	# The production birth path—not only the review birth—must use the same
	# full-anatomy and accelerated-life contract.
	margin._birth(DreamMarginController.TIER_SECONDARY, Vector3.RIGHT,
			Vector3.FORWARD)
	var born: Dictionary = margin.palps.back()
	_check(is_equal_approx(float(born.grow), 1.0),
			"production birth begins folded at full anatomy")
	_check(float(born.life) >= DreamMarginController.TIER_LIFE_MIN_S[1]
			and float(born.life) <= DreamMarginController.TIER_LIFE_MAX_S[1],
			"production birth draws from its ruled tier life band")
	margin.palps.pop_back()


func _prove_complete_postures() -> void:
	var p := _palp()
	var progress := [0.04, 0.13, 0.28, 0.515, 0.715, 0.84, 0.935, 0.985]
	var lengths: Array[float] = []
	var outward: Array[float] = []
	for stage in Lifecycle.Stage.values():
		p.age = float(progress[stage]) * p.life
		renderer._lay(0, p)
		var root: Vector3 = renderer._spine[0]
		var tip: Vector3 = renderer._spine[DreamPalpRenderer.JOINTS - 1]
		var reach := tip - root
		lengths.append(reach.length())
		outward.append(reach.normalized().dot(p.normal))
		_check(reach.length() > float(p.morph.length) * 0.42,
				"%s is a full-length posture, not scale-from-zero"
				% Lifecycle.stage_name(stage))
		_check(is_equal_approx(renderer._params[0].x, 1.0),
				"%s submits anatomy scale one" % Lifecycle.stage_name(stage))
	_check(absf(outward[Lifecycle.Stage.FOLDED]) < 0.45
			and absf(outward[Lifecycle.Stage.SHED]) < 0.55,
			"reserve and shed postures lie along the architectural surface")
	_check(outward[Lifecycle.Stage.MATURE] > 0.55
			and outward[Lifecycle.Stage.EXCHANGE] > 0.55,
			"mature and exchange postures reach into playable space")
	_check(lengths.min() / lengths.max() > 0.42,
			"the smallest staged silhouette retains substantial authored reach")


func _prove_branch_work_clock() -> void:
	var branch: Dictionary = _palp().duplicate(true)
	branch.parent = 0
	branch.lifecycle_override = -1
	branch.unfold = 0.0
	branch.folding = false
	branch.task_left = 0.0
	branch.task_done = false
	branch.cilia_out = 0.0
	var seen: Array[String] = []
	for unfold in [0.02, 0.22, 0.62, 1.0]:
		branch.unfold = unfold
		seen.append(Lifecycle.stage_name(
				DreamMarginController.lifecycle_stage_of(branch)))
	branch.cilia_out = 1.0
	seen.append(Lifecycle.stage_name(
			DreamMarginController.lifecycle_stage_of(branch)))
	branch.task_left = 0.5
	seen.append(Lifecycle.stage_name(
			DreamMarginController.lifecycle_stage_of(branch)))
	branch.task_left = 0.0
	branch.task_done = true
	seen.append(Lifecycle.stage_name(
			DreamMarginController.lifecycle_stage_of(branch)))
	branch.folding = true
	seen.append(Lifecycle.stage_name(
			DreamMarginController.lifecycle_stage_of(branch)))
	_check(seen == ["folded", "bud", "juvenile", "mature", "exchange",
			"exchange", "senescent", "shed"],
			"branch lifecycle names the existing unfold/cilia/work/retract order")
	_check(is_equal_approx(float(branch.grow), 1.0),
			"branch work sequence retains full anatomy")


func _prove_review_override_and_submission() -> void:
	var p := _palp()
	p.age = 0.0
	p.lifecycle_override = Lifecycle.Stage.MATURE
	_check(DreamMarginController.lifecycle_stage_of(p) == Lifecycle.Stage.MATURE,
			"review arrangements remain deliberately mature")
	renderer._lay(0, p)
	_check(is_equal_approx(renderer._branch[0].z,
			float(Lifecycle.Stage.MATURE) / 7.0),
			"the spare packed channel carries lifecycle stage to the shader")
	var census := renderer.census()
	_check(int(census.surfaces) == 1 and renderer.get_child_count() == 1,
			"lifecycle posture adds no draw owner")
	_check(find_children("*", "CollisionObject3D", true, false).is_empty()
			and find_children("*", "Light3D", true, false).is_empty(),
			"lifecycle presentation adds no collision or light nodes")


func _prove_death_memory_and_recruitment() -> void:
	# One real top-level expiry records full anatomy before removal.
	var p: Dictionary = _palp()
	p.lifecycle_override = -1
	p.age = p.life - 0.01
	margin._age(0.02)
	_check(margin.impressions.size() == 1,
			"top-level withdrawal leaves one owner-local anatomical memory")
	var stain: Dictionary = margin.impressions[0]
	_check(int(stain.lifecycle_override) == Lifecycle.Stage.STAIN
			and is_equal_approx(float(stain.grow), 1.0),
			"the memory is a full-anatomy stain posture")
	_check(margin.palps.is_empty() and int(stain.last_death_id) == 0,
			"the stain survives removal of the organ it remembers")
	renderer._lay(0, stain)
	_check(float(renderer._params[0].y) > 0.0
			and float(renderer._params[0].y) < float(stain.morph.base_radius) * 0.30,
			"the terminal section compresses into the wall without reaching zero")
	_check(margin.impressions.size() <= DreamMarginController.MAX_IMPRESSIONS,
			"visit memory has an explicit bound")

	_check(Lifecycle.reproduction_for({"food": 0.8, "ether": 0.1,
			"density": 0.2}) == Lifecycle.Reproduction.ASEXUAL,
			"rich sparse tissue selects asexual recruitment")
	_check(Lifecycle.reproduction_for({"ether": 0.8, "density": 0.7,
			"same_compatibility": 0.8}) == Lifecycle.Reproduction.SEXUAL,
			"ether-rich compatible tissue selects sexual recruitment")
	_check(Lifecycle.reproduction_for({"ether": 0.5, "density": 0.7,
			"cross_compatibility": 0.8, "diversity": 0.8})
			== Lifecycle.Reproduction.PANSEXUAL,
			"heterogeneous tissue selects pansexual recruitment")
	_check(Lifecycle.reproduction_for({}) == Lifecycle.Reproduction.QUIESCENT,
			"an unsupported vacancy remains quiet")

	# A recruited descendant keeps the receiving organ's function and tier.
	margin._pending_recruits.append({"tier": 0, "kind": int(stain.morph.kind),
			"seed": 99173, "anchor": stain.anchor, "normal": stain.normal,
			"mode": Lifecycle.Reproduction.PANSEXUAL, "generation": 1})
	margin._retired_slots[0] = 1
	var request := margin._take_recruit(0)
	margin._birth(0, request.anchor, request.normal, request)
	var child: Dictionary = margin.palps.back()
	_check(int(child.tier) == int(stain.tier)
			and int(child.morph.kind) == int(stain.morph.kind),
			"recombination retains tier and receiving organ function")
	_check(int(child.seed) != int(stain.seed) and int(child.generation) == 1,
			"recombination changes only bounded seeded variation")

	# Stains consume reserved slots inside the same surface.
	renderer._process(0.0)
	var rc := renderer.census()
	_check(int(rc.stains) == 1 and int(rc.surfaces) == 1,
			"a stain remains drawable inside the existing one-surface budget")
	_check(find_children("*", "CollisionObject3D", true, false).is_empty()
			and find_children("*", "Light3D", true, false).is_empty(),
			"death memory adds no collision or light owner")

	# Repeated death at one anatomical address thickens one memory; distinct
	# addresses evict oldest-first at the explicit visit bound.
	var same_place := stain.duplicate(true)
	same_place.id = 101
	margin._remember_death(same_place)
	_check(margin.impressions.size() == 1
			and int(margin.impressions[0].deaths) == 2,
			"repeated withdrawal in one cell coalesces into a deeper stain")
	for index in DreamMarginController.MAX_IMPRESSIONS + 2:
		var elsewhere := stain.duplicate(true)
		elsewhere.id = 200 + index
		elsewhere.anchor = Vector3(1.0 + float(index), 0.0, 0.0)
		margin._remember_death(elsewhere)
	_check(margin.impressions.size() == DreamMarginController.MAX_IMPRESSIONS,
			"distinct memories cannot exceed the visit cap")
	_check(int(margin.impressions[0].last_death_id) == 202,
			"overflow evicts oldest records deterministically")
	renderer._process(0.0)
	_check(int(renderer.census().stains) == DreamPalpRenderer.MAX_STAIN_SLOTS,
			"the nearest bounded stain subset receives the reserved mesh slots")


func _check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("  [margin lifecycle ok] ", label)
	else:
		failures += 1
		printerr("  [MARGIN LIFECYCLE FAIL] ", label)
