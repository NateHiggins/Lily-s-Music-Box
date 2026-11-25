extends Node3D
## The first-person rubber-hose arm (Lily, 2026-11-24): a flat, black-and-white
## rubber-hose cartoon limb that reaches in from the lower left while the player
## works something. It is presentation only. The grab owner keeps every mechanism,
## inventory and save authority. The arm reads the active grab and draws a hand on it.
##
## How it moves, in the manner of a 1930s rubber-hose cartoon:
##  - It is drawn on twos: the pose changes 12 times a second, never in between.
##  - No elbow: an eight-bone chain bent along one drooping curve from an off-screen
##    shoulder to the glove, stretching rather than locking straight.
##  - It writhes like a snake: a wave runs down the hose in two crossed planes,
##    pinned at the shoulder and the wrist so the glove stays on what it holds.
##  - It keeps a rhythm: on a steady beat the hose's droop breathes, the glove bobs,
##    and the fingers roll over the grip one after another.
##  - Cartoon timing: a little pull-back before the reach, an overshoot on arrival,
##    and a rubbery wobble on the recoil when it lets go.
## Model: art/blender/scripts/build_first_person_hose_arm.py. Shaders:
## hose_arm_cel.gdshader (flat fill) and hose_arm_outline.gdshader (ink line).

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
const DRAWINGS_PER_SECOND := 12.0
const REACH_SECONDS := 0.20
const RETRACT_SECONDS := 0.22
const CURL_RATE := 8.0
## The beat the limb keeps, and the writhe that runs down it.
const BEATS_PER_MINUTE := 104.0
const WRITHE_WAVES := 1.35     # wavelengths along the hose
const WRITHE_SPEED := 1.6      # waves per second running toward the glove
const WRITHE_SIDE := 0.034     # metres, side to side
const WRITHE_LIFT := 0.022     # metres, up and down, a quarter-wave behind
const RECOIL_WRITHE := 2.4     # how much wilder the hose whips on the way out
const GLOVE_BOB := 0.008
## A cartoon glove is drawn big: it has to read at arm's length.
const GLOVE_SCALE := 1.6

var player: Node
var skeleton: Skeleton3D
var reach := 0.0          # 0 stowed .. 1 at the grip
var curl := 0.0           # 0 open .. 1 closed
var clock := 0.0          # drawing time, advancing in steps of a twelfth
var _since_drawing := 0.0
var _rest_length := 0.55
var _arm_bones: Array[int] = []
var _hand := -1
var _fingers: Array[int] = []
var _thumbs: Array[int] = []
var _rest: Dictionary = {}
var _target := Vector3.ZERO
var _holding := false
var _recoil := 0.0


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


## Flat paper white for the glove, flat ink for the hose and stitches; all inked round.
func _finish(key: String) -> ShaderMaterial:
	var outline := ShaderMaterial.new()
	outline.shader = OUTLINE
	var fill := ShaderMaterial.new()
	fill.shader = CEL
	fill.set_shader_parameter("tone", 0.97 if key == "HoseGlove" else 0.02)
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
			if not _holding:
				_recoil = 0.0
			_holding = true
	elif not visible:
		return
	elif _holding:
		_holding = false
		_recoil = 1.0
	# Drawn on twos: advance and redraw only when the next drawing is due.
	_since_drawing += delta
	var step := 1.0 / DRAWINGS_PER_SECOND
	if _since_drawing < step:
		return
	var elapsed := _since_drawing
	_since_drawing = fmod(_since_drawing, step)
	elapsed -= _since_drawing
	clock += elapsed
	var aim := 1.0 if _holding else 0.0
	reach = move_toward(reach, aim, elapsed / (REACH_SECONDS if _holding else RETRACT_SECONDS))
	curl = move_toward(curl, aim, elapsed * CURL_RATE)
	_recoil = move_toward(_recoil, 0.0, elapsed * 3.0)
	visible = reach > 0.0
	if visible:
		_pose()


## Anticipation, then an overshoot: pull back a little, then fling past and settle.
static func _ease(t: float) -> float:
	if t < 0.18:
		return -0.12 * sin(t / 0.18 * PI)
	var u := (t - 0.18) / 0.82 - 1.0
	var s := 2.2
	return 1.0 + u * u * ((s + 1.0) * u + s)


## The beat, as a bounce that is 1 on the beat and falls away between.
func beat() -> float:
	var phase := fmod(clock * BEATS_PER_MINUTE / 60.0, 1.0)
	return pow(1.0 - phase, 2.0)


func _pose() -> void:
	var camera: Camera3D = player.get("camera")
	var stowed: Vector3 = camera.to_global(STOWED)
	var palm: Vector3 = stowed.lerp(_target, _ease(reach))
	var space: Transform3D = skeleton.global_transform.affine_inverse()
	var bounce := beat()
	var down := (space.basis * Vector3.DOWN).normalized()
	var shoulder: Vector3 = space * global_position
	var palm_local: Vector3 = space * palm - down * GLOVE_BOB * bounce * reach
	var line: Vector3 = palm_local - shoulder
	var length := maxf(line.length(), 0.05)
	var forward := line / length
	var wrist := palm_local - forward * PALM_FROM_WRIST * GLOVE_SCALE
	# The drooping hose breathes on the beat.
	var droop := 1.0 + 0.35 * bounce
	var c1 := shoulder + forward * length * 0.35 + down * length * 0.18 * droop
	var c2 := wrist - forward * length * 0.25 + down * length * 0.10 * droop
	# The writhe: a two-plane wave running toward the glove, pinned at both ends.
	var side := forward.cross(down).normalized()
	var lift := side.cross(forward).normalized()
	var wild := 1.0 + RECOIL_WRITHE * _recoil
	var points: Array[Vector3] = []
	for i in ARM_BONES + 1:
		var t := float(i) / ARM_BONES
		var phase := TAU * (WRITHE_WAVES * t - WRITHE_SPEED * clock)
		var pinned := sin(PI * t)
		var wave := side * sin(phase) * WRITHE_SIDE + lift * sin(phase - PI * 0.5) * WRITHE_LIFT
		points.append(_bezier(shoulder, c1, c2, wrist, t) + wave * pinned * wild * minf(1.0, length / 0.4))
	for i in ARM_BONES:
		var rest: Transform3D = _rest[_arm_bones[i]]
		var segment := points[i + 1] - points[i]
		var turn := Basis(Quaternion(rest.basis.y.normalized(), segment.normalized()))
		var stretch := segment.length() / maxf(_rest_length / ARM_BONES, 0.0001)
		var frame := (turn * rest.basis).scaled_local(Vector3(1.0, stretch, 1.0))
		skeleton.set_bone_global_pose(_arm_bones[i], Transform3D(frame, points[i]))
	var hand_rest: Transform3D = _rest[_hand]
	var arrival := (wrist - points[ARM_BONES - 1]).normalized()
	skeleton.set_bone_global_pose(_hand, Transform3D((Basis(Quaternion(hand_rest.basis.y.normalized(), arrival)) * hand_rest.basis).scaled_local(Vector3.ONE * GLOVE_SCALE), wrist))
	# The fingers roll over the grip on the beat, one after another.
	for i in _fingers.size():
		var finger := i >> 1
		var roll := 0.12 * sin(TAU * (clock * BEATS_PER_MINUTE / 60.0) - float(finger) * 0.9) * curl
		var bend := ((1.1 if i % 2 == 0 else 1.25) * curl) + roll
		skeleton.set_bone_pose_rotation(_fingers[i], skeleton.get_bone_rest(_fingers[i]).basis.get_rotation_quaternion() * Quaternion(Vector3.RIGHT, -bend))
	var tap := 0.15 * bounce * curl
	skeleton.set_bone_pose_rotation(_thumbs[0], skeleton.get_bone_rest(_thumbs[0]).basis.get_rotation_quaternion() * Quaternion(Vector3.RIGHT, -0.5 * curl - tap) * Quaternion(Vector3.BACK, 0.6 * curl))


static func _bezier(a: Vector3, b: Vector3, c: Vector3, d: Vector3, t: float) -> Vector3:
	var u := 1.0 - t
	return a * u * u * u + b * 3.0 * u * u * t + c * 3.0 * u * t * t + d * t * t * t


## Where the drawn palm is now, for tests and reviews.
func palm_position() -> Vector3:
	if _hand < 0:
		return global_position
	var hand: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(_hand)
	return hand.origin + hand.basis.y.normalized() * PALM_FROM_WRIST * GLOVE_SCALE
