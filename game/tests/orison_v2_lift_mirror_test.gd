extends "res://tests/orison_v2_floor_surface_test.gd"
## Production moving mirror, analytic reflected marker pixels and shared budget.
var probes := 0

func _run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("Lift mirror proof requires windowed rendering")
		get_tree().quit(1); return
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
	var lift := world.elevator as OrisonElevator
	var mirror: Variant = lift._cab_mirror
	var renderer := world.mirror_renderer as PlanarMirrorRenderer
	var camera := Camera3D.new()
	world.add_child(camera); camera.make_current(); camera.fov=75
	renderer._main_camera=camera
	var markers: Array[MeshInstance3D] = []
	for index in 3:
		var marker := MeshInstance3D.new()
		var box := BoxMesh.new(); box.size=Vector3(.16,.20,.08)
		marker.mesh=box
		var mat := StandardMaterial3D.new()
		mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color=[Color(.95,.02,.02),Color(.02,.95,.02),Color(.02,.02,.95)][index]
		marker.material_override=mat
		lift._cabin.add_child(marker)
		marker.position=Vector3((index-1)*.30,1.52,.55)
		markers.append(marker)
	check(renderer.get_child_count()==1 and renderer.get_child(0) is SubViewport,"one shared mirror viewport for building and lift")
	check(renderer._camera.cull_mask & PlanarMirrorRenderer.MIRROR_LAYER == 0,"mirror glass excluded from reflected view")
	for offset in [-.20,0.0,.20]:
		camera.global_position=lift._cabin.to_global(Vector3(offset,1.52,-.10))
		camera.look_at(mirror.mirror_center())
		await shot("lift_mirror_"+str(offset))
		check(renderer.active_mirror()==mirror,"production cab surface selected")
		_check_pixels(camera,mirror,markers)
	var before: Vector3 = mirror.mirror_center()
	var target: String = lift.stop_order[lift.stop_order.find(lift.current)+1]
	var rise := float(lift.stops[target])-float(lift.stops[lift.current])
	lift.interact_area(lift._cabin_controls.areas[target])
	var elapsed := 0.0
	while lift.moving and elapsed<12:
		await get_tree().create_timer(.1).timeout
		elapsed+=.1
	check(lift.current==target and not lift.moving,"real car drive reaches next stop")
	check(absf(mirror.mirror_center().y-before.y-rise)<.01,"mirror follows car through actual ride")
	camera.global_position=lift._cabin.to_global(Vector3(0,1.52,-.10))
	camera.look_at(mirror.mirror_center())
	await shot("lift_mirror_after_ride")
	_check_pixels(camera,mirror,markers)
	for marker in markers: marker.hide()
	await shot("lift_mirror_gameplay")
	var household: MedicineCabinetProp
	for surface in get_tree().get_nodes_in_group("planar_mirror_surface"):
		var candidate := surface.get_parent().get_parent() as MedicineCabinetProp
		if candidate!=null:
			household=candidate; break
	check(household!=null,"production household mirror available for handoff")
	if household!=null:
		camera.global_position=household.mirror_center()+household.mirror_normal()*.8
		camera.look_at(household.mirror_center())
		await shot("bathroom_handoff")
		check(renderer.active_mirror()==household,"same view hands back to installed bathroom mirror")
		check(not mirror.mirror_surface().material_override is ShaderMaterial,"cab fallback restored on handoff")
	camera.global_position+=Vector3.UP*(PlanarMirrorRenderer.MAX_DISTANCE_M*100.0)
	await get_tree().process_frame
	await get_tree().process_frame
	check(renderer.active_mirror()==null and renderer._view.render_target_update_mode==SubViewport.UPDATE_DISABLED,"shared view sleeps out of range")
	check(not mirror.mirror_surface().material_override is ShaderMaterial,"fallback restored when mirror sleeps")
	print("LIFT MIRROR: reflected_pixel_probes=%d failures=%d" % [probes,failures.size()])
	world.shutdown_for_tests(); world.free()
	get_tree().quit(0 if failures.is_empty() else 1)

func _check_pixels(camera: Camera3D, mirror: Variant, markers: Array[MeshInstance3D]) -> void:
	var frame := get_viewport().get_texture().get_image()
	var center: Vector3 = mirror.mirror_center()
	var normal: Vector3 = mirror.mirror_normal()
	for index in markers.size():
		var at := markers[index].global_position
		var reflected: Vector3 = at-normal*(2.0*(at-center).dot(normal))
		var ray := reflected-camera.global_position
		var glass_point := camera.global_position+ray*((center-camera.global_position).dot(normal)/ray.dot(normal))
		var pixel := Vector2i(camera.unproject_position(glass_point))
		var colour := frame.get_pixelv(pixel)
		var channels := [colour.r,colour.g,colour.b]
		check(channels[index]>channels[(index+1)%3]*1.5 and channels[index]>channels[(index+2)%3]*1.5,"analytical reflected location contains correct coloured marker")
		probes+=1
