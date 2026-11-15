extends Node

const State := preload("res://scripts/dream/dream_cellular_state.gd")
const Phenotype := preload("res://scripts/dream/dream_cellular_phenotype.gd")
const Colony := preload("res://scripts/dream/dream_moss_colony.gd")
const Renderer := preload("res://scripts/dream/dream_moss_colony_renderer.gd")

var passed := 0
var total := 0


func _ready() -> void:
	var source := {"ether": 1.4, "information": -0.2, "reporting": 0.7,
			"senescence": 0.4, "cleanup": 0.25}
	var a = State.new(source)
	var b = State.new(source)
	_check(a.signature() == b.signature(), "state packet is deterministic")
	_check(a.get_value(&"ether") == 1.0 and a.get_value(&"information") == 0.0,
			"state packet clamps every ecological input")
	_check(is_equal_approx(a.get_value(&"reporting"), 0.7)
			and is_equal_approx(a.get_value(&"cleanup"), 0.25),
			"state packet consumes reporting and authorized cleanup facts")
	var p0 := Phenotype.profile(Phenotype.Kind.CRYSTAL_LISTENER, 9041)
	var p1 := Phenotype.profile(Phenotype.Kind.CRYSTAL_LISTENER, 9041)
	var p2 := Phenotype.profile(Phenotype.Kind.FOLD_CRAB, 9041)
	_check(p0 == p1, "stable identity produces stable phenotype parameters")
	_check(p0 != p2 and p0.kind != p2.kind,
			"ecological types differ in organization rather than hue alone")
	var colony = Colony.new(); colony.configure(7, 9041); colony.seed_at(Vector3.ZERO)
	var renderer = Renderer.new(); add_child(renderer); renderer.setup(colony)
	for _i in 80: colony.add_surface_access(1.0)
	renderer._process(0.25)
	var census: Dictionary = renderer.census()
	_check(renderer.waking_style and renderer._waking != null,
			"every colony is drawn as the waking cell (ruling dream_tissue_look_20261115)")
	var before := colony.census()
	for _i in 120: renderer._process(1.0 / 60.0)
	_check(colony.census() == before, "presentation updates never mutate ecology authority")
	_check(int(census.nodes) <= 3, "cellular surface adds no node forest")
	var profiles := []
	for kind in Phenotype.Kind.size(): profiles.append(Phenotype.profile(kind, 9041))
	_check(profiles.size() == 13 and profiles[Phenotype.Kind.PIONEER].organization
			!= profiles[Phenotype.Kind.CRYSTAL_LISTENER].organization,
			"all thirteen cellular phenotype profiles remain reachable")
	renderer.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(not is_instance_valid(renderer), "teardown retains no cellular presentation node")
	print("DREAM SURFACE S1 TEST: %s (%d/%d)" % ["PASS" if passed == total else "FAIL", passed, total])
	get_tree().quit(0 if passed == total else 1)


func _check(ok: bool, label: String) -> void:
	total += 1
	if ok:
		passed += 1
		print("  [surface s1 ok] " + label)
	else:
		push_error("[SURFACE S1 FAIL] " + label)
