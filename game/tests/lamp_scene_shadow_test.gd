extends Node3D
var field: RefCounted
var observation: Node3D
var shadow_owner: Node3D
var directory: String
var failures := 0
var values := {}
func _ready() -> void: call_deferred("_run")
func _run() -> void:
	directory = OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(directory)
	var camera := Camera3D.new()
	camera.position = Vector3(.8,0,0)
	add_child(camera)
	camera.look_at(Vector3(0,0,-2))
	camera.make_current()
	var lamp := SpotLight3D.new()
	lamp.spot_range = 6
	lamp.spot_angle = 35
	add_child(lamp)
	observation = preload("res://scripts/lamp/carried_lamp_observation.gd").new()
	add_child(observation)
	observation.state.switched_on = true
	observation.state.intensity = 4
	observation.state.angle = 35
	observation.range_m = 6
	field = preload("res://scripts/lamp/lamp_optical_voxel_field.gd").new()
	field.initialize(1)
	for i in 120:
		await RenderingServer.frame_post_draw
		if field.ready or not field.failed.is_empty(): break
	if not field.ready:
		push_error(field.failed)
		get_tree().quit(2)
		return
	var receiver := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(.4,.4)
	receiver.mesh = quad
	receiver.position.z = -2
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = 'shader_type spatial; render_mode unshaded;\n#include "res://shaders/lamp_optical_sample.gdshaderinc"\nvarying vec3 world; void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;} void fragment(){ALBEDO=sample_lamp_optics(world).radiance;}'
	material.shader = shader
	receiver.material_override = material
	add_child(receiver)
	field.bind_material(material)
	shadow_owner = preload("res://scripts/lamp/lamp_scene_shadow.gd").new()
	add_child(shadow_owner)
	shadow_owner.setup(field,lamp)
	var clear := await _sample("clear")
	var blocker := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(.35,.8,.08)
	blocker.mesh = box
	blocker.position.z = -1
	add_child(blocker)
	var blocked := await _sample("blocked")
	blocker.position.x = 1
	var moved := await _sample("moved")
	blocker.position.x = 0
	var deformed_material := ShaderMaterial.new()
	var deformed_shader := Shader.new()
	deformed_shader.code = "shader_type spatial; void vertex(){VERTEX.x+=2.0;} void fragment(){ALBEDO=vec3(0.5);}"
	deformed_material.shader = deformed_shader
	blocker.material_override = deformed_material
	var deformed := await _sample("vertex_deformed")
	_check(absf(deformed-clear)<.03,"shadow follows actual shader deformation instead of original mesh bounds")
	_check(clear>.05 and blocked<clear*.15,"actual mesh occludes unshaded voxel receiver")
	_check(absf(moved-clear)<.03,"moving mesh restores field without stale shadow")
	_check(shadow_owner.effect.passes>0 and shadow_owner.effect.failed.is_empty(),"GPU compositor executes without failure")
	position = Vector3(31,4,-17)
	rotation.y = PI*.5
	var transformed := await _sample("transformed")
	_check(absf(transformed-clear)<.03,"translated rotated lamp and geometry preserve visibility")
	receiver.position.z = -.3
	quad.size = Vector2(.08,.08)
	camera.position = Vector3(.12,0,0)
	camera.look_at(receiver.global_position)
	var near_clear := await _sample("near_clear")
	blocker.material_override = null
	box.size = Vector3(.045,.15,.02)
	blocker.position = Vector3(0,0,-.15)
	var near_blocked := await _sample("near_blocked")
	_check(near_clear>.05 and near_blocked<near_clear*.15,"hero near cascade receives actual geometry shadow")
	var passes: int = shadow_owner.effect.passes
	for i in 12: await RenderingServer.frame_post_draw
	_check(shadow_owner.effect.passes==passes,"paused field is not repeatedly attenuated")
	observation.state.switched_on = false
	observation.state.intensity = 0
	var off := await _sample("off")
	_check(off<.001 and shadow_owner.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"logical off disables geometry view and material response")
	var retained := [weakref(shadow_owner),weakref(shadow_owner.effect)]
	shadow_owner.queue_free()
	shadow_owner = null
	field.dispose()
	field = null
	for i in 12: await RenderingServer.frame_post_draw
	_check(retained[0].get_ref()==null and retained[1].get_ref()==null,"shadow owner and effect release")
	FileAccess.open(directory.path_join("measurements.json"),FileAccess.WRITE).store_string(JSON.stringify(values,"\t"))
	print("SCENE SHADOW: 9 checks; %d failures"%failures)
	get_tree().quit(0 if failures==0 else 1)
func _sample(label: String) -> float:
	for i in 20:
		field.observe(observation,true)
		await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(directory.path_join(label+".png"))
	var p := image.get_size()/2
	var value := image.get_pixel(p.x,p.y).r
	values[label] = value
	return value
func _check(ok: bool,label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)
