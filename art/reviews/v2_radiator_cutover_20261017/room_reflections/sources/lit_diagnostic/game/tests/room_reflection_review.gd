extends "res://tests/annunciator_world_review.gd"
## INERT paired scene experiment. No extra lights, material calibration,
## runtime-contract promotion, or human appearance acceptance.
var observations: Array[Dictionary]=[]
func _run() -> void:
	out=OS.get_environment("SHOT_DIR")
	if out.is_empty() or DisplayServer.get_name()=="headless":get_tree().quit(1);return
	DirAccess.make_dir_recursive_absolute(out)
	RealityState.persistence_enabled=false;RealityState.reset_campaign_for_tests()
	CampaignTime.set_frozen_for_tests(true);GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var world := await _world()
	if world.startup_failed or world.player==null:world.free();_finish_reflections();return
	var player := world.player;player.set_physics_process(false)
	player.set_lamp_enabled(false)
	var deadline := Time.get_ticks_msec()+5000
	while player.flashlight.visible and Time.get_ticks_msec()<deadline:await get_tree().create_timer(.05).timeout
	check(not player.flashlight.visible,"comparison begins after the real lamp cools")
	var paused_before := get_tree().paused
	var lamp_layers_before := player.flashlight.layers
	get_tree().paused=true
	var manager := preload("res://scripts/building/orison_v2_room_reflections.gd").new()
	manager.name="CandidateRoomReflections";manager.process_mode=Node.PROCESS_MODE_ALWAYS
	world.add_child(manager);check(manager.setup(world),"candidate derives its rooms from composed layout")
	manager.set_reflections_enabled(false)
	var board := world.adapter.resolve("LobbyPorterBoard") as OtisProp
	var radiator := world.adapter.resolve("F02_B_RADIATOR_01") as RadiatorProp
	var boiler := world.adapter.resolve("B1_BOILER_01") as BoilerProp
	check(board!=null and radiator!=null and boiler!=null,"three installed assemblies resolve")
	if board==null or radiator==null or boiler==null:get_tree().paused=paused_before;world.free();_finish_reflections();return
	var stations: Array[Dictionary]=[
		{"id":"watch_board","actor":board,"frame":board,"eye":Vector3(.20,-.05,.65),"at":Vector3(0,0,.045),"space":"F01_WATCH"},
		{"id":"2b_radiator","actor":radiator,"frame":radiator.native_rig,"eye":Vector3(-.55,.85,-.90),"at":Vector3(-.35,.37,-.04),"space":"F02_B_MAIN"},
		{"id":"boiler_column","actor":boiler,"frame":boiler,"eye":Vector3(.8,1.3,-1.55),"at":Vector3(.50,1.08,-.585),"space":"B1_BOILER_ROOM"}]
	for station: Dictionary in stations:
		manager.set_reflections_enabled(false)
		get_tree().paused=false
		# LightRig selects a storey from the controller's feet while this
		# camera remains its child. Moving only that camera froze the wrong
		# floor's budgets in the first comparison. Settle the real circuit
		# and floor selection before freezing each A/B/A lighting state.
		var eye: Vector3=station.frame.to_global(station.eye)
		for room: Dictionary in manager.rooms:
			if room.id==station.space:
				var local_eye: Vector3=manager.frame.to_local(eye)
				local_eye.y=room.bounds.position.y+.02
				player.global_position=manager.frame.to_global(local_eye)
		var switches := world.get_node("V2RoomSwitches") as SwitchSystem
		var circuit := switches.room_snapshot(station.space)
		check(not circuit.is_empty(),"review room has an authoritative light circuit: "+station.id)
		for identity: String in circuit:circuit[identity]=true
		check(switches.restore_room(station.space,circuit),"existing room fixtures are powered for finish review: "+station.id)
		player.camera.global_position=station.frame.to_global(station.eye);player.camera.look_at(station.frame.to_global(station.at))
		await get_tree().create_timer(1.2).timeout
		check(world.light_rig.active_floor==str(station.space).get_slice("_",0),"light budget follows the reviewed storey: "+station.id)
		get_tree().paused=true
		check(manager.room_at(player.camera.global_position)==station.space,"camera is in its actual authored room: "+station.id)
		var frames := _normal_frames(station.actor)
		check(frames.surfaces>0 and frames.failures.is_empty(),"loaded normal-mapped surfaces retain usable tangent frames: "+station.id+" "+str(frames.failures))
		var materials := _material_state(station.actor)
		var lights := _light_state(world)
		var before := await _reflection_capture(station.id+"_sky_context")
		var environment: Environment=world.get_node("WakingAtmosphere").environment
		var ssr_before := environment.ssr_enabled
		environment.ssr_enabled=true
		var screen_space := await _reflection_capture(station.id+"_screen_space_context")
		environment.ssr_enabled=ssr_before
		manager.set_reflections_enabled(true)
		for count in range(180):
			await RenderingServer.frame_post_draw
			if manager.probes.has(station.space):break
		check(manager.active_id==station.space and manager.probes.has(station.space),"view follower creates a bounded room capture: "+station.id)
		var after := await _reflection_capture(station.id+"_room_context")
		var sky_retained: Image=after
		if manager.probes.has(station.space):
			var probe: ReflectionProbe=manager.probes[station.space]
			probe.interior=false;probe.position.x+=.00001
			sky_retained=await _reflection_capture(station.id+"_room_with_sky_context")
			probe.interior=true
		manager.set_reflections_enabled(false)
		var restored := await _reflection_capture(station.id+"_restored_sky_context")
		check(_material_state(station.actor)==materials,"comparison preserves actual material fields: "+station.id)
		check(_light_state(world)==lights,"comparison preserves fixtures and direct-light fields: "+station.id)
		check(manager.probes.size()<=manager.CACHE_LIMIT,"room capture cache remains bounded")
		observations.append({"id":station.id,"room":station.space,"normal_frames":frames,"screen_space_difference":_picture_difference(before,screen_space),"probe_difference":_picture_difference(before,after),"sky_retained_probe_difference":_picture_difference(before,sky_retained),"baseline_repeat_difference":_picture_difference(before,restored),"cached_probes":manager.probes.size()})
	check(manager.errors.is_empty(),"clear origins exist for reviewed captures")
	var lamp_layers := player.flashlight.layers
	manager.free()
	check(lamp_layers==1<<18 and player.flashlight.layers==lamp_layers_before,"candidate retirement restores the original carried-light layer")
	get_tree().paused=paused_before
	world.free();_finish_reflections()

func _reflection_capture(label: String) -> Image:
	for count in range(40):await RenderingServer.frame_post_draw
	var picture := get_viewport().get_texture().get_image()
	check(picture.save_png(out.path_join(label+".png"))==OK,label+" captured")
	return picture

func _material_state(actor: Node3D) -> Dictionary:
	var state := {}
	for draw: GeometryInstance3D in actor.find_children("*","GeometryInstance3D",true,false):
		var mesh: Mesh=draw.mesh if draw is MeshInstance3D else draw.multimesh.mesh if draw is MultiMeshInstance3D and draw.multimesh!=null else null
		if mesh==null:continue
		for index in mesh.get_surface_count():
			# Native fitted parts bind their catalogue stock per surface. Reading
			# only the imported mesh would compare unused exporter materials.
			var material: Material=draw.get_active_material(index) if draw is MeshInstance3D else draw.material_override if draw.material_override!=null else mesh.surface_get_material(index)
			if material is StandardMaterial3D:
				state[str(draw.get_instance_id())+"/"+str(index)]=[material.get_instance_id(),material.albedo_color,material.albedo_texture,material.roughness_texture,material.normal_texture,material.normal_enabled,material.normal_scale,material.metallic,material.roughness,material.uv1_scale,material.uv1_triplanar]
	return state

func _light_state(root: Node3D) -> Dictionary:
	var state := {}
	for light: Light3D in root.find_children("*","Light3D",true,false):state[light.get_instance_id()]=[light.light_energy,light.light_color,light.visible,light.global_transform]
	return state

func _normal_frames(actor: Node3D) -> Dictionary:
	var result := {"surfaces":0,"vertices":0,"max_normal_tangent_dot":0.0,"failures":[]}
	for draw: GeometryInstance3D in actor.find_children("*","GeometryInstance3D",true,false):
		var mesh: Mesh=draw.mesh if draw is MeshInstance3D else draw.multimesh.mesh if draw is MultiMeshInstance3D and draw.multimesh!=null else null
		if mesh==null:continue
		for index in mesh.get_surface_count():
			var material: Material=draw.get_active_material(index) if draw is MeshInstance3D else draw.material_override if draw.material_override!=null else mesh.surface_get_material(index)
			if not material is StandardMaterial3D or material.normal_texture==null:continue
			result.surfaces+=1
			var arrays := mesh.surface_get_arrays(index)
			var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var normals: Variant=arrays[Mesh.ARRAY_NORMAL]
			var tangents: Variant=arrays[Mesh.ARRAY_TANGENT]
			var label := str(draw.name)+"/"+str(index)
			if not material.normal_enabled or not normals is PackedVector3Array or not tangents is PackedFloat32Array or normals.size()!=vertices.size() or tangents.size()!=vertices.size()*4:
				result.failures.append(label+": disabled normal or missing vertex frame");continue
			var invalid := 0
			for vertex in vertices.size():
				var n: Vector3=normals[vertex]
				var t := Vector3(tangents[vertex*4],tangents[vertex*4+1],tangents[vertex*4+2])
				var sign_value: float=tangents[vertex*4+3]
				var dot := absf(n.dot(t))
				result.max_normal_tangent_dot=maxf(result.max_normal_tangent_dot,dot)
				if not n.is_finite() or not t.is_finite() or not is_finite(sign_value) or absf(n.length()-1.)>.02 or absf(t.length()-1.)>.02 or dot>.02 or absf(absf(sign_value)-1.)>.01:invalid+=1
			result.vertices+=vertices.size()
			if invalid>0:result.failures.append(label+": invalid frames="+str(invalid))
	return result

func _picture_difference(a: Image,b: Image) -> float:
	var sum := 0.;var samples := 0
	for y in range(0,a.get_height(),4):
		for x in range(0,a.get_width(),4):
			var p := a.get_pixel(x,y);var q := b.get_pixel(x,y)
			sum+=absf(p.r-q.r)+absf(p.g-q.g)+absf(p.b-q.b);samples+=3
	return sum/maxi(samples,1)

func _finish_reflections() -> void:
	FileAccess.open(out.path_join("room_reflection_review.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","checks":checks,"failures":failures,"observations":observations,"scope":"Paused-lighting A/B/A comparison of three installed assemblies. Candidate not production-enabled; no route, save, broad contract or human acceptance."},"\t"))
	print("ROOM REFLECTION REVIEW: ","PASS" if failures.is_empty() else "FAIL","; ",checks," checks; ",failures)
	terminal=true;get_tree().quit(0 if failures.is_empty() else 1)
