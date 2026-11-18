extends StaticBody3D
## A local sliding cabinet mechanism. Carcass surfaces/collision pieces come
## from the furniture source; bypass panels stay inside that closed envelope.
const TRAVEL := .382
const DURATION := .28
signal open_state_changed(open: bool)
var unit := ""
var opened := false
var track_clean := true
var _slide: AnimatableBody3D
var _motion: Tween
var _held := false
## Where the panel has been put, in metres. The panel is synchronised to
## physics, so its node transform is the last physics frame's: reading that at
## the moment of release loses the final frame of the hand's motion. This is
## what the hand, a toggle or a restore last asked for, and it is what is saved.
var _travel := 0.0

func manipulation_target(hit: Dictionary) -> Dictionary:
	if hit.get("collider") != _slide: return {}
	return {"owner":self,"part":_slide,"frame":self,"kind":"slide","axis":Vector3.RIGHT,
		"minimum":0.0,"maximum":TRAVEL,"read":func(): return _travel,
		"owns":func(): return _held,
		"begin":func():
			if _held or RealityState.save_write_blocked: return false
			if _motion != null and _motion.is_valid(): _motion.kill()
			_held = true
			return true,
		"write":func(value: float):
			if not _held: return
			_travel = clampf(value, 0.0, TRAVEL)
			_slide.position.x = _travel
			opened = _travel > .001,
		"end":func(): _held = false; open_state_changed.emit(opened)}

class SlidingPanel extends AnimatableBody3D:
	var cabinet: Node
	func interact_prompt() -> String:
		return str(cabinet.call("interact_prompt"))
	func interact(actor: Node = null) -> Dictionary:
		return cabinet.call("interact", actor)

func setup(household: String) -> void:
	unit = household
	set_meta("unit", unit)
	# Rear/right panel is fixed; the forward/left panel slides over it.
	_panel(self, Vector3(.191,.475,-.229), Vector3(.37,.75,.018), true)
	_handle(self, Vector3(.06,.61,-.25))
	var panel := SlidingPanel.new()
	panel.cabinet = self
	_slide = panel
	_slide.name = "SlidingPanel"
	_slide.sync_to_physics = true
	add_child(_slide)
	_panel(_slide, Vector3(-.191,.475,-.253), Vector3(.37,.75,.018), true)
	_handle(_slide, Vector3(-.06,.61,-.277))

func _panel(parent: Node3D, at: Vector3, size: Vector3, collision: bool) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = at
	mesh.material_override = MatLib.get_mat("trim")
	parent.add_child(mesh)
	if collision:
		var shape := CollisionShape3D.new()
		var bounds := BoxShape3D.new()
		bounds.size = size
		shape.shape = bounds
		shape.position = at
		parent.add_child(shape)

func _handle(parent: Node3D, at: Vector3) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(.022,.085,.022)
	mesh.mesh = box
	mesh.position = at
	mesh.material_override = MatLib.get_mat("brass")
	parent.add_child(mesh)

func interact_prompt() -> String:
	return "Close kitchen cabinet" if opened else "Open kitchen cabinet"

## The panel's place as a share of its travel, 0 shut to 1 open: the saved value.
func travel_fraction() -> float:
	return _travel / TRAVEL


func interact(_actor: Node = null) -> Dictionary:
	opened = not opened
	_travel = TRAVEL if opened else 0.0
	if _motion != null and _motion.is_valid(): _motion.kill()
	_motion = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_motion.tween_property(_slide, "position:x", TRAVEL if opened else 0.0, DURATION if track_clean else DURATION*2.0) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	open_state_changed.emit(opened)
	return {"action":"kitchen_cabinet", "unit":unit, "open":opened}

func restore_open_state(value: bool) -> void:
	restore_travel(1.0 if value else 0.0)

func restore_travel(fraction: float) -> void:
	if _motion != null and _motion.is_valid(): _motion.kill()
	_held = false
	opened = fraction > .001
	_travel = TRAVEL*clampf(fraction,0,1)
	# Reconstruction is a teleport, not a physics animation. The synchronized
	# body otherwise retains its pre-mount physics transform until the next tick.
	_slide.sync_to_physics = false
	_slide.transform = Transform3D(Basis.IDENTITY, Vector3(TRAVEL*clampf(fraction,0,1), 0.0, 0.0))
	_slide.force_update_transform()
	_slide.sync_to_physics = true

func _exit_tree() -> void:
	if _motion != null and _motion.is_valid(): _motion.kill()
