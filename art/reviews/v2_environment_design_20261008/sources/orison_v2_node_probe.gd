extends "res://tests/orison_v2_floor_surface_test.gd"
## Dossier inspection probe: list the drawable nodes crossing a box and take framed captures.
## Copy beside game/tests to run it through the lane (it is not a suite).
## PROBE_BOXES: "name:x0,y0,z0,x1,y1,z1[@px,py,pz];..."  PROBE_SHOTS: "name:fx,fy,fz,tx,ty,tz;..." (feet, target) in adapter-root metres (the blockout frame).
## The clock is frozen at the packet's 1928-11-10 20:00. PROBE_LAMP=0 takes the shots with the hand lamp off
## (an acceptance condition for lighting rows); each shot settles 1.8 s so the storey gate has faded in.
func _run() -> void:
	RealityState.persistence_enabled=false
	RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928,11,10,20*60)
	GameBoot.launch_mode=GameBoot.LaunchMode.CINEMATIC
	var world := _world_scene().instantiate()
	add_child(world)
	await get_tree().physics_frame
	await get_tree().physics_frame
	for spec: String in OS.get_environment("PROBE_BOXES").split(";", false):
		var name := spec.get_slice(":", 0)
		var v := spec.get_slice(":", 1).get_slice("@", 0).split(",")
		# Optional "@x,y,z": stand the player there first (V2 shows only the player's floor).
		if "@" in spec and world.player != null:
			var at := spec.get_slice("@", 1).split(",")
			world.player.global_position = world.adapter.root.to_global(Vector3(float(at[0]), float(at[1]), float(at[2])))
			world.player.velocity = Vector3.ZERO
			for i in 20: await get_tree().physics_frame
		var box: AABB = world.adapter.root.global_transform * AABB(Vector3(float(v[0]), float(v[1]), float(v[2])), Vector3(float(v[3]) - float(v[0]), float(v[4]) - float(v[1]), float(v[5]) - float(v[2])))
		var found := 0
		for node: Node in world.find_children("*", "GeometryInstance3D", true, false):
			var g := node as GeometryInstance3D
			if not g.is_visible_in_tree(): continue
			var aabb: AABB = g.global_transform * g.get_aabb()
			if not aabb.intersects(box): continue
			found += 1
			var local_box: AABB = world.adapter.root.global_transform.affine_inverse() * aabb
			print("PROBE ", name, " ", g.get_path(), " local=", local_box)
		print("PROBE ", name, " total=", found)
	var shots := OS.get_environment("PROBE_SHOTS")
	if not shots.is_empty() and world.player != null:
		DirAccess.make_dir_recursive_absolute(OS.get_environment("SHOT_DIR"))
		for layer: CanvasLayer in world.find_children("*", "CanvasLayer", true, false): layer.hide()
		world.player.set_physics_process(false)
		for driver: CampaignClockDriver in get_tree().get_nodes_in_group("campaign_time_owner"): driver.set_frozen_for_tests(true)
		if world.get("service_set_carrier") != null: world.service_set_carrier.set_capture_hidden(true)
		for spec: String in shots.split(";", false):
			var name := spec.get_slice(":", 0)
			var v := spec.get_slice(":", 1).split(",")
			world.player.global_position = world.adapter.root.to_global(Vector3(float(v[0]), float(v[1]), float(v[2])))
			world.player.velocity = Vector3.ZERO
			world.player.set_lamp_enabled(OS.get_environment("PROBE_LAMP") != "0")
			for i in 12: await get_tree().physics_frame
			await get_tree().create_timer(1.8).timeout
			var target: Vector3 = world.adapter.root.to_global(Vector3(float(v[3]), float(v[4]), float(v[5])))
			var eye: Vector3 = world.player.camera.global_position
			var flat := Vector2(target.x - eye.x, target.z - eye.z)
			world.player.rotation.y = atan2(-flat.x, -flat.y)
			world.player.camera.rotation = Vector3(atan2(target.y - eye.y, flat.length()), 0, 0)
			for i in 12: await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var image := get_viewport().get_texture().get_image()
			image.save_png(OS.get_environment("SHOT_DIR").path_join(name + ".png"))
			print("PROBE shot ", name)
	world.free()
	get_tree().quit(0)
