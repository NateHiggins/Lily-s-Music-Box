extends Node3D
## Focused E3 contracts for support-normal tentacles and connected crab gait.

const Tentacle = preload("res://scripts/dream/entity/dream_tentacle_controller.gd")
const Colony = preload("res://scripts/dream/dream_moss_colony.gd")
const Critters = preload("res://scripts/dream/critters/dream_critter_controller.gd")
const Generator = preload("res://scripts/dream/critters/dream_critter_generator.gd")
const Species = preload("res://scripts/dream/critters/dream_critter_species.gd")

var checks := 0
var failures := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var frames := [
		{"name": "floor", "normal": Vector3.UP},
		{"name": "wall", "normal": Vector3.RIGHT},
		{"name": "ceiling", "normal": Vector3.DOWN},
		{"name": "prop", "normal": Vector3(0.35, 0.82, 0.45).normalized()},
	]
	for row in frames:
		var normal: Vector3 = row.normal
		var at := Vector3(frames.find(row) * 3.0, 0.0, 0.0)
		var tangent := Vector3.UP - normal * normal.dot(Vector3.UP)
		if tangent.length_squared() < 0.01: tangent = Vector3.FORWARD
		var colony = Colony.new(); colony.configure(100 + frames.find(row), 7711)
		colony.seed_at(at + tangent.normalized() * 0.24)
		var target := at + normal * 0.72 + tangent.normalized() * 0.35
		var tentacle = Tentacle.new(); add_child(tentacle)
		tentacle.setup(null, 0, at, normal, null,
				[{"aabb": AABB(target - Vector3.ONE * 0.12, Vector3.ONE * 0.24),
				"name": "profiled_target", "node": null}], 8800 + frames.find(row), String(row.name))
		tentacle.bind_ecology(colony, {}, Colony.OrganismClass.PALPATOR)
		for _frame in 900: tentacle._tick(1.0 / 60.0)
		var root_vector: Vector3 = tentacle.anchor - tentacle.rig.anchor
		_check("%s root remains behind its support plane" % row.name,
				root_vector.normalized().dot(normal) > 0.999)
		_check("%s emergence uses an orthonormal local frame" % row.name,
				absf(tentacle.support_tangent.dot(normal)) < 0.001
				and tentacle.rig.point_at(0.10).dot(normal) > tentacle.rig.anchor.dot(normal))
		_check("%s exploration tends moss and samples distinct directions" % row.name,
				tentacle.ecology_tended_moss
				and tentacle.exploration_probe_directions.size() >= 3)
		tentacle.queue_free()

	var controller = Critters.new()
	var morph: Dictionary = Generator.generate(Species.Kind.FOLD_CRAB, 4401)
	var crab := {"morph": morph, "pos": Vector3(0.0, float(morph.tall) * 0.5, 0.0),
			"up": Vector3.UP, "fwd": Vector3.FORWARD, "gait": 0.0,
			"moving": true, "leg_state": [], "support_legs": 0,
			"leg_root_gap_max": 0.0}
	var min_support := 99
	var max_stance_slide := 0.0
	var prior_feet: Array[Vector3] = []
	var prior_stance: Array[bool] = []
	for sample in 360:
		crab.gait = float(crab.gait) + 1.0 / 30.0 * float(morph.speed) * 26.0
		controller._advance_crab_gait(crab, 1.0 / 30.0)
		min_support = mini(min_support, int(crab.support_legs))
		var legs: Array = crab.leg_state
		if prior_feet.size() == legs.size():
			for leg_i in legs.size():
				if bool(legs[leg_i].was_stance) and prior_stance[leg_i]:
					max_stance_slide = maxf(max_stance_slide,
							prior_feet[leg_i].distance_to(legs[leg_i].foot))
		prior_feet.clear()
		prior_stance.clear()
		for leg in legs:
			prior_feet.append(leg.foot)
			prior_stance.append(bool(leg.was_stance))
	_check("fold crab owns six-to-eight stable body sockets", crab.leg_state.size() == int(morph.limbs)
			and int(morph.limbs) >= 6 and float(crab.leg_root_gap_max) == 0.0)
	_check("metachronal gait keeps at least three distributed supports", min_support >= 3)
	_check("stance feet remain planted within tolerance (%.2f mm)" % (max_stance_slide * 1000.0),
			max_stance_slide < 0.001)
	_check("fold crab body plan is low and non-orbital", float(morph.length) > float(morph.tall)
			and float(morph.wide) > float(morph.tall) * 0.9)
	_check("E3A manipulators are a bounded attached pair",
			controller.MAX_LIMBS == 8 and controller.MAX_CRITTERS == 12)
	var habituation := {"ecology_last_target_id": "motor", "ecology_repeat_count": 0,
			"ecology_target_id": "", "ecology_target": Vector3.INF}
	var target_colony = Colony.new(); target_colony.configure(992, 7711)
	target_colony.register_route("motor", "motor", [Vector3.ZERO, Vector3.RIGHT])
	controller._select_ecology_target(habituation, target_colony)
	controller._select_ecology_target(habituation, target_colony)
	_check("repeated observable target produces bounded habituation",
			int(habituation.ecology_repeat_count) == 2)
	var coordination = Colony.new(); coordination.configure(991, 7711)
	_check("duplicate purpose reservations are refused while another modality may share",
			coordination.reserve_target("motor", Colony.OrganismClass.PALPATOR, 1)
			and not coordination.reserve_target("motor", Colony.OrganismClass.PALPATOR, 2)
			and coordination.reserve_target("motor", Colony.OrganismClass.VIBRATION_LISTENER, 3))
	for animal_count in [1, 4, 8]:
		var perf_crabs: Array[Dictionary] = []
		for animal_i in animal_count:
			perf_crabs.append({"morph": Generator.generate(Species.Kind.FOLD_CRAB, 5000 + animal_i),
					"pos": Vector3(animal_i * 0.3, 0.08, 0), "up": Vector3.UP,
					"fwd": Vector3.FORWARD, "gait": 0.0, "moving": true,
					"leg_state": [], "support_legs": 0, "leg_root_gap_max": 0.0})
		var perf_start := Time.get_ticks_usec()
		for perf_frame in 300:
			for perf_crab in perf_crabs:
				perf_crab.gait = float(perf_crab.gait) + 0.03
				controller._advance_crab_gait(perf_crab, 1.0 / 60.0)
		var perf_ms := float(Time.get_ticks_usec() - perf_start) / 300.0 / 1000.0
		print("[e3 perf] fold-crab gait %d animal(s): %.4f ms/frame" % [animal_count, perf_ms])

	controller.free(); controller = null; crab.clear(); morph.clear()
	for _frame in 5: await get_tree().process_frame
	print("DREAM ECOLOGY E3 TEST: %s (%d/%d)" % ["PASS" if failures == 0 else "FAIL",
			checks - failures, checks])
	get_tree().quit(failures)


func _check(label: String, ok: bool) -> void:
	checks += 1
	if ok: print("[e3 ok] " + label)
	else:
		failures += 1
		printerr("[E3 FAIL] " + label)
