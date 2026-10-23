extends "res://tests/v2_service_set_hand_world_test.gd"
## INERT paired capture-shadows study after the ordinary route and hand checks.
func configure_treatment() -> void:
	RenderingServer.viewport_set_measure_render_time(world.mirror_renderer._view.get_viewport_rid(),true)

func _process(delta: float) -> void:
	super._process(delta)
	var mirror: PlanarMirrorRenderer=world.mirror_renderer
	samples[-1].mirror_active=is_instance_valid(mirror.active_mirror())
	samples[-1].mirror_occlusion=mirror._view.use_occlusion_culling
	samples[-1].mirror_cpu_ms=RenderingServer.viewport_get_measured_render_time_cpu(mirror._view.get_viewport_rid())
	samples[-1].mirror_gpu_ms=RenderingServer.viewport_get_measured_render_time_gpu(mirror._view.get_viewport_rid())

func review_controls() -> Dictionary:
	var result: Dictionary=await super.review_controls()
	var survey:=preload("res://tests/v2_area_survey.gd").new()
	var switches: SwitchSystem=world.get_node("V2RoomSwitches")
	var records: Array=[]
	player.set_physics_process(false);player.set_lamp_enabled(false)
	carrier.set_capture_hidden(true);reflections.set_physics_process(false)
	for spec in [["F03_B_BATH","F03_3B_MIRROR_01"],["F06_B_KITCHEN","F06_6B_KITCHEN_SINK_01"]]:
		var identity: String=spec[0]
		var room: Dictionary={}
		for entry: Dictionary in world.layout.spaces:
			if str(entry.id)==identity:room=entry;break
		var stance: Dictionary=survey._stance(world,world.adapter.root,room.rect,world.adapter.root.level_y[room.level])
		if stance.is_empty():check(false,"clear capsule for paired capture "+identity);continue
		player.global_position=Vector3(stance.feet[0],stance.feet[1],stance.feet[2])
		var subject: Node3D=world.adapter.resolve(spec[1])
		if subject==null:check(false,"paired view subject resolves "+str(spec[1]));continue
		var target:=subject.global_position+Vector3.UP*1.1
		if "BATH" in identity:
			for surface in get_tree().get_nodes_in_group("planar_mirror_surface"):
				var cabinet: Node=surface.get_parent()
				while cabinet!=null and not cabinet.has_method("mirror_center"):cabinet=cabinet.get_parent()
				if cabinet!=null and str(cabinet.name)==str(spec[1]):target=cabinet.mirror_center();break
		player.face_world_point(target)
		await get_tree().physics_frame
		if not reflections.probes.has(identity):reflections._create(identity)
		if not reflections.probes.has(identity):check(false,"paired room probe exists "+identity);continue
		var probe: ReflectionProbe=reflections.probes[identity]
		var original_shadows:=probe.enable_shadows
		var original:=switches.room_snapshot(identity)
		for powered in [true,false]:
			var wanted: Dictionary={}
			for key: String in original:wanted[key]=powered
			check(switches.restore_room(identity,wanted),"paired lighting owner sets "+identity+" "+str(powered))
			for shadows in [true,false]:
				var label:=identity+("_lit" if powered else "_dark")+("_shadows" if shadows else "_unshadowed")
				mode=label;previous=Time.get_ticks_usec();set_process(true)
				# Retain a few full samples before the refresh, so excluding a
				# partial first frame cannot hide the capture's stall.
				for frame in 6:await get_tree().process_frame
				probe.enable_shadows=shadows;reflections._refresh(identity)
				for tick in 90:await get_tree().physics_frame
				set_process(false)
				await RenderingServer.frame_post_draw
				var filename:=label+".png"
				check(get_viewport().get_texture().get_image().save_png(directory.path_join(filename))==OK,"paired reflection image "+label)
				records.append({"id":identity,"powered":powered,"shadows":shadows,"image":filename,"eye":str(player.camera.global_transform),"origin":str(probe.global_position+probe.origin_offset),"refresh_count":reflections.refresh_count})
		switches.restore_room(identity,original);probe.enable_shadows=original_shadows
		if "BATH" in identity:
			player.set_physics_process(true)
			# A synchronous image readback can leave physics catching up.
			# Settle it before sampling the subsequent actual movement.
			for frame in 8:await RenderingServer.frame_post_draw
			mode=identity+"_mirror_oblique";previous=Time.get_ticks_usec();set_process(true)
			for frame in 6:await get_tree().process_frame
			key(KEY_A,true)
			for tick in 24:
				if tick==12:key(KEY_A,false)
				var motion:=InputEventMouseMotion.new();motion.relative=Vector2(1.5,0);Input.parse_input_event(motion)
				await get_tree().physics_frame
				await RenderingServer.frame_post_draw
			key(KEY_A,false);set_process(false);player.set_physics_process(false)
			await RenderingServer.frame_post_draw
			check(get_viewport().get_texture().get_image().save_png(directory.path_join(identity+"_mirror_oblique.png"))==OK,"actual sidestep and turn near mirror")
	FileAccess.open(directory.path_join("reflection_observations.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","records":records,"limits":"Two diagnostic camera stations, not walked access or material acceptance. Main scene shadows remain enabled; fixture personality/weather can vary. Refresh samples are still-eye, not the movement phases.","failures":failures},"\t"))
	survey.free()
	return result
