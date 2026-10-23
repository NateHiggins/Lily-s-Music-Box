extends RefCounted
## Actual FPS input on an isolated collision-bearing floor. Not building qualification.
func _aim_error(player: Node3D,joint: Node3D) -> float:
	return rad_to_deg(acos(clampf((-player.camera.global_basis.z).dot(joint.body.global_basis.y),-1.,1.)))
func _hand_distance(player: Node3D,actor: Node3D,joint: Node3D) -> float:
	return actor.to_global(joint.receiver.origin).distance_to(player.camera.to_global(Vector3(.17,-.16,-.48)))
func _points(rows: PackedVector3Array) -> Array:
	var result: Array=[]
	for point: Vector3 in rows:result.append([point.x,point.y,point.z])
	return result
func _planes(rows: Array) -> Array:
	var result: Array=[]
	for row: Dictionary in rows:result.append({"ring":row.ring,"normal":[row.normal.x,row.normal.y,row.normal.z],"offset":row.offset})
	return result
func _settle(bench: Node,hose: Node3D,actor: Node3D,joint: Node3D,milliseconds: int) -> void:
	var until: int=Time.get_ticks_msec()+milliseconds
	while Time.get_ticks_msec()<until and bench.player._grab.holding_pickup():
		if not hose.tether.pending and _hand_distance(bench.player,actor,joint)<.025 and _aim_error(bench.player,joint)<1.:return
		await bench.get_tree().process_frame
func run(bench: Node,actor: Node3D,hose: Node3D,joint: Node3D) -> void:
	var player: Node3D=bench.player
	if player._grab.active():bench.click()
	# Explicit owner change: full deployment is a visual approximation, with
	# static rest. Earlier strict physical programmes and failures are retained.
	hose.enable_visual_follow()
	bench.check(not hose.is_processing() and not hose.is_physics_processing(),"visual hose has no idle simulation callbacks")
	# One initial fixture placement, before pickup. All payout travel below uses
	# the normal character controller and original collision capsule.
	player.global_position=Vector3(-.4,.02,1.15);player.velocity=Vector3.ZERO
	player.collision_layer=1;player.collision_mask=2097153;player.set_physics_process(true)
	player.face_world_point(joint.body.global_position)
	for frame in 8:await bench.get_tree().physics_frame
	bench.check(not player.noclip and player.is_physics_processing() and (player.collision_mask&1)==1,"payout uses the live player capsule and ordinary ground collision")
	if not bench.check(await bench._aim_nozzle_surface(actor,joint,false),"FPS payout targets the actual nozzle without relocating the player"):return
	bench.click()
	if not bench.check(player._grab.holding_pickup() and player.held_stock_body()==joint.body,"actual primary click acquires the FPS nozzle and its physical body"):return
	var auxiliary: Array=hose._auxiliary_contacts.duplicate(true)
	var auxiliary_paths: Array=[]
	for row: Dictionary in auxiliary:auxiliary_paths.append(str(row.body.get_path()))
	bench.check(not auxiliary.is_empty() and auxiliary.all(func(row: Dictionary):return player.get_collision_exceptions().has(row.body)),"held hose assembly includes attached auxiliary bodies in carrier exclusions")
	await _settle(bench,hose,actor,joint,3000)
	bench.check(hose.error.is_empty() and _hand_distance(player,actor,joint)<.025 and _aim_error(player,joint)<1.,"FPS nozzle initially settles at the camera hand pose")
	var sensitivity: float=clampf(float(GameBoot.settings.get("look_sensitivity",1.)),.25,2.)
	# Actual mouse input turns the held nozzle and character toward the clear
	# floor route; no carrier transform is assigned after pickup.
	for step in 100:
		var turn: float=wrapf(PI*.5-player.rotation.y,-PI,PI)
		var pitch: float=player.camera.rotation.x
		if absf(turn)<.001 and absf(pitch)<.001:break
		var event:=InputEventMouseMotion.new()
		event.relative=Vector2(-clampf(turn,-.08,.08),clampf(pitch,-.08,.08))/(player.MOUSE_SENS*sensitivity)
		player._unhandled_input(event)
		await bench.get_tree().physics_frame
	await _settle(bench,hose,actor,joint,3000)
	var rows: Array=[];var started: int=Time.get_ticks_msec();var stalls:=0
	var previous_span: float=hose.rig.strand.points[0].distance_to(hose.rig.strand.anchor)
	for step in 500:
		if not player._grab.holding_pickup() or Time.get_ticks_msec()-started>90000:break
		var span: float=hose.rig.strand.points[0].distance_to(hose.rig.strand.anchor)
		if span>=15.089:break
		var before: Vector3=player.global_position
		var tick: int=Time.get_ticks_msec()
		var during_contacts: Dictionary={}
		Input.action_press("move_forward",.4)
		while player.global_position.distance_to(before)<.06 and Time.get_ticks_msec()-tick<1000 and player._grab.holding_pickup():
			await bench.get_tree().physics_frame
			for index in player.get_slide_collision_count():
				var body: Object=player.get_slide_collision(index).get_collider()
				if body is Node:during_contacts[str(body.get_path())]=true
		Input.action_release("move_forward")
		await bench.get_tree().physics_frame
		await _settle(bench,hose,actor,joint,1500)
		span=hose.rig.strand.points[0].distance_to(hose.rig.strand.anchor)
		var contacts: Array=[]
		for index in player.get_slide_collision_count():
			var collider: Object=player.get_slide_collision(index).get_collider()
			contacts.append(str(collider.get_path()) if collider is Node else str(collider))
		var row: Dictionary={"step":step,"span_m":span,"elapsed_ms":Time.get_ticks_msec()-tick,"player":[player.global_position.x,player.global_position.y,player.global_position.z],"held":player._grab.holding_pickup(),"aim_degrees":_aim_error(player,joint),"hand_distance_m":_hand_distance(player,actor,joint),"error":hose.error,"feedback":player._grab.feedback({}).state,"player_contacts":contacts,"during_contacts":during_contacts.keys(),"fitting_blocker":hose.last_fitting_blocker,"profile":hose.last_motion_profile.duplicate(true)}
		rows.append(row)
		if step%25==0:print("FPS PAYOUT: ",JSON.stringify(row))
		stalls=stalls+1 if span-previous_span<.001 else 0;previous_span=span
		if stalls>=3:break
	Input.action_release("move_forward")
	var final_span: float=hose.rig.strand.points[0].distance_to(hose.rig.strand.anchor)
	print("FPS PAYOUT FINAL: span=",final_span," steps=",rows.size()," last=",JSON.stringify(rows.back() if not rows.is_empty() else {}))
	bench.check(player._grab.holding_pickup() and final_span>=15.089,"actual FPS walking reaches the15.24m stock bound with150mm rigid-end allowance and1mm measurement tolerance")
	bench.check(hose.rig.strand.points[-1]==hose.rig.strand.anchor and final_span<=hose.rig.strand.total_length-.149 and hose.rig.strand.points.size()==hose.rig.rest.size() and Array(hose.rig.strand.points).all(func(p: Vector3):return p.is_finite()),"visual full payout keeps its fixed source, finite native skin and nominal stock reach bound")
	bench.check(_aim_error(player,joint)<1.,"fully paid-out FPS nozzle still aims along the reticle")
	bench.check(hose.visual_route.limited and player._grab.feedback({}).state=="limit","full payout reports the same authoritative reach limit through the reticle")
	bench.check(rows.all(func(row: Dictionary):return row.during_contacts.all(func(path: String):return path not in auxiliary_paths)),"actual payout walking never collides with attached carried hose parts")
	var directory:=OS.get_environment("SHOT_DIR")
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(directory)
		await RenderingServer.frame_post_draw
		bench.check(bench.get_viewport().get_texture().get_image().save_png(directory.path_join("full_payout_fps.png"))==OK,"full payout actual FPS view captured")
	if player._grab.active():bench.click()
	var resting: PackedVector3Array=hose.rig.strand.points.duplicate()
	for frame in 12:await bench.get_tree().physics_frame
	bench.check(hose.rig.strand.points==resting and not hose.is_processing() and not hose.is_physics_processing(),"released hose rests statically without a cloth solver or settling work")
	bench.check(not player._grab.active() and hose.contact.exclusions==hose._contact_exclusions,"next actual click releases full payout and restores query ownership")
	bench.check(auxiliary.all(func(row: Dictionary):return (not row.holder_added or not player.get_collision_exceptions().has(row.body)) and (not row.part_added or not row.body.get_collision_exceptions().has(player))),"release restores only the auxiliary collision exceptions owned by the hose")
	if not directory.is_empty():
		DirAccess.make_dir_recursive_absolute(directory)
		var file:=FileAccess.open(directory.path_join("fps_payout.json"),FileAccess.WRITE)
		if not bench.check(file!=null,"FPS payout diagnostic destination is writable"):return
		file.store_string(JSON.stringify({"evidence_class":"INERT","scope":"Owner-authorized visual hose; actual walking and FPS input on an isolated collision-bearing floor. No exact material conservation, physical cloth collision, building, water or save qualification.","span_m":final_span,"stock_m":hose.rig.strand.total_length,"elapsed_ms":Time.get_ticks_msec()-started,"steps":rows,"points":_points(hose.rig.strand.points),"motion_profiles":hose.motion_profile_records,"failures":bench.failures},"\t"));file.close()
