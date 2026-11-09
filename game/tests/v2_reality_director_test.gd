extends Node
## The invisible director runs in V2 (v1r_sanity_layer_20261109): it is
## composed, it knows which apartment a point is in, it acts on free-standing
## props and never moves a mounted fitting, and a forced rung really happens.
const RealityDirector := preload("res://scripts/building/orison_v2_reality_director.gd")

var _fails := 0
var _checks := 0


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("  [FAIL] ", label)


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var world := (load("res://scenes/building/orison_v2_runtime.tscn") as PackedScene).instantiate()
	add_child(world)
	while not world.startup_failed and world.startup_ms <= 0.0:
		await get_tree().process_frame
	_check(not world.startup_failed, "the V2 world starts")
	if world.startup_failed:
		_finish(world)
		return
	var sanity: SanityDirector = world.sanity
	var intrusions: Intrusions = world.intrusions
	_check(sanity != null and intrusions != null and world.fourth_wall != null
		and world.building_personality != null, "director, intrusions, personality and fourth wall are composed")
	_check(sanity.world == world and intrusions.world == world, "the director is bound to the V2 root")

	var movable: Array = world.intrusion_props()
	var fits: Array = world.intrusion_fit_props()
	print("[V2 REALITY DIRECTOR] movable props %d, props that can have a fit %d" % [movable.size(), fits.size()])
	_check(movable.size() >= 20, "there are free-standing props to act on")
	_check(fits.size() >= 1, "there are props that can have a fit")
	var kinds: Dictionary = {}
	for prop: Node in movable:
		_check(not RealityDirector.is_fixed(prop) and not prop is LightFixtureProp,
			"no mounted fitting or light in the movable pool: " + str(prop.name))
		var path: String = prop.get_script().resource_path.get_file()
		kinds[path] = int(kinds.get(path, 0)) + 1
	print("[V2 REALITY DIRECTOR] movable kinds ", JSON.stringify(kinds))

	# Units: every poltergeist's home must be a place the director can find.
	var units: Dictionary = {}
	var by_unit: Dictionary = {}
	for prop: Node3D in movable:
		var unit: String = world.unit_at_world(prop.global_position)
		if unit != "":
			units[unit] = true
			if not by_unit.has(unit):
				by_unit[unit] = prop
	var homes: Dictionary = {}
	for case_id: String in PoltergeistLibrary.ids():
		var home := PoltergeistLibrary.unit_of(case_id)
		if home != "":
			homes[home] = case_id
	var missing: Array = []
	for home: String in homes:
		if not units.has(home):
			missing.append(home)
	print("[V2 REALITY DIRECTOR] units with movable props %s; poltergeist homes without one %s" % [str(units.keys()), str(missing)])
	_check(units.size() >= 8, "the director resolves apartments from V2 footprints")
	_check(missing.size() * 2 <= homes.size(), "most poltergeist homes hold something to act on")

	# A real act on a real prop, in a home that has a poltergeist.
	var home_unit := ""
	for unit: String in by_unit:
		if homes.has(unit):
			home_unit = unit
			break
	_check(home_unit != "", "a poltergeist's home holds a movable prop")
	if home_unit != "":
		var target: Node3D = by_unit[home_unit]
		var player: Node3D = world.player
		player.global_position = target.global_position + Vector3(1.4, 0.0, 0.0)
		await get_tree().physics_frame
		_check(world.unit_at_world(target.global_position) == home_unit, "the target is in " + home_unit)
		var before: Dictionary = {}
		for prop: Node3D in movable:
			if prop.global_position.distance_to(player.global_position) <= Intrusions.REACH:
				before[prop] = prop.global_transform
		_check(intrusions.perform("prop_turn", 2), "prop_turn finds props within reach")
		var moved := 0
		for prop: Node3D in intrusions.last_targets:
			if before.has(prop) and not prop.global_transform.is_equal_approx(before[prop]):
				moved += 1
			_check(not RealityDirector.is_fixed(prop), "prop_turn never turns a fitting")
		_check(moved >= 1, "prop_turn visibly turned something")
		var fired: Array = []
		sanity.intruded.connect(func(case_id: String, tier: int): fired.append([case_id, tier]))
		var case_id: String = homes[home_unit]
		sanity.force(case_id, 1)
		_check(fired.size() == 1 and fired[0][0] == case_id, "a forced rung of %s happens in V2" % case_id)

	_finish(world)


func _finish(world: Node) -> void:
	var ok := _fails == 0
	print("[V2 REALITY DIRECTOR] RESULT: %s (%d checks, %d failures)" % ["PASS" if ok else "FAIL", _checks, _fails])
	if world.has_method("shutdown_for_tests"):
		world.shutdown_for_tests()
	get_tree().quit(0 if ok else 1)
