extends Node3D
## Focused integration seam proof, not a composed apartment or warehouse proof.
## Two real production batches share one external owner's existing RG8 volume.

const BindingScript := preload("res://scripts/dream/critters/dream_critter_voxel_binding.gd")
const ControllerScript := preload("res://scripts/dream/critters/dream_critter_controller.gd")
const FieldScript := preload("res://scripts/dream/field/dream_field_controller.gd")
const ExposureScript := preload("res://scripts/dream/dream_exposure_field.gd")

var checks := 0
var failures := 0


func _ready() -> void:
	var owner := Node3D.new()
	add_child(owner)
	var field := FieldScript.new()
	owner.add_child(field)
	field.set_process(false)
	var binding := BindingScript.new()
	owner.add_child(binding)
	var first := _controller(owner, field, 101)
	var second := _controller(owner, field, 102)
	var first_material: ShaderMaterial = first.material
	var second_material: ShaderMaterial = second.material
	var first_mesh: Mesh = first.mesh_instance.mesh
	_check(not binding.bind_controller(first), "unconfigured owner refuses attachment")
	_check(not binding.set_texture(null), "null texture is refused")

	var exposure := ExposureScript.new()
	exposure.stamp_room("warehouse_binding_probe", [400.0, -2.0, 404.0, 2.0], 0.0, .23)
	var texture := exposure.make_texture()
	_check(binding.set_texture(texture), "existing owner RG8 texture is admitted")
	_check(binding.bind_controller(first) and binding.bind_controller(second),
			"two existing production batches attach to the same sampler")
	_check(binding.bind_controller(first) and binding.controller_count() == 2,
			"repeat attachment does not duplicate a batch")
	_check(first.material == first_material and second.material == second_material
			and first.mesh_instance.mesh == first_mesh,
			"binding preserves existing batch material and mesh objects")
	_check(first_material.get_shader_parameter("exposure_tex") == texture
			and second_material.get_shader_parameter("exposure_tex") == texture,
			"both materials reference the exact same owner texture")
	_check(float(first_material.get_shader_parameter("exposure_extent")) == 96.0
			and float(first_material.get_shader_parameter("exposure_height")) == 4.0,
			"shader domain matches the accepted wrapped single-storey field")

	var competing := BindingScript.new()
	owner.add_child(competing)
	_check(competing.set_texture(texture) and not competing.bind_controller(first),
			"another binding owner cannot acquire an already-bound controller")
	competing.free()
	var wrong_format := _texture(Image.FORMAT_RGBA8, 192, 8)
	_check(not binding.set_texture(wrong_format)
			and first_material.get_shader_parameter("exposure_tex") == texture,
			"RGBA light volumes are refused without changing a valid binding")
	var wrong_shape := _texture(Image.FORMAT_RG8, 4, 1)
	_check(not binding.set_texture(wrong_shape)
			and binding.controller_count() == 2,
			"wrong RG8 grid dimensions are refused atomically")

	var at := Vector3(402.25, 1.25, .25)
	var origin := Vector3(400.25, 1.25, .25)
	_check(exposure.sample(at) == 0.0 and exposure.sample_irradiance(at) == 0.0,
			"binding does not advance or seed the field")
	exposure.add_lamp(origin, Vector3.RIGHT, 4.0, cos(deg_to_rad(25.0)), 1.0, 1.0)
	var retained := exposure.sample(at)
	_check(retained > 0.0 and exposure.sample_irradiance(at) > 0.0,
			"the world owner alone advances durable R and reversible G")
	_check(exposure.upload(texture) and not exposure.upload(texture),
			"owner updates existing texture only while field bytes are dirty")
	_check(first_material.get_shader_parameter("exposure_tex") == texture
			and second_material.get_shader_parameter("exposure_tex") == texture,
			"live upload needs no replacement sampler or material")
	var illuminated: Array[Image] = texture.get_data()
	_check(illuminated.size() == 8 and illuminated[2].get_pixel(36, 0).r > 0.0
			and illuminated[2].get_pixel(36, 0).g > 0.0,
			"the shared sampler receives both actual uploaded light channels")
	exposure.add_lamp(origin, Vector3.RIGHT, 4.0, cos(deg_to_rad(25.0)), 0.0, 2.0)
	_check(exposure.sample(at) == retained and exposure.sample_irradiance(at) == 0.0,
			"lamp off cools G without erasing R")
	_check(exposure.upload(texture), "lamp-off change reaches the shared sampler")
	var cooled: Array[Image] = texture.get_data()
	_check(cooled.size() == 8 and is_equal_approx(cooled[2].get_pixel(36, 0).r, retained)
			and cooled[2].get_pixel(36, 0).g == 0.0,
			"readback retains durable R and clears current G")

	var rebuilt_exposure := ExposureScript.new()
	var rebuilt_texture := rebuilt_exposure.make_texture()
	_check(binding.set_texture(rebuilt_texture)
			and first_material.get_shader_parameter("exposure_tex") == rebuilt_texture
			and second_material.get_shader_parameter("exposure_tex") == rebuilt_texture,
			"owner reconstruction replaces both stale samplers together")
	_check(rebuilt_exposure.sample(at) == 0.0 and exposure.sample(at) == retained,
			"rebinding neither copies old history nor mutates either field")
	binding.unbind_controller(first)
	_check(first._voxel_texture == null and binding.controller_count() == 1
			and second._voxel_texture == rebuilt_texture,
			"explicit departure releases only the selected batch")
	_check(binding.bind_controller(first), "released batch can attach again")
	owner.remove_child(first)
	_check(first_material.get_shader_parameter("exposure_tex") == null
			and binding.controller_count() == 1,
			"controller tree exit clears retained material and registry prunes it")
	_check(binding.set_texture(texture) and first._voxel_texture == null,
			"later world rebuild does not reacquire a departed controller")
	first.free()
	var second_reference: WeakRef = weakref(second)
	second.free()
	_check(second_reference.get_ref() == null and binding.controller_count() == 0,
			"registry weak references do not retain freed production controllers")

	# An explicit controller release is valid without notifying the old helper.
	# Both helpers deliberately use the SAME texture, so pointer equality alone
	# cannot protect the controller's replacement owner.
	var transfer := _controller(owner, field, 103)
	var next_owner := BindingScript.new()
	owner.add_child(next_owner)
	_check(next_owner.set_texture(texture) and binding.bind_controller(transfer),
			"same-texture ownership transfer fixture starts under the old owner")
	transfer.unbind_voxel_optics()
	_check(next_owner.bind_controller(transfer),
			"explicit controller release permits attachment to the next owner")
	binding.clear()
	_check(transfer._voxel_texture == texture and next_owner.controller_count() == 1,
			"stale owner clear cannot release a new owner using the same texture")
	next_owner.unbind_controller(transfer)
	binding.set_texture(texture)
	binding.bind_controller(transfer)
	transfer.unbind_voxel_optics()
	next_owner.bind_controller(transfer)
	_check(binding.set_texture(rebuilt_texture) and transfer._voxel_texture == texture
			and next_owner.controller_count() == 1 and binding.controller_count() == 0,
			"stale owner replacement cannot hijack a new owner using the same texture")
	next_owner.free()
	_check(transfer._voxel_texture == null,
			"the actual replacement owner still releases its binding on teardown")
	transfer.free()

	var survivor := _controller(owner, field, 104)
	var retained_material: ShaderMaterial = survivor.material
	_check(binding.bind_controller(survivor), "replacement batch attaches")
	owner.remove_child(binding)
	_check(survivor._voxel_texture == null
			and retained_material.get_shader_parameter("exposure_tex") == null
			and float(retained_material.get_shader_parameter("voxel_optics_enabled")) == 0.0,
			"binding owner tree exit clears samplers while controllers still live")
	binding.clear()
	_check(binding.controller_count() == 0, "repeated cleanup is harmless")
	binding.free()
	owner.free()
	print("[DREAM-CRITTER-VOXEL-BINDING] checks=%d failures=%d external_fields=1 per_animal_fields=0" % [checks, failures])
	get_tree().quit(1 if failures > 0 else 0)


func _controller(owner: Node3D, field: DreamFieldController, seed_v: int) -> DreamCritterController:
	var controller := ControllerScript.new()
	owner.add_child(controller)
	controller.setup(field, seed_v)
	controller.set_process(false)
	return controller


func _texture(format: Image.Format, size: int, depth: int) -> ImageTexture3D:
	var images: Array[Image] = []
	for i in depth:
		var image := Image.create(size, size, false, format)
		image.fill(Color(0.0, 0.0, 0.0, 1.0))
		images.append(image)
	var result := ImageTexture3D.new()
	result.create(format, size, size, depth, false, images)
	return result


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + label)
