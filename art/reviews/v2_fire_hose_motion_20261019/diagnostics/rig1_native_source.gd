extends RefCounted
## Drives the native ring skin; no repair booleans or procedural replacement mesh.
var model: Node3D
var skeleton: Skeleton3D
var indices:=PackedInt32Array()
var rest:=PackedVector3Array()
var sides:=PackedVector3Array()
var inverse_rests: Array[Transform3D]=[]
var parent_inverse: Array[Transform3D]=[]
var original_frames: Array[Transform3D]=[]
var strand:=preload("res://scripts/props/hose_length_constraint.gd").new()
func configure(root: Node3D,data: Dictionary) -> bool:
	if data.size()!=5 or data.get("schema_version")!=1:return false
	if data.get("bone_names") is not Array or data.get("points") is not Array or data.get("sides") is not Array:return false
	if data.bone_names.size()!=data.points.size() or data.sides.size()!=data.points.size():return false
	if typeof(data.get("length_m")) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(data.length_m)):return false
	var found: Array[Node]=root.find_children("*","Skeleton3D",true,false)
	if found.size()!=1:return false
	model=root;skeleton=found[0]
	for i in data.points.size():
		if data.points[i] is not Array or data.points[i].size()!=3 or data.sides[i] is not Array or data.sides[i].size()!=3:return false
		for value: Variant in data.points[i]+data.sides[i]:
			if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)):return false
		var bone: int=skeleton.find_bone(str(data.bone_names[i]))
		if bone<0 or bone in indices:return false
		indices.append(bone);rest.append(Vector3(data.points[i][0],data.points[i][1],data.points[i][2]));sides.append(Vector3(data.sides[i][0],data.sides[i][1],data.sides[i][2]))
		inverse_rests.append(skeleton.get_bone_rest(bone).affine_inverse())
		var parent: int=skeleton.get_bone_parent(bone)
		parent_inverse.append(skeleton.get_bone_global_rest(parent).affine_inverse() if parent>=0 else Transform3D.IDENTITY)
	if not strand.configure(rest) or absf(strand.total_length-float(data.length_m))>.00002:return false
	var into_model: Transform3D=model.global_transform.affine_inverse()*skeleton.global_transform
	for i in indices.size():
		var original: Transform3D=into_model*skeleton.get_bone_global_rest(indices[i])
		if original.origin.distance_to(rest[i])>.00001:return false
		original_frames.append(original)
	return apply_points(rest)
func apply_points(points: PackedVector3Array) -> bool:
	if points.size()!=rest.size():return false
	var frames: Array[Transform3D]=[]
	var to_skeleton: Transform3D=skeleton.global_transform.affine_inverse()*model.global_transform
	for i in points.size():
		if not points[i].is_finite():return false
		var tangent: Vector3=points[mini(i+1,points.size()-1)]-points[maxi(i-1,0)]
		var before: Vector3=rest[mini(i+1,rest.size()-1)]-rest[maxi(i-1,0)]
		if tangent.length_squared()<1e-14 or before.length_squared()<1e-14:return false
		tangent=tangent.normalized();before=before.normalized()
		var side: Vector3=sides[i]-before*before.dot(sides[i])
		if side.length_squared()<1e-14:return false
		side=side.normalized()
		var turn: Quaternion=Quaternion(side,PI) if before.dot(tangent)<-.999999 else Quaternion(before,tangent)
		# Transport the actual native bind orientation rather than assuming an
		# importer bone-axis convention. At rest every pose remains identity.
		var frame:=Transform3D(Basis(turn)*original_frames[i].basis,points[i])
		frames.append(inverse_rests[i]*parent_inverse[i]*to_skeleton*frame)
	for i in indices.size():
		skeleton.set_bone_pose_position(indices[i],frames[i].origin)
		skeleton.set_bone_pose_rotation(indices[i],frames[i].basis.get_rotation_quaternion())
		skeleton.set_bone_pose_scale(indices[i],Vector3.ONE)
	var bounds:=AABB(points[0],Vector3.ZERO)
	for p: Vector3 in points:bounds=bounds.expand(p)
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):draw.custom_aabb=bounds.grow(.04)
	return true
func move_endpoint(goal: Vector3,contact_veto: Callable=Callable()) -> bool:
	var before: PackedVector3Array=strand.points.duplicate()
	if not strand.move_endpoint(goal,contact_veto):return false
	if apply_points(strand.points):return true
	strand.points=before
	return false
func snapshot() -> Dictionary:return strand.snapshot()
func restore(value: Variant,contact_veto: Callable=Callable()) -> bool:
	var before: PackedVector3Array=strand.points.duplicate()
	if not strand.restore(value,contact_veto):return false
	if apply_points(strand.points):return true
	strand.points=before
	return false
