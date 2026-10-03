class_name DreamEcologyWarehouse
extends Node3D
## Debug-only living catalogue. Production species, motion and receptors;
## two unchanged eight-animal draws share one exhibit-owned RG8 volume.

const Species := preload("res://scripts/dream/critters/dream_critter_species.gd")
const Controller := preload("res://scripts/dream/critters/dream_critter_controller.gd")
const Binding := preload("res://scripts/dream/critters/dream_critter_voxel_binding.gd")
const Zoo := preload("res://scripts/debug/dream_zoo_catalog.gd")
const Organelle := preload("res://scripts/debug/dream_organelle_exhibit.gd")
const WIDTH := 24.0
const HALL_MIN_Z := -29.0
const HALL_MAX_Z := 9.0
const DEPTH := HALL_MAX_Z - HALL_MIN_Z
const HALL_CENTER_Z := (HALL_MIN_Z + HALL_MAX_Z) * 0.5
const ORGANELLE_WALL := Vector3(-5.1,1.7,-11.8)
const BENCH_Y := 0.85
const EXHIBIT_LAYER := 1 << 19
const LAMP_ENERGY := preload("res://scripts/lamp/lamp_gameplay_profile.gd").INSPECTION_ENERGY
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
var inspection_key: DirectionalLight3D
var blender_review_mode := 0
var blender_failures: Array[String] = []
var organelle: Node3D
var placeholders: Array[Dictionary] = []
var stations: Dictionary = {}
var _bay_labels: Dictionary = {}
var _specimen_labels: Array[Label3D] = []
var selected_exhibit := "organelle"
var _pulse_button: Button
var _food_button: Button
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
var _player_overlay_states: Array[Dictionary] = []
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
# True while _overview was turned on for a walk rather than by the
# exhibit's own Overview button, so the inspection rig can take its own
# framing back without discarding a choice the operator made.
var _walk_overview := false
var _dragging := false

func setup(player: Node3D = null) -> void:
	if initialized or GameBoot.launch_mode != GameBoot.LaunchMode.DEBUG: return
	initialized = true
	add_to_group("lamp_inspection_source")
	_player = player
	name = "DreamEcologyWarehouse"
	placeholders = Zoo.placeholders()
	placeholders.append_array(Zoo.deferred_groups())
	_build_room()
	_build_ecology()
	_build_controls()
	_restrict_geometry(self)
	reset_specimens()
	focus_organelle()

func _build_room() -> void:
	_box("ExhibitFloor", Vector3(0, -0.10, HALL_CENTER_Z), Vector3(WIDTH, 0.2, DEPTH), Color(0.10,0.12,0.15))
	for side in [-1.0, 1.0]:
		_box("SideWall", Vector3(side * WIDTH * 0.5, 2.1, HALL_CENTER_Z), Vector3(0.15,4.2,DEPTH), Color(0.16,0.18,0.21))
	_box("BackWall", Vector3(0, 2.1, HALL_MIN_Z), Vector3(WIDTH,4.2,0.15), Color(0.16,0.18,0.21))
	# The floor is a real support surface; plinths keep organisms in view.
	for kind in Species.all_kinds():
		var center := _bench_position(int(kind))
		_box("Bench_%02d" % kind, center + Vector3(0, BENCH_Y - 0.08, 0), Vector3(3.4,0.16,2.65), Color(0.23,0.25,0.28))
		var caption: String = Species.NAMES[kind].replace("_", " ")
		if kind == Species.Kind.CRYSTAL_LISTENER: caption += " — at organelle wall"
		_specimen_labels.append(_label(caption, center + Vector3(0, BENCH_Y + 0.06, 1.45)))
		if kind == Species.Kind.SEAM_GRAZER:
			_box("GrazerThinPanel", center + Vector3(0, BENCH_Y + 0.55, 0), Vector3(1.7,1.1,0.06), Color(0.36,0.38,0.39))
	_build_zoo_bays()
	var key := DirectionalLight3D.new()
	inspection_key = key
	key.rotation_degrees = Vector3(-55,-28,0)
	key.light_color = Color(0.80,0.86,1.0)
	key.light_energy = 1.0
	key.light_cull_mask = EXHIBIT_LAYER
	key.shadow_enabled = true
	add_child(key)
	overview_station = Marker3D.new()
	overview_station.name = "OverviewCameraStation"
	overview_station.position = Vector3(WIDTH*0.58,DEPTH*0.82,HALL_MAX_Z+DEPTH*0.7)
	add_child(overview_station)
	camera = Camera3D.new()
	camera.name = "SpecimenCamera"
	camera.near = 0.006
	camera.fov = 40.0
	add_child(camera)
	lamp = SpotLight3D.new()
	lamp.name = "InspectionLamp"
	# A camera only centimetres from a small specimen makes the half-metre
	# optical grid miss a narrow cone. Keep the real inspection source behind
	# the viewing plane, then aim it at the specimen in _update_camera.
	lamp.position = Vector3(0,0,1.0)
	lamp.spot_range = 8.0
	lamp.spot_angle = 24.0
	lamp.light_energy = LAMP_ENERGY
	lamp.light_color = Color(1.0,0.82,0.55)
	lamp.shadow_enabled = true
	lamp.light_cull_mask = EXHIBIT_LAYER
	camera.add_child(lamp)
	lamp.position = Vector3(0,0,1.0)

func _build_ecology() -> void:
	var origin := global_position
	field = DreamFieldController.new()
	add_child(field)
	field.setup(73129, Vector4(origin.x-WIDTH*0.5,origin.z+HALL_MIN_Z,origin.x+WIDTH*0.5,origin.z+HALL_MAX_Z), origin.y, to_global(ORGANELLE_WALL))
	field.player = self
	exposure = DreamExposureField.new()
	exposure.stamp_room("@warehouse_ecology", [origin.x-WIDTH*0.5,origin.z+HALL_MIN_Z,origin.x+WIDTH*0.5,origin.z+HALL_MAX_Z], 0.07, 0.31)
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
	# Palp vertices already contain world positions; avoid a second warehouse transform.
	palps.top_level = true
	palps.global_transform = Transform3D.IDENTITY
	palps.setup(margin)
	palps.mesh_instance.mesh.custom_aabb = AABB(
		to_global(Vector3(-WIDTH*0.5-2,-2,HALL_MIN_Z-2)),Vector3(WIDTH+4,8,DEPTH+4))
	director.margin = margin
	for group in 2:
		var controller := Controller.new()
		add_child(controller)
		controller.setup(field,73133+group)
		if OS.get_environment("DREAM_BLENDER_LEGACY") != "1" and not controller.enable_blender_visuals():
			blender_failures.append(controller.blender_error)
		controller.debug_set_id_base(group*100000)
		controller.margin = margin
		controller.residue = residue
		controller.director = director
		controllers.append(controller)
		_roster.batches.append(controller)
		voxel_binding.bind_controller(controller)
	# One recovered hero shares the existing ecology owners in its own wall bay.
	# The listener joins this ensemble; its same record remains in the roster.
	hero = DreamHeroTentacle.new()
	add_child(hero)
	hero.setup(73135,to_global(ORGANELLE_WALL+Vector3(-2.2,-0.2,0.08)),Vector3.BACK)
	for mesh in hero.meshes: mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hero.field = field
	hero.critters = _roster
	hero.margin = margin
	hero.watch = camera
	margin.hero = hero
	director.hero = hero
	for controller in controllers: controller.hero = hero
	hero.touched.connect(func(at: Vector3, normal: Vector3): residue.lay(at,normal,0.16,1.0,3.6))
	hero.lifecycle_shed.connect(residue.lay_memory)
	organelle = Organelle.new()
	add_child(organelle)
	organelle.setup(field,residue,director,margin,palps,hero,_roster,to_global(ORGANELLE_WALL),Vector3.BACK)

func _build_zoo_bays() -> void:
	_box("OrganelleSupportWall",ORGANELLE_WALL,Vector3(8.5,3.4,0.12),Color(0.12,0.08,0.13))
	_label("HERO & ORGANELLES — LIVE",ORGANELLE_WALL+Vector3(0,1.35,0.12))
	for index in placeholders.size():
		var entry: Dictionary = placeholders[index]
		# The first two bays are reserved for the live wall ensemble.
		var slot := index + 2
		var center := Vector3((slot % 4 - 1.5)*5.1,0,-10.2-float(slot / 4)*3.0)
		var marker := Marker3D.new()
		marker.name = "ReservedView" # Identity is the stations dictionary, not a generated node path.
		marker.position = center+Vector3(0,1.15,0)
		add_child(marker)
		stations[entry.id] = marker
		_box("Reserved_"+str(entry.id),center+Vector3(0,0.55,0),Vector3(3.4,0.18,1.85),Color(0.17,0.16,0.19))
		# Empty stands and text deliberately make no claim to creature anatomy.
		_bay_labels[entry.id] = _label(str(entry.label)+"\nPLACEHOLDER",center+Vector3(0,1.2,0),true)

func placeholder_for(id: String) -> Dictionary:
	for entry in placeholders:
		if str(entry.id) == id: return entry
	return {}

func focus_placeholder(id: String) -> void:
	_set_blender_inspection_kind(-1)
	if not initialized or not stations.has(id): return
	selected_exhibit = id
	_overview = false
	_orbit = Vector2(PI+0.15,0.32)
	_distance = 5.3
	_process(0.0)

func focus_organelle() -> void:
	_set_blender_inspection_kind(-1)
	if not initialized or organelle == null: return
	selected_exhibit = "organelle"
	_overview = false
	_orbit = Vector2(0.25,0.16)
	_distance = 5.2
	_process(0.0)

func focus_hero() -> void:
	_set_blender_inspection_kind(-1)
	if not initialized or hero == null: return
	selected_exhibit = "hero"
	_overview = false
	_orbit = Vector2(-0.65,0.08)
	_distance = 1.6
	_process(0.0)

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
		var spawn_at := to_global(contact)
		if kind == Species.Kind.CRYSTAL_LISTENER and organelle != null:
			spawn_at = organelle.recipient_position()
			normal = Vector3.BACK
		controllers[kind / 8].debug_spawn_specimen(kind,24001+kind*101,spawn_at,normal,3600.0)
	for controller in controllers: controller._push()
	if organelle != null: organelle.reset_display()

func focus_species(kind: int) -> void:
	if kind < 0 or kind >= Species.NAMES.size() or not initialized: return
	selected_exhibit = ""
	selected_kind = kind
	_set_blender_inspection_kind(kind)
	_overview = false
	var specimen := specimen_for(kind)
	if not specimen.is_empty():
		var morph: Dictionary = specimen.morph
		var span: float = maxf(morph.length,maxf(morph.wide,morph.tall))
		if kind == Species.Kind.CRYSTAL_LISTENER: span *= 1.5
		if kind == Species.Kind.HELIOZOAN: span *= 1.65
		var provider = controllers[0].blender_visuals
		if provider != null and provider.assets.templates.has(kind):
			var bounds: AABB = provider.assets.templates[kind][0].bounds
			var extent := bounds.size*Vector3(morph.wide,morph.tall,morph.length)
			span = maxf(extent.x,maxf(extent.y,extent.z))
			_distance = clampf(span*2.0,0.40,5.0)
		else:
			_distance = clampf(span*2.8,0.40,2.8)
		# A side view shows the hunting reach rather than looking along it.
		if kind == Species.Kind.LACRYMARIA: _distance = clampf(float(morph.length)*7.0*1.65,0.4,8.0)
		var up: Vector3 = specimen.up
		var forward: Vector3 = specimen.fwd
		var side := up.cross(forward).normalized()
		var view := (side*0.85+up*0.55+forward*0.25).normalized()
		# Wall-mounted mantles need a face view; jointed blades need a diagonal
		# view so the far-side knees do not hide their descending foot segments.
		if kind == Species.Kind.SEAM_GRAZER:
			view = (side*0.35+up*1.1+forward*0.35).normalized()
		elif kind == Species.Kind.CRYSTAL_LISTENER:
			view = (side*0.45+up*0.8+forward*0.65).normalized()
		elif kind == Species.Kind.FOLD_CRAB:
			view = (side*0.85+up*0.7+forward*0.85).normalized()
		_orbit = Vector2(atan2(view.x,view.z),asin(view.y))
	_process(0.0)

func _set_blender_inspection_kind(kind: int) -> void:
	for controller in controllers:
		controller.set_blender_inspection_kind(kind)

func set_blender_review_mode(mode: int) -> void:
	blender_review_mode = clampi(mode,0,2)
	for controller in controllers: controller.set_blender_review_mode(blender_review_mode)
	_process(0.0)

func set_lamp_enabled(value: bool) -> void:
	lamp_enabled = value
	if lamp != null: lamp.light_energy = LAMP_ENERGY if value else 0.0
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
	if organelle != null: organelle.set_simulation_paused(value)
	if _pause_button != null: _pause_button.text = "Resume" if value else "Pause"

func stimulate_selected() -> void:
	if selected_exhibit in ["organelle","hero"]:
		organelle.pulse()
		return
	if not selected_exhibit.is_empty(): return
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
	if selected_exhibit in ["organelle","hero"]:
		residue.lay(organelle.recipient_position(),Vector3.BACK,0.15,1.0,6.0)
		return
	if not selected_exhibit.is_empty(): return
	var specimen := specimen_for(selected_kind)
	if specimen.is_empty(): return
	residue.lay(specimen.pos-specimen.up*float(specimen.morph.tall)*0.5,specimen.up,0.15,1.0,6.0)

func viewing_stand() -> Vector3:
	return to_global(Vector3(0,0.06,HALL_MAX_Z-1.0))

## Where a visitor stands to walk the zoo rather than orbit it: just inside
## the open end of the hall, on the floor, with the sixteen specimen benches
## ahead and the reserved bays and the organelle wall beyond them.
func zoo_stand() -> Vector3:
	return to_global(Vector3(0,0.06,HALL_MAX_Z-2.2))

## Yaw for a body whose forward is -Z, aimed from zoo_stand() down the hall.
## Arriving faced at the wall behind you is arriving nowhere.
func zoo_yaw() -> float:
	var look := to_global(Vector3(0,0.06,HALL_CENTER_Z)) - zoo_stand()
	return atan2(-look.x,-look.z)

## Turn the room on without taking the camera, for a visit made on foot.
##
## activate() is an inspection rig: it makes the specimen camera current,
## frees the pointer for orbiting and stops the player processing entirely.
## Two things a walking visitor needs are tied to that rig rather than to
## the room - the organelle wall's tendrils are visible only while the
## organelle adapter is active, and every organism's processing follows
## simulation_paused, which activate() sets on the way out. So leaving the
## inspection camera used to leave a frozen hall with an empty wall. This
## gives the walker the live room and none of the rig.
func open_for_walking() -> void:
	if not initialized: return
	if active: activate(false)
	if organelle != null: organelle.activate(true)
	set_simulation_paused(false)
	# The plaques are the zoo's signage; on foot they are the only thing
	# naming what is on each bench. The inspection camera hides them because
	# it puts one specimen in front of you and titles it in the panel.
	_overview = true
	_walk_overview = true
	_process(0.0)

func hall_aabb() -> AABB:
	return AABB(to_global(Vector3(-WIDTH*0.5,-0.5,HALL_MIN_Z)),Vector3(WIDTH,4.8,DEPTH))

func activate(value: bool = true) -> void:
	if not initialized or value == active: return
	active = value
	if organelle != null: organelle.activate(value)
	_canvas.visible = value
	if value:
		if _walk_overview:
			# The plaques were lit for a visit on foot. The rig frames one
			# specimen at a time, so give it its own framing back rather than
			# opening on the room from the overview station.
			_walk_overview = false
			_overview = false
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
			_hide_player_overlays()
		camera.make_current()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		set_simulation_paused(false)
	else:
		_restore_player_overlays()
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

func _hide_player_overlays() -> void:
	# The held set, screen beam mask and crosshair use CanvasLayers, so a
	# camera change alone leaves them over the specimen. Suspend presentation
	# only; the carried instrument, radio and held lamp retain their owners.
	_player_overlay_states.clear()
	var controller := _player as PlayerController
	if controller == null: return
	for child: Node in controller.get_children():
		if child is CanvasLayer: _hide_player_layer(child as CanvasLayer)
	if is_instance_valid(controller.carried_device):
		for layer: CanvasLayer in controller.carried_device.find_children("*", "CanvasLayer", true, false):
			_hide_player_layer(layer)

func _hide_player_layer(layer: CanvasLayer) -> void:
	_player_overlay_states.append({"layer": weakref(layer), "visible": layer.visible})
	layer.hide()

func _restore_player_overlays() -> void:
	for state: Dictionary in _player_overlay_states:
		var layer := (state.layer as WeakRef).get_ref() as CanvasLayer
		if is_instance_valid(layer): layer.visible = bool(state.visible)
	_player_overlay_states.clear()

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
	for label in _specimen_labels: label.visible = _overview
	for id in _bay_labels: _bay_labels[id].visible = _overview or str(id) == selected_exhibit
	_update_camera()
	if _title != null:
		if selected_exhibit in ["organelle","hero"]:
			_title.text = "HERO & ORGANELLE WALL"
			var hero_state := "Arriving" if hero == null else hero.state_name().capitalize()
			if hero != null and hero.state == DreamHeroTentacle.State.MEMBRANE_BULGE:
				hero_state = "Arriving — membrane swelling"
			elif hero != null and hero.state == DreamHeroTentacle.State.ABSENT:
				hero_state = "Between appearances"
			_status.text = "Hero: %s\nLive hero, six palp forms, branches/cilia and living wall. Crystal listener joins this bay.\nPulse: staged debug stimulus · no new species" % hero_state
		elif not selected_exhibit.is_empty():
			var entry := placeholder_for(selected_exhibit)
			_title.text = str(entry.get("label","Reserved bay")).to_upper()
			_status.text = str(entry.get("description",""))
		else:
			_title.text = Species.NAMES[selected_kind].replace("_"," ").to_upper()
			var specimen := specimen_for(selected_kind)
			_status.text = NOTES[selected_kind]+"\n\n16 species · Shared voxel light\n1-hour lifetime · Debug"+ (" · Feeding" if specimen.get("feeding",false) else "")
		if selected_exhibit.is_empty():
			if not controllers.is_empty() and controllers[0].blender_visuals != null and controllers[0].blender_visuals.assets.templates.has(selected_kind):
				_status.text += "\nBlender anatomy" + [" · Intact", " · Neutral geometry", " · DIAGNOSTIC CUTAWAY"][blender_review_mode]
			elif not blender_failures.is_empty():
				_status.text += "\nBlender unavailable: " + blender_failures[0]
		if _pulse_button != null: _pulse_button.disabled = not selected_exhibit in ["organelle","hero"] and not selected_exhibit.is_empty()
		if _food_button != null: _food_button.disabled = not selected_exhibit in ["organelle","hero"] and not selected_exhibit.is_empty()

func _focus_position() -> Vector3:
	if selected_exhibit == "hero" and hero != null: return hero.tip_world()
	if selected_exhibit in ["organelle","hero"] and organelle != null: return organelle.focus_position()
	if stations.has(selected_exhibit): return stations[selected_exhibit].global_position
	var specimen := specimen_for(selected_kind)
	if not specimen.is_empty() and selected_kind == Species.Kind.LACRYMARIA:
		return specimen.pos+specimen.fwd*float(specimen.morph.length)*2.7
	return specimen.pos if not specimen.is_empty() else to_global(Vector3(0,1,0))

func _update_camera() -> void:
	if camera == null: return
	if _overview:
		camera.fov = 50.0
		camera.global_position = overview_station.global_position
		camera.look_at(to_global(Vector3(0,BENCH_Y,HALL_CENTER_Z)))
	else:
		camera.fov = 40.0
		var focus := _focus_position()
		var offset := Vector3(sin(_orbit.x)*cos(_orbit.y),sin(_orbit.y),cos(_orbit.x)*cos(_orbit.y))*_distance
		camera.global_position = focus+offset
		camera.look_at(focus,Vector3.UP)
	# Center the specimen in the usable view beside the controls. Moving the
	# actual camera keeps its child lamp at the rendered inspection viewpoint.
	var view_height := maxf(1,get_viewport().get_visible_rect().size.y)
	var distance := camera.global_position.distance_to(to_global(Vector3(0,BENCH_Y,HALL_CENTER_Z))) if _overview else _distance
	camera.global_position -= camera.global_basis.x*distance*tan(deg_to_rad(camera.fov*0.5))*376.0/view_height
	# Framing shifts the camera sideways to leave space for the control panel.
	# Aim its lamp at the specimen after that shift, so the real RG8 cone and
	# visible spotlight both illuminate the inspection target.
	if lamp != null and not _overview: lamp.look_at(_focus_position(),Vector3.UP)
	elif lamp != null: lamp.rotation = Vector3.ZERO

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
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.055,0.065,0.08,1.0)
	panel.add_theme_stylebox_override("panel",background)
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
	_title.custom_minimum_size.x = 335
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_title)
	_status = Label.new()
	_status.custom_minimum_size = Vector2(335,115)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)
	var actions := GridContainer.new()
	actions.columns = 2
	column.add_child(actions)
	_lamp_button = _button(actions,"Lamp: ON",func():set_lamp_enabled(not lamp_enabled))
	_pause_button = _button(actions,"Pause",func():set_simulation_paused(not simulation_paused))
	_pause_button.tooltip_text = "Pause controller and lifecycle clocks; shader micro-motion continues."
	_pulse_button = _button(actions,"Pulse / touch",stimulate_selected)
	_food_button = _button(actions,"Food residue",feed_selected)
	_button(actions,"Reset display",reset_specimens)
	_button(actions,"Overview",func():
		_overview=true
		_set_blender_inspection_kind(-1))
	_button(actions,"Leave camera",func():activate(false))
	var review := OptionButton.new()
	review.add_item("Blender: intact material")
	review.add_item("Blender: neutral geometry")
	review.add_item("Blender: diagnostic cutaway")
	review.tooltip_text = "Applies to rebuilt specimens. Cutaway removes half the skin to inspect enclosed organs."
	review.item_selected.connect(set_blender_review_mode)
	column.add_child(review)
	var selector := OptionButton.new()
	selector.add_item("Researched organisms")
	selector.add_item("Original critters")
	selector.add_item("Organelle & reserved zoo")
	selector.selected = 2
	column.add_child(selector)
	var grids: Array[GridContainer] = []
	for group in 3:
		var grid := GridContainer.new()
		grid.columns = 2
		grid.visible = group == 2
		column.add_child(grid)
		grids.append(grid)
	# Inspection order matches the owner's researched-first Blender queue.
	for kind in [3,6,5,11,4,8,7,10,9,12,13,14,15,0,1,2]:
		_button(grids[0 if kind >= 3 else 1],Species.NAMES[kind].replace("_"," "),focus_species.bind(kind))
	_button(grids[2],"Hero & organelles",focus_organelle)
	_button(grids[2],"Hero close-up",focus_hero)
	for entry in placeholders:
		var button := _button(grids[2],str(entry.label),focus_placeholder.bind(str(entry.id)))
		button.tooltip_text = str(entry.description)
	selector.item_selected.connect(func(index: int):
		for group in grids.size(): grids[group].visible = group == index)
	var help := Label.new()
	help.text = "Right-drag: orbit · wheel: zoom\nPulse / touch: debug stimulus\nReset keeps light history · F1: leave camera"
	column.add_child(help)

func _button(parent: Node, caption: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.clip_text = true
	button.custom_minimum_size = Vector2(162,34)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.tooltip_text = caption
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

func _label(caption: String, at: Vector3, billboard := false) -> Label3D:
	var label := Label3D.new()
	label.text = caption
	if billboard: label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = at
	label.width = 640.0
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.font_size = 46
	label.pixel_size = 0.005
	label.modulate = Color(0.82,0.9,1.0)
	add_child(label)
	return label

func stats() -> Dictionary:
	return {"species":_roster.critters.size(),"controllers":controllers.size(),"voxel_fields":1 if exposure!=null else 0,
		"voxel_textures":1 if exposure_texture!=null else 0,"placeholder_bays":placeholders.size(),
		"organelle":organelle.stats() if organelle != null else {},"uploads":upload_count,"paused":simulation_paused,"active":active}

func _exit_tree() -> void:
	if active: activate(false)
	if is_instance_valid(voxel_binding): voxel_binding.clear()
	if _roster != null: _roster.batches.clear()
	exposure_texture = null
	exposure = null
