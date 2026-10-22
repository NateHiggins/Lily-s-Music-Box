extends RefCounted
## Drives the native ring skin; no repair booleans or procedural replacement mesh.
var model: Node3D
var skeleton: Skeleton3D
var indices:=PackedInt32Array()
var rest:=PackedVector3Array()
var sides:=PackedVector3Array()
var parent_inverse: Array[Transform3D]=[]
var original_frames: Array[Transform3D]=[]
var configured:=false
var _material_transport:=false
var _rest_transport_twist:=PackedFloat64Array()
var _frame_points: Array[PackedVector3Array]=[]
var _frame_values: Array=[]
var strand:=preload("res://scripts/props/hose_length_constraint.gd").new()
func configure(root: Node3D,data: Dictionary) -> bool:
	if model!=null:return false
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
		var parent: int=skeleton.get_bone_parent(bone)
		parent_inverse.append(skeleton.get_bone_global_rest(parent).affine_inverse() if parent>=0 else Transform3D.IDENTITY)
	if not strand.configure(rest) or absf(strand.total_length-float(data.length_m))>.00002:return false
	var into_model: Transform3D=model.global_transform.affine_inverse()*skeleton.global_transform
	for i in indices.size():
		var original: Transform3D=into_model*skeleton.get_bone_global_rest(indices[i])
		if original.origin.distance_to(rest[i])>.00001:return false
		original_frames.append(original)
	configured=apply_points(rest)
	return configured
func enable_material_transport() -> bool:
	if not configured or rest.size()<6:return false
	_material_transport=true;_frame_points.clear();_frame_values.clear();_rest_transport_twist.clear()
	var baseline: Array[Transform3D]=_transported_frames(rest)
	if baseline.size()!=rest.size():_material_transport=false;return false
	# Preserve the authored rest roll relative to the rest Bishop frame.
	# Endpoint correction alone would retwist the stored three-dimensional lead.
	for i in rest.size():
		var tangent: Vector3=(rest[mini(i+1,rest.size()-1)]-rest[maxi(i-1,0)]).normalized()
		var original: Vector3=(sides[i]-tangent*tangent.dot(sides[i])).normalized()
		var transported: Vector3=(baseline[i].basis*original_frames[i].basis.inverse()*original).normalized()
		_rest_transport_twist.append(atan2(tangent.dot(transported.cross(original)),transported.dot(original)))
	var checked: Array[Transform3D]=_transported_frames(rest)
	for i in checked.size():
		if not checked[i].basis.is_equal_approx(original_frames[i].basis):_material_transport=false;return false
	if apply_points(strand.points):return true
	_material_transport=false;_frame_points.clear();_frame_values.clear();return false
func _transported_frames(points: PackedVector3Array) -> Array[Transform3D]:
	var tangents:=PackedVector3Array();var directors:=PackedVector3Array();directors.resize(points.size())
	for i in points.size():
		if not points[i].is_finite():return []
		var tangent: Vector3=points[mini(i+1,points.size()-1)]-points[maxi(i-1,0)]
		if tangent.length_squared()<1e-14:return []
		tangents.append(tangent.normalized())
	var last: int=points.size()-1
	var seed: Vector3=sides[last]-tangents[last]*tangents[last].dot(sides[last])
	if seed.length_squared()<1e-14:return []
	directors[last]=seed.normalized()
	# Transport between adjacent CURRENT tangents, never from an unrelated
	# rest tangent that can become antiparallel and flip one section's roll.
	for i in range(last-1,-1,-1):
		var turn: Quaternion=Quaternion(directors[i+1],PI) if tangents[i+1].dot(tangents[i])<-.999999 else Quaternion(tangents[i+1],tangents[i])
		var side: Vector3=turn*directors[i+1];side-=tangents[i]*tangents[i].dot(side)
		if side.length_squared()<1e-14:return []
		directors[i]=side.normalized()
	var head: Vector3=sides[0]-tangents[0]*tangents[0].dot(sides[0])
	if head.length_squared()<1e-14:return []
	head=head.normalized()
	var twist: float=atan2(tangents[0].dot(directors[0].cross(head)),directors[0].dot(head))
	var arc:=PackedFloat64Array();arc.resize(points.size());arc[0]=0.
	for i in range(1,points.size()):arc[i]=arc[i-1]+strand.lengths[i-1]
	var start: float=arc[2];var end: float=arc[points.size()-3]
	if end<=start:return []
	var frames: Array[Transform3D]=[]
	for i in points.size():
		var fraction: float=clampf((end-arc[i])/(end-start),0.,1.)
		var rest_twist: float=0. if _rest_transport_twist.is_empty() else _rest_transport_twist[i]
		var side: Vector3=directors[i].rotated(tangents[i],twist*fraction+rest_twist).normalized()
		var before: Vector3=(rest[mini(i+1,rest.size()-1)]-rest[maxi(i-1,0)]).normalized()
		var original_side: Vector3=(sides[i]-before*before.dot(sides[i])).normalized()
		var old_frame:=Basis(before,original_side,before.cross(original_side))
		var new_frame:=Basis(tangents[i],side,tangents[i].cross(side))
		frames.append(Transform3D(new_frame*old_frame.transposed()*original_frames[i].basis,points[i]))
	return frames
func model_frames(points: PackedVector3Array) -> Array[Transform3D]:
	if skeleton==null or rest.size()<3 or points.size()!=rest.size() or original_frames.size()!=rest.size():return []
	for i in _frame_points.size():
		if points==_frame_points[i]:
			# Keep the repeatedly reused pre-step pose when trial poses change.
			# FIFO eviction regenerated it on every second contact iteration.
			var cached: Array[Transform3D]=_frame_values[i]
			if i>0:
				var coordinates: PackedVector3Array=_frame_points[i]
				_frame_points.remove_at(i);_frame_values.remove_at(i)
				_frame_points.push_front(coordinates);_frame_values.push_front(cached)
			return cached.duplicate()
	var frames: Array[Transform3D]=[]
	if _material_transport:
		frames=_transported_frames(points)
		if frames.is_empty():return []
	else:
		for i in points.size():
			if not points[i].is_finite():return []
			var tangent: Vector3=points[mini(i+1,points.size()-1)]-points[maxi(i-1,0)]
			var before: Vector3=rest[mini(i+1,rest.size()-1)]-rest[maxi(i-1,0)]
			if tangent.length_squared()<1e-14 or before.length_squared()<1e-14:return []
			tangent=tangent.normalized();before=before.normalized()
			var side: Vector3=sides[i]-before*before.dot(sides[i])
			if side.length_squared()<1e-14:return []
			side=side.normalized()
			var turn: Quaternion=Quaternion(side,PI) if before.dot(tangent)<-.999999 else Quaternion(before,tangent)
			# Transport the actual native bind orientation rather than assuming an
			# importer bone-axis convention. Godot4 poses include their rest
			# transform; they are not deltas multiplied on top of that rest.
			var frame:=Transform3D(Basis(turn)*original_frames[i].basis,points[i])
			frames.append(frame)
	# Cache geometry only. Copy the coordinates so in-place solver edits cannot
	# silently retain an old frame, and never cache world collision answers.
	_frame_points.push_front(points.duplicate());_frame_values.push_front(frames.duplicate())
	if _frame_points.size()>2:_frame_points.pop_back();_frame_values.pop_back()
	return frames
func apply_points(points: PackedVector3Array) -> bool:
	var frames: Array[Transform3D]=model_frames(points)
	if frames.is_empty():return false
	var to_skeleton: Transform3D=skeleton.global_transform.affine_inverse()*model.global_transform
	for i in indices.size():
		var pose: Transform3D=parent_inverse[i]*to_skeleton*frames[i]
		skeleton.set_bone_pose_position(indices[i],pose.origin)
		skeleton.set_bone_pose_rotation(indices[i],pose.basis.get_rotation_quaternion())
		skeleton.set_bone_pose_scale(indices[i],pose.basis.get_scale())
	var bounds:=AABB(points[0],Vector3.ZERO)
	for p: Vector3 in points:bounds=bounds.expand(p)
	for draw: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):draw.custom_aabb=bounds.grow(.04)
	return true
func move_endpoint(goal: Vector3,contact_veto: Callable=Callable()) -> bool:
	if not configured:return false
	var before: PackedVector3Array=strand.points.duplicate()
	if not strand.move_endpoint(goal,contact_veto):return false
	if apply_points(strand.points):return true
	strand.points=before
	return false
func snapshot() -> Dictionary:return strand.snapshot() if configured else {}
func restore(value: Variant,contact_veto: Callable=Callable()) -> bool:
	if not configured:return false
	var before: PackedVector3Array=strand.points.duplicate()
	if not strand.restore(value,contact_veto):return false
	if apply_points(strand.points):return true
	strand.points=before
	return false
