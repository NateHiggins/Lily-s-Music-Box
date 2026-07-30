extends Node3D

var failures := 0


func _ready() -> void:
	var lab := MapDistortionLab.new()
	add_child(lab)
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	mesh.position = Vector3(3, 1, -2)
	add_child(mesh)
	var canonical := mesh.global_transform
	lab._pivot = Vector3.ZERO
	for distortion_mode in MapDistortionLab.MODES:
		if distortion_mode == "none":
			continue
		lab.mode = distortion_mode
		var altered := lab._distorted(canonical, mesh, 1.25)
		_check(not altered.is_equal_approx(canonical),
				distortion_mode + " produces an alternate map transform")
	lab._canonical[mesh] = canonical
	mesh.position = Vector3(99, 99, 99)
	lab.restore()
	_check(mesh.global_transform.is_equal_approx(canonical),
			"canonical map transform restores exactly")
	lab.mode = "none"
	var low_pick := lab._choose_chaos_mode(0.01)
	var high_pick := lab._choose_chaos_mode(0.99)
	_check(low_pick in MapDistortionLab.CHAOS_WEIGHTS,
			"chaos scheduler selects a valid low-weight phase")
	_check(high_pick in MapDistortionLab.CHAOS_WEIGHTS,
			"chaos scheduler selects a valid high-weight phase")
	lab.mode = "fractured"
	_check(lab._choose_chaos_mode(0.90) != "fractured",
			"chaos scheduler avoids repeating the current distortion")
	print("MAP DISTORTION TEST: %s" %
			("PASS" if failures == 0 else "FAIL (%d)" % failures))
	get_tree().quit(failures)


func _check(ok: bool, label: String) -> void:
	if ok:
		print("  [map ok] ", label)
	else:
		failures += 1
		printerr("  [MAP FAIL] ", label)
