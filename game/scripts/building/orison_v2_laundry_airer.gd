extends LaundryAirerProp
## Blender presentation follows the original mechanism, including settling.
const MODEL := preload("res://assets/props/basement_airer.glb")
var suspension: Array[Node3D] = []

func _build_visual() -> void:
	super._build_visual()
	for parent in [_fixed, _rack]:
		for child in parent.get_children():
			if child is MeshInstance3D: child.free()
	var model := MODEL.instantiate() as Node3D
	_skin(model)
	var fixed := model.get_node("Fixed") as Node3D
	var moving := model.get_node("Rack") as Node3D
	model.remove_child(fixed); _fixed.add_child(fixed)
	model.remove_child(moving); _rack.add_child(moving)
	var template := model.get_node("Rope") as Node3D
	for side in [-1., 1.]:
		var instance := template.duplicate() as Node3D
		instance.name = "SuspensionLeft" if side < 0 else "SuspensionRight"
		add_child(instance); suspension.append(instance)
	model.free()
	_update_suspension()
	set_meta("v2_native_airer",true)

func _skin(root: Node) -> void:
	root.owner=null
	if root is MeshInstance3D:
		for index in root.mesh.get_surface_count():
			var source: Material = root.mesh.surface_get_material(index)
			root.set_surface_override_material(index,MatLib.get_mat(source.resource_name))
	for child in root.get_children(): _skin(child)

func _process(_delta: float) -> void:
	_update_suspension()

func _update_suspension() -> void:
	for index in suspension.size():
		var side := -1. if index == 0 else 1.
		var bottom := Vector3(side * .56,_rack.position.y + .075,0)
		var top := Vector3(side * .52,2.42,0)
		var direction := top-bottom
		suspension[index].transform = Transform3D(Basis(Quaternion(Vector3.UP,direction.normalized()))*Basis.from_scale(Vector3(1,direction.length(),1)),bottom)

func set_airer_lowered(lowered: bool, duration := .55) -> void:
	super.set_airer_lowered(lowered,duration)
	_update_suspension()
