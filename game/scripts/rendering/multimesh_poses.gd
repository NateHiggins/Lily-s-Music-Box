extends RefCounted
## MultiMesh instance poses that read back the same under every renderer.
##
## Godot's headless (dummy) renderer keeps no MultiMesh instance data:
## MultiMesh.get_instance_transform() answers identity for every instance there.
## Owners that read their own poses back (trim splices, clearance surveys,
## collision shapes, anchors, key travel) therefore write through set_pose(),
## which also keeps a CPU copy on the MultiMesh resource, and read through
## pose(). Under a real renderer the copy and the renderer always agree.

const META := &"cpu_instance_poses"

static var _warned_headless_read := false


static func set_pose(multimesh: MultiMesh, index: int, at: Transform3D) -> void:
	multimesh.set_instance_transform(index, at)
	var poses: Array
	if multimesh.has_meta(META):
		poses = multimesh.get_meta(META)
	else:
		poses = []
		multimesh.set_meta(META, poses)
	if poses.size() != multimesh.instance_count:
		poses.resize(multimesh.instance_count)
	poses[index] = at


static func pose(multimesh: MultiMesh, index: int) -> Transform3D:
	if multimesh.has_meta(META):
		var poses: Array = multimesh.get_meta(META)
		if index < poses.size() and poses[index] is Transform3D:
			return poses[index]
	if not _warned_headless_read and DisplayServer.get_name() == "headless":
		_warned_headless_read = true
		push_warning("MultiMeshPoses: a pose written without set_pose() reads as identity under the headless renderer")
	return multimesh.get_instance_transform(index)
