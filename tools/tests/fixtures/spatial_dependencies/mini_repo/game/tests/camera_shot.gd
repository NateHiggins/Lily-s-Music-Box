extends Node3D
## Capture-only coupling: plan-space camera stations and a room toggle.


func _ready() -> void:
	_look([0.0, -12.2, 1.62], [0.0, -9.9, 1.58], 72.0)
	toggle_room("F01_LOBBY")
	var away := Vector3(50.0, 0.0, 50.0)
	camera.global_position = away
