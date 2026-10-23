extends "res://tests/v2_fire_hand_bench.gd"
## Installed-owner fixture, actual input and loaded surface diagnostics only.
## This does not grant playable-world, water, save or human acceptance.
func _run() -> void:
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	var adapter:=FixtureAdapter.new();adapter.root=Node3D.new();add_child(adapter.root)
	var reserve:=MeshInstance3D.new();reserve.name="FIRE_SERVICE_RISER";adapter.root.add_child(reserve)
	var native:=Native.new()
	if not check(native.mount(adapter,{"levels":[{"y":0.}]}),"production cabinet installer mounts"):
		print(native.errors);get_tree().quit(1);return
	var actor: Node3D=native.stations.values()[0].get_ref()
	var ground:=StaticBody3D.new();var ground_shape:=CollisionShape3D.new();var ground_box:=BoxShape3D.new()
	ground_box.size=Vector3(40,.2,10);ground_shape.shape=ground_box;ground.add_child(ground_shape);add_child(ground);ground.position=Vector3(-12,-.1,0)
	for station: WeakRef in native.stations.values():
		var other: Node3D=station.get_ref()
		if other!=actor:other.free()
	actor.door_open=true;actor._refresh_cabinet()
	var joint: Node3D=actor._nozzle_joint
	actor.nozzle_coupled=true
	joint.restore_legacy(true)
	var hose:=preload("res://scripts/props/fire_unracked_hose.gd").new();hose.name="CandidateUnrackedHose";actor.add_child(hose)
	hose.guide_enabled=OS.get_environment("ORISON_UNRACKED_GUIDE")=="1";hose.ground_y_local=-1.2
	var projection: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v2_unracked_fire_hose_rig.json"))
	var placement: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v2_unracked_fire_hose_placement.json"))
	if OS.get_environment("ORISON_UNRACKED_FLOOR")=="1":placement=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/v2_unracked_floor_hose_placement.json"))
	if not check(hose.configure(actor,"res://tests/fixtures/v2_unracked_fire_hose.glb",projection,placement),"135-ring separate round hose prepares before input"):
		print("UNRACKED SETUP ERROR: ",hose.error);get_tree().quit(1);return
	var metrics: Node=preload("res://tests/orison_v2_domestic_native_test.gd").new()
	for draw: MeshInstance3D in hose.model.find_children("*","MeshInstance3D",true,false):
		metrics._check_cap_mapping(draw.mesh,true)
		var finish: StandardMaterial3D=draw.material_override
		for texture: Texture2D in [finish.albedo_texture,finish.normal_texture,finish.roughness_texture]:
			check(texture!=null and texture.get_image().get_mipmap_count()>0,"unracked custom PBR map has loaded mipmaps")
	for failure: String in metrics.failures:check(false,failure)
	metrics.free()
	var lamp:=DirectionalLight3D.new();lamp.rotation_degrees=Vector3(-35,-25,0);lamp.light_energy=1.3;add_child(lamp)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new();add_child(environment)
	environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color(.12,.12,.12)
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_energy=.6
	player=PlayerController.new();add_child(player);player.set_physics_process(false)
	# This isolated camera follows the held part without walking. Its capsule
	# must not become a moving obstacle inside the diagnostic hose. Production
	# player collision remains unchanged and needs a separate played-world run.
	player.collision_layer=0;player.collision_mask=0
	check(player.collision_layer==0,"isolated following camera has no physical player capsule in the hose route")
	player.global_position=actor.to_global(Vector3(-.3,.15,.70))-player.camera.position
	player.camera.make_current();player.camera.look_at(joint.body.global_position)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	for frame in 8:await get_tree().physics_frame
	if not check(hose.prepare_contact(),"native annular world queries and short solver initialize"):
		print("UNRACKED CONTACT ERROR: ",hose.error);get_tree().quit(1);return
	if OS.get_environment("ORISON_UNRACKED_LOCAL")=="1":
		check(hose.set_local_follow(true),"optional local numerical seed prepares before input")
		hose.profile_motion=true
	joint.hose_grip_provider=hose.grip
	check(not hose.deployed and not hose.model.visible and not hose.is_processing() and not hose.is_physics_processing(),"stored representation has no running hose simulation")
	var initially_clear: bool=not hose.contact.intersects_pose(hose._placement)
	print("UNRACKED READY: setup_ms=",hose.setup_ms," initial_placement_clear=",initially_clear," collider=",hose.contact.last_collider.get_path() if hose.contact.last_collider!=null else "none")
	var pick:=false
	for local: Vector3 in [Vector3(0,.035,0),Vector3(0,.065,0),Vector3(0,.01,0)]:
		await aim(joint.body.to_global(local))
		if player._grab.find_target().get("part")==actor._play_pipe:pick=true;break
	if check(pick,"actual nozzle surface targets the rack extraction owner"):
		var deployment_blocker:=StaticBody3D.new();var deployment_shape:=CollisionShape3D.new();var deployment_box:=BoxShape3D.new()
		deployment_box.size=Vector3(.15,.15,.15);deployment_shape.shape=deployment_box;deployment_blocker.add_child(deployment_shape);add_child(deployment_blocker)
		deployment_blocker.global_position=hose.model.to_global(hose._placement[65])
		await get_tree().physics_frame;await get_tree().physics_frame
		var before: Transform3D=joint.body.transform
		click()
		check(player._grab.active() and actor._hand=="hose" and joint.body.transform==before and not hose.deployed,"primary click grabs without removing or moving the stored hose")
		for step in 40:
			if hose.deployed:break
			var target: Dictionary=player._grab.target
			var point: Vector3=target.part.to_global(player._grab.contact)
			var axis: Vector3=actor.global_basis*Vector3.BACK
			var screen: Vector2=(player.camera.unproject_position(point+axis*.01)-player.camera.unproject_position(point))/.01
			if screen.length()<24. and absf(axis.dot(player.camera.global_basis.z))>.5:screen=Vector2(0,axis.dot(player.camera.global_basis.z)*180.)
			var event:=InputEventMouseMotion.new();event.relative=screen*.006
			player._unhandled_input(event);await get_tree().physics_frame
		check(not hose.deployed and not hose.model.visible and actor.hose_racked and hose.error=="unracked placement obstructed","a real distant obstruction prevents the representation swap")
		deployment_blocker.free();await get_tree().physics_frame;await get_tree().physics_frame
		var last_event:=InputEventMouseMotion.new()
		var last_point: Vector3=actor._play_pipe.to_global(player._grab.contact)
		var last_axis: Vector3=actor.global_basis*Vector3.BACK
		var last_screen: Vector2=(player.camera.unproject_position(last_point+last_axis*.01)-player.camera.unproject_position(last_point))/.01
		if last_screen.length()<24. and absf(last_axis.dot(player.camera.global_basis.z))>.5:last_screen=Vector2(0,last_axis.dot(player.camera.global_basis.z)*180.)
		last_event.relative=last_screen*.008;player._unhandled_input(last_event)
		await get_tree().physics_frame
		print("UNRACKED EXTRACTION: deployed=",hose.deployed," distance=",hose.extraction," error=",hose.error," collider=",hose.contact.last_collider.get_path() if hose.contact.last_collider!=null else "none")
		check(hose.deployed and hose.model.visible and not actor.hose_racked,"actual mouse pull replaces stored stock with full-length round hose")
		if player._grab.active():click()
		check(not player._grab.active() and actor._hand.is_empty(),"second click releases extraction")
	var input_ms: Array[float]=[]
	if hose.deployed:
		if not check(await _aim_nozzle_surface(actor,joint),"unracked nozzle remains the actual carry target"):
			get_tree().quit(1);return
		var initial: PackedVector3Array=hose.rig.strand.points.duplicate()
		click()
		if not check(player._grab.active() and actor._hand=="hose" and player._grab.target.part==actor._play_pipe and hose.rig.strand.points==initial,"regrabbing the actual unracked nozzle does not snap the hose"):
			get_tree().quit(1);return
		for step in 16:
			var point: Vector3=actor._play_pipe.to_global(player._grab.contact)
			var displacement: Vector3=actor.global_basis*Vector3(-.004,.001,0)
			var event:=InputEventMouseMotion.new()
			event.relative=player.camera.unproject_position(point+displacement)-player.camera.unproject_position(point)
			var started: int=Time.get_ticks_usec();player._unhandled_input(event)
			# The isolated camera disables player physics. Drive the same hand
			# publication normally called by PlayerController after mouse input.
			player._grab.follow_holder()
			input_ms.append((Time.get_ticks_usec()-started)/1000.)
			for frame in 8:
				if not hose.tether.pending:break
				await get_tree().process_frame
			await get_tree().physics_frame
		check(hose.rig.strand.points[0].distance_to(initial[0])>.01 and hose.rig.strand._valid_positions(hose.rig.strand.points) and not hose.contact.intersects_pose(hose.rig.strand.points),"actual unracked mouse carry moves the full material without stretching or world penetration")
		print("UNRACKED CARRY: moved=",hose.rig.strand.points[0].distance_to(initial[0])," error=",hose.error," input_ms=",input_ms)
		for step in 8:
			var wheel:=InputEventMouseButton.new();wheel.button_index=MOUSE_BUTTON_WHEEL_UP;wheel.pressed=true
			player._unhandled_input(wheel)
			player._grab.follow_holder()
			for frame in 32:
				if not hose.tether.pending:break
				await get_tree().process_frame
			await get_tree().physics_frame
		var bounds:=AABB(joint.body.global_position,Vector3.ZERO)
		for shape: CollisionShape3D in joint.body.get_children():
			if shape.disabled or not shape.shape is ConvexPolygonShape3D:continue
			for vertex: Vector3 in shape.shape.points:bounds=bounds.expand(shape.to_global(vertex))
		var carry_blocker:=StaticBody3D.new();var carry_shape:=CollisionShape3D.new();var carry_box:=BoxShape3D.new()
		carry_shape.shape=carry_box;carry_blocker.add_child(carry_shape);add_child(carry_blocker)
		var direction:=Vector3.ZERO
		for option: Vector3 in [Vector3.RIGHT,Vector3.UP,Vector3.LEFT,Vector3.DOWN]:
			var axis: int=option.abs().max_axis_index()
			carry_box.size=bounds.size+Vector3.ONE*.4;carry_box.size[axis]=.01
			var center: Vector3=bounds.get_center();center[axis]=(bounds.end[axis] if option[axis]>0. else bounds.position[axis])+option[axis]*.03
			carry_blocker.global_position=center
			await get_tree().physics_frame;await get_tree().physics_frame
			var sight:=PhysicsRayQueryParameters3D.create(player.camera.global_position,actor._play_pipe.to_global(player._grab.contact),1,[player.get_rid()])
			var hit: Dictionary=get_world_3d().direct_space_state.intersect_ray(sight)
			if not hose.contact.intersects_pose(hose.rig.strand.points) and hit.get("collider")!=carry_blocker:direction=option;break
		check(direction!=Vector3.ZERO and player._grab.active(),"carry blocker begins outside the accepted hose without stealing the held sightline")
		var stopped: PackedVector3Array=hose.rig.strand.points.duplicate()
		var contact_point: Vector3=actor._play_pipe.to_global(player._grab.contact)
		var blocked_event:=InputEventMouseMotion.new()
		blocked_event.relative=player.camera.unproject_position(contact_point+direction*.05)-player.camera.unproject_position(contact_point)
		# FPS mouse motion turns the view; keep requesting movement until the
		# hand actually reaches the barrier instead of assuming a pixel drag
		# is an exact five-centimetre world-space displacement.
		var blocked_feedback:=""
		for attempt in 16:
			player._unhandled_input(blocked_event)
			player._grab.follow_holder()
			for frame in 8:
				if not hose.tether.pending:break
				await get_tree().process_frame
			await get_tree().physics_frame;await get_tree().physics_frame
			player._grab.validate()
			blocked_feedback=player._grab.feedback({}).state
			if blocked_feedback=="blocked":break
		await get_tree().physics_frame;player._grab.validate()
		print("UNRACKED BLOCK: direction=",direction," wall=",carry_blocker.global_transform," delta=",hose.rig.strand.points[0]-stopped[0]," error=",hose.error," feedback=",player._grab.motion_feedback," clear=",not hose.contact.intersects_pose(hose.rig.strand.points))
		check(not hose.contact.intersects_pose(hose.rig.strand.points) and hose._nozzle_clear(joint.receiver),"actual nozzle carry retains physical obstruction protection")
		check(blocked_feedback=="blocked","reticle reads blocked carry from the same accepted motion state")
		carry_blocker.free();await get_tree().physics_frame
		var before_release: PackedVector3Array=hose.rig.strand.points.duplicate()
		if player._grab.active():click()
		for frame in 3:await get_tree().physics_frame
		check(not player._grab.active() and not hose.tether.pending and hose.rig.strand.points==before_release,"second click cancels pending hose carry and preserves its accepted pose")
		if OS.get_environment("ORISON_UNRACKED_FULL_PAYOUT")=="1" and failures.is_empty():await _full_payout(actor,hose,joint)
	var out:=OS.get_environment("SHOT_DIR")
	if not out.is_empty():
		DirAccess.make_dir_recursive_absolute(out)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("extraction.png"))
		var seed_rows: Array=[]
		for point: Vector3 in hose.tether.last_seed_points:seed_rows.append([point.x,point.y,point.z])
		FileAccess.open(out.path_join("diagnostic.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","setup_ms":hose.setup_ms,"deployed":hose.deployed,"error":hose.error,"input_ms":input_ms,"seeded_candidates":hose.tether.seeded_candidates,"seeded_accepts":hose.tether.seeded_accepts,"last_seed_bend_error_m":hose.tether.last_seed_bend_error,"last_seed_material_valid":hose.tether.last_seed_material_valid,"last_seed_points":seed_rows,"bend_spans":Array(hose.tether.kernel.bend_spans),"pose":hose.rig.snapshot(),"bind_frames":_frame_rows(hose.rig.original_frames),"frames":_frame_rows(hose.rig.model_frames(hose.rig.strand.points)),"observations":observations,"failures":failures},"\t"))
	print("V2 UNRACKED HOSE: ","PASS" if failures.is_empty() else "FAIL"," failures=",failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)

func _frame_rows(frames: Array[Transform3D]) -> Array:
	var rows: Array=[]
	for frame: Transform3D in frames:rows.append([Array([frame.basis.x.x,frame.basis.x.y,frame.basis.x.z]),Array([frame.basis.y.x,frame.basis.y.y,frame.basis.y.z]),Array([frame.basis.z.x,frame.basis.z.y,frame.basis.z.z]),Array([frame.origin.x,frame.origin.y,frame.origin.z])])
	return rows

func _aim_nozzle_surface(actor: Node3D,joint: Node3D) -> bool:
	var barrel: MeshInstance3D
	for draw: MeshInstance3D in actor._play_pipe.find_children("*","MeshInstance3D",true,false):
		if str(draw.get_meta("native_fire_part",""))=="F059":barrel=draw;break
	if barrel==null or barrel.mesh==null:return false
	var faces: PackedVector3Array=barrel.mesh.get_faces()
	var center: Vector3=barrel.to_global(barrel.mesh.get_aabb().get_center())
	for view in 4:
		if view>0:
			var offset: Vector3=joint.body.global_basis.z*(.65 if view==1 else -.65) if view<3 else Vector3(0,.2,.65)
			player.global_position=center+offset-player.camera.position
			player.camera.look_at(center)
			await get_tree().physics_frame;await get_tree().physics_frame
		var candidates: Array[Dictionary]=[]
		for index in range(0,faces.size(),3):
			var a: Vector3=barrel.to_global(faces[index]);var b: Vector3=barrel.to_global(faces[index+1]);var c: Vector3=barrel.to_global(faces[index+2])
			if player.camera.is_position_behind(a) or player.camera.is_position_behind(b) or player.camera.is_position_behind(c):continue
			var area: float=absf((player.camera.unproject_position(b)-player.camera.unproject_position(a)).cross(player.camera.unproject_position(c)-player.camera.unproject_position(a)))
			candidates.append({"at":(a+b+c)/3.,"area":area})
		candidates.sort_custom(func(a: Dictionary,b: Dictionary):return a.area>b.area)
		for index in mini(64,candidates.size()):
			await aim(candidates[index].at)
			if player._grab.find_target().get("part")==actor._play_pipe:return true
	return false

func _full_payout(actor: Node3D,hose: Node3D,joint: Node3D) -> void:
	# The diagnostic camera follows with player physics disabled. This is
	# actual mouse handling, not a playable-building traversal claim.
	var pick: Vector3=joint.body.to_global(Vector3(.008,.12,.008))
	player.global_position=pick+Vector3(0,0,.65)-player.camera.position
	player.camera.global_basis=Basis.IDENTITY;Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	for frame in 3:await get_tree().physics_frame
	if not check(await _aim_nozzle_surface(actor,joint),"long payout selects the original native nozzle"):return
	click()
	var before_clearance: Vector3=joint.body.global_position
	for step in 10:
		var wheel:=InputEventMouseButton.new();wheel.button_index=MOUSE_BUTTON_WHEEL_UP;wheel.pressed=true
		player._unhandled_input(wheel)
		for frame in 32:
			if not hose.tether.pending:break
			await get_tree().process_frame
		await get_tree().physics_frame
	var frontmost:=INF
	for shape: CollisionShape3D in joint.body.get_children():
		if shape.disabled or not shape.shape is ConvexPolygonShape3D:continue
		for vertex: Vector3 in shape.shape.points:frontmost=minf(frontmost,actor.to_local(shape.to_global(vertex)).z)
	check(joint.body.global_position.distance_to(before_clearance)>.01 and frontmost>.2066,"actual depth input reaches a nozzle pose wholly clear of the cabinet front before lateral travel")
	var records: Array=[];var poses: Array=[];var gesture_m:=.055
	for step in 3000:
		if not player._grab.active():check(false,"long payout retains actual hand ownership");break
		var before: PackedVector3Array=hose.rig.strand.points.duplicate()
		var span: float=before[0].distance_to(hose.rig.strand.anchor)
		if span>=15.09:break
		var point: Vector3=actor._play_pipe.to_global(player._grab.contact)
		var displacement: Vector3=actor.global_basis*Vector3.LEFT*minf(gesture_m,15.10-span)
		var event:=InputEventMouseMotion.new()
		event.relative=player.camera.unproject_position(point+displacement)-player.camera.unproject_position(point)
		var started: int=Time.get_ticks_usec();player._unhandled_input(event)
		var input_ms: float=(Time.get_ticks_usec()-started)/1000.
		var pending_frames:=0
		for frame in 32:
			if not hose.tether.pending:break
			pending_frames+=1;await get_tree().process_frame
		var latency_ms: float=(Time.get_ticks_usec()-started)/1000.
		var moved: Vector3=hose.rig.strand.points[0]-before[0]
		records.append({"step":step,"gesture_m":gesture_m,"input_ms":input_ms,"pose_latency_ms":latency_ms,"pending_frames":pending_frames,"span_m":hose.rig.strand.points[0].distance_to(hose.rig.strand.anchor),"error":hose.error,"collider":str(hose.contact.last_collider.get_path()) if hose.contact.last_collider!=null else ""})
		if step%64==0:poses.append({"step":step,"pose":hose.rig.snapshot(),"bind_frames":_frame_rows(hose.rig.original_frames),"frames":_frame_rows(hose.rig.model_frames(hose.rig.strand.points))})
		player.global_position+=hose.model.global_basis*moved
		await get_tree().physics_frame
		if moved.length()<.000001:
			if gesture_m>.001:gesture_m*=.5;continue
			print("UNRACKED PAYOUT STALLED: step=",step," span=",span," error=",hose.error," pending=",hose.tether.pending)
			check(false,"long payout makes progress before the physical reach limit");break
		gesture_m=minf(.055,gesture_m*1.2)
	check(hose.rig.strand.points[0].distance_to(hose.rig.strand.anchor)>=15.09 and hose.rig.strand._valid_positions(hose.rig.strand.points),"actual nozzle input deploys the full15.24m material within150mm rigid-end span allowance")
	if player._grab.active():click()
	poses.append({"step":records.size(),"pose":hose.rig.snapshot(),"bind_frames":_frame_rows(hose.rig.original_frames),"frames":_frame_rows(hose.rig.model_frames(hose.rig.strand.points))})
	var out:=OS.get_environment("SHOT_DIR")
	if not out.is_empty():
		DirAccess.make_dir_recursive_absolute(out)
		FileAccess.open(out.path_join("payout.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","scope":"Actual mouse payout in isolated installed-owner fixture; following camera and player physics disabled. No world-travel, water, save, self-contact or runtime qualification.","steps":records,"poses":poses,"failures":failures},"\t"))
