extends Node
## INERT query attribution. Exclusions affect isolated diagnostic queries only.
var world: Node3D
var player: PlayerController
var directory: String

func _ready() -> void:
	run.call_deferred()

func measure(excluded: Array[RID],motion: Vector3) -> Dictionary:
	var query:=PhysicsTestMotionParameters3D.new()
	query.from=player.global_transform;query.motion=motion
	query.margin=player.safe_margin;query.exclude_bodies=excluded
	var timings: Array=[]
	var hit:=false
	for repeat in 5:
		var started:=Time.get_ticks_usec()
		hit=PhysicsServer3D.body_test_motion(player.get_rid(),query)
		timings.append((Time.get_ticks_usec()-started)/1000.)
	return {"ms":timings,"hit":hit}

func run() -> void:
	directory=OS.get_environment("SHOT_DIR");DirAccess.make_dir_recursive_absolute(directory)
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	world=load("res://scenes/building/orison_v2_runtime.tscn").instantiate();add_child(world)
	if world.startup_failed:get_tree().quit(1);return
	player=world.player;player.set_physics_process(false)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
	await get_tree().physics_frame
	# Exact overlap queries omit large concave bounds whose triangles do not
	# touch the capsule. Attribute those query candidates by global exclusion
	# bisection, without changing any body's production layers or exceptions.
	var global_bodies: Array[PhysicsBody3D]=[]
	for body: PhysicsBody3D in world.find_children("*","PhysicsBody3D",true,false):
		if body!=player and (body.collision_layer&player.collision_mask)!=0:global_bodies.append(body)
	player.global_position=Vector3(-14.325,6.400265,-.575)
	var subject: Vector3=player.global_position+Vector3.FORWARD
	for surface in get_tree().get_nodes_in_group("planar_mirror_surface"):
		var cabinet: Node=surface.get_parent()
		while cabinet!=null and not cabinet.has_method("mirror_center"):cabinet=cabinet.get_parent()
		if cabinet!=null and str(cabinet.name)=="F03_3B_MIRROR_01":subject=cabinet.mirror_center();break
	player.face_world_point(subject)
	for tick in 20:await get_tree().physics_frame
	for frame in 8:await RenderingServer.frame_post_draw
	var published:=state()
	var attribution_motion:=Vector3(.05,0,0)
	var baseline: Dictionary=measure([],attribution_motion)
	var remaining: Array[PhysicsBody3D]=global_bodies.duplicate()
	var attribution: Array=[]
	var reason: String="stable query below 1ms; no expensive owner established"
	while remaining.size()>1:
		var restored_before:=measure([],attribution_motion)
		if median(restored_before.ms)<1.:break
		var half: int=remaining.size()/2
		var left: Array[RID]=[];var right: Array[RID]=[]
		for index in remaining.size():
			if index<half:left.append(remaining[index].get_rid())
			else:right.append(remaining[index].get_rid())
		var without_left:=measure(left,attribution_motion);var without_right:=measure(right,attribution_motion)
		var restored_after:=measure([],attribution_motion)
		attribution.append({"candidates":remaining.size(),"restored_before":restored_before,"without_left":without_left,"without_right":without_right,"restored_after":restored_after})
		if absf(median(restored_before.ms)-median(restored_after.ms))>maxf(.1,median(restored_before.ms)*.15):
			reason="restored baseline drifted; attribution rejected";break
		if absf(median(without_left.ms)-median(without_right.ms))<median(restored_before.ms)*.15:
			reason="cost not isolated by either half; no single owner established";break
		remaining=remaining.slice(0,half) if median(without_left.ms)<median(without_right.ms) else remaining.slice(half)
		# No yield within a paired restored-baseline attribution sequence.
	var result: Dictionary={"evidence_class":"INERT","state":published,"baseline":baseline,"body_count":global_bodies.size(),"steps":attribution,"reason":reason}
	if remaining.size()==1:
		result.suspect=str(remaining[0].get_path());result.suspect_excluded=measure([remaining[0].get_rid()],attribution_motion)
	FileAccess.open(directory.path_join("global_attribution.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	var live: Array=[]
	player.profile_physics=true;player.physics_profile_records.clear();player.set_physics_process(true)
	for tick in 120:
		if tick==0:key(KEY_A,true)
		if tick==12:key(KEY_A,false)
		if tick==36:key(KEY_D,true)
		if tick==48:key(KEY_D,false)
		if tick<48:
			var turn:=InputEventMouseMotion.new();turn.relative=Vector2(1.5 if tick<24 else -1.5,0);Input.parse_input_event(turn)
		await get_tree().physics_frame
		if tick%12==0:
			var before_draw: Dictionary={"tick":tick,"state":state(),"query":measure([],attribution_motion)}
			await RenderingServer.frame_post_draw
			before_draw.after_draw=measure([],attribution_motion);live.append(before_draw)
	key(KEY_A,false);key(KEY_D,false);player.set_physics_process(false)
	FileAccess.open(directory.path_join("live_query.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","samples":live,"physics":player.physics_profile_records,"limits":"Queries add work to this diagnostic route. Not a before/after wall-time benchmark."},"\t"))
	await chunk_controls(subject)
	var records: Array=[]
	for feet: Vector3 in [Vector3(-14.325,6.400265,-.575),Vector3(-14.684,6.700265,-.303697)]:
		player.global_position=feet
		await get_tree().physics_frame
		var box:=BoxShape3D.new();box.size=Vector3(3,3,3)
		var spatial:=PhysicsShapeQueryParameters3D.new();spatial.shape=box
		spatial.transform=Transform3D(Basis.IDENTITY,feet+Vector3.UP*.8)
		spatial.collision_mask=player.collision_mask;spatial.exclude=[player.get_rid()]
		var hits:=player.get_world_3d().direct_space_state.intersect_shape(spatial,512)
		var bodies: Dictionary={}
		for hit: Dictionary in hits:
			if hit.collider is PhysicsBody3D:bodies[hit.collider.get_instance_id()]=hit.collider
		var all: Array[RID]=[]
		for body: PhysicsBody3D in bodies.values():all.append(body.get_rid())
		var motions: Array=[]
		for motion: Vector3 in [Vector3(.05,0,0),Vector3(0,-.01,0),Vector3(0,0,.05)]:
			var row: Dictionary={"motion":str(motion),"baseline":measure([],motion),"all_nearby_excluded":measure(all,motion),"owners":[]}
			for body: PhysicsBody3D in bodies.values():
				var geometry: Array=[]
				for shape: CollisionShape3D in body.find_children("*","CollisionShape3D",true,false):
					geometry.append({"type":shape.shape.get_class(),"triangles":shape.shape.get_faces().size()/3 if shape.shape is ConcavePolygonShape3D else 0})
				row.owners.append({"path":str(body.get_path()),"shapes":geometry,"excluded":measure([body.get_rid()],motion)})
			motions.append(row)
			await get_tree().process_frame
		records.append({"feet":str(feet),"query_hits":hits.size(),"unique_bodies":bodies.size(),"motions":motions})
	FileAccess.open(directory.path_join("collision_cost.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","records":records,"limits":"Synchronous isolated body_test_motion queries at two observed production positions; no bypass installed and no runtime qualification."},"\t"))
	print("BATH COLLISION COST: PASS diagnostic only")
	get_tree().quit()

func median(values: Array) -> float:
	var sorted:=values.duplicate();sorted.sort();return float(sorted[sorted.size()/2])

func key(code: Key,pressed: bool) -> void:
	var event:=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=pressed;Input.parse_input_event(event)

func state() -> Dictionary:
	return {"physics_frame":Engine.get_physics_frames(),"render_frame":Engine.get_process_frames(),"engine":ProjectSettings.get_setting("physics/3d/physics_engine","DEFAULT"),"basis":str(player.global_basis),"server_pose":str(PhysicsServer3D.body_get_state(player.get_rid(),PhysicsServer3D.BODY_STATE_TRANSFORM)),"node_pose":str(player.global_transform),"capsule_radius":player._capsule.radius,"capsule_height":player._capsule.height,"shape_pose":str(player._shape.transform),"safe_margin":player.safe_margin,"exceptions":player.get_collision_exceptions().size(),"position":str(player.global_position)}

func chunk_controls(subject: Vector3) -> void:
	var shapes: Array[Dictionary]=[]
	for body: PhysicsBody3D in world.find_children("*","PhysicsBody3D",true,false):
		if not str(body.get_path()).contains("F03_3B_SINK_01/FixtureBody") and not str(body.get_path()).contains("3B_wc/FixedCastingCollision"):continue
		for shape: CollisionShape3D in body.get_children():
			if not shape.shape is ConcavePolygonShape3D:continue
			shapes.append({"original":shape,"chunks":[]})
			for partition: ConcavePolygonShape3D in preload("res://scripts/props/native_collision_chunks.gd").build_mesh_faces(shape.shape.get_faces()):
				var node:=CollisionShape3D.new();node.shape=partition;node.transform=shape.transform;node.disabled=true;body.add_child(node)
				shapes[-1].chunks.append(node)
	var phases: Array=[]
	for label: String in ["original","chunked","restored"]:
		for row: Dictionary in shapes:
			row.original.disabled=label=="chunked"
			for chunk: CollisionShape3D in row.chunks:chunk.disabled=label!="chunked"
		player.global_position=Vector3(-14.325,6.400265,-.575);player.velocity=Vector3.ZERO;player.face_world_point(subject)
		player.set_physics_process(true)
		for tick in 20:await get_tree().physics_frame
		for frame in 8:await RenderingServer.frame_post_draw
		player.physics_profile_records.clear()
		var start: Dictionary=state();var query:=measure([],Vector3(.05,0,0))
		for tick in 120:
			if tick==0:key(KEY_A,true)
			if tick==12:key(KEY_A,false)
			if tick==36:key(KEY_D,true)
			if tick==48:key(KEY_D,false)
			if tick<48:
				var turn:=InputEventMouseMotion.new();turn.relative=Vector2(1.5 if tick<24 else -1.5,0);Input.parse_input_event(turn)
			await get_tree().physics_frame
		key(KEY_A,false);key(KEY_D,false);player.set_physics_process(false)
		phases.append({"phase":label,"start":start,"end":state(),"query":query,"slow_physics":player.physics_profile_records.duplicate(true)})
	var counts: Array=[]
	for row: Dictionary in shapes:
		counts.append({"original":str(row.original.get_path()),"triangles":row.original.shape.get_faces().size()/3,"chunks":row.chunks.size()})
		for chunk: CollisionShape3D in row.chunks:chunk.free()
	FileAccess.open(directory.path_join("chunk_controls.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","phases":phases,"shapes":counts,"limits":"Exact triangle repartition candidate; original/chunked/restored actual keys and turns. No rendering or contact bypass."},"\t"))
