extends RefCounted
## Standing poses, written by hand as numbers and built on the skeleton each
## frame. No motion capture: a pose is a short table of directions in degrees
## (res://data/characters/stand_poses.json), so any of it can be adjusted by
## editing a number and looking again.
##
## How a pose is written
##   hips    turn, tilt (one hip up), shift_x and shift_z in metres
##   spine   forward, side, twist: shared between the three spine bones
##   head    nod, turn, tilt: shared between neck and head
##   each side (left, right):
##     shoulder   degrees raised
##     arm, forearm   [down, heading]: down is degrees below level;
##                heading is 0 out to the side, 90 forward, 180 across the
##                body, negative behind
##     thigh, shin   [out, forward] from straight down
##     foot       degrees turned out
##     hand_turn  degrees the hand turns about the forearm
##     curl       how far the fingers close
## Directions are the character's own, so a pose fits any body on this skeleton.
## A little breathing and sway is added on top. Feet stay on the floor: the
## hips are lowered or raised to keep the lower foot where it rests.

const DATA := "res://data/characters/stand_poses.json"
const SIDES: Array[String] = ["Left", "Right"]
const FINGERS: Array[String] = ["Thumb", "Index", "Middle", "Ring", "Pinky"]

var poses: Dictionary = {}
var people: Dictionary = {}
## Which way fingers close; set once by looking.
var curl_sign := -1.0


func load_table(path: String = DATA) -> bool:
	var document: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if document is not Dictionary or int(document.get("schema_version", 0)) != 1:
		return false
	poses.clear()
	people.clear()
	for row: Dictionary in document.get("poses", []):
		poses[str(row.get("name", ""))] = row
	for row: Dictionary in document.get("people", []):
		people[str(row.get("id", ""))] = row
	return not poses.is_empty()


## The pose a person stands in by habit, and whether it is mirrored.
func habit(person: String) -> Array:
	var row: Dictionary = people.get(person, {})
	return [str(row.get("pose", "at_ease")), bool(row.get("mirror", false))]


static func _turn(axis: Vector3, degrees: float) -> Basis:
	return Basis(axis, deg_to_rad(degrees))


static func _arc(from: Vector3, to: Vector3) -> Basis:
	var a := from.normalized()
	var b := to.normalized()
	var axis := a.cross(b)
	if axis.length() < 1e-5:
		return Basis.IDENTITY
	return Basis(axis.normalized(), a.angle_to(b))


static func _pair(value: Variant, first: float, second: float) -> Vector2:
	if value is Array and (value as Array).size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2(first, second)


## Put `pose_name` on the skeleton. `time` drives the breathing and sway.
func apply(skeleton: Skeleton3D, pose_name: String, mirror: bool = false, time: float = 0.0, life: float = 1.0) -> bool:
	var pose: Dictionary = poses.get(pose_name, {})
	if pose.is_empty() or skeleton == null:
		return false
	var flip := -1.0 if mirror else 1.0
	var hips: Dictionary = pose.get("hips", {})
	var spine: Dictionary = pose.get("spine", {})
	var head: Dictionary = pose.get("head", {})
	var breath := sin(time * 1.3) * life
	var sway := sin(time * 0.47) * life
	var hips_turn := _turn(Vector3.UP, float(hips.get("turn", 0.0)) * flip)
	var deltas: Array[Basis] = []
	var globals: Array[Basis] = []
	var origins: Array[Vector3] = []
	deltas.resize(skeleton.get_bone_count())
	globals.resize(skeleton.get_bone_count())
	origins.resize(skeleton.get_bone_count())
	var hips_bone := skeleton.find_bone("Hips")
	var feet: Array[int] = [skeleton.find_bone("LeftFoot"), skeleton.find_bone("RightFoot")]
	for bone in skeleton.get_bone_count():
		var label := skeleton.get_bone_name(bone)
		var parent := skeleton.get_bone_parent(bone)
		var before: Basis = deltas[parent] if parent >= 0 else Basis.IDENTITY
		var rest := skeleton.get_bone_global_rest(bone)
		var side := ""
		var sign := 1.0
		for name: String in SIDES:
			if label.begins_with(name):
				side = name
				sign = 1.0 if name == "Left" else -1.0
		# A mirrored pose reads the other side's numbers.
		var written := side
		if mirror and side != "":
			written = "Right" if side == "Left" else "Left"
		var limb: Dictionary = pose.get(written.to_lower(), {}) if side != "" else {}
		var part := label.trim_prefix(side)
		var delta := before
		if label == "Hips":
			delta = hips_turn * _turn(Vector3.BACK, float(hips.get("tilt", 0.0)) * flip)
		elif label.begins_with("Spine"):
			delta = before * _turn(Vector3.BACK, (float(spine.get("side", 0.0)) * flip) / 3.0) \
					* _turn(Vector3.RIGHT, (float(spine.get("forward", 0.0)) + 0.5 * breath) / 3.0) \
					* _turn(Vector3.UP, (float(spine.get("twist", 0.0)) * flip) / 3.0)
		elif label == "Neck" or label == "Head":
			delta = before * _turn(Vector3.UP, (float(head.get("turn", 0.0)) * flip + 1.5 * sin(time * 0.31) * life) / 2.0) \
					* _turn(Vector3.RIGHT, float(head.get("nod", 0.0)) / 2.0) \
					* _turn(Vector3.BACK, (float(head.get("tilt", 0.0)) * flip) / 2.0)
		elif part == "Shoulder":
			delta = before * _turn(Vector3.BACK, sign * (float(limb.get("shoulder", 0.0)) + 0.6 * breath))
		elif part in ["Arm", "ForeArm", "UpLeg", "Leg"]:
			var want: Vector3
			if part in ["Arm", "ForeArm"]:
				var angles := _pair(limb.get("arm" if part == "Arm" else "forearm"), 82.0, 20.0)
				var down := deg_to_rad(angles.x)
				var heading := deg_to_rad(angles.y)
				want = Vector3(sign * cos(down) * cos(heading), -sin(down), cos(down) * sin(heading))
			else:
				var angles := _pair(limb.get("thigh" if part == "UpLeg" else "shin"), 3.0, 0.0)
				want = _turn(Vector3.RIGHT, -angles.y) * Vector3(sign * sin(deg_to_rad(angles.x)), -cos(deg_to_rad(angles.x)), 0.0)
			want = hips_turn * want
			var child := -1
			for other: int in skeleton.get_bone_children(bone):
				if skeleton.get_bone_name(other).begins_with(side) and not skeleton.get_bone_name(other).contains("Skirt"):
					child = other
					break
			if child >= 0:
				var rest_way := (skeleton.get_bone_global_rest(child).origin - rest.origin).normalized()
				delta = _arc(before * rest_way, want) * before
		elif part == "Hand":
			# The hand turns about the forearm: palms to the thigh, not to the front.
			var along := (before * (rest.origin - skeleton.get_bone_global_rest(parent).origin)).normalized()
			delta = Basis(along, deg_to_rad(sign * float(limb.get("hand_turn", 0.0)))) * before
		elif part == "Foot" or part == "ToeBase":
			delta = hips_turn * _turn(Vector3.UP, sign * (float(limb.get("foot", 10.0)) - 8.0))
		elif side != "" and part.begins_with("Hand") and part != "Hand":
			var index_bone := skeleton.find_bone(side + "HandIndex1")
			var pinky_bone := skeleton.find_bone(side + "HandPinky1")
			if index_bone >= 0 and pinky_bone >= 0:
				var hand_delta: Basis = deltas[skeleton.find_bone(side + "Hand")]
				var across := (hand_delta * (skeleton.get_bone_global_rest(index_bone).origin - skeleton.get_bone_global_rest(pinky_bone).origin)).normalized()
				var amount := float(limb.get("curl", 26.0)) * (0.4 if part.contains("Thumb") else 1.0)
				delta = Basis(across, deg_to_rad(amount) * sign * curl_sign) * before
		deltas[bone] = delta
		globals[bone] = delta * rest.basis
		var local_origin := skeleton.get_bone_rest(bone).origin
		if parent >= 0:
			origins[bone] = origins[parent] + globals[parent] * local_origin
			skeleton.set_bone_pose_rotation(bone, (globals[parent].inverse() * globals[bone]).orthonormalized().get_rotation_quaternion())
		else:
			origins[bone] = local_origin
			skeleton.set_bone_pose_rotation(bone, globals[bone].orthonormalized().get_rotation_quaternion())
	# The lower foot stays where it rests: the hips take up the difference.
	if hips_bone >= 0:
		var drop := 0.0
		var found := false
		for foot: int in feet:
			if foot < 0:
				continue
			var lifted := origins[foot].y - skeleton.get_bone_global_rest(foot).origin.y
			drop = lifted if not found else minf(drop, lifted)
			found = true
		var parent_basis := Basis.IDENTITY
		var hips_parent := skeleton.get_bone_parent(hips_bone)
		if hips_parent >= 0:
			parent_basis = globals[hips_parent]
		var shift := Vector3(float(hips.get("shift_x", 0.0)) * flip + 0.004 * sway, -drop, float(hips.get("shift_z", 0.0)))
		skeleton.set_bone_pose_position(hips_bone, skeleton.get_bone_rest(hips_bone).origin + parent_basis.inverse() * shift)
	return true
