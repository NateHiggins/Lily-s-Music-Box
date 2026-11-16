extends SkeletonModifier3D
## Test-only sole pose owner on one isolated current presentation.
var actor: Node3D
var skeleton: Skeleton3D
var model: Node3D
var person_id := ""
var _stand: RefCounted
var pipeline: SkeletonModifier3D
var soles: Dictionary = {}
var contact_math: RefCounted
var role := ""
var enabled := false
var writers: Dictionary = {}
var refused_writes := 0
var faults: Array[String] = []
func _write(bone: int, pose: Transform3D, layer: String) -> bool:
	if bone < 0 or writers.has(bone) or not pose.is_finite():
		refused_writes += 1; return false
	writers[bone] = layer
	skeleton.set_bone_global_pose(bone,pose)
	return true
func _process_modification() -> void:
	if not enabled: return
	writers.clear()
	if not _stand.apply(skeleton,"__physical_candidate",false,0.0,0.0):
		faults.append("current technical base pose refused"); return
	if role == "piano": contact_math._piano(self)
	elif role == "drums": contact_math._drums(self)
	elif role == "carry":contact_math._carry(self)
