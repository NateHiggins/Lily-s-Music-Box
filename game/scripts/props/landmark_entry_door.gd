class_name LandmarkEntryDoor
extends DoorProp
## The Orison's face. Original 1928 oak and glass, repaired for a century by
## people who respected its authority more than its finish.

const HERO_ALBEDO := preload("res://assets/building/textures/signage/orison_century_entry_door_albedo_v1.png")

var _oak: StandardMaterial3D
var _oak_dark: StandardMaterial3D
var _brass: StandardMaterial3D
var _iron: StandardMaterial3D
var _glass: StandardMaterial3D


func _ready() -> void:
	name = "F01_DOOR_06"
	add_to_group("building_entry")
	_build_materials()
	_build_frame_and_transom()
	_build_leaf()
	_build_audio()
	apply_hinge_setback()


func _build_materials() -> void:
	_oak = StandardMaterial3D.new()
	_oak.albedo_texture = HERO_ALBEDO
	_oak.albedo_color = Color(0.76, 0.64, 0.56)
	_oak.roughness = 0.62
	_oak.normal_enabled = true
	_oak.normal_scale = 0.32
	_oak_dark = StandardMaterial3D.new()
	_oak_dark.albedo_color = Color(0.085, 0.032, 0.021)
	_oak_dark.roughness = 0.72
	_brass = StandardMaterial3D.new()
	_brass.albedo_color = Color(0.48, 0.30, 0.105)
	_brass.metallic = 0.84
	_brass.roughness = 0.39
	_iron = StandardMaterial3D.new()
	_iron.albedo_color = Color(0.075, 0.070, 0.064)
	_iron.metallic = 0.72
	_iron.roughness = 0.58
	_glass = StandardMaterial3D.new()
	_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glass.albedo_color = Color(0.16, 0.22, 0.20, 0.66)
	_glass.metallic = 0.16
	_glass.roughness = 0.27
	_glass.cull_mode = BaseMaterial3D.CULL_DISABLED


func _build_frame_and_transom() -> void:
	# Deep jamb and battered exterior architrave; the stepped head is the one
	# surviving flourish that makes the entrance readable from across rain.
	_box(self, Vector3(0.10, height + 0.20, 0.15),
			Vector3(-0.055, height * 0.5, 0.0), _oak_dark)
	_box(self, Vector3(0.10, height + 0.20, 0.15),
			Vector3(width + 0.055, height * 0.5, 0.0), _oak_dark)
	_box(self, Vector3(width + 0.21, 0.12, 0.16),
			Vector3(width * 0.5, height + 0.055, 0.0), _oak_dark)
	_box(self, Vector3(width + 0.34, 0.07, 0.19),
			Vector3(width * 0.5, height + 0.145, 0.0), _oak_dark)
	# Transom is intentionally shallow—historic infill retained against a
	# wall opening later reduced from behind. Its wired glass is opaque enough
	# that the cheat survives from street and lobby.
	var transom_y := height + 0.34
	_box(self, Vector3(width + 0.12, 0.43, 0.055),
			Vector3(width * 0.5, transom_y, 0.018), _oak_dark)
	_box(self, Vector3(width - 0.06, 0.28, 0.018),
			Vector3(width * 0.5, transom_y, 0.018), _glass)
	_wire_grid(self, Vector3(width * 0.5, transom_y, 0.032),
			Vector2(width - 0.10, 0.24), 8, 3)
	var title := Label3D.new()
	title.text = "THE ORISON  ·  1928"
	title.font_size = 26
	title.pixel_size = 0.00115
	title.modulate = Color(0.73, 0.50, 0.20)
	title.outline_size = 2
	title.position = Vector3(width * 0.5, height + 0.145, 0.105)
	add_child(title)
	# Bluestone saddle worn hollow at the centre by a century of tenants.
	_box(self, Vector3(width + 0.15, 0.030, 0.24),
			Vector3(width * 0.5, 0.015, 0.0), _iron)
	_box(self, Vector3(width * 0.42, 0.010, 0.27),
			Vector3(width * 0.52, 0.035, -0.015), _brass)


func _build_leaf() -> void:
	_body = AnimatableBody3D.new()
	_body.name = "CenturyOakLeaf"
	_body.sync_to_physics = true
	add_child(_body)
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width - 0.018, height - 0.018, 0.064)
	shape_node.shape = shape
	shape_node.position = Vector3(width * 0.5, height * 0.5, 0)
	_body.add_child(shape_node)
	_box(_body, shape.size, shape_node.position, _oak_dark)
	# Full photoreal face capture, held just proud of the structural slab.
	_door_face(1.0)
	_door_face(-1.0)
	# Rails, stiles and bolection moldings make the generated depth physically
	# real at glancing angles instead of relying on a flat photographic trick.
	for side: float in [-1.0, 1.0]:
		var z: float = side * 0.044
		_box(_body, Vector3(0.105, height - 0.12, 0.035),
				Vector3(0.065, height * 0.5, z), _oak_dark)
		_box(_body, Vector3(0.105, height - 0.12, 0.035),
				Vector3(width - 0.065, height * 0.5, z), _oak_dark)
		for y in [0.12, 0.73, 1.24, height - 0.095]:
			_box(_body, Vector3(width - 0.12, 0.075, 0.035),
					Vector3(width * 0.5, y, z), _oak_dark)
	# Two narrow panes: imperfect wired glass, one cracked but retained.
	for index in 2:
		var cx := width * (0.31 if index == 0 else 0.69)
		for side: float in [-1.0, 1.0]:
			var z: float = side * 0.066
			_box(_body, Vector3(width * 0.27, 0.62, 0.012),
					Vector3(cx, 1.61, z), _glass)
			_wire_grid(_body, Vector3(cx, 1.61, z + side * 0.008),
					Vector2(width * 0.25, 0.59), 4, 8)
	# Crack held by an old brass mending plate: the Dorian Gray detail.
	var crack := _box(_body, Vector3(0.013, 0.46, 0.008),
			Vector3(width * 0.72, 0.50, 0.071), _iron)
	crack.rotation.z = -0.12
	_box(_body, Vector3(0.075, 0.19, 0.012),
			Vector3(width * 0.73, 0.49, 0.078), _brass)
	_build_hardware()
	if leaf_state == "open":
		open = true
		_body.rotation.y = deg_to_rad(-168 if swing_out else 168)


func _door_face(side: float) -> void:
	var face := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(width - 0.035, height - 0.035)
	face.mesh = quad
	face.position = Vector3(width * 0.5, height * 0.5, side * 0.035)
	face.rotation.y = 0.0 if side > 0 else PI
	face.material_override = _oak
	_body.add_child(face)


func _build_hardware() -> void:
	# Exterior escutcheon carries ghosts of two earlier locksets beneath it.
	_box(_body, Vector3(0.12, 0.34, 0.016),
			Vector3(width - 0.115, 0.96, 0.073), _brass)
	for y in [0.875, 1.045]:
		_cylinder(_body, 0.032, 0.028,
				Vector3(width - 0.115, y, 0.088), _brass, 90)
	# Long offset pull, polished only where hands actually land.
	for y in [0.84, 1.22]:
		_cylinder(_body, 0.018, 0.075,
				Vector3(width - 0.19, y, 0.12), _brass, 90)
	var pull := _cylinder(_body, 0.019, 0.38,
			Vector3(width - 0.19, 1.03, 0.16), _brass, 0)
	pull.rotation.z = 0.0
	# Inside retains an ugly 1970s panic bar and a twentieth-century closer.
	_box(_body, Vector3(width - 0.18, 0.055, 0.085),
			Vector3(width * 0.5, 0.94, -0.10), _iron)
	_box(_body, Vector3(0.25, 0.07, 0.08),
			Vector3(width - 0.20, height - 0.12, -0.085), _iron)
	var arm := _box(_body, Vector3(0.36, 0.018, 0.018),
			Vector3(width - 0.35, height - 0.065, -0.095), _iron)
	arm.rotation.z = -0.14
	# Mail slot welded shut after letters began arriving addressed to rooms
	# that do not exist. It remains unmistakably a mail slot.
	_box(_body, Vector3(0.34, 0.105, 0.018),
			Vector3(width * 0.43, 0.68, 0.073), _brass)
	_box(_body, Vector3(0.27, 0.035, 0.022),
			Vector3(width * 0.43, 0.68, 0.087), _iron)
	# Four overbuilt butt hinges, ball-tipped, because an oak-and-glass
	# leaf this heavy was never hung on three.
	for y in [0.26, height * 0.36, height * 0.66, height - 0.26]:
		butt_hinge(_body, y, _brass)
	_entrance_lockset()


## Ornamental research, and the reason this door is the building's face.
##
## A 1926 New York apartment-house entrance was ironmongered from a
## catalogue - Corbin, Sargent, Russwin - and the pattern that turns up
## again and again on buildings of exactly this class is a long cast
## escutcheon carrying a knob above a covered keyhole, with a thumbpiece
## latch for the hand that is already full. The ornament is late
## Beaux-Arts sliding into Deco: a stepped border, a beaded rose, and an
## octagonal faceted knob rather than a plain sphere, because faceting is
## what catches a streetlight at a glancing angle.
##
## All of it is bronze that nobody has polished since the sixties, except
## the two places a century of hands actually land: the knob's crown and
## the thumbpiece.
func _entrance_lockset() -> void:
	var worn := StandardMaterial3D.new()
	worn.albedo_color = Color(0.66, 0.47, 0.20)
	worn.metallic = 0.92
	worn.roughness = 0.22

	for face in [1.0, -1.0]:
		var z0: float = 0.073 * face
		var kx: float = width - 0.115
		# stepped Deco border on the escutcheon: three receding frames
		for i in 3:
			var inset: float = 0.012 * i
			_box(_body, Vector3(0.116 - inset * 2.0, 0.334 - inset * 2.0,
					0.004), Vector3(kx, 0.96, z0 + 0.008 + 0.004 * i),
					_brass)
		# beaded rose behind the knob
		_cylinder(_body, 0.040, 0.010, Vector3(kx, 1.045, z0 + 0.022),
				_brass, 90)
		for b in 10:
			var a: float = TAU * b / 10.0
			_cylinder(_body, 0.006, 0.008,
					Vector3(kx + cos(a) * 0.040, 1.045 + sin(a) * 0.040,
							z0 + 0.026), _brass, 90)
		# shank, collar, and the faceted knob itself
		_cylinder(_body, 0.014, 0.030, Vector3(kx, 1.045, z0 + 0.040),
				_brass, 90)
		_cylinder(_body, 0.023, 0.010, Vector3(kx, 1.045, z0 + 0.056),
				_brass, 90)
		var knob := MeshInstance3D.new()
		var km := SphereMesh.new()
		km.radius = 0.034
		km.height = 0.060
		km.radial_segments = 8      # octagonal facets, not a ball
		km.rings = 4
		knob.mesh = km
		knob.material_override = worn
		knob.position = Vector3(kx, 1.045, z0 + 0.086 * face / absf(face))
		knob.position.z = z0 + 0.086 * (1.0 if face > 0.0 else -1.0)
		_body.add_child(knob)
		# thumbpiece: the lever that lifts the latch bar, worn bright
		var thumb := _box(_body, Vector3(0.030, 0.052, 0.010),
				Vector3(kx, 1.132, z0 + 0.034), worn)
		thumb.rotation.x = -0.34
		# keyhole below, under a pivoting cover hanging slightly askew
		_cylinder(_body, 0.019, 0.006, Vector3(kx, 0.862, z0 + 0.020),
				_brass, 90)
		_box(_body, Vector3(0.010, 0.020, 0.004),
				Vector3(kx, 0.856, z0 + 0.024), _iron)
		var cover := _box(_body, Vector3(0.030, 0.036, 0.004),
				Vector3(kx + 0.006, 0.872, z0 + 0.028), _brass)
		cover.rotation.z = 0.28 if face > 0.0 else -0.28
		_cylinder(_body, 0.005, 0.008, Vector3(kx, 0.888, z0 + 0.030),
				_brass, 90)

	# The bell push lives on the jamb, not the leaf: a brass rosette with a
	# bakelite button worn pale in the middle.
	var bell_x := width + 0.105
	_cylinder(self, 0.034, 0.012, Vector3(bell_x, 1.16, 0.086), _brass, 90)
	for b in 8:
		var a2: float = TAU * b / 8.0
		_cylinder(self, 0.005, 0.007,
				Vector3(bell_x + cos(a2) * 0.034, 1.16 + sin(a2) * 0.034,
						0.090), _brass, 90)
	var button := StandardMaterial3D.new()
	button.albedo_color = Color(0.19, 0.14, 0.11)
	button.roughness = 0.34
	_cylinder(self, 0.014, 0.010, Vector3(bell_x, 1.16, 0.096), button, 90)


func _wire_grid(parent: Node3D, center: Vector3, size: Vector2,
		columns: int, rows: int) -> void:
	for column in range(1, columns):
		var x := center.x - size.x * 0.5 + size.x * column / columns
		_box(parent, Vector3(0.0035, size.y, 0.0035),
				Vector3(x, center.y, center.z), _iron)
	for row in range(1, rows):
		var y := center.y - size.y * 0.5 + size.y * row / rows
		_box(parent, Vector3(size.x, 0.0035, 0.0035),
				Vector3(center.x, y, center.z), _iron)


func _build_audio() -> void:
	_click = AudioStreamPlayer3D.new()
	_click.stream = PropAudio.get_stream("thud")
	_click.volume_db = -14.0
	_click.unit_size = 2.8
	_click.max_distance = 18.0
	add_child(_click)
	_squeak = AudioStreamPlayer3D.new()
	_squeak.stream = PropAudio.get_stream("door_squeak")
	_squeak.volume_db = -15.5
	_squeak.pitch_scale = 0.76
	_squeak.unit_size = 3.0
	_squeak.max_distance = 20.0
	add_child(_squeak)


func _box(parent: Node3D, size: Vector3, at: Vector3,
		material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = at
	node.material_override = material
	parent.add_child(node)
	return node


func _cylinder(parent: Node3D, radius: float, length: float, at: Vector3,
		material: Material, x_rotation: float) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = 16
	node.mesh = mesh
	node.position = at
	node.rotation_degrees.x = x_rotation
	node.material_override = material
	parent.add_child(node)
	return node
