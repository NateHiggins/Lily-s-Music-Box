extends Node3D
## Forward+ review of four production critter morphs under one real
## DreamExposureField.  Each species is framed at microscopy scale in the same
## white observation bay; the tardigrade label reports its production length.

const ControllerScript := preload("res://scripts/dream/critters/dream_critter_controller.gd")
const FieldControllerScript := preload("res://scripts/dream/field/dream_field_controller.gd")
const ExposureScript := preload("res://scripts/dream/dream_exposure_field.gd")
const GeneratorScript := preload("res://scripts/dream/critters/dream_critter_generator.gd")
const SpeciesScript := preload("res://scripts/dream/critters/dream_critter_species.gd")
const MicroLightScript := preload("res://scripts/dream/dream_microbiology_light.gd")
const MicroMechanicsScript := preload("res://scripts/dream/dream_microbiology_mechanics.gd")

const PANELS := [
	{"kind": SpeciesScript.Kind.SEAM_GRAZER, "seed": 17201,
		"name": "SEAM GRAZER",
		"optics": "wet comb / anastomosing capillaries / seam-memory R"},
	{"kind": SpeciesScript.Kind.CRYSTAL_LISTENER, "seed": 17202,
		"name": "CRYSTAL LISTENER",
		"optics": "still shell / rotating resonator / polarized lattice"},
	{"kind": SpeciesScript.Kind.FOLD_CRAB, "seed": 17203,
		"name": "FOLD CRAB",
		"optics": "ossified plates / load paths / transfer rosette"},
	{"kind": SpeciesScript.Kind.TARDIGRADE, "seed": 17204,
		"name": "CAT-SIZED TARDIGRADE",
		"optics": "reticulate cuticle / pharynx-gut axis / double claws"},
]

var camera: Camera3D
var controller: DreamCritterController
var exposure: DreamExposureField
var exposure_texture: ImageTexture3D
var title: Label
var subtitle: Label
var output_dir := ""


func _ready() -> void:
	output_dir = OS.get_environment("SHOT_DIR")
	if output_dir.is_empty() or not output_dir.is_absolute_path():
		push_error("SHOT_DIR must be an absolute directory")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output_dir)
	_build_white_observation_room()
	_build_shared_field()
	call_deferred("_capture_contact_sheet")


func _build_white_observation_room() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(.72, .73, .70)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(.88, .90, .86)
	environment.ambient_light_energy = .38
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = .82
	world.environment = environment
	add_child(world)

	_add_box("BackWall", Vector3(4.0, 2.6, .08), Vector3(0, 1.25, -1.15),
			Color(.74, .75, .71))
	_add_box("Floor", Vector3(4.0, .08, 3.2), Vector3(0, -.06, .10),
			Color(.69, .70, .66))
	_add_box("ObservationSlide", Vector3(1.35, .035, .84), Vector3(0, .005, 0),
			Color(.84, .85, .80))

	var key := DirectionalLight3D.new()
	key.name = "NeutralObliqueKey"
	key.rotation_degrees = Vector3(-47, -32, 0)
	key.light_color = Color(.93, .90, .82)
	key.light_energy = .92
	key.shadow_enabled = true
	add_child(key)
	var transmission := SpotLight3D.new()
	transmission.name = "TransmittedMicroscopyLamp"
	transmission.position = Vector3(.55, .80, .55)
	transmission.rotation_degrees = Vector3(-58, 36, 0)
	transmission.light_color = Color(.90, .75, .43)
	transmission.light_energy = 1.85
	transmission.spot_range = 3.0
	transmission.spot_angle = 48.0
	transmission.shadow_enabled = true
	add_child(transmission)

	camera = Camera3D.new()
	camera.fov = 35.0
	camera.near = .008
	add_child(camera)
	camera.make_current()

	var overlay := CanvasLayer.new()
	add_child(overlay)
	title = Label.new()
	title.position = Vector2(28, 24)
	title.size = Vector2(720, 42)
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(.055, .06, .055))
	title.add_theme_color_override("font_outline_color", Color(.96, .97, .93, .90))
	title.add_theme_constant_override("outline_size", 7)
	overlay.add_child(title)
	subtitle = Label.new()
	subtitle.position = Vector2(28, 65)
	subtitle.size = Vector2(720, 34)
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(.10, .11, .10))
	subtitle.add_theme_color_override("font_outline_color", Color(.96, .97, .93, .92))
	subtitle.add_theme_constant_override("outline_size", 5)
	overlay.add_child(subtitle)

	var field_controller = FieldControllerScript.new()
	add_child(field_controller)
	field_controller.setup(0xC81773, Vector4(-2, -2, 2, 2), 0.0, Vector3.ZERO)
	controller = ControllerScript.new()
	add_child(controller)
	controller.setup(field_controller, 0xC81773)
	controller.set_process(false)
	controller.set_physics_process(false)
	controller.mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func _add_box(label: String, size: Vector3, at: Vector3, color: Color) -> void:
	var node := MeshInstance3D.new()
	node.name = label
	var box := BoxMesh.new()
	box.size = size
	node.mesh = box
	node.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = .88
	node.material_override = material
	add_child(node)


func _build_shared_field() -> void:
	exposure = ExposureScript.new()
	exposure.stamp_room("@critter_white_room", [-1.4, -1.0, 2.8, 2.0], 0.0, .07)
	# Leave converted R under the left half, cool reversible G, then illuminate
	# the right.  Every panel therefore proves that present and remembered light
	# can disagree without a debug heatmap or a substitute scalar.
	exposure.add_lamp(Vector3(-.25, 1.25, 0), Vector3.DOWN, 1.8,
			cos(deg_to_rad(20.0)), 1.0, 5.5)
	exposure.add_lamp(Vector3.ZERO, Vector3.DOWN, 0.0, 1.0, 0.0, 2.0)
	exposure.add_lamp(Vector3(.25, 1.25, 0), Vector3.DOWN, 1.8,
			cos(deg_to_rad(20.0)), 1.0, 1.0)
	exposure_texture = exposure.make_texture()
	controller.bind_voxel_optics(exposure_texture, ExposureScript.EXTENT_M,
			ExposureScript.HEIGHT_M)


func _state(kind: int, seed_value: int) -> Dictionary:
	var morph: Dictionary = GeneratorScript.generate(kind, seed_value)
	var state := {
		"id": kind, "morph": morph, "pos": Vector3(0, float(morph.tall) * .50, 0),
		"fwd": Vector3(0, 0, 1), "up": Vector3.UP, "gait": float(morph.gait_phase),
		"moving": false, "twin": false, "spin": 1.15, "fold_leg": 2,
		"fold": .72 if kind == SpeciesScript.Kind.FOLD_CRAB else 0.0,
		"tun": .22 if kind == SpeciesScript.Kind.TARDIGRADE else 0.0,
		"unfold": .58, "photo": MicroLightScript.state(), "photo_side": .55,
		"mechanical": MicroMechanicsScript.state(), "leg_state": [],
		"manipulator_deploy": .72, "information_pulse": .66,
		"ecology_repeat_count": 0, "ecology_returning": false, "alive": 1.0,
		"hero_near": 0.0,
	}
	if kind == SpeciesScript.Kind.CRYSTAL_LISTENER:
		state.photo.response = .72
		state.photo.scan = 1.7
	controller._advance_crab_gait(state, 0.0)
	return state


func _capture_contact_sheet() -> void:
	await get_tree().create_timer(.45).timeout
	var captures: Array[Image] = []
	for panel in PANELS:
		var state := _state(int(panel.kind), int(panel.seed))
		controller.critters = [state]
		controller._push()
		var morph: Dictionary = state.morph
		var length_m := float(morph.length)
		var radius := maxf(length_m, maxf(float(morph.wide), float(morph.tall))) * .54
		var distance := radius / tan(deg_to_rad(camera.fov * .5)) * 1.04
		if int(panel.kind) == SpeciesScript.Kind.TARDIGRADE:
			# Side-biased view proves the long four-segment body and four leg pairs;
			# the earlier frontal view collapsed it into a generic round walker.
			camera.position = Vector3(distance * 1.12, maxf(.20, distance * .42),
					distance * .42)
		elif int(panel.kind) == SpeciesScript.Kind.CRYSTAL_LISTENER:
			camera.position = Vector3(distance * .74, maxf(.20, distance * .46),
					distance * 1.20)
		elif int(panel.kind) == SpeciesScript.Kind.SEAM_GRAZER:
			camera.position = Vector3(distance * .42, maxf(.13, distance * .32),
					distance * .62)
		else:
			camera.position = Vector3(distance * .69, maxf(.20, distance * .44),
					distance * 1.08)
		camera.look_at(Vector3(0, float(morph.tall) * .34, 0), Vector3.UP)
		title.text = String(panel.name)
		subtitle.text = String(panel.optics)
		if int(panel.kind) == SpeciesScript.Kind.TARDIGRADE:
			title.text += "  •  %.2f m" % length_m
		title.reset_size()
		title.size = Vector2(720, 42)
		subtitle.reset_size()
		subtitle.size = Vector2(720, 34)
		for _frame in 12:
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		image.resize(800, 450, Image.INTERPOLATE_LANCZOS)
		image.convert(Image.FORMAT_RGBA8)
		captures.append(image)

	var sheet := Image.create(1600, 900, false, Image.FORMAT_RGBA8)
	for i in captures.size():
		var destination := Vector2i((i % 2) * 800, (i / 2) * 450)
		sheet.blit_rect(captures[i], Rect2i(Vector2i.ZERO, Vector2i(800, 450)),
				destination)
	var output := output_dir.path_join("dream_critter_voxel_species_contact_sheet.png")
	var result := sheet.save_png(output)
	print("[DREAM-CRITTER-VOXEL-SHOT] %s %s" % [output,
			"ok" if result == OK else "SAVE FAILED %d" % result])
	print("[DREAM-CRITTER-VOXEL-SHOT] one shared RG8 texture, one material, "
			+ "four authored optical expressions; tardigrade %.3f m"
			% float(controller.critters[0].morph.length))
	print("[DREAM-CRITTER-VOXEL-SHOT] field left R/G %.3f/%.3f right R/G %.3f/%.3f"
			% [exposure.sample(Vector3(-.25, .25, 0)),
			exposure.sample_irradiance(Vector3(-.25, .25, 0)),
			exposure.sample(Vector3(.25, .25, 0)),
			exposure.sample_irradiance(Vector3(.25, .25, 0))])
	controller.unbind_voxel_optics()
	get_tree().quit(0 if result == OK else 1)
