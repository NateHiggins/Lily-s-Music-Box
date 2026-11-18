extends Node
## Organism incidents in V2 (v1r_organism_incidents_20261109): a resident
## reports a neighbour's organism in their flat as a V2 work order, the report
## can hold one of the flat's appliances, and fixing it closes the order and
## drives the growth out.

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
	var inc: Node = world.organism_incidents
	_check(inc != null and inc.enabled, "organism incidents are composed and enabled")
	if inc == null:
		_finish(world)
		return
	var with_props := 0
	for unit: String in inc.flat_props:
		if not (inc.flat_props[unit] as Array).is_empty():
			with_props += 1
	print("[V2 ORGANISM INCIDENTS] %d flats can report; %d hold appliances" % [inc.flats.size(), with_props])
	_check(inc.flats.size() >= 10, "case flats on living storeys can report")
	_check(with_props * 2 >= inc.flats.size(), "most reporting flats hold appliances it can fault")

	# Mina's organism in someone else's flat on her storey.
	var enc: Node = world.apartment_encroachment
	var source_case := "mina_caption_crisis"
	var storey: String = enc._floor_of(source_case)
	var unit := ""
	for candidate: String in inc.flats:
		if str(inc.flats[candidate].floor_id) == storey and str(inc.flats[candidate].case_id) != source_case \
				and not (inc.flat_props.get(candidate, []) as Array).is_empty():
			unit = candidate
			break
	_check(unit != "", "a neighbour of Mina's on %s holds appliances" % storey)
	if unit == "":
		_finish(world)
		return
	var rect: Vector4 = inc.flats[unit].rect
	var at := Vector3((rect.x + rect.z) * 0.5, float(inc.flats[unit].floor_y) + 0.2, (rect.y + rect.w) * 0.5)
	inc._forced_roll = "1"
	var before := int(inc.reports_filed)
	inc._report(unit, source_case, {"at": at, "count": 40})
	_check(int(inc.reports_filed) == before + 1, "the resident of %s files a report" % unit)
	var record: Dictionary = inc._record(unit)
	var order_id := str(record.get("order_id", ""))
	_check(order_id.begins_with("ORG-" + unit), "the report is a V2 work order (%s)" % order_id)
	_check(world.work_orders.is_active(order_id),
		"the work order is active")
	var condition := str(record.get("condition", ""))
	_check(not condition.is_empty(), "the report holds one of the flat's appliances")
	var prop: Node = world.get_node_or_null(str(record.get("prop", "")))
	_check(prop is FunctionalProp and (prop as FunctionalProp).state == FunctionalProp.PState.FAULT,
		"the held appliance is in fault")
	print("[V2 ORGANISM INCIDENTS] %s reports %s; condition %s on %s" % [unit, order_id, condition, prop.name if prop else "?"])
	if prop != null:
		_check(inc.fix(unit, prop), "fixing the appliance is accepted")
		_check((prop as FunctionalProp).state == FunctionalProp.PState.IDLE, "the appliance is restored")
		_check(bool(inc._record(unit).get("closed", false)), "the work order closes")
	_finish(world)


func _finish(world: Node) -> void:
	var ok := _fails == 0
	print("[V2 ORGANISM INCIDENTS] RESULT: %s (%d checks, %d failures)" % ["PASS" if ok else "FAIL", _checks, _fails])
	if world.has_method("shutdown_for_tests"):
		world.shutdown_for_tests()
	get_tree().quit(0 if ok else 1)
