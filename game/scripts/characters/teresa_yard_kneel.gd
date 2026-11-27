extends RefCounted
## Teresa's explicit S04 lower-body lease. Navigation retains the actor root.
## Authored raw-source contact fit; imported skin/cloth still needs native proof.
const Stand := preload("res://scripts/characters/stand_pose.gd")
## Regenerate/check with tools/calibrate_teresa_yard_kneel.py.
## Angles are degrees, lifts are metres at 33 equally spaced pose samples.
const THIGH_FORWARD_DEGREES := 20.0
const LIFT_INTERVALS := 32
const FIT := {
	"a_feet": {
		"out": {
			"Left": {
				"thigh": 5.556426,
				"shin": 5.391004
			},
			"Right": {
				"thigh": 5.556453,
				"shin": 5.391064
			}
		},
		"shin_degrees": -96.572997,
		"lifts": [
			0.0070834,
			0.0070993,
			0.0071146,
			0.0071448,
			0.0071796,
			0.0072127,
			0.0072438,
			0.007273,
			0.0073001,
			0.007325,
			0.0073478,
			0.0073696,
			0.0074041,
			0.0074343,
			0.0074604,
			0.007482,
			0.0074993,
			0.007512,
			0.0075203,
			0.007524,
			0.0075231,
			0.0075176,
			0.0075075,
			0.0074928,
			0.0074735,
			0.0074497,
			0.0074213,
			0.0073884,
			0.0073511,
			0.0073102,
			0.0072798,
			0.00725,
			0.0072178
		]
	}
}
const LOWER: Array[String]=["Hips","LeftUpLeg","LeftLeg","LeftFoot","LeftToeBase","RightUpLeg","RightLeg","RightFoot","RightToeBase"]
var wanted := true
var amount := 0.0
var settle := 0.0
var blocked_reason := ""
var last: Dictionary={}
var diagnostics := false
var _cast: Node3D
var _actor: Node3D
var _body: Skeleton3D
var _stand: RefCounted
var _profile: Dictionary={}
var _feet_part := ""
var _draws: Array[Dictionary]=[]
var _owned: Array[int]=[]
var _floor_y := 0.0
var _cached_t := -1.0
var _targets: Dictionary={}

func bind(actor: Node3D, cast: Node3D) -> bool:
	if not is_instance_valid(actor) or str(actor.get("resident_id"))!="teresa_vale" or not is_instance_valid(cast):return _refuse("Teresa cast required")
	if not bool(cast.get("ready_ok")) or cast.skeleton==null or cast.skeleton.get_bone_count()!=76:return _refuse("actual shared Teresa skeleton unavailable")
	_feet_part=str(cast.wardrobe.worn.get("feet",""))
	if not FIT.has(_feet_part):return _refuse("unmeasured worn shoes")
	if str(cast.wardrobe.worn.get("bottom",""))!="a_bottom":return _refuse("unqualified skirt; work a_bottom required")
	_profile=FIT[_feet_part]
	_cast=cast;_actor=actor;_body=cast.skeleton
	if _body.global_basis.get_scale().distance_to(Vector3.ONE)>.0001 or _body.global_basis.y.normalized().dot(Vector3.UP)<.9999:return _refuse("unmeasured model scale or tilt")
	for label: String in LOWER:
		var index:=_body.find_bone(label)
		if index<0:return _refuse("lower-body joint missing: "+label)
		_owned.append(index)
	for side: String in ["Left","Right"]:
		var thigh:=_body.find_bone(side+"UpLeg");var knee:=_body.find_bone(side+"Leg");var foot:=_body.find_bone(side+"Foot");var toe:=_body.find_bone(side+"ToeBase")
		if _body.get_bone_parent(knee)!=thigh or _body.get_bone_parent(foot)!=knee or _body.get_bone_parent(toe)!=foot:return _refuse("installed leg hierarchy changed")
		var hip_at:=_body.get_bone_global_rest(thigh).origin;var knee_at:=_body.get_bone_global_rest(knee).origin;var foot_at:=_body.get_bone_global_rest(foot).origin
		if absf(hip_at.distance_to(knee_at)-.344247)>.0005 or absf(knee_at.distance_to(foot_at)-.377056)>.0005:return _refuse("installed leg length differs from measured fit")
		var expected:=Vector3(.158874 if side=="Left" else -.158874,.066295,.024599)
		if foot_at.distance_to(expected)>.0005:return _refuse("installed foot rest differs from measured fit")
	for draw: MeshInstance3D in (cast.wardrobe._meshes.get(_feet_part,[]) as Array)+(cast.wardrobe._meshes.get("a_bottom",[]) as Array):
		if draw.mesh==null or draw.skin==null:return _refuse("worn shoe/skirt skin unavailable")
		for index in draw.mesh.get_blend_shape_count():
			if absf(draw.get_blend_shape_value(index))>.000001:return _refuse("unmeasured worn shoe/skirt morph")
		_draws.append({"draw":draw,"mesh":draw.mesh,"skin":draw.skin,"morph_count":draw.mesh.get_blend_shape_count()})
	if _draws.is_empty():return _refuse("actual worn shoes absent")
	if actor.get_world_3d()==null:return _refuse("native floor unavailable")
	var exclusions: Array[RID]=[]
	for collider: CollisionObject3D in actor.find_children("*","CollisionObject3D",true,false):exclusions.append(collider.get_rid())
	var floors: Array[float]=[]
	for point: Vector3 in [Vector3(.16,0,.025),Vector3(-.16,0,.025),Vector3(.124,0,.40),Vector3(-.124,0,.40)]:
		var at:=_body.to_global(point)
		var query:=PhysicsRayQueryParameters3D.create(at+Vector3.UP*.25,at-Vector3.UP*.25,1,exclusions)
		var hit: Dictionary=actor.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or (hit.normal as Vector3).y<.95:return _refuse("foot/knee has no real level floor")
		floors.append((hit.position as Vector3).y)
	_floor_y=floors[0]
	for height: float in floors:
		if absf(height-_floor_y)>.005:return _refuse("uneven kneel support")
	if absf(_body.to_local(Vector3(_body.global_position.x,_floor_y,_body.global_position.z)).y)>.025:return _refuse("model origin differs from measured floor")
	_stand=Stand.new()
	return true

func _refuse(reason: String) -> bool:
	blocked_reason=reason
	return false

func source_valid() -> bool:
	if not is_instance_valid(_cast) or not is_instance_valid(_body) or not bool(_cast.get("ready_ok")) or _cast.skeleton!=_body:return false
	if str(_cast.wardrobe.worn.get("feet",""))!=_feet_part or str(_cast.wardrobe.worn.get("bottom",""))!="a_bottom":return false
	for row: Dictionary in _draws:
		var draw: MeshInstance3D=row.draw
		if not is_instance_valid(draw) or draw.mesh!=row.mesh or draw.skin!=row.skin:return false
		for index in int(row.morph_count):
			if absf(draw.get_blend_shape_value(index))>.000001:return false
	return not _draws.is_empty()

func released() -> bool:return not wanted and amount<=0.0 and settle<=0.0

func apply_base(body: Skeleton3D, delta: float) -> void:
	if body!=_body or not source_valid():blocked_reason="skin invalidated";return
	# Reverse from the current amount; repeated off requests never restart rise.
	if wanted:
		settle=move_toward(settle,1.0,maxf(delta,0.0)/.20)
		if settle>=1.0:amount=move_toward(amount,1.0,maxf(delta,0.0)/1.0)
	else:
		amount=move_toward(amount,0.0,maxf(delta,0.0)/1.0)
		if amount<=0.0:settle=move_toward(settle,0.0,maxf(delta,0.0)/.20)
	if settle<=0.0:return
	var t:=amount*amount*(3.0-2.0*amount)
	if _cached_t!=t:
		var before: Array[Transform3D]=[]
		for bone in body.get_bone_count():before.append(body.get_bone_pose(bone))
		var row: Dictionary={"hips":{}}
		for side: String in ["Left","Right"]:
			var out: Dictionary=_profile.out[side]
			row[side.to_lower()]={"thigh":[float(out.thigh),THIGH_FORWARD_DEGREES*t],"shin":[float(out.shin),float(_profile.shin_degrees)*t],"foot":8.0}
		_stand.poses={"yard_kneel":row}
		_stand.apply(body,"yard_kneel",false,0.0,0.0)
		# Keep each pair's mean footprint in the authored source position; only
		# the Hips bone translates. Actor, capsule, route and world never move.
		var mean:=Vector3.ZERO;var target:=Vector3.ZERO
		for label: String in ["LeftFoot","RightFoot"]:
			var index:=body.find_bone(label)
			mean+=body.get_bone_global_pose(index).origin*.5
			target+=body.get_bone_global_rest(index).origin*.5
		var pelvis:=body.find_bone("Hips")
		var position:=body.get_bone_pose_position(pelvis)
		position.x+=target.x-mean.x;position.z+=target.z-mean.z
		var at:=t*float(LIFT_INTERVALS);var index:=mini(int(at),LIFT_INTERVALS-1)
		var lift:=lerpf(float(_profile.lifts[index]),float(_profile.lifts[index+1]),at-float(index))
		var floor_offset:=body.to_local(Vector3(body.global_position.x,_floor_y,body.global_position.z)).y
		position.y+=lift+floor_offset
		body.set_bone_pose_position(pelvis,position)
		_targets.clear()
		for bone: int in _owned:_targets[bone]=body.get_bone_pose(bone)
		for bone in body.get_bone_count():body.set_bone_pose(bone,before[bone])
		_cached_t=t
	for bone: int in _owned:
		body.set_bone_pose(bone,body.get_bone_pose(bone).interpolate_with(_targets[bone],settle))
	if diagnostics:
		var knees: Array[Vector3]=[]
		for label: String in ["LeftLeg","RightLeg"]:knees.append(body.to_global(body.get_bone_global_pose(body.find_bone(label)).origin))
		last={"knee_world":knees,"amount":amount,"settle":settle,"wanted":wanted,"floor_y":_floor_y,"shoe":_feet_part,"observation":"inside lower-body base stage; native whole skin/cloth qualification required"}
