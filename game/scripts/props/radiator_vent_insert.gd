extends RigidBody3D
var bank: Node3D
var identity := ""

func manipulation_target(_hit: Dictionary) -> Dictionary:
	return bank.grip(identity)
