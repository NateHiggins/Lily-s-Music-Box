extends Node3D
## The retained western weather boundary and eastern expansion dogleg share
## the same normalized front-door frame as the street and Passage.
const Detail := preload("res://scripts/building/exterior_detail_pass.gd")
const SOURCE := "res://data/orison_v2/exterior/construction_shed.json"
var detail: ExteriorDetailPass

static func valid_source_header(source: Variant) -> bool:
	if source is not Dictionary: return false
	var version: Variant = source.get("schema_version")
	return typeof(version) in [TYPE_INT, TYPE_FLOAT] and float(version) == 1.0 \
			and source.get("frame") == "ORISON_FRONT_DOOR_THRESHOLD" \
			and source.get("boxes") is Array and source.get("lights") is Array

func _ready() -> void:
	var source: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	if not valid_source_header(source):
		push_error("Street boundaries require the supported front-door source frame")
		return
	var section := preload("res://scripts/building/orison_v2_street_frame.gd").load_default()
	if section.is_empty():
		push_error("Invalid street coordinate frame")
		return
	detail = Detail.new()
	detail.name = "RetainedStreetEnds"
	detail.position.z = -float(section.source_threshold_z)
	add_child(detail)
	detail.build_boundaries_only(detail, true)
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
		if record.id == "ShedTemporaryClosure":
			_mount_closure_notice(body, mesh.size.z)
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

func _mount_closure_notice(closure: StaticBody3D, depth: float) -> void:
	# Lettering belongs to the collision-bearing panel, including relocation
	# and rotation. Keep the existing 45 mm clearance from its front face.
	var notice := Label3D.new()
	notice.name = "ContractorClosureNotice"
	notice.text = "SIDEWALK CLOSED\nWORK IN PROGRESS"
	notice.position = Vector3(0, 0.35, depth * 0.5 + 0.045)
	notice.font_size = 40
	notice.pixel_size = 0.0015
	notice.modulate = Color(0.1, 0.08, 0.05)
	notice.outline_size = 0
	notice.no_depth_test = false
	closure.add_child(notice)
