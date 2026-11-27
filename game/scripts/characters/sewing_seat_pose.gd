extends RefCounted
## Lena-only authored base-pose blend. Never moves the actor or a chair.
## Called inside PosePipeline before its posture/gaze/contact composition.
var amount := 0.0
var clock := 0.0
var clip: Animation
var allowed: Callable
var tracks: Array[Dictionary] = []

func predicted_globals(body: Skeleton3D, standing: Animation, standing_time: float, weight: float) -> Array[Transform3D]:
	var before:=_sample(body,standing,standing_time)
	var after:=_sample(body,clip,clock)
	var result: Array[Transform3D]=[]
	for bone in body.get_bone_count():
		var local:=before[bone].interpolate_with(after[bone],weight)
		var parent:=body.get_bone_parent(bone)
		if parent>=bone:return []
		result.append(local if parent<0 else result[parent]*local)
	return result

func _sample(body: Skeleton3D, animation: Animation, seconds: float) -> Array[Transform3D]:
	var poses: Array[Transform3D]=[]
	for bone in body.get_bone_count():poses.append(body.get_bone_rest(bone))
	for track in animation.get_track_count():
		var path:=animation.track_get_path(track)
		if path.get_subname_count()!=1:continue
		var bone:=body.find_bone(str(path.get_subname(0)))
		if bone<0:continue
		match animation.track_get_type(track):
			Animation.TYPE_POSITION_3D:poses[bone].origin=animation.position_track_interpolate(track,seconds)
			Animation.TYPE_ROTATION_3D:poses[bone].basis=Basis(animation.rotation_track_interpolate(track,seconds)).scaled(poses[bone].basis.get_scale())
			Animation.TYPE_SCALE_3D:poses[bone].basis=poses[bone].basis.orthonormalized().scaled(animation.scale_track_interpolate(track,seconds))
	return poses

func bind(body: Skeleton3D, animation: Animation, permitted: Callable) -> bool:
	if animation==null or not permitted.is_valid():return false
	clip=animation;allowed=permitted
	for track in clip.get_track_count():
		var kind:=clip.track_get_type(track)
		if kind not in [Animation.TYPE_POSITION_3D,Animation.TYPE_ROTATION_3D,Animation.TYPE_SCALE_3D]:continue
		var path:=clip.track_get_path(track)
		if path.get_subname_count()!=1:return false
		var bone:=body.find_bone(str(path.get_subname(0)))
		if bone<0:return false
		tracks.append({"track":track,"bone":bone,"kind":kind})
	return not tracks.is_empty()

func apply_base(body: Skeleton3D, delta: float) -> void:
	if not allowed.is_valid() or not allowed.call() or amount<=0.0:return
	clock=fposmod(clock+delta,clip.length)
	for item: Dictionary in tracks:
		var bone: int=item.bone
		match int(item.kind):
			Animation.TYPE_POSITION_3D:
				body.set_bone_pose_position(bone,body.get_bone_pose_position(bone).lerp(clip.position_track_interpolate(item.track,clock),amount))
			Animation.TYPE_ROTATION_3D:
				body.set_bone_pose_rotation(bone,body.get_bone_pose_rotation(bone).slerp(clip.rotation_track_interpolate(item.track,clock),amount))
			Animation.TYPE_SCALE_3D:
				body.set_bone_pose_scale(bone,body.get_bone_pose_scale(bone).lerp(clip.scale_track_interpolate(item.track,clock),amount))
