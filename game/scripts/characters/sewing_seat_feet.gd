extends RefCounted
## Lena-only supported transition candidate. Existing native two-bone method,
## actual worn-shoe landmarks, no root movement and no leg stretching.
## Whole native shoe qualification remains mandatory for intermediate amounts.
var amount := 0.0
var surface: Node3D
var allowed: Callable
var legs: Array[Dictionary] = []
var valid := true
var maximum_reach_error := 0.0
var floor_y := 0.0
var source_part := ""
var _cast: Node3D
var _draws: Array[Dictionary] = []
var pose_owner: RefCounted
var diagnostics := false
var last: Dictionary = {}
var _settle := 0.0
var last_lifts: Array[float]=[0.0,0.0]
const STEP_HEIGHT := .065
const RIGHT_FORWARD_BOW := .10
const LEFT_REARWARD_BOW := .06
var _forward_world := Vector3.BACK

func copy_transition(previous: RefCounted) -> void:
	_settle=1.0
	for side in legs.size():
		for key: String in ["start","start_toe","end","end_toe"]:
			if previous.legs[side].has(key):legs[side][key]=previous.legs[side][key]
		for key: String in ["start","end"]:
			if not legs[side].has(key):continue
			var frame: Transform3D=legs[side][key]
			var toe: Transform3D=legs[side][key+"_toe"]
			frame.origin.y+=maxf(0.0,floor_y+.001-_frame_low(legs[side],frame,toe))
			legs[side][key]=frame

func _smooth(value: float) -> float:
	var t:=clampf(value,0.0,1.0)
	return t*t*(3.0-2.0*t)

func _frame_low(leg: Dictionary, frame: Transform3D, toe: Transform3D) -> float:
	var low:=INF
	# The articulated Foot/Toe blend can expose a sole point which is not
	# extreme in the rest pose. Keep every actual rigid lower-shoe point
	# for the short transition; rest-direction landmarks are insufficient.
	for point: Array in leg.support_points:
		var position:=Vector3.ZERO
		for part: Array in point:
			var posed:=frame if int(part[0])==int(leg.ids[2]) else frame*toe
			position+=(posed*(part[1] as Vector3))*float(part[2])
		low=minf(low,position.y)
	return low

## Actual seated destination from the imported clip, not a guessed leg mark.
## At amount1 the original qualified solver still owns the endpoint.
func prepare_end(poses: Array[Transform3D], world: Transform3D) -> void:
	for leg: Dictionary in legs:
		var foot: Transform3D=poses[leg.ids[2]]
		var toe:=foot.affine_inverse()*poses[leg.ids[3]]
		var frame:=world*foot
		frame.origin.y+=maxf(_minimum_lift(),floor_y-_frame_low(leg,frame,toe))
		leg["end"]=frame;leg["end_toe"]=toe

## Pure amount-driven path. Reversing or pausing amount retraces/holds exactly.
## Lift vertically before translating, and finish translating before landing.
func _step_goal(leg: Dictionary, weight: float) -> Dictionary:
	if not leg.has("start") or not leg.has("end"):return {}
	var right: bool=leg.side=="Right"
	var begin:=.02 if right else .51
	var finish:=.47 if right else .96
	var t:=clampf((weight-begin)/(finish-begin),0.0,1.0)
	var u:=_smooth((t-.15)/.70)
	var rise:=STEP_HEIGHT*_smooth(t/.15)*_smooth((1.0-t)/.15)
	var start: Transform3D=leg.start
	var end: Transform3D=leg.end
	var relaxed_end:=end
	# A seated clip may rest one shoe above the floor. It cannot support
	# the other leg's step there: land it first, then relax it only after
	# the opposite foot lands. The final authored seated frame is unchanged.
	var end_low:=_frame_low(leg,end,leg.end_toe)
	if end_low>floor_y+.006:end.origin.y+=floor_y+.001-end_low
	if right and weight>.96:
		var relax:=_smooth((weight-.96)/.04)
		var relaxed:=end.interpolate_with(relaxed_end,relax)
		return {"frame":relaxed,"toe":leg.end_toe,"mode":"seated_relax","progress":1.0,"clearance":relaxed.origin.y-end.origin.y}
	var frame:=start.interpolate_with(end,u)
	var toe: Transform3D=(leg.start_toe as Transform3D).interpolate_with(leg.end_toe,u)
	if right:frame.origin+=_forward_world*(RIGHT_FORWARD_BOW*pow(sin(PI*u),2))
	else:frame.origin-=_forward_world*(LEFT_REARWARD_BOW*pow(sin(PI*u),2))
	var low:=lerpf(_frame_low(leg,start,leg.start_toe),_frame_low(leg,end,leg.end_toe),u)+rise
	frame.origin.y+=low-_frame_low(leg,frame,toe)
	var mode:="start_plant" if t<=0.0 else ("end_plant" if t>=1.0 else ("lift" if t<.15 else ("land" if t>.85 else "swing")))
	return {"frame":frame,"toe":toe,"mode":mode,"progress":t,"clearance":rise}

func _minimum_lift() -> float:
	# Native actual-shoe probe attempt14: the work shoe sat 4.106–6.278mm
	# above floor with the casual shoe's17mm lift. Keep its distinct sole
	# calibration; the actual geometric floor bound still applies below.
	return .014 if source_part=="a_feet" else .017

func source_valid() -> bool:
	if not is_instance_valid(_cast) or str(_cast.wardrobe.worn.get("feet",""))!=source_part:return false
	for row: Dictionary in _draws:
		var draw: MeshInstance3D=row.draw
		if not is_instance_valid(draw) or draw.mesh!=row.mesh or draw.skin!=row.skin:return false
		for index in row.morphs.size():
			if draw.get_blend_shape_value(index)!=row.morphs[index]:return false
	return not _draws.is_empty()

## Pure FK boundary used before route commits a proposed actor transform.
## It rejects unreachable legs; it does not certify unmeasured skin/footsteps.
func can_reach(poses: Array[Transform3D], world: Transform3D, weight: float) -> bool:
	if not source_valid():return false
	if weight<=0.0:return true
	if poses.is_empty():return false
	for leg: Dictionary in legs:
		var ids: Array=leg.ids
		var hip:=poses[ids[0]].origin
		var knee:=poses[ids[1]].origin
		var ankle:=poses[ids[2]].origin
		var low:=INF
		for point: Array in leg.points:
			var position:=Vector3.ZERO
			for part: Array in point:position+=(poses[int(part[0])]*(part[1] as Vector3))*float(part[2])
			low=minf(low,(world*position).y)
		var lift:=maxf(_minimum_lift()*weight,floor_y-low)
		var target:=world.affine_inverse()*(world*ankle+Vector3.UP*lift)
		if weight>0.0 and weight<1.0:
			var goal:=_step_goal(leg,weight)
			if goal.is_empty():return false
			target=world.affine_inverse()*(goal.frame as Transform3D).origin
		var upper:=hip.distance_to(knee);var lower:=knee.distance_to(ankle)
		var distance:=hip.distance_to(target)
		if distance>upper+lower-.001 or distance<absf(upper-lower)+.001:return false
	return true

func bind(cast: Node3D, machine: Node3D, permitted: Callable) -> bool:
	if not is_instance_valid(machine) or not permitted.is_valid():return false
	# Both are Lena's authored shoes. Bind the actually worn mesh; the old
	# b-only assumption refused her real work outfit at amount0. Each shape
	# still needs independent native skin qualification, never a wardrobe swap.
	source_part=str(cast.wardrobe.worn.get("feet",""))
	if source_part not in ["a_feet","b_feet"]:return false
	_cast=cast
	for draw: MeshInstance3D in cast.wardrobe._meshes.get(source_part,[]):
		if draw.skin==null or draw.mesh==null:return false
		var morphs: Array[float]=[]
		for index in draw.mesh.get_blend_shape_count():morphs.append(draw.get_blend_shape_value(index))
		_draws.append({"draw":draw,"mesh":draw.mesh,"skin":draw.skin,"morphs":morphs})
	if _draws.is_empty():return false
	surface=machine;allowed=permitted;floor_y=machine.global_position.y;_forward_world=machine.global_basis.z
	var body: Skeleton3D=cast.skeleton
	for side: String in ["Left","Right"]:
		var ids: Array[int]=[]
		for suffix: String in ["UpLeg","Leg","Foot","ToeBase"]:ids.append(body.find_bone(side+suffix))
		if ids.has(-1):return false
		if body.get_bone_parent(ids[1])!=ids[0] or body.get_bone_parent(ids[2])!=ids[1] or body.get_bone_parent(ids[3])!=ids[2]:return false
		var candidates: Array=[]
		for draw: MeshInstance3D in cast.wardrobe._meshes.get(source_part,[]):
			if draw.skin==null or draw.mesh==null:return false
			var mesh:=draw.bake_mesh_from_current_blend_shape_mix()
			if mesh==null:return false
			for index in mesh.get_surface_count():
				var arrays:=mesh.surface_get_arrays(index)
				var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
				var bones: PackedInt32Array=arrays[Mesh.ARRAY_BONES]
				var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
				if vertices.is_empty() or bones.size()%vertices.size()!=0:return false
				var stride:=int(bones.size()/vertices.size())
				for vertex in vertices.size():
					var influences: Array=[]
					var only_foot:=true
					var total:=0.0
					var rest:=Vector3.ZERO
					for slot in stride:
						var at:=vertex*stride+slot
						if weights[at]<=0.0:continue
						var joint:=bones[at]
						var name:=draw.skin.get_bind_name(joint)
						var bone:=body.find_bone(name) if not name.is_empty() else draw.skin.get_bind_bone(joint)
						if bone not in [ids[2],ids[3]]:only_foot=false;break
						var local: Vector3=draw.skin.get_bind_pose(joint)*vertices[vertex]
						influences.append([bone,local,weights[at]])
						rest+=(body.get_bone_global_rest(bone)*local)*weights[at]
						total+=weights[at]
					if only_foot and total>.999:candidates.append({"rest":rest,"parts":influences})
		if candidates.is_empty():return false
		# Actual source landmarks selected once, bounded at runtime. This is
		# not a substitute for the independent full-skin acceptance sweep.
		var points: Array=[]
		var selected: Array[int]=[]
		for x in [-1,0,1]:
			for y in [-1,0,1]:
				for z in [-1,0,1]:
					if x==0 and y==0 and z==0:continue
					var direction:=Vector3(x,y,z).normalized()
					var best:=INF;var winner:=-1
					for index in candidates.size():
						var score: float=(candidates[index].rest as Vector3).dot(direction)
						if score<best:best=score;winner=index
					if not selected.has(winner):selected.append(winner);points.append(candidates[winner].parts)
		var support: Array=[]
		for candidate: Dictionary in candidates:support.append(candidate.parts)
		legs.append({"side":side,"ids":ids,"points":points,"support_points":support})
	return legs.size()==2

func apply(body: Skeleton3D, write: Callable) -> void:
	valid=true;maximum_reach_error=0.0
	last.clear()
	if not source_valid():valid=false;return
	if not allowed.is_valid() or not allowed.call():return
	var delta: float=pose_owner.last_delta if pose_owner!=null else 1.0/60.0
	_settle=move_toward(_settle,1.0,delta/.20)
	for side_index in legs.size():
		var leg: Dictionary=legs[side_index]
		var ids: Array=leg.ids
		var thigh:=body.get_bone_global_pose(ids[0])
		var knee:=body.get_bone_global_pose(ids[1])
		var foot:=body.get_bone_global_pose(ids[2])
		var base_ankle_world:=body.to_global(foot.origin)
		var toe_relative:=foot.affine_inverse()*body.get_bone_global_pose(ids[3])
		var original_basis:=foot.basis
		var low:=INF
		for point: Array in leg.points:
			var position:=Vector3.ZERO
			for part: Array in point:position+=(body.get_bone_global_pose(int(part[0]))*(part[1] as Vector3))*float(part[2])
			low=minf(low,body.to_global(position).y)
		var lift:=maxf(_minimum_lift()*amount,floor_y-low)
		if amount<=0.0:
			var actual_low:=_frame_low(leg,body.global_transform*foot,toe_relative)
			lift=maxf(0.0,floor_y+.001-actual_low)*_smooth(_settle)
		var target:=body.to_local(body.to_global(foot.origin)+Vector3.UP*lift)
		var mode:="standing" if amount<=0.0 else "seated"
		var progress:=0.0;var clearance:=0.0
		if amount>0.0 and amount<1.0:
			var goal:=_step_goal(leg,amount)
			if goal.is_empty():valid=false;continue
			var wanted:=body.global_transform.affine_inverse()*(goal.frame as Transform3D)
			target=wanted.origin;original_basis=wanted.basis;toe_relative=goal.toe
			mode=goal.mode;progress=goal.progress;clearance=goal.clearance
		var upper:=thigh.origin.distance_to(knee.origin)
		var lower:=knee.origin.distance_to(foot.origin)
		var reach:=target-thigh.origin
		var distance:=reach.length()
		if upper<.001 or lower<.001 or distance>upper+lower-.001 or distance<absf(upper-lower)+.001:
			valid=false;continue
		var direction:=reach.normalized()
		var old_line:=(foot.origin-thigh.origin).normalized()
		var bend:=knee.origin-thigh.origin
		bend-=old_line*bend.dot(old_line);bend-=direction*bend.dot(direction)
		if bend.length_squared()<.000001:valid=false;continue
		bend=bend.normalized()
		var along:=(upper*upper-lower*lower+distance*distance)/(2.0*distance)
		var wanted:=thigh.origin+direction*along+bend*sqrt(maxf(0.0,upper*upper-along*along))
		var turn:=Basis(Quaternion((knee.origin-thigh.origin).normalized(),(wanted-thigh.origin).normalized()))
		if not write.call(ids[0],Transform3D(turn*thigh.basis,thigh.origin),"contact"):valid=false;continue
		knee=body.get_bone_global_pose(ids[1]);foot=body.get_bone_global_pose(ids[2])
		turn=Basis(Quaternion((foot.origin-knee.origin).normalized(),(target-knee.origin).normalized()))
		if not write.call(ids[1],Transform3D(turn*knee.basis,knee.origin),"contact"):valid=false;continue
		foot=body.get_bone_global_pose(ids[2])
		maximum_reach_error=maxf(maximum_reach_error,foot.origin.distance_to(target))
		var settled:=Transform3D(original_basis,foot.origin)
		if not write.call(ids[2],settled,"contact"):valid=false;continue
		if not write.call(ids[3],settled*toe_relative,"contact"):valid=false
		var placed:=body.global_transform*settled
		if amount<=0.0:leg["start"]=placed;leg["start_toe"]=toe_relative
		elif amount>=1.0:leg["end"]=placed;leg["end_toe"]=toe_relative
		last_lifts[side_index]=placed.origin.y-base_ankle_world.y
		if diagnostics:
			last[leg.side]={"mode":mode,"amount":amount,"swing_progress":progress,"requested_clearance":clearance,
				"support_points":leg.support_points.size(),"legacy_landmarks":leg.points.size(),
				"world_foot":placed,"world_toe":body.to_global((settled*toe_relative).origin),
				"sole_low_world":_frame_low(leg,placed,toe_relative),"target_world":body.to_global(target),
				"tracking_error":foot.origin.distance_to(target),"observation":"inside post-contact modifier; native whole shoe still required"}
