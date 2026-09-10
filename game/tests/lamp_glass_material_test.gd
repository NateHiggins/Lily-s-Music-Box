extends Node3D
const Field = preload("res://scripts/lamp/lamp_optical_voxel_field.gd")
const Observation = preload("res://scripts/lamp/carried_lamp_observation.gd")
var field: RefCounted
var failures := 0
var directory: String
var samples := {}
const Receivers = preload("res://scripts/lamp/lamp_optical_receivers.gd")

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	directory = OS.get_environment("SHOT_DIR")
	DirAccess.make_dir_recursive_absolute(directory)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color.BLACK
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.BLACK
	add_child(environment)
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(.8,0,0)
	camera.look_at(Vector3(0,0,-2))
	camera.make_current()
	var lamp := SpotLight3D.new()
	lamp.light_energy = 4
	lamp.spot_range = 6
	lamp.spot_angle = 35
	lamp.shadow_enabled = true
	lamp.shadow_bias = .01
	lamp.shadow_normal_bias = .01
	var lamp_mask: int = lamp.light_cull_mask
	add_child(lamp)
	var observation := Observation.new()
	add_child(observation)
	observation.state.switched_on = true
	observation.state.intensity = 4
	observation.state.angle = 35
	observation.range_m = 6
	field = Field.new()
	field.initialize(0)
	for frame in 120:
		await RenderingServer.frame_post_draw
		if field.ready or not field.failed.is_empty(): break
	if not field.ready:
		push_error(field.failed)
		get_tree().quit(2)
		return
	field.observe(observation,true)
	var mote := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(.4,.4)
	var base := StandardMaterial3D.new()
	base.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	base.albedo_color = Color.BLACK
	quad.material = base
	mote.mesh = quad
	mote.position = Vector3(0,0,-2)
	mote.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mote)
	var receiver := Receivers.add_glass_haze(mote)
	var material_ref: WeakRef = weakref(receiver.material_override)
	var registry := Receivers.new()
	registry.setup(self,lamp,field)
	_check(receiver.mesh == mote.mesh and mote.mesh.material == base,"native surface and shared geometry preserved")
	_check(registry.receivers.size() == 1 and field._materials.size() == 1,"actual glass receiver binds exactly once")
	var clear := await _sample("clear")
	var blocker := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(.3,.6,.08)
	blocker.mesh = box
	blocker.position = Vector3(0,0,-1)
	add_child(blocker)
	var shadow := await _sample("native_shadow")
	_check(clear > .002 and shadow < clear*.15,"real mesh shadow suppresses volumetric mote response")
	blocker.queue_free()
	await get_tree().process_frame
	var restored := await _sample("restored")
	_check(absf(clear-restored) < .015,"removing occluder restores response")
	var fill := OmniLight3D.new()
	fill.position = Vector3(.6,.3,-1)
	fill.light_energy = 2
	fill.omni_range = 4
	var fill_mask: int = fill.light_cull_mask
	add_child(fill)
	var two_lights := await _sample("two_lights")
	_check(absf(two_lights-restored) < .002,"late ordinary light cannot duplicate lamp scattering")
	lamp.light_energy = 0
	fill.light_energy = 0
	var no_lights := await _sample("field_without_lights")
	_check(no_lights < .002,"nonzero shared radiance cannot make unlit material emit")
	lamp.light_energy = 4
	observation.state.switched_on = false
	observation.state.intensity = 0
	field.observe(observation,true)
	var off := await _sample("logical_off")
	_check(off < .002,"logical off rejects material despite native light remaining on")
	FileAccess.open(directory.path_join("measurements.json"),FileAccess.WRITE).store_string(JSON.stringify(samples,"\t"))
	_check((fill.light_cull_mask & Receivers.LAYER) == 0,"new light excludes reserved receiver layer")
	field.failed = "review unavailable field"
	registry.hide_all()
	_check(not receiver.visible and mote.visible,"field failure hides only added optical layer")
	var temporary := MeshInstance3D.new()
	temporary.mesh = quad
	add_child(temporary)
	var unavailable := Receivers.add_glass_haze(temporary)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(not unavailable.visible and field._materials.size() == 1,"failed field refuses late optical binding")
	temporary.queue_free()
	await get_tree().process_frame
	field.failed = ""
	registry.bind_pending()
	mote.queue_free()
	await get_tree().process_frame
	_check(registry.receivers.is_empty() and field._materials.is_empty(),"receiver removal immediately unbinds optical texture")
	receiver = null
	await get_tree().process_frame
	_check(material_ref.get_ref() == null,"receiver material releases after removal")
	for path: String in Receivers.DREAM_SURFACES:
		var material := ShaderMaterial.new()
		material.shader = load(path)
		var first := MeshInstance3D.new()
		first.mesh = quad
		first.material_override = material
		var second := MeshInstance3D.new()
		second.mesh = quad
		second.material_override = material
		add_child(first)
		add_child(second)
		await get_tree().process_frame
		await get_tree().process_frame
		_check(registry.surfaces.size() == 2 and field._materials.size() == 1,"late shared Dream material binds once: "+path)
		first.queue_free()
		await get_tree().process_frame
		_check(bool(material.get_shader_parameter("lamp_optical_bound")),"surviving shared receiver keeps its field")
		second.queue_free()
		await get_tree().process_frame
		_check(field._materials.is_empty() and registry.surface_materials.is_empty(),"last shared receiver releases field")
	fill.light_cull_mask &= ~4
	registry.dispose()
	_check(fill.light_cull_mask == (fill_mask & ~4) and lamp.light_cull_mask == lamp_mask,"registry teardown restores owned bit and preserves unrelated mask changes")
	field.dispose()
	field = null
	await get_tree().create_timer(.2).timeout
	print("LAMP GLASS MATERIAL: 25 checks; %d failures"%failures)
	get_tree().quit(0 if failures == 0 else 1)

func _sample(label: String) -> float:
	for frame in 20: await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(directory.path_join(label+".png"))
	var value := 0.0
	var center := image.get_size()/2
	for y in range(-8,9):
		for x in range(-8,9):
			var color := image.get_pixel(center.x+x,center.y+y)
			value += (color.r+color.g+color.b)/3.0
	value /= 289.0
	samples[label] = value
	return value

func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)
