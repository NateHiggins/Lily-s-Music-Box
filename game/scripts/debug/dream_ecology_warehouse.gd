class_name DreamEcologyWarehouse
extends Node3D
## Debug-only living catalogue. Production species, motion and receptors;
## two unchanged eight-animal draws share one exhibit-owned RG8 volume.

const Species := preload("res://scripts/dream/critters/dream_critter_species.gd")
const Controller := preload("res://scripts/dream/critters/dream_critter_controller.gd")
const Binding := preload("res://scripts/dream/critters/dream_critter_voxel_binding.gd")
const WIDTH := 24.0
const DEPTH := 18.0
const BENCH_Y := 0.85
const EXHIBIT_LAYER := 1 << 19
signal inspection_changed(is_active: bool)
const NOTES := [
	"One animal on both sides of a thin panel.",
	"A rotating crystal in a still shell. Try lamp onset or a pulse.",
	"A planted leg folds without moving its endpoints.",
	"Eight-leg gait and periodic whole-body tun contraction.",
	"Whole trumpet contractions gradually habituate.",
	"An anchored hunter with a searching, extending neck.",
	"The stalk coils and recovers beneath the bell.",
	"Four coordinated cirral gait phases.",
	"The long body contracts and slowly relaxes.",
	"One selected ray captures and hauls inward.",
	"Continuous metaboly. No directional phototaxis is implemented.",
	"Slow colony rotation and daughter inversion; watch for 30 seconds.",
	"Touch specimen triggers the accepted debug scintillation stimulus.",
	"Cells shear and telescope as a coordinated raft.",
	"Rosette, collar and flagellar motion.",
	"Internal plastid and nucleus motion in the ciliate host.",
]

class FaunaRoster:
	extends RefCounted
	var batches: Array = []
	var critters: Array:
		get:
			var result: Array = []
			for batch in batches: result.append_array(batch.critters)
			return result
	func nudged_by_hero(at: Vector3, from: Vector3, delta: float) -> Dictionary:
		var nearest = null
		var distance := 0.30
		for batch in batches:
			for specimen: Dictionary in batch.critters:
				var d: float = at.distance_to(specimen.pos)
				if d < distance:
					distance = d
					nearest = batch
		return nearest.nudged_by_hero(at, from, delta) if nearest != null else {}

var controllers: Array = []
var exposure: DreamExposureField
var exposure_texture: ImageTexture3D
var voxel_binding: Node
var field: DreamFieldController
var residue: DreamResidue
var director: DreamEcologyDirector
var margin: DreamMarginController
var palps: DreamPalpRenderer
var hero: DreamHeroTentacle
var camera: Camera3D
var overview_station: Marker3D
var lamp: SpotLight3D
var selected_kind := 0
var simulation_paused := false
var lamp_enabled := true
var active := false
var initialized := false
var upload_count := 0
var _player: Node3D
var _prior_camera: WeakRef
var _prior_mouse := Input.MOUSE_MODE_VISIBLE
var _prior_physics := false
var _prior_input := false
var _prior_process := false
var _prior_camera_process := false
var _prior_camera_input := false
var _prior_camera_physics := false
var _roster := FaunaRoster.new()
var _canvas: CanvasLayer
var _status: Label
var _title: Label
var _lamp_button: Button
var _pause_button: Button
var _clock := 0.0
var _lamp_clock := 0.0
var _orbit := Vector2(0.65, 0.34)
var _distance := 1.05
var _overview := false
var _dragging := false

func setup(player: Node3D = null) -> void:
	if initialized or GameBoot.launch_mode != GameBoot.LaunchMode.DEBUG: return
	initialized = true
	_player = player
	name = "DreamEcologyWarehouse"
	_build_room()
	_build_ecology()
	_build_controls()
	_restrict_geometry(self)
	reset_specimens()
	focus_species(0)

func _build_room() -> void:
	_box("ExhibitFloor", Vector3(0, -0.10, 0), Vector3(WIDTH, 0.2, DEPTH), Color(0.10,0.12,0.15))
	for side in [-1.0, 1.0]:
		_box("SideWall", Vector3(side * WIDTH * 0.5, 2.1, 0), Vector3(0.15,4.2,DEPTH), Color(0.16,0.18,0.21))
	_box("BackWall", Vector3(0, 2.1, -DEPTH * 0.5), Vector3(WIDTH,4.2,0.15), Color(0.16,0.18,0.21))
	# The floor is a real support surface; plinths keep organisms in view.
	for kind in Species.all_kinds():
		var center := _bench_position(int(kind))
		_box("Bench_%02d" % kind, center + Vector3(0, BENCH_Y - 0.08, 0), Vector3(3.4,0.16,2.65), Color(0.23,0.25,0.28))
		_label(Species.NAMES[kind].replace("_", " "), center + Vector3(0, BENCH_Y + 0.06, 1.45))
		if kind == Species.Kind.SEAM_GRAZER:
			_box("GrazerThinPanel", center + Vector3(0, BENCH_Y + 0.55, 0), Vector3(1.7,1.1,0.06), Color(0.36,0.38,0.39))
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-55,-28,0)
	key.light_color = Color(0.80,0.86,1.0)
	key.light_energy = 1.0
	key.light_cull_mask = EXHIBIT_LAYER
	key.shadow_enabled = true
	add_child(key)
	overview_station = Marker3D.new()
	overview_station.name = "OverviewCameraStation"
	overview_station.position = Vector3(WIDTH*0.58,DEPTH*0.92,DEPTH*1.25)
	add_child(overview_station)
	camera = Camera3D.new()
	camera.name = "SpecimenCamera"
	camera.near = 0.006
	camera.fov = 40.0
	add_child(camera)
	lamp = SpotLight3D.new()
	lamp.name = "InspectionLamp"
	lamp.spot_range = 8.0
	lamp.spot_angle = 24.0
	lamp.light_energy = 2.2
	lamp.light_color = Color(1.0,0.82,0.55)
	lamp.shadow_enabled = true
	lamp.light_cull_mask = EXHIBIT_LAYER
	camera.add_child(lamp)
	lamp.position = Vector3(0.03,-0.025,0)

func _build_ecology() -> void:
	var origin := global_position
	field = DreamFieldController.new()
	add_child(field)
	field.setup(73129, Vector4(origin.x-12,origin.z-9,origin.x+12,origin.z+9), origin.y, to_global(_bench_position(0)+Vector3(0,1.3,0)))
	field.player = self
	exposure = DreamExposureField.new()
	exposure.stamp_room("@warehouse_ecology", [origin.x-12,origin.z-9,origin.x+12,origin.z+9], 0.07, 0.31)
	exposure_texture = exposure.make_texture()
	voxel_binding = Binding.new()
	add_child(voxel_binding)
	if not voxel_binding.set_texture(exposure_texture): push_error("Warehouse exposure texture refused")
	residue = DreamResidue.new()
	add_child(residue)
	residue.setup(73130)
	residue.field = field
	director = DreamEcologyDirector.new()
	add_child(director)
	director.setup(73131)
	director.field = field
	director.critters = _roster
	margin = DreamMarginController.new()
	add_child(margin)
	margin.setup(field,73132)
	margin.director = director
	margin.critters = _roster
	palps = DreamPalpRenderer.new()
	add_child(palps)
	palps.setup(margin)
	director.margin = margin
	for group in 2:
		var controller := Controller.new()
		add_child(controller)
		controller.setup(field,73133+group)
		controller.debug_set_id_base(group*100000)
		controller.margin = margin
		controller.residue = residue
		controller.director = director
		controllers.append(controller)
		_roster.batches.append(controller)
		voxel_binding.bind_controller(controller)
	# Actual habitat owners remain available. The hero is placed by the first
	# bay, away from the crab so fear does not continuously suppress its law.
	hero = DreamHeroTentacle.new()
	add_child(hero)
	hero.setup(73135,to_global(_bench_position(0)+Vector3(-1.3,1.5,-0.3)),Vector3.RIGHT)
	hero.field = field
	hero.critters = _roster
	hero.margin = margin
	hero.watch = camera
	margin.hero = hero
	director.hero = hero
	for controller in controllers: controller.hero = hero
	hero.touched.connect(func(at: Vector3, normal: Vector3): residue.lay(at,normal,0.16,1.0,3.6))

func _bench_position(kind: int) -> Vector3:
	return Vector3((kind % 4 - 1.5)*5.1,0,(kind / 4 - 1.5)*3.8)

func specimen_for(kind: int) -> Dictionary:
	for controller in controllers:
		for specimen: Dictionary in controller.critters:
			if int(specimen.morph.kind) == kind: return specimen
	return {}

func reset_specimens() -> void:
	if not initialized: return
	for controller in controllers: controller.debug_clear_specimens()
	for kind in Species.all_kinds():
		var contact := _bench_position(kind) + Vector3(0,BENCH_Y,0)
		var normal := Vector3.UP
		if kind == Species.Kind.SEAM_GRAZER:
			contact += Vector3(0,0.56,0.03)
			normal = Vector3.BACK
		controllers[kind / 8].debug_spawn_specimen(kind,24001+kind*101,to_global(contact),normal,3600.0)
	for controller in controllers: controller._push()

func focus_species(kind: int) -> void:
	if kind < 0 or kind >= Species.NAMES.size() or not initialized: return
	selected_kind = kind
	_overview = false
	var specimen := specimen_for(kind)
	if not specimen.is_empty():
		var morph: Dictionary = specimen.morph
		var span: float = maxf(morph.length,maxf(morph.wide,morph.tall))
		if kind == Species.Kind.CRYSTAL_LISTENER: span *= 1.5
		if kind == Species.Kind.HELIOZOAN: span *= 1.65
		_distance = clampf(span*2.8,0.40,2.8)
		# Its existing shader extends the neck up to 6.4 body lengths.
		if kind == Species.Kind.LACRYMARIA: _distance = clampf(float(morph.length)*7.0*1.65,0.4,8.0)
	_update_camera()

func set_lamp_enabled(value: bool) -> void:
	lamp_enabled = value
	if lamp != null: lamp.light_energy = 2.2 if value else 0.0
	if _lamp_button != null: _lamp_button.text = "Lamp: ON" if value else "Lamp: OFF"

func lamp_pose() -> Dictionary:
	if lamp == null: return {}
	return {"origin":lamp.global_position,"dir":-lamp.global_basis.z,"range":lamp.spot_range,
		"angle_deg":lamp.spot_angle*2.0,"energy":1.0 if lamp_enabled else 0.0,
		"splash":_focus_position()}

func set_simulation_paused(value: bool) -> void:
	simulation_paused = value
	for node in [field,residue,director,margin,palps,hero] + controllers:
		if is_instance_valid(node):
			node.set_physics_process(not value)
			node.set_process(not value)
	if _pause_button != null: _pause_button.text = "Resume" if value else "Pause"

func stimulate_selected() -> void:
	var specimen := specimen_for(selected_kind)
	if specimen.is_empty(): return
	if selected_kind == Species.Kind.NOCTILUCA:
		# Exact transient stimulus used by the accepted motion harness. This
		# debug control does not pretend a gameplay receptor exists for it.
		specimen.mechanical.response = 1.0
		specimen.mechanical.age = 0.0
		specimen.mechanical.carrier = DreamEcologyDirector.Carrier.IMPULSE
	else:
		var substrate := DreamEcologyDirector.Substrate.FLOOR if absf(specimen.up.y)>0.65 else DreamEcologyDirector.Substrate.WALL
		director.emit_mechanical_packet(-73129,specimen.pos,1.0,1.0,DreamEcologyDirector.Carrier.IMPULSE,Vector3.RIGHT,0.5,substrate,18.0)

func feed_selected() -> void:
	var specimen := specimen_for(selected_kind)
	if specimen.is_empty(): return
	residue.lay(specimen.pos-specimen.up*float(specimen.morph.tall)*0.5,specimen.up,0.15,1.0,6.0)

func viewing_stand() -> Vector3:
	return to_global(Vector3(0,0.06,DEPTH*0.5-1.0))

func hall_aabb() -> AABB:
	return AABB(to_global(Vector3(-WIDTH*0.5,-0.5,-DEPTH*0.5)),Vector3(WIDTH,4.8,DEPTH))

func activate(value: bool = true) -> void:
	if not initialized or value == active: return
	active = value
	_canvas.visible = value
	if value:
		var previous := get_viewport().get_camera_3d()
		_prior_camera = weakref(previous) if previous != null and previous != camera else null
		_prior_mouse = Input.mouse_mode
		if is_instance_valid(previous) and previous != camera:
			_prior_camera_process = previous.is_processing()
			_prior_camera_physics = previous.is_physics_processing()
			_prior_camera_input = previous.is_processing_unhandled_input()
			previous.set_process(false)
			previous.set_physics_process(false)
			previous.set_process_unhandled_input(false)
		if is_instance_valid(_player):
			_prior_physics = _player.is_physics_processing()
			_prior_input = _player.is_processing_unhandled_input()
			_prior_process = _player.is_processing()
			_player.set_physics_process(false)
			_player.set_process_unhandled_input(false)
			_player.set_process(false)
		camera.make_current()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		set_simulation_paused(false)
	else:
		camera.clear_current()
		var previous: Camera3D = _prior_camera.get_ref() if _prior_camera != null else null
		if is_instance_valid(previous):
			previous.make_current()
			previous.set_process(_prior_camera_process)
			previous.set_physics_process(_prior_camera_physics)
			previous.set_process_unhandled_input(_prior_camera_input)
		if is_instance_valid(_player):
			_player.set_physics_process(_prior_physics)
			_player.set_process_unhandled_input(_prior_input)
			_player.set_process(_prior_process)
		Input.mouse_mode = _prior_mouse
		set_simulation_paused(true)
	_dragging = false
	inspection_changed.emit(active)

func _physics_process(delta: float) -> void:
	if not initialized: return
	if active and is_instance_valid(_player) and not hall_aabb().has_point(_player.global_position):
		activate(false)
	if simulation_paused: return
	_clock += delta
	_lamp_clock += delta
	if _lamp_clock >= 0.1:
		var pose := lamp_pose()
		exposure.add_lamp(pose.origin,pose.dir,pose.range,cos(deg_to_rad(pose.angle_deg*0.5)),pose.energy,_lamp_clock)
		if exposure.upload(exposure_texture): upload_count += 1
		_lamp_clock = 0.0

func _process(_delta: float) -> void:
	if not initialized: return
	_update_camera()
	if _title != null:
		_title.text = Species.NAMES[selected_kind].replace("_"," ").to_upper()
		var specimen := specimen_for(selected_kind)
		_status.text = NOTES[selected_kind]+"\n\n16 species · Shared voxel light\n1-hour lifetime · Debug"+ (" · Feeding" if specimen.get("feeding",false) else "")

func _focus_position() -> Vector3:
	var specimen := specimen_for(selected_kind)
	if not specimen.is_empty() and selected_kind == Species.Kind.LACRYMARIA:
		return specimen.pos+specimen.fwd*float(specimen.morph.length)*2.5
	return specimen.pos if not specimen.is_empty() else to_global(Vector3(0,1,0))

func _update_camera() -> void:
	if camera == null: return
	if _overview:
		camera.fov = 50.0
		camera.global_position = overview_station.global_position
		camera.look_at(to_global(Vector3.UP*BENCH_Y))
	else:
		camera.fov = 40.0
		var focus := _focus_position()
		var offset := Vector3(sin(_orbit.x)*cos(_orbit.y),sin(_orbit.y),cos(_orbit.x)*cos(_orbit.y))*_distance
		camera.global_position = focus+offset
		camera.look_at(focus,Vector3.UP)
	# Center the specimen in the usable view beside the controls. Moving the
	# actual camera keeps its child lamp at the rendered inspection viewpoint.
	var view_height := maxf(1,get_viewport().get_visible_rect().size.y)
	var distance := camera.global_position.distance_to(to_global(Vector3.UP*BENCH_Y)) if _overview else _distance
	camera.global_position -= camera.global_basis.x*distance*tan(deg_to_rad(camera.fov*0.5))*376.0/view_height

func _unhandled_input(event: InputEvent) -> void:
	if not active: return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT: _dragging = event.pressed
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP: _distance = maxf(0.15,_distance*0.87)
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN: _distance = minf(10.0,_distance*1.15)
	elif event is InputEventMouseMotion and _dragging:
		_overview = false
		_orbit.x -= event.relative.x*0.008
		_orbit.y = clampf(_orbit.y+event.relative.y*0.008,-0.15,1.3)

func _build_controls() -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer = 80
	_canvas.visible = false
	add_child(_canvas)
	var panel := PanelContainer.new()
	panel.position = Vector2(16,16)
	_canvas.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(360, minf(760,get_viewport().get_visible_rect().size.y-32))
	panel.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_font_size_override("font_size",16)
	column.add_theme_constant_override("separation",8)
	scroll.add_child(column)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size",22)
	column.add_child(_title)
	var grid := GridContainer.new()
	grid.columns = 2
	column.add_child(grid)
	for kind in Species.all_kinds():
		var button := Button.new()
		button.text = Species.NAMES[kind].replace("_"," ")
		button.pressed.connect(focus_species.bind(kind))
		grid.add_child(button)
	var actions := GridContainer.new()
	actions.columns = 2
	column.add_child(actions)
	_lamp_button = _button(actions,"Lamp: ON",func():set_lamp_enabled(not lamp_enabled))
	_pause_button = _button(actions,"Pause",func():set_simulation_paused(not simulation_paused))
	_button(actions,"Pulse / touch",stimulate_selected)
	_button(actions,"Food residue",feed_selected)
	_button(actions,"Reset specimens",reset_specimens)
	_button(actions,"Overview",func():_overview=true)
	_button(actions,"Leave camera",func():activate(false))
	_status = Label.new()
	_status.custom_minimum_size = Vector2(335,115)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)
	var help := Label.new()
	help.text = "Right-drag: orbit · wheel: zoom\nPulse / touch: debug stimulus\nReset keeps light history · F1: leave camera"
	column.add_child(help)

func _button(parent: Node, caption: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _restrict_geometry(node: Node) -> void:
	# Exhibition lighting must not brighten ordinary building geometry.
	if node is VisualInstance3D: node.layers = EXHIBIT_LAYER
	for child in node.get_children(): _restrict_geometry(child)

func _box(label_text: String, at: Vector3, dimensions: Vector3, tint: Color) -> void:
	var body := StaticBody3D.new()
	body.name = label_text
	body.position = at
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	visual.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.roughness = 0.88
	visual.material_override = mat
	body.add_child(visual)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = dimensions
	shape.shape = box
	body.add_child(shape)
	add_child(body)

func _label(caption: String, at: Vector3) -> void:
	var label := Label3D.new()
	label.text = caption
	label.position = at
	label.font_size = 46
	label.pixel_size = 0.005
	label.modulate = Color(0.82,0.9,1.0)
	add_child(label)

func stats() -> Dictionary:
	return {"species":_roster.critters.size(),"controllers":controllers.size(),"voxel_fields":1 if exposure!=null else 0,
		"voxel_textures":1 if exposure_texture!=null else 0,"uploads":upload_count,"paused":simulation_paused,"active":active}

func _exit_tree() -> void:
	if active: activate(false)
	if is_instance_valid(voxel_binding): voxel_binding.clear()
	if _roster != null: _roster.batches.clear()
	exposure_texture = null
	exposure = null
