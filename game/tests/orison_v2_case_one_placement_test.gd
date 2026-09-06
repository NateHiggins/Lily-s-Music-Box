extends "res://tests/orison_v2_connected_exterior_route_test.gd"
## Spatial case-object route; complaint uses the existing public case owner.
## It is not a complete golden shift or a physical resident encounter.

func _init() -> void:
	route_label = "V2 CASE ONE PLACEMENT"

func _route() -> void:
	var owner := world.mina_gameplay
	var previous := owner.console.global_transform
	_require(not owner.place_case_objects({}) and owner.console.global_transform == previous,
			"incomplete placement refused without partial mutation")
	for point in [Vector3(2.3,1.6,1.3),Vector3(3.8,1.6,1.3),Vector3(3.8,3.2,-2.4),
			Vector3(3.8,3.2,-3.4),Vector3(0,3.2,-3.0),Vector3(0,3.2,0),
			Vector3(-3.2,3.2,0),Vector3(-6.4,3.2,0),Vector3(-8.5,3.2,0),
			Vector3(-9.2,3.2,1.4)]:
		if not await _walk(point): return
	var fixture: LightFixtureProp = world.adapter.resolve("F02_A_MAIN_LT_PENDANT_SHADE")
	var plate: Node3D = world.adapter.resolve("F02_A_MAIN_SWITCH")
	var other: LightFixtureProp = world.adapter.resolve("F03_B_MAIN_LT_PENDANT_SHADE")
	var other_powered := other.powered
	for point in [Vector3(-8.5,3.2,0),Vector3(-8.5,3.2,-2.0)]:
		if not await _walk(point): return
	player.set_lamp_enabled(false)
	_require(fixture.powered,"2A main pendant begins powered")
	for enabled in [false,true]:
		if not await _use(plate,plate.global_position-plate.global_basis.z*.05,
				"case_room_switch_%s"%enabled): return
		_require(fixture.powered == enabled and other.powered == other_powered,
				"physical 2A switch controls only its room circuit")
	if not await _walk(Vector3(-8.5,3.2,0)): return
	if not await _walk(Vector3(-9.2,3.2,1.4)): return
	RealityState.ensure_case(MinaCaseGameplay.CASE_ID,"mina_vale")
	RealityCases.interact_with_resident("mina_vale")
	for i in 30:
		if not owner.dialogue.visible: break
		owner.dialogue.choose(0)
		await get_tree().process_frame
	if not _require(not player.call_locked,"complaint dialogue releases movement"): return
	if not await _walk(Vector3(-10.5,3.2,1.0)): return
	for i in 3:
		var item: CaseInteractable = owner.evidence_nodes[i]
		var local: Vector3 = world.adapter.root.to_local(item.global_position)
		_require(is_equal_approx(local.y,3.98),"evidence rests at V2 desk height")
		if not await _walk(Vector3(local.x,3.2,0.85)): return
		var ray := PhysicsRayQueryParameters3D.create(item.global_position+Vector3.UP*.01,
				item.global_position-Vector3.UP*.1)
		ray.exclude = [item.get_rid()]
		var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(ray)
		_require(not hit.is_empty() and str(hit.collider.name)=="F02_A_CaptionDesk","case evidence has physical support")
		var spec: Dictionary = MinaCaseGameplay.EVIDENCE[i]
		for choice in (spec.choices as Array).find(spec.fact)+1:
			if not await _use(item,item.global_position+Vector3.UP*.008,"case_evidence_%d_%d"%[i,choice]): return
	_require(owner._inspection_count(RealityState.case_state(MinaCaseGameplay.CASE_ID)) == 3,
			"ordinary caption choices commit all three case-owned evidence facts")
	if not await _walk(Vector3(-11.1,3.2,1.7)): return
	if not await _use(owner.console,owner.console.global_position+Vector3.UP*.2,"case_calibrator"): return
	_require(world.adapter.root.to_local(owner.letter.global_position).is_equal_approx(Vector3(-6.4,9.615,.35)),
			"recurrence letter sits inside the V2 home threshold")
	for point in [Vector3(-10.5,3.2,2.5),Vector3(-8.5,3.2,2.5),Vector3(-8.5,3.2,0),
			Vector3(-6.4,3.2,0),Vector3(-3.2,3.2,0),Vector3(0,3.2,0)]:
		if not await _walk(point): return
