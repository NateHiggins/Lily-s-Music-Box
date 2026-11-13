extends SkeletonModifier3D
## A skirt that makes room for the legs. The rebuilt cast's skeleton carries
## eight chains of skirt bones round the hips. Each frame, after the clip,
## every chain's first bone is swung by a share of the swing of the thigh on
## its side, about that thigh's own joint: a leg stepping forward carries the
## front of the skirt with it, so the leg never comes through the cloth.
## Nothing is simulated: the skirt is skinned cloth, placed from the legs' pose
## alone, so it is the same every time and costs almost nothing.
##
## Sitting is a different arrangement of the same cloth. With a thigh lifted
## past about sixty degrees the whole skirt on that side lies along it, the
## hem hangs from the knee, and the back of the skirt stays down behind the
## seat and turns forward under the thigh. Where both legs claim a chain (the
## front and back middles) it takes the mean of the two, never one after the
## other: that doubled the turn and stood the front of a seated skirt on end.
##
## The chains are three bones of 0.2 m. The first two lie along the thigh and
## the third begins at the knee, so the knee's bend belongs to the third.
##
## It writes the three bones of each skirt chain, and reads the hips, thighs
## and shins; nothing else writes those bones.

const CHAINS := 8
## How much of a thigh's swing its side of the skirt takes.
@export var follow := 1.0

var _chain_bones: Array[int] = []
var _chain_second: Array[int] = []
var _chain_third: Array[int] = []
var _shins: Array[int] = []
## How much of a knee's bend the lower skirt on that side takes.
@export var follow_knee := 0.7
## Seated, how much of the thigh's lift the sides of the skirt take: less than the front, so they hang beside the leg.
@export var seated_side := 0.75
## Seated, how far short of the thigh's lift the front of the skirt stops (radians). The cloth starts a hand
## above the thigh at the waist; stopping a little short lets it come down onto the lap toward the knee.
@export var seated_settle := 0.05
## How much further than the thigh the skirt in front of a lifted leg swings, as a share of the swing. Cloth
## carried by a leg runs ahead of it; turned exactly as far, a long skirt was split by the thigh in a deep reach.
@export var lead := 0.15
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
	_chain_second.clear()
	_chain_third.clear()
	_chain_side.clear()
	_chain_front.clear()
	for chain in CHAINS:
		var bone := body.find_bone("Skirt%d_1" % chain)
		if bone < 0:
			return false
		_chain_bones.append(bone)
		_chain_second.append(body.find_bone("Skirt%d_2" % chain))
		_chain_third.append(body.find_bone("Skirt%d_3" % chain))
		# Where the chain sits round the hips at rest: +1 fully on the left side, -1 on the right.
		var out := body.get_bone_global_rest(bone).origin - body.get_bone_global_rest(_hips).origin
		out.y = 0.0
		_chain_side.append(out.normalized().x if out.length() > 0.001 else 0.0)
		_chain_front.append(out.normalized().z if out.length() > 0.001 else 0.0)
	_shins = [body.find_bone("LeftLeg"), body.find_bone("RightLeg")]
	return _hips >= 0 and _left >= 0 and _right >= 0


func _process_modification() -> void:
	var body := get_skeleton()
	if body == null or _chain_bones.is_empty():
		return
	var hips_now := body.get_bone_global_pose(_hips)
	var hips_rest := body.get_bone_global_rest(_hips)
	var to_hips_now := hips_now.affine_inverse()
	var to_hips_rest := hips_rest.affine_inverse()
	var hips_turn := hips_now.basis.orthonormalized()
	# Down and forward as the hips had them at rest: the hips bone's own axes differ from body to body.
	var down_rest := (to_hips_rest.basis.orthonormalized() * Vector3.DOWN).normalized()
	var front_rest := (to_hips_rest.basis.orthonormalized() * Vector3.BACK).normalized()
	var thighs: Array[int] = [_left, _right]
	# Each thigh's swing from rest, seen from the hips; how far forward it points; how seated it is.
	var swings: Array[Quaternion] = []
	var pivots: Array[Vector3] = []
	var forward: Array[float] = []
	var seated: Array[float] = []
	var bends: Array[Quaternion] = []
	var knees: Array[Vector3] = []
	for leg in 2:
		var thigh_now := body.get_bone_global_pose(thighs[leg])
		var thigh_rest := body.get_bone_global_rest(thighs[leg])
		var now := (to_hips_now * thigh_now).basis.orthonormalized()
		var rest := (to_hips_rest * thigh_rest).basis.orthonormalized()
		var swing := Quaternion(now * rest.inverse())
		swings.append(swing)
		pivots.append((to_hips_rest * thigh_rest).origin)
		var down_now := swing * down_rest
		forward.append(down_now.dot(front_rest))
		seated.append(smoothstep(0.75, 1.25, down_now.angle_to(down_rest)) if down_now.dot(front_rest) > 0.0 else 0.0)
		if _shins[leg] >= 0:
			var shin_now := body.get_bone_global_pose(_shins[leg])
			var shin_in_thigh_rest := thigh_rest.affine_inverse() * body.get_bone_global_rest(_shins[leg])
			var unbent := (thigh_now * shin_in_thigh_rest).basis.orthonormalized()
			bends.append(Quaternion(shin_now.basis.orthonormalized() * unbent.inverse()))
			knees.append(shin_now.origin)
		else:
			bends.append(Quaternion.IDENTITY)
			knees.append(thigh_now.origin)
	for index in _chain_bones.size():
		var side := _chain_side[index]
		var front := _chain_front[index]
		# How far round the back this chain sits: the back of a seated skirt does not ride up with the thighs.
		var back := smoothstep(0.2, 0.7, -front)
		# The front and back of the skirt answer to either leg in full; a side only to its own.
		var shares: Array[float] = [smoothstep(-0.6, 0.0, side), smoothstep(-0.6, 0.0, -side)]
		var first: Array[float] = [0.0, 0.0]
		var under: Array[float] = [0.0, 0.0]
		var hem: Array[float] = [0.0, 0.0]
		for leg in 2:
			# A leg lifted forward takes the front of the skirt; swung back, the back of it.
			var facing := smoothstep(-0.5, 0.5, signf(forward[leg]) * front)
			var lap := lerpf(seated_side, 1.0, smoothstep(0.0, 0.7, front))
			first[leg] = shares[leg] * follow * lerpf(facing, lap, seated[leg] * (1.0 - back))
			under[leg] = shares[leg] * follow * seated[leg] * back
			hem[leg] = shares[leg] * lerpf(follow_knee * facing, 1.0, seated[leg]) * (1.0 - seated[leg] * back)
		var posed := to_hips_rest * body.get_bone_global_rest(_chain_bones[index])
		var total := first[0] + first[1]
		if total > 0.001:
			var ratio := first[1] / total
			var mean := swings[0].slerp(swings[1], ratio)
			var settle := seated_settle * lerpf(seated[0], seated[1], ratio) * smoothstep(0.0, 0.7, front)
			var ahead := 1.0 + lead * (1.0 - lerpf(seated[0], seated[1], ratio)) * smoothstep(0.0, 0.5, front)
			var turn := Basis(Quaternion(mean.get_axis().normalized(), maxf(0.0, mean.get_angle() * minf(1.0, maxf(first[0], first[1])) * ahead - settle))) if mean.get_angle() > 0.0001 else Basis.IDENTITY
			var pivot := pivots[0].lerp(pivots[1], ratio)
			posed = Transform3D(turn * posed.basis, pivot + turn * (posed.origin - pivot))
		body.set_bone_global_pose(_chain_bones[index], hips_now * posed)
		# Seated, the back of the skirt hangs to the seat on its first bone and turns forward under the thigh on its second.
		var second := _chain_second[index]
		total = under[0] + under[1]
		if second >= 0 and total > 0.001:
			var ratio := under[1] / total
			var local_turn := Basis(Quaternion.IDENTITY.slerp(swings[0].slerp(swings[1], ratio), minf(1.0, maxf(under[0], under[1]))))
			var world_turn := hips_turn * local_turn * hips_turn.inverse()
			var lower := body.get_bone_global_pose(second)
			body.set_bone_global_pose(second, Transform3D(world_turn * lower.basis, lower.origin))
		# From the knee down the skirt goes with the shin: walking, a raised knee does not leave the lower leg
		# standing out in front of the cloth; seated, the hem hangs from the knees.
		var third := _chain_third[index]
		total = hem[0] + hem[1]
		if third >= 0 and total > 0.001:
			var ratio := hem[1] / total
			var turn := Basis(Quaternion.IDENTITY.slerp(bends[0].slerp(bends[1], ratio), minf(1.0, maxf(hem[0], hem[1]))))
			var pivot := knees[0].lerp(knees[1], ratio)
			var below := body.get_bone_global_pose(third)
			body.set_bone_global_pose(third, Transform3D(turn * below.basis, pivot + turn * (below.origin - pivot)))
