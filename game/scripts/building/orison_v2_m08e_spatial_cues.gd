class_name OrisonV2M08ESpatialCues
extends OrisonV2ReadabilityCues
## Development-only architectural light, threshold, and floor cues for M08E.

const SERVICE := Color(0.78, 0.50, 0.16)
const HOME_2B := Color(0.30, 0.58, 0.48)

func _ready() -> void:
	super()
	_portal(Vector3(-3.3, 0.0, -3.85), 0.0, 2.0, 2.35,
			SERVICE, "WATCH STATION")
	_portal(Vector3(9.5, 3.2, -3.25), PI * 0.5, 0.91, 2.13,
			HOME_2B, "2B")
	_portal(Vector3(9.5, -3.2, -0.4), PI * 0.5, 0.91, 2.13,
			SERVICE, "BOILER ROOM")
	_floor_plate(Vector3(5.8, -3.2, -0.95), "B1", SERVICE)
	_band(Vector3(-3.3, 0.012, -4.2), Vector3(2.0, 0.024, 0.16), SERVICE)
	_band(Vector3(7.45, 3.212, -3.25), Vector3(4.1, 0.024, 0.16), HOME_2B)
	_band(Vector3(7.45, -3.188, -0.4), Vector3(4.1, 0.024, 0.16), SERVICE)
	_build_ritual_instruments()
	_build_boiler_machine()
	_build_2b_home_cues()
	_light(Vector3(-3.3, 2.35, -2.1), SERVICE, 5.5, 3.6)
	_light(Vector3(-4.7, 1.85, -0.9), Color(0.72, 0.25, 0.12), 3.8, 2.2)
	_light(Vector3(-2.0, 1.85, -3.0), Color(0.88, 0.70, 0.38), 3.5, 2.4)
	_light(Vector3(10.0, 5.25, -3.0), HOME_2B, 5.0, 1.8)
	_light(Vector3(13.2, 5.35, -5.0), HOME_2B, 7.0, 1.6)
	_light(Vector3(7.4, -1.0, -0.4), SERVICE, 5.5, 2.0)
	_light(Vector3(12.4, -0.45, -0.5), SERVICE, 8.0, 4.0)
	_light(Vector3(10.6, -1.0, -2.6), Color(0.55, 0.68, 0.78), 6.0, 2.5)
	_light(Vector3(14.4, 5.15, -3.0), HOME_2B, 4.5, 2.4)
	_light(Vector3(4.9, -0.75, -1.1), Color(0.52, 0.66, 0.78), 5.5, 3.0)
	_light(Vector3(8.2, -1.05, -0.4), SERVICE, 5.0, 3.0)
	_light(Vector3(13.0, -0.55, -0.5), Color(0.95, 0.54, 0.22), 6.0, 4.8)
	_light(Vector3(12.3, 5.1, -6.5), Color(0.78, 0.68, 0.48), 6.5, 2.8)
	_light(Vector3(11.2, 5.0, -10.6), Color(0.48, 0.62, 0.72), 5.0, 2.2)

func _build_ritual_instruments() -> void:
	var detector := Node3D.new()
	detector.name = "WatchmanDetectorSilhouette"
	detector.position = Vector3(-2.0, 0.0, -3.1)
	add_child(detector)
	_box(detector, Vector3(0.48, 0.82, 0.22), Vector3(0, 1.02, 0), Color(0.18, 0.15, 0.11))
	_cylinder(detector, 0.19, 0.06, Vector3(0, 1.12, -0.14), Color(0.88, 0.72, 0.38), Vector3(90, 0, 0))
	_box(detector, Vector3(0.12, 0.28, 0.12), Vector3(0, 0.52, 0), Color(0.42, 0.28, 0.13))
	_instrument_plate(detector, "CLOCK", Vector3(0, 1.52, -0.14), 0.0014)

	var ledger := Node3D.new()
	ledger.name = "NightRegisterSilhouette"
	ledger.position = Vector3(-3.25, 0.0, -0.08)
	add_child(ledger)
	_box(ledger, Vector3(1.05, 0.10, 0.62), Vector3(0, 0.84, 0), Color(0.24, 0.13, 0.08))
	_box(ledger, Vector3(0.92, 0.035, 0.52), Vector3(0, 0.91, -0.02), Color(0.86, 0.80, 0.64))
	_box(ledger, Vector3(0.025, 0.04, 0.48), Vector3(0, 0.935, -0.02), Color(0.38, 0.16, 0.10))
	_instrument_plate(ledger, "NIGHT LOG", Vector3(0, 1.16, -0.02), 0.0012)

	var signals := Node3D.new()
	signals.name = "SignalRegisterSilhouette"
	signals.position = Vector3(-5.0, 0.0, -0.6)
	add_child(signals)
	_box(signals, Vector3(0.18, 0.92, 0.86), Vector3(0, 1.18, 0), Color(0.10, 0.16, 0.17))
	for row in 2:
		for col in 3:
			_sphere(signals, 0.065, Vector3(-0.12, 1.40 - row * 0.30, -0.25 + col * 0.25),
					Color(0.85, 0.22 + row * 0.30, 0.10 + col * 0.15))
	_instrument_plate(signals, "SIGNALS", Vector3(-0.14, 1.82, 0), 0.0012, Vector3(0, 90, 0))

	var keys := Node3D.new()
	keys.name = "TourKeyGuardSilhouette"
	keys.position = Vector3(-5.0, 0.0, -1.75)
	add_child(keys)
	_box(keys, Vector3(0.18, 1.0, 0.92), Vector3(0, 1.18, 0), Color(0.20, 0.14, 0.09))
	for i in 4:
		_box(keys, Vector3(0.13, 0.035, 0.035), Vector3(-0.13, 1.48 - i * 0.22, -0.27), Color(0.82, 0.62, 0.25))
		_box(keys, Vector3(0.035, 0.18, 0.035), Vector3(-0.19, 1.39 - i * 0.22, -0.27), Color(0.82, 0.62, 0.25))
	_instrument_plate(keys, "TOUR KEYS", Vector3(-0.14, 1.83, 0), 0.0011, Vector3(0, 90, 0))

func _build_boiler_machine() -> void:
	var machine := Node3D.new()
	machine.name = "BoilerMachineSilhouette"
	add_child(machine)
	_cylinder(machine, 1.12, 2.55, Vector3(13.05, -1.95, -0.5), Color(0.22, 0.31, 0.34), Vector3(0, 0, 90))
	_box(machine, Vector3(1.3, 1.05, 1.65), Vector3(11.85, -2.55, -0.5), Color(0.20, 0.16, 0.12))
	_cylinder(machine, 0.42, 0.10, Vector3(11.16, -2.50, -0.5), Color(0.65, 0.25, 0.10), Vector3(0, 0, 90))
	_cylinder(machine, 0.12, 0.08, Vector3(11.42, -1.15, -0.5), Color(0.88, 0.78, 0.52), Vector3(0, 0, 90))
	_box(machine, Vector3(0.12, 1.65, 0.18), Vector3(11.48, -1.85, -0.05), Color(0.18, 0.66, 0.72))
	_box(machine, Vector3(0.26, 0.16, 0.52), Vector3(11.42, -1.02, -0.28), Color(0.46, 0.34, 0.18))
	_cylinder(machine, 0.24, 2.5, Vector3(14.0, -0.55, -0.5), Color(0.27, 0.38, 0.40), Vector3(0, 0, 0))
	_cylinder(machine, 0.22, 2.8, Vector3(14.7, -1.55, 1.55), Color(0.24, 0.33, 0.35), Vector3(90, 0, 0))
	for x in [12.2, 13.7]:
		_box(machine, Vector3(0.22, 0.75, 0.22), Vector3(x, -3.0, -0.5), Color(0.12, 0.13, 0.14))

func _build_2b_home_cues() -> void:
	var home := Node3D.new()
	home.name = "Apartment2BReadableMasses"
	add_child(home)
	# Bed with mattress, headboard, and pillow.
	_box(home, Vector3(1.45, 0.50, 2.05), Vector3(10.9, 3.45, -10.9), Color(0.28, 0.40, 0.50))
	_box(home, Vector3(1.55, 0.88, 0.12), Vector3(10.9, 3.64, -11.92), Color(0.20, 0.25, 0.29))
	_box(home, Vector3(0.62, 0.16, 0.42), Vector3(10.9, 3.78, -11.42), Color(0.78, 0.75, 0.65))
	# Folding work table and fabric rolls.
	_box(home, Vector3(2.45, 0.10, 0.82), Vector3(13.1, 4.0, -0.35), Color(0.45, 0.25, 0.13))
	for x in [12.2, 14.0]:
		_box(home, Vector3(0.10, 0.75, 0.10), Vector3(x, 3.58, -0.35), Color(0.25, 0.18, 0.12))
	for i in 4:
		_cylinder(home, 0.14, 2.6, Vector3(15.05, 4.15, -5.55 - i * 0.72),
				Color(0.34 + i * 0.08, 0.25, 0.46 - i * 0.05), Vector3(90, 0, 0))
	# Kitchen counter, upper cabinets, and sink marker.
	_box(home, Vector3(0.68, 0.92, 3.1), Vector3(10.08, 3.66, -6.4), Color(0.30, 0.34, 0.29))
	_box(home, Vector3(0.42, 0.78, 2.65), Vector3(9.78, 5.0, -6.4), Color(0.40, 0.38, 0.29))
	_box(home, Vector3(0.70, 0.035, 0.58), Vector3(10.12, 4.15, -5.8), Color(0.64, 0.72, 0.72))
	# Radiator fins and bath-threshold value cue.
	for i in 6:
		_box(home, Vector3(0.10, 0.92, 0.13), Vector3(15.38, 3.72, -3.48 + i * 0.19), Color(0.52, 0.66, 0.68))
	_box(home, Vector3(0.10, 2.2, 0.14), Vector3(14.2, 4.30, -9.35), Color(0.45, 0.72, 0.74))

func _cylinder(parent: Node3D, radius: float, height: float, at: Vector3,
		color: Color, rotation_degrees: Vector3) -> void:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 20
	mesh.material = _material(color)
	node.mesh = mesh
	node.position = at
	node.rotation_degrees = rotation_degrees
	parent.add_child(node)

func _sphere(parent: Node3D, radius: float, at: Vector3, color: Color) -> void:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.material = _material(color)
	node.mesh = mesh
	node.position = at
	parent.add_child(node)

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.68
	return material

func _instrument_plate(parent: Node3D, words: String, at: Vector3,
		pixel_size: float, rotation := Vector3.ZERO) -> void:
	var plate := Label3D.new()
	plate.text = words
	plate.font_size = 56
	plate.pixel_size = pixel_size
	plate.modulate = Color(0.92, 0.78, 0.48)
	plate.outline_modulate = Color(0.05, 0.04, 0.03)
	plate.outline_size = 8
	plate.position = at
	plate.rotation_degrees = rotation
	parent.add_child(plate)
