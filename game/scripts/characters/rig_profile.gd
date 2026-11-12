extends RefCounted
## What a skeleton can do, in the pose pipeline's own words. The cast's rigs
## share bone names but not rest poses or bone frames (seven residents carry
## their hips frame turned, Mina's arm axes are flipped), so nothing here
## trusts a bone's axes. A profile names the semantic joints and measures every
## direction it needs from the rest pose itself: which way the head faces,
## which way is up, where the chest looks. The pipeline then works in the
## model's own space and is the same code on every body.

const DATA := "res://data/characters/rig_profiles.json"

var family := ""
var skeleton: Skeleton3D
## Semantic joint name to bone index.
var bones: Dictionary = {}
var lacks: Array = []
## In skeleton space at rest: the way the face looks and the way the crown points.
var forward := Vector3.FORWARD
var up := Vector3.UP
## The same two directions in the head bone's own rest frame, so the head's
## present facing can be read from any animated pose.
var head_forward_local := Vector3.FORWARD
var head_up_local := Vector3.UP
var gaze_yaw := 1.0
var gaze_pitch := 0.5
var chest_share := 0.18
var neck_share := 0.42
var breath_radians := 0.0
var breath_seconds := 4.0
var errors: Array[String] = []
## Optional semantic rest landmarks for bodies without an artificial face marker.
var _rest_frame: Dictionary = {}


## The profile for a skeleton, or null when no family fits it.
static func for_skeleton(body: Skeleton3D) -> RefCounted:
	var document: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if document is not Dictionary or int(document.get("schema_version", 0)) != 1 or document.get("families") is not Array:
		return null
	for row: Dictionary in document.families:
		var fits := true
		for bone_name: Variant in row.get("detect", []):
			fits = fits and _find(body, [str(bone_name), str(bone_name).replace(".", "_")]) >= 0
		if not fits:
			continue
		var profile: RefCounted = (load("res://scripts/characters/rig_profile.gd") as GDScript).new()
		profile.family = str(row.id)
		profile.skeleton = body
		profile._rest_frame = row.get("rest_frame", {})
		if row.has("bone_count") and body.get_bone_count() != int(row.bone_count):
			profile.errors.append("%s expected %d bones, found %d" % [profile.family, int(row.bone_count), body.get_bone_count()])
		for joint: Dictionary in row.joints:
			var index := _find(body, joint.names)
			if index < 0:
				profile.errors.append("%s has no %s" % [profile.family, str(joint.joint)])
			profile.bones[str(joint.joint)] = index
		profile.lacks = row.get("lacks", [])
		var gaze: Dictionary = row.gaze
		profile.gaze_yaw = deg_to_rad(float(gaze.yaw_degrees))
		profile.gaze_pitch = deg_to_rad(float(gaze.pitch_degrees))
		profile.chest_share = float(gaze.chest_share)
		profile.neck_share = float(gaze.neck_share)
		var breath: Dictionary = row.breath
		profile.breath_radians = deg_to_rad(float(breath.degrees))
		profile.breath_seconds = float(breath.seconds)
		profile._measure()
		return profile
	return null


static func _find(body: Skeleton3D, names: Array) -> int:
	for candidate: Variant in names:
		var index := body.find_bone(str(candidate))
		if index >= 0:
			return index
	return -1


func has(joint: String) -> bool:
	return int(bones.get(joint, -1)) >= 0


func can(control: String) -> bool:
	return control not in lacks


## Read the rest pose: where the face looks and where the crown points.
func _measure() -> void:
	if not _rest_frame.is_empty():
		_measure_landmarks()
		return
	if not (has("head") and has("head_front")):
		errors.append("%s cannot be measured: no head or no face marker" % family)
		return
	var head := skeleton.get_bone_global_rest(int(bones.head))
	var front := skeleton.get_bone_global_rest(int(bones.head_front))
	var facing := front.origin - head.origin
	if facing.length() < 0.001:
		errors.append("%s has its face marker on the head bone" % family)
		return
	forward = facing.normalized()
	var crown := Vector3.UP
	if has("head_top"):
		crown = skeleton.get_bone_global_rest(int(bones.head_top)).origin - head.origin
	# Up is the crown's direction with any lean toward the face taken out.
	crown = crown - forward * crown.dot(forward)
	up = crown.normalized() if crown.length() > 0.001 else Vector3.UP
	# The face marker sits forward and often a little below the head bone; the
	# way the face looks is level.
	var level := forward - up * forward.dot(up)
	if level.length() > 0.001:
		forward = level.normalized()
	head_forward_local = head.basis.orthonormalized().inverse() * forward
	head_up_local = head.basis.orthonormalized().inverse() * up


## Bilateral foot/toe landmarks define forward; pelvis-to-neck defines up.
## These are measured rest positions in skeleton space, never a guessed yaw
## or a bone-axis convention. No pose is written and no marker bone is added.
func _landmark_mean(joints: Array) -> Vector3:
	if joints.is_empty():
		errors.append("%s has an empty rest-frame landmark group" % family)
		return Vector3.ZERO
	var total := Vector3.ZERO
	for joint: Variant in joints:
		if not has(str(joint)):
			errors.append("%s lacks rest-frame landmark %s" % [family, str(joint)])
			return Vector3.ZERO
		total += skeleton.get_bone_global_rest(int(bones[str(joint)])).origin
	return total / float(joints.size())


func _measure_landmarks() -> void:
	if not has("head"):
		errors.append("%s has no head" % family)
		return
	var facing := _landmark_mean(_rest_frame.get("forward_to", [])) - _landmark_mean(_rest_frame.get("forward_from", []))
	var crown := _landmark_mean(_rest_frame.get("up_to", [])) - _landmark_mean(_rest_frame.get("up_from", []))
	if not errors.is_empty():
		return
	if facing.length() < 0.001 or crown.length() < 0.001:
		errors.append("%s has coincident rest-frame landmarks" % family)
		return
	up = crown.normalized()
	var level := facing - up * facing.dot(up)
	if level.length() < 0.001:
		errors.append("%s has parallel forward and up landmarks" % family)
		return
	forward = level.normalized()
	var head := skeleton.get_bone_global_rest(int(bones.head))
	head_forward_local = head.basis.orthonormalized().inverse() * forward
	head_up_local = head.basis.orthonormalized().inverse() * up
