extends Node
## E2 presentation/authority contract.

const Colony = preload("res://scripts/dream/dream_moss_colony.gd")
const Renderer = preload("res://scripts/dream/dream_moss_colony_renderer.gd")
const Director = preload("res://scripts/dream/dream_ecology_director.gd")

var checks := 0
var failures := 0


func _ready() -> void:
	var orphan := Renderer.new()
	add_child(orphan)
	orphan._process(0.1)
	_check(not orphan.visible, "no renderer content before a colony exists")
	orphan.queue_free()

	var colony = Colony.new()
	colony.configure(31, 1204)
	var renderer := Renderer.new()
	add_child(renderer)
	renderer.setup(colony)
	var before := colony.deterministic_receipt()
	for _i in 30: renderer._process(1.0 / 60.0)
	_check(before == colony.deterministic_receipt() and not bool(renderer.census().owns_simulation), "renderer owns no simulation state")
	colony.choose_site([{"id": "bench", "position": Vector3.ZERO,
			"reachable": true, "eligible": true, "target_density": 0.8,
			"information": 0.8, "continuity": 0.8, "volume": 0.8}])
	for _i in 50: colony.add_surface_access(1.0)
	var cilium: Dictionary = colony.spawn(Colony.OrganismClass.CILIUM, Vector3.ZERO)
	renderer._process(0.25)
	_check(int(renderer.census().cilia_visible) == 1 and colony._tentacle_count() == 0, "cilia are first visually and logically")
	var pulse_before := int(renderer.census().report_presentations)
	renderer.present_report(Vector3.ONE, 0.0)
	_check(int(renderer.census().report_presentations) == pulse_before, "zero/non-report cannot create information pulse")
	var director := Director.new(); add_child(director); director.setup(1204)
	# Cellular audio has its own dedicated contract; keep this presentation test
	# free of asynchronous stream-loader lifetime so zero-retention is measurable.
	director.cellular_audio.queue_free()
	director.cellular_audio = null
	await get_tree().process_frame
	director.moss_colonies[colony.source_id] = colony
	var report := {"state_signature": "warm", "heat": 0.8, "vibration": 0.7,
			"material_complexity": 0.8, "modalities": ["touch", "heat", "vibration"]}
	var value: float = director.receive_cilium_sample(colony.source_id, int(cilium.id), "motor", Vector3(0.4, 0, 0), report)
	renderer.present_report(Vector3(0.4, 0, 0), value)
	_check(bool(renderer.census().report_visible) and int(renderer.census().report_presentations) == 1, "real typed report alone creates visible pulse")
	colony.register_route("motor", "motor", [Vector3.ZERO, Vector3(0.5, 0, 0)])
	_check(not colony.can_spawn(Colony.OrganismClass.PALPATOR, Vector3(9, 0, 0)), "unsupported visible tentacle remains refused")
	var palp := colony.spawn(Colony.OrganismClass.PALPATOR, Vector3.ZERO, "motor")
	_check(not palp.is_empty() and Colony.CLASS_NAMES[int(palp["class"])] == "palpator", "specialized record carries purpose morphology key")
	palp.ether = 0.20
	_check(colony.update_excursion(palp, Vector3(0.3, 0, 0), 0.2) == "returning", "return presentation state derives from logical return")
	_check(not colony.complex_unlocked(), "complex presentation remains locked before thresholds")
	var phases: Array[String] = []
	colony.disturb(1.0, "test shock"); phases.append(colony.census().phase)
	for _i in 30:
		colony.advance_collapse(0.2)
		var phase: String = colony.census().phase
		if phases[-1] != phase: phases.append(phase)
	_check(phases == ["disturbed", "recalling", "withering", "stained"], "disturbance presentation preserves ordered phases")
	_check(colony.stain_coverage() > 0.0, "stain facts remain in existing colony-to-field submission seam")
	var dirty := colony.stain_coverage()
	_check(is_equal_approx(colony.cleanup(1.0, false), dirty) and colony.cleanup(1.0, true) < dirty, "cleanup presentation requires authorized path")
	var pc: Dictionary = renderer.census()
	_check(int(pc.nodes) <= 6 and int(pc.caps.cilia) == 8 and int(pc.caps.ether_motes) == 24, "pooled presentation remains inside caps")
	var cpu_start := Time.get_ticks_usec()
	for _i in 300: renderer._process(1.0 / 60.0)
	var cpu_ms := float(Time.get_ticks_usec() - cpu_start) / 300.0 / 1000.0
	_check(cpu_ms < 0.35, "colony presentation CPU remains under 0.35 ms (%.3f ms)" % cpu_ms)
	var receipt_a := _receipt(88)
	var receipt_b := _receipt(88)
	_check(receipt_a == receipt_b, "deterministic presentation run produces identical census")

	renderer.queue_free(); director.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(not is_instance_valid(renderer) and not is_instance_valid(director), "teardown retains no presentation nodes")
	call_deferred("_finish")


func _finish() -> void:
	print("DREAM MOSS PRESENTATION TEST: %s (%d/%d)" % ["PASS" if failures == 0 else "FAIL", checks - failures, checks])
	for _frame in 5:
		await get_tree().process_frame
	get_tree().quit(failures)


func _receipt(seed_value: int) -> String:
	var colony = Colony.new(); colony.configure(1, seed_value)
	colony.choose_site([{"id": "a", "position": Vector3.ZERO,
			"reachable": true, "eligible": true, "target_density": 1.0, "information": 1.0}])
	for _i in 12: colony.add_surface_access(0.8)
	return colony.deterministic_receipt()


func _check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("  [moss presentation ok] ", label)
	else:
		failures += 1
		printerr("  [MOSS PRESENTATION FAIL] ", label)
