extends "res://tests/orison_v2_floor_surface_test.gd"
## Installed leaf geometry, real vision apertures and retained shaft barriers.
## Ordinary passenger crossings are covered by the elevator route suite.
func _run() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	GameBoot.launch_mode = GameBoot.LaunchMode.CINEMATIC
	var world := _world_scene().instantiate()
	add_child(world)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var lift := world.elevator as OrisonElevator
	if lift==null or world.player==null:
		check(false,"production lift initialized")
		world.free(); get_tree().quit(1); return
	world.player.set_physics_process(false)
	world.player.set_lamp_enabled(false)
	for child in world.player.carried_device.get_children():
		if child is CanvasLayer: child.hide()
	for level: String in lift.stop_order: lift._set_door_t(level,0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var panels := 0
	var aperture_probes := 0
	var barriers := 0
	for level: String in lift.stop_order:
		var bounds: Array[AABB] = []
		for side: String in ["w","e"]:
			var body := lift._doors[level][side] as AnimatableBody3D
			var parts: Dictionary = lift._panel_visuals[body]
			var skin := parts.skin as MeshInstance3D
			var glass := parts.glass as MeshInstance3D
			var kick := parts.kick as MeshInstance3D
			check(skin.mesh is ArrayMesh and kick.mesh is ArrayMesh,"Blender skin and kick plate installed")
			check(body.get_child_count()==4 and body.get_child(0) is CollisionShape3D,"one original moving barrier and three visuals remain")
			var shape := (body.get_child(0) as CollisionShape3D).shape as BoxShape3D
			check(shape.size.is_equal_approx(Vector3(.5,2.06,.045)),"physical shaft barrier retains its full original envelope")
			check((glass.mesh as BoxMesh).size.is_equal_approx(Vector3(.108,.318,.006)),"glazing fits inside its metal aperture")
			check(glass.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"transparent pane does not cast an opaque window shadow")
			var faces := skin.mesh.get_faces()
			for offset: Vector2 in [Vector2.ZERO,Vector2(-.035,0),Vector2(.035,0),Vector2(0,-.10),Vector2(0,.10)]:
				var eye := glass.position+Vector3(offset.x,offset.y,.2)
				check(not _mesh_blocks(faces,eye),"vision opening is cut through actual steel triangles")
				aperture_probes+=1
			check(_mesh_blocks(faces,Vector3(0,-.35,.2)),"pressed steel field remains solid around the window")
			var ray := PhysicsRayQueryParameters3D.create(body.to_global(glass.position+Vector3.BACK*.2),body.to_global(glass.position+Vector3.FORWARD*.2),1,[world.player.get_rid()])
			var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(ray)
			check(not hit.is_empty() and hit.collider==body,"closed glazed leaf still blocks physical passage into shaft")
			barriers+=1
			bounds.append(body.transform*skin.get_aabb())
			panels+=1
		check(absf(bounds[1].position.x-bounds[0].end.x-.002)<.0001,"closed steel leaves have a two-millimetre seam instead of coplanar overlap")
	check(panels==14 and aperture_probes==70 and barriers==14,"all seven pairs checked")
	var camera := Camera3D.new()
	world.add_child(camera); camera.make_current()
	camera.fov = 100
	var floor_y := float(lift.stops[lift.current])
	camera.global_position = lift.to_global(Vector3(0,floor_y+1.2,1.9))
	camera.look_at(lift.to_global(Vector3(0,floor_y+1.2,OrisonElevator.FRONT_Z)))
	var fill := OmniLight3D.new()
	world.add_child(fill)
	fill.global_position = camera.global_position; fill.omni_range=3; fill.light_energy=.35
	await shot("closed_lift_panels")
	var leaf := lift._doors[lift.current]["w"] as Node3D
	var window := lift._panel_visuals[leaf].glass as MeshInstance3D
	camera.fov = 75
	camera.global_position = window.global_position+lift.global_basis*Vector3(-.10,.03,.4)
	camera.look_at(window.global_position)
	fill.global_position=camera.global_position; fill.light_energy=.09
	await shot("lift_vision_window")
	lift._set_door_t(lift.current,1)
	await get_tree().physics_frame
	camera.fov=100
	camera.global_position=lift.to_global(Vector3(0,floor_y+1.2,1.9))
	camera.look_at(lift.to_global(Vector3(0,floor_y+1.2,OrisonElevator.FRONT_Z)))
	fill.global_position=camera.global_position; fill.light_energy=.35
	await shot("open_lift_panels")
	print("LIFT PANELS: leaves=%d aperture_probes=%d physical_barriers=%d failures=%d" % [panels,aperture_probes,barriers,failures.size()])
	world.shutdown_for_tests(); world.free()
	get_tree().quit(0 if failures.is_empty() else 1)

func _mesh_blocks(faces: PackedVector3Array, origin: Vector3) -> bool:
	for i in range(0,faces.size(),3):
		if Geometry3D.ray_intersects_triangle(origin,Vector3.FORWARD,faces[i],faces[i+1],faces[i+2])!=null: return true
	return false
