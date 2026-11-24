extends SkeletonModifier3D
## Walking foot placement (order w3473eaaf58a9; Lily's ruling npc_generic_stairs_20261124: foot placement first,
## everyone keeps their own walk, feet land on each tread, no new animation).
##
## A walking clip is authored on a flat floor at the body's root. On the house's stairs the route carries the body
## up a ramp that only touches each tread's back edge, so the clip's feet sink into the steps. This stage reads the
## real floor under each foot (a ray onto the tread's own collider), keeps every foot at the height above it that
## the clip gave it above its flat floor, lowers or raises the pelvis by the smaller of the two corrections so a
## leg can reach, and solves each leg as two bones in the clip's own knee plane. The foot keeps the clip's
## orientation. On a level floor both corrections are zero and the clip passes through unchanged.
##
## It is its own modifier, placed directly after the PosePipeline, so the pipeline's bytes (which the Harukiya
## staff standing profile pins) stay untouched. It writes the pelvis, thighs, shins and feet; the pipeline writes
## none of those while a body walks (its contact slot serves seated feet only, and a seated body is never walked).

## The furthest a foot is moved off the clip, up or down. A long stride puts the leading foot two treads above the
## ramp point under the body (about 0.4 m on the house's stairs); more than this is a missed ray.
const REACH := 0.5
## How fast the pelvis and the stage's weight follow, as the time to cover most of the way.
const EASE_SECONDS := 0.12
## Ray reach above and below the body's floor.
const PROBE := 0.6
## How far ahead of a swinging toe the floor is read, so the toe clears the next riser instead of passing through
## it. Only the swinging foot looks ahead; a planted foot stays on the tread under it.
const LOOK_AHEAD := 0.12
## A foot is swinging when its toe is this much higher in the clip than the other one's.
const SWING_LIFT := 0.015
## How fast one foot's correction follows the floor under it.
const FOOT_SECONDS := 0.06

var actor: Node3D
var legs: Array[Dictionary] = []
var pelvis := -1
## True while the route walks the body; the stage's weight eases toward it. (`active`, the engine's own switch,
## turns the whole modifier off.)
var walking := false
var weight := 0.0
var _hip := 0.0
## Each foot's correction, eased: a swinging foot that passes over a nosing rises onto the next tread over a few
## frames instead of in one.
var _feet := [0.0, 0.0]
## Last frame's measurement, for tests and the capture: per side the correction asked for and the reach left over.
var last_offsets := [0.0, 0.0]
var last_reach_error := [0.0, 0.0]
var last_hip := 0.0
var rays := 0
## Where the stage put the feet last frame, in the world: left toe, right toe, left heel, right heel. The engine
## restores the clip's pose after skinning, so this is the only readable record of the placed feet. Empty while the
## stage is at rest (the clip's own pose is then the true one).
var last_feet_world: Array[Vector3] = []
var errors: Array[String] = []


var _last_usec := 0


## Installs the stage on `pipeline`'s skeleton, directly after it. Null when the rig lacks a leg chain.
static func install(body_actor: Node3D, pipeline: Node) -> Node:
	var skeleton := pipeline.get_parent() as Skeleton3D
	if skeleton == null or pipeline.get("profile") == null:
		return null
	var feet: Node = (load("res://scripts/characters/walking_feet.gd") as GDScript).new()
	feet.name = "WalkingFeet"
	if not feet.bind(body_actor, pipeline.profile):
		feet.free()
		return null
	skeleton.add_child(feet)
	skeleton.move_child(feet, pipeline.get_index() + 1)
	return feet


func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	var now := Time.get_ticks_usec()
	var delta := clampf(float(now - _last_usec) / 1000000.0, 0.0, 0.1) if _last_usec > 0 else 0.016
	_last_usec = now
	apply(skeleton, _write, delta)


func _write(bone: int, pose: Transform3D, _layer: String) -> bool:
	get_skeleton().set_bone_global_pose(bone, pose)
	return true


func bind(body_actor: Node3D, profile: RefCounted) -> bool:
	actor = body_actor
	pelvis = int(profile.bones.get("pelvis", -1))
	for side: String in ["left", "right"]:
		var ids: Array[int] = []
		for joint: String in ["thigh", "shin", "foot", "toe"]:
			ids.append(int(profile.bones.get(side + "_" + joint, -1)))
		if ids.has(-1):
			errors.append("no %s leg chain" % side)
			return false
		legs.append({"bones": ids})
	if pelvis < 0:
		errors.append("no pelvis")
		return false
	return true


func _floor_under(world: World3D, at: Vector3, floor_y: float) -> float:
	var query := PhysicsRayQueryParameters3D.create(Vector3(at.x, floor_y + PROBE, at.z), Vector3(at.x, floor_y - PROBE, at.z))
	query.collide_with_areas = false
	rays += 1
	var hit := world.direct_space_state.intersect_ray(query)
	return float(hit.position.y) if not hit.is_empty() else NAN


func apply(skeleton: Skeleton3D, write: Callable, delta: float) -> void:
	var ease := 1.0 - exp(-delta * 3.0 / EASE_SECONDS)
	weight = lerpf(weight, 1.0 if walking else 0.0, ease)
	if weight < 0.001 or actor == null or not is_instance_valid(actor) or not actor.is_inside_tree():
		_hip = 0.0
		_feet = [0.0, 0.0]
		last_feet_world.clear()
		return
	var world := skeleton.get_world_3d()
	if world == null:
		return
	var world_from_skeleton := skeleton.global_transform
	var skeleton_from_world := world_from_skeleton.affine_inverse()
	var floor_y := actor.global_position.y
	# 1. What each foot needs: the floor under its sole against the clip's flat floor.
	var offsets: Array[float] = []
	var clip_toes: Array[Vector3] = []
	for leg: Dictionary in legs:
		clip_toes.append(world_from_skeleton * skeleton.get_bone_global_pose(leg.bones[3]).origin)
	var ahead := actor.global_basis.z.normalized()
	for side: int in legs.size():
		var ids: Array = legs[side].bones
		var ankle := world_from_skeleton * skeleton.get_bone_global_pose(ids[2]).origin
		var toe := clip_toes[side]
		# Heel and ball: the higher floor under either is the one the foot stands on.
		var floors: Array[float] = [_floor_under(world, ankle, floor_y), _floor_under(world, toe, floor_y)]
		if toe.y > clip_toes[1 - side].y + SWING_LIFT:
			floors.append(_floor_under(world, toe + ahead * LOOK_AHEAD, floor_y))
		var under := NAN
		for found: float in floors:
			if is_finite(found):
				under = found if not is_finite(under) else maxf(under, found)
		var offset := under - floor_y if is_finite(under) else 0.0
		var wanted := offset if absf(offset) <= REACH else 0.0
		var i := offsets.size()
		_feet[i] = lerpf(_feet[i], wanted, 1.0 - exp(-delta * 3.0 / FOOT_SECONDS))
		offsets.append(_feet[i])
	last_offsets = offsets.duplicate()
	# 2. The pelvis carries the smaller correction, so the leg with further to go bends rather than overreaching.
	_hip = lerpf(_hip, minf(offsets[0], offsets[1]), ease)
	last_hip = _hip
	var hip_lift := skeleton_from_world.basis * (Vector3.UP * _hip * weight)
	var hips := skeleton.get_bone_global_pose(pelvis)
	write.call(pelvis, Transform3D(hips.basis, hips.origin + hip_lift), "contact")
	# 3. Each leg: the ankle goes where the clip had it, moved by its own correction (the pelvis already moved it by
	# the hip's), solved as thigh and shin in the clip's knee plane; the foot keeps the clip's turn.
	for side: int in legs.size():
		var ids: Array = legs[side].bones
		var clip_foot := skeleton.get_bone_global_pose(ids[2])
		# The pelvis write already carried this ankle up by the hip's share; add only the rest of its own.
		var target := clip_foot.origin + skeleton_from_world.basis * (Vector3.UP * (offsets[side] - _hip) * weight)
		var thigh := skeleton.get_bone_global_pose(ids[0])
		var knee := skeleton.get_bone_global_pose(ids[1]).origin
		var hip_at := thigh.origin
		var upper := hip_at.distance_to(knee)
		var lower := knee.distance_to(clip_foot.origin)
		var reach := target - hip_at
		var distance := clampf(reach.length(), absf(upper - lower) + 0.001, upper + lower - 0.001)
		var along := reach.normalized()
		# The bend direction is the clip's own: the knee's offset from the hip-to-ankle line.
		var clip_line := (clip_foot.origin - hip_at).normalized()
		var bend := (knee - hip_at) - clip_line * (knee - hip_at).dot(clip_line)
		if bend.length() < 0.0001:
			bend = skeleton_from_world.basis * actor.global_basis.z
		bend = (bend - along * bend.dot(along)).normalized()
		var cos_hip := clampf((upper * upper + distance * distance - lower * lower) / (2.0 * upper * distance), -1.0, 1.0)
		var new_knee := hip_at + along * upper * cos_hip + bend * upper * sqrt(1.0 - cos_hip * cos_hip)
		var new_ankle := hip_at + along * distance
		if not write.call(ids[0], Transform3D(Basis(Quaternion((knee - hip_at).normalized(), (new_knee - hip_at).normalized())) * thigh.basis, hip_at), "contact"):
			continue
		var shin := skeleton.get_bone_global_pose(ids[1])
		var shin_to := (skeleton.get_bone_global_pose(ids[2]).origin - shin.origin).normalized()
		if not write.call(ids[1], Transform3D(Basis(Quaternion(shin_to, (new_ankle - shin.origin).normalized())) * shin.basis, shin.origin), "contact"):
			continue
		var placed := skeleton.get_bone_global_pose(ids[2]).origin
		write.call(ids[2], Transform3D(clip_foot.basis, placed), "contact")
		last_reach_error[side] = (world_from_skeleton * placed).distance_to(world_from_skeleton * target)
	var toes: Array[Vector3] = []
	var heels: Array[Vector3] = []
	for leg: Dictionary in legs:
		toes.append(world_from_skeleton * skeleton.get_bone_global_pose(leg.bones[3]).origin)
		heels.append(world_from_skeleton * skeleton.get_bone_global_pose(leg.bones[2]).origin)
	last_feet_world = [toes[0], toes[1], heels[0], heels[1]]
