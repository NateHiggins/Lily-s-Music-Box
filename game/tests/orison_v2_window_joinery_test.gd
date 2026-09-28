extends "res://tests/orison_v2_lift_joinery_test.gd"
## All 72 installed openings: original glazing, framed apertures, actual walls.
func _run() -> void:
	RealityState.persistence_enabled=false
	RealityState.reset_campaign_for_tests()
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var world := _world_scene().instantiate()
	add_child(world)
	await get_tree().physics_frame
	await get_tree().physics_frame
	world.player.set_physics_process(false); world.player.set_lamp_enabled(false)
	for child in world.player.carried_device.get_children():
		if child is CanvasLayer: child.hide()
	var root: Node3D=world.adapter.root
	var spaces: Dictionary={}
	for record: Dictionary in root.layout.spaces: spaces[str(record.id)]=record
	var camera := Camera3D.new()
	world.add_child(camera); camera.make_current(); camera.fov=80
	var fill := OmniLight3D.new()
	world.add_child(fill); fill.omni_range=3; fill.light_energy=.3
	var captured: Dictionary={}
	var count := 0
	var contacts := 0
	var trim_checks := 0
	for record: Dictionary in root.layout.windows:
		var opening := root.get_node(str(record.id)) as Node3D
		var frame := opening.get_node("FittedWindowJoinery") as MeshInstance3D
		check(frame.mesh is ArrayMesh,"complete Blender joinery installed "+str(record.id))
		check(opening.get_node("Glazing").visible,"original glazing retained")
		check(not opening.get_node("JambA").visible and not opening.get_node("JambB").visible,"primitive jambs hidden")
		var faces := frame.mesh.get_faces()
		var room := root.get_node(str(record.space)) as Node3D
		for label in ["HistoricMillwork","PublicWainscot","PublicWainscotFrames"]:
			var trim := room.get_node_or_null(label) as MultiMeshInstance3D
			if trim==null: continue
			for index in trim.multimesh.instance_count:
				var relative := frame.global_transform.affine_inverse()*trim.global_transform*trim.multimesh.get_instance_transform(index)
				var bounds: AABB=(relative*trim.multimesh.mesh.get_aabb()).grow(-.0002)
				if not frame.mesh.get_aabb().intersects(bounds): continue
				var crossing := false
				for start in range(0,faces.size(),3):
					for edge in 3:
						if bounds.intersects_segment(faces[start+edge],faces[start+(edge+1)%3])!=null:
							crossing=true; break
					if crossing: break
				check(not crossing,"Blender window triangles do not enter room trim "+str(record.id)+"/"+label)
				trim_checks+=1
		if str(spaces[str(record.space)].get("class",""))=="public":
			var panel := room.get_node_or_null("PublicWainscot") as MultiMeshInstance3D
			var rect: Array=spaces[str(record.space)].rect
			var at := Vector3(float(record.center[0]),float(root.level_y[record.level])+minf(float(record.sill)*.5,.5),float(record.center[1]))
			var axis := 2 if str(record.axis)=="x" else 0
			var center := (float(rect[1])+float(rect[3]))*.5 if axis==2 else (float(rect[0])+float(rect[2]))*.5
			at[axis]+=signf(center-at[axis])*(float(root.layout.dimensions.partition_wall)*.5+.008)
			var covered := false
			if panel!=null:
				for index in panel.multimesh.instance_count:
					var bounds: AABB=panel.multimesh.get_instance_transform(index)*panel.multimesh.mesh.get_aabb()
					if bounds.has_point(at): covered=true
			check(covered,"public panel backing remains below the window sill "+str(record.id))
		for y in [-.24,.24]:
			check(not is_finite(_mesh_distance(faces,Vector3(.1,y,-.4),Vector3.BACK)),"upper and lower sash apertures remain open")
			var through := PhysicsRayQueryParameters3D.create(frame.to_global(Vector3(.1,y,-.3)),frame.to_global(Vector3(.1,y,.3)),1,[world.player.get_rid()])
			through.hit_from_inside=true
			check(world.get_world_3d().direct_space_state.intersect_ray(through).is_empty(),"actual sash opening is not sealed by a room wall or service chase "+str(record.id))
		for y in [-.52,0,.52]:
			check(is_finite(_mesh_distance(faces,Vector3(0,y,-.4),Vector3.BACK)),"bottom rail, meeting rail and head have actual geometry")
		for side in [-1.0,1.0]:
			for face in [-1.0,1.0]:
				var local_x: float=side*(.5+.02/float(record.width))
				var origin := Vector3(local_x,0,face*.30)
				var end := Vector3(local_x,0,-face*.30)
				var ray := PhysicsRayQueryParameters3D.create(frame.to_global(origin),frame.to_global(end),1,[world.player.get_rid()])
				var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(ray)
				check(not hit.is_empty(),"window reveal has an actual masonry backing "+str(record.id))
				if not hit.is_empty(): check(absf(absf(frame.to_local(hit.position).z)-.175)<.002,"frame depth follows actual wall faces")
				contacts+=1
		var rect: Array=spaces[str(record.space)].rect
		var axis := str(record.axis)
		var outward := signf(float(record.center[1])-(float(rect[1])+float(rect[3]))*.5) if axis=="x" else signf(float(record.center[0])-(float(rect[0])+float(rect[2]))*.5)
		var key := axis+str(outward)
		if not captured.has(key):
			var room_depth := float(rect[3])-float(rect[1]) if axis=="x" else float(rect[2])-float(rect[0])
			var normal := frame.global_basis.z.normalized()*outward
			camera.global_position=frame.global_position-normal*minf(room_depth*.6,1.5)
			camera.look_at(frame.global_position)
			fill.global_position=camera.global_position
			var view_ray := PhysicsRayQueryParameters3D.create(camera.global_position,frame.global_position,1,[world.player.get_rid()])
			view_ray.hit_from_inside=true
			var obstruction: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(view_ray)
			check(obstruction.is_empty(),"inspection view reaches the installed frame "+str(record.id))
			await shot("window_"+key)
			captured[key]=true
		count+=1
	check(count==72 and contacts==288,"all windows and both wall faces covered")
	check(trim_checks>0,"actual neighboring trim was checked")
	print("WINDOW JOINERY: openings=%d wall_contacts=%d failures=%d" % [count,contacts,failures.size()])
	print("WINDOW TRIM: adjacent_strips=%d failures=%d" % [trim_checks,failures.size()])
	world.shutdown_for_tests(); world.free()
	get_tree().quit(0 if failures.is_empty() else 1)
