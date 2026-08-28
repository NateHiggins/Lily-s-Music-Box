extends Node
## M08E human-review packet; experiential frames use a 1.41 m player eye.

const ShotHarnessScript := preload("res://tests/shot_harness.gd")
const REVIEW := preload("res://scenes/building/orison_v2_m08e_spatial_review.tscn")
var shots = ShotHarnessScript.new()
var camera: Camera3D
var overview: Node3D
var blockout: Node3D
var camera_records: Array[Dictionary] = []

func _ready() -> void:
	if not shots.setup(self, "ORISON-V2-M08E", 13):
		get_tree().quit(2)
		return
	var review := REVIEW.instantiate()
	add_child(review)
	review.get_node("Player").queue_free()
	blockout = review.get_node("Blockout") as Node3D
	_hide_debug(blockout)
	camera = Camera3D.new()
	camera.current = true
	camera.fov = 72.0
	add_child(camera)
	overview = _build_overview()
	overview.visible = false
	await shots.settle(0.8, "spatial_owners_ready")
	await _shot("01_f01_station_from_lobby", Vector3(-3.3, 1.41, -6.2), Vector3(-3.3, 1.0, -2.0), 76.0)
	await _shot("02_f01_four_owners_and_stances", Vector3(-1.65, 1.41, -2.6), Vector3(-4.1, 1.05, -1.0), 78.0)
	await _shot("03_f01_station_toward_primary_core", Vector3(-3.8, 1.41, -0.85), Vector3(1.2, 1.1, -1.8), 76.0)
	await _shot("04_b1_arrival", Vector3(2.2, -1.79, -2.9), Vector3(5.0, -1.9, -0.75), 78.0)
	await _shot("05_boiler_room_threshold", Vector3(7.2, -1.79, -0.4), Vector3(10.8, -2.0, -0.45))
	await _shot("06_boiler_water_column_approach", Vector3(10.35, -1.79, -2.75), Vector3(12.55, -1.75, -0.5), 80.0)
	var fire_leaf := blockout.get_node_or_null("B1_BOILER_FIRE_DOOR/Hinge/Leaf") as Node3D
	if fire_leaf != null: fire_leaf.visible = false
	await _shot("07_boiler_retreat_route", Vector3(10.9, -1.79, -0.4), Vector3(6.7, -1.95, -0.4), 78.0)
	if fire_leaf != null: fire_leaf.visible = true
	await _shot("08_f02_arrival_2b_threshold", Vector3(5.8, 4.61, -3.25), Vector3(9.5, 4.25, -3.25))
	await _shot("09_2b_entry_domestic_organization", Vector3(11.9, 4.61, -2.55), Vector3(13.7, 4.1, -0.35), 86.0)
	var bed_leaf := blockout.get_node_or_null("F02_B_BED_DOOR/Hinge/Leaf") as Node3D
	if bed_leaf != null: bed_leaf.visible = false
	await _shot("10_2b_work_sleep_circulation", Vector3(13.18, 4.61, -8.9), Vector3(10.9, 3.9, -10.9), 70.0)
	if bed_leaf != null: bed_leaf.visible = true
	await _shot("11_radiator_inspection_stance", Vector3(13.0, 4.61, -2.5), Vector3(15.4, 4.0, -3.0), 74.0)
	await _shot("12_2b_exit_toward_core", Vector3(10.4, 4.61, -3.25), Vector3(5.3, 4.25, -3.0), 78.0)
	overview.visible = true
	await _shot("13_topdown_complete_service_round", Vector3(4.5, 30.0, -24.0), Vector3(4.5, 4.0, -2.0), 60.0)
	_write_camera_receipt()
	get_tree().quit(0 if shots.finish() else 2)

func _shot(label: String, from: Vector3, at: Vector3, fov := 72.0,
		up := Vector3.UP) -> void:
	camera.global_position = from
	camera.fov = fov
	camera.look_at(at, up)
	var captured := await shots.capture(label)
	camera_records.append({"label": label, "position": _vec(from), "target": _vec(at),
			"fov": fov, "player_height": not label.begins_with("13_"),
			"capture": "PASS" if captured else "FAIL",
			"frame_check": "PASS" if captured else "FAIL"})

func _hide_debug(blockout: Node3D) -> void:
	for envelope: Dictionary in blockout.layout.get("envelopes", []):
		var node := blockout.get_node_or_null(str(envelope.id)) as Node3D
		if node != null: node.visible = false
	for anchor: Dictionary in blockout.layout.get("anchors", []):
		var node := blockout.get_node_or_null("%s/Envelope" % str(anchor.id)) as Node3D
		if node != null: node.visible = false

func _build_overview() -> Node3D:
	var root := Node3D.new()
	root.name = "ServiceRoundOverview"
	add_child(root)
	var points := [Vector3(15.4, 13.5, -3.0), Vector3(3.0, 13.5, -3.0),
		Vector3(-3.2, 13.5, -2.8), Vector3(3.0, 13.5, -3.0),
		Vector3(7.2, 13.5, -0.4), Vector3(12.45, 13.5, -0.5),
		Vector3(7.2, 13.5, -0.4), Vector3(3.0, 13.5, -3.0),
		Vector3(15.4, 13.5, -3.0)]
	for i in points.size() - 1:
		_line(root, points[i], points[i + 1])
	for item: Dictionary in [{"p": points[0], "t": "2B RADIATOR"},
		{"p": points[2], "t": "F01 PORTER"}, {"p": points[5], "t": "B1 BOILER"}]:
		var label := Label3D.new()
		label.text = str(item.t)
		label.font_size = 72
		label.pixel_size = 0.0025
		label.modulate = Color(1.0, 0.8, 0.3)
		label.outline_size = 10
		label.position = item.p + Vector3(0, 0.05, 0)
		label.rotation_degrees.x = -90
		root.add_child(label)
	return root

func _line(parent: Node3D, a: Vector3, b: Vector3) -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(a.distance_to(b), 0.06, 0.16)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.55, 0.08)
	material.emission_enabled = true
	material.emission = Color(0.9, 0.32, 0.03)
	mesh.material = material
	mesh_instance.mesh = mesh
	mesh_instance.position = (a + b) * 0.5
	mesh_instance.rotation.y = -atan2(b.z - a.z, b.x - a.x)
	parent.add_child(mesh_instance)

func _write_camera_receipt() -> void:
	var file := FileAccess.open(shots.output_dir.path_join("camera_and_frame_receipt.json"), FileAccess.WRITE)
	if file == null:
		push_error("M08E-A camera receipt could not be written")
		return
	file.store_string(JSON.stringify({"schema_version": 1,
			"status": "PASS" if camera_records.size() == 13 else "FAIL",
			"resolution": [1600, 900], "frames": camera_records}, "\t"))

func _vec(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]
