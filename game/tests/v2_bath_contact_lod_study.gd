extends Node
## INERT original/candidate/restored study. No production installation.
var world: Node3D
var player: PlayerController
var directory: String
var samples: Array=[]
var phase: String
var previous: int
var failures: Array[String]=[]
var installed_only:=false
func _ready() -> void:
	set_process(false);run.call_deferred()
func _process(_delta: float) -> void:
	var now:=Time.get_ticks_usec()
	samples.append({"phase":phase,"wall_ms":(now-previous)/1000.,"physics_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.,"process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000.,"render_cpu_ms":RenderingServer.viewport_get_measured_render_time_cpu(get_viewport().get_viewport_rid()),"render_gpu_ms":RenderingServer.viewport_get_measured_render_time_gpu(get_viewport().get_viewport_rid()),"pipeline_surface":Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE),"pipeline_draw":Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)})
	previous=now
func key(code: Key,pressed: bool) -> void:
	var event:=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=pressed;Input.parse_input_event(event)
func measure() -> Array:
	var query:=PhysicsTestMotionParameters3D.new();query.from=player.global_transform;query.motion=Vector3(.05,0,0);query.margin=player.safe_margin
	var times: Array=[]
	for repeat in 5:
		var started:=Time.get_ticks_usec();PhysicsServer3D.body_test_motion(player.get_rid(),query);times.append((Time.get_ticks_usec()-started)/1000.)
	return times
func installed_interactions() -> Dictionary:
	return {}
func run() -> void:
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests();GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	directory=OS.get_environment("SHOT_DIR");DirAccess.make_dir_recursive_absolute(directory)
	world=load("res://scenes/building/orison_v2_runtime.tscn").instantiate();add_child(world)
	if world.startup_failed:get_tree().quit(1);return
	player=world.player;player.set_physics_process(false);player.profile_physics=true
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED;DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED);Engine.max_fps=0
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
	world.service_set_carrier.set_capture_hidden(true);player.set_lamp_enabled(false)
	# Keep the same warmed reflection work for each phase; streaming is not a treatment.
	world.get_node("V2RoomReflections").set_physics_process(false)
	var mirror: Node3D
	for surface in get_tree().get_nodes_in_group("planar_mirror_surface"):
		var owner: Node=surface.get_parent()
		while owner!=null and not owner.has_method("mirror_center"):owner=owner.get_parent()
		if owner!=null and str(owner.name)=="F03_3B_MIRROR_01":mirror=owner;break
	if mirror==null:get_tree().quit(1);return
	var switches: SwitchSystem=world.get_node("V2RoomSwitches");var saved:=switches.room_snapshot("F03_B_BATH");var lit: Dictionary={}
	for id: String in saved:lit[id]=true
	switches.restore_room("F03_B_BATH",lit)
	var rows: Array=[]
	for spec: Array in [["F03_3B_SINK_01","FixtureBody","bath_lavatory"],["3B_wc","FixedCastingCollision","bath_water_closet"]]:
		var fixture: Node3D=world.find_child(spec[0],true,false)
		if fixture==null:failures.append("missing fixture "+spec[0]);continue
		var body: StaticBody3D=fixture.get_node(spec[1]);var originals: Array=[]
		if installed_only:
			if body.get_meta("native_contact_family","")!=spec[2]:failures.append("production contact stock missing: "+spec[0])
			continue
		for node in body.get_children():
			if node is CollisionShape3D:originals.append(node)
		var retained: Array=[]
		# After installation, reconstruct the exact old visual-mesh baseline
		# locally rather than mislabelling the new production contacts "original".
		if body.has_meta("native_contact_family"):
			retained=originals.duplicate();originals=[]
			for shape: CollisionShape3D in retained:shape.disabled=true
			var fixed: Node=fixture.get_node("StaticFixture") if spec[2]=="bath_lavatory" else fixture.find_child("WaterClosetCasting",true,false)
			for draw: MeshInstance3D in fixed.find_children("*","MeshInstance3D",true,false):
				if draw.name in ["WaterSeal","StoredWater"]:continue
				var shape:=CollisionShape3D.new();shape.shape=draw.mesh.create_trimesh_shape();body.add_child(shape);shape.global_transform=draw.global_transform;originals.append(shape)
		var candidate: Node3D=(load("res://assets/props/"+spec[2]+"_contact.glb") as PackedScene).instantiate();fixture.add_child(candidate)
		var shapes: Array=[];var triangles:=0
		for draw: MeshInstance3D in candidate.find_children("*","MeshInstance3D",true,false):
			var shape:=CollisionShape3D.new();shape.shape=draw.mesh.create_trimesh_shape();shape.disabled=true;body.add_child(shape);shape.global_transform=draw.global_transform
			triangles+=draw.mesh.get_faces().size()/3;shapes.append(shape)
		candidate.free()
		rows.append({"fixture":spec[0],"originals":originals,"candidates":shapes,"retained":retained,"triangles":triangles})
	if not installed_only and rows.size()!=2:failures.append("two candidate families required")
	var records: Array=[]
	var labels: Array=["installed"] if installed_only else ["original","candidate","restored"]
	for label: String in labels:
		for row: Dictionary in rows:
			for shape: CollisionShape3D in row.originals:shape.disabled=label=="candidate"
			for shape: CollisionShape3D in row.candidates:shape.disabled=label!="candidate"
		player.global_position=Vector3(-14.325,6.400265,-.575);player.velocity=Vector3.ZERO;player.face_world_point(mirror.mirror_center());player.set_physics_process(true)
		for tick in 20:await get_tree().physics_frame
		for frame in 8:await RenderingServer.frame_post_draw
		var start:=player.global_position;var query:=measure();player.physics_profile_records.clear()
		phase=label;previous=Time.get_ticks_usec();set_process(true)
		for tick in 240:
			if tick==0:key(KEY_A,true)
			if tick==12:key(KEY_A,false)
			if tick==36:key(KEY_D,true)
			if tick==48:key(KEY_D,false)
			if tick<48:
				var event:=InputEventMouseMotion.new();event.relative=Vector2(1.5 if tick<24 else -1.5,0);Input.parse_input_event(event)
			await get_tree().physics_frame
		set_process(false);key(KEY_A,false);key(KEY_D,false);player.set_physics_process(false)
		records.append({"phase":label,"start":str(start),"end":str(player.global_position),"query_ms":query,"slow_physics":player.physics_profile_records.duplicate(true)})
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(directory.path_join(label+".png"))
	var counts: Array=[]
	for row: Dictionary in rows:
		counts.append({"fixture":row.fixture,"original_shapes":row.originals.size(),"candidate_shapes":row.candidates.size(),"candidate_triangles":row.triangles})
		for shape: CollisionShape3D in row.originals:shape.disabled=false
		for shape: CollisionShape3D in row.candidates:shape.free()
		if not row.retained.is_empty():
			for shape: CollisionShape3D in row.originals:shape.free()
			for shape: CollisionShape3D in row.retained:shape.disabled=false
	var interactions: Dictionary=await installed_interactions()
	switches.restore_room("F03_B_BATH",saved)
	FileAccess.open(directory.path_join("profile.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","installed":installed_only,"settings":{"viewport":str(get_viewport().size),"vsync":"disabled","max_fps":0,"physics_hz":Engine.physics_ticks_per_second,"ticks_per_phase":240},"records":records,"samples":samples,"shapes":counts,"interactions":interactions,"failures":failures,"limits":"Windowed contact study. Wall/render/physics monitors overlap. Captures, interaction checks and isolated query timing outside sampled route. No independent asset, compilation or streaming attribution; not runtime qualification."},"\t"))
	print("BATH CONTACT LOD STUDY: ","PASS" if failures.is_empty() else "FAIL"," diagnostic only")
	get_tree().quit(0 if failures.is_empty() else 1)
