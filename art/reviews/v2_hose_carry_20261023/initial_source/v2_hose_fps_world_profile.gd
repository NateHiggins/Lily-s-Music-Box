extends "res://tests/v2_unracked_hose_world_survey.gd"
## INERT: observe current pickup semantics in the actual occupied world.
func _init() -> void:route_label="V2 FPS HOSE WORLD PROFILE"

func _ready() -> void:
	var directory:=OS.get_environment("SHOT_DIR")
	if not directory.is_empty():DirAccess.make_dir_recursive_absolute(directory)
	super._ready()

func _carry_control(actor: Node3D,hose: Node3D,helper: Node,cycle: String) -> Array:
	profile_phase="fps_acquire_excluded"
	var picked:=false
	for point: Vector3 in [Vector3(0,.155,.014),Vector3(0,.065,.020),Vector3(0,.04,.020)]:
		await helper.aim(actor._play_pipe.to_global(point))
		if player._grab.find_target().get("part")==actor._play_pipe:picked=true;break
	if not _require(picked,"FPS diagnostic targets original nozzle"):return []
	for frame in 4:await get_tree().process_frame
	profile_phase="fps_hose_held"
	helper.click()
	if not _require(player._grab.holding_pickup(),"deployed hose uses current FPS pickup hand"):return []
	var rows: Array=[]
	for step in 40:
		var before: Vector3=hose.rig.strand.points[0]
		if step>=16:
			profile_phase="fps_hose_turning"
			var event:=InputEventMouseMotion.new();event.relative=Vector2(2. if step<28 else -2.,0)
			player._unhandled_input(event)
		await RenderingServer.frame_post_draw
		var forward: Vector3=-player.camera.global_basis.z
		var nozzle: Vector3=actor._nozzle_joint.body.global_basis.y
		rows.append({"cycle":cycle,"step":step,"progress_m":before.distance_to(hose.rig.strand.points[0]),"physics_frame":Engine.get_physics_frames(),"process_frame":Engine.get_process_frames(),"profile":hose.last_motion_profile.duplicate(true),"held":player._grab.holding_pickup(),"feedback":player._grab.feedback({}).state,"aim_error_degrees":rad_to_deg(acos(clampf(forward.dot(nozzle),-1.,1.))),"error":hose.error})
		await get_tree().process_frame
		if not player._grab.active():break
	profile_phase="fps_hose_release"
	if player._grab.active():helper.click()
	for frame in 4:await get_tree().process_frame
	FileAccess.open(OS.get_environment("SHOT_DIR").path_join("fps_calls.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","calls":hose.motion_profile_records,"samples":rows,"failures":failures},"\t"))
	return rows
