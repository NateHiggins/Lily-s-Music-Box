extends "res://tests/v2_handheld_profile.gd"
## INERT actual-input causal controls; no diagnostic bypass qualifies runtime.
func configure_treatment() -> void:
	treatment="bath_contact_diagnosis"
	world.player.profile_physics=true
	RenderingServer.viewport_set_measure_render_time(world.mirror_renderer._view.get_viewport_rid(),true)

func _process(delta: float) -> void:
	super._process(delta)
	samples[-1].physics_frame=Engine.get_physics_frames()
	samples[-1].mirror_active=is_instance_valid(world.mirror_renderer.active_mirror())
	samples[-1].mirror_cpu_ms=RenderingServer.viewport_get_measured_render_time_cpu(world.mirror_renderer._view.get_viewport_rid())
	samples[-1].mirror_gpu_ms=RenderingServer.viewport_get_measured_render_time_gpu(world.mirror_renderer._view.get_viewport_rid())

func review_controls() -> Dictionary:
	var identity: String="F03_B_BATH"
	var room: Dictionary={}
	for entry: Dictionary in world.layout.spaces:
		if str(entry.id)==identity:room=entry;break
	var survey:=preload("res://tests/v2_area_survey.gd").new()
	var stance: Dictionary=survey._stance(world,world.adapter.root,room.rect,world.adapter.root.level_y[room.level]);survey.free()
	if stance.is_empty():check(false,"standing capsule for bath profile");return {}
	var feet:=Vector3(stance.feet[0],stance.feet[1],stance.feet[2])
	var mirror: PlanarMirrorRenderer=world.mirror_renderer
	var subject: Vector3=feet+Vector3.FORWARD
	for surface in get_tree().get_nodes_in_group("planar_mirror_surface"):
		var cabinet: Node=surface.get_parent()
		while cabinet!=null and not cabinet.has_method("mirror_center"):cabinet=cabinet.get_parent()
		if cabinet!=null and str(cabinet.name)=="F03_3B_MIRROR_01":subject=cabinet.mirror_center();break
	var switches: SwitchSystem=world.get_node("V2RoomSwitches")
	var original:=switches.room_snapshot(identity);var lit: Dictionary={}
	for id: String in original:lit[id]=true
	switches.restore_room(identity,lit)
	carrier.set_capture_hidden(true);player.set_lamp_enabled(false)
	reflections.set_physics_process(false)
	var records: Array=[]
	for label: String in ["static","normal","step_disabled","mirror_disabled","both_disabled","normal_repeat"]:
		key(KEY_A,false);key(KEY_D,false)
		player.global_position=feet;player.velocity=Vector3.ZERO;player.face_world_point(subject)
		player._profile_disable_step_up=label in ["step_disabled","both_disabled"]
		var mirror_off: bool=label in ["mirror_disabled","both_disabled"]
		mirror.set_process(not mirror_off)
		if mirror_off:mirror._sleep()
		player.set_physics_process(true)
		for tick in 20:await get_tree().physics_frame
		for frame in 8:await RenderingServer.frame_post_draw
		player.physics_profile_records.clear();player.step_guard_rejections=0
		mode="bath_"+label;previous=Time.get_ticks_usec();set_process(true)
		for tick in 120:
			if label!="static":
				if tick==0:key(KEY_A,true)
				if tick==12:key(KEY_A,false)
				if tick==36:key(KEY_D,true)
				if tick==48:key(KEY_D,false)
				if tick<48:
					var motion:=InputEventMouseMotion.new();motion.relative=Vector2(1.5 if tick<24 else -1.5,0);Input.parse_input_event(motion)
			await get_tree().physics_frame
		set_process(false);key(KEY_A,false);key(KEY_D,false)
		records.append({"phase":label,"start":str(feet),"end":str(player.global_position),"step_guard_rejections":player.step_guard_rejections,"physics":player.physics_profile_records.duplicate(true)})
		if label in ["normal","normal_repeat"]:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(directory.path_join(label+".png"))
	player._profile_disable_step_up=false;mirror.set_process(true)
	switches.restore_room(identity,original)
	FileAccess.open(directory.path_join("contact_profile.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","records":records,"limits":"120 physics ticks with identical key and turn sequence per moving phase; body collisions remain on. Step/mirror disables are diagnostics only. Physics records include ticks above 1 ms; rendering samples contain every process frame. No whole-world qualification."},"\t"))
	return {}
