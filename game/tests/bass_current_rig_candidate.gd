extends Node3D
## INERT nearby current-source rig candidate. No music or household ownership.
const Body = preload("res://scripts/characters/harukiya_staff_body.gd")
const Domestic = preload("res://scripts/building/orison_v2_native_domestic_objects.gd")
const Destination = preload("res://scripts/building/orison_v2_bar_destination.gd")
const Math = preload("res://tests/bass_current_contact_math.gd")
const Driver = preload("res://tests/bass_current_contact_writer.gd")
const SkinWitness = preload("res://tests/harukiya_evaluated_skin_witness.gd")
const FIXTURE := "res://tests/fixtures/bass_current_rig_fixture.json"
const MANIFEST := "res://tests/fixtures/bass_current_rig_sources.json"
const MAX_BYTES := 104857600
const CONTACT_ERROR_M := 0.006 # Existing physical contact candidate tolerance.
var output := ""
var failures: Array[String] = []
var checks: Array[Dictionary] = []
var observations: Array[Dictionary] = []
var actor: Node3D
var bass: StaticBody3D
var frame: Node3D
var driver: SkeletonModifier3D
var contact: RefCounted
var skin: RefCounted
var rows: Array[Dictionary] = []
var sampled_bone_poses: Array[Dictionary] = []
var sampled := false
var fixture: Dictionary = {}
var bindings: Dictionary = {}
var initial: Dictionary = {}
var runtime_before: Dictionary = {}
var manifest_hash := ""
var original_data: Dictionary
var original_text := ""
var original_mode: int
var original_mouse: int
var preview := false
var geometry_bytes := 0
var logger
func _ready() -> void:_run.call_deferred()
func check(ok: bool, label: String) -> bool:
	checks.append({"ok":ok,"label":label})
	if not ok:failures.append(label)
	return ok
func v(a: Array) -> Vector3:return Vector3(float(a[0]),float(a[1]),float(a[2]))
func source_snapshot() -> Dictionary:
	var result: Dictionary = {}
	for path: String in bindings:
		result[path]=FileAccess.get_sha256(path) if bindings[path].kind=="raw" else FileAccess.get_file_as_string(path).replace("\r\n","\n").sha256_text()
	return result
func _run() -> void:
	output=OS.get_environment("SHOT_DIR")
	if output.is_empty() or DirAccess.make_dir_recursive_absolute(output)!=OK:get_tree().quit(2);return
	if FileAccess.file_exists(output.path_join("diagnostic.json")):get_tree().quit(2);return
	original_data=RealityState.data;original_text=JSON.stringify(original_data,"",true,true)
	original_mode=GameBoot.launch_mode;original_mouse=Input.mouse_mode
	logger=preload("res://tests/guide_bell_error_capture.gd").new();OS.add_logger(logger)
	var manifest: Variant=JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	var decoded: Variant=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	if not check(manifest is Dictionary and decoded is Dictionary,"explicit private candidate/source manifest loads"):await finish();return
	fixture=decoded;bindings=manifest.sources;initial=source_snapshot()
	manifest_hash=FileAccess.get_file_as_string(MANIFEST).replace("\r\n","\n").sha256_text()
	runtime_before=runtime_snapshot()
	for path: String in bindings:check(initial[path]==str(bindings[path].sha256),"pinned current input "+path)
	if not failures.is_empty():await finish();return
	preview=RealityState.begin_preview_campaign(self)
	if not check(preview,"exclusive isolated preview"):await finish();return
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	frame=Node3D.new();frame.name="BassTechnicalFrame";add_child(frame);frame.position.z=-9.795
	# Reuse native architecture factory only; no schedules/actors/items are mounted.
	var destination: Node3D=Destination.new();frame.add_child(destination)
	destination.spec=JSON.parse_string(FileAccess.get_file_as_string("res://data/orison_v2/harukiya_destination_layout.json"))
	if not check(destination._mount_architecture(),"current complete native destination architecture"):await finish();return
	var markers: Array=destination.spec.standing_positions.filter(func(r):return r.id=="bass_performer")
	if not check(markers.size()==1 and GameBoot.b2g(markers[0].at).is_equal_approx(v(fixture.lily_feet_bar)),"authored bass performer frame unchanged"):await finish();return
	var factory: RefCounted=Domestic.new()
	if not check(factory.prepare(),"actual NativeDomesticObjects.prepare"):factory.finish();await finish();return
	bass=StaticBody3D.new();bass.name="TechnicalOnlyComplete3CBass";frame.add_child(bass)
	var mounted: bool=factory.mount_on(bass,"3C_bass");factory.finish()
	if not check(mounted and str(bass.get_meta("v2_native_domestic_variant",""))=="DomesticObject140","existing original complete bass mounted exactly once"):await finish();return
	var m: Array=fixture.placement.asset_to_bar_matrix
	bass.position=Vector3(float(m[0][3]),float(m[1][3]),float(m[2][3])) # Identity source basis; baked lean not applied again.
	var triangles := 0
	var draws: Array=bass.find_children("*","MeshInstance3D",true,false)
	for draw: MeshInstance3D in draws:triangles+=int(draw.mesh.get_faces().size()/3)
	if not check(draws.size()==7 and triangles==11744,"all seven native bass parts and 11744 triangles retained"):await finish();return
	var profiles: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/characters/harukiya_staff_standing_columns.json"))
	var matches: Array=profiles.profiles.filter(func(r):return r.person=="lily" and r.parts==["p_top","p_feet","p_head"])
	if not check(matches.size()==1 and str(matches[0].model)=="res://assets/characters/lily/lily.gltf","unique current Lily sealed work outfit"):await finish();return
	var profile: Dictionary=matches[0]
	actor=Body.new();actor.configure("lily",profile.model,profile.parts,profile.stand_pose);frame.add_child(actor)
	if not check(actor.ready_ok and actor.load_standing_profiles(),"current Lily body/garments/sealed source profiles validate"):await finish();return
	actor.set_process(false);actor.attention.pipeline.active=false;actor.face.set_process(false)
	# Same neutral-expression technical skin boundary as the existing contact candidate.
	for draw: MeshInstance3D in actor.model.find_children("*","MeshInstance3D",true,false):
		if draw.mesh!=null:
			for blend: int in draw.mesh.get_blend_shape_count():draw.set_blend_shape_value(blend,0.0)
	# Keep existing secondary modifiers and clothing active; one test owner replaces only base/attention pose.
	actor.global_basis=Basis(Vector3.UP,PI)
	actor.global_position=frame.to_global(v(fixture.lily_feet_bar))-actor.global_basis*v(profile.base_local)
	contact=Math.new();skin=SkinWitness.new()
	driver=Driver.new();driver.actor=actor;driver.skeleton=actor.skeleton;driver.model=actor.model;driver.person_id="lily"
	driver._stand=actor._stand;driver.pipeline=driver;driver.contact_math=contact;driver.role="bass"
	actor.skeleton.add_child(driver);actor.skeleton.move_child(driver,actor._skirt.get_index())
	for side: String in ["Left","Right"]:
		contact.tips[side]=contact._fingertip_datum(driver,side)
		contact.palms[side]=contact.current_palm(driver,side)
		driver.soles[side]=skin.sole_datum(actor,side)
		check(not contact.tips[side].is_empty() and not contact.palms[side].is_empty() and not driver.soles[side].is_empty(),"current source fingertip/palm/sole datums "+side)
	if not failures.is_empty():await finish();return
	# Authored finite technical base, cloned from her own current stand table.
	driver._stand.poses["__bass_candidate"]=driver._stand.poses.at_ease.duplicate(true)
	driver._stand.apply(actor.skeleton,"__bass_candidate",false,0.0,0.0)
	var source_lowest := INF
	for side: String in ["Left","Right"]:source_lowest=minf(source_lowest,skin.measured_point(actor,driver.soles[side]).y)
	var foot_correction: float=frame.global_position.y+float(fixture.placement.stage_actual_top_y)-source_lowest
	if not check(is_finite(foot_correction) and absf(foot_correction)<.10,"bounded current source sole-derived initial root grounding"):await finish();return
	actor.global_position.y+=foot_correction
	# Author an actual closer, slightly flexed stance; do not move string targets
	# or lengthen the rig to accommodate the previous reach failure.
	var stance: Dictionary=fixture.candidate_stance
	actor.global_position+=frame.global_basis*v(stance.offset_bar)
	actor.global_position.y-=float(stance.knees_flex_root_drop_m)
	observations.append({"kind":"explicit_initial_technical_placement","sealed_profile":profile,"source_lowest_sole_world_y":source_lowest,"sole_derived_y_correction":foot_correction,"candidate_stance":stance,"actor":actor.global_transform,"bass":bass.global_transform,"world_z_offset_applied_once":frame.position.z})
	for side: String in ["Left","Right"]:
		var sole: Vector3=skin.measured_point(actor,driver.soles[side])
		contact.supports[side]=Vector3(sole.x,frame.global_position.y+float(fixture.placement.stage_actual_top_y),sole.z)
	for witness: Dictionary in fixture.contact_witnesses:
		var id: String=str(witness.id)
		if id=="left_fret":contact.targets.Left=bass.to_global(v(witness.string_surface.point_asset))
		if id=="right_pluck":contact.targets.Right=bass.to_global(v(witness.string_surface.point_asset))
	actor._skirt.modification_processed.connect(_after_secondary)
	var light:=DirectionalLight3D.new();add_child(light);light.rotation_degrees=Vector3(-45,-25,0);light.light_energy=1.1
	var camera:=Camera3D.new();add_child(camera);camera.fov=48;camera.make_current()
	await get_tree().physics_frame
	# First native rays retain lower buried-string negative regardless of pose feasibility.
	for witness: Dictionary in fixture.contact_witnesses:_native_witness(witness)
	driver.enabled=true
	for sample: int in 2:
		sampled=false;rows.clear();sampled_bone_poses.clear()
		for wait_frame: int in 12:
			await get_tree().process_frame;await RenderingServer.frame_post_draw
			if sampled:break
		if not check(sampled and not rows.is_empty(),"actual final weighted skin after current secondary sample "+str(sample)):break
		var actual: Dictionary={}
		for side: String in ["Left","Right"]:
			var point: Vector3=_sampled_point(contact.tips[side])
			var palm := Vector3.ZERO
			for vertex: int in contact.palms[side].vertices:
				palm+=_sampled_point({"mesh":contact.palms[side].mesh,"surface":contact.palms[side].surface,"vertex":vertex})/3.0
			var sole: Vector3=_sampled_point(driver.soles[side])
			var metric: Dictionary=contact.latest.get("lily_bass_wrist_"+side,{})
			check(not metric.is_empty() and not bool(metric.get("clamped",true)),"UNCLAMPED current Lily wrist reach "+side)
			var leg: Dictionary=contact.latest.get("lily_foot_"+side,{})
			check(not leg.is_empty() and not bool(leg.get("clamped",true)),"UNCLAMPED current Lily supporting leg "+side)
			check(point.is_finite() and point.distance_to(contact.targets[side])<=CONTACT_ERROR_M,"post-secondary actual source fingertip reaches defined string3 "+side)
			check(sole.is_finite() and sole.distance_to(contact.supports[side])<=CONTACT_ERROR_M,"post-secondary actual sole at native stage "+side)
			var hit: Dictionary=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(sole+Vector3.UP*.012,sole-Vector3.UP*.012,1))
			check(not hit.is_empty() and _part(hit).begins_with("Destination_Stage_"),"actual native stage first supports sole "+side)
			actual[side]={"fingertip":point,"palm_facet_centroid":palm,"sole":sole,"support":contact.supports[side],"support_first_hit":_hit(hit),"wrist_reach":metric,"datums":{"tip":contact.tips[side],"palm":contact.palms[side],"sole":driver.soles[side]}}
		var exports: Array[Dictionary]=[]
		for row: Dictionary in rows:
			var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=row.vertices;arrays[Mesh.ARRAY_INDEX]=row.indices
			var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
			var path: String=output.path_join("sample_%d_surface_%03d.res"%[sample,exports.size()])
			if geometry_bytes+row.vertices.size()*12+row.indices.size()*4>MAX_BYTES:check(false,"100MiB bounded geometry export");break
			check(ResourceSaver.save(mesh,path,ResourceSaver.FLAG_COMPRESS)==OK,"actual evaluated mesh saved")
			var file:=FileAccess.open(path,FileAccess.READ)
			if file!=null:geometry_bytes+=file.get_length();file.close()
			exports.append({"mesh":row.mesh,"surface":row.surface,"file":path,"vertices":row.vertices.size(),"triangles":int(row.indices.size()/3)})
		var eye: Vector3=frame.to_global(Vector3(-1.3,-.8,32.7) if sample==0 else Vector3(-3.8,-1.0,34.1))
		camera.global_position=eye;camera.look_at(frame.to_global(Vector3(-2.8,-1.65,35.1)))
		await RenderingServer.frame_post_draw
		var image: Image=get_viewport().get_texture().get_image()
		check(image!=null and not image.is_empty() and image.save_png(output.path_join("bass_current_%d.png"%sample))==OK,"actual diagnostic camera PNG")
		var bone_poses: Array[Dictionary]=sampled_bone_poses.duplicate(true)
		observations.append({"sample":sample,"actual_current_bone_poses":bone_poses,"actor":actor.global_transform,"bass":bass.global_transform,"frame":frame.global_transform,"actual":actual,"solver":contact.latest.duplicate(true),"skin_native_edges":skin.edge_witnesses(rows,get_world_3d().direct_space_state,4000),"geometry":exports,"camera":camera.global_transform,"fov":camera.fov,"viewport":get_viewport().get_visible_rect().size})
		if geometry_bytes>MAX_BYTES:check(false,"bounded total geometry bytes");break
	check(driver.refused_writes==0 and driver.faults.is_empty(),"one finite test pose writer")
	check(skin.errors.is_empty(),"current weighted skin evaluator has no errors")
	await finish()
func _after_secondary() -> void:
	if sampled or not is_instance_valid(driver) or not driver.enabled:return
	rows=skin.snapshot(actor)
	for bone: int in actor.skeleton.get_bone_count():
		sampled_bone_poses.append({"name":actor.skeleton.get_bone_name(bone),"pose":actor.skeleton.get_bone_global_pose(bone)})
	sampled=true
func _sampled_point(witness: Dictionary) -> Vector3:
	# SkeletonModifier restores base poses after processing; use the final skin
	# snapshot captured in modification_processed, not a later rest-pose query.
	for row: Dictionary in rows:
		if str(row.mesh).get_file()!=str(witness.get("mesh","")) or int(row.surface)!=int(witness.get("surface",-1)):continue
		var vertex: int=int(witness.get("vertex",-1))
		var points: PackedVector3Array=row.vertices
		return points[vertex] if vertex>=0 and vertex<points.size() else Vector3.INF
	return Vector3.INF
func _part(hit: Dictionary) -> String:
	if hit.is_empty():return ""
	var collider: Node=hit.get("collider") as Node
	if collider==null:return ""
	var draw:=collider.get_parent() as MeshInstance3D
	return str(draw.get_meta("harukiya_destination_part","")) if draw!=null else ""
func _hit(hit: Dictionary) -> Dictionary:
	if hit.is_empty():return {}
	var collider: CollisionObject3D=hit.get("collider") as CollisionObject3D
	var shape: int=int(hit.get("shape",-1))
	var owner: Object=collider.shape_owner_get_owner(collider.shape_find_owner(shape)) if collider!=null and shape>=0 else null
	return {"collider":str(collider.get_path()) if collider!=null else "","rid":str(hit.get("rid",RID())),"shape":shape,"shape_owner":str(owner.get_path()) if owner is Node else "","face_index":int(hit.get("face_index",-1)),"position":hit.get("position",Vector3.INF),"normal":hit.get("normal",Vector3.INF)}
func _native_witness(w: Dictionary) -> void:
	var point: Vector3=bass.to_global(v(w.string_surface.point_asset))
	var front: Vector3=v(fixture.source_frame.front_towards_audience_godot).normalized()
	var ray: Dictionary=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point+front*.10,point-front*.10,1))
	var expected: Vector3=bass.to_global(v(w.whole_instrument_first_surface.point_asset))
	check(not ray.is_empty() and ray.collider==bass and ray.position.distance_to(expected)<.002,"actual whole native instrument first surface "+str(w.id))
	# Reconcile actual loaded triangle by vertex geometry, never equate GLB and runtime face indices.
	var face: Dictionary=w.string_surface.faces[0]
	var draw:=bass.get_node_or_null(str(face.part)) as MeshInstance3D
	var matched := false
	if draw!=null:
		# Render arrays retain authored float32 positions; get_faces() snaps
		# through TriangleMesh on the pinned engine. Collision rays stay separate.
		for surface: int in draw.mesh.get_surface_count():
			var arrays: Array=draw.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
			if indices.is_empty():
				for vertex: int in vertices.size():indices.append(vertex)
			for i: int in int(indices.size()/3):
				var all_match := true
				for expected_vertex: Array in face.points_asset:
					var nearest := INF
					for j: int in 3:nearest=minf(nearest,(draw.transform*vertices[indices[i*3+j]]).distance_to(v(expected_vertex)))
					all_match=all_match and nearest<.00001
				if all_match:matched=true;break
			if matched:break
	check(matched,"canonical string facet independently matches loaded native vertices "+str(w.id))
	if str(w.id)=="buried_lower_string_negative":check(not ray.is_empty() and ray.position.distance_to(point)>.01,"buried lower string remains occluded by original native board")
	observations.append({"kind":"native_string_working_envelope","witness":w,"ray_first":_hit(ray),"canonical_facet_loaded_match":matched,"scope":"finite source-defined string3 samples; runtime face numbering kept separate"})
func runtime_snapshot() -> Dictionary:
	var root: String=ProjectSettings.globalize_path("res://..").simplify_path()
	var digest: Array=[]
	check(OS.execute("python",[root.path_join("tools/run_receipt.py"),"digest","--root",root],digest)==0,"current complete runtime digest tool succeeds")
	return {"runtime":str(digest[0]).strip_edges() if not digest.is_empty() else ""}
func finish() -> void:
	var writer_errors: Array=driver.faults.duplicate() if is_instance_valid(driver) else []
	if is_instance_valid(driver):driver.enabled=false
	if is_instance_valid(frame):frame.free()
	if preview:check(RealityState.end_preview_campaign(self) and is_same(RealityState.data,original_data) and JSON.stringify(original_data,"",true,true)==original_text,"exact prior campaign object/content restored")
	GameBoot.launch_mode=original_mode;Input.mouse_mode=original_mouse
	await get_tree().process_frame
	var final_sources: Dictionary=source_snapshot() if not initial.is_empty() else {}
	if not initial.is_empty():check(final_sources==initial,"exact consumed source bindings unchanged")
	var runtime_after: Dictionary=runtime_snapshot() if not runtime_before.is_empty() else {}
	if not runtime_before.is_empty():check(runtime_after==runtime_before,"complete runtime digest unchanged")
	if not manifest_hash.is_empty():check(FileAccess.get_file_as_string(MANIFEST).replace("\r\n","\n").sha256_text()==manifest_hash,"source manifest itself unchanged")
	var errors: Array=logger.errors.duplicate() if logger!=null else []
	check(errors.is_empty(),"no unexpected engine/teardown errors")
	if logger!=null:OS.remove_logger(logger)
	var result: Dictionary={"evidence_class":"INERT","status":"FINITE_TECHNICAL_PASS" if failures.is_empty() else "FAIL","checks":checks,"failures":failures,"source_before":initial,"source_after":final_sources,"observations":observations,"skin_errors":skin.errors if skin!=null else [],"writer_errors":writer_errors,"runtime_before":runtime_before,"runtime_after":runtime_after,"source_manifest_lf_sha256":manifest_hash,"engine_errors":errors,"geometry_bytes":geometry_bytes,"human_played":false,"artistically_accepted":false,"scope":"One original bass/current Lily finite rig envelope only. No production bass actor, household move/copy/save, music, continuous reach/volume/self/cloth clearance, mechanical stability or art acceptance. Actual native rays and sampled skin edges are witnesses, not full collision proof."}
	FileAccess.open(output.path_join("diagnostic.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	get_tree().quit(0 if failures.is_empty() else 1)
