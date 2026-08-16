class_name BuildingEntrySign
extends Node3D
## Exterior bronze-and-enamel identity plaque beside the street entrance.

var _inspection_tap: AudioStreamPlayer3D


func _ready() -> void:
	name = "FrontDoorExteriorSign"
	var plaque := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.90, 0.62, 0.045)
	plaque.mesh = box
	var bronze := StandardMaterial3D.new()
	bronze.albedo_color = Color(0.15, 0.105, 0.055)
	bronze.metallic = 0.72
	bronze.roughness = 0.48
	plaque.material_override = bronze
	add_child(plaque)
	for corner in [
		Vector2(-0.405, -0.265), Vector2(0.405, -0.265),
		Vector2(-0.405, 0.265), Vector2(0.405, 0.265)]:
		var screw := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.014
		cylinder.bottom_radius = 0.014
		cylinder.height = 0.012
		screw.mesh = cylinder
		screw.position = Vector3(corner.x, corner.y, 0.032)
		screw.rotation_degrees.x = 90
		screw.material_override = bronze
		add_child(screw)
	_add_label("THE ORISON", Vector3(0, 0.15, 0.031), 42)
	_add_label("APARTMENT BUILDING", Vector3(0, 0.015, 0.031), 22)
	_add_label("QUEENS, N.Y.  ·  EST. 1928",
			Vector3(0, -0.13, 0.031), 17)
	_add_label("REALTY MAINTENANCE",
			Vector3(0, -0.235, 0.031), 12, Color(0.68, 0.55, 0.32))
	_build_interaction()
	_inspection_tap = AudioStreamPlayer3D.new()
	_inspection_tap.name = "PlaqueTap"
	_inspection_tap.stream = PropAudio.get_stream("tick")
	_inspection_tap.volume_db = -21.0
	_inspection_tap.pitch_scale = 0.82
	_inspection_tap.unit_size = 2.5
	_inspection_tap.max_distance = 16.0
	add_child(_inspection_tap)


## The plaque remains distinct from the adjacent entrance-door verb.  Its
## interaction plane is only as large as the bronze assembly and sits proud of
## the face, so opening the door cannot accidentally become inspecting text.
func _build_interaction() -> void:
	var area := Area3D.new()
	area.name = "BuildingPlaqueInspection"
	area.collision_layer = 1
	area.collision_mask = 0
	area.monitoring = false
	area.monitorable = true
	area.add_to_group("functional_interaction_areas")
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.94, 0.66, 0.18)
	collision.shape = shape
	collision.position = Vector3(0.0, 0.0, 0.10)
	area.add_child(collision)
	add_child(area)


func interact_prompt() -> String:
	return "[E]  Inspect Orison entrance plaque"


func interact(_player: Node) -> Dictionary:
	if _inspection_tap:
		_inspection_tap.play()
	return service_wire_card()


func service_wire_card() -> Dictionary:
	return PropServiceWire.card("building_plaque", {
		"face_state": "THE ORISON / BRONZE AND ENAMEL / EST. 1928",
		"fastener_state": "FOUR BRONZE SCREWS SEATED",
		"entrance_state": "RESIDENT ENTRY / REALTY MAINTENANCE",
	})


func _add_label(value: String, at: Vector3, size: int,
		color := Color(0.88, 0.78, 0.52)) -> void:
	var label := Label3D.new()
	label.text = value
	label.font_size = size
	label.modulate = color
	label.outline_size = 2
	label.outline_modulate = Color(0.035, 0.025, 0.015, 0.9)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = at
	label.pixel_size = 0.00155
	label.no_depth_test = false
	add_child(label)
