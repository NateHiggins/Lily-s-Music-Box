extends Node3D
## INERT rendering feature fixture, not world or appearance qualification.
var failures: Array[String]=[]
func check(ok: bool,label: String) -> void:
	print("REFLECTION WARMUP: ",label," = ",ok)
	if not ok:failures.append(label)
func _ready() -> void:_run.call_deferred()
func _run() -> void:
	var before:=get_viewport().get_camera_3d()
	var warm:=preload("res://tests/reflection_pipeline_warmup.gd")
	var elapsed: float=warm.warm_reflections(self)
	check(get_viewport().get_camera_3d()==before,"warm scene cannot steal game camera")
	check(get_child_count()==1,"private scene stays dormant after loading")
	check(warm.warm_reflections(self)==0.,"same MSAA configuration warms once")
	var camera:=Camera3D.new();camera.position=Vector3(.3,.25,.5);add_child(camera);camera.look_at(Vector3.ZERO);camera.make_current()
	var draw:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=Vector3.ONE*.1;draw.mesh=box
	draw.material_override=MatLib.get_mat("brass_dull");add_child(draw)
	var light:=OmniLight3D.new();light.position=Vector3(.2,.3,.1);add_child(light)
	for frame in 8:await RenderingServer.frame_post_draw
	var original: float=Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE)
	var probe:=ReflectionProbe.new();probe.size=Vector3.ONE*2.;probe.enable_shadows=true;probe.ambient_mode=ReflectionProbe.AMBIENT_DISABLED;add_child(probe)
	warm.retire(self)
	for frame in 20:await RenderingServer.frame_post_draw
	var delta: float=Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE)-original
	check(delta==0.,"first real probe does not recompile loaded material surfaces")
	check(get_node_or_null("ReflectionPipelineKeepalive")==null,"warm resources retire after real probe takes over")
	var directory:=OS.get_environment("SHOT_DIR");DirAccess.make_dir_recursive_absolute(directory)
	FileAccess.open(directory.path_join("observations.json"),FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT","warm_ms":elapsed,"late_surface_pipelines":delta,"failures":failures},"\t"))
	print("REFLECTION WARMUP: ","PASS" if failures.is_empty() else "FAIL")
	get_tree().quit(0 if failures.is_empty() else 1)
