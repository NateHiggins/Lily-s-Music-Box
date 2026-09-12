extends StaticBody3D
## A local sliding cabinet mechanism. Carcass surfaces/collision pieces come
## from the furniture source; bypass panels stay inside that closed envelope.
const TRAVEL := .382
const DURATION := .28
var unit := ""
var opened := false
var _slide: AnimatableBody3D
var _motion: Tween

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
	return "[E] Close kitchen cabinet" if opened else "[E] Open kitchen cabinet"

func interact(_actor: Node = null) -> Dictionary:
	opened = not opened
	if _motion != null and _motion.is_valid(): _motion.kill()
	_motion = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_motion.tween_property(_slide, "position:x", TRAVEL if opened else 0.0, DURATION) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return {"action":"kitchen_cabinet", "unit":unit, "open":opened}

func _exit_tree() -> void:
	if _motion != null and _motion.is_valid(): _motion.kill()
