extends Node
## DREAM-ECOLOGY-E1 deterministic causal contract.
## godot --headless --path game res://tests/DreamMossEcologyTest.tscn

const Colony = preload("res://scripts/dream/dream_moss_colony.gd")
const Director = preload("res://scripts/dream/dream_ecology_director.gd")

var checks := 0
var failures := 0


func _ready() -> void:
	var colony = _new_colony(7101)
	var bad := {"id": "sealed", "position": Vector3(9, 0, 0), "reachable": true,
			"eligible": true, "sealed": true, "target_density": 1.0, "information": 1.0}
	var good := {"id": "radiator_cluster", "position": Vector3(1, 0, 1),
			"reachable": true, "eligible": true, "target_density": 0.8,
			"information": 0.9, "continuity": 0.8, "volume": 0.7,
			"disturbance": 0.1, "route_cost": 0.2}
	_check(colony.choose_site([bad, good]).id == "radiator_cluster", "1 pioneer selects valid information-bearing site")
	_check(colony.phase == Colony.Phase.SEEDED and colony.organisms.is_empty(), "2 moss exists before any organelle")
	for _i in 30:
		colony.add_surface_access(1.0)
	var cilium: Dictionary = colony.spawn(Colony.OrganismClass.CILIUM, colony.origin)
	_check(not cilium.is_empty() and colony.census().organisms.cilium == 1, "3 cilia are first spawned class")
	var director := Director.new()
	add_child(director)
	director.setup(7101)
	director.moss_colonies[colony.source_id] = colony
	var observation := _radiator_observation("cold")
	cilium.information = 0.16
	var sample_value: float = director.receive_cilium_sample(colony.source_id, int(cilium.id), "radiator", colony.origin, observation)
	_check(sample_value > 0.0 and colony.known_targets.has("radiator") and director.signal_census().emitted == 1, "4 cilia sample reaches moss memory as typed signal")

	colony.register_route("r1", "radiator", [colony.origin, colony.origin + Vector3(0.8, 0, 0)], 0.0)
	var near: float = colony.ether_at(colony.origin + Vector3(0.1, 0, 0))
	var far: float = colony.ether_at(colony.origin + Vector3(1.4, 0, 0))
	var blocked: float = colony.ether_at(colony.origin + Vector3(0.1, 0, 0), 0.8)
	_check(near > far and blocked < near * 0.3, "5 ether falls with route distance and obstruction")
	_check(not colony.can_spawn(Colony.OrganismClass.PALPATOR, colony.origin + Vector3(20, 0, 0)), "6 unsupported organism spawn is refused")
	_check(not colony.can_spawn(Colony.OrganismClass.PALPATOR, colony.origin + Vector3(Colony.SUPPORT_RADIUS[1] + 0.1, 0, 0)), "7 tentacle root respects class moss range")

	# Make an ecologically justified first specialist, then exercise its breath/report loop.
	for _i in 30:
		colony.add_surface_access(1.0)
	var palp: Dictionary = colony.spawn(Colony.OrganismClass.PALPATOR, colony.origin, "r1")
	_check(not palp.is_empty(), "specialist unlocks from surface, ether and returned information")
	palp.ether = 0.21
	_check(colony.update_excursion(palp, colony.origin + Vector3(0.7, 0, 0), 1.0) == "returning", "8 low ether forces return")
	palp.returning = false; palp.ether = 1.0; palp.information = Colony.INFO_CAPACITY[1] * 0.84
	_check(colony.update_excursion(palp, colony.origin, 0.1, 0.02) == "returning", "9 high information load forces reporting")
	palp.information = 0.5
	var strength_before: float = colony.routes.r1.strength
	colony.report(palp, "radiator", observation)
	_check(float(colony.routes.r1.strength) > strength_before, "10 useful report reinforces route")
	for _i in 12:
		colony.routes.r1.empty_trips = 2
		colony.routes.r1.strength = 0.06
		colony.report(palp)
	_check(not bool(colony.routes.r1.live) and colony.pruned_routes > 0, "11 repeated empty trips prune route")
	var repeat_value: float = colony.remember_target("radiator", observation)
	var changed_value: float = colony.remember_target("radiator", _radiator_observation("hot"))
	_check(changed_value > repeat_value, "12 target state change renews interest")

	var immature = _new_colony(90); immature.seed_at(Vector3.ZERO); immature.add_surface_access(1.0)
	immature.spawn(Colony.OrganismClass.CILIUM, Vector3.ZERO)
	_check(not immature.can_spawn(Colony.OrganismClass.COMPLEX_ORGANELLE, Vector3.ZERO), "13 complex life locked in immature colony")
	_unlock_complex(immature)
	_check(immature.complex_unlocked() and not immature.spawn(Colony.OrganismClass.COMPLEX_ORGANELLE, Vector3.ZERO, "a").is_empty(), "14 maturity, ether, diversity and routes unlock complex life")
	_check(Colony.class_preference(Colony.OrganismClass.VIBRATION_LISTENER, {"vibration": 1.0}) > Colony.class_preference(Colony.OrganismClass.VIBRATION_LISTENER, {"material_complexity": 1.0}) and Colony.class_preference(Colony.OrganismClass.MANIPULATOR, {"controls": 1.0}) > 1.0, "15 sensory classes prefer appropriate observable targets")
	_check(not colony.census().has("case_state") and not colony.census().has("save"), "16 organelles expose no case/save mutation authority")

	colony.routes.r1.live = true; colony.routes.r1.strength = 0.7
	colony.disturb(1.0, "maintenance shock")
	_check(colony.phase == Colony.Phase.DISTURBED and bool(palp.returning), "17 disturbance coordinates recall")
	palp.returning = true
	colony.routes.r1.live = false
	_check(colony.update_excursion(palp, colony.origin + Vector3(4, 0, 0), 0.2) == "senescent" and bool(palp.residue), "18 unreachable organism senesces in place")
	for _i in 50:
		colony.advance_collapse(0.2)
	_check(colony.phase == Colony.Phase.STAINED and colony.stain_coverage() >= 1.0, "19 collapse leaves density-correlated stain")
	_check(colony.recolonization_blocked(), "20 stain blocks immediate recolonization")
	var dirty: float = colony.stain_coverage()
	var unauthorized: float = colony.cleanup(1.0, false)
	var cleaned: float = colony.cleanup(1.0, true)
	_check(is_equal_approx(unauthorized, dirty) and cleaned < dirty, "21 authorized cleanup alone reduces stain")

	var one := _deterministic_run(444)
	var two := _deterministic_run(444)
	_check(one == two, "22 equal seeds produce byte-identical census receipt")
	var budgeted = _new_colony(555); budgeted.seed_at(Vector3.ZERO); _unlock_complex(budgeted)
	for i in 400:
		budgeted.remember_target("t%d" % i, {"state_signature": str(i), "material_complexity": 1.0, "modalities": ["touch"]})
		budgeted.register_route("r%d" % i, "t", [Vector3.ZERO])
		budgeted.spawn(Colony.OrganismClass.CILIUM, Vector3.ZERO)
	var budget: Dictionary = budgeted.census().budget
	_check(int(budget.organisms) <= int(budget.organism_cap) and int(budget.targets) <= int(budget.target_cap) and int(budget.routes) <= int(budget.route_cap), "23 accelerated simulation remains capped")
	budgeted.organisms.clear(); budgeted.routes.clear(); budgeted.known_targets.clear()
	_check(budgeted.organisms.is_empty() and budgeted.routes.is_empty() and budgeted.known_targets.is_empty(), "24 teardown retains no transient records")
	_check(director.cellular_audio.census().voices <= 4, "25 existing four-voice cellular audio budget remains intact")

	print("DREAM MOSS ECOLOGY TEST: %s (%d/%d)" % ["PASS" if failures == 0 else "FAIL", checks - failures, checks])
	get_tree().quit(failures)


func _new_colony(seed_value: int):
	var colony = Colony.new()
	colony.configure(7, seed_value)
	return colony


func _radiator_observation(state: String) -> Dictionary:
	return {"state_signature": state, "moving_parts": 0.8, "heat": 0.7,
			"vibration": 0.8, "controls": 0.7, "openings": 0.4,
			"material_complexity": 0.8, "modalities": ["touch", "vibration", "heat"]}


func _unlock_complex(colony) -> void:
	colony.maturity = 0.8; colony.extent = 3.5; colony.ether_reserve = 1.0
	colony.connected_ether_volume = 2.0; colony.stored_information = 2.0
	colony.information_modalities = {"touch": true, "vibration": true, "vision": true}
	colony.spawn(Colony.OrganismClass.CILIUM, colony.origin)
	colony.register_route("a", "one", [colony.origin]); colony.routes.a.strength = 0.7
	colony.register_route("b", "two", [colony.origin]); colony.routes.b.strength = 0.7


func _deterministic_run(seed_value: int) -> String:
	var colony = _new_colony(seed_value)
	colony.choose_site([{"id": "b", "position": Vector3(1, 0, 0), "reachable": true, "eligible": true, "target_density": 0.8, "information": 0.8}, {"id": "a", "position": Vector3.ZERO, "reachable": true, "eligible": true, "target_density": 0.8, "information": 0.8}])
	for _i in 20: colony.add_surface_access(0.8)
	colony.spawn(Colony.OrganismClass.CILIUM, colony.origin)
	colony.remember_target("fixture", {"state_signature": "1", "heat": 1.0, "modalities": ["heat"]})
	return colony.deterministic_receipt()


func _check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("  [moss ok] ", label)
	else:
		failures += 1
		printerr("  [MOSS FAIL] ", label)
