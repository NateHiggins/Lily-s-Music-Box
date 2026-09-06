extends Node3D
## The retained western weather boundary and eastern expansion dogleg share
## the same normalized front-door frame as the street and Passage.
const Detail := preload("res://scripts/building/exterior_detail_pass.gd")
const SOURCE := "res://data/orison_v2/exterior/construction_shed.json"
var detail: ExteriorDetailPass

func _ready() -> void:
	var section: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
			"res://data/orison_v2/exterior/street_section_source.json"))
	detail = Detail.new()
	detail.name = "RetainedStreetEnds"
	detail.position.z = -float(section.source_threshold_z)
	add_child(detail)
	detail.build_boundaries_only(detail, true)
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	for record: Dictionary in source.boxes:
		var body := StaticBody3D.new()
		body.name = record.id
		body.position = Vector3(record.center[0], record.center[1], record.center[2])
		body.rotation_degrees.z = float(record.get("roll_degrees", 0.0))
		var mesh := BoxMesh.new()
		mesh.size = Vector3(record.size[0], record.size[1], record.size[2])
		var draw := MeshInstance3D.new()
		draw.mesh = mesh
		draw.material_override = MatLib.get_mat(record.material)
		body.add_child(draw)
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = mesh.size
		collision.shape = shape
		body.add_child(collision)
		add_child(body)
	for record: Dictionary in source.lights:
		var light := LightFixtureProp.new()
		light.prop_type = "cage_bulb"
		light.name = record.id
		light.position = Vector3(record.center[0], record.center[1], record.center[2])
		light.range_clamp = 5.0
		light.energy_scale = 0.65
		light.navigation_light = true
		light.standby_scale = 0.35
		add_child(light)
	var notice := Label3D.new()
	notice.name = "ContractorClosureNotice"
	notice.text = "SIDEWALK CLOSED\nWORK IN PROGRESS"
	notice.position = Vector3(24, 1.65, -2.955)
	notice.font_size = 40
	notice.pixel_size = 0.0015
	notice.modulate = Color(0.1, 0.08, 0.05)
	notice.outline_size = 0
	notice.no_depth_test = false
	add_child(notice)
