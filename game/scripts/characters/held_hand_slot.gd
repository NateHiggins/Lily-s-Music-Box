class_name HeldHandSlot
extends BoneAttachment3D
## The hand slot (order w4b7f08c909bb; Lily 2026-11-24: "use the clothing system to put
## the object in their hand model not as an actual game object"). A part worn here
## follows the hand bone. It is presentation only: the carried case owns what is held
## (CarriedCase.HAND) and the world owner keeps the object's record. Nothing here
## moves, saves or collides.
##
## Bodies: the doodle avatar's right hand today; cast bodies share the same slot later.

var layers := 1
var worn := ""
var _part: Node3D


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


## Held in the palm: centred on the hand, at world size whatever the rig's scale.
func _fit() -> void:
	if not is_instance_valid(_part):
		return
	var scale_now := global_basis.get_scale()
	var unscale := Vector3(1.0 / maxf(scale_now.x, 0.0001), 1.0 / maxf(scale_now.y, 0.0001), 1.0 / maxf(scale_now.z, 0.0001))
	var bounds := AABB()
	var first := true
	for draw: Node in _part.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = (draw as MeshInstance3D).transform * (draw as MeshInstance3D).get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	_part.transform = Transform3D(Basis.from_scale(unscale), -(Basis.from_scale(unscale) * bounds.get_center()))
