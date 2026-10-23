extends "res://tests/v2_golden_repair_profile.gd"
## INERT layout survey in the complete production world. No installation grant.
func _init() -> void:route_label="V2 UNRACKED HOSE WORLD SURVEY"

func _prepare_player_start() -> void:
	player.global_position=world.adapter.root.to_global(Vector3(1.925,.02,-3.5));player.velocity=Vector3.ZERO

func _play_route() -> void:
	player.profile_physics=true
	for target: Vector3 in [Vector3(1.925,1.6,1.3),Vector3(3.975,1.6,1.3),Vector3(3.975,3.2,-2.4),Vector3(3.65,3.2,-3.4)]:
		if not await _walk(target):return
	if OS.get_environment("ORISON_HOSE_SURVEY_CLEAR_STANCE")=="1":
		for target: Vector3 in [Vector3(3.65,3.2,-3.0),Vector3(4.5,3.2,-2.95)]:
			if not await _walk(target):return
	profile_phase="layout_survey_excluded"
	var native: RefCounted=world.adapter.root.get_meta("v2_native_fire_service")
	var rows: Array=[]
	var projection: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v2_unracked_fire_hose_rig.json"))
	var placement: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v2_unracked_fire_hose_placement.json"))
	var proposal_path: String=OS.get_environment("ORISON_HOSE_SURVEY_PLACEMENT")
	if not proposal_path.is_empty():placement=JSON.parse_string(FileAccess.get_file_as_string(proposal_path))
	for id: String in native.stations:
		if OS.get_environment("ORISON_HOSE_SURVEY_STATION")!="" and id!=OS.get_environment("ORISON_HOSE_SURVEY_STATION"):continue
		var actor: Node3D=native.stations[id].get_ref()
		var saved: Dictionary=actor.mechanism_snapshot()
		# Coupling is an explicit survey precondition, not claimed user assembly.
		actor.door_open=true;actor._refresh_cabinet();actor.nozzle_coupled=true;actor._nozzle_joint.restore_legacy(true)
		var hose:=preload("res://scripts/props/fire_unracked_hose.gd").new();actor.add_child(hose)
		hose.guide_enabled=proposal_path.is_empty();hose.ground_y_local=-1.2
		var start: int=Time.get_ticks_usec()
		var configured: bool=hose.configure(actor,"res://tests/fixtures/v2_unracked_fire_hose.glb",projection,placement)
		await get_tree().physics_frame;await get_tree().physics_frame
		var clear: bool=configured and hose.prepare_contact()
		var collider: Object=hose.contact.last_collider
		var row: Dictionary={"id":id,"configured":configured,"clear":clear,"error":hose.error,"prepare_ms":(Time.get_ticks_usec()-start)/1000.,"actor_transform":str(actor.global_transform),"collider":str(collider.get_path()) if collider is Node else str(collider),"player_collision_layer":player.collision_layer,"player_collision_mask":player.collision_mask}
		var stored: Dictionary={}
		for stock: Node3D in hose._stored:stored[stock]=[stock.visible,stock.is_processing()]
		if clear and id=="F02_FIRE_LINE_STAIR" and OS.get_environment("ORISON_HOSE_SURVEY_PULL")=="1":
			profile_phase="played_unrack_acquire_excluded"
			row.input=await _exercise_pull(actor,hose)
			profile_phase="layout_survey_excluded"
		if clear:
			var directory: String=OS.get_environment("SHOT_DIR")
			DirAccess.make_dir_recursive_absolute(directory)
			var frames: Array=[];var binds: Array=[]
			var posed: PackedVector3Array=hose.rig.strand.points if hose.deployed else hose._placement
			for frame: Transform3D in hose.rig.model_frames(posed):frames.append(_frame_row(frame))
			for frame: Transform3D in hose.rig.original_frames:binds.append(_frame_row(frame))
			FileAccess.open(directory.path_join(id+"_pose.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","deployed":hose.deployed,"frames":frames,"bind_frames":binds},"\t"))
			if hose.deployed:
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(directory.path_join(id+"_pull.png"))
		rows.append(row);print("UNRACKED WORLD STATION: ",JSON.stringify(row))
		if OS.get_environment("ORISON_HOSE_SURVEY_DIRECTIONS")=="1":
			for degrees: float in [30.,45.,60.,90.,120.,180.,240.,270.,300.,330.]:
				# Each contact owner binds once. Reuse cached immutable assets,
				# but create a fresh candidate and numerical placement per trial.
				var trial:=preload("res://scripts/props/fire_unracked_hose.gd").new();actor.add_child(trial)
				trial.guide_enabled=true;trial.ground_y_local=-1.2
				trial.guide_axis_local=Vector3.LEFT.rotated(Vector3.UP,deg_to_rad(degrees))
				trial.guide_side_local=Vector3.BACK.rotated(Vector3.UP,deg_to_rad(degrees))
				var fit: bool=trial.configure(actor,"res://tests/fixtures/v2_unracked_fire_hose.glb",projection,placement) and trial.prepare_contact()
				var hit: Object=trial.contact.last_collider
				var alternate: Dictionary={"id":id,"degrees":degrees,"clear":fit,"error":trial.error,"collider":str(hit.get_path()) if hit is Node else str(hit)}
				rows.append(alternate);print("UNRACKED WORLD DIRECTION: ",JSON.stringify(alternate))
				trial.free()
		for stock: Node3D in stored:stock.visible=stored[stock][0];stock.set_process(stored[stock][1])
		for body: CollisionObject3D in hose._stock_layers:body.collision_layer=hose._stock_layers[body]
		actor._nozzle_joint.receiver=hose._receiver;actor._nozzle_joint.hose_grip_provider=Callable()
		hose.free();actor.restore_mechanism(saved)
		await get_tree().physics_frame
	var directory: String=OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(directory)
	FileAccess.open(directory.path_join("layout_survey.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"complete-world layout diagnostic, no installed removal or runtime qualification","stations":rows,"failures":failures},"\t"))

func _frame_row(frame: Transform3D) -> Array:
	return [[frame.basis.x.x,frame.basis.x.y,frame.basis.x.z],[frame.basis.y.x,frame.basis.y.y,frame.basis.y.z],[frame.basis.z.x,frame.basis.z.y,frame.basis.z.z],[frame.origin.x,frame.origin.y,frame.origin.z]]

func _exercise_pull(actor: Node3D,hose: Node3D) -> Dictionary:
	var helper: Node=preload("res://tests/v2_fire_hand_bench.gd").new()
	helper.set_meta("shared_world_validation",true);helper.player=player;add_child(helper)
	actor._nozzle_joint.hose_grip_provider=hose.grip
	var picked:=false
	for point: Vector3 in [Vector3(0,.035,0),Vector3(0,.065,0),Vector3(0,.01,0)]:
		await helper.aim(actor._nozzle_joint.body.to_global(point))
		if player._grab.find_target().get("part")==actor._play_pipe:picked=true;break
	var inputs: Array=[]
	if picked:
		for frame in 4:await get_tree().process_frame
		profile_phase="played_unrack_input"
		helper.click()
		for step in 40:
			if not player._grab.active() or hose.deployed:break
			var point: Vector3=actor._play_pipe.to_global(player._grab.contact)
			var axis: Vector3=actor.global_basis*Vector3.BACK
			var screen: Vector2=(player.camera.unproject_position(point+axis*.01)-player.camera.unproject_position(point))/.01
			if screen.length()<24. and absf(axis.dot(player.camera.global_basis.z))>.5:screen=Vector2(0,axis.dot(player.camera.global_basis.z)*180.)
			var event:=InputEventMouseMotion.new();event.relative=screen*.008
			var start: int=Time.get_ticks_usec();player._unhandled_input(event)
			inputs.append({"step":step,"cpu_input_ms":(Time.get_ticks_usec()-start)/1000.,"extraction_m":hose.extraction,"error":hose.error,"feedback":player._grab.motion_feedback})
			await get_tree().process_frame
	if player._grab.active():helper.click()
	for frame in 3:await get_tree().process_frame
	var carry: Array=[]
	if hose.deployed:
		var initial: PackedVector3Array=hose.rig.strand.points.duplicate()
		var receiver: Transform3D=actor._nozzle_joint.receiver
		var eye: Transform3D=player.camera.global_transform
		var cycles: Array[String]=["single"]
		if OS.get_environment("ORISON_HOSE_LOCAL_COMPARE")=="1":cycles=["global_a","local_b","restored_a"]
		if OS.get_environment("ORISON_HOSE_CONTACT_COMPARE")=="1":cycles=["global_a","envelope_b","restored_a"]
		if OS.get_environment("ORISON_HOSE_COMBINED_COMPARE")=="1":cycles=["local_a","combined_b","restored_local_a"]
		if OS.get_environment("ORISON_HOSE_AIM_CONTROL")=="1":cycles=["aim_b"]
		hose.profile_motion=true
		hose.local_contacts_enabled=OS.get_environment("ORISON_HOSE_LOCAL_CONTACT")=="1"
		for cycle: String in cycles:
			profile_phase=cycle+"_pose_restore_excluded"
			hose.tether.cancel_motion();hose.set_process(false)
			if not _require(hose.rig.apply_points(initial),"control restores the same accepted cloth pose"):break
			hose.rig.strand.points=initial.duplicate();actor._nozzle_joint.receiver=receiver;actor._nozzle_joint.sync();hose.error=""
			player.camera.global_transform=eye
			if not _require(hose.set_local_follow(cycle in ["local_b","local_a","combined_b","restored_local_a","aim_b"]),"control applies the selected numerical seed"):break
			if not _require(not hose.contact.intersects_pose(initial),"control retains all world obstructions at its initial pose"):break
			var rows: Array=await _carry_control(actor,hose,helper,cycle)
			carry.append_array(rows)
			_require(rows.any(func(row: Dictionary):return row.progress_m>.0001),"actual unracked carry moves the original nozzle and full hose: "+cycle)
			profile_phase=cycle+"_pose_capture_excluded"
			var frames: Array=[];var binds: Array=[]
			for frame: Transform3D in hose.rig.model_frames(hose.rig.strand.points):frames.append(_frame_row(frame))
			for frame: Transform3D in hose.rig.original_frames:binds.append(_frame_row(frame))
			FileAccess.open(OS.get_environment("SHOT_DIR").path_join("F02_"+cycle+"_pose.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","frames":frames,"bind_frames":binds},"\t"))
	var result: Dictionary={"picked":picked,"deployed":hose.deployed,"events":inputs,"carry":carry,"error":hose.error,"released":not player._grab.active(),"player_position":str(player.global_position),"collision_mask":player.collision_mask}
	helper.free();return result

func _carry_control(actor: Node3D,hose: Node3D,helper: Node,cycle: String) -> Array:
	profile_phase=cycle+"_carry_acquire_excluded"
	var picked:=false
	for point: Vector3 in [Vector3(0,.155,.014),Vector3(0,.065,.020),Vector3(0,.04,.020)]:
		await helper.aim(actor._play_pipe.to_global(point))
		if player._grab.find_target().get("part")==actor._play_pipe:picked=true;break
	if not _require(picked,"control targets the same original nozzle: "+cycle):return []
	for frame in 4:await get_tree().process_frame
	profile_phase="played_unracked_carry_"+cycle
	helper.click()
	var rows: Array=[]
	for step in 8:
		if not player._grab.active():break
		var before: Vector3=hose.rig.strand.points[0]
		var point: Vector3=actor._play_pipe.to_global(player._grab.contact)
		var delta: Vector3=actor.global_basis*Vector3(-.002,.001,0)
		var event:=InputEventMouseMotion.new();event.relative=player.camera.unproject_position(point+delta)-player.camera.unproject_position(point)
		var start: int=Time.get_ticks_usec();player._unhandled_input(event)
		var cpu: float=(Time.get_ticks_usec()-start)/1000.
		var pending_frames:=0
		while hose.tether.pending and pending_frames<12:
			await get_tree().process_frame;pending_frames+=1
		var row: Dictionary={"cycle":cycle,"step":step,"cpu_input_ms":cpu,"pose_acceptance_ms":(Time.get_ticks_usec()-start)/1000.,"pending_frames":pending_frames,"progress_m":before.distance_to(hose.rig.strand.points[0]),"error":hose.error,"profile":hose.last_motion_profile.duplicate(true)}
		await RenderingServer.frame_post_draw
		row.feedback=player._grab.feedback({}).state
		rows.append(row);await get_tree().process_frame
	if player._grab.active():helper.click()
	profile_phase="played_unracked_release_"+cycle
	for frame in 3:await get_tree().process_frame
	return rows
