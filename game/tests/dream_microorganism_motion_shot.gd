extends Node3D
## Pre-merge temporal proof for the twelve microscopy-derived critters.
## This harness advances the production presentation laws directly. It adds no
## species, motion authority, material, voxel field or geometry.

const ControllerScript := preload("res://scripts/dream/critters/dream_critter_controller.gd")
const FieldControllerScript := preload("res://scripts/dream/field/dream_field_controller.gd")
const ExposureScript := preload("res://scripts/dream/dream_exposure_field.gd")
const GeneratorScript := preload("res://scripts/dream/critters/dream_critter_generator.gd")
const SpeciesScript := preload("res://scripts/dream/critters/dream_critter_species.gd")
const MicroLightScript := preload("res://scripts/dream/dream_microbiology_light.gd")
const MicroMechanicsScript := preload("res://scripts/dream/dream_microbiology_mechanics.gd")

const FRAME_SIZE := Vector2i(720, 405)
const FIXED_STEP := 1.0 / 30.0

const PANELS := [
	{"kind": SpeciesScript.Kind.STENTOR, "name": "STENTOR",
		"times": [0.0, .08, .28, .62],
		"phases": ["OPEN TRUMPET", "DRAWSTRING", "RECOVERY", "REOPENED"]},
	{"kind": SpeciesScript.Kind.LACRYMARIA, "name": "LACRYMARIA",
		"times": [0.0, .80, 1.70, 2.80],
		"phases": ["ANCHORED", "NECK DART", "SEARCH ARC", "RETRACT"]},
	{"kind": SpeciesScript.Kind.VORTICELLA, "name": "VORTICELLA",
		"times": [0.0, .08, .65, 1.50],
		"phases": ["BELL EXTENDED", "STALK COILS", "PULLED DOWN", "RECOVERY"]},
	{"kind": SpeciesScript.Kind.EUPLOTES, "name": "EUPLOTES",
		"times": [0.0, .22, .45, .72],
		"phases": ["CIRRI I", "CIRRI II", "CIRRI III", "CIRRI IV"]},
	{"kind": SpeciesScript.Kind.SPIROSTOMUM, "name": "SPIROSTOMUM",
		"times": [0.0, .08, .32, .72],
		"phases": ["ELONGATE", "TWIST FRONT", "CONTRACT", "RELAX"]},
	{"kind": SpeciesScript.Kind.HELIOZOAN, "name": "HELIOZOAN",
		"times": [0.0, .08, .95, 2.20],
		"phases": ["AXOPOD SUN", "CAPTURE RAY", "INWARD HAUL", "RESTORED"]},
	{"kind": SpeciesScript.Kind.EUGLENA, "name": "EUGLENA",
		"times": [0.0, .65, 1.45, 2.40],
		"phases": ["STRAIGHT", "METABOLY I", "METABOLY II", "FLAGELLAR TURN"]},
	{"kind": SpeciesScript.Kind.VOLVOX, "name": "VOLVOX",
		"times": [0.0, 3.50, 6.50, 10.50],
		"phases": ["CELLULAR SPHERE", "ROLL", "DAUGHTER LIP", "INVERSION"]},
	{"kind": SpeciesScript.Kind.NOCTILUCA, "name": "NOCTILUCA",
		"times": [0.0, .08, .32, .72],
		"phases": ["VACUOLAR RIND", "TOUCH", "SCINTILLON WAVE", "AFTERGLOW"]},
	{"kind": SpeciesScript.Kind.BACILLARIA, "name": "BACILLARIA",
		"times": [0.0, .55, 1.20, 1.90],
		"phases": ["RAFT CLOSED", "SHEAR I", "TELESCOPE", "SHEAR II"]},
	{"kind": SpeciesScript.Kind.SALPINGOECA, "name": "SALPINGOECA",
		"times": [0.0, .80, 1.80, 3.10],
		"phases": ["ROSETTE", "FLAGELLA OUT", "COLLAR FLOW", "MATRIX PULSE"]},
	{"kind": SpeciesScript.Kind.MESODINIUM, "name": "MESODINIUM",
		"times": [0.0, .65, 1.40, 2.40],
		"phases": ["BILOBED HOST", "CILIARY BAND", "PLASTID TURN", "KLEPTOKARYON"]},
]

const GROUPS := [
	{"file": "motion_pair_spherical.png", "title": "SPHERICAL FIRST READ",
		"kinds": [SpeciesScript.Kind.VOLVOX, SpeciesScript.Kind.NOCTILUCA]},
	{"file": "motion_pair_stalked.png", "title": "STALKED CILIATE MOTION",
		"kinds": [SpeciesScript.Kind.STENTOR, SpeciesScript.Kind.VORTICELLA]},
	{"file": "motion_hunters_and_ciliates.png", "title": "HUNTERS AND CILIATES",
		"kinds": [SpeciesScript.Kind.LACRYMARIA, SpeciesScript.Kind.EUPLOTES,
			SpeciesScript.Kind.SPIROSTOMUM, SpeciesScript.Kind.HELIOZOAN]},
	{"file": "motion_phototrophs_and_colonies.png", "title": "PHOTOTROPHS AND COLONIES",
		"kinds": [SpeciesScript.Kind.EUGLENA, SpeciesScript.Kind.BACILLARIA,
			SpeciesScript.Kind.SALPINGOECA, SpeciesScript.Kind.MESODINIUM]},
]

var camera: Camera3D
var controller: DreamCritterController
var exposure: DreamExposureField
var exposure_texture: ImageTexture3D
var title: Label
var subtitle: Label
var output_dir := ""
var receipt := {
	"packet": "DREAM-CRITTER-VOXEL-V3-MOTION",
	"shared_materials": 1,
	"shared_voxel_fields": 1,
	"shared_voxel_textures": 1,
	"geometry_triangles": 84000,
	"new_species": 0,
	"new_materials": 0,
	"ecology_writes": 0,
	"species": {},
}


func _ready() -> void:
	output_dir = OS.get_environment("SHOT_DIR")
	if output_dir.is_empty() or not output_dir.is_absolute_path():
		push_error("SHOT_DIR must be absolute")
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(output_dir)
	_build_room()
	_build_field()
	call_deferred("_capture_packet")


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
	_add_box("MicroscopyWall", Vector3(4.4, 2.8, .08),
			Vector3(0, 1.30, -1.20), Color(.78, .79, .75))
	_add_box("MicroscopyBench", Vector3(4.4, .10, 3.2),
			Vector3(0, -.08, .10), Color(.69, .70, .66))
	_add_box("ShallowObservationChamber", Vector3(1.45, .038, .92),
			Vector3(0, .002, 0), Color(.88, .89, .84))
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-51, -34, 0)
	key.light_color = Color(.92, .91, .85)
	key.light_energy = .86
	key.shadow_enabled = true
	add_child(key)
	var lamp := SpotLight3D.new()
	lamp.position = Vector3(.52, .92, .62)
	lamp.rotation_degrees = Vector3(-58, 35, 0)
	lamp.light_color = Color(.94, .76, .39)
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
	title.position = Vector2(26, 22)
	title.size = Vector2(1050, 42)
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(.045, .05, .045))
	title.add_theme_color_override("font_outline_color", Color(.97, .98, .95, .92))
	title.add_theme_constant_override("outline_size", 7)
	overlay.add_child(title)
	subtitle = Label.new()
	subtitle.position = Vector2(27, 64)
	subtitle.size = Vector2(1050, 34)
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(.09, .10, .09))
	subtitle.add_theme_color_override("font_outline_color", Color(.97, .98, .95, .92))
	subtitle.add_theme_constant_override("outline_size", 5)
	overlay.add_child(subtitle)
	var field_controller = FieldControllerScript.new()
	add_child(field_controller)
	field_controller.setup(0xC81774, Vector4(-2, -2, 2, 2), 0.0, Vector3.ZERO)
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
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = .9
	node.material_override = material
	add_child(node)


func _build_field() -> void:
	exposure = ExposureScript.new()
	exposure.stamp_room("@microorganism_motion", [-1.5, -1.1, 3.0, 2.2], 0.0, .07)
	# The same field contains spatially disagreeing durable R and current G.
	exposure.add_lamp(Vector3(-.28, 1.25, -.08), Vector3.DOWN, 1.9,
			cos(deg_to_rad(21.0)), 1.0, 5.0)
	exposure.add_lamp(Vector3.ZERO, Vector3.DOWN, 0.0, 1.0, 0.0, 2.2)
	exposure.add_lamp(Vector3(.30, 1.25, .10), Vector3.DOWN, 1.9,
			cos(deg_to_rad(21.0)), 1.0, 1.15)
	exposure_texture = exposure.make_texture()
	controller.bind_voxel_optics(exposure_texture,
			ExposureScript.EXTENT_M, ExposureScript.HEIGHT_M)


func _panel_for(kind: int) -> Dictionary:
	for panel in PANELS:
		if int(panel.kind) == kind:
			return panel
	return {}


func _state(panel: Dictionary) -> Dictionary:
	var kind := int(panel.kind)
	var morph: Dictionary = GeneratorScript.generate(kind, 24001 + kind * 101)
	var initial_phase := -1.75 if kind == SpeciesScript.Kind.VOLVOX else .35
	var event_species := kind in [SpeciesScript.Kind.STENTOR,
			SpeciesScript.Kind.VORTICELLA, SpeciesScript.Kind.SPIROSTOMUM,
			SpeciesScript.Kind.HELIOZOAN]
	return {
		"id": kind, "morph": morph,
		"pos": Vector3(0, float(morph.tall) * .50, 0),
		"fwd": Vector3.FORWARD, "up": Vector3.UP,
		"gait": .12, "moving": kind == SpeciesScript.Kind.EUPLOTES,
		"twin": false, "spin": 0.0, "fold_leg": -1, "fold": 0.0, "tun": 0.0,
		"unfold": .35, "photo": MicroLightScript.state(), "photo_side": .55,
		"mechanical": MicroMechanicsScript.state(), "leg_state": [],
		"micro_phase": initial_phase, "micro_state": 0.0, "micro_aux": .23,
		"micro_clock": .02 if event_species else 9.0,
		"manipulator_deploy": 0.0, "information_pulse": 0.0,
		"ecology_repeat_count": 0, "ecology_returning": false, "alive": 1.0,
		"hero_near": 0.0, "pause": 0.0,
	}


func _frame_specimen(kind: int, morph: Dictionary) -> void:
	var span := maxf(float(morph.length), maxf(float(morph.wide), float(morph.tall)))
	if kind == SpeciesScript.Kind.LACRYMARIA:
		span *= 2.35
	elif kind == SpeciesScript.Kind.HELIOZOAN:
		span *= 1.65
	elif kind == SpeciesScript.Kind.SALPINGOECA:
		span *= 1.35
	var distance := (span * .53) / tan(deg_to_rad(camera.fov * .5))
	camera.position = Vector3(distance * .72, maxf(.18, distance * .42), distance * 1.02)
	if kind in [SpeciesScript.Kind.STENTOR, SpeciesScript.Kind.SPIROSTOMUM,
			SpeciesScript.Kind.BACILLARIA]:
		camera.position = Vector3(distance * .96, maxf(.16, distance * .34), distance * .58)
	camera.look_at(Vector3(0, float(morph.tall) * .30, 0), Vector3.UP)


func _advance_state(state: Dictionary, from_time: float, to_time: float) -> void:
	var elapsed := from_time
	while elapsed + .0001 < to_time:
		var delta := minf(FIXED_STEP, to_time - elapsed)
		var kind := int(state.morph.kind)
		if kind == SpeciesScript.Kind.EUPLOTES:
			state.gait = float(state.gait) + delta * 5.6
		if kind == SpeciesScript.Kind.NOCTILUCA and elapsed < .05 and elapsed + delta >= .05:
			state.mechanical.response = 1.0
			state.mechanical.age = 0.0
			state.mechanical.carrier = DreamEcologyDirector.Carrier.IMPULSE
		controller._apply_law(state, delta)
		elapsed += delta


func _capture_frame(panel: Dictionary, state: Dictionary, frame_index: int,
		at_time: float) -> Image:
	controller.critters = [state]
	controller._push()
	_frame_specimen(int(panel.kind), state.morph)
	title.text = String(panel.name)
	subtitle.text = "%s  •  t = %.2f s  •  SHARED RG8 FIELD" % [
			String(panel.phases[frame_index]), at_time]
	for _frame in 3:
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.resize(FRAME_SIZE.x, FRAME_SIZE.y, Image.INTERPOLATE_LANCZOS)
	image.convert(Image.FORMAT_RGBA8)
	return image


func _image_delta(a: Image, b: Image) -> float:
	var difference := 0.0
	var samples := 0
	# Ignore text; compare the specimen and room only.
	for y in range(105, FRAME_SIZE.y, 12):
		for x in range(0, FRAME_SIZE.x, 12):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			difference += absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b)
			samples += 3
	return difference / float(maxi(1, samples))


func _capture_species(panel: Dictionary) -> Array[Image]:
	var state := _state(panel)
	var images: Array[Image] = []
	var laws := []
	var deltas := []
	var previous_time := 0.0
	for frame_index in 4:
		var at_time := float(panel.times[frame_index])
		_advance_state(state, previous_time, at_time)
		var image := await _capture_frame(panel, state, frame_index, at_time)
		if not images.is_empty():
			deltas.append(_image_delta(images[-1], image))
		images.append(image)
		laws.append([float(state.micro_phase), float(state.micro_aux),
				float(state.micro_state), float(state.gait)])
		previous_time = at_time
	receipt.species[String(panel.name)] = {
		"times_s": panel.times,
		"phase_labels": panel.phases,
		"law_samples": laws,
		"mean_image_deltas": deltas,
		"minimum_image_delta": deltas.min() if not deltas.is_empty() else 0.0,
	}
	return images


func _save_group(group: Dictionary) -> int:
	var rows: Array = []
	for kind in group.kinds:
		var panel := _panel_for(int(kind))
		rows.append(await _capture_species(panel))
	var sheet := Image.create(FRAME_SIZE.x * 4, FRAME_SIZE.y * rows.size(),
			false, Image.FORMAT_RGBA8)
	for row_index in rows.size():
		var images: Array = rows[row_index]
		for frame_index in images.size():
			var destination := Vector2i(frame_index * FRAME_SIZE.x,
					row_index * FRAME_SIZE.y)
			sheet.blit_rect(images[frame_index], Rect2i(Vector2i.ZERO, FRAME_SIZE), destination)
	var output := output_dir.path_join(String(group.file))
	var result := sheet.save_png(output)
	print("[DREAM-MICROORGANISM-MOTION] %s %s" % [output,
			"ok" if result == OK else "SAVE FAILED %d" % result])
	return result


func _capture_packet() -> void:
	await get_tree().create_timer(.5).timeout
	var result := OK
	for group in GROUPS:
		var save_result := await _save_group(group)
		if save_result != OK:
			result = save_result
	var receipt_path := output_dir.path_join("motion_receipt.json")
	var receipt_file := FileAccess.open(receipt_path, FileAccess.WRITE)
	if receipt_file == null:
		result = ERR_CANT_CREATE
	else:
		receipt_file.store_string(JSON.stringify(receipt, "  ") + "\n")
		receipt_file.close()
	print("[DREAM-MICROORGANISM-MOTION] species=12 sheets=4 material=1 texture=1 "
			+ "field=1 triangles=84000 ecology_writes=0")
	controller.unbind_voxel_optics()
	get_tree().quit(0 if result == OK else 1)
