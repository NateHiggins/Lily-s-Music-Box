extends Node
## The waking organism in V2 (v1r_waking_organism_20261109): the encroachment
## finds every organism case's flat in V2, its living fields cover V2's
## storeys, the fields bind V2's own wall materials, and the organism lives.

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
	var enc: Node = world.apartment_encroachment
	_check(enc != null, "the encroachment is composed")
	if enc == null:
		_finish(world)
		return
	var cases: Array = enc.CASES.keys()
	print("[V2 WAKING ORGANISM] cases %d, flats found %d, fields %s, storey %s"
		% [cases.size(), enc.units.size(), str(enc.fields.keys()), str(enc.storey_rect)])
	_check(enc.units.size() == cases.size(), "every organism case's flat is found in V2")
	for case_id: String in enc.units:
		var unit := str(enc.CASES[case_id].unit)
		var rect: Vector4 = enc.units[case_id].rect
		_check(rect.x >= enc.storey_rect.x - 0.01 and rect.z <= enc.storey_rect.z + 0.01
			and rect.y >= enc.storey_rect.y - 0.01 and rect.w <= enc.storey_rect.w + 0.01,
			"%s's flat lies inside the storey field" % case_id)
		_check(enc.field_source.has(case_id), "%s has a source in its storey's field" % case_id)
		var floor_id: String = enc._floor_of(case_id)
		_check(floor_id == "F0" + unit.left(1), "%s lives on its own storey (%s)" % [case_id, floor_id])
	for floor_id: String in enc.fields:
		var bound: int = (enc.storey_materials.get(floor_id, []) as Array).size()
		print("[V2 WAKING ORGANISM] %s binds %d V2 materials" % [floor_id, bound])
		_check(bound >= 5, "the %s field binds its case flats' V2 materials" % floor_id)
	_check(enc.dream_field != null, "the waking dream field runs")
	_check(enc.surface_tendrils == null and enc.critters == null, "V2 builds no tendrils and no critters")
	_check(enc.margin != null and enc.palp_renderer != null, "the margin and its palps are built")
	# The margin runs only on the storey the dream field was seeded on.
	var player: Node3D = world.player
	var margin_floor: String = enc._margin_floor
	var other_y := INF
	var margin_y := INF
	for case_id: String in enc.units:
		var fy := float(enc.units[case_id].floor_y)
		if enc._floor_of(case_id) == margin_floor:
			margin_y = fy
		else:
			other_y = fy
	var rect: Vector4 = enc.storey_rect
	var mid := Vector3((rect.x + rect.z) * 0.5, 0.0, (rect.y + rect.w) * 0.5)
	if other_y < INF and margin_y < INF:
		player.global_position = Vector3(mid.x, other_y + 1.0, mid.z)
		for i in 3: await get_tree().physics_frame
		_check(enc.margin.process_mode == Node.PROCESS_MODE_DISABLED and not enc.palp_renderer.visible,
			"off the margin's storey the margin pauses and its palps hide")
		player.global_position = Vector3(mid.x, margin_y + 1.0, mid.z)
		for i in 3: await get_tree().physics_frame
		_check(enc.margin.process_mode == Node.PROCESS_MODE_INHERIT and enc.palp_renderer.visible,
			"on %s the margin runs and its palps draw" % margin_floor)
	# The organism lives: its fields step.
	var before: Dictionary = {}
	for floor_id: String in enc.fields:
		before[floor_id] = int(enc.fields[floor_id].steps)
	for i in 120:
		await get_tree().physics_frame
	for floor_id: String in enc.fields:
		_check(int(enc.fields[floor_id].steps) > int(before[floor_id]), "the %s field advances" % floor_id)
	print("[V2 WAKING ORGANISM] startup_ms %.0f" % world.startup_ms)
	var last := 0.0
	for row: Dictionary in world.startup_milestones:
		var at := float(row.wall_ms_since_start)
		if at - last > 2000.0 or str(row.stage) in ["reality_director_ready", "waking_organism_ready"]:
			print("[V2 WAKING ORGANISM] milestone %s at %.0f ms (+%.0f)" % [row.stage, at, at - last])
		last = at
	_finish(world)


func _finish(world: Node) -> void:
	var ok := _fails == 0
	print("[V2 WAKING ORGANISM] RESULT: %s (%d checks, %d failures)" % ["PASS" if ok else "FAIL", _checks, _fails])
	if world.has_method("shutdown_for_tests"):
		world.shutdown_for_tests()
	get_tree().quit(0 if ok else 1)
