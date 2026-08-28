class_name OrisonV2ReadabilityCues
extends Node3D
## Development-only architectural legibility cues for the integrated slice.
## All geometry is non-colliding and deliberately schematic.

const PUBLIC := Color(0.18, 0.48, 0.72)
const UNIT_2A := Color(0.18, 0.58, 0.42)
const UNIT_4B := Color(0.72, 0.38, 0.16)
const WARM := Color(1.0, 0.72, 0.38)

func _ready() -> void:
	_portal(Vector3(0, 0, -11.65), 0.0, 1.1, 2.13, PUBLIC, "PUBLIC ENTRANCE")
	_portal(Vector3(-5.6, 3.2, 0), PI * 0.5, 0.91, 2.13, UNIT_2A, "2A")
	_portal(Vector3(-5.6, 9.6, 0), PI * 0.5, 0.91, 2.13, UNIT_4B, "4B")
	_floor_plate(Vector3(-1.25, 3.2, -3.30), "F02", PUBLIC)
	_floor_plate(Vector3(-1.25, 9.6, -3.30), "F04", PUBLIC)
	# Repeated light pools expose the first flight, turn, return flight and arrival.
	for base_y in [0.0, 3.2, 6.4]:
		_light(Vector3(2.3, base_y + 1.25, -1.7), PUBLIC, 4.8, 2.0)
		_light(Vector3(3.05, base_y + 2.25, 1.15), WARM, 4.2, 1.7)
		_light(Vector3(3.8, base_y + 2.75, -1.0), PUBLIC, 4.8, 1.8)
	# Low, durable floor bands point from lobby/landings to the intended thresholds.
	_band(Vector3(1.1, 0.012, -3.35), Vector3(2.2, 0.024, 0.16), PUBLIC)
	_band(Vector3(-3.55, 3.212, 0), Vector3(3.7, 0.024, 0.16), UNIT_2A)
	_band(Vector3(-3.55, 9.612, 0), Vector3(3.7, 0.024, 0.16), UNIT_4B)
	_band(Vector3(-11.55, 9.612, 5.1), Vector3(0.16, 0.024, 7.0), UNIT_4B)
	_terminal_mass()
	_bed_mass()
	_light(Vector3(0, 2.25, -10.2), WARM, 6.0, 2.2)
	_light(Vector3(1.8, 2.2, -3.0), PUBLIC, 6.0, 2.0)
	_light(Vector3(-5.6, 5.15, 0), UNIT_2A, 4.0, 1.4)
	_light(Vector3(-5.6, 11.55, 0), UNIT_4B, 4.0, 1.4)
	_light(Vector3(-9.05, 11.0, 1.25), WARM, 3.8, 1.25)
	_light(Vector3(-13.1, 11.0, 8.9), WARM, 4.0, 1.15)

func _portal(at: Vector3, yaw: float, width: float, height: float,
		color: Color, words: String) -> void:
	var portal := Node3D.new()
	portal.name = words.replace(" ", "_")
	portal.position = at
	portal.rotation.y = yaw
	add_child(portal)
	_box(portal, Vector3(0.09, height, 0.12), Vector3(-width * 0.5 - 0.045, height * 0.5, 0), color)
	_box(portal, Vector3(0.09, height, 0.12), Vector3(width * 0.5 + 0.045, height * 0.5, 0), color)
	_box(portal, Vector3(width + 0.18, 0.16, 0.16), Vector3(0, height + 0.08, 0), color)
	var plate := Label3D.new()
	plate.text = words
	plate.font_size = 64
	plate.pixel_size = 0.0022 if words.length() < 4 else 0.00105
	plate.modulate = Color(0.96, 0.94, 0.82)
	plate.outline_modulate = Color(0.02, 0.025, 0.03)
	plate.outline_size = 8
	plate.double_sided = true
	plate.position = Vector3(0, height + 0.09, 0.09)
	portal.add_child(plate)

func _floor_plate(at: Vector3, words: String, color: Color) -> void:
	var plate := Label3D.new()
	plate.text = words
	plate.font_size = 96
	plate.pixel_size = 0.0022
	plate.modulate = color.lightened(0.35)
	plate.outline_modulate = Color(0.02, 0.025, 0.03)
	plate.outline_size = 10
	plate.position = at + Vector3(0, 1.45, 0)
	add_child(plate)

func _terminal_mass() -> void:
	var home := Node3D.new()
	home.name = "TerminalHomeContext"
	home.position = Vector3(-9.05, 9.6, 1.25)
	add_child(home)
	_box(home, Vector3(0.58, 0.76, 1.25), Vector3(0, 0.38, 0), Color(0.28, 0.19, 0.10))
	_box(home, Vector3(0.035, 0.34, 0.58), Vector3(0.31, 0.48, 0), Color(0.12, 0.58, 0.42))
	_box(home, Vector3(1.3, 0.08, 0.5), Vector3(-0.70, 0.72, 0), UNIT_4B.darkened(0.3))

func _bed_mass() -> void:
	var bed := Node3D.new()
	bed.name = "BedHomeContext"
	bed.position = Vector3(-13.1, 9.6, 8.9)
	add_child(bed)
	_box(bed, Vector3(2.0, 0.48, 1.25), Vector3(0, 0.24, 0), Color(0.32, 0.40, 0.48))
	_box(bed, Vector3(0.16, 1.0, 1.35), Vector3(-0.92, 0.5, 0), Color(0.23, 0.28, 0.34))

func _band(at: Vector3, size: Vector3, color: Color) -> void:
	_box(self, size, at, color)

func _box(parent: Node3D, size: Vector3, at: Vector3, color: Color) -> void:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.72
	mesh.material = mat
	node.mesh = mesh
	node.position = at
	parent.add_child(node)

func _light(at: Vector3, color: Color, range_m: float, energy: float) -> void:
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = color.lightened(0.35)
	light.light_energy = energy
	light.omni_range = range_m
	light.omni_attenuation = 1.6
	light.shadow_enabled = false
	add_child(light)
