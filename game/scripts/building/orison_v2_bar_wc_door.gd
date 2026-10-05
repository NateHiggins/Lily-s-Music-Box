extends DoorProp
## A cranked hinge clears the original 700 mm opening without wall overtravel.
const HINGE_X := .08
const HINGE_NORMAL := .04

func _ready() -> void:
	super._ready()
	_body.sync_to_physics=false
	_body.position+=Vector3(-HINGE_X,0,HINGE_SETBACK-HINGE_NORMAL)
	for child: Node3D in _body.get_children():
		child.position+=Vector3(HINGE_X,0,HINGE_NORMAL-HINGE_SETBACK)
	if open: _body.rotation.y=motion_target_angle(true)
	_body.force_update_transform()
	_body.sync_to_physics=true

func _build_fixed_hardware() -> void:
	var metal:=MatLib.get_mat("iron_blackened",Color(.045,.04,.034))
	_box(_fixed,Vector3(width+.045,.004,.14),Vector3(width*.5,.002,0),metal)
	var native: Node3D=(preload("res://assets/props/wc_swing_clear_hinge.glb") as PackedScene).instantiate()
	for y: float in [.26,height*.5,height-.26]:
		for group: String in ["Fixed","Moving"]:
			var source:=native.get_node(group) as MeshInstance3D
			var part:=MeshInstance3D.new();part.name="SwingClear"+group
			part.mesh=source.mesh;part.material_override=metal;part.position.y=y
			(_fixed if group=="Fixed" else _body).add_child(part)
	native.free()

func motion_target_angle(want_open: bool) -> float:
	return deg_to_rad(-90.0 if swing_out else 90.0) if want_open else 0.0
