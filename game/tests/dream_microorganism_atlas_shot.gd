extends Node3D
## Forward+ microscopy atlas for the twelve source-derived V3 species. Every
## panel uses one production DreamCritterController, one shared material and
## one real DreamExposureField texture in the same enclosed white room.

const ControllerScript := preload("res://scripts/dream/critters/dream_critter_controller.gd")
const FieldControllerScript := preload("res://scripts/dream/field/dream_field_controller.gd")
const ExposureScript := preload("res://scripts/dream/dream_exposure_field.gd")
const GeneratorScript := preload("res://scripts/dream/critters/dream_critter_generator.gd")
const SpeciesScript := preload("res://scripts/dream/critters/dream_critter_species.gd")
const MicroLightScript := preload("res://scripts/dream/dream_microbiology_light.gd")
const MicroMechanicsScript := preload("res://scripts/dream/dream_microbiology_mechanics.gd")

const PANELS := [
	{"kind": SpeciesScript.Kind.STENTOR, "name": "STENTOR",
		"note": "habituating trumpet • spiral myonemes", "phase": 1.1, "state": .22},
	{"kind": SpeciesScript.Kind.LACRYMARIA, "name": "LACRYMARIA",
		"note": "seven-body neck • stochastic hunter", "phase": 2.4, "state": .62, "aux": .58},
	{"kind": SpeciesScript.Kind.VORTICELLA, "name": "VORTICELLA",
		"note": "oral vortex • coiling spasmoneme", "phase": .8, "state": .46},
	{"kind": SpeciesScript.Kind.EUPLOTES, "name": "EUPLOTES",
		"note": "fourteen cirri • finite-state gait", "phase": 2.6, "state": .66},
	{"kind": SpeciesScript.Kind.SPIROSTOMUM, "name": "SPIROSTOMUM",
		"note": "ultrafast twist • myoneme fishnet", "phase": 1.5, "state": .36},
	{"kind": SpeciesScript.Kind.HELIOZOAN, "name": "HELIOZOAN",
		"note": "axopod sun • inward prey transport", "phase": .9, "state": .54, "aux": .64},
	{"kind": SpeciesScript.Kind.EUGLENA, "name": "EUGLENA",
		"note": "metaboly • eyespot-clipped light", "phase": 2.0, "state": .72, "aux": .48},
	{"kind": SpeciesScript.Kind.VOLVOX, "name": "VOLVOX",
		"note": "rolling colony • daughter inversion", "phase": 1.7, "state": .68},
	{"kind": SpeciesScript.Kind.NOCTILUCA, "name": "NOCTILUCA",
		"note": "feeding tentacle • scintillon wave", "phase": 2.1, "state": .74},
	{"kind": SpeciesScript.Kind.BACILLARIA, "name": "BACILLARIA",
		"note": "silica raft • sliding neighbors", "phase": 1.35, "state": .71, "aux": .34},
	{"kind": SpeciesScript.Kind.SALPINGOECA, "name": "SALPINGOECA ROSETTA",
		"note": "clonal rosette • bacterial morphogen", "phase": 1.9, "state": .61},
	{"kind": SpeciesScript.Kind.MESODINIUM, "name": "MESODINIUM",
		"note": "stolen nucleus • borrowed plastids", "phase": 2.7, "state": .59},
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
		push_error("SHOT_DIR must be absolute")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output_dir)
	_build_room()
	_build_field()
	call_deferred("_capture")


func _build_room() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(.76, .77, .73)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(.88, .91, .87)
	environment.ambient_light_energy = .34
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = .84
	world.environment = environment
	add_child(world)
	_add_box("MicroscopyWall", Vector3(4.4, 2.8, .08), Vector3(0, 1.30, -1.20), Color(.78,.79,.75))
	_add_box("MicroscopyBench", Vector3(4.4, .10, 3.2), Vector3(0, -.08, .10), Color(.69,.70,.66))
	_add_box("ShallowObservationChamber", Vector3(1.45, .038, .92), Vector3(0, .002, 0), Color(.88,.89,.84))
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-51, -34, 0)
	key.light_color = Color(.92,.91,.85)
	key.light_energy = .86
	key.shadow_enabled = true
	add_child(key)
	var lamp := SpotLight3D.new()
	lamp.position = Vector3(.52,.92,.62)
	lamp.rotation_degrees = Vector3(-58,35,0)
	lamp.light_color = Color(.94,.76,.39)
	lamp.light_energy = 2.0
	lamp.spot_range = 3.2
	lamp.spot_angle = 46.0
	lamp.shadow_enabled = true
	add_child(lamp)
	camera = Camera3D.new()
	camera.fov = 34.0
	camera.near = .006
	add_child(camera)
	camera.make_current()
	var overlay := CanvasLayer.new()
	add_child(overlay)
	title = Label.new()
	title.position = Vector2(26,22)
	title.size = Vector2(1050,42)
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(.045,.05,.045))
	title.add_theme_color_override("font_outline_color", Color(.97,.98,.95,.92))
	title.add_theme_constant_override("outline_size", 7)
	overlay.add_child(title)
	subtitle = Label.new()
	subtitle.position = Vector2(27,64)
	subtitle.size = Vector2(1050,34)
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(.09,.10,.09))
	subtitle.add_theme_color_override("font_outline_color", Color(.97,.98,.95,.92))
	subtitle.add_theme_constant_override("outline_size", 5)
	overlay.add_child(subtitle)
	var field_controller = FieldControllerScript.new()
	add_child(field_controller)
	field_controller.setup(0xC81774, Vector4(-2,-2,2,2), 0.0, Vector3.ZERO)
	controller = ControllerScript.new()
	add_child(controller)
	controller.setup(field_controller, 0xC81774)
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
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = .9
	node.material_override = mat
	add_child(node)


func _build_field() -> void:
	exposure = ExposureScript.new()
	exposure.stamp_room("@microorganism_atlas", [-1.5,-1.1,3.0,2.2], 0.0, .07)
	# Durable R remains left/rear while current G illuminates right/front.
	exposure.add_lamp(Vector3(-.28,1.25,-.08), Vector3.DOWN, 1.9,
			cos(deg_to_rad(21.0)), 1.0, 5.0)
	exposure.add_lamp(Vector3.ZERO, Vector3.DOWN, 0.0, 1.0, 0.0, 2.2)
	exposure.add_lamp(Vector3(.30,1.25,.10), Vector3.DOWN, 1.9,
			cos(deg_to_rad(21.0)), 1.0, 1.15)
	exposure_texture = exposure.make_texture()
	controller.bind_voxel_optics(exposure_texture, ExposureScript.EXTENT_M, ExposureScript.HEIGHT_M)


func _state(panel: Dictionary, panel_index: int) -> Dictionary:
	var kind := int(panel.kind)
	var morph: Dictionary = GeneratorScript.generate(kind, 24001 + panel_index * 101)
	return {
		"id": kind, "morph": morph,
		"pos": Vector3(0, float(morph.tall) * .50, 0),
		"fwd": Vector3.FORWARD, "up": Vector3.UP,
		"gait": float(panel.get("phase", 1.0)), "moving": false,
		"twin": false, "spin": 0.0, "fold_leg": -1, "fold": 0.0, "tun": 0.0,
		"unfold": .35, "photo": MicroLightScript.state(), "photo_side": .55,
		"mechanical": MicroMechanicsScript.state(), "leg_state": [],
		"micro_phase": float(panel.get("phase", 1.0)),
		"micro_state": float(panel.get("state", .5)),
		"micro_aux": float(panel.get("aux", .35)),
		"micro_clock": 2.0, "manipulator_deploy": 0.0, "information_pulse": 0.0,
		"ecology_repeat_count": 0, "ecology_returning": false, "alive": 1.0,
		"hero_near": 0.0,
	}


func _capture() -> void:
	await get_tree().create_timer(.5).timeout
	var images: Array[Image] = []
	for panel_index in PANELS.size():
		var panel: Dictionary = PANELS[panel_index]
		var state := _state(panel, panel_index)
		controller.critters = [state]
		controller._push()
		var morph: Dictionary = state.morph
		var span := maxf(float(morph.length), maxf(float(morph.wide), float(morph.tall)))
		# Lacrymaria's visible neck and Vorticella's stalk exceed body bounds.
		if int(panel.kind) == SpeciesScript.Kind.LACRYMARIA:
			span *= 2.35
		elif int(panel.kind) == SpeciesScript.Kind.HELIOZOAN:
			span *= 1.65
		elif int(panel.kind) == SpeciesScript.Kind.SALPINGOECA:
			span *= 1.35
		var distance := (span * .53) / tan(deg_to_rad(camera.fov * .5))
		camera.position = Vector3(distance * .72, maxf(.18,distance*.42), distance * 1.02)
		if int(panel.kind) in [SpeciesScript.Kind.STENTOR, SpeciesScript.Kind.SPIROSTOMUM,
				SpeciesScript.Kind.BACILLARIA]:
			camera.position = Vector3(distance * .96, maxf(.16,distance*.34), distance * .58)
		camera.look_at(Vector3(0,float(morph.tall)*.30,0), Vector3.UP)
		title.text = String(panel.name)
		subtitle.text = String(panel.note)
		for _frame in 10:
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		image.resize(800,450,Image.INTERPOLATE_LANCZOS)
		image.convert(Image.FORMAT_RGBA8)
		images.append(image)
	var sheet := Image.create(2400,1800,false,Image.FORMAT_RGBA8)
	for i in images.size():
		var destination := Vector2i((i % 3) * 800, (i / 3) * 450)
		sheet.blit_rect(images[i], Rect2i(Vector2i.ZERO,Vector2i(800,450)), destination)
	var output := output_dir.path_join("dream_microorganism_atlas.png")
	var result := sheet.save_png(output)
	print("[DREAM-MICROORGANISM-ATLAS] %s %s" % [output,
			"ok" if result == OK else "SAVE FAILED %d" % result])
	print("[DREAM-MICROORGANISM-ATLAS] species=12 materials=1 textures=1 fields=1 "
			+ "per_species_allocations=false")
	controller.unbind_voxel_optics()
	get_tree().quit(0 if result == OK else 1)
