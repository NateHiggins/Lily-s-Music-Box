extends Node
## Focused ownership regression: no imported world or timed walking fixtures.
const Boundaries := preload("res://scripts/building/orison_v2_street_boundaries.gd")
const Residency := preload("res://scripts/building/orison_v2_passage_residency.gd")
var failures: Array[String] = []
var passed := 0

class EmptyRegion extends Node3D:
	const CELLS := []
	var cell_nodes := {}

func _ready() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	if ok:
		passed += 1
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)

func _run() -> void:
	var section := Node3D.new()
	section.transform = Transform3D(Basis(Vector3.UP, 0.71), Vector3(48, 3, -63))
	add_child(section)
	var boundary := Boundaries.new()
	section.add_child(boundary)
	var closure := boundary.get_node("ShedTemporaryClosure") as StaticBody3D
	var notice := closure.get_node_or_null("ContractorClosureNotice") as Label3D
	_check(notice != null, "closure panel owns its lettering")
	if notice != null:
		var mesh := closure.get_child(0) as MeshInstance3D
		var surface_z: float = (mesh.mesh as BoxMesh).size.z * 0.5
		_check(notice.position.is_equal_approx(Vector3(0, .35, surface_z + .045)),
				"lettering clearance derives from the panel front face")
		var original := notice.global_position
		closure.transform = Transform3D(Basis(Vector3.UP, -.39), Vector3(30, 2, -8))
		_check(notice.global_position.is_equal_approx(closure.to_global(Vector3(0, .35, surface_z + .045)))
				and not notice.global_position.is_equal_approx(original),
				"moving and rotating the physical closure carries lettering")
	var region := EmptyRegion.new()
	region.position = Vector3(-.35, 0, -9.795)
	section.add_child(region)
	var interior := Node3D.new()
	section.add_child(interior)
	var resident := Residency.new()
	var player := PlayerController.new()
	var layout := {"spaces": [
		{"id":"F01_PUBLIC_CORE", "level":"F01", "rect":[-2,-8,2,-4]},
		{"id":"F01_VESTIBULE", "level":"F01", "rect":[-2,-4,2,-1]}]}
	_check(resident.configure(region, player, interior, layout), "residency accepts an owned section frame")
	# No asynchronous loading runs in this unit: drive only the actual gate
	# construction and wanted-state functions, then tear the owner down.
	resident.process_mode = Node.PROCESS_MODE_DISABLED
	region.add_child(resident)
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
			"res://data/orison_v2/exterior/street_frame.json"))
	var gate: StaticBody3D = region.get_node("PassageLoadingBarrier")
	var gate_point := Vector3(14, 1.05, float(source.arcade_building_line_z)-.3)
	_check(gate.global_position.is_equal_approx(section.to_global(gate_point)),
			"loading barrier uses the translated and rotated street section")
	resident._wanted = false
	var outside := section.to_global(Vector3(10, 0, 2))
	_check(outside.z < 0, "outside probe disagrees with the old world-z shortcut")
	resident._update_wanted(outside)
	_check(resident._wanted, "section exterior requests residency despite negative world z")
	resident._update_wanted(interior.to_global(Vector3(0, 0, -6)))
	_check(not resident._wanted, "named interior core still releases residency after relocation")
	resident._update_wanted(interior.to_global(Vector3(0, 0, -2)))
	_check(resident._wanted, "named vestibule still prefetches after relocation")
	section.free()
	player.free()
	print("V2 SPATIAL OWNERSHIP: %d passed; %d failed" % [passed, failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
