extends RefCounted
## Fixed-footrest seating only. Navigation/seat height stay with their owners.
## Anchors come from actual morphed worn shoe vertices in the rig's rest frame.
## All writes go through PosePipeline's contact slot, before SkirtFollow.
var legs: Array[Dictionary] = []
var errors: Array[String] = []
var maximum_reach_error := 0.0

func bind(actor: Node3D, targets: Array[Vector3], resident: String) -> bool:
	var skeleton: Skeleton3D=actor.skeleton
	if targets.size()!=2:return false
	var profile: RefCounted=actor.attention.pipeline.profile
	var forward: Vector3=profile.forward
	var up: Vector3=profile.up
	var footwear: String=str(actor.wardrobe.worn.get("feet",""))
	var calibration: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/characters/stool_foot_support.json"))
	if int(calibration.get("schema_version",0))!=1:return false
	var support: Dictionary={}
	for row: Dictionary in calibration.get("residents",[]):
		if str(row.id)==resident:support=row;break
	var lifts: Array=support.get("lift_m",[0.0,0.0]) if str(support.get("part",""))==footwear else [0.0,0.0]
	var draws: Array=actor.wardrobe._meshes.get(footwear,[])
	for side_index: int in 2:
		var side: String="Left" if side_index==0 else "Right"
		var ids: Array[int]=[]
		for suffix: String in ["UpLeg","Leg","Foot","ToeBase"]:
			ids.append(skeleton.find_bone(side+suffix))
		if ids.has(-1):errors.append("missing seated leg chain "+side);return false
		var points: Array[Vector3]=[]
		for draw: MeshInstance3D in draws:
			if draw.skin==null:continue
			var mesh: ArrayMesh=draw.bake_mesh_from_current_blend_shape_mix()
			if mesh==null:continue
			for surface: int in mesh.get_surface_count():
				var a: Array=mesh.surface_get_arrays(surface)
				var vertices: PackedVector3Array=a[Mesh.ARRAY_VERTEX]
				var bones: PackedInt32Array=a[Mesh.ARRAY_BONES]
				var weights: PackedFloat32Array=a[Mesh.ARRAY_WEIGHTS]
				if vertices.is_empty() or bones.size()%vertices.size()!=0:return false
				var stride: int=bones.size()/vertices.size()
				for vi: int in vertices.size():
					var p:=Vector3.ZERO
					var own:=0.0
					for slot: int in stride:
						var k: int=vi*stride+slot
						if weights[k]<=0:continue
						var bind_index: int=bones[k]
						var bone: int=draw.skin.get_bind_bone(bind_index)
						if bone<0:bone=skeleton.find_bone(draw.skin.get_bind_name(bind_index))
						if bone<0:return false
						p+=(skeleton.get_bone_global_rest(bone)*draw.skin.get_bind_pose(bind_index)*vertices[vi])*weights[k]
						if str(skeleton.get_bone_name(bone)).begins_with(side):own+=weights[k]
					if own>.99:points.append(p)
		if points.is_empty():errors.append("no actual worn shoe vertices "+side);return false
		var front: float=-INF
		var back: float=INF
		for p: Vector3 in points:
			front=maxf(front,p.dot(forward));back=minf(back,p.dot(forward))
		# A real forefoot sole vertex, not a foot-bone origin or a boot shaft.
		var anchor:=Vector3.ZERO
		var lowest: float=INF
		for p: Vector3 in points:
			if p.dot(forward)<lerpf(back,front,.65):continue
			if p.dot(up)<lowest:lowest=p.dot(up);anchor=p
		var rest: Transform3D=skeleton.get_bone_global_rest(ids[2])
		var target: Vector3=targets[side_index]+Vector3.UP*float(lifts[side_index])
		legs.append({"bones":ids,"anchor":rest.affine_inverse()*anchor,"foot_basis":rest.basis,
			"toe_relative":rest.affine_inverse()*skeleton.get_bone_global_rest(ids[3]),"target":target,
			"forward":forward,"source_part":footwear,"source_anchor":anchor})
	return legs.size()==2

func apply(skeleton: Skeleton3D, write: Callable) -> void:
	for leg: Dictionary in legs:
		var ids: Array=leg.bones
		var hip: Transform3D=skeleton.get_bone_global_pose(ids[0])
		var knee: Transform3D=skeleton.get_bone_global_pose(ids[1])
		var foot: Transform3D=skeleton.get_bone_global_pose(ids[2])
		var desired_basis: Basis=leg.foot_basis
		var ankle: Vector3=skeleton.global_transform.affine_inverse()*(leg.target as Vector3)-desired_basis*(leg.anchor as Vector3)
		var upper: float=hip.origin.distance_to(knee.origin)
		var lower: float=knee.origin.distance_to(foot.origin)
		var aim: Vector3=ankle-hip.origin
		var distance: float=aim.length()
		if distance<.001 or upper<.001 or lower<.001:continue
		var length: float=clampf(distance,absf(upper-lower)+.00001,upper+lower-.00001)
		maximum_reach_error=maxf(maximum_reach_error,absf(distance-length))
		var direction: Vector3=aim/distance
		var pole: Vector3=leg.forward
		pole-=direction*pole.dot(direction)
		if pole.length_squared()<.000001:continue
		pole= pole.normalized()
		var along: float=(upper*upper-lower*lower+length*length)/(2*length)
		var bend: float=sqrt(maxf(0,upper*upper-along*along))
		var wanted_knee: Vector3=hip.origin+direction*along+pole*bend
		var turn:=Quaternion((knee.origin-hip.origin).normalized(),(wanted_knee-hip.origin).normalized())
		if not write.call(ids[0],Transform3D(Basis(turn)*hip.basis,hip.origin),"contact"):continue
		knee=skeleton.get_bone_global_pose(ids[1]);foot=skeleton.get_bone_global_pose(ids[2])
		var reached: Vector3=hip.origin+direction*length
		turn=Quaternion((foot.origin-knee.origin).normalized(),(reached-knee.origin).normalized())
		if not write.call(ids[1],Transform3D(Basis(turn)*knee.basis,knee.origin),"contact"):continue
		foot=skeleton.get_bone_global_pose(ids[2])
		var settled:=Transform3D(desired_basis,foot.origin)
		if not write.call(ids[2],settled,"contact"):continue
		write.call(ids[3],settled*(leg.toe_relative as Transform3D),"contact")
