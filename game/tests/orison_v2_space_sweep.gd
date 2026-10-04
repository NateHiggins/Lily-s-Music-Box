extends "res://tests/orison_v2_floor_surface_test.gd"
## Discovery capture only: a clear station is not route or fabrication acceptance.
func _run() -> void:
	RealityState.persistence_enabled=false
	RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928,11,10,20*60)
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var world := _world_scene().instantiate() as OrisonV2RuntimeRoot
	add_child(world)
	await get_tree().physics_frame
	await get_tree().physics_frame
	world.player.set_physics_process(false)
	world.player.set_lamp_enabled(true)
	var filter := OS.get_environment("V2_SWEEP_LEVEL")
	var report: Array[Dictionary]=[]
	var directory := OS.get_environment("SHOT_DIR")
	check(not directory.is_empty(),"room sweep requires a screenshot directory")
	if directory.is_empty(): get_tree().quit(1); return
	for record: Dictionary in world.layout.spaces:
		if not filter.is_empty() and record.level!=filter: continue
		var entry := {"id":record.id,"level":record.level,"class":record.get("class",""),"purpose":record.get("purpose",""),"captures":[],"status":"uninspected"}
		var rect: Array=record.rect
		var floor_y: float=world.adapter.root.level_y[str(record.level)]
		var center := Vector3((float(rect[0])+float(rect[2]))*.5,floor_y+.8,(float(rect[1])+float(rect[3]))*.5)
		var candidates: Array[Vector3]=[]
		for u in [.16,.33,.5,.67,.84]:
			for v in [.16,.33,.5,.67,.84]:
				var at := Vector3(lerpf(float(rect[0]),float(rect[2]),u),floor_y+.03,lerpf(float(rect[1]),float(rect[3]),v))
				if _clear_station(world,at): candidates.append(at)
		entry["clear_stations"]=candidates.size()
		if candidates.is_empty():
			entry["status"]="no_clear_sampled_station_requires_review"
		else:
			var first: Vector3=candidates.front()
			var last := first
			for candidate in candidates:
				if candidate.distance_squared_to(first)>last.distance_squared_to(first): last=candidate
			var index := 0
			for at in [first,last]:
				# Retain a gameplay view, then expose the room in a paired survey
				# view without changing its real lamp or any production settings.
				world.service_set_carrier.set_capture_hidden(index==1)
				world.player.global_position=world.adapter.root.to_global(at)
				world.player.velocity=Vector3.ZERO
				var target := center
				if Vector2(at.x-center.x,at.z-center.z).length()<.25: target.z+=.7
				world.player.face_world_point(world.adapter.root.to_global(target))
				await get_tree().physics_frame
				await get_tree().create_timer(.65).timeout
				var label := str(record.id)+"_"+str(index)
				await shot(label)
				entry.captures.append({"image":label+".png","feet":[at.x,at.y,at.z],"device_visible":index==0})
				index+=1
			entry["status"]="captured_pending_visual_review"
		report.append(entry)
		var file := FileAccess.open(directory.path_join("spaces.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify({"evidence_class":"INERT","spaces":report},"\t"))
		print("SPACE SWEEP: ",record.id," ",entry.status)
	print("SPACE SWEEP COMPLETE: records=%d failures=%d" % [report.size(),failures.size()])
	world.shutdown_for_tests(); world.free()
	get_tree().quit(0 if failures.is_empty() else 1)

func _clear_station(world: OrisonV2RuntimeRoot, local: Vector3) -> bool:
	var root: Node3D = world.adapter.root
	var shape := CapsuleShape3D.new()
	shape.radius=PlayerController.BODY_RADIUS; shape.height=PlayerController.STANDING_HEIGHT
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape=shape; query.collision_mask=1
	query.transform=Transform3D(root.global_basis,root.to_global(local+Vector3.UP*(PlayerController.STANDING_HEIGHT*.5)))
	query.exclude=[world.player.get_rid()]
	if not world.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): return false
	var ray := PhysicsRayQueryParameters3D.create(root.to_global(local+Vector3.UP*.1),root.to_global(local-Vector3.UP*.12),1,[world.player.get_rid()])
	var hit: Dictionary=world.get_world_3d().direct_space_state.intersect_ray(ray)
	return not hit.is_empty() and hit.normal.dot(root.global_basis.y)>.9

