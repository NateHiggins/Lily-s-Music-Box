extends SkeletonModifier3D
## A skirt that makes room for the legs. The rebuilt cast's skeleton carries
## eight chains of skirt bones round the hips. Each frame, after the clip,
## every chain's first bone is swung by a share of the swing of the thigh on
## its side, about that thigh's own joint: a leg stepping forward carries the
## front of the skirt with it, so the leg never comes through the cloth.
## Spring bones placed after this one then add the sway and the settling.
##
## It writes only the first bone of each skirt chain, and reads the thighs and
## hips; nothing else writes those bones before the springs.

const CHAINS := 8
## How much of a thigh's swing its side of the skirt takes.
@export var follow := 1.0

var _chain_bones: Array[int] = []
var _chain_side: Array[float] = []
var _chain_front: Array[float] = []
var _hips := -1
var _left := -1
var _right := -1


func bind() -> bool:
	var body := get_skeleton()
	if body == null:
		return false
	_hips = body.find_bone("Hips")
	_left = body.find_bone("LeftUpLeg")
	_right = body.find_bone("RightUpLeg")
	_chain_bones.clear()
	_chain_side.clear()
	_chain_front.clear()
	for chain in CHAINS:
		var bone := body.find_bone("Skirt%d_1" % chain)
		if bone < 0:
			return false
		_chain_bones.append(bone)
		# Where the chain sits round the hips at rest: +1 fully on the left side, -1 on the right.
		var out := body.get_bone_global_rest(bone).origin - body.get_bone_global_rest(_hips).origin
		out.y = 0.0
		_chain_side.append(out.normalized().x if out.length() > 0.001 else 0.0)
		_chain_front.append(out.normalized().z if out.length() > 0.001 else 0.0)
	return _hips >= 0 and _left >= 0 and _right >= 0


func _process_modification() -> void:
	var body := get_skeleton()
	if body == null or _chain_bones.is_empty():
		return
	var hips_now := body.get_bone_global_pose(_hips)
	var hips_rest := body.get_bone_global_rest(_hips)
	var to_hips_now := hips_now.affine_inverse()
	var to_hips_rest := hips_rest.affine_inverse()
	# Each thigh's swing from rest, seen from the hips.
	var swings: Array[Quaternion] = []
	var pivots: Array[Vector3] = []
	for thigh: int in [_left, _right]:
		var now := (to_hips_now * body.get_bone_global_pose(thigh)).basis.orthonormalized()
		var rest := (to_hips_rest * body.get_bone_global_rest(thigh)).basis.orthonormalized()
		swings.append(Quaternion(now * rest.inverse()))
		pivots.append((to_hips_rest * body.get_bone_global_rest(thigh)).origin)
	for index in _chain_bones.size():
		var side := _chain_side[index]
		var left_share := smoothstep(-0.8, 0.4, side)
		var right_share := smoothstep(-0.8, 0.4, -side)
		var rest_in_hips := to_hips_rest * body.get_bone_global_rest(_chain_bones[index])
		var posed := rest_in_hips
		for leg in 2:
			# A leg lifted forward takes the front of the skirt; swung back, the back of it.
			var toward := (swings[leg] * Vector3.DOWN).z
			var facing := smoothstep(-0.5, 0.5, signf(toward) * _chain_front[index])
			var share := (left_share if leg == 0 else right_share) * follow * lerpf(0.3, 1.0, facing)
			if share <= 0.001:
				continue
			var turn := Basis(Quaternion.IDENTITY.slerp(swings[leg], share))
			posed = Transform3D(turn * posed.basis, pivots[leg] + turn * (posed.origin - pivots[leg]))
		body.set_bone_global_pose(_chain_bones[index], hips_now * posed)
