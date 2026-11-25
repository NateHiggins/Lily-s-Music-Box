extends Node3D
## The first-person rubber-hose arm (Lily, 2026-11-24): a black-and-white cartoon
## arm that reaches in from the lower left while the player works something. It is
## presentation only. The grab owner keeps every mechanism, inventory and save
## authority. The arm reads the active grab and draws a hand on it.
##
## The jointless arm is an eight-bone chain bent along one drooping curve from an
## off-screen shoulder to the glove, so it reads as a hose with no elbow. It stretches
## rather than locking straight. The glove's fingers curl to grip. Model:
## art/blender/scripts/build_first_person_hose_arm.py. Shaders:
## hose_arm_cel.gdshader and hose_arm_outline.gdshader.

const MODEL := preload("res://assets/characters/player_hose_arm/hose_arm.glb")
const CEL := preload("res://shaders/hose_arm_cel.gdshader")
const OUTLINE := preload("res://shaders/hose_arm_outline.gdshader")
## Own render layer: the first-person camera draws it, and mirrors leave it out.
const LAYER := 1 << 16
const ARM_BONES := 8
const FINGERS := ["Index", "Middle", "Ring"]
## Camera-local shoulder, below and left of the frame; the set is held at the right.
const SHOULDER := Vector3(-0.30, -0.38, 0.06)
## Where the glove waits, just out of frame, on its way in and out.
const STOWED := Vector3(-0.22, -0.46, -0.20)
const PALM_FROM_WRIST := 0.052
const REACH_SECONDS := 0.16
const RETRACT_SECONDS := 0.18
const CURL_RATE := 9.0

var player: Node
var skeleton: Skeleton3D
var reach := 0.0          # 0 stowed .. 1 at the grip
var curl := 0.0           # 0 open .. 1 closed
var _rest_length := 0.55
var _arm_bones: Array[int] = []
var _hand := -1
var _fingers: Array[int] = []
var _thumbs: Array[int] = []
var _rest: Dictionary = {}
var _target := Vector3.ZERO
var _holding := false


func bind(owner_player: Node) -> bool:
	player = owner_player
	var camera: Camera3D = player.get("camera")
	if camera == null:
		return false
	camera.cull_mask |= LAYER
	position = SHOULDER
	var model := MODEL.instantiate() as Node3D
	model.name = "HoseArmModel"
	add_child(model)
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		return false
	skeleton = skeletons[0] as Skeleton3D
	for i in ARM_BONES:
		_arm_bones.append(skeleton.find_bone("Arm_%02d" % i))
	_hand = skeleton.find_bone("Hand")
	for finger: String in FINGERS:
		_fingers.append(skeleton.find_bone(finger + "_1"))
		_fingers.append(skeleton.find_bone(finger + "_2"))
	_thumbs = [skeleton.find_bone("Thumb_1"), skeleton.find_bone("Thumb_2")]
	if _arm_bones.has(-1) or _hand < 0 or _fingers.has(-1) or _thumbs.has(-1):
		return false
	for bone in skeleton.get_bone_count():
		_rest[bone] = skeleton.get_bone_global_rest(bone)
	_rest_length = (_rest[_hand] as Transform3D).origin.distance_to((_rest[_arm_bones[0]] as Transform3D).origin)
	for draw: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		draw.layers = LAYER
		draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for surface in draw.mesh.get_surface_count():
			var source := draw.mesh.surface_get_material(surface)
			draw.set_surface_override_material(surface, _finish(source.resource_name if source != null else ""))
	visible = false
	return true


## Ink for the hose and stitches, paper-white for the glove; both inked round.
func _finish(key: String) -> ShaderMaterial:
	var outline := ShaderMaterial.new()
	outline.shader = OUTLINE
	var fill := ShaderMaterial.new()
	fill.shader = CEL
	if key == "HoseGlove":
		fill.set_shader_parameter("tone", 0.96)
		fill.set_shader_parameter("shadow_tone", 0.72)
	else:
		fill.set_shader_parameter("tone", 0.05)
		fill.set_shader_parameter("shadow_tone", 0.4)
		fill.set_shader_parameter("shine", 0.9)
	fill.next_pass = outline
	return fill


func _process(delta: float) -> void:
	var grab: Object = player.get("_grab") if player != null else null
	var active: bool = grab != null and bool(grab.call("active")) and not bool(player.call("inspecting"))
	if active:
		var target: Dictionary = grab.get("target")
		var part := target.get("part") as Node3D
		if is_instance_valid(part):
			_target = part.to_global(grab.get("contact"))
			_holding = true
	elif not visible:
		return
	else:
		_holding = false
	var aim := 1.0 if _holding else 0.0
	var rate := delta / (REACH_SECONDS if _holding else RETRACT_SECONDS)
	reach = move_toward(reach, aim, rate)
	curl = move_toward(curl, aim, delta * CURL_RATE)
	visible = reach > 0.0
	if visible:
		_pose()


## A little overshoot on the way in: the cartoon reach.
static func _ease(t: float) -> float:
	var s := 1.70158
	var u := t - 1.0
	return 1.0 + u * u * ((s + 1.0) * u + s)


func _pose() -> void:
	var camera: Camera3D = player.get("camera")
	var stowed: Vector3 = camera.to_global(STOWED)
	var grip: Vector3 = _target if _holding or reach > 0.0 else stowed
	var palm: Vector3 = stowed.lerp(grip, _ease(reach))
	var space: Transform3D = skeleton.global_transform.affine_inverse()
	var shoulder: Vector3 = space * global_position
	var palm_local: Vector3 = space * palm
	var line: Vector3 = palm_local - shoulder
	var length := maxf(line.length(), 0.05)
	var forward := line / length
	var wrist := palm_local - forward * PALM_FROM_WRIST
	# The drooping hose: leave the shoulder forward and low, arrive along the reach.
	var down := (space.basis * Vector3.DOWN).normalized()
	var c1 := shoulder + forward * length * 0.35 + down * length * 0.18
	var c2 := wrist - forward * length * 0.25 + down * length * 0.10
	var points: Array[Vector3] = []
	for i in ARM_BONES + 1:
		points.append(_bezier(shoulder, c1, c2, wrist, float(i) / ARM_BONES))
	for i in ARM_BONES:
		var rest: Transform3D = _rest[_arm_bones[i]]
		var segment := points[i + 1] - points[i]
		var turn := Basis(Quaternion(rest.basis.y.normalized(), segment.normalized()))
		var frame := turn * rest.basis
		var stretch := segment.length() / maxf(rest.basis.y.length() * _rest_length / ARM_BONES, 0.0001)
		frame = frame.scaled_local(Vector3(1.0, stretch, 1.0))
		skeleton.set_bone_global_pose(_arm_bones[i], Transform3D(frame, points[i]))
	var hand_rest: Transform3D = _rest[_hand]
	var arrival := (wrist - points[ARM_BONES - 1]).normalized()
	skeleton.set_bone_global_pose(_hand, Transform3D(Basis(Quaternion(hand_rest.basis.y.normalized(), arrival)) * hand_rest.basis, wrist))
	for i in _fingers.size():
		var bend := (1.1 if i % 2 == 0 else 1.25) * curl
		skeleton.set_bone_pose_rotation(_fingers[i], skeleton.get_bone_rest(_fingers[i]).basis.get_rotation_quaternion() * Quaternion(Vector3.RIGHT, -bend))
	skeleton.set_bone_pose_rotation(_thumbs[0], skeleton.get_bone_rest(_thumbs[0]).basis.get_rotation_quaternion() * Quaternion(Vector3.RIGHT, -0.5 * curl) * Quaternion(Vector3.BACK, 0.6 * curl))


static func _bezier(a: Vector3, b: Vector3, c: Vector3, d: Vector3, t: float) -> Vector3:
	var u := 1.0 - t
	return a * u * u * u + b * 3.0 * u * u * t + c * 3.0 * u * t * t + d * t * t * t


## Where the drawn palm is now, for tests and reviews.
func palm_position() -> Vector3:
	if _hand < 0:
		return global_position
	var hand: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(_hand)
	return hand.origin + hand.basis.y.normalized() * PALM_FROM_WRIST
