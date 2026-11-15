extends Node
## Diagnostic old/new render comparison; no passenger or gameplay acceptance.
const FinishOwner := preload("res://scripts/building/orison_v2_owner_building_finishes.gd")
const FinishRecipes := preload("res://scripts/building/orison_v2_owner_finishes.gd")

func run(world: OrisonV2RuntimeRoot, check: Callable) -> Dictionary:
	var result := {"executed":true,"scope":"Same-world old3/new16batch, identical editor-import parameters,60warm/180samples per arm at closed/open owner poses. Diagnostic, not whole-game budget acceptance.","legs":[]}
	var imports := {}
	for path: String in ["res://assets/props/lift_gate.glb", "res://tests/fixtures/lift_gate_legacy.glb"]:
		var config:=ConfigFile.new()
		if config.load(path+".import")!=OK:
			check.call(false,"both real scene importer sidecars exist");return {"executed":false,"status":"FAIL"}
		var params: Dictionary={}
		for option: String in config.get_section_keys("params"):params[option]=config.get_value("params",option)
		imports[path]={"sha256":FileAccess.get_sha256(path),"params":params,"resource":config.get_value("remap","path")}
	if imports.values()[0].params!=imports.values()[1].params:
		check.call(false,"editor import parameter parity");return {"executed":false,"status":"FAIL"}
	result.imports=imports
	var lift: OrisonElevator=world.elevator
	var current: Node3D=lift._gate.get_node("ArticulatedGate")
	var legacy: Node3D=preload("res://tests/fixtures/lift_gate_legacy_driver.gd").new()
	legacy.name="LegacyGateCostReference"
	legacy.call("mount",lift)
	var finish := FinishOwner.new()
	finish.finish=FinishRecipes.new()
	finish._apply(legacy,"lift",lift._cabin)
	legacy.hide()
	var original_gate_transform: Transform3D=lift._gate.transform
	var original_visible: bool=current.visible
	var original_camera: Camera3D=get_viewport().get_camera_3d()
	var original_mirror: Camera3D=world.mirror_renderer._main_camera
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.global_position=lift._cabin.to_global(Vector3(.12,1.25,-.30))
	camera.look_at(lift._cabin.to_global(Vector3(0,1.2,.95)))
	camera.make_current()
	var old_max:=Engine.max_fps
	var old_vsync:=DisplayServer.window_get_vsync_mode()
	Engine.max_fps=0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var rid:=get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid,true)
	result.settings={"viewport":get_viewport().get_visible_rect().size,"adapter":RenderingServer.get_video_adapter_name(),
		"method":RenderingServer.get_current_rendering_method(),"msaa":get_viewport().msaa_3d,"taa":get_viewport().use_taa,
		"scale":get_viewport().scaling_3d_scale,"camera":camera.global_transform,"fov":camera.fov,"max_fps":Engine.max_fps,"vsync":DisplayServer.window_get_vsync_mode()}
	result.meshes={}
	for pair: Array in [["old",legacy],["new",current]]:
		var records:=[]
		for node: Node in pair[1].get_children():
			if node is MultiMeshInstance3D:
				var mesh: ArrayMesh=node.multimesh.mesh
				records.append({"name":node.name,"instances":node.multimesh.instance_count,"surfaces":mesh.get_surface_count(),"format":mesh.surface_get_format(0),"shadow_mesh":mesh.shadow_mesh!=null,"resource":mesh.resource_path})
		result.meshes[pair[0]]=records
	check.call(result.meshes.old.size()==3 and result.meshes.new.size()==16,"actual old3/new16 render batches")
	var complete:=true
	var before: float=lift.landing_door_open_fraction(lift.current)
	for opening: float in [0.0,1.0]:
		if not lift.set_landing_door_for_service(lift.current,opening):
			check.call(false,"idle landing owner accepts diagnostic render pose")
			complete=false;break
		lift._drive_cab_hardware()
		for variant: String in ["oldA","newB","oldA2"]:
			current.visible=variant=="newB"
			legacy.visible=variant!="newB"
			for warm in 60:await RenderingServer.frame_post_draw
			var samples: Array=[]
			var previous:=Time.get_ticks_usec()
			for frame in 180:
				await RenderingServer.frame_post_draw
				var now:=Time.get_ticks_usec()
				samples.append([float(now-previous)/1000.0,RenderingServer.viewport_get_measured_render_time_cpu(rid),
					RenderingServer.viewport_get_measured_render_time_gpu(rid),Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
					Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
				previous=now
			var times:=[]
			for sample: Array in samples:times.append(sample[0])
			times.sort()
			result.legs.append({"opening":opening,"variant":variant,"samples":samples,"p50_ms":times[90],"p95_ms":times[171],"p99_ms":times[178],"max_ms":times[179]})
			await RenderingServer.frame_post_draw
			check.call(get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT_DIR").path_join("cost_"+str(int(opening))+"_"+variant+".png"))==OK,"diagnostic cost arm capture")
	current.visible=original_visible
	legacy.free()
	check.call(lift.set_landing_door_for_service(lift.current,before),"original owner door pose restored after cost comparison")
	lift._drive_cab_hardware()
	Engine.max_fps=old_max
	DisplayServer.window_set_vsync_mode(old_vsync)
	lift._gate.transform=original_gate_transform
	original_camera.make_current()
	world.mirror_renderer._main_camera=original_mirror
	RenderingServer.viewport_set_measure_render_time(rid,false)
	camera.free()
	check.call(complete and result.legs.size()==6,"all six diagnostic comparison arms completed")
	result.status="RECORDED" if complete and result.legs.size()==6 else "FAIL"
	return result
