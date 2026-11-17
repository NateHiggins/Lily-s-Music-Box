extends RefCounted
## Fixed-footrest seating only. Navigation/seat height stay with their owners.
## Anchors come from actual morphed worn shoe vertices in the rig's rest frame.
## All writes go through PosePipeline's contact slot, before SkirtFollow.
var legs: Array[Dictionary] = []
var _ridge: Array[Vector3]=[]
var _ring_centre:=Vector3.ZERO
var _ring_front:=Vector3.ZERO
var _ring_right:=Vector3.ZERO
var errors: Array[String] = []
var maximum_reach_error := 0.0

func bind(actor: Node3D, targets: Array[Vector3], resident: String, ridge: Array[Vector3]) -> bool:
	var skeleton: Skeleton3D=actor.skeleton
	if targets.size()!=2 or ridge.size()!=32:return false
	_ridge=ridge.duplicate()
	for p: Vector3 in _ridge:_ring_centre+=p/float(_ridge.size())
	_ring_front=((targets[0]+targets[1])*.5-_ring_centre).normalized()
	_ring_right=(targets[1]-targets[0]).normalized()
	var profile: RefCounted=actor.attention.pipeline.profile
	# A level footrest follows gravity, not the rig's leaning pelvis-to-neck axis.
	var up: Vector3=(skeleton.global_basis.inverse()*Vector3.UP).normalized()
	var forward: Vector3=((profile.forward as Vector3)-up*(profile.forward as Vector3).dot(up)).normalized()
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
					var rigid_only:=true
					var total:=0.0
					for slot: int in stride:
						var k: int=vi*stride+slot
						if weights[k]<=0:continue
						var bind_index: int=bones[k]
						var bone: int=draw.skin.get_bind_bone(bind_index)
						if bone<0:bone=skeleton.find_bone(draw.skin.get_bind_name(bind_index))
						if bone<0:return false
						p+=(skeleton.get_bone_global_rest(bone)*draw.skin.get_bind_pose(bind_index)*vertices[vi])*weights[k]
						total+=weights[k]
						if str(skeleton.get_bone_name(bone)) not in [side+"Foot",side+"ToeBase"]:rigid_only=false
					# Imported UNORM16 rows can total65534/65535. Membership is
					# determined by every positive influence, never a near-one sum.
					if rigid_only and total>0.0:points.append(p)
		if points.is_empty():errors.append("no actual worn shoe vertices "+side);return false
		var front: float=-INF
		var back: float=INF
		for p: Vector3 in points:
			front=maxf(front,p.dot(forward));back=minf(back,p.dot(forward))
		# Use the actual lowest sole vertex. An arch-only search can place the heel
		# below the support plane even when its chosen anchor reaches the ring.
		var lateral: Vector3=up.cross(forward).normalized()
		var leftmost: float=INF
		var rightmost: float=-INF
		var lowest: float=INF
		for p: Vector3 in points:
			leftmost=minf(leftmost,p.dot(lateral));rightmost=maxf(rightmost,p.dot(lateral))
			lowest=minf(lowest,p.dot(up))
		var anchor:=Vector3.ZERO
		var best: float=INF
		for p: Vector3 in points:
			if p.dot(up)>lowest:continue
			var score: float=pow(p.dot(forward)-lerpf(back,front,.35),2)+pow(p.dot(lateral)-(leftmost+rightmost)*.5,2)
			if score<best:best=score;anchor=p
		if not is_finite(best):return false
		var rest: Transform3D=skeleton.get_bone_global_rest(ids[2])
		var target: Vector3=targets[side_index]+Vector3.UP*float(lifts[side_index])
		legs.append({"bones":ids,"anchor":rest.affine_inverse()*anchor,"foot_basis":rest.basis,
			"toe_relative":rest.affine_inverse()*skeleton.get_bone_global_rest(ids[3]),"target":target,"lift_m":float(lifts[side_index]),"side_sign":-1.0 if side_index==0 else 1.0,
			"forward":forward,"source_part":footwear,"source_anchor":anchor})
	return legs.size()==2

func apply(skeleton: Skeleton3D, write: Callable) -> void:
	for leg: Dictionary in legs:
		var ids: Array=leg.bones
		# Preserve the original thigh/seat pose. Only the lower leg and shoe turn.
		var knee: Transform3D=skeleton.get_bone_global_pose(ids[1])
		var foot: Transform3D=skeleton.get_bone_global_pose(ids[2])
		var world_from_skeleton: Transform3D=skeleton.global_transform
		var knee_world: Vector3=world_from_skeleton*knee.origin
		var length: float=(world_from_skeleton*foot.origin).distance_to(knee_world)
		var desired_basis: Basis=leg.foot_basis
		var offset: Vector3=world_from_skeleton.basis*(desired_basis*(leg.anchor as Vector3))
		var lift: Vector3=Vector3.UP*float(leg.lift_m)
		var best:=INF
		var ankle_world:=Vector3.ZERO
		for i: int in _ridge.size():
			var start: Vector3=_ridge[i]
			var delta: Vector3=_ridge[(i+1)%_ridge.size()]-start
			var from_knee: Vector3=start+lift-offset-knee_world
			var a: float=delta.length_squared()
			if a<1e-12:continue
			var b: float=2*from_knee.dot(delta)
			var c: float=from_knee.length_squared()-length*length
			var discriminant: float=b*b-4*a*c
			if discriminant<0:continue
			for root: float in [(-b-sqrt(discriminant))/(2*a),(-b+sqrt(discriminant))/(2*a)]:
				if root<0 or root>1:continue
				var point: Vector3=start+delta*root
				var radial: Vector3=point-_ring_centre
				if radial.dot(_ring_front)<0 or radial.dot(_ring_right)*float(leg.side_sign)<.04:continue
				var score: float=(point+lift).distance_squared_to(leg.target)
				if score<best:best=score;ankle_world=point+lift-offset
		if not is_finite(best):
			maximum_reach_error=INF
			continue
		var ankle: Vector3=world_from_skeleton.affine_inverse()*ankle_world
		var turn:=Quaternion((foot.origin-knee.origin).normalized(),(ankle-knee.origin).normalized())
		if not write.call(ids[1],Transform3D(Basis(turn)*knee.basis,knee.origin),"contact"):continue
		foot=skeleton.get_bone_global_pose(ids[2])
		maximum_reach_error=maxf(maximum_reach_error,(world_from_skeleton*foot.origin).distance_to(ankle_world))
		var settled:=Transform3D(desired_basis,foot.origin)
		if not write.call(ids[2],settled,"contact"):continue
		write.call(ids[3],settled*(leg.toe_relative as Transform3D),"contact")
