extends Node
## Exercise the restored volume with ordinary controller movement, then render.
var world: OrisonV2RuntimeRoot
var host: Node
var player: PlayerController
var trace: Array = []

func run(current: OrisonV2RuntimeRoot, owner: Node) -> void:
	world=current;host=owner;player=world.player
	var prior_physics := player.is_physics_processing()
	var prior_position := player.global_position
	var prior_rotation := player.rotation
	player.set_physics_process(true)
	player.set_lamp_enabled(false)
	player.carried_device.set_capture_hidden(true)
	await get_tree().create_timer(1.0).timeout
	for floor_index in range(2,7):
		var y := (floor_index-1)*3.2
		player.global_position=world.adapter.root.to_global(Vector3(6.8,y+.025,-3.25))
		player.velocity=Vector3.ZERO
		await get_tree().physics_frame
		for p in [Vector3(6.8,y,-4.6),Vector3(6.8,y,-8.2),Vector3(0,y,-9.8),Vector3(-4,y,-10.4),Vector3(6.8,y,-10.75),Vector3(8.9,y,-10.75),Vector3(8.9,y,-8.65)]:
			if not await _walk(p):break
		await _capture("front_gallery_%02d"%floor_index,Vector3(1.2,y+1.524,-6.7),Vector3(1.2,y+1.3,-12))
	# Each ground-floor leg starts in an existing public room, never inside the addition.
	for leg in [
		[Vector3(-4.85,0,-8.4),Vector3(-4.85,0,-9.8),Vector3(-3.7,0,-10.7)],
		[Vector3(4.85,0,-8.4),Vector3(4.85,0,-9.8),Vector3(4,0,-10.7),Vector3(6.8,0,-10.7),Vector3(8.9,0,-10.7),Vector3(8.9,0,-8.6)]]:
		player.global_position=world.adapter.root.to_global(leg[0]+Vector3.UP*.025);player.velocity=Vector3.ZERO
		await get_tree().physics_frame
		for p: Vector3 in leg.slice(1):
			if not await _walk(p):break
	await _capture("front_ground_bay",Vector3(-3.7,1.524,-9.8),Vector3(-3.7,1.4,-12.35))
	var atmosphere: Node=world.get_node("WakingAtmosphere")

	atmosphere.weather_manager._publish();atmosphere.director._apply(world.campaign_clock.minute_of_day())
	await _capture("front_restored_mass",Vector3(1.95,9,-37),Vector3(1.95,9.5,-12.35))
	await _capture("front_restored_entrance",Vector3(0,1.524,-18),Vector3(0,3,-12.35))
	var directory:=OS.get_environment("SHOT_DIR")
	if not directory.is_empty():
		var file:=FileAccess.open(directory.path_join("front-restoration-walk.json"),FileAccess.WRITE)
		if file!=null:file.store_string(JSON.stringify({"evidence_class":"INERT","scope":"Executed movement diagnostics within the surface review; not a spatial ledger contract.","trace":trace},"\t"))
	player.global_position=prior_position;player.rotation=prior_rotation;player.velocity=Vector3.ZERO
	player.set_physics_process(prior_physics)

func _walk(target_local: Vector3) -> bool:
	var target: Vector3=world.adapter.root.to_global(target_local)
	var started:=Time.get_ticks_msec()
	var budget:=maxi(12000,int(player.global_position.distance_to(target)/player.WALK*1000)+2000)
	var contacts: Array[String]=[]
	while Time.get_ticks_msec()-started<budget:
		var delta: Vector3=target-player.global_position;delta.y=0
		if delta.length()<.04:break
		player.rotation.y=atan2(-delta.x,-delta.z);player.camera.rotation=Vector3.ZERO
		Input.action_press("move_forward",clampf(delta.length()/.35,.25,1.0))
		await get_tree().physics_frame
		for i in player.get_slide_collision_count():
			var hit:=player.get_slide_collision(i)
			if absf(hit.get_normal().y)<.7 and hit.get_collider() is Node:
				var path:=str(hit.get_collider().get_path())
				if path not in contacts:contacts.append(path)
	Input.action_release("move_forward")
	var actual: Vector3=world.adapter.root.to_local(player.global_position)
	var ok:=Vector2(actual.x-target_local.x,actual.z-target_local.z).length()<.18 and absf(actual.y-target_local.y)<.15 and not player.noclip and player.collision_mask==1
	trace.append({"target":str(target_local),"actual":str(actual),"ok":ok,"contacts":contacts})
	host.check(ok,"restored front volume is walkable at "+str(target_local)+" actual="+str(actual)+" contacts="+str(contacts))
	return ok

func _capture(label: String, eye: Vector3, target: Vector3) -> void:
	var camera:=Camera3D.new();world.add_child(camera)
	camera.global_position=world.adapter.root.to_global(eye);camera.look_at(world.adapter.root.to_global(target));camera.make_current()
	await host.shot(label)
	camera.queue_free();player.camera.make_current()
