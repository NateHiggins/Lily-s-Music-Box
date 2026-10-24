extends "res://tests/v2_hose_idle_visual_profile.gd"
## INERT: actual installed union input before the inherited extraction route.
## Initial placement and later repaired-line staging remain explicit diagnostics.
func _idle_controls() -> void:
	var native: RefCounted=world.adapter.root.get_meta("v2_native_fire_service")
	var actor: Node3D=native.stations.F02_FIRE_LINE_STAIR.get_ref()
	var saved: Dictionary=actor.mechanism_snapshot()
	var hands: Node3D=preload("res://tests/v2_fire_hand_bench.gd").new()
	hands.set_meta("shared_world_validation",true);hands.player=player;add_child(hands)
	var hand: Node=preload("res://tests/fixed_gesture_patrol_hand.gd").new()
	hand.player=player;add_child(hand)
	var result: Dictionary={"evidence_class":"INERT","scope":"Actual installed F02 union grab/motion/release. Optional continued repair chain is recorded separately in actual_repaired_line.json; programme includes explicit save/restore negative controls.","before":saved}
	profile_phase="installed_union_open"
	var ok: bool=_check(await hand.operate(actor._door_pivot.to_global(Vector3(-.4,.1,.015)),1.78,actor),"actual installed cover opens before union maintenance")
	if ok:
		await hands.aim(actor._tag.to_global(Vector3(0,0,.0035)));hands.click();hands.key(KEY_SPACE)
		ok=_check(player.inspecting() and player.inspect_owner==actor,"actual installed tag grip enters supported maintenance inspection")
	if ok:
		profile_phase="installed_union_partial_unscrew"
		ok=_check(await hands.inspect_operate(hand,actor._joint_nut,actor._coupling.to_global(Vector3(0,-.012,.032)),.9),"actual installed union accepts a partial screw stroke")
		_check(not actor.coupling_made_up and not actor.gasket_seen,"partial unscrewing neither repairs nor counterfeits gasket inspection")
		result.partial=actor.mechanism_snapshot()
	if ok:
		profile_phase="installed_union_full_unscrew"
		ok=_check(await hands.inspect_operate(hand,actor._joint_nut,actor._coupling.to_global(Vector3(0,-.012,.032)),actor._maximum("joint")),"actual installed union follows the full retained screw travel")
	if ok:
		profile_phase="installed_union_yz_carry"
		var goal: Vector3=actor._loose_union.receiving()+Vector3(0,-.015,.015)
		ok=_check(await hands.carry_union(actor,goal),"actual mouse and depth input move the installed loose hose end on Y and Z")
		result.loose=actor.mechanism_snapshot()
		_check(not actor.coupling_made_up and not actor.gasket_seated and actor.valid_mechanism(result.loose),"loose installed union preserves maintenance faults and a valid saved pose")
	if ok:
		profile_phase="installed_union_return"
		ok=_check(await hands.carry_union(actor,actor._loose_union.receiving()),"actual installed loose hose end returns to its receiving thread")
	if ok:
		profile_phase="installed_union_retighten"
		ok=_check(await hands.inspect_operate(hand,actor._joint_nut,actor._coupling.to_global(Vector3(0,-.012,.032)),actor._minimum("joint")),"actual installed union retightens through mouse motion")
		_check(actor.coupling_made_up and not actor.line_made_up() and not actor.gasket_seated,"an empty tightened union retains the original gasket fault")
	if ok and OS.get_environment("V2_INSTALLED_NOZZLE_REVIEW")=="1":
		player.cancel_manipulation()
		if player.inspecting():hands.key(KEY_ESCAPE)
		var nozzle_hands: Node3D=preload("res://tests/v2_fire_nozzle_coupling_bench.gd").new()
		nozzle_hands.set_meta("shared_world_validation",true);nozzle_hands.player=player;add_child(nozzle_hands)
		profile_phase="installed_nozzle_programme"
		await nozzle_hands.exercise_nozzle(actor,hand)
		result.nozzle_checks=nozzle_hands.observations.duplicate(true)
		result.nozzle_failures=nozzle_hands.failures.duplicate()
		ok=_check(nozzle_hands.failures.is_empty(),"installed physical nozzle programme retains actual translation, screw, constraint and support checks")
		nozzle_hands.free()
	if ok and OS.get_environment("V2_INSTALLED_GASKET_REVIEW")=="1":
		player.cancel_manipulation()
		if player.inspecting():hands.key(KEY_ESCAPE)
		profile_phase="installed_gasket_programme"
		await hands.exercise_gasket(actor,hand)
		result.gasket_checks=hands.observations.duplicate(true)
		result.gasket_failures=hands.failures.duplicate()
		ok=_check(hands.failures.is_empty() and actor.gasket_seated and actor.gasket_seen and actor.coupling_made_up,"installed physical washer programme retains actual fitting, inspection and original save checks")
	result.after=actor.mechanism_snapshot();result.completed=ok
	profile_phase="capture_excluded_union_review"
	await _picture("installed_union_review")
	player.cancel_manipulation()
	if player.inspecting():hands.key(KEY_ESCAPE)
	if OS.get_environment("V2_INSTALLED_REPAIR_CHAIN")!="1":actor.restore_mechanism(saved)
	_check(actor.valid_mechanism(actor.mechanism_snapshot()),"installed diagnostic mechanism remains valid after maintenance review")
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("installed_union.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	hands.free();hand.free()

func _prepare_repaired_line(actor: Node3D,joint: Node3D) -> bool:
	if OS.get_environment("V2_INSTALLED_REPAIR_CHAIN")!="1":return await super._prepare_repaired_line(actor,joint)
	if not _check(actor.gasket_seated and actor.gasket_seen and actor.coupling_made_up and not actor.nozzle_coupled,"installed chain begins with the washer programme's real gasket-bearing connection"):return false
	var nozzle_hands: Node3D=preload("res://tests/v2_fire_nozzle_coupling_bench.gd").new()
	nozzle_hands.set_meta("shared_world_validation",true);nozzle_hands.player=player;add_child(nozzle_hands)
	await nozzle_hands.aim(actor._tag.to_global(Vector3(0,0,.0035)));nozzle_hands.click();nozzle_hands.key(KEY_SPACE)
	var ok:=player.inspecting() and player.inspect_owner==actor
	profile_phase="installed_chain_nozzle_alignment"
	var entry: Vector3=joint.thread_pose(joint.stock.maximum_angle()).origin
	var approach: Vector3=entry+joint.receiver.basis.y*.006+Vector3(0,.0005,.0006)
	var lifted: Vector3=joint.body.position+Vector3.UP*.001
	var clear: Vector3=lifted+joint.receiver.basis.y*.012
	var stop:=func():
		var local: Vector3=joint.receiver.affine_inverse()*joint.body.position
		return joint._on_pilot() and absf(local.y-joint.stock.pilot_min)<.00001
	if ok:ok=await nozzle_hands.carry_path(actor,actor._play_pipe,actor._play_pipe.to_global(Vector3(0,.155,.014)),[lifted,clear,approach+joint.receiver.basis.y*.012,approach,entry-joint.receiver.basis.y*.004],.0001,stop)
	_check(ok,"actual installed chain carries the nozzle into its receiving guide")
	if ok:ok=await nozzle_hands.pickup_with_mouse(joint)
	_check(ok,"actual tightening input engages the installed nozzle thread")
	profile_phase="installed_chain_nozzle_seal"
	if ok:ok=await nozzle_hands.inspect_operate(driver,joint.nut,joint.nut.to_global(Vector3(0,.020,.027)),0.)
	ok=_check(ok and actor.gasket_seated and actor.gasket_seen and actor.coupling_made_up and actor.nozzle_coupled and actor.nozzle_shut and actor.valid_mechanism(actor.mechanism_snapshot()),"actual maintenance input produces the valid sealed line used by charging and save/reload") and ok
	player.cancel_manipulation()
	if player.inspecting():nozzle_hands.key(KEY_ESCAPE)
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("actual_repaired_line.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Actual final nozzle engagement after the diagnostic washer programme. The programme separately includes save/restore negative controls; procurement, dressing and certification are not claimed.","ok":ok,"state":actor.mechanism_snapshot(),"checks":nozzle_hands.observations,"failures":nozzle_hands.failures},"\t"))
	nozzle_hands.free();return ok
