extends "res://scripts/building/orison_v2_reality_affected_prop.gd"
## Gives an object V2 already furnishes the affected-state interface of a
## catalogue prop without rebuilding or reparenting it. The binding stands
## unseen at the object's place; V1's driver moves the binding, and the object
## follows it by the same offset, turn and swell. Its own finishes wear the
## glow. A stabilised rule puts the object back exactly where it stood.

var target: Node3D
var _rest := Transform3D.IDENTITY
var _carrying := false


func bind(node: Node3D, is_fixed: bool) -> void:
	target = node
	fixed = is_fixed
	position = node.position


func _build_visual() -> void:
	if target == null:
		push_error("V2 case prop binding has no object: " + prop_id)
		return
	_rest = target.transform
	target.set_meta("reality_affected_prop_id", prop_id)
	# Its own drawn parts, not the separate things standing on it.
	var stack: Array = [target]
	while not stack.is_empty():
		var item: Node = stack.pop_back()
		if item != target and (item.has_meta("v2_surface_prop") or item.has_meta("reality_affected_prop_id") \
				or item.has_meta("v2_native_case_prop")):
			continue
		if item is MeshInstance3D:
			_draws.append(item as MeshInstance3D)
		for child in item.get_children():
			stack.append(child)


func _apply_rule(effect: Dictionary) -> void:
	var was := _intensity
	super._apply_rule(effect)
	if not is_instance_valid(target):
		return
	if _intensity > 0.0 and was <= 0.0:
		# Seized from wherever the building has it standing now.
		_rest = target.transform
		position = _rest.origin
		_home = position
		_carrying = not fixed
	elif _intensity <= 0.0 and _carrying:
		_carrying = false
		position = _home
		rotation.y = 0.0
		scale = Vector3.ONE
		target.transform = _rest


func _process(delta: float) -> void:
	super._process(delta)
	if _carrying and is_instance_valid(target):
		var turned := Basis(Vector3.UP, rotation.y) * _rest.basis
		target.transform = Transform3D(turned.scaled_local(scale), _rest.origin + position - _home)


func _echo_frame() -> Transform3D:
	return Transform3D(_rest.basis, Vector3.ZERO)


func _echo_origin() -> Transform3D:
	return target.global_transform if is_instance_valid(target) else global_transform
