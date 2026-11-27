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
## Only the short live-clip handoff needs support beyond the baked kneel.
## Cached installed vertices, never raw authoring files or GPU readback.
const HANDOFF_CLEARANCE := .001
const HANDOFF_LIMIT := .02
var _shoe_legs: Array[Dictionary]=[]
var _handoff_supported := true
var _handoff_cost_usec := 0

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
	if not _bind_handoff_support():return false
	_stand=Stand.new()
	return true

func _bind_handoff_support() -> bool:
	for side: String in ["Left","Right"]:
		var ids: Array[int]=[]
		for suffix: String in ["UpLeg","Leg","Foot","ToeBase"]:ids.append(_body.find_bone(side+suffix))
		_shoe_legs.append({"side":side,"ids":ids,"points":[]})
	for draw: MeshInstance3D in _cast.wardrobe._meshes.get(_feet_part,[]):
		if not (_body.global_transform.affine_inverse()*draw.global_transform).is_equal_approx(Transform3D.IDENTITY):return _refuse("shoe/skeleton coordinates differ")
		for surface in draw.mesh.get_surface_count():
			var arrays: Array=draw.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array=arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
			if vertices.is_empty() or bones.size()%vertices.size()!=0 or weights.size()!=bones.size():return _refuse("incomplete installed shoe skin")
			var stride:=int(bones.size()/vertices.size())
			if stride not in [4,8]:return _refuse("unsupported installed shoe influences")
			for vertex in vertices.size():
				var parts: Array=[];var side:=-1;var total:=0.0
				for slot in stride:
					var at:=vertex*stride+slot
					if not is_finite(weights[at]) or weights[at]<0.0:return _refuse("invalid shoe weight")
					if weights[at]<=0.0:continue
					if bones[at]<0 or bones[at]>=draw.skin.get_bind_count():return _refuse("invalid shoe bind")
					var name:=draw.skin.get_bind_name(bones[at])
					var bone:=_body.find_bone(name) if not name.is_empty() else draw.skin.get_bind_bone(bones[at])
					var current:=-1
					for index in 2:
						if bone in (_shoe_legs[index].ids as Array).slice(1):current=index
					if current<0 or (side>=0 and current!=side):return _refuse("unmeasured cross-leg shoe skin")
					side=current;total+=weights[at]
					parts.append([bone,(draw.skin.get_bind_pose(bones[at])*vertices[vertex])*weights[at],weights[at]])
				if side<0 or absf(total-1.0)>.001:return _refuse("unnormalized installed shoe")
				_shoe_legs[side].points.append(parts)
	for leg: Dictionary in _shoe_legs:
		if leg.points.is_empty():return _refuse("one actual shoe is missing")
	return true

func _shoe_low(body: Skeleton3D, leg: Dictionary, posed: Dictionary={}) -> float:
	var frames: Dictionary={}
	for bone: int in (leg.ids as Array).slice(1):frames[bone]=posed.get(bone,body.get_bone_global_pose(bone))
	var low:=INF
	for point: Array in leg.points:
		var at:=Vector3.ZERO
		for part: Array in point:
			var frame: Transform3D=frames[int(part[0])]
			at+=frame.basis*(part[1] as Vector3)+frame.origin*float(part[2])
		low=minf(low,body.to_global(at).y)
	return low

func _leg_goal(body: Skeleton3D, leg: Dictionary, target: Vector3) -> Dictionary:
	var ids: Array=leg.ids
	var thigh:=body.get_bone_global_pose(ids[0]);var knee:=body.get_bone_global_pose(ids[1]);var foot:=body.get_bone_global_pose(ids[2])
	var toe_relative:=foot.affine_inverse()*body.get_bone_global_pose(ids[3])
	var upper:=thigh.origin.distance_to(knee.origin);var lower:=knee.origin.distance_to(foot.origin)
	var reach:=target-thigh.origin;var distance:=reach.length()
	if distance>=upper+lower-.000001 or distance<=absf(upper-lower)+.000001:return {}
	var direction:=reach.normalized()
	var bend:=knee.origin-thigh.origin;bend-=direction*bend.dot(direction)
	if bend.length_squared()<.000001:
		# The authored standing stance can be almost straight. Its knees bend
		# toward the existing +Z front, never through an offset search.
		bend=Vector3.BACK-direction*Vector3.BACK.dot(direction)
	if bend.length_squared()<.000001:return {}
	var along:=(upper*upper-lower*lower+distance*distance)/(2.0*distance)
	var wanted:=thigh.origin+direction*along+bend.normalized()*sqrt(maxf(0.0,upper*upper-along*along))
	var upper_turn:=Basis(Quaternion((knee.origin-thigh.origin).normalized(),(wanted-thigh.origin).normalized()))
	var moved_foot:=wanted+upper_turn*(foot.origin-knee.origin)
	var lower_turn:=Basis(Quaternion((moved_foot-wanted).normalized(),(target-wanted).normalized()))
	var placed:=Transform3D(foot.basis,target)
	return {ids[0]:Transform3D(upper_turn*thigh.basis,thigh.origin),ids[1]:Transform3D(lower_turn*upper_turn*knee.basis,wanted),ids[2]:placed,ids[3]:placed*toe_relative}

func _support_handoff(body: Skeleton3D) -> bool:
	var proposed: Dictionary={}
	for leg: Dictionary in _shoe_legs:
		var foot:=body.get_bone_global_pose(leg.ids[2])
		var target:=foot.origin;var poses: Dictionary={}
		for iteration in 3:
			var low:=_shoe_low(body,leg,poses)
			var error:=_floor_y+HANDOFF_CLEARANCE-low
			if low>=_floor_y+.0008 and low<=_floor_y+.0058:break
			if error<0.0:error=_floor_y+.0055-low
			target=body.to_local(body.to_global(target)+Vector3.UP*error)
			if body.to_global(target).distance_to(body.to_global(foot.origin))>HANDOFF_LIMIT:return _refuse("standing handoff exceeds measured support range")
			poses=_leg_goal(body,leg,target)
			if poses.is_empty():return _refuse("standing handoff leg cannot reach real floor")
		var supported:=_shoe_low(body,leg,poses)-_floor_y
		if supported<.0008 or supported>.006:return _refuse("standing handoff source sole did not converge")
		proposed.merge(poses)
	# Both legs preflight before any support writes; no stretching or actor move.
	for leg: Dictionary in _shoe_legs:
		for bone: int in leg.ids:
			if proposed.has(bone):body.set_bone_global_pose(bone,proposed[bone])
	if blocked_reason.begins_with("standing handoff"):blocked_reason=""
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

func released() -> bool:return not wanted and amount<=0.0 and settle<=0.0 and _handoff_supported

func apply_base(body: Skeleton3D, delta: float) -> void:
	if body!=_body or not source_valid():blocked_reason="skin invalidated";return
	# Reverse from the current amount; repeated off requests never restart rise.
	if wanted:
		settle=move_toward(settle,1.0,maxf(delta,0.0)/.20)
		if settle>=1.0:amount=move_toward(amount,1.0,maxf(delta,0.0)/1.0)
	else:
		amount=move_toward(amount,0.0,maxf(delta,0.0)/1.0)
		if amount<=0.0:settle=move_toward(settle,0.0,maxf(delta,0.0)/.20)
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
	_handoff_supported=true;_handoff_cost_usec=0
	if settle<1.0:
		var began:=Time.get_ticks_usec()
		_handoff_supported=_support_handoff(body)
		_handoff_cost_usec=Time.get_ticks_usec()-began
	if diagnostics:
		var knees: Array[Vector3]=[]
		for label: String in ["LeftLeg","RightLeg"]:knees.append(body.to_global(body.get_bone_global_pose(body.find_bone(label)).origin))
		last={"knee_world":knees,"amount":amount,"settle":settle,"wanted":wanted,"floor_y":_floor_y,"shoe":_feet_part,"handoff_supported":_handoff_supported,"handoff_cost_usec":_handoff_cost_usec,"support_reason":blocked_reason,"observation":"inside lower-body base stage; native whole skin/cloth qualification required"}
