extends Node3D
## Harmless local prop: every literal here is presentation-only and must be
## counted in stats, never recorded.


func _build() -> void:
	var lamp := MeshInstance3D.new()
	lamp.position = Vector3(0.0, 0.45, -0.34)
	var eye := Node3D.new()
	eye.position = Vector3(0.02, 1.55, 0.0)
	lamp.scale = Vector3(1.2, 1.2, 1.2)
