extends RefCounted
## Actual timber grabs and two independent supports, not a pitch dial.

func _restore_household(codec: Node,saved: Dictionary) -> void:
	if codec._bound:
		# Exercise the bound owner's real document adoption. A private fixture
		# restore alone is correctly reconciled back to RealityState next frame.
		RealityState.data[codec.KEY]=saved.duplicate(true)
		codec._on_state_changed()
	else:codec._restore(saved)

func _focus(bench: Node3D,prop: Node3D,player: Node3D,part: Node3D) -> void:
	var at := part.to_global(Vector3(0,.12*.14,-.14))
	if player.inspecting():Input.warp_mouse(player.camera.unproject_position(at))
	else:
		player.camera.global_position=at+prop.global_basis*Vector3(.035,.18,-.30)
		player.camera.look_at(at)
	await bench.get_tree().physics_frame
	await bench.get_tree().physics_frame

func _move(bench: Node3D,prop: Node3D,player: Node3D,driver: Node3D,side: String,depth: float,failures: Array) -> bool:
	var part: Node3D=prop.native_pitch_wedges.rows[side].draw
	await _focus(bench,prop,player,part)
	if player._grab.find_target().get("part")!=part:failures.append("actual cursor finds "+side+" wood wedge");return false
	driver._click(player)
	if not player._grab.active() or prop._native_held!="pitch_"+side:failures.append("grab "+side+" wedge");return false
	driver._drag_to(player,depth)
	driver._click(player)
	if absf(float(part.position.z)-depth)>.00001 or not prop._native_held.is_empty():failures.append("mouse slides and releases "+side+" wedge");return false
	await bench.get_tree().physics_frame
	await bench.get_tree().physics_frame
	return true

func _supports(bench: Node3D,prop: Node3D,failures: Array) -> float:
	var rig: RadiatorNativeAssembly=prop.native_rig
	var mechanism: Node3D=prop.native_pitch_wedges
	var all_lowest := INF
	for side: String in ["supply","far"]:
		var row: Dictionary=mechanism.rows[side]
		var floor_gap := INF;var wedge_gap := INF;var witness := Vector3.ZERO
		for point in rig._shoe_points:
			var at: Vector3=rig.body.transform*(point+Vector3(row.anchor.position.x,0,-.03))
			floor_gap=minf(floor_gap,at.y)
			var gap: float=at.y+float(mechanism.spec().rise_per_m)*(at.z-row.anchor.position.z-row.draw.position.z)
			if gap<wedge_gap:wedge_gap=gap;witness=at
		all_lowest=minf(all_lowest,floor_gap)
		if floor_gap<-.000002 or wedge_gap<-.000002 or absf(minf(floor_gap,wedge_gap))>.000002:failures.append("actual entire shoe skin bears without floor/wedge penetration: "+side)
		if row.draw.position.z>.001 and wedge_gap<=floor_gap:
			var at: Vector3=rig.to_global(witness)
			var probe := PhysicsRayQueryParameters3D.create(at+rig.global_basis*Vector3.UP*.002,at-rig.global_basis*Vector3.UP*.004)
			probe.collide_with_areas=true
			var hit: Dictionary=bench.get_world_3d().direct_space_state.intersect_ray(probe)
			if hit.is_empty() or not row.draw.is_ancestor_of(hit.collider) or hit.position.distance_to(at)>.0001:
				print("WEDGE CONTACT PROBE ",side," at ",at," hit ",hit," draw ",row.draw.global_transform)
				failures.append("actual wedge collider supports actual shoe skin: "+side)
	return all_lowest

func run(bench: Node3D,prop: Node3D,player: Node3D,driver: Node3D,codec: Node,failures: Array) -> void:
	var original: Dictionary=JSON.parse_string(JSON.stringify(codec.snapshot()))
	var mechanism: Node3D=prop.native_pitch_wedges
	prop.native_service_progress=0
	prop.set_supply_position(0,0)
	prop.set_pitch(0)
	if mechanism.rows.size()!=2 or not prop.native_rig._shims.is_empty():failures.append("two actual wedges retire all preset shim draws")
	prop.set_supply_position(1,0)
	if not mechanism.grip("far").is_empty():failures.append("live supply prevents moving loaded radiator supports")
	prop.set_supply_position(0,0)
	if not await _move(bench,prop,player,driver,"far",.037,failures):return
	if prop.pitch_toward_supply<=.05 or absf(mechanism.rows.supply.draw.position.z)>.000001:failures.append("one real wedge raises only its own support")
	_supports(bench,prop,failures)
	if not await _move(bench,prop,player,driver,"supply",.025,failures):return
	await bench.get_tree().physics_frame
	if _supports(bench,prop,failures)<.001:failures.append("both independent wedges lift both actual shoes rather than resetting either support")
	var saved: Dictionary=JSON.parse_string(JSON.stringify(codec.snapshot()))
	var body_pose: Transform3D=prop.native_rig.body.transform
	if not codec.validate(saved,codec._kinds):failures.append("two-support JSON household state validates")
	var wrong := saved.duplicate(true)
	wrong.records.F02_B_RADIATOR_01.value.pitch=.95
	if codec.validate(wrong,codec._kinds):failures.append("saved pitch cannot contradict actual wedge positions")
	wrong=saved.duplicate(true)
	wrong.records.F02_B_RADIATOR_01.value.pitch_wedges.supply=true
	if codec.validate(wrong,codec._kinds):failures.append("boolean wedge travel is rejected without script errors")
	var directory := OS.get_environment("SHOT_DIR")
	if not directory.is_empty():
		player.camera.global_position=prop.native_rig.to_global(Vector3(0,.24,-.72))
		player.camera.look_at(prop.native_rig.to_global(Vector3(0,.025,-.1)))
		await RenderingServer.frame_post_draw
		bench.get_viewport().get_texture().get_image().save_png(directory.path_join("pitch_both_shoes_supported.png"))
	if not await _move(bench,prop,player,driver,"far",0,failures):return
	if not await _move(bench,prop,player,driver,"supply",0,failures):return
	_restore_household(codec,saved)
	if not prop.native_rig.body.transform.is_equal_approx(body_pose) or absf(mechanism.rows.far.draw.position.z-.037)>.00001 or absf(mechanism.rows.supply.draw.position.z-.025)>.00001:failures.append("restore reconstructs two actual wedge and raised-body poses")
	var legacy := saved.duplicate(true)
	legacy.records.F02_B_RADIATOR_01.value.erase("pitch_wedges")
	legacy.records.F02_B_RADIATOR_01.value.pitch=-.35
	if not codec.validate(legacy,codec._kinds):failures.append("pre-wedge radiator household state migrates")
	_restore_household(codec,legacy)
	await bench.get_tree().physics_frame
	await bench.get_tree().physics_frame
	if absf(prop.pitch_toward_supply+.35)>.00001 or mechanism.rows.far.draw.position.z>.000001 or mechanism.rows.supply.draw.position.z<=0:failures.append("legacy negative pitch maps to same physical sole and fixed supply wedge")
	_supports(bench,prop,failures)
	await _focus(bench,prop,player,mechanism.rows.supply.draw)
	driver._click(player)
	var key := InputEventKey.new()
	key.keycode=KEY_SPACE;key.physical_keycode=KEY_SPACE;key.pressed=true
	player._unhandled_input(key)
	if not player.inspecting():failures.append("Space reaches actual shoe supports for inspection");return
	var view: Transform3D=player.camera.global_transform
	if not await _move(bench,prop,player,driver,"supply",.012,failures):return
	if not view.is_equal_approx(player.camera.global_transform):failures.append("wedge inspection camera remains static while pointer moves support")
	player.end_inspection()
	_restore_household(codec,original)
	print("PITCH WEDGE HAND PASS COMPLETE")
