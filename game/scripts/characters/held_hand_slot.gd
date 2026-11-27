class_name HeldHandSlot
extends BoneAttachment3D
## The hand slot (order w4b7f08c909bb; Lily 2026-11-24: "use the clothing system to put
## the object in their hand model not as an actual game object"). A part worn here
## follows the hand bone. It is presentation only: the carried case owns what is held
## (CarriedCase.HAND) and the world owner keeps the object's record. Nothing here
## moves, saves or collides.
##
## Bodies: the doodle avatar's right hand (the mirror view) and the first-person
## rubber-hose glove (ruling held_view_first_person_20261125); cast bodies later.

var layers := 1
var worn := ""
## Where the palm sits from the bone's origin, in the bone's own (unscaled) space.
var palm := Vector3.ZERO
## While this returns true the hand is busy working something else and the worn
## part is hidden. It stays worn: the case still says it is in hand.
var busy := Callable()
var _part: Node3D


var _fitted := Basis()


## A posed rig (the glove scales and stretches its Hand bone) changes the bone's
## basis after the part is worn, so the part is refitted after every skeleton update,
## once this attachment has followed the new pose.
func _ready() -> void:
	set_process(busy.is_valid())
	var skeleton := get_parent() as Skeleton3D
	if skeleton != null and not skeleton.skeleton_updated.is_connected(_refit):
		skeleton.skeleton_updated.connect(_refit)


func _process(_delta: float) -> void:
	if is_instance_valid(_part):
		_part.visible = not bool(busy.call())


func _refit() -> void:
	if is_instance_valid(_part) and not global_basis.is_equal_approx(_fitted):
		_fit()


## The worn part, for tests and reviews.
func part() -> Node3D:
	return _part if is_instance_valid(_part) else null


## Bind to the first bone whose name ends in one of these (imported glTF turns
## "smartrig:RightHand" into "smartrig_RightHand"; cast skeletons use "RightHand").
func bind_hand(skeleton: Skeleton3D, names: Array[String] = ["smartrig_RightHand", "RightHand"]) -> bool:
	for wanted: String in names:
		var index := skeleton.find_bone(wanted)
		if index >= 0:
			bone_name = skeleton.get_bone_name(index)
			return true
	return false


## Wear a part (a fresh node the slot takes ownership of) under an item name, or
## take the current one off with an empty name.
func wear(item: String, part: Node3D) -> void:
	if item == worn and (item.is_empty() or is_instance_valid(_part)):
		if part != null and part != _part:
			part.free()
		return
	if is_instance_valid(_part):
		_part.queue_free()
	_part = null
	worn = item
	if item.is_empty() or part == null:
		worn = ""
		return
	for draw: Node in part.find_children("*", "VisualInstance3D", true, false) + [part]:
		if draw is VisualInstance3D:
			draw.layers = layers
		if draw is GeometryInstance3D:
			draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(part)
	_part = part
	_fit()


## Held in the palm: centred on the palm, at world size and square whatever the
## rig's scale or stretch.
func _fit() -> void:
	if not is_instance_valid(_part):
		return
	_fitted = global_basis
	var correction := global_basis.inverse() * global_basis.orthonormalized()
	var bounds := AABB()
	var first := true
	for draw: Node in _part.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = (draw as MeshInstance3D).transform * (draw as MeshInstance3D).get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	_part.transform = Transform3D(correction, palm - correction * bounds.get_center())
