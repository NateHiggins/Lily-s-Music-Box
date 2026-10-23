extends "res://tests/v2_unracked_hose_world_survey.gd"
## INERT: observe current pickup semantics in the actual occupied world.
var _output_root := ""
var _fps_samples: Array=[]
var _fps_calls: Array=[]
var _cast_captured:=false
func _init() -> void:route_label="V2 FPS HOSE WORLD PROFILE"

func _ready() -> void:
	var directory:=OS.get_environment("SHOT_DIR")
	if not directory.is_empty():DirAccess.make_dir_recursive_absolute(directory)
	_output_root=directory
	if not _write_profile("output_probe.json",{"evidence_class":"INERT","output_root":directory,"placement":OS.get_environment("ORISON_HOSE_SURVEY_PLACEMENT"),"local_compare":OS.get_environment("ORISON_HOSE_LOCAL_COMPARE"),"clear_stance":OS.get_environment("ORISON_HOSE_SURVEY_CLEAR_STANCE")}):
		get_tree().quit(1);return
	super._ready()

func _play_route() -> void:
	await super._play_route()
	var path:=_output_root.path_join("layout_survey.json")
	var survey: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not _require(survey is Dictionary and survey.get("stations") is Array and survey.stations.size()==1,"FPS profile executes exactly the requested station"):return
	_require(bool(survey.stations[0].get("clear",false)),"FPS profile starts from a physically clear placement")
	_require(not _fps_samples.is_empty(),"FPS profile retains actual held-motion measurements")

func _write_profile(name: String,value: Dictionary) -> bool:
	var path:=_output_root.path_join(name)
	var file:=FileAccess.open(path,FileAccess.WRITE)
	if file==null:
		_require(false,"profile output failed: "+path+" / "+error_string(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify(value,"\t"));file.close()
	return true

func _carry_control(actor: Node3D,hose: Node3D,helper: Node,cycle: String) -> Array:
	hose.contact.capsule_broadphase=cycle in ["envelope_b","combined_b","aim_b"]
	hose.fps_aim_enabled=cycle=="aim_b"
	hose.fps_once_per_frame=OS.get_environment("ORISON_HOSE_AIM_SCHEDULE")=="1"
	if OS.get_environment("ORISON_HOSE_CAPTURE_CAST")=="1":hose.cast_observer=_capture_cast
	profile_phase="fps_acquire_excluded"
	var picked:=false
	for point: Vector3 in [Vector3(0,.155,.014),Vector3(0,.065,.020),Vector3(0,.04,.020)]:
		await helper.aim(actor._play_pipe.to_global(point))
		if player._grab.find_target().get("part")==actor._play_pipe:picked=true;break
	if not _require(picked,"FPS diagnostic targets original nozzle"):return []
	for frame in 4:await get_tree().process_frame
	profile_phase="fps_hose_"+cycle+"_held"
	hose.motion_profile_records.clear()
	helper.click()
	if not _require(player._grab.holding_pickup(),"deployed hose uses current FPS pickup hand"):return []
	if cycle=="aim_b" and not _require(player.held_stock_body()==actor._nozzle_joint.body,"hose pickup registers the existing sibling physics body"):return []
	var rows: Array=[]
	var previous_tip: Vector3=hose.rig.strand.points[0]
	for step in 40:
		if step>=16:
			profile_phase="fps_hose_"+cycle+"_turning"
			var event:=InputEventMouseMotion.new();event.relative=Vector2(2. if step<28 else -2.,0)
			player._unhandled_input(event)
		await RenderingServer.frame_post_draw
		var forward: Vector3=-player.camera.global_basis.z
		var nozzle: Vector3=actor._nozzle_joint.body.global_basis.y
		var current_tip: Vector3=hose.rig.strand.points[0]
		rows.append({"cycle":cycle,"step":step,"progress_m":previous_tip.distance_to(current_tip),"tip":[current_tip.x,current_tip.y,current_tip.z],"physics_frame":Engine.get_physics_frames(),"process_frame":Engine.get_process_frames(),"profile":hose.last_motion_profile.duplicate(true),"held":player._grab.holding_pickup(),"feedback":player._grab.feedback({}).state,"aim_error_degrees":rad_to_deg(acos(clampf(forward.dot(nozzle),-1.,1.))),"error":hose.error,"fitting_blocker":hose.last_fitting_blocker})
		previous_tip=current_tip
		await get_tree().process_frame
		if not player._grab.active():break
	profile_phase="fps_hose_"+cycle+"_release"
	if player._grab.active():helper.click()
	for frame in 4:await get_tree().process_frame
	_fps_samples.append_array(rows)
	var calls: Array=hose.motion_profile_records.duplicate(true)
	for call: Dictionary in calls:call.cycle=cycle
	_fps_calls.append_array(calls)
	_write_profile("fps_calls_"+cycle+".json",{"evidence_class":"INERT","calls":calls,"samples":rows,"failures":failures})
	_write_profile("fps_calls.json",{"evidence_class":"INERT","calls":_fps_calls,"samples":_fps_samples,"failures":failures})
	return rows

func _capture_cast(query: PhysicsShapeQueryParameters3D,candidates: Array[Dictionary],stage: String,fractions: PackedFloat32Array) -> void:
	if _cast_captured:return
	_cast_captured=true
	var root:=Node3D.new();root.name="CapturedFittingCast"
	root.set_meta("query_shape",query.shape.duplicate(true))
	root.set_meta("query_transform",query.transform);root.set_meta("query_motion",query.motion)
	root.set_meta("query_margin",query.margin);root.set_meta("query_mask",query.collision_mask)
	root.set_meta("original_fractions",fractions);root.set_meta("stage",stage)
	var seen: Dictionary={}
	for hit: Dictionary in candidates:
		var original: CollisionObject3D=hit.collider
		if seen.has(original.get_instance_id()):continue
		seen[original.get_instance_id()]=true
		var body:=StaticBody3D.new();body.name="Candidate"+str(seen.size());body.transform=original.global_transform
		body.collision_layer=original.collision_layer;body.set_meta("original_path",str(original.get_path()))
		root.add_child(body);body.owner=root
		for owner_id: int in original.get_shape_owners():
			if original.is_shape_owner_disabled(owner_id):continue
			for index in original.shape_owner_get_shape_count(owner_id):
				var shape:=CollisionShape3D.new();shape.shape=original.shape_owner_get_shape(owner_id,index).duplicate(true)
				shape.transform=original.shape_owner_get_transform(owner_id);body.add_child(shape);shape.owner=root
	var packed:=PackedScene.new()
	var packed_ok: bool=packed.pack(root)==OK
	var saved: bool=packed_ok and ResourceSaver.save(packed,_output_root.path_join("blocked_cast.tscn"))==OK
	_require(saved,"failed fitting cast and actual candidate shapes are preserved for isolated replay")
	print("FITTING CAST CAPTURE: ",stage," fractions=",fractions," candidates=",seen.size())
	root.free()
