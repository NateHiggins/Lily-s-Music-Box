extends RefCounted
## INERT rejected loading experiment. Fixture-only; never a production dependency.

static func warm_reflections(parent: Node3D) -> float:
	if RenderingServer.get_current_rendering_method()!="forward_plus" or RenderingServer.get_rendering_device()==null:return 0.
	if parent.has_meta("reflection_pipeline_warmed"):return 0.
	var started:=Time.get_ticks_usec()
	var previous:=parent.get_viewport().get_camera_3d()
	var viewport:=Node3D.new();viewport.name="ReflectionPipelineKeepalive"
	# Use the existing render target. A private SubViewport retained seven
	# extra texture RIDs at shutdown on the measured backend.
	viewport.position=Vector3(100000,100000,100000)
	var camera:=Camera3D.new();camera.near=.005
	camera.transform=Transform3D(Basis.looking_at(Vector3(-.1,-.1,-.2)),Vector3(.1,.1,.2))
	viewport.add_child(camera)
	var draw:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=Vector3.ONE*.03;draw.mesh=box
	var finish:=StandardMaterial3D.new();finish.metallic=.8;finish.roughness=.2
	draw.material_override=finish;viewport.add_child(draw)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-40,-20,0);viewport.add_child(light)
	var probe:=ReflectionProbe.new();probe.size=Vector3.ONE;probe.enable_shadows=true
	probe.ambient_mode=ReflectionProbe.AMBIENT_DISABLED;viewport.add_child(probe)
	parent.add_child(viewport);camera.make_current()
	# A mere hidden node did not initialize this feature on the qualified
	# backend. Draw one private loading frame, without swapping the game window
	# or reading pixels back. Keep the feature active until a real probe takes
	# over; immediately freeing this scene disables it again on this backend.
	RenderingServer.force_draw(false);RenderingServer.force_sync()
	if is_instance_valid(previous):previous.make_current()
	else:camera.clear_current(false)
	draw.hide();light.hide()
	parent.set_meta("reflection_pipeline_warmed",true)
	return (Time.get_ticks_usec()-started)/1000.

static func retire(parent: Node3D) -> void:
	var viewport:=parent.get_node_or_null("ReflectionPipelineKeepalive")
	if viewport==null:return
	# Let the real probe enter rendering before removing the warm feature.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	if is_instance_valid(viewport):viewport.queue_free()
