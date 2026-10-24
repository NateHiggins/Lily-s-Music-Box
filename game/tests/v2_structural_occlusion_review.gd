extends "res://tests/orison_v2_vertical_route_test.gd"
const Occlusion := preload("res://scripts/building/orison_v2_structural_occlusion.gd")

func _init() -> void: route_label="V2 STRUCTURAL OCCLUSION REVIEW"

func _route() -> void:
	var directory:=OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(directory)
	var solid:=world.get_node_or_null("V2StructuralOcclusion")
	var admitted:=0
	if solid==null:
		solid=Occlusion.new();world.add_child(solid)
		admitted=solid.setup(world._blockout)
	else: admitted=solid.sources.size()
	var views: Array[SubViewport]=[]
	var cameras: Array[Camera3D]=[]
	for i in 2:
		var view:=SubViewport.new();view.size=Vector2i(1280,720)
		view.world_3d=world.get_world_3d();view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
		view.use_occlusion_culling=i==1;view.msaa_3d=get_viewport().msaa_3d
		add_child(view);views.append(view)
		RenderingServer.viewport_set_measure_render_time(view.get_viewport_rid(),true)
		var eye:=Camera3D.new();view.add_child(eye);eye.make_current();cameras.append(eye)
	var stations: Array=[
		["lobby",Vector3(1.925,1.43,-3.5),Vector3(1.925,1.43,-7.5)],
		["street",Vector3(0,1.43,-12.2),Vector3(0,1.43,-8.5)],
		["upper_landing",Vector3(3.975,11.01,-3.4),Vector3(1.925,11.01,-3.4)],
		["mina_room",Vector3(-8.5,4.61,0),Vector3(-13.4,4.3,.75)],
		["roof",Vector3(3.975,20.61,-3.4),Vector3(8,20.1,3)]]
	var records: Array=[]
	player.set_physics_process(false)
	for station: Array in stations:
		world.process_mode=Node.PROCESS_MODE_INHERIT
		player.global_position=world.adapter.root.to_global(station[1])-Vector3.UP*player.STANDING_EYE
		player.camera.global_position=world.adapter.root.to_global(station[1])
		player.camera.look_at(world.adapter.root.to_global(station[2]))
		for eye: Camera3D in cameras:
			eye.global_transform=player.camera.global_transform;eye.fov=player.camera.fov
		for i in 30: await RenderingServer.frame_post_draw
		world.process_mode=Node.PROCESS_MODE_DISABLED
		var rows: Array=[]
		for i in 60:
			await RenderingServer.frame_post_draw
			rows.append([RenderingServer.viewport_get_measured_render_time_cpu(views[0].get_viewport_rid()),RenderingServer.viewport_get_measured_render_time_cpu(views[1].get_viewport_rid()),RenderingServer.viewport_get_measured_render_time_gpu(views[0].get_viewport_rid()),RenderingServer.viewport_get_measured_render_time_gpu(views[1].get_viewport_rid())])
		for i in 2: views[i].get_texture().get_image().save_png(directory.path_join(str(station[0])+"_"+("candidate" if i else "reference")+".png"))
		records.append({"station":station[0],"eye":str(player.camera.global_transform),"cpu0_cpu1_gpu0_gpu1_ms":rows})
	world.process_mode=Node.PROCESS_MODE_INHERIT
	for view: SubViewport in views: view.free()
	FileAccess.open(directory.path_join("occlusion.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","admitted_walls":admitted,"rejected_walls":solid.rejected,"stations":records},"\t"))
	print("STRUCTURAL OCCLUSION: ",admitted," conservative walls; ",records.size()," paired views")
