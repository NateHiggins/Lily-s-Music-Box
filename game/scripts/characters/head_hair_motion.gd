extends SkeletonModifier3D
## Observes the final Head pose after the existing pose/skirt modifiers.
## Writes only a private material uniform; never poses a bone or advances time.
const MAX_PUSH_METRES := 0.012
const TRANSLATION_LAG := 0.012
const ROTATION_LAG := 0.025
const RETURN_RATE := 9.0
const MAX_SAMPLE_GAP := 0.25
const TELEPORT_METRES := 0.5

var ready_ok := false
var errors: Array[String] = []
var frames := 0
var last_delta := 0.0
var last_sway := Vector3.ZERO
var _cards: MeshInstance3D
var _material: ShaderMaterial
var _head := -1
var _primed := false
var _previous := Transform3D.IDENTITY
var _push_world := Vector3.ZERO


func bind(cards: MeshInstance3D, material: ShaderMaterial) -> bool:
	if ready_ok:
		return _refuse("motion reader is already bound")
	var body := get_skeleton()
	if body == null or cards == null or material == null:
		return _refuse("motion reader requires its Skeleton3D parent, cards and private material")
	_head = body.find_bone("Head")
	if _head < 0 or cards.get_node_or_null(cards.skeleton) != body:
		return _refuse("cards must bind the observed skeleton containing Head")
	_cards = cards
	_material = material
	ready_ok = true
	set_presentation_active(true)
	return true


func _refuse(message: String) -> bool:
	errors.append(message)
	ready_ok = false
	active = false
	reset()
	return false


func reset() -> void:
	_primed = false
	_previous = Transform3D.IDENTITY
	_push_world = Vector3.ZERO
	last_sway = Vector3.ZERO
	last_delta = 0.0
	if _material != null:
		_material.set_shader_parameter("sway", Vector3.ZERO)


func set_presentation_active(enabled: bool) -> void:
	reset()
	active = enabled and ready_ok


## Motion sample, also available to a fixture without changing any pose.
## Bound is in world metres, even when a model carries nonuniform scale.
func sample(head_world: Transform3D, card_world_basis: Basis, delta: float) -> Vector3:
	if not is_finite(delta) or delta <= 0.0 or delta > MAX_SAMPLE_GAP or not head_world.is_finite() or not card_world_basis.is_finite():
		reset()
		return Vector3.ZERO
	if absf(card_world_basis.determinant()) < 0.000001 or absf(head_world.basis.determinant()) < 0.000001:
		reset()
		return Vector3.ZERO
	if not _primed:
		_previous = head_world
		_primed = true
		return Vector3.ZERO
	var rotation := head_world.basis.orthonormalized().get_rotation_quaternion()
	var previous_rotation := _previous.basis.orthonormalized().get_rotation_quaternion()
	var change := (rotation * previous_rotation.inverse()).normalized()
	var angle := change.get_angle()
	if angle > PI:
		angle -= TAU
	var travel := head_world.origin - _previous.origin
	_previous = head_world
	if travel.length() > TELEPORT_METRES or absf(angle) > PI * 0.5:
		reset()
		return Vector3.ZERO
	var spin := change.get_axis() * angle / delta
	var velocity := travel / delta
	var lever := head_world.basis.orthonormalized().y * 0.10
	var target := (-velocity * TRANSLATION_LAG - spin.cross(lever) * ROTATION_LAG).limit_length(MAX_PUSH_METRES)
	_push_world = _push_world.lerp(target, 1.0 - exp(-RETURN_RATE * delta))
	# Forward+ has already skinned VERTEX into mesh space before vertex().
	# Applying a Head-space inverse here would rotate the displacement twice.
	return card_world_basis.inverse() * _push_world


func _process_modification_with_delta(delta: float) -> void:
	if not ready_ok:
		return
	var body := get_skeleton()
	if body == null or not is_instance_valid(_cards) or not _cards.is_inside_tree():
		_refuse("observed skeleton or cards disappeared")
		return
	var head_world := body.global_transform * body.get_bone_global_pose(_head)
	last_sway = sample(head_world, _cards.global_basis, delta)
	last_delta = delta
	_material.set_shader_parameter("sway", last_sway)
	frames += 1


func _exit_tree() -> void:
	reset()
