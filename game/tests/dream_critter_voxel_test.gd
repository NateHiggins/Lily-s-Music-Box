extends Node
## Focused DREAM-CRITTER-VOXEL receipt.  This does not boot Orison and does
## not create a new light field; it proves the authored morphs and the one
## shared production binding in under a second.

const ControllerScript := preload("res://scripts/dream/critters/dream_critter_controller.gd")
const FieldControllerScript := preload("res://scripts/dream/field/dream_field_controller.gd")
const ExposureScript := preload("res://scripts/dream/dream_exposure_field.gd")
const MicroLightScript := preload("res://scripts/dream/dream_microbiology_light.gd")
const MicroMechanicsScript := preload("res://scripts/dream/dream_microbiology_mechanics.gd")

var checks := 0
var failures := 0


func _ready() -> void:
	var species := DreamCritterSpecies
	var generator := DreamCritterGenerator
	var kinds: Array = species.all_kinds()
	_check(kinds.size() == 16, "four original and twelve researched species are registered")
	for kind in kinds:
		for i in 128:
			var morph: Dictionary = generator.generate(kind, 8100 + kind * 997 + i * 31)
			_check(species.violates_identity(kind, morph) == "",
					"%s identity %d" % [species.name_of(kind), i])

	var bear: Dictionary = generator.generate(species.Kind.TARDIGRADE, 0x7A4D1)
	_check(float(bear.length) >= .50 and float(bear.length) <= .75,
			"tardigrade is cat sized")
	_check(int(bear.limbs) == 8 and bool(bear.double_claws),
			"tardigrade has eight lobopods and double claws")
	_check(int(bear.body_annuli) == 4 and int(bear.mouth_lamellae) == 6,
			"tardigrade has four trunk annuli and a six-part mouth crown")

	var shader_source := FileAccess.get_file_as_string(
			"res://shaders/dream_critter.gdshader")
	var optics_source := FileAccess.get_file_as_string(
			"res://shaders/dream_critter_voxel_optics.gdshaderinc")
	var forms_source := FileAccess.get_file_as_string(
			"res://shaders/dream_microorganism_forms.gdshaderinc")
	_check("sampler3D exposure_tex" in shader_source
			and "critter_exposure_at(v_world)" in shader_source,
			"production critter shader samples the RG8 field in world space")
	for function_name in ["grazer_voxel_optics", "listener_voxel_optics",
			"crab_voxel_optics", "tardigrade_voxel_optics", "stentor_voxel_optics",
			"lacrymaria_voxel_optics", "vorticella_voxel_optics",
			"euplotes_voxel_optics", "spirostomum_voxel_optics",
			"heliozoan_voxel_optics", "euglena_voxel_optics", "volvox_voxel_optics",
			"noctiluca_voxel_optics", "bacillaria_voxel_optics",
			"salpingoeca_voxel_optics", "mesodinium_voxel_optics"]:
		_check(function_name in optics_source, "%s is authored" % function_name)
	for form_name in ["microorganism_body", "microorganism_limb",
			"microorganism_feeler", "microorganism_detail"]:
		_check(form_name in forms_source, "%s uses the bounded shared geometry pool" % form_name)
	_check("rg.g" in optics_source and "rg.r" in optics_source,
			"current G and durable R remain technically distinct")
	var laws := {}
	for kind in kinds:
		laws[String(species.rules(kind).law)] = true
	_check(laws.size() == 16, "each species retains one distinct source-derived law")

	var field_controller = FieldControllerScript.new()
	add_child(field_controller)
	var controller = ControllerScript.new()
	add_child(controller)
	controller.setup(field_controller, 0xC81773)
	for kind in range(species.Kind.STENTOR, species.Kind.MESODINIUM + 1):
		var morph: Dictionary = generator.generate(kind, 9200 + kind * 41)
		var state := {
			"morph": morph, "photo": MicroLightScript.state(),
			"mechanical": MicroMechanicsScript.state(), "pos": Vector3.ZERO,
			"up": Vector3.UP, "fwd": Vector3.FORWARD, "moving": true,
			"pause": 0.0, "gait": 1.25, "turn_bias": float(morph.turn_bias),
			"micro_phase": 0.0, "micro_state": 0.0, "micro_aux": .25,
			"micro_clock": 2.0, "photo_side": 0.0,
			"authority_sentinel": "ecology_owns_decisions",
		}
		controller._apply_law(state, .25)
		_check(float(state.micro_phase) != 0.0,
				"%s advances its bounded source-derived presentation law" % species.name_of(kind))
		_check(String(state.authority_sentinel) == "ecology_owns_decisions",
				"%s presentation does not write ecology authority" % species.name_of(kind))
	var mesh_arrays: Array = controller.mesh_instance.mesh.surface_get_arrays(0)
	var batch_triangles: int = (mesh_arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	_check(batch_triangles < 150000,
			"the complete twelve-slot sixteen-species batch remains bounded (%d triangles)"
			% batch_triangles)
	var exposure = ExposureScript.new()
	exposure.stamp_room("@critter_voxel_test", [-2.0, -2.0, 4.0, 4.0], 0.0, .23)
	var texture := exposure.make_texture()
	controller.bind_voxel_optics(texture, ExposureScript.EXTENT_M,
			ExposureScript.HEIGHT_M)
	_check(controller._voxel_texture == texture,
			"all critters bind the one world-owned texture")
	_check(controller.material.get_shader_parameter("exposure_tex") == texture,
			"the one shared fauna material holds that texture")
	_check(controller.mesh_instance.material_override == controller.material,
			"one material overrides the complete sixteen-species batch")
	controller.unbind_voxel_optics()
	_check(controller._voxel_texture == null
			and float(controller.material.get_shader_parameter("voxel_optics_enabled")) == 0.0,
			"teardown unbinds the voxel sampler")

	print("[DREAM-CRITTER-VOXEL] checks=%d failures=%d species=16 triangles=%d "
			% [checks, failures, batch_triangles]
			+ "materials=1 shared_texture=1 per_critter_field=false cat_scale_m=%.3f"
			% float(bear.length))
	get_tree().quit(1 if failures > 0 else 0)


func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: %s" % label)
