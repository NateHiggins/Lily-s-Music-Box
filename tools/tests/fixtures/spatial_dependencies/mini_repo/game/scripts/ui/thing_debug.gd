extends Node
## Debug-only surface: filename carries "debug", so records here must gain
## the DEBUG_ONLY authority class.


func _go_lobby(player: Node3D) -> void:
	player.global_position = Vector3(0.0, 0.1, 9.0)
	prints("teleport to", "F01_LOBBY")
