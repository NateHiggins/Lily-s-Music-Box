extends Node3D

func _ready() -> void:
	var camera:=Camera3D.new()
	camera.position=Vector3(0.0,1.5,3.0)
	add_child(camera)
	camera.current=true
	var surface:=MeshInstance3D.new()
	surface.mesh=BoxMesh.new()
	add_child(surface)
	var environment:=WorldEnvironment.new()
	environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR
	environment.environment.background_color=Color(0.25,0.20,0.15)
	add_child(environment)
	var enabled:=OS.get_environment("ORISON_REFLECTION_CONTROL")=="probe"
	var probe:ReflectionProbe=null
	if enabled:
		probe=ReflectionProbe.new()
		probe.size=Vector3(4.0,3.0,4.0)
		probe.update_mode=ReflectionProbe.UPDATE_ONCE
		add_child(probe)
	for _i in 24: await get_tree().process_frame
	if probe!=null: probe.queue_free()
	for _i in 12: await get_tree().process_frame
	print("REFLECTION CLEANUP CONTROL: probe=%s retired=true" % enabled)
	get_tree().quit()
