extends Node3D
## Minimal renderer control: no tentacle, lamp field, world, or gameplay owners.
func _ready() -> void:
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(0,0,3)
	var draw := MeshInstance3D.new()
	draw.mesh = BoxMesh.new()
	add_child(draw)
	var probe := ReflectionProbe.new()
	probe.size = Vector3(6,6,6)
	add_child(probe)
	for frame in 90: await RenderingServer.frame_post_draw
	var retired: WeakRef = weakref(probe)
	probe.free()
	draw.free()
	camera.free()
	for frame in 8: await RenderingServer.frame_post_draw
	var passed := retired.get_ref()==null
	var directory := OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(directory)
	var receipt := {"schema_version":2,"evidence_kind":"runtime_contract","selector":"v2","production_runtime":false,
		"scope":"Minimal ReflectionProbe owner retirement. Renderer RID leak verdict requires the complete shutdown stderr; this receipt alone cannot certify it.",
		"source":{"test_path":"game/tests/reflection_atlas_retirement_test.gd","test_sha256":get_script().source_code.replace("\r\n","\n").sha256_text()},
		"execution":{"completed":true,"exit_code":0 if passed else 1,"timed_out":false},
		"contracts":{"owner_retirement":{"executed":true,"status":"PASS" if passed else "FAIL"}},"engine":Engine.get_version_info()}
	FileAccess.open(directory.path_join("runtime_contract.json"),FileAccess.WRITE).store_string(JSON.stringify(receipt,"\t"))
	get_tree().quit(0 if passed else 1)
