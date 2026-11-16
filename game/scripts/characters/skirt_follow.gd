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
## Seated gowns (order w4ad7cfa1287a, 2026-11-16). Measured on Adela's piano and Stacy's drum poses, the gowns
## tore where neighbouring chains were placed far apart, and three things placed them so:
## - Which part of the skirt a lifted leg carries is how far the knee has moved toward that chain, as a
##   continuous share. It was the sign of the knee's forward reach, so a thigh held out sideways on a drum stool
##   flipped the front of the skirt from following to hanging straight while its neighbours swung with the leg.
##   The share comes in only as the thigh lifts (from about seventeen degrees): standing, a weight-shifted leg
##   points its knee to the side, and the continuous share swung the gown's sides out 4-5 cm (Codex's
##   standing measurements, 2026-11-16), so a standing body keeps the sign of the forward reach exactly.
## - Sitting is also both thighs raised and neither swung back. A high stool keeps the thighs near forty
##   degrees, short of the single-thigh test, and a walking stride always has one thigh back.
## - Seated, the chains near the front and the back take the turn their band's middle chain takes. A slim
##   gown's back hangs close to the hips' axis, where the cloth hands over from one chain to the next within a
##   few centimetres, so chains that disagree there split it. The sides still lie along their own thigh.
## And the back of a seated skirt turns forward under the thigh about a point nearer the body than its bone,
## which stands well behind a slim gown and swung the cloth round a pivot outside it.
## None of this changes a standing body; walking straight forward or back, the two shares are the same.
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
## Seated, how much of the thigh's lift the sides of the skirt take. 0.75 left them hanging beside the leg, and a
## slim skirt (Nadia's ready-made suit) opened along its side seam over the thigh; all of it keeps the side over
## the leg, and wider skirts balloon less (cast extras, 2026-11-14).
@export var seated_side := 1.0
## Seated, how far short of the thigh's lift the front of the skirt stops (radians). The cloth starts a hand
## above the thigh at the waist; stopping a little short lets it come down onto the lap toward the knee.
@export var seated_settle := 0.05
## How much further than the thigh the skirt in front of a lifted leg swings, as a share of the swing. Cloth
## carried by a leg runs ahead of it; turned exactly as far, a long skirt was split by the thigh in a deep reach.
@export var lead := 0.15
## Seated, how fully the chains near the front and back take their band's middle turn (0 leaves each to its legs).
@export var seated_band := 1.0
## Seated, how far in from the back chains' own joint toward the hips' axis the skirt turns under the thigh.
@export var under_inward := 0.5
## A thigh lifted between these angles (radians) moves from the forward-reach sign to the continuous share.
@export var toward_from := 0.3
@export var toward_to := 0.6
## Both thighs lifted between these angles (radians) and neither swung back: sitting, on however high a seat.
@export var pair_lift_from := 0.35
@export var pair_lift_to := 0.7
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


## How much of each leg's swing, under-turn and knee bend a chain at (side, front) takes: three pairs, left leg
## first. `toward` is each knee's horizontal move from rest, as (side, front), unit length or zero; `reach` is
## the sign of its forward reach; `lifted` how far each leg has moved from that sign to the continuous share.
func _shares(side: float, front: float, toward: Array[Vector2], reach: Array[float], lifted: Array[float], seated: Array[float]) -> Array:
	# How far round the back this chain sits: the back of a seated skirt does not ride up with the thighs.
	var back := smoothstep(0.2, 0.7, -front)
	# The front and back of the skirt answer to either leg in full; a side only to its own.
	var shares: Array[float] = [smoothstep(-0.6, 0.0, side), smoothstep(-0.6, 0.0, -side)]
	var first: Array[float] = [0.0, 0.0]
	var under: Array[float] = [0.0, 0.0]
	var hem: Array[float] = [0.0, 0.0]
	for leg in 2:
		# A leg lifted forward takes the front of the skirt; swung back, the back of it. Lifted, a knee moving
		# toward the chain takes it and moving away leaves it hanging.
		var facing := lerpf(smoothstep(-0.5, 0.5, reach[leg] * front), smoothstep(-0.5, 0.5, toward[leg].dot(Vector2(side, front))), lifted[leg])
		var lap := lerpf(seated_side, 1.0, smoothstep(0.0, 0.7, front))
		first[leg] = shares[leg] * follow * lerpf(facing, lap, seated[leg] * (1.0 - back))
		under[leg] = shares[leg] * follow * seated[leg] * back
		hem[leg] = shares[leg] * lerpf(follow_knee * facing, 1.0, seated[leg]) * (1.0 - seated[leg] * back)
	return [first, under, hem]


func _process_modification() -> void:
	var body := get_skeleton()
	if body == null or _chain_bones.is_empty():
		return
	var hips_now := body.get_bone_global_pose(_hips)
	var hips_rest := body.get_bone_global_rest(_hips)
	var to_hips_now := hips_now.affine_inverse()
	var to_hips_rest := hips_rest.affine_inverse()
	var hips_turn := hips_now.basis.orthonormalized()
	# Down, forward and to the left as the hips had them at rest: the hips bone's own axes differ from body to body.
	var down_rest := (to_hips_rest.basis.orthonormalized() * Vector3.DOWN).normalized()
	var front_rest := (to_hips_rest.basis.orthonormalized() * Vector3.BACK).normalized()
	var left_rest := front_rest.cross(down_rest).normalized()
	var thighs: Array[int] = [_left, _right]
	# Each thigh's swing from rest, seen from the hips; how far forward it points; how seated it is.
	var swings: Array[Quaternion] = []
	var pivots: Array[Vector3] = []
	var forward: Array[float] = []
	var lifts: Array[float] = []
	var toward: Array[Vector2] = []
	var reach: Array[float] = []
	var lifted: Array[float] = []
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
		lifts.append(down_now.angle_to(down_rest))
		var moved := down_now - down_rest
		var flat := Vector2(moved.dot(left_rest), moved.dot(front_rest))
		toward.append(flat.normalized() if flat.length() > 0.0001 else Vector2.ZERO)
		reach.append(signf(forward[leg]))
		lifted.append(smoothstep(toward_from, toward_to, lifts[leg]))
		seated.append(smoothstep(0.75, 1.25, lifts[leg]) * smoothstep(0.0, 0.35, forward[leg]))
		if _shins[leg] >= 0:
			var shin_now := body.get_bone_global_pose(_shins[leg])
			var shin_in_thigh_rest := thigh_rest.affine_inverse() * body.get_bone_global_rest(_shins[leg])
			var unbent := (thigh_now * shin_in_thigh_rest).basis.orthonormalized()
			bends.append(Quaternion(shin_now.basis.orthonormalized() * unbent.inverse()))
			knees.append(shin_now.origin)
		else:
			bends.append(Quaternion.IDENTITY)
			knees.append(thigh_now.origin)
	# Both thighs up and neither swung back is sitting, however high the seat holds the knees.
	var pair := smoothstep(pair_lift_from, pair_lift_to, minf(lifts[0], lifts[1])) * smoothstep(-0.3, 0.1, minf(forward[0], forward[1]))
	for leg in 2:
		seated[leg] = maxf(seated[leg], pair)
	var sitting := (seated[0] + seated[1]) * 0.5
	for index in _chain_bones.size():
		var side := _chain_side[index]
		var front := _chain_front[index]
		var own: Array = _shares(side, front, toward, reach, lifted, seated)
		var middle: Array = _shares(0.0, front, toward, reach, lifted, seated)
		var band := seated_band * sitting * smoothstep(0.3, 0.8, absf(front))
		# Per stage (first bone, under-turn, knee): which leg's turn, as a 0..1 blend toward the right, and how much.
		var ratio: Array[float] = []
		var amount: Array[float] = []
		var acts: Array[bool] = []
		for stage in 3:
			var mine: Array[float] = own[stage]
			var theirs: Array[float] = middle[stage]
			var total := mine[0] + mine[1]
			var lean := mine[1] / total if total > 0.001 else 0.5
			ratio.append(lerpf(lean, 0.5, band))
			amount.append(lerpf(maxf(mine[0], mine[1]), maxf(theirs[0], theirs[1]), band))
			# Unbanded, a stage acts exactly when it always did: its two shares sum past a thousandth.
			acts.append(total > 0.001 if band <= 0.0 else amount[stage] > 0.0005)
		var posed := to_hips_rest * body.get_bone_global_rest(_chain_bones[index])
		if acts[0]:
			var mean := swings[0].slerp(swings[1], ratio[0])
			var seat := lerpf(seated[0], seated[1], ratio[0])
			var settle := seated_settle * seat * smoothstep(0.0, 0.7, front)
			var ahead := 1.0 + lead * (1.0 - seat) * smoothstep(0.0, 0.5, front)
			var turn := Basis(Quaternion(mean.get_axis().normalized(), maxf(0.0, mean.get_angle() * minf(1.0, amount[0]) * ahead - settle))) if mean.get_angle() > 0.0001 else Basis.IDENTITY
			var pivot := pivots[0].lerp(pivots[1], ratio[0])
			posed = Transform3D(turn * posed.basis, pivot + turn * (posed.origin - pivot))
		body.set_bone_global_pose(_chain_bones[index], hips_now * posed)
		# Seated, the back of the skirt hangs to the seat on its first bone and turns forward under the thigh on its
		# second, about a point drawn in toward the hips' axis from its joint, where the cloth of a slim gown is.
		var second := _chain_second[index]
		if second >= 0 and acts[1]:
			var local_turn := Basis(Quaternion.IDENTITY.slerp(swings[0].slerp(swings[1], ratio[1]), minf(1.0, amount[1])))
			var world_turn := hips_turn * local_turn * hips_turn.inverse()
			var lower := body.get_bone_global_pose(second)
			var at := to_hips_now * lower.origin
			at -= (at - down_rest * at.dot(down_rest)) * under_inward
			var pivot := hips_now * at
			body.set_bone_global_pose(second, Transform3D(world_turn * lower.basis, pivot + world_turn * (lower.origin - pivot)))
		# From the knee down the skirt goes with the shin: walking, a raised knee does not leave the lower leg
		# standing out in front of the cloth; seated, the hem hangs from the knees.
		var third := _chain_third[index]
		if third >= 0 and acts[2]:
			var turn := Basis(Quaternion.IDENTITY.slerp(bends[0].slerp(bends[1], ratio[2]), minf(1.0, amount[2])))
			var pivot := knees[0].lerp(knees[1], ratio[2])
			var below := body.get_bone_global_pose(third)
			body.set_bone_global_pose(third, Transform3D(turn * below.basis, pivot + turn * (below.origin - pivot)))
