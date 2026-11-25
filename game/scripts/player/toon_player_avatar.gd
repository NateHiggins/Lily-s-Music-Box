extends Node3D
## The player's body as a 1930s rubber-hose cartoon of Lily (Lily, 2026-11-25): flat
## black and white, ink-lined, in a maid's outfit, drawn and moved like the first-person
## rubber-hose arm. It is presentation only. The controller owns motion; nothing here
## moves, saves or collides. It draws only on the avatar layer, so mirrors see it and
## the first-person eye does not, and it animates only while a mirror shows it.
##
## How it moves, in the manner of the first-person arm:
##  - Every limb is a jointless hose: a bezier from shoulder or hip to the wrist or
##    ankle, with a writhe pinned flat at both ends, stretching rather than locking.
##  - It keeps the arm's beat: the body bobs and squashes on it, the head tilts from
##    side to side on alternate beats, and the legs bow outward as the body sinks.
##  - Walking is a bouncy cartoon strut: the feet swing through arcs, the hips bob
##    twice a stride, and the arms swing against the legs with a rubbery lag.
##  - The head turns to where the player looks, so the reflection looks back.
## Model: art/blender/scripts/build_player_toon_lily.py. Shaders: the arm's
## hose_arm_cel.gdshader and hose_arm_outline.gdshader, unsqueezed (it is in the world).

const LAYER := 1 << 15
const MODEL := preload("res://assets/characters/player_toon/player_toon_lily.glb")
const CEL := preload("res://shaders/hose_arm_cel.gdshader")
const OUTLINE := preload("res://shaders/hose_arm_outline.gdshader")
const Arm := preload("res://scripts/player/first_person_hose_arm.gd")
const HeldHandSlotScript := preload("res://scripts/characters/held_hand_slot.gd")
const LIMB_BONES := 12
const SIDES := ["Left", "Right"]
## Idle and walk, in metres and seconds, at the arm's beat.
const BOB := 0.022             # how far the body sinks on the beat
const SQUASH := 0.035          # how much it widens as it sinks
const HEAD_TILT := 0.10        # radians, side to side on alternate beats
const ARM_WRITHE := 0.022
const LEG_WRITHE := 0.010
const LEG_BOW := 1.4           # sideways bow per metre the leg is compressed
const STRIDE := 0.55           # metres per full walk cycle
const STEP_LIFT := 0.075
const STEP_REACH := 0.17
const ARM_SWING := 0.16
const WALK_BOB := 0.03
const MOVING_SPEED := 0.10
const HEAD_YAW_LIMIT := 1.05   # radians either side of the body's front
const HEAD_PITCH_LIMIT := 0.55

var holder: PlayerController
var skeleton: Skeleton3D
var native_ready := false
var reflected := false
var clock := 0.0
var walk_phase := 0.0
var walk := 0.0                # 0 standing .. 1 walking, eased
var hand_slot: HeldHandSlotScript
var _rest: Dictionary = {}
var _limbs: Array[Dictionary] = []
var _hips := -1
var _chest := -1
var _neck := -1
var _head := -1
var _head_front := -1
var _fingers: Array[int] = []
var _last_position := Vector3.ZERO


func _ready() -> void:
	set_process(false)
	var model := MODEL.instantiate() as Node3D
	model.name = "ToonLilyModel"
	# The model faces +Z (glTF front); the player faces -Z.
	model.rotation.y = PI
	add_child(model)
	var skeletons := model.find_children("*", "Skeleton3D", true, false)
	if skeletons.size() != 1:
		return
	skeleton = skeletons[0] as Skeleton3D
	for bone in skeleton.get_bone_count():
		_rest[bone] = skeleton.get_bone_global_rest(bone)
	_hips = skeleton.find_bone("Hips")
	_chest = skeleton.find_bone("Chest")
	_neck = skeleton.find_bone("Neck")
	_head = skeleton.find_bone("Head")
	_head_front = skeleton.find_bone("HeadFront")
	if _hips < 0 or _chest < 0 or _neck < 0 or _head < 0 or _head_front < 0:
		return
	for side: String in SIDES:
		for kind: String in ["Arm", "Leg"]:
			var bones: Array[int] = []
			for i in LIMB_BONES:
				bones.append(skeleton.find_bone("%s%s_%02d" % [side, kind, i]))
			var end := skeleton.find_bone(side + ("Hand" if kind == "Arm" else "Foot"))
			if bones.has(-1) or end < 0:
				return
			var root: Vector3 = (_rest[bones[0]] as Transform3D).origin
			var tip: Vector3 = (_rest[end] as Transform3D).origin
			_limbs.append({"side": side, "kind": kind, "bones": bones, "end": end, "root": root, "tip": tip,
					"length": root.distance_to(tip), "flip": 1.0 if side == "Left" else -1.0,
					"anchor": _chest if kind == "Arm" else _hips})
		for finger: String in ["Index", "Middle", "Ring"]:
			for k in [1, 2]:
				_fingers.append(skeleton.find_bone("%s%s_%d" % [side, finger, k]))
	if _fingers.has(-1):
		return
	# The gloves rest softly curled.
	for i in _fingers.size():
		var finger := _fingers[i]
		skeleton.set_bone_pose_rotation(finger, skeleton.get_bone_rest(finger).basis.get_rotation_quaternion() * Quaternion(Vector3.RIGHT, -(0.45 if i % 2 == 0 else 0.55)))
	# Flat black and white, ink-lined, in the world (no first-person depth squeeze).
	for draw: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		draw.layers = LAYER
		draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for surface in draw.mesh.get_surface_count():
			var source := draw.mesh.surface_get_material(surface)
			draw.set_surface_override_material(surface, _finish(source.resource_name if source != null else ""))
	# Bound the posed figure once (skinned bounds would follow the rest mesh only).
	var bounds := AABB(Vector3.ZERO, Vector3.ZERO)
	for bone in skeleton.get_bone_count():
		bounds = bounds.expand((_rest[bone] as Transform3D).origin)
	bounds = bounds.grow(0.45)
	for draw: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		draw.custom_aabb = draw.global_transform.affine_inverse() * skeleton.global_transform * bounds
	if holder == null or holder.camera == null:
		return
	holder.camera.cull_mask &= ~LAYER
	native_ready = true
	_pose()
	_bind_hand_slot()


func _finish(key: String) -> ShaderMaterial:
	var outline := ShaderMaterial.new()
	outline.shader = OUTLINE
	outline.set_shader_parameter("depth_squeeze", 1.0)
	outline.set_shader_parameter("width_px", 2.6)
	var fill := ShaderMaterial.new()
	fill.shader = CEL
	fill.set_shader_parameter("depth_squeeze", 1.0)
	fill.set_shader_parameter("tone", 0.0 if key == "ToonInk" else 0.97)
	fill.next_pass = outline
	return fill


## The hand slot shows what the carried case says is held, in her right glove. It is
## drawn on the avatar's own layer, so mirrors see it and the first-person camera does not.
func _bind_hand_slot() -> void:
	hand_slot = HeldHandSlotScript.new()
	hand_slot.name = "HandSlot"
	hand_slot.layers = LAYER
	skeleton.add_child(hand_slot)
	if not hand_slot.bind_hand(skeleton):
		hand_slot.queue_free()
		hand_slot = null
		return
	if not RealityState.state_changed.is_connected(refresh_hand):
		RealityState.state_changed.connect(refresh_hand)
	refresh_hand()


func refresh_hand() -> void:
	if not is_instance_valid(hand_slot):
		return
	var item := CarriedCase.hand()
	if item == hand_slot.worn:
		return
	var part: Node3D
	var state: Node = get_tree().get_first_node_in_group("v2_household_state") if is_inside_tree() else null
	if not item.is_empty() and state != null and state.has_method("packed_kitchen_tool"):
		var packed: Dictionary = state.packed_kitchen_tool(item)
		if not packed.is_empty():
			part = packed.station.tool_visual(packed.assembly)
	hand_slot.wear(item if part != null else "", part)


func _exit_tree() -> void:
	if RealityState.state_changed.is_connected(refresh_hand):
		RealityState.state_changed.disconnect(refresh_hand)


func set_reflection_active(enabled: bool) -> void:
	if not native_ready or reflected == enabled:
		return
	reflected = enabled
	_last_position = holder.global_position
	set_process(enabled)


func _process(delta: float) -> void:
	clock += delta
	var travelled := Vector2(holder.global_position.x - _last_position.x, holder.global_position.z - _last_position.z).length()
	_last_position = holder.global_position
	var moving := holder.planar_speed() > MOVING_SPEED
	walk = move_toward(walk, 1.0 if moving else 0.0, delta * 4.0)
	walk_phase = fmod(walk_phase + travelled / STRIDE, 1.0)
	_pose()


## The beat the whole body keeps: the arm's tempo and swell.
func beat() -> float:
	var swell := 0.5 + 0.5 * cos(TAU * clock * Arm.BEATS_PER_MINUTE / 60.0)
	return swell * swell


func _pose() -> void:
	var bounce := beat()
	var stride := TAU * walk_phase
	var still := 1.0 - walk
	# Body: sinks and widens on the beat; bobs twice a stride when walking.
	var sink := BOB * bounce * still + WALK_BOB * absf(sin(stride)) * walk
	var lift := Vector3(0.0, -sink, 0.0)
	var squash := 1.0 + SQUASH * bounce * still
	var sway := HEAD_TILT * 0.4 * sin(PI * clock * Arm.BEATS_PER_MINUTE / 60.0) * still + 0.05 * sin(stride) * walk
	var hips_pose := _moved(_hips, lift, Basis(Vector3.BACK, sway * 0.5), Vector3(squash, 1.0 / squash, squash))
	var chest_pose := _moved(_chest, lift * 1.1, Basis(Vector3.BACK, -sway), Vector3.ONE)
	skeleton.set_bone_global_pose(_hips, hips_pose)
	skeleton.set_bone_global_pose(_chest, chest_pose)
	skeleton.set_bone_global_pose(_neck, _moved(_neck, lift * 1.15, Basis(Vector3.BACK, -sway), Vector3.ONE))
	var head_pose := _head_pose(lift * 1.2, bounce, stride)
	skeleton.set_bone_global_pose(_head, head_pose)
	# The face marker rides the head, so reviews can read where the face points.
	skeleton.set_bone_global_pose(_head_front, head_pose * (_rest[_head] as Transform3D).affine_inverse() * (_rest[_head_front] as Transform3D))
	var anchors := {_hips: hips_pose * (_rest[_hips] as Transform3D).affine_inverse(), _chest: chest_pose * (_rest[_chest] as Transform3D).affine_inverse()}
	for limb: Dictionary in _limbs:
		_pose_limb(limb, anchors[limb.anchor], bounce, stride)


## A rest transform moved by an offset, turned about its own origin, and scaled.
func _moved(bone: int, offset: Vector3, turn: Basis, scale_by: Vector3) -> Transform3D:
	var rest: Transform3D = _rest[bone]
	return Transform3D((turn * rest.basis).scaled_local(scale_by), rest.origin + offset)


## The head turns toward where the player looks (so the reflection looks back), within
## a cartoon's neck, and tilts from side to side on alternate beats.
func _head_pose(offset: Vector3, bounce: float, stride: float) -> Transform3D:
	var rest: Transform3D = _rest[_head]
	var look := Vector3.BACK
	if is_instance_valid(holder) and holder.camera != null:
		var space := skeleton.global_basis.orthonormalized().inverse()
		look = (space * -holder.camera.global_basis.z).normalized()
	var yaw := clampf(atan2(look.x, look.z), -HEAD_YAW_LIMIT, HEAD_YAW_LIMIT)
	var pitch := clampf(asin(clampf(look.y, -1.0, 1.0)), -HEAD_PITCH_LIMIT, HEAD_PITCH_LIMIT)
	var tilt := HEAD_TILT * sin(PI * clock * Arm.BEATS_PER_MINUTE / 60.0) * (1.0 - walk) + 0.06 * sin(stride * 2.0) * walk
	var turn := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -pitch) * Basis(Vector3.BACK, tilt)
	# Turn about the neck, not the head's centre.
	var pivot: Vector3 = (_rest[_neck] as Transform3D).origin
	var origin := pivot + turn * (rest.origin - pivot) + offset + Vector3(0.0, 0.006 * bounce, 0.0)
	return Transform3D(turn * rest.basis, origin)


func _pose_limb(limb: Dictionary, anchor: Transform3D, bounce: float, stride: float) -> void:
	var flip: float = limb.flip
	var root: Vector3 = anchor * (limb.root as Vector3)
	var rest_tip: Vector3 = limb.tip
	var length: float = limb.length
	var arm: bool = limb.kind == "Arm"
	# Each leg's step is half a stride from the other's; each arm swings with the
	# opposite leg.
	var phase := stride + (0.0 if limb.side == "Left" else PI)
	var tip: Vector3
	if arm:
		var swing := -sin(phase) * ARM_SWING * walk
		var drift := 0.02 * sin(TAU * clock * 0.31 + flip) * (1.0 - walk)
		tip = root + (rest_tip - (limb.root as Vector3)) + Vector3(0.0, -BOB * bounce * 0.5 * (1.0 - walk), swing + drift)
	else:
		var foot_lift := maxf(0.0, sin(phase)) * STEP_LIFT * walk
		tip = rest_tip + Vector3(0.0, foot_lift, cos(phase) * STEP_REACH * walk)
	var line := tip - root
	var span := maxf(line.length(), 0.05)
	var forward := line / span
	var out := Vector3(flip, 0.0, 0.0)
	var side := (out - forward * out.dot(forward)).normalized()
	var front := (Vector3.BACK - forward * forward.z).normalized()   # her front is +Z
	# A compressed hose bows outward (the rubber-hose knee); an arm droops back a touch.
	var bow := side * maxf(0.0, length - span) * LEG_BOW if not arm else -front * 0.03 + side * 0.02
	var c1 := root + line * 0.33 + bow
	var c2 := tip - line * 0.33 + bow
	var writhe := ARM_WRITHE if arm else LEG_WRITHE
	var points: Array[Vector3] = []
	for i in LIMB_BONES + 1:
		var t := float(i) / LIMB_BONES
		var pinned := sin(PI * t) * sin(PI * t)
		var wave := TAU * (1.2 * t - clock * Arm.WRITHE_SPEED) + flip
		var p := _bezier(root, c1, c2, tip, t) + (side * sin(wave) + front * sin(wave - PI * 0.5) * 0.6) * writhe * pinned
		points.append(p)
	var bones: Array[int] = limb.bones
	for i in LIMB_BONES:
		var rest: Transform3D = _rest[bones[i]]
		var segment := points[i + 1] - points[i]
		var turn := Basis(Quaternion(rest.basis.y.normalized(), segment.normalized()))
		var stretch := segment.length() / maxf(length / LIMB_BONES, 0.0001)
		skeleton.set_bone_global_pose(bones[i], Transform3D((turn * rest.basis).scaled_local(Vector3(1.0, stretch, 1.0)), points[i]))
	var end_rest: Transform3D = _rest[limb.end]
	if arm:
		var arrival := (tip - c2).normalized()
		skeleton.set_bone_global_pose(limb.end, Transform3D(Basis(Quaternion(end_rest.basis.y.normalized(), arrival)) * end_rest.basis, tip))
	else:
		# The shoe stays level, toes dipping a little as the foot lifts.
		var dip := maxf(0.0, sin(phase)) * 0.35 * walk
		skeleton.set_bone_global_pose(limb.end, Transform3D(Basis(Vector3.RIGHT, dip) * end_rest.basis, tip))


static func _bezier(a: Vector3, b: Vector3, c: Vector3, d: Vector3, t: float) -> Vector3:
	var u := 1.0 - t
	return a * u * u * u + b * 3.0 * u * u * t + c * 3.0 * u * t * t + d * t * t * t
