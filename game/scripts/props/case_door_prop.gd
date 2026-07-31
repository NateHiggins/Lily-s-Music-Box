class_name CaseDoorProp
extends FunctionalProp
## A door a case leaves behind.
##
## Unlike the 4B seam (`door_anomaly_prop.gd`), which is a light-leak that
## breathes with infection and is gated purely on how saturated the building
## is, this one is ordinary joinery in an ordinary corridor wall — a utility
## door, correctly detailed, in a spot the plans do not have a door. That is
## the whole horror of it: nothing about it looks wrong except that it is
## there. Case 02 ends with it whichever way the player answers, because the
## route in the pipes was never asking permission.
##
## Hidden until a case reveals it, and it does not open. Omar is the only
## person on the floor with a key to a utility door, and he is not opening
## one that never got a work order.

const W := 0.86
const H := 2.04
const T := 0.05

var revealed := false

var _leaf: Node3D


func _build_visual() -> void:
	_leaf = Node3D.new()
	add_child(_leaf)
	var frame := smat("trim", Color(0.74, 0.71, 0.64))
	var panel := smat("wood_dark", Color(0.40, 0.31, 0.24))
	# jambs and head, sitting proud of the plaster the way the real ones do
	for spec in [[Vector3(0.06, H + 0.08, 0.09), Vector3(-W / 2 - 0.03, (H + 0.08) / 2, 0.0)],
			[Vector3(0.06, H + 0.08, 0.09), Vector3(W / 2 + 0.03, (H + 0.08) / 2, 0.0)],
			[Vector3(W + 0.12, 0.07, 0.09), Vector3(0.0, H + 0.045, 0.0)]]:
		var piece := make_box(spec[0], spec[1], Color.WHITE)
		piece.material_override = frame
		piece.reparent(_leaf)
	var slab := make_box(Vector3(W, H, T), Vector3(0.0, H / 2, 0.0), Color.WHITE)
	slab.material_override = panel
	slab.reparent(_leaf)
	# two sunk panels, so it reads as period joinery and not a plywood blank
	for oy in [H * 0.30, H * 0.72]:
		var inset := make_box(Vector3(W - 0.20, H * 0.30, 0.012),
				Vector3(0.0, oy, T / 2 + 0.004), Color.WHITE)
		inset.material_override = frame
		inset.reparent(_leaf)
	var knob := make_cyl(0.028, 0.028, 0.05,
			Vector3(W / 2 - 0.09, 1.02, T / 2 + 0.03), Color.WHITE)
	knob.material_override = smat("brass", Color(0.68, 0.55, 0.24))
	knob.reparent(_leaf)
	_leaf.visible = false


func reveal() -> void:
	if revealed:
		return
	revealed = true
	_leaf.visible = true
	print("[CASE DOOR] %s is now in the wall" % name)


func is_revealed() -> bool:
	return revealed


func interact_prompt() -> String:
	if not revealed:
		return ""
	return "[E]  Omar: \"Not without a work order\""


func interact(_player: Node) -> void:
	# Deliberately does nothing. The door being shut is the point; opening
	# it belongs to a later case, and a locked door the player keeps
	# walking past does more work than one that opens on the first night.
	pass


func _start_normal_function() -> void:
	state = PState.IDLE
