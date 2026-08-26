class_name DoorProp
extends Node3D
## A 1928 reopening-era leaf hung in the Orison's older openings.  These are
## deliberately plain Node3D actors, not FunctionalProps: a hinge can be used
## by residents and the player without becoming one hundred and twenty new
## subscribers to the building's possession network.
##
## The subtype is layout data, never inferred from width or lock state.  The
## old leaf made every wide door an apartment entry and every locked door
## galvanized; a deadbolt is not a material specification.

var width := 0.81
var height := 2.03
var leaf_state := "closed"  # closed | open | locked
var swing_out := false
var door_kind := "apartment_interior"
var unit := ""
var finish_variant := 0

const HINGE_SETBACK := 0.026

var open := false
var _hinge_offset := 0.0
var _body: AnimatableBody3D
var _fixed: Node3D
# Reserved for the LandmarkEntryDoor override. Ordinary leaves leave both null.
var _click: AudioStreamPlayer3D
var _squeak: AudioStreamPlayer3D
var _moving := false


func warehouse_variants() -> Array[Dictionary]:
	return [
		{"label": "1928 apartment entry", "properties": {
			"door_kind": "apartment_entry", "width": 0.91, "height": 2.13,
			"unit": "2A"}},
		{"label": "1928 apartment interior", "properties": {
			"door_kind": "apartment_interior", "width": 0.81, "height": 2.03}},
		{"label": "service leaf", "properties": {
			"door_kind": "service", "width": 0.96, "height": 2.10}},
		{"label": "glazed storefront", "properties": {
			"door_kind": "storefront", "width": 0.95, "height": 2.10}},
		{"label": "exterior service", "properties": {
			"door_kind": "exterior_service", "width": 0.90, "height": 2.10}},
		{"label": "cabinet leaf", "properties": {
			"door_kind": "cabinet", "width": 0.55, "height": 0.72}},
	]


func warehouse_rotation_y() -> float:
	return PI


func _ready() -> void:
	if door_kind == "apartment_entry" and unit != "":
		add_to_group("apartment_doors")
	_build_leaf()
	_build_audio()
	if leaf_state == "open":
		open = true
		_body.rotation.y = deg_to_rad(-168.0 if swing_out else 168.0)
	apply_hinge_setback()


## Landmark subclasses may retain a deliberately authored private acoustic
## body. Ordinary leaves use the shared semantic pool and allocate nothing.
func _build_audio() -> void:
	pass


func _build_leaf() -> void:
	_body = AnimatableBody3D.new()
	_body.name = "HingedLeaf"
	_body.sync_to_physics = true
	_hinge_offset = HINGE_SETBACK * (-1.0 if swing_out else 1.0)
	_body.position.z = -_hinge_offset
	add_child(_body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width - 0.02, height - 0.02, 0.044)
	shape.shape = box
	shape.position = Vector3(width * 0.5, height * 0.5, _hinge_offset)
	_body.add_child(shape)
	_fixed = Node3D.new()
	_fixed.name = "FixedIronmongery"
	add_child(_fixed)

	if door_kind == "cabinet" or height < 1.2:
		_build_cabinet()
	elif door_kind == "storefront":
		_build_storefront()
	elif door_kind in ["service", "exterior_service"]:
		_build_service()
	else:
		_build_domestic(door_kind == "apartment_entry")
	if door_kind != "cabinet" and height >= 1.2:
		_build_fixed_hardware()
	StaticMeshBatcher.merge(_body)
	StaticMeshBatcher.merge(_fixed)


## The reopening contractor used one economical two-panel pattern throughout
## the residential work. Entries get darker corridor paint and accumulated
## security hardware; room leaves are the same stock joinery without pretending
## every bedroom needs a closer, peephole and kick plate.
func _build_domestic(is_entry: bool) -> void:
	var palette := [Color(0.38, 0.34, 0.25), Color(0.25, 0.34, 0.29),
		Color(0.35, 0.27, 0.24)] if is_entry else [Color(0.78, 0.75, 0.67),
		Color(0.66, 0.69, 0.61), Color(0.70, 0.63, 0.57)]
	var tint: Color = palette[finish_variant % palette.size()]
	var paint := MatLib.get_mat("trim", tint, 0.85)
	var shadow := MatLib.get_mat("trim", tint.darkened(0.18), 0.85)
	var brass := MatLib.get_mat("brass_dull", Color(0.82, 0.74, 0.55))
	_box(_body, Vector3(width - 0.02, height - 0.02, 0.044),
			Vector3(width * 0.5, height * 0.5, 0), paint)
	# Recesses are shallow dark beds surrounded by physical rails. From a
	# glancing hallway angle the rail casts the line; it is not a rectangle
	# pasted onto a featureless slab.
	for face in [-1.0, 1.0]:
		for field in [[0.18, 0.84], [0.98, height - 0.16]]:
			var cy: float = (field[0] + field[1]) * 0.5
			var fh: float = field[1] - field[0]
			_box(_body, Vector3(width - 0.24, fh, 0.006),
					Vector3(width * 0.5, cy, face * 0.025), shadow)
			for x in [0.095, width - 0.095]:
				_box(_body, Vector3(0.045, fh + 0.045, 0.018),
						Vector3(x, cy, face * 0.031), paint)
			for y in [field[0] - 0.022, field[1] + 0.022]:
				_box(_body, Vector3(width - 0.15, 0.045, 0.018),
						Vector3(width * 0.5, y, face * 0.031), paint)
	_build_knob_set(brass)
	if is_entry:
		# One outer kick plate, polished only in the crescent where shoes land.
		_box(_body, Vector3(width - 0.13, 0.17, 0.008),
				Vector3(width * 0.5, 0.13, -0.029), brass)
		_cyl(_body, 0.014, 0.018, Vector3(width * 0.5, 1.49, -0.034),
				brass, 90)
		var iron := MatLib.get_mat("cast_iron", Color(0.42, 0.40, 0.36))
		_box(_body, Vector3(0.22, 0.055, 0.065),
				Vector3(width - 0.18, height - 0.115, -0.055), iron)
		var arm := _box(_body, Vector3(0.33, 0.018, 0.018),
				Vector3(width - 0.34, height - 0.07, -0.065), iron)
		arm.rotation.z = -0.16


## A SERVICE LEAF MAY BE PAINTED, and one of these two is canonically red.
##
## This built every exterior_service door in galvanized grey and ignored
## `finish_variant` entirely, so the Harukiya's door — specified in the
## evidence ledger as "battered painted **red steel**", with Otomo's
## teal-offset-by-red named as the staircase composition
## (docs/harukiya_reference_notes.md) — has been rendering grey since it
## was built. A canonical element was quietly absent and no test looked,
## because no test asserts a colour. Found by the bar audit, 2026-08-16.
##
## Variant 0 keeps the galvanized finish for the plain service leaf.
## Variant 1 is oxblood-red enamel gone chalky: still obviously steel,
## still battered, never a bright pillarbox.
const SERVICE_FINISHES: Array[Color] = [
	Color(0.48, 0.50, 0.47),        # 0 — galvanized, unpainted
	Color(0.44, 0.13, 0.11),        # 1 — battered red enamel
]


func _build_service() -> void:
	var leaf_tint: Color = SERVICE_FINISHES[
			finish_variant % SERVICE_FINISHES.size()]
	var galvanized := MatLib.get_mat("metal", leaf_tint)
	var iron := MatLib.get_mat("cast_iron", Color(0.36, 0.35, 0.32))
	_box(_body, Vector3(width - 0.02, height - 0.02, 0.052),
			Vector3(width * 0.5, height * 0.5, 0), galvanized)
	# Riveted Z-brace: cheap reinforcement on a hard-used service leaf, not
	# domestic panel moulding recoloured grey.
	for y in [0.16, height - 0.16]:
		_box(_body, Vector3(width - 0.10, 0.065, 0.018),
				Vector3(width * 0.5, y, -0.035), iron)
	var brace := _box(_body, Vector3(width * 0.92, 0.065, 0.018),
			Vector3(width * 0.5, height * 0.51, -0.035), iron)
	brace.rotation.z = atan2(height - 0.40, width - 0.12) - PI * 0.5
	_build_knob_set(MatLib.get_mat("brass_dull", Color(0.64, 0.58, 0.43)))


func _build_storefront() -> void:
	var oak := MatLib.get_mat("oak_quartered", Color(0.42, 0.30, 0.20), 0.8)
	var brass := MatLib.get_mat("brass_dull", Color(0.80, 0.70, 0.47))
	var glass := StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	glass.albedo_color = Color(0.16, 0.22, 0.20, 0.34)
	glass.roughness = 0.18
	glass.metallic = 0.08
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	# A real glazed shop leaf: narrow timber carcass around a transparent field,
	# so the eleven interiors remain the point of building them.
	for x in [0.065, width - 0.065]:
		_box(_body, Vector3(0.13, height - 0.02, 0.055),
				Vector3(x, height * 0.5, 0), oak)
	for y in [0.065, 0.78, height - 0.065]:
		_box(_body, Vector3(width - 0.02, 0.13, 0.055),
				Vector3(width * 0.5, y, 0), oak)
	_box(_body, Vector3(width - 0.19, height - 0.98, 0.012),
			Vector3(width * 0.5, 1.39, 0), glass)
	for face in [-1.0, 1.0]:
		_cyl(_body, 0.014, 0.34, Vector3(width - 0.16, 1.03,
				face * 0.07), brass, 0)
		for y in [0.86, 1.20]:
			_cyl(_body, 0.012, 0.065, Vector3(width - 0.16, y,
					face * 0.045), brass, 90)


func _build_cabinet() -> void:
	var paint := MatLib.get_mat("trim", Color(0.70, 0.68, 0.61), 0.65)
	var brass := MatLib.get_mat("brass_dull", Color(0.70, 0.62, 0.44))
	_box(_body, Vector3(width - 0.015, height - 0.015, 0.032),
			Vector3(width * 0.5, height * 0.5, 0), paint)
	_box(_body, Vector3(width - 0.12, height - 0.12, 0.006),
			Vector3(width * 0.5, height * 0.5, -0.020),
			MatLib.get_mat("trim", Color(0.56, 0.54, 0.48), 0.65))
	_cyl(_body, 0.014, 0.026, Vector3(width - 0.055, height * 0.53,
			-0.030), brass, 90)


func _build_knob_set(material: StandardMaterial3D) -> void:
	for face in [-1.0, 1.0]:
		var z: float = float(face) * 0.038
		_box(_body, Vector3(0.055, 0.17, 0.010),
				Vector3(width - 0.085, 0.94, z), material)
		_cyl(_body, 0.029, 0.048, Vector3(width - 0.085, 1.00,
				face * 0.065), material, 90)
		_box(_body, Vector3(0.012, 0.030, 0.006),
				Vector3(width - 0.085, 0.89, face * 0.045), material)


func _build_fixed_hardware() -> void:
	var metal := MatLib.get_mat("brass_dull", Color(0.58, 0.52, 0.39)) \
			if door_kind in ["apartment_entry", "apartment_interior", "storefront"] \
			else MatLib.get_mat("cast_iron", Color(0.38, 0.37, 0.34))
	# The saddle and jamb-side barrels do not rotate with the leaf. The old
	# model parented both hinge leaves to the door and visibly tore the jamb
	# half away whenever it opened.
	_box(_fixed, Vector3(width + 0.045, 0.004, 0.14),
			Vector3(width * 0.5, 0.002, 0), metal)
	for y in [0.26, height * 0.5, height - 0.26]:
		_cyl(_fixed, 0.010, 0.105, Vector3(0, y, -HINGE_SETBACK),
				metal, 0, 8)


func interact_prompt() -> String:
	if leaf_state == "locked":
		return "[E]  Locked"
	return "[E]  Close door" if open else "[E]  Open door"


func interact(_player: Node) -> void:
	if _moving:
		return
	if leaf_state == "locked":
		_rattle()
		return
	_moving = true
	open = not open
	_play_move()
	var swept := -100.0 if swing_out else 100.0
	var tween := create_tween()
	tween.tween_property(_body, "rotation:y",
			deg_to_rad(swept) if open else 0.0, 0.5).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(_settled)


func npc_set_open(want_open: bool) -> void:
	if leaf_state == "locked" or _moving or open == want_open:
		return
	interact(null)


func _settled() -> void:
	_moving = false
	if not open:
		_play_latch()


func _rattle() -> void:
	var tween := create_tween()
	for i in 3:
		tween.tween_callback(_play_locked)
		tween.tween_interval(0.09)


func _play_move() -> void:
	if _squeak:
		_squeak.play()
	else:
		AudioPolicy.present_3d(&"interaction.door_move", global_position, 1.0,
				StringName(name))


func _play_latch() -> void:
	if _click:
		_click.play()
	else:
		AudioPolicy.present_3d(&"interaction.door_latch", global_position, 1.0,
				StringName(name))


func _play_locked() -> void:
	if _click:
		_click.play()
	else:
		AudioPolicy.present_3d(&"interaction.door_locked", global_position, 1.0,
				StringName(name))


func apply_hinge_setback() -> void:
	if _body == null or is_zero_approx(_hinge_offset):
		return
	for child in _body.get_children():
		if child is MeshInstance3D:
			child.position.z += _hinge_offset


## Compatibility builder for the landmark leaf. Its detailed ball-tipped
## hinge is collapsed with the rest of that hero's brass in _ready().
func butt_hinge(parent: Node3D, at_y: float,
		material: StandardMaterial3D) -> void:
	_cyl(parent, 0.011, 0.105, Vector3(0, at_y, -HINGE_SETBACK),
			material, 0, 10)
	for end in [-1.0, 1.0]:
		_cyl(parent, 0.014, 0.014,
				Vector3(0, at_y + end * 0.059, -HINGE_SETBACK),
				material, 0, 8)


func _box(parent: Node3D, size: Vector3, at: Vector3,
		material: StandardMaterial3D) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = at
	node.material_override = material
	parent.add_child(node)
	return node


func _cyl(parent: Node3D, radius: float, length: float, at: Vector3,
		material: StandardMaterial3D, x_rotation: float,
		segments := 12) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = segments
	node.mesh = mesh
	node.position = at
	node.rotation_degrees.x = x_rotation
	node.material_override = material
	parent.add_child(node)
	return node
