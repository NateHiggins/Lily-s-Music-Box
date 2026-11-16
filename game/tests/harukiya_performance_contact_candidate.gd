extends Node3D
## UNAPPLIED, uncompiled candidate. Technical contacts only, no shipped performance.
const Body := preload("res://scripts/characters/harukiya_staff_body.gd")
const Writer := preload("res://tests/harukiya_physical_contact_writer.gd")
const ContactMath := preload("res://tests/harukiya_physical_contact_math.gd")
const SkinWitness := preload("res://tests/harukiya_evaluated_skin_witness.gd")
const Manifest := "res://tests/fixtures/harukiya_physical_candidate_manifest.json"
const CONTACT_ERROR_M := .006
var bar: OrisonV2BarRegion
var actors: Dictionary={}
var drivers: Dictionary={}
var contact_math: RefCounted
var skin: RefCounted
var snapshots: Dictionary={}
var pose_bones:Dictionary={}
var pose_frames:Dictionary={}
var requested: Dictionary={}
var observations: Array[Dictionary]=[]
var checks: Array[Dictionary]=[]
var failures: Array[String]=[]
var camera: Camera3D
var logger
var output := ""
var preview := false
var prior_data: Dictionary
var prior_text := ""
var prior_mode: int
var prior_mouse: int
var kit: Node3D
var spec: Dictionary={}
var evaluated_surfaces := 0
var output_bytes := 0
const MAX_OUTPUT_BYTES := 104857600
var initial_inputs: Dictionary={}
var bound_sources: Dictionary={}
var pose_supports: Dictionary={}
func _ready() -> void: _run.call_deferred()
func check(ok: bool,label: String) -> bool:
	checks.append({"ok":ok,"label":label})
	if not ok:failures.append(label)
	return ok
func _run() -> void:
	output=OS.get_environment("SHOT_DIR")
	if output.is_empty() or DirAccess.make_dir_recursive_absolute(output)!=OK:get_tree().quit(2);return
	if FileAccess.file_exists(output.path_join("diagnostic.json")):get_tree().quit(2);return
	logger=preload("res://tests/guide_bell_error_capture.gd").new();OS.add_logger(logger)
	prior_data=RealityState.data;prior_text=JSON.stringify(prior_data,"",true,true)
	prior_mode=GameBoot.launch_mode;prior_mouse=Input.mouse_mode
	var binding: Variant=JSON.parse_string(FileAccess.get_file_as_string(Manifest))
	if not check(binding is Dictionary,"explicit candidate source bindings load"):await finish();return
	for path: String in binding.sources:
		var row: Dictionary=binding.sources[path]
		var actual: String=FileAccess.get_sha256(path) if row.kind=="raw" else FileAccess.get_file_as_string(path).replace("\r\n","\n").sha256_text()
		check(FileAccess.file_exists(path) and actual==str(row.sha256),"exact source input "+path)
	if not failures.is_empty():await finish();return
	bound_sources=binding.sources.duplicate(true)
	initial_inputs=_input_snapshot()
	preview=RealityState.begin_preview_campaign(self)
	if not check(preview,"exclusive nonpersistent component preview"):await finish();return
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	bar=OrisonV2BarRegion.new();add_child(bar)
	if not check(not bar.startup_failed and bar.destination!=null,"actual current bar-only destination mounts"):await finish();return
	spec=bar.destination.spec
	kit=bar.destination.get_node_or_null("HarukiyaDrumKit") as Node3D
	if not check(kit!=null,"actual mounted native kit"):await finish();return
	contact_math=ContactMath.new();skin=SkinWitness.new()
	contact_math.kit=kit;contact_math.kit_data=kit.get_meta("source",{})
	var piano: Dictionary=spec.relocations.piano
	contact_math.piano_frame=bar.destination.global_transform*Transform3D(Basis(Vector3.UP,deg_to_rad(float(piano.yaw_deg))),GameBoot.b2g(piano.at))
	for draw: MeshInstance3D in kit.find_children("*","MeshInstance3D",true,false):
		var id:=str(draw.get_meta("harukiya_drum_part",""))
		for group: String in ["StickLeft","StickRight","BassPedal","HiHatPedal","BassBeater"]:
			if id.begins_with("DrumKit_"+group+"_"):
				if not contact_math.moving.has(group):contact_math.moving[group]=[]
				contact_math.moving[group].append(draw);contact_math.rest_props[draw.get_instance_id()]=draw.transform
	var profiles: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/characters/harukiya_staff_standing_columns.json"))
	for id: String in ["adela_voss","stacy"]:
		var rows: Array=profiles.profiles.filter(func(r):return r.person==id and r.parts==["p_top","p_feet","p_head"])
		if not check(rows.size()==1,"unique current work-parts/body profile "+id):continue
		var row: Dictionary=rows[0]
		var expected_model:String="res://assets/characters/cast/adela_voss/adela_voss.gltf" if id=="adela_voss" else "res://assets/characters/stacy/stacy.gltf"
		if not check(str(row.model)==expected_model,"actual current HarukiyaCast body path "+id):continue
		var actor: Node3D=Body.new();actor.configure(id,row.model,row.parts,row.stand_pose);add_child(actor)
		if not check(actor.ready_ok and actor.load_standing_profiles(),"current rig/garment/source profile validates "+id):continue
		actors[id]=actor;actor.set_process(false)
		for node: Node in actor.find_children("*","Node",true,false):node.set_process(false)
		actor.attention.pipeline.active=false
		for draw: MeshInstance3D in actor.model.find_children("*","MeshInstance3D",true,false):
			if draw.mesh!=null:
				for blend: int in draw.mesh.get_blend_shape_count():draw.set_blend_shape_value(blend,0.)
		var driver: SkeletonModifier3D=Writer.new()
		driver.actor=actor;driver.skeleton=actor.skeleton;driver.model=actor.model;driver.person_id=id
		driver._stand=actor._stand;driver.pipeline=driver;driver.contact_math=contact_math
		driver.role="piano" if id=="adela_voss" else "drums"
		driver.skeleton.add_child(driver)
		driver.skeleton.move_child(driver,actor._skirt.get_index()) # contact before existing secondary skirt writer
		var datum: Dictionary=contact_math._pelvis_datum(driver)
		check(not datum.is_empty(),"current skin posterior datum "+id)
		contact_math.seated[id]=datum
		contact_math.seated[id].fingertips={}
		for side: String in ["Left","Right"]:
			var tip: Dictionary=contact_math._fingertip_datum(driver,side)
			var sole: Dictionary=skin.sole_datum(actor,side)
			check(not tip.is_empty() and not sole.is_empty(),"current actual fingertip/sole source "+id+side)
			contact_math.seated[id].fingertips[side]=tip;driver.soles[side]=sole
		drivers[id]=driver
		actor._skirt.modification_processed.connect(_after_secondary.bind(id))
	if not failures.is_empty() or actors.size()!=2:await finish();return
	_lighting()
	# Newly authored finite technical posture, not copied old actor/root offsets.
	for id: String in actors:
		var driver: Node=drivers[id];var pose: Dictionary=driver._stand.poses.at_ease.duplicate(true)
		pose.hips={"turn":0.,"tilt":0.,"shift_x":0.,"shift_z":0.}
		pose.spine={"forward":18. if id=="adela_voss" else 8.,"side":0.,"twist":0.}
		for side: String in ["left","right"]:
			pose[side].thigh=[5.,75.];pose[side].shin=[4.,0.]
			pose[side].arm=[65.,85.];pose[side].forearm=[10.,90.];pose[side].curl=12.
		driver._stand.poses["__physical_candidate"]=pose
		driver._stand.apply(driver.skeleton,"__physical_candidate",false,0.,0.)
		var support: Vector3
		var forward: Vector3
		if id=="adela_voss":
			var bench: Dictionary=spec.architecture.stage.piano_bench
			support=bar.destination.to_global(GameBoot.b2g(bench.at))+Vector3.UP*float(bench.height)
			support+=contact_math.piano_frame.basis*Vector3.BACK*(float(bench.depth)*.4)
			forward=contact_math.piano_frame.basis*Vector3.BACK
		else:
			support=kit.to_global(Vector3(0,float(contact_math.kit_data.contacts.seat.position[1]),float(contact_math.kit_data.contacts.seat.position[2])))
			forward=kit.global_basis*Vector3.FORWARD
		var actor: Node3D=actors[id]
		actor.global_basis=Basis(Vector3.UP,atan2(forward.x,forward.z))
		var hips: Vector3=driver.skeleton.get_bone_global_pose(driver.skeleton.find_bone("Hips")).origin
		actor.global_position=support+Vector3.UP*float(contact_math.seated[id].hips_above_support)-actor.global_basis*hips
		contact_math.seated[id].world_support=support
		contact_math.seated[id].forward=forward
		driver.enabled=true
	_assembled_negative()
	for state: Dictionary in [{"index":0,"press":0.,"left":"HiHatUpper","right":"Snare"},{"index":0,"press":1.,"left":"HiHatUpper","right":"Snare"},{"index":2,"press":0.,"left":"Crash","right":"Ride"},{"index":2,"press":1.,"left":"Crash","right":"Ride"},{"index":4,"press":0.,"left":"RackTomLeft","right":"FloorTom"},{"index":4,"press":1.,"left":"RackTomLeft","right":"RackTomRight"}]:
		await sample(state)
		if output_bytes>MAX_OUTPUT_BYTES:check(false,"bounded100MiB private geometry-output ceiling")
		if not failures.is_empty() or not skin.errors.is_empty():break
	if not failures.is_empty() or not skin.errors.is_empty() or output_bytes>MAX_OUTPUT_BYTES:await finish();return
	await proposed_component_transport()
	await finish()
func _after_secondary(id: String) -> void:
	if not requested.get(id,false):return
	requested[id]=false
	snapshots[id]=skin.snapshot(actors[id])
	var bones:Array=[]
	for bone:int in actors[id].skeleton.get_bone_count():bones.append({"name":actors[id].skeleton.get_bone_name(bone),"pose":actors[id].skeleton.get_bone_global_pose(bone)})
	pose_bones[id]=bones;pose_frames[id]=Engine.get_process_frames()
	pose_supports[id]=skin.measured_point(actors[id],contact_math.seated[id].support_witness)
func sample(state: Dictionary) -> void:
	contact_math.press=float(state.press);contact_math.event_index=int(state.index);contact_math.drum_targets={"Left":str(state.left),"Right":str(state.right)};contact_math.latest.clear()
	for id: String in actors:
		snapshots.erase(id);pose_bones.erase(id);requested[id]=true
	await get_tree().process_frame;await RenderingServer.frame_post_draw
	await get_tree().process_frame;await RenderingServer.frame_post_draw
	await get_tree().physics_frame
	var row: Dictionary={"newly_authored_technical_state":state,"contacts":contact_math.latest.duplicate(true),"actors":{},"artistically_accepted":false}
	for id: String in actors:
		var driver: Node=drivers[id]
		check(driver.refused_writes==0 and driver.faults.is_empty(),"one finite contact writer "+id)
		check(snapshots.has(id) and not snapshots[id].is_empty(),"actual skin sampled after secondary "+id)
		if not snapshots.has(id):continue
		var support:Vector3=pose_supports.get(id,Vector3.INF)
		var target:Vector3=contact_math.seated[id].world_support
		check(support.is_finite() and absf(support.y-target.y)<=CONTACT_ERROR_M,"actual posterior skin height meets native seat "+id)
		var contact_hit:Dictionary={}
		if support.is_finite():contact_hit=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(support+Vector3.UP*.012,support-Vector3.UP*.012,1))
		var seat_expected: Dictionary={"harukiya_destination_part":["Destination_Stage_oak"]} if id=="adela_voss" else {"harukiya_drum_part":["DrumKit_static_KitSeat"]}
		check(_native_identity(contact_hit,seat_expected) and absf(float(contact_hit.get("position",Vector3.INF).y)-target.y)<.003,"intended native seat directly supports posterior "+id)
		if not contact_hit.is_empty():check(not _native_identity(contact_hit,{"bar_furniture_part":["Piano__key_white"]}),"seat witness rejects unrelated intended assembly "+id)
		var bones:Array=pose_bones.get(id,[])
		check(bones.size()==driver.skeleton.get_bone_count(),"all actual post-secondary bone poses captured "+id)
		var witnesses: Dictionary=skin.edge_witnesses(snapshots[id],get_world_3d().direct_space_state,4000)
		var surfaces: Array=[]
		for surface: Dictionary in snapshots[id]:
			var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=surface.vertices;arrays[Mesh.ARRAY_INDEX]=surface.indices
			var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			var file:=output.path_join("evaluated_%02d_%s_%03d.res"%[observations.size(),id,surfaces.size()])
			check(ResourceSaver.save(mesh,file,ResourceSaver.FLAG_COMPRESS)==OK,"save actual evaluated body surface")
			_count_output(file)
			surfaces.append({"mesh":surface.mesh,"surface":surface.surface,"file":file,"vertices":surface.vertices.size(),"triangles":surface.indices.size()/3});evaluated_surfaces+=1
		row.actors[id]={"posterior_native_hit":str(contact_hit.collider.get_path()) if not contact_hit.is_empty() else "","posterior_skin":support,"seat_support_target":target,"post_secondary_process_frame":pose_frames.get(id,-1),"actor_transform":actors[id].global_transform,"source_model":actors[id]._source_model,"parts":actors[id].worn_parts(),"all_bone_poses":bones,"evaluated_surfaces":surfaces,"native_edge_witnesses":witnesses}
	for label:String in ["adela_voss_piano_Left","adela_voss_piano_Right","piano_fingertip_Left","piano_fingertip_Right","adela_voss_foot_Left","adela_voss_foot_Right","adela_voss_sole_Left","adela_voss_sole_Right","stacy_drum_Left","stacy_drum_Right","stick_tip_Left","stick_tip_Right","stacy_foot_Left","stacy_foot_Right","stacy_sole_Left","stacy_sole_Right"]:
		check(contact_math.latest.has(label),"all declared hand/foot observations evaluated "+label)
	for label: String in contact_math.latest:
		var metric: Dictionary=contact_math.latest[label]
		check(is_finite(float(metric.error_m)) and float(metric.error_m)<=CONTACT_ERROR_M and not bool(metric.get("clamped",false)),"finite unclamped contact<=6mm "+label)
	var native_contacts:Array=[]
	for label:String in contact_math.latest:
		var metric:Dictionary=contact_math.latest[label]
		if not metric.has("target"):continue
		var should_touch:bool=label.contains("_sole_") or (float(state.press)>0.99 and (label.begins_with("piano_fingertip_") or label.begins_with("stick_tip_")))
		if not should_touch:continue
		var target:Vector3=metric.target
		var hit:Dictionary=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(target+Vector3.UP*.012,target-Vector3.UP*.012,1))
		var expected:Dictionary=_expected_contact(label,metric)
		var valid:bool=_native_identity(hit,expected) and hit.position.distance_to(target)<.003
		native_contacts.append({"label":label,"target":target,"native_hit":str(hit.collider.get_path()) if not hit.is_empty() else "","point":hit.get("position"),"normal":hit.get("normal"),"within_3mm_and_intended_owner":valid,"expected_owner":expected,"face_index":hit.get("face_index",-1)})
		check(valid,"actual native surface at intended contact "+label)
	row["intended_native_surface_contacts"]=native_contacts
	check(skin.errors.is_empty(),"all evaluated skin source bindings valid")
	observations.append(row)
	if observations.size() in [1,2,6]:
		var views:Dictionary={1:[Vector3(-2.5,-1.35,35.6),Vector3(-3.6,-1.91,36.63)],2:[Vector3(-2.2,-1.1,36.9),Vector3(-.95,-1.7,36.25)],6:[Vector3(.2,-2.0,36.9),Vector3(-1.,-2.51,36.3)]}
		camera.global_position=bar.to_global(views[observations.size()][0])
		camera.look_at(bar.to_global(views[observations.size()][1]))
		await get_tree().process_frame;await RenderingServer.frame_post_draw
		check(get_viewport().get_texture().get_image().save_png(output.path_join("neutral_%02d.png"%observations.size()))==OK,"neutral contact view saved")
func _assembled_negative() -> void:
	var from:=bar.destination.to_global(Vector3(.978,-2.2524,36.46000003))
	var to:=bar.destination.to_global(Vector3(2.688,-2.4724,36.52000003))
	var hit:=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from,to,1))
	check(not hit.is_empty() and str(hit.collider.get_path()).contains("Backstage"),"original assembled-yaw0 kit edge crosses loaded native backstage wall")
	observations.append({"original_negative":"fixed upright assembled kit translated stage_e to backstage","from":from,"to":to,"hit":str(hit.collider.get_path()) if not hit.is_empty() else "","point":hit.get("position"),"all_other_transport_orientations":"NOT_TESTED"})
func _lighting() -> void:
	var env:=WorldEnvironment.new();env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.12,.13,.15)
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color(.8,.82,.85);env.environment.ambient_light_energy=.35;add_child(env)
	var light:=OmniLight3D.new();add_child(light);light.global_position=bar.to_global(Vector3(-1.,.2,35.));light.omni_range=8.;light.light_energy=1.4
	camera=Camera3D.new();add_child(camera);camera.make_current();camera.fov=48.
func finish() -> void:
	for driver: Node in drivers.values():driver.enabled=false
	for actor: Node in actors.values():
		if is_instance_valid(actor):actor.free()
	if is_instance_valid(bar):bar.free()
	if preview:check(RealityState.end_preview_campaign(self) and is_same(RealityState.data,prior_data) and JSON.stringify(prior_data,"",true,true)==prior_text,"exact preview context restored")
	GameBoot.launch_mode=prior_mode;Input.mouse_mode=prior_mouse
	await get_tree().process_frame
	if not initial_inputs.is_empty():
		var final_inputs:Dictionary=_input_snapshot()
		check(final_inputs==initial_inputs,"all declared source/test/manifest and runtime/physical inputs unchanged during probe")
	await get_tree().process_frame
	var errors:Array=logger.errors.duplicate() if logger!=null else []
	check(errors.is_empty(),"no unexpected engine errors including teardown")
	if logger!=null:OS.remove_logger(logger)
	var diagnostic: Dictionary={"source_inputs":initial_inputs,"evidence_class":"INERT","status":"CONTACT_SUBPROBE_PASS" if failures.is_empty() else "FAIL","full_physical_qualification":false,"checks":checks,"failures":failures,"engine_errors":errors,"observations":observations,"evaluated_surface_files":evaluated_surfaces,"generated_geometry_bytes":output_bytes,"scope":"New technical contact poses on current cast, actual skin/native edge witnesses and retained one exact assembled transport negative. Not full native volume/continuous handler transport clearance or seated garment acceptance, gameplay or performance.","remaining_implementation":["Full triangle-interior/enclosed-volume/self/cloth collision classification, narrow intended contacts","Continuous working/approach envelopes between finite states","Finite proposed stick+current handler samples implemented; complete continuous/full-triangle clearance and all larger instrument loads remain open","Bass absent: no mounted bass or transport assertion"]}
	if not output.is_empty():FileAccess.open(output.path_join("diagnostic.json"),FileAccess.WRITE).store_string(JSON.stringify(diagnostic,"\t"))
	get_tree().quit(0 if failures.is_empty() else 1)

func _input_snapshot() -> Dictionary:
	var root:=ProjectSettings.globalize_path("res://..").simplify_path()
	var runtime:Array=[];var physical:Array=[]
	check(OS.execute("python",[root.path_join("tools/run_receipt.py"),"digest","--root",root],runtime)==0,"bind exact runtime inputs")
	check(OS.execute("python",[root.path_join("tools/v2_physical_inputs.py"),"--root",root],physical)==0,"bind exact physical inputs")
	var declared:Dictionary={}
	for path:String in bound_sources:
		declared[path]=FileAccess.get_sha256(path) if str(bound_sources[path].kind)=="raw" else FileAccess.get_file_as_string(path).replace("\r\n","\n").sha256_text()
	return {"declared_sources":declared,"manifest_sha256_lf":FileAccess.get_file_as_string(Manifest).replace("\r\n","\n").sha256_text(),"runtime":str(runtime[0]).strip_edges() if not runtime.is_empty() else "","physical":str(physical[0]).strip_edges() if not physical.is_empty() else "","test_sha256_lf":FileAccess.get_file_as_string(get_script().resource_path).replace("\r\n","\n").sha256_text(),"scene_sha256_lf":FileAccess.get_file_as_string(scene_file_path).replace("\r\n","\n").sha256_text()}

func proposed_component_transport() -> void:
	# A proposed test load-in of an existing complete named component. No new game carry mechanism.
	var source: MeshInstance3D
	for draw: MeshInstance3D in kit.find_children("*","MeshInstance3D",true,false):
		if str(draw.get_meta("harukiya_drum_part",""))=="DrumKit_StickLeft_KitSticks":source=draw
	if not check(source!=null and contact_math.rest_props.has(source.get_instance_id()),"actual complete named native component/rest transform exists"):return
	var payload:=MeshInstance3D.new();payload.name="ProposedNativeStickPayload";payload.mesh=source.mesh
	add_child(payload);payload.create_trimesh_collision();contact_math.proposed_payload=payload;contact_math.payload_source_pose=contact_math.rest_props[source.get_instance_id()]
	var driver: Node=drivers.stacy
	drivers.adela_voss.enabled=false;actors.adela_voss.set_active(false)
	driver._stand.poses["__physical_candidate"]=driver._stand.poses.at_ease.duplicate(true)
	driver.role="carry"
	var points: Array[Vector3]=[]
	for name: String in ["entrance","backstage_public_axis","backstage","stage_e","stage_front"]:
		var node: Node3D=bar.destination.get_node_or_null("Navigation/"+name)
		if not check(node!=null,"native component itinerary node "+name):payload.free();return
		points.append(node.global_position)
	var count:=0
	for leg in range(points.size()-1):
		var steps:=maxi(1,ceili(points[leg].distance_to(points[leg+1])/.20))
		for step in range(steps+1):
			if count>=40:check(false,"finite transport-sample budget exceeded");break
			count+=1
			var feet: Vector3=points[leg].lerp(points[leg+1],float(step)/steps)
			var forward: Vector3=points[leg+1]-points[leg];forward.y=0.
			actors.stacy.global_basis=Basis(Vector3.UP,atan2(-forward.x,-forward.z))
			var profile: Dictionary=actors.stacy._profile_for(actors.stacy.worn_parts())
			if not check(not profile.is_empty(),"current handler source profile retained"):break
			# Only initial technical root placement; no original motor/arrival authority claimed.
			actors.stacy.global_position=feet-actors.stacy.global_basis*Vector3(float(profile.base_local[0]),float(profile.base_local[1]),float(profile.base_local[2]))
			snapshots.erase("stacy");pose_bones.erase("stacy");requested.stacy=true;contact_math.latest.clear()
			await get_tree().process_frame;await RenderingServer.frame_post_draw
			await get_tree().process_frame;await RenderingServer.frame_post_draw
			await get_tree().physics_frame
			if not check(snapshots.has("stacy") and not snapshots.stacy.is_empty(),"actual full handler skin snapshot"):break
			var native_edges: Dictionary=skin.edge_witnesses(snapshots.stacy,get_world_3d().direct_space_state,1000)
			var payload_rows:Array[Dictionary]=[]
			for surface: int in payload.mesh.get_surface_count():
				var arrays:Array=payload.mesh.surface_get_arrays(surface);var vs:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var transformed:=PackedVector3Array()
				for v:Vector3 in vs:transformed.append(payload.global_transform*v)
				payload_rows.append({"mesh":"ProposedNativeStickPayload","surface":surface,"vertices":transformed,"indices":arrays[Mesh.ARRAY_INDEX]})
			var cargo_exclude:Array[RID]=[]
			for collider:PhysicsBody3D in payload.find_children("*","PhysicsBody3D",true,false):cargo_exclude.append(collider.get_rid())
			var cargo_edges: Dictionary=skin.edge_witnesses(payload_rows,get_world_3d().direct_space_state,2000,cargo_exclude)
			var file:=output.path_join("transport_%02d_handler.json"%count)
			var geometry:Array=[]
			for row:Dictionary in snapshots.stacy+payload_rows:
				var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=row.vertices;arrays[Mesh.ARRAY_INDEX]=row.indices
				var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
				var resource:=output.path_join("transport_%02d_surface_%03d.res"%[count,geometry.size()])
				check(ResourceSaver.save(mesh,resource,ResourceSaver.FLAG_COMPRESS)==OK,"full current handler/payload evaluated geometry saved")
				_count_output(resource)
				geometry.append({"mesh":row.mesh,"surface":row.surface,"file":resource,"vertices":row.vertices.size(),"triangles":row.indices.size()/3})
			FileAccess.open(file,FileAccess.WRITE).store_string(JSON.stringify({"actual_evaluated_handler_and_native_payload":geometry}))
			if output_bytes>MAX_OUTPUT_BYTES:check(false,"bounded100MiB private geometry-output ceiling");driver.enabled=false;payload.free();return
			check(driver.refused_writes==0 and driver.faults.is_empty(),"one transport contact writer")
			if contact_math.latest.has("component_handler_grip"):
				var gap:float=float(contact_math.latest.component_handler_grip.error_m)
				check(is_finite(gap) and gap<=CONTACT_ERROR_M and not bool(contact_math.latest.get("stacy_carry_hand",{}).get("clamped",false)),"actual current rig reaches proposed component grip")
			else:check(false,"transport hand contact evaluated")
			observations.append({"scope":"PROPOSED_FINITE_KINEMATIC_COMPONENT_PLUS_CURRENT_HANDLER; not motor walking or continuous clearance","leg":leg,"sample":step,"feet_datum":feet,"handler_transform":actors.stacy.global_transform,"pose":contact_math.carry_state.duplicate(true),"full_geometry_file":file,"native_handler_edge_witnesses":native_edges,"native_payload_edge_witnesses":cargo_edges,"artistically_accepted":false})
	driver.enabled=false;payload.free()

func _count_output(file: String) -> void:
	var handle:=FileAccess.open(file,FileAccess.READ)
	if handle==null:check(false,"generated geometry file is readable");return
	output_bytes+=handle.get_length();handle.close()

func _native_identity(hit: Dictionary, expected: Dictionary) -> bool:
	if hit.is_empty() or expected.is_empty():return false
	var collider:Node=hit.get("collider") as Node
	if collider==null:return false
	var draw:=collider.get_parent() as MeshInstance3D
	if draw==null or draw.mesh==null or not bar.is_ancestor_of(draw):return false
	for key:String in expected:
		if not draw.has_meta(key) or str(draw.get_meta(key)) not in expected[key]:return false
		if key=="harukiya_drum_part" and not kit.is_ancestor_of(draw):return false
	return int(hit.get("face_index",-1))>=0

func _expected_contact(label:String, metric:Dictionary) -> Dictionary:
	if label.begins_with("piano_fingertip_"):return {"bar_furniture_part":["Piano__key_white","Piano__key_white_b"]}
	if label=="adela_voss_sole_Left":return {"harukiya_destination_part":["Destination_Stage_floor"]}
	if label=="adela_voss_sole_Right":return {"bar_furniture_part":["Piano__brass"]}
	if label=="stacy_sole_Left":return {"harukiya_drum_part":["DrumKit_HiHatPedal_KitNickel"]}
	if label=="stacy_sole_Right":return {"harukiya_drum_part":["DrumKit_BassPedal_KitNickel"]}
	if label.begins_with("stick_tip_"):
		var surface:String=str(metric.get("surface",""))
		if surface=="HiHatUpper":return {"harukiya_drum_part":["DrumKit_HiHatUpper_KitBronze"]}
		if surface in ["Crash","Ride"]:return {"harukiya_drum_part":["DrumKit_static_KitBronze"]}
		if surface in ["Snare","RackTomLeft","RackTomRight","FloorTom"]:return {"harukiya_drum_part":["DrumKit_static_KitHide"]}
	return {}
