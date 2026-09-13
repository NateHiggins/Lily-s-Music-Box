extends "res://scripts/props/medicine_cabinet_prop.gd"
## Surface mounted over the basin. Keep MirrorGlass -> CabinetDoor -> cabinet
## intact for the shared reflection owner. The moving leaf is also solid.

func _build_visual() -> void:
	super._build_visual()
	var body := AnimatableBody3D.new()
	body.name = "CabinetLeafBody"
	body.sync_to_physics = true
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(W, H, .030)
	collision.shape = shape
	var side := 1.0 if hinge_side == "left" else -1.0
	collision.position = Vector3(-side * W * .5, 0, -.003)
	body.add_child(collision)
	_door.add_child(body)
	set_process(false)
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	super._process(delta)
