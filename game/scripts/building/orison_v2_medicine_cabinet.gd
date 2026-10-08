extends "res://scripts/props/medicine_cabinet_prop.gd"
## Surface mounted over the basin. Keep MirrorGlass -> CabinetDoor -> cabinet
## intact for the shared reflection owner. The moving leaf is also solid.
signal open_state_changed(open: bool)
var native_ready := false
var _leaf_body: AnimatableBody3D

func merge_static(under: Node3D, keep: Array = []) -> int:
	if under.name == "CabinetContents": return 0
	return super.merge_static(under, keep)

func _build_kept() -> void:
	super._build_kept()
	var contents := get_node("CabinetContents")
	var names := inventory_names()
	for i in contents.get_child_count(): contents.get_child(i).set_meta("source_kept_name", names[i])

func set_door_open(open: bool, duration := .35) -> void:
	super.set_door_open(open, duration)
	open_state_changed.emit(open)

func restore_open_state(value: bool) -> void:
	_open = value
	_swing = 1.0 if value else 0.0
	_apply_swing()

func _build_visual() -> void:
	super._build_visual()
	if has_meta("native_medicine_factory"):
		native_ready = get_meta("native_medicine_factory").install_on(self)
		remove_meta("native_medicine_factory")
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
	_leaf_body = body
	set_process(false)
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	super._process(delta)

func _apply_swing() -> void:
	super._apply_swing()
	# AnimatableBody3D owns its physics transform: ancestor rotation alone can
	# leave its server body at the old pose. Submit the original hinge target.
	if is_instance_valid(_leaf_body): _leaf_body.global_transform = _door.global_transform
