extends "res://tests/v2_hose_follower_programme.gd"
## Longer uninstalled fixture diagnostic. Solver work is not played frame time.
func run(holder: PlayerController) -> bool:
	if not await super.run(holder):return false
	await _settle()
	return failures.is_empty()
func _settle() -> void:
	var saved: Dictionary=rig.snapshot();var initial: PackedVector3Array=rig.strand.points.duplicate()
	var dynamics:=preload("res://scripts/props/native_hose_dynamics.gd").new()
	dynamics.use_follow_projection=true;dynamics.pin_outlet_direction=true
	if not check_configuration(dynamics):return
	var frames: Array[Transform3D]=rig.model_frames(initial);var lowest:=INF
	for i in initial.size():
		for point: Vector3 in contact.sections[i].outer:lowest=minf(lowest,(frames[i]*point).y)
	var floor:=StaticBody3D.new();var leaf:=CollisionShape3D.new();var box:=BoxShape3D.new()
	box.size=Vector3(4,.04,4);leaf.shape=box;floor.add_child(leaf);add_child(floor)
	floor.global_transform=rig.model.global_transform*Transform3D(Basis.IDENTITY,Vector3(0,lowest-.025,.1))
	await get_tree().physics_frame;await get_tree().physics_frame
	check(not contact.intersects_pose(initial),"long release floor begins outside the actual skin")
	var physics: bool=player.is_physics_processing();player.set_physics_process(false)
	var records: Array=[];var success:=true
	for step in 120:
		var before: PackedVector3Array=rig.strand.points.duplicate();var speed: PackedVector3Array=dynamics.velocities.duplicate()
		var start: int=Time.get_ticks_usec();var accepted: bool=dynamics.step(dynamics.STEP_S)
		var elapsed: float=(Time.get_ticks_usec()-start)/1000.
		records.append({"step":step,"solver_ms":elapsed,"accepted":accepted,"error":dynamics.error,"profile_usec":dynamics.profile_usec.duplicate(),"follow_successes":dynamics.follow_successes,"follow_fallbacks":dynamics.follow_fallbacks,"last_follow_error":dynamics.last_follow_error,"attempts":dynamics.step_attempts,"advanced_time_s":dynamics.advanced_time_s,"energy_delta":dynamics.last_energy_delta,"internal_energy_removed":dynamics.last_internal_energy_removed})
		if not accepted:
			preload("res://tests/v2_fire_hose_gravity_programme.gd").new().save_case(dynamics)
			check(rig.strand.points==before and dynamics.velocities==speed and dynamics.advanced_time_s==0. and _pose_matches(),"rejected long release preserves pose, skin, speed and time atomically")
			success=false;break
		if step%2==1:await get_tree().physics_frame
	check(success and records.size()==120,"full native strand advances all120steps across60real physics frames")
	check(rig.strand._valid_positions(rig.strand.points) and dynamics.kernel._bend_error(rig.strand.points)<=.00002 and not contact.intersects_pose(rig.strand.points),"long release retains material, bending and real world clearance")
	var final_frames: Array[Transform3D]=rig.model_frames(rig.strand.points)
	var port:=true
	for i in range(initial.size()-3,initial.size()):port=port and rig.strand.points[i]==initial[i] and dynamics.velocities[i]==Vector3.ZERO
	check(port,"long release preserves the fixed fitting neck")
	var out: String=OS.get_environment("SHOT_DIR")
	if not out.is_empty():
		var bind: Array=[];var current: Array=[]
		for i in final_frames.size():
			bind.append(frame_row(rig.original_frames[i]));current.append(frame_row(final_frames[i]))
		FileAccess.open(out.path_join("settling.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Uninstalled fixture solver costs, not played frame time or full deployment. No self-contact or water authority.","steps":records,"pose":rig.snapshot(),"bind_frames":bind,"frames":current,"failures":failures},"\t"))
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("settling_final.png"))
	floor.free();await get_tree().physics_frame
	check(rig.restore(saved),"long release diagnostic restores the original pose")
	_sync();player.set_physics_process(physics)
func check_configuration(dynamics: RefCounted) -> bool:
	var configured: bool=dynamics.configure(rig,contact)
	check(configured,"long release binds the source-owned native solver and shell")
	return configured
func frame_row(frame: Transform3D) -> Array:
	return [[frame.basis.x.x,frame.basis.x.y,frame.basis.x.z],[frame.basis.y.x,frame.basis.y.y,frame.basis.y.z],[frame.basis.z.x,frame.basis.z.y,frame.basis.z.z],[frame.origin.x,frame.origin.y,frame.origin.z]]
