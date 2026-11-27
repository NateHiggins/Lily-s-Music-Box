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
		var lift:=maxf(.017*weight,floor_y-low)
		var target:=world.affine_inverse()*(world*ankle+Vector3.UP*lift)
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
	surface=machine;allowed=permitted;floor_y=machine.global_position.y
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
		legs.append({"ids":ids,"points":points})
	return legs.size()==2

func apply(body: Skeleton3D, write: Callable) -> void:
	valid=true;maximum_reach_error=0.0
	if not source_valid():valid=false;return
	if amount<=0.0 or not allowed.is_valid() or not allowed.call():return
	for leg: Dictionary in legs:
		var ids: Array=leg.ids
		var thigh:=body.get_bone_global_pose(ids[0])
		var knee:=body.get_bone_global_pose(ids[1])
		var foot:=body.get_bone_global_pose(ids[2])
		var toe_relative:=foot.affine_inverse()*body.get_bone_global_pose(ids[3])
		var original_basis:=foot.basis
		var low:=INF
		for point: Array in leg.points:
			var position:=Vector3.ZERO
			for part: Array in point:position+=(body.get_bone_global_pose(int(part[0]))*(part[1] as Vector3))*float(part[2])
			low=minf(low,body.to_global(position).y)
		var lift:=maxf(.017*amount,floor_y-low)
		var target:=body.to_local(body.to_global(foot.origin)+Vector3.UP*lift)
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
