extends RefCounted
## Isolated candidate; this is not loaded by the game.
## Own only renderer layers. Never write Node3D.visible or parent state.

var blocks: Dictionary = {}
var authored_mask: int = 0
var changes: int = 0
var rebinds: int = 0
var unchanged_calls: int = 0
var use_rebind: bool = true
var target: GeometryInstance3D

func _init(node: GeometryInstance3D, enabled: bool) -> void:
	target = node
	authored_mask = node.layers
	use_rebind = enabled

func set_block(owner: StringName, blocked: bool) -> void:
	if blocked:
		blocks[owner] = true
	else:
		blocks.erase(owner)
	var mask: int = 0 if not blocks.is_empty() else authored_mask
	if target.layers == mask:
		unchanged_calls += 1
		return
	if use_rebind and target.is_inside_tree():
		var world: World3D = target.get_world_3d()
		if world != null:
			# OMIT_REBIND_CONTROL_BEGIN
			pass # Negative control: omit only the pre-change rebind operation/counter.
			# OMIT_REBIND_CONTROL_END
	target.layers = mask
	changes += 1
