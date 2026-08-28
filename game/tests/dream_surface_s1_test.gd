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
	for _i in Colony.MAX_CILIA + 5: colony.spawn(Colony.OrganismClass.CILIUM, Vector3.ZERO)
	renderer._process(0.25)
	var census: Dictionary = renderer.census()
	_check(int(census.caps.cilia) == 32 and int(census.caps.membrane_proteins) == 64,
			"cilia and protein families have hard capacities")
	_check(int(census.cilia_visible) <= Colony.MAX_CILIA
			and int(census.proteins_visible) <= int(census.caps.membrane_proteins),
			"visible instance counts stay bounded by ecology and rendering caps")
	var before := colony.census()
	for _i in 120: renderer._process(1.0 / 60.0)
	_check(colony.census() == before, "presentation updates never mutate ecology authority")
	var root_y: float = renderer._cilia.multimesh.get_instance_transform(0).origin.y
	for _i in 30: renderer._process(1.0 / 60.0)
	_check(is_equal_approx(renderer._cilia.multimesh.get_instance_transform(0).origin.y, root_y),
			"cilia roots remain attached through metachronal motion")
	_check(int(census.nodes) <= 7, "cellular surface adds no node forest")
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
