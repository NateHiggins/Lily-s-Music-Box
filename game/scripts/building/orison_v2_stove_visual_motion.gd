extends Node3D
## Attached to the original visual owner. Source transforms remain untouched.
## A child presentation frame lifts loose stock clear and seats it on the hob.
var _native_root: Node3D
var _home := Vector3.ZERO
var _index := 0
var _grate := false
var _fit: Dictionary

func configure(grate: bool, index: int, fit: Dictionary) -> void:
	_grate = grate
	_index = index
	_fit = fit
	_home = position
	_native_root = Node3D.new()
	_native_root.name = "NativeServiceStock"
	for child: Node in get_children():
		remove_child(child)
		_native_root.add_child(child)
	add_child(_native_root)
	set_notify_local_transform(true)
	_apply_native_pose()

func _notification(what: int) -> void:
	if what == NOTIFICATION_LOCAL_TRANSFORM_CHANGED and is_instance_valid(_native_root):
		_apply_native_pose()

func _smooth(value: float) -> float:
	var t := clampf(value,0.,1.)
	return t*t*(3.-2.*t)

func _apply_native_pose() -> void:
	var desired := Transform3D(Basis.IDENTITY,_home)
	if _grate:
		var u := clampf(rotation.x/deg_to_rad(-68.),0.,1.)
		var row: Dictionary = _fit.grate_parking[_index]
		var p: Array = row.blender_center
		var target := Vector3(p[0],p[2],-p[1])
		desired.origin = _home.lerp(target,u)+Vector3.UP*float(_fit.grate_lift_m)*sin(PI*u)
		if _index>=2: desired.origin.z -= float(_fit.grate_forward_m)*sin(PI*u)
		desired.basis = Basis(Vector3.RIGHT,deg_to_rad(float(row.angle_degrees))*u)
	else:
		var u := clampf((position.x-_home.x)/(.12 if _index%2==0 else -.12),0.,1.)
		var p: Array = _fit.cap_end_blender_delta[_index]
		var travel := Vector3(p[0],p[2],-p[1])
		var lift := float(_fit.cap_lift_m)*(_smooth((u-.25)/.20)-_smooth((u-.8)/.2))
		desired.origin += travel*_smooth((u-.45)/.35)+Vector3.UP*lift
	_native_root.transform = transform.affine_inverse()*desired
