extends Node
## Sink-local installation survey and combined plumbing/trim diagnostics.
func run(world: OrisonV2RuntimeRoot,directory: String) -> Dictionary:
	var rows: Array=[];var failures: Array[String]=[]
	var camera:=Camera3D.new();world.add_child(camera);camera.make_current()
	world.player.set_physics_process(false);world.player.set_lamp_enabled(false);world.player.carried_device.set_capture_hidden(true)
	for layer: CanvasLayer in world.find_children("*","CanvasLayer",true,false):layer.hide()
	var baseboards:=0;var caps:=0;var eye_rails:=0
	for draw: MultiMeshInstance3D in world.find_children("*","MultiMeshInstance3D",true,false):
		if draw.name not in ["HistoricMillwork","PublicWainscotCap"]:continue
		var room:=draw.get_parent() as Node3D
		var record: Dictionary={}
		for space: Dictionary in world.layout.spaces:
			if space.id==str(room.name):record=space;break
		if record.is_empty():continue
		var floor_y: float=world.adapter.root.level_y[str(record.level)]
		for index in draw.multimesh.instance_count:
			var at: Vector3=(world.adapter.root.global_transform.affine_inverse()*draw.global_transform*draw.multimesh.get_instance_transform(index)).origin
			if draw.name=="PublicWainscotCap":caps+=1
			elif absf(at.y-floor_y-.07)<.02:baseboards+=1
			elif absf(at.y-floor_y-1.65)<.025:eye_rails+=1
	if eye_rails!=0 or baseboards<200 or caps==0:failures.append("Eye rail removal/baseboard-panel-cap retention")
	for tap: Node in world.adapter.root.find_children("*","Node3D",true,false):
		if not tap is TapProp or tap.fixture!="kitchen_sink":continue
		var excluded: Array[RID]=[]
		for body: CollisionObject3D in tap.find_children("*","CollisionObject3D",true,false):excluded.append(body.get_rid())
		var points: Array=[]
		for x: float in [-.095,0.,.095]:
			for y: float in [.22,.64,1.01]:
				var query:=PhysicsRayQueryParameters3D.create(tap.to_global(Vector3(x,y,.24)),tap.to_global(Vector3(x,y,1.24)),1,excluded)
				var hit:=world.get_world_3d().direct_space_state.intersect_ray(query)
				if hit.is_empty():points.append({"x":x,"y":y,"missing":true});continue
				var local: Vector3=tap.to_local(hit.position)
				points.append({"x":x,"y":y,"z":local.z,"owner":str(world.get_path_to(hit.collider))})
		rows.append({"unit":tap.unit,"compact":tap.compact_kitchen,"drainboard":tap.has_drainboard,"sink_name":str(tap.name),"rim_y":tap.kitchen_rim_height(),"ports":points})
		if tap.unit in ["2A","4B","5B"]:
			camera.global_position=tap.to_global(Vector3(.62,.70,-1.4));camera.look_at(tap.to_global(Vector3(.02,.53,.08)));camera.fov=56.
			for frame in 6:await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(directory.path_join("sink_"+tap.unit+".png"))
	var result: Dictionary={"evidence_class":"INERT","scope":"Current production sink-local wall ports and posed WIP; no route/acceptance proof","sinks":rows,"eye_rails":eye_rails,"baseboards":baseboards,"panel_caps":caps,"failures":failures}
	FileAccess.open(directory.path_join("plumbing_review.json"),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("SINK PLUMBING REVIEW: sinks=",rows.size()," eye_rails=",eye_rails," retained_baseboards=",baseboards," panel_caps=",caps," failures=",failures.size())
	camera.free();return result
